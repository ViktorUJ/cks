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

---
| **2** | **Создать EncryptionConfiguration для Secret** |
| :---: | :--- |
| Что делаем | На control-plane создайте `/etc/kubernetes/enc/encryption-config.yaml`, owner `root:root`, mode `0600`. Формат: `apiserver.config.k8s.io/v1`, `EncryptionConfiguration`; для `secrets` первым provider задайте `aescbc` с именованным base64-ключом из **32 случайных bytes**, затем `identity: {}`. |
| Критерии приёмки | Файл защищён mode `0600`; config содержит `secrets`, `aescbc` и корректный 32-byte key. `identity` допустим только последним временным fallback для legacy plaintext. |

---
| **3** | **Подключить config к static kube-apiserver** |
| :---: | :--- |
| Что делаем | Аккуратно измените `/etc/kubernetes/manifests/kube-apiserver.yaml`: добавьте flag `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`, read-only `volumeMount` `/etc/kubernetes/enc` и соответствующий `hostPath` volume `/etc/kubernetes/enc`. Сохраните backup manifest до правки. |
| Критерии приёмки | Работающий manifest содержит flag, mount и hostPath; после restart static Pod `kubectl get --raw='/readyz'` возвращает `ok`. |

---
| **4** | **Re-encrypt и доказать ciphertext** |
| :---: | :--- |
| Что делаем | После готовности API server создайте в `encryption-109` Secret `encrypted-secret` с literal `token=cks-109-fresh-ciphertext`. Перепишите все ранее существующие Secret через API (`kubectl get secrets --all-namespaces -o json | kubectl replace -f -`). Проверьте оба Secret через API и raw etcd. Только после этой проверки удалите временный `identity` fallback, перезапустите static kube-apiserver и снова проверьте `/readyz` и чтение обоих Secret. |
| Критерии приёмки | `legacy-secret` и `encrypted-secret` читаются через API с исходными значениями; raw value каждого начинается с `k8s:enc:aescbc:v1:`; legacy marker больше не виден в raw etcd; в финальной конфигурации отсутствует `identity`, API healthy. |

---
| **5** | **Минимизировать RBAC и отключить automount** |
| :---: | :--- |
| Что делаем | Создайте ServiceAccount `secret-reader` в `encryption-109` с `automountServiceAccountToken: false`. Role `secret-reader-109` должна давать только `get` только Secret `encrypted-secret`; привяжите её одноимённым RoleBinding. Создайте Pod `secret-reader-109` c этим ServiceAccount, `automountServiceAccountToken: false`, образом `registry.k8s.io/pause:3.10`. |
| Критерии приёмки | ServiceAccount может `get encrypted-secret`, но не `list secrets` и не `get legacy-secret`; Pod Running и не имеет автоматически добавленного `kube-api-access-*` volume. |

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
