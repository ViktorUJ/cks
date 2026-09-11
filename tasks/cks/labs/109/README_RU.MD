# Лаба 109 — Шифрование Secret в etcd и минимальный доступ

## Цель

В этой CKS-лабе вы докажете, что Kubernetes Secret без encryption at rest хранится в
etcd как читаемые bytes (base64 — не шифрование), включите `aescbc` через
`EncryptionConfiguration`, подключите его к static `kube-apiserver`, перепишете старые
Secret и ограничите доступ к данным RBAC и `automountServiceAccountToken`.

`aescbc` выбран здесь только для отработки экзаменационной механики
`EncryptionConfiguration` и re-encryption. Текущая документация Kubernetes считает AES-CBC
слабым и не рекомендует его из-за риска padding-oracle атак; `aesgcm` также требует
автоматизированной ротации ключа. Для production выбирайте provider по актуальной
документации и threat model; при внешнем key manager предпочтителен KMS v2
(см. [главу 21](../../course/21/ru.md)).

## Threat model

Encryption at rest защищает от storage compromise: предположим, что атакующий получил read-only доступ к etcd snapshot или storage layer, например через backup или volume snapshot, но не имеет авторизованного API-доступа. Задание 1 доказывает именно этот исходный риск через raw чтение etcd.

После включения encryption at rest задания 2–4 уменьшают blast radius такого доступа: прочитанные напрямую данные не должны раскрывать Secret. Это не универсальная защита и не замена контролю доступа к API.

Если у атакующего есть законный API-доступ с правами на чтение Secret, encryption at rest от этой угрозы не защищает: API вернёт значение после расшифровки. Поэтому задание 5 отдельно ограничивает RBAC и automount, уменьшая blast radius identity workload с такими правами.

## Проверьте себя перед стартом

<details>
<summary>1. Почему base64 в `Secret.data` не является шифрованием?</summary>

base64 - это просто кодирование, обратимое без ключа: любой, у кого есть доступ к самим байтам (например, через raw чтение etcd), может декодировать значение мгновенно, без каких-либо криптографических операций. Шифрование требует ключа для обратного преобразования - base64 этого свойства не имеет вообще.
</details>

<details>
<summary>2. Почему `identity` provider должен идти ПОСЛЕДНИМ в списке providers, а не первым?</summary>

Провайдеры в `EncryptionConfiguration` пробуются по порядку для ЧТЕНИЯ существующих записей, а первый provider используется для ЗАПИСИ новых данных. Если `identity` (то есть "без шифрования") стоит первым, все новые записи будут писаться НЕзашифрованными, несмотря на наличие `aescbc` в списке. `identity` последним позволяет читать старые (ещё не мигрированные) plaintext-записи, но гарантирует, что все новые записи шифруются первым provider'ом.
</details>

<details>
<summary>3. Почему нельзя просто удалить старый ключ шифрования сразу после добавления нового?</summary>

Существующие записи в etcd остаются зашифрованными СТАРЫМ ключом до тех пор, пока их не перепишут явно (re-encryption). Если удалить старый ключ раньше, чем все записи переписаны новым, API server не сможет расшифровать оставшиеся старые записи - они станут навсегда нечитаемыми. Порядок: добавить новый ключ первым → переписать все Secret → подтвердить, что все записи используют новый ключ → только потом удалить старый.
</details>

## Инфраструктура

