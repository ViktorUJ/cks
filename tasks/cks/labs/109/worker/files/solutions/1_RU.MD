# Лаба 109 — эталонное решение: encryption at rest для Secret

> Все действия выполняются на рабочей машине. Это **только учебный одноузловой кластер**:
> bootstrap намеренно дал worker root-доступ к копии etcd TLS-материалов в закрытом
> каталоге и loopback SSH tunnel. В production не копируют `server.key` на рабочую
> станцию и не открывают прямой доступ к etcd.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
export NS=encryption-109
kubectl config use-context "$CTX"
```

## 1. Зафиксировать доказательство plaintext до включения шифрования

`Secret.data` в API кодируется base64, а не шифруется. Bootstrap создал безопасный
canary до появления EncryptionConfiguration. Выполним запрос к raw value etcd через
подготовленный tunnel и сохраним только строковое доказательство.

```bash
sudo etcdctl-109 get /registry/secrets/encryption-109/legacy-secret \
  --print-value-only | strings | tee /var/work/109/plaintext-proof.txt
# cks-109-legacy-plaintext
```

На этом шаге в файле нет `k8s:enc:`. Это доказательство состояния **до** настройки;
после re-encryption повторный вывод обязан стать ciphertext и marker исчезнет.

## 2. Создать EncryptionConfiguration

`aescbc` выбран только для учебной механики CKS. Kubernetes считает AES-CBC слабым из-за
риска padding-oracle атак и не рекомендует его как production default. Для внешнего key
manager используйте KMS v2; локальный provider выбирайте только с актуальным threat model
и процедурой ротации.

Сгенерируем 32-byte ключ AES-256, закодируем base64 и передадим конфигурацию на
control-plane. `aescbc` стоит первым: им будут записываться новые Secret. `identity`
последним позволяет API server прочитать старую plaintext запись только до миграции.

```bash
umask 077
key=$(head -c 32 /dev/urandom | base64 -w0)
cfg=$(mktemp)
cat >"$cfg" <<EOF
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

ssh control-plane 'sudo install -d -o root -g root -m 0700 /etc/kubernetes/enc'
scp "$cfg" control-plane:/tmp/encryption-config-109.yaml
ssh control-plane 'sudo install -o root -g root -m 0600 /tmp/encryption-config-109.yaml /etc/kubernetes/enc/encryption-config.yaml && sudo rm -f /tmp/encryption-config-109.yaml'
rm -f "$cfg"
ssh control-plane 'sudo stat -c "%a %U:%G %n" /etc/kubernetes/enc/encryption-config.yaml'
# 600 root:root /etc/kubernetes/enc/encryption-config.yaml
```

Настоящий ключ нельзя помещать в Git, ticket, терминальный log или Terraform state.
При потере ключа encrypted Secret из snapshot становится нечитаемым.

## 3. Подключить конфигурацию к static kube-apiserver

Сначала сохраним manifest. На control-plane откройте именно существующий static-Pod
manifest и добавьте **к имеющимся** `command`, `volumeMounts` и `volumes` эти элементы;
не заменяйте весь файл шаблоном.

```bash
ssh control-plane 'sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml.bak-109'
ssh -t control-plane 'sudoedit /etc/kubernetes/manifests/kube-apiserver.yaml'
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
kubectl get --raw='/readyz?verbose'
ssh control-plane "sudo grep -n -- '--encryption-provider-config\|encryption-config' /etc/kubernetes/manifests/kube-apiserver.yaml"
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

sudo etcdctl-109 get /registry/secrets/encryption-109/legacy-secret --print-value-only | strings | head
sudo etcdctl-109 get /registry/secrets/encryption-109/encrypted-secret --print-value-only | strings | head
# обе записи начинаются с k8s:enc:aescbc:v1:...
```

API возвращает plaintext авторизованному клиенту — это нормально и не доказывает
шифрование at rest. Здесь доказательство — raw etcd содержит `k8s:enc:aescbc:v1:` для
старой и новой записи и больше не содержит legacy marker.

Теперь migration fallback больше не нужен. Удаляем `identity`, принудительно перезапускаем
static kube-apiserver через CRI и ещё раз проверяем здоровье и чтение. Делайте это только
после snapshot и подтверждения ciphertext всех затронутых типов ресурсов.

```bash
ssh control-plane \
  "sudo sed -i '/^[[:space:]]*- identity: {}/d' /etc/kubernetes/enc/encryption-config.yaml"
ssh control-plane \
  "sudo crictl ps --name kube-apiserver -q | head -n1 | xargs -r sudo crictl stop"

until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
kubectl -n "$NS" get secret legacy-secret encrypted-secret
ssh control-plane 'sudo grep -n identity /etc/kubernetes/enc/encryption-config.yaml || true'
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
