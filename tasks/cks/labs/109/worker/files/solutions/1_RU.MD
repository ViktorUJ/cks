# Лаба 109 - эталонное решение: encryption at rest для Secret

> Работаем как на экзамене: команды `kubectl` выполняются на рабочей машине, а операции над
> узлом (etcd, файлы и manifest control-plane) - на самом control-plane: зайдите на него
> `ssh control-plane`, выполните команды и выйдите (`exit`). Это **только учебный одноузловой
> кластер**; в production прямой доступ к etcd пользователям не дают.

## Где взять примеры в документации

Все команды ниже взяты из официальной документации Kubernetes - на экзамене их нужно найти там
же, а не помнить наизусть:

| Что нужно                                                                                                                                                                                                                                                                                                            | Страница и раздел                                                                                                                                                                                    |
| :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Прочитать raw-запись etcd и увидеть префикс `k8s:enc:aescbc:v1:` (команда `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret1 \| hexdump -C`) | [Encrypting Confidential Data at Rest - Verify that newly written data is encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted)                             |
| Пример `EncryptionConfiguration` с `aescbc` и `identity`                                                                                                                                                                                                                                                       | [Encrypting Confidential Data at Rest - Write an encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file)                            |
| Флаг `--encryption-provider-config` и монтирование файла в static Pod kube-apiserver                                                                                                                                                                                                                | [Encrypting Confidential Data at Rest - Use the new encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file)                      |
| Перезаписать все Secret (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`)                                                                                                                                                                                                             | [Encrypting Confidential Data at Rest - Ensure all relevant data are encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted)                                  |
| Ротация ключа (шаги 1-7) и удаление старого ключа                                                                                                                                                                                                                                       | [Encrypting Confidential Data at Rest - Rotate a decryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#rotating-a-decryption-key)                                                        |
| Где взять пути к сертификатам etcd, если их не помнить: «`trusted-ca-file`, `cert-file` и `key-file` можно получить из описания Pod etcd» (`kubectl -n kube-system describe pod etcd-<node>` или `/etc/kubernetes/manifests/etcd.yaml`)       | [Operating etcd clusters for Kubernetes - Snapshot using etcdctl options](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)                                                               |
| Role/RoleBinding и ServiceAccount (`automountServiceAccountToken`)                                                                                                                                                                                                                                                        | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) |

Пути к сертификатам в kubeadm-кластере: `/etc/kubernetes/pki/etcd/ca.crt`,
`/etc/kubernetes/pki/etcd/server.crt`, `/etc/kubernetes/pki/etcd/server.key`; эндпоинт по умолчанию -
`https://127.0.0.1:2379`, поэтому на control-plane флаг `--endpoints` не нужен.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
export NS=encryption-109
kubectl config use-context "$CTX"
```

## 1. Зафиксировать доказательство plaintext до включения шифрования

`Secret.data` в API кодируется base64, а не шифруется. Bootstrap создал безопасный
canary до появления EncryptionConfiguration. Сначала посмотрим raw-запись etcd командой из
документации, затем сохраним строковое доказательство в файл `/var/work/109/plaintext-proof.txt`
на control-plane (`/tmp/plaintext-proof.txt`), затем скопируем его на рабочую машину в
`/var/work/109/plaintext-proof.txt` (каталог создан bootstrap-ом): проверка читает файл на рабочей машине.

Зайдите на control-plane и выполните на нём (в этой команде всё из документации, кроме ключа в
etcd: `/registry/secrets/<namespace>/<name>`):

```bash
ssh control-plane
sudo -i
```

```bash
# на control-plane: raw-запись etcd, вывод hexdump -C показывает plaintext
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C

# сохранить доказательство (только значение, через strings) - тоже на control-plane
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings > /tmp/plaintext-proof.txt
cat /tmp/plaintext-proof.txt
# cks-109-legacy-plaintext
exit   # из root
exit   # с control-plane
```

```bash
# на рабочей машине: скопировать доказательство
scp control-plane:/tmp/plaintext-proof.txt /var/work/109/plaintext-proof.txt
cat /var/work/109/plaintext-proof.txt
```

На этом шаге в файле нет `k8s:enc:`. Это доказательство состояния **до** настройки;
после re-encryption повторный вывод обязан стать ciphertext и marker исчезнет.

## 2. Создать EncryptionConfiguration

`aescbc` выбран только для учебной механики CKS. Kubernetes считает AES-CBC слабым из-за
риска padding-oracle атак и не рекомендует его как production default. Для внешнего key
manager используйте KMS v2; локальный provider выбирайте только с актуальным threat model
и процедурой ротации.

Сгенерируем 32-byte ключ AES-256, закодируем base64 и создадим конфигурацию на control-plane.
`aescbc` стоит первым: им будут записываться новые Secret. `identity` последним позволяет API
server прочитать старую plaintext запись только до миграции. Пример файла - на странице
документации (ссылка в начале решения).

```bash
ssh control-plane
sudo -i
```

```bash
# на control-plane (root)
mkdir -m 700 /etc/kubernetes/enc
key=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/encryption-config.yaml
ls -ld /etc/kubernetes/enc; ls -l /etc/kubernetes/enc
exit   # из root
exit   # с control-plane
```

Настоящий ключ нельзя помещать в Git, ticket, терминальный log или Terraform state.
При потере ключа encrypted Secret из snapshot становится нечитаемым.

## 3. Подключить конфигурацию к static kube-apiserver

Сначала сохраним manifest **вне** каталога `/etc/kubernetes/manifests/`: kubelet читает как static
Pod каждый не скрытый файл этого каталога, включая `*.bak`. Копия оригинального manifest внутри
каталога - это второй static Pod с тем же именем; kubelet может продолжать запускать именно её
(старую конфигурацию без `--encryption-provider-config`), а правка основного файла молча не
вступит в силу, и шифрование останется выключенным при внешне здоровом API server.
На control-plane откройте именно существующий static-Pod
manifest и добавьте **к имеющимся** `command`, `volumeMounts` и `volumes` эти элементы;
не заменяйте весь файл шаблоном.

```bash
ssh control-plane
sudo -i
```

```bash
# на control-plane (root)
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# container name: kube-apiserver
command:
- kube-apiserver
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
volumeMounts:
- name: encryption-config
  mountPath: /etc/kubernetes/enc
  readOnly: true

# spec.volumes
volumes:
- name: encryption-config
  hostPath:
    path: /etc/kubernetes/enc
    type: Directory
```

Kubelet заметит изменение и перезапустит static Pod. До продолжения дождитесь API
server, иначе ошибка YAML/пути может оставить control-plane недоступным.

```bash
# всё ещё на control-plane: проверить, что флаг попал в рабочий manifest, затем выйти
grep -n -- '--encryption-provider-config\|encryption-config' /etc/kubernetes/manifests/kube-apiserver.yaml
exit   # из root
exit   # с control-plane
```

```bash
# на рабочей машине: дождаться API server
kubectl get --raw='/readyz?verbose'
```

## 4. Переписать старые Secret и проверить ciphertext

Конфигурация не меняет уже сохранённые записи. Сначала создадим Secret после включения
provider, затем перепишем все существующие Secret через API. В production перед этим
делают защищённый snapshot и используют контролируемую процедуру с retry.

```bash
kubectl -n "$NS" create secret generic encrypted-secret \
  --from-literal=token='cks-109-fresh-ciphertext'
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

kubectl -n "$NS" get secret legacy-secret -o jsonpath='{.data.token}' | base64 -d; echo
kubectl -n "$NS" get secret encrypted-secret -o jsonpath='{.data.token}' | base64 -d; echo
# cks-109-legacy-plaintext
# cks-109-fresh-ciphertext
```

Raw-записи читаем на control-plane, как в задании 1:

```bash
ssh control-plane
sudo -i
```

```bash
# на control-plane (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/encrypted-secret | hexdump -C
# обе записи начинаются с k8s:enc:aescbc:v1:...
exit   # из root
exit   # с control-plane
```

API возвращает plaintext авторизованному клиенту - это нормально и не доказывает
шифрование at rest. Здесь доказательство - raw etcd содержит `k8s:enc:aescbc:v1:` для
старой и новой записи и больше не содержит legacy marker.

Теперь migration fallback больше не нужен. Удаляем `identity`, принудительно перезапускаем
static kube-apiserver через CRI и ещё раз проверяем здоровье и чтение. Делайте это только
после snapshot и подтверждения ciphertext всех затронутых типов ресурсов.

```bash
ssh control-plane
sudo -i
```

```bash
# на control-plane (root): убрать identity и перезапустить static kube-apiserver
vim /etc/kubernetes/enc/encryption-config.yaml   # удалить строку "- identity: {}"
crictl ps | grep kube-apiserver
crictl stop <id контейнера kube-apiserver>
exit   # из root
exit   # с control-plane
```

```bash
# на рабочей машине
until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
kubectl -n "$NS" get secret legacy-secret encrypted-secret
```

Финальное состояние этой лабы: encrypted provider первый и единственный, `identity`
удалён. Временный fallback нельзя оставлять постоянной «страховкой».

## 5. Ограничить API-доступ и отключить token automount

Шифрование at rest не заменяет RBAC: субъект с `get` Secret увидит plaintext через API.
Создадим ServiceAccount, которому доступен ровно один Secret, и диагностический Pod без
смонтированного service-account token.

```yaml
# rbac-109.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: encryption-109
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader-109
  namespace: encryption-109
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["encrypted-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-109
  namespace: encryption-109
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: encryption-109
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader-109
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader-109
  namespace: encryption-109
spec:
  serviceAccountName: secret-reader
  automountServiceAccountToken: false
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.10
```

```bash
kubectl apply -f rbac-109.yaml
kubectl wait -n "$NS" --for=condition=Ready pod/secret-reader-109 --timeout=120s
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/encrypted-secret -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader list secrets -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/legacy-secret -n "$NS"
# yes
# no
# no

check_result
```

`automountServiceAccountToken: false` уменьшает доступный Pod credential surface, но не
ограничивает RBAC самого ServiceAccount, если приложение получит другие credentials.

## Дополнительно: как выглядит KMS v2 и полная ротация ключа

### KMS v2: envelope encryption без локального ключа в config

`aescbc` выше нужен только для учебной механики. В production KMS v2 подключает
поддерживаемый KMS-plugin через локальный Unix socket в `EncryptionConfiguration`.
Для KMS v2 API server использует зашифрованный seed/DEK на уровне API server и
выводит ключи шифрования отдельных записей. Plugin защищает seed через внешний KEK;
этим KMS v2 отличается от per-resource KMS v1. Etcd хранит ciphertext ресурсов и
метаданные, необходимые для расшифровки. KEK остаётся во внешнем KMS, а не в etcd или в Git. Схема
конфигурации зависит от версии Kubernetes и plugin, но принципиально нужны provider `kms`,
стабильное имя key и endpoint socket. Не копируйте примерный endpoint из чужого кластера:
сверьте формат KMS v2 и health/ACL требования с документацией своей версии Kubernetes.

### Полный lifecycle ротации aescbc key

Переход `identity -> aescbc` в задании 4 - это migration, а не ротация уже
зашифрованного ключа. Перед ротацией сделайте зашифрованный etcd snapshot и сохраните
старый ключ для rollback. Добавьте новый ключ **первым**, а старый временно оставьте
вторым: providers читаются по порядку, а новые записи пишутся первым ключом.

```yaml
- aescbc:
    keys:
    - name: cks-109-aescbc-2026-rotation
      secret: <base64-32-byte-new-key>
    - name: cks-109-aescbc
      secret: <base64-32-byte-old-key>
```

После перезапуска API server перепишите ресурсы и проверьте именно имя нового key в raw
ciphertext, а не только общий `k8s:enc` prefix:

```bash
# на рабочей машине
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
ssh control-plane
sudo -i
```

```bash
# на control-plane (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings | grep -F 'k8s:enc:aescbc:v1:cks-109-aescbc-2026-rotation:'
exit   # из root
exit   # с control-plane
```

Когда migration всех Secret подтверждена, backup сделан, API читает данные и `/readyz`
возвращает `ok`, удалите старый key из списка, перезапустите API server и повторите
проверки. Не удаляйте старый key раньше: записи, не переписанные новым provider, станут
нечитаемыми. Для KMS v2 порядок тот же: сначала новый primary KEK/plugin, затем
re-encryption, проверка и только после миграции вывод старого KEK из эксплуатации.