Окружение разворачивается Terragrunt в AWS `eu-central-1`:

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.10.0.0/16` с публичными подсетями |
| `ssh-keys` | SSH-ключи для worker и control-plane |
| `k8s-1` | одноузловой kubeadm control-plane: Kubernetes **1.36.0**, containerd, **Calico** |
| `worker` | рабочая машина с `kubectl`, `etcdctl` 3.6.0 и helper `etcdctl-109` |

Control-plane намеренно принимает обычные Pod — отдельный Kubernetes worker не создаётся.
До начала заданий bootstrap создаёт namespace `encryption-109` и безобидный
`legacy-secret`. Этот Secret создан **до** EncryptionConfiguration, поэтому служит
контролируемым доказательством plaintext состояния.

`etcdctl-109` на рабочей машине создаёт SSH tunnel к loopback endpoint etcd и использует
TLS-материалы в root-only каталоге. Это намеренно ограниченный механизм учебной среды;
в production нельзя переносить etcd private key на worker и нельзя давать пользователям
прямой доступ к etcd.

## Развёртывание

```bash
TASK=109 make run_cks_task
```

Подключитесь к рабочей машине. Контекст `cluster1-admin@cluster1` уже настроен.

```bash
time_left
check_result
```

## Задания

---
| **1** | **Доказать исходный plaintext Secret** |
| :---: | :--- |
| Что делаем | До включения шифрования запросите raw запись `/registry/secrets/encryption-109/legacy-secret` через `sudo etcdctl-109 get ... --print-value-only`, пропустите через `strings` и сохраните результат в `/var/work/109/plaintext-proof.txt`. |
| Критерии приёмки | Файл непустой, содержит ровно marker `cks-109-legacy-plaintext` и не содержит `k8s:enc:`. Это доказательство исходного состояния: `Secret.data` — base64, не encryption at rest. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

Это задание нужно выполнить ПЕРВЫМ, до задания 2 - как только вы включите EncryptionConfiguration и перепишете Secret, plaintext-доказательство исчезнет и вы не сможете зафиксировать его post-hoc. `etcdctl-109` уже настроен на SSH tunnel и TLS - используйте именно этот helper, а не пытайтесь подключиться к etcd напрямую.
</details>

---
| **2** | **Создать EncryptionConfiguration для Secret** |
| :---: | :--- |
| Что делаем | На control-plane создайте `/etc/kubernetes/enc/encryption-config.yaml`, owner `root:root`, mode `0600`. Формат: `apiserver.config.k8s.io/v1`, `EncryptionConfiguration`; для `secrets` первым provider задайте `aescbc` с именованным base64-ключом из **32 случайных bytes**, затем `identity: {}`. |
| Критерии приёмки | Файл защищён mode `0600`; config содержит `secrets`, `aescbc` и корректный 32-byte key. `identity` допустим только последним временным fallback для legacy plaintext. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Сгенерируйте ключ через `head -c 32 /dev/urandom | base64` - именно 32 БАЙТА (не 32 символа base64-строки, которая будет длиннее из-за кодирования). Проверьте себя: `echo -n "<ваш-base64-ключ>" | base64 -d | wc -c` должен вернуть ровно `32`.
</details>

---
| **3** | **Подключить config к static kube-apiserver** |
| :---: | :--- |
| Что делаем | Аккуратно измените `/etc/kubernetes/manifests/kube-apiserver.yaml`: добавьте flag `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`, read-only `volumeMount` `/etc/kubernetes/enc` и соответствующий `hostPath` volume `/etc/kubernetes/enc`. Сохраните backup manifest до правки. |
| Критерии приёмки | Работающий manifest содержит flag, mount и hostPath; после restart static Pod `kubectl get --raw='/readyz'` возвращает `ok`. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Три отдельных изменения нужны одновременно: сам флаг `--encryption-provider-config`, `volumeMounts` (внутри контейнера) И `volumes` (hostPath на уровне Pod spec) - забыть любое из трёх приведёт либо к CrashLoopBackOff (флаг указывает на файл, которого контейнер не видит), либо к тому, что флаг просто не будет передан. Сохраните копию оригинального manifest (`sudo cp kube-apiserver.yaml kube-apiserver.yaml.bak`) перед правкой - если что-то пойдёт не так, у вас будет путь для быстрого восстановления.
</details>

---
| **4** | **Re-encrypt и доказать ciphertext** |
| :---: | :--- |
| Что делаем | После готовности API server создайте в `encryption-109` Secret `encrypted-secret` с literal `token=cks-109-fresh-ciphertext`. Перепишите все ранее существующие Secret через API (`kubectl get secrets --all-namespaces -o json | kubectl replace -f -`). Проверьте оба Secret через API и raw etcd. Только после этой проверки удалите временный `identity` fallback, перезапустите static kube-apiserver и снова проверьте `/readyz` и чтение обоих Secret. |
| Критерии приёмки | `legacy-secret` и `encrypted-secret` читаются через API с исходными значениями; raw value каждого начинается с `k8s:enc:aescbc:v1:`; legacy marker больше не виден в raw etcd; в финальной конфигурации отсутствует `identity`, API healthy. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Порядок критичен: создать `encrypted-secret` → переписать ВСЕ существующие Secret через `kubectl replace` → проверить raw etcd для ОБОИХ (legacy и encrypted) → ТОЛЬКО ПОТОМ убрать `identity` из конфига. Если убрать `identity` раньше, чем `legacy-secret` перезаписан, API server больше не сможет прочитать старую plaintext-запись через provider chain, и `legacy-secret` станет недоступен.
</details>

---
| **5** | **Минимизировать RBAC и отключить automount** |
| :---: | :--- |
| Что делаем | Создайте ServiceAccount `secret-reader` в `encryption-109` с `automountServiceAccountToken: false`. Role `secret-reader-109` должна давать только `get` только Secret `encrypted-secret`; привяжите её одноимённым RoleBinding. Создайте Pod `secret-reader-109` c этим ServiceAccount, `automountServiceAccountToken: false`, образом `registry.k8s.io/pause:3.10`. |
| Критерии приёмки | ServiceAccount может `get encrypted-secret`, но не `list secrets` и не `get legacy-secret`; Pod Running и не имеет автоматически добавленного `kube-api-access-*` volume. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Используйте `resourceNames: ["encrypted-secret"]` в Role - без этого поля `get`/`list` на ресурсе `secrets` дало бы доступ ко ВСЕМ Secret в namespace, включая `legacy-secret`, что нарушает требование least-privilege. `pause:3.10` - образ-заглушка, не требующий Kubernetes API вообще, поэтому automount отключается на двух уровнях (SA и Pod) без функциональных последствий.
</details>

## Проверка

```bash
check_result
```

Проверка содержит Init и пять обязательных тестов. Тест 4 проверяет не только наличие
файла конфигурации, а реальный ciphertext `k8s:enc:aescbc:v1:` для новой и прежней
etcd-записи и отсутствие migration-only `identity` в финальной конфигурации. Перед массовым re-encryption в реальной среде требуется snapshot, план
ротации ключей и контролируемое окно; эта лаба не является production runbook.

## Статический DoD

Перед сдачей проверьте, что в `tasks/cks/labs/109` есть только полный CKS-набор:

- `README_RU.MD` и `worker/files/solutions/1_RU.MD`; переводов и CKA-материалов нет;
- `env.hcl` фиксирует `k8_version = "1.36.0"` и CNI `calico`;
- присутствуют `vpc`, `ssh-keys`, `k8s-1` и `worker` Terragrunt-конфигурации;
- control-plane bootstrap создаёт legacy plaintext canary, worker bootstrap устанавливает
  pinned `etcdctl` и helper;
- `tests.bats` содержит `0 Init` и ровно пять тематических acceptance tests;
- документация, тесты и решение покрывают plaintext proof, EncryptionConfiguration,
  apiserver flag/mount, re-encryption с `k8s:enc`, RBAC и automount.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD)

## Удаление

```bash
TASK=109 make delete_cks_task
```

## Дополнительно: KMS v2 и полный жизненный цикл ротации

**KMS v2 (опциональный walkthrough).** Внешний KMS-plugin подключается к API server как
provider `kms` в `EncryptionConfiguration`; его endpoint — локальный Unix socket, а ключ
provider получает стабильное имя, например `kms-v2-primary`. API server генерирует
случайный **DEK** для шифрования каждой записи Secret, KMS-plugin шифрует (wrap) этот DEK
своим **KEK** (ключом, управляемым внешним key manager), а etcd хранит ciphertext Secret
и wrapped DEK. Таким образом, KEK не лежит в etcd; availability, ACL и backup KMS становятся
частью модели безопасности. Минимальный **иллюстративный** provider (endpoint должен
соответствовать установленному plugin) выглядит так:

```yaml
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: kms-v2-primary
      endpoint: unix:///var/run/kms-plugin/socket.sock
```

Добавьте provider первым для новых записей, смонтируйте socket в static `kube-apiserver`
и дождитесь health plugin до re-encryption. Для реальной конфигурации используйте
поддерживаемый plugin и актуальный формат `kms` v2 из документации используемой версии
Kubernetes; эта лаба не поднимает KMS-plugin и не выдаёт рабочий socket.

**Полная ротация ключа provider.** Выполненная в задании 4 миграция plaintext в первый
`aescbc`-ключ — не полная ротация ключа. Для неё: (1) сделайте защищённый etcd snapshot и
проверьте, что старый ключ сохранён и доступен для rollback; (2) добавьте новый ключ
первым в `aescbc.keys`, оставив старый вторым, затем перезапустите API server; (3)
перезапишите существующие Secret через API, чтобы они были зашифрованы новым первым ключом;
(4) для выборочных и затем всех raw etcd записей подтвердите префикс
`k8s:enc:aescbc:v1:<имя-нового-ключа>:`; (5) только после полной миграции, backup и
проверки чтения удалите старый ключ, перезапустите API server и снова проверьте `/readyz`
и Secret. Для KMS v2 эквивалентно сначала переключают primary KEK/plugin, проводят
re-encryption и только затем выводят старый KEK из использования по процедуре KMS.
