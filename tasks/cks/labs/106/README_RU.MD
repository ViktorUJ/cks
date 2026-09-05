# Лаба 106 — AppArmor и seccomp: node-local policy и проверяемые отказы

## Цель

В этой CKS-лабе вы примените два независимых механизма защиты процесса контейнера на
уровне ядра Linux. Сначала переведёте заранее доставленный **AppArmor**-профиль из
`complain` в `enforce`, назначите его Pod через современное поле
`securityContext.appArmorProfile` и докажете отказ записи. Затем назначите безопасный
baseline `RuntimeDefault` и custom **seccomp Localhost**-профиль, который блокирует
системный вызов `unshare(2)`.

Это продолжение базового `SecurityContext` из CKA-лабы 106: здесь недостаточно написать
YAML. Localhost-профили живут на Kubernetes-ноде, поэтому нужно проверить ноду,
placement Pod и фактическое поведение процесса.

## Связь с курсом

- [Глава 16. AppArmor](../../course/16/ru.md)
- [Глава 17. seccomp](../../course/17/ru.md)
- [Глава 03. Container Runtime Security](../../course/03/ru.md)

## Инфраструктура

Окружение разворачивается через Terragrunt в AWS `eu-central-1`.

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.10.0.0/16` с публичными подсетями |
| `ssh-keys` | ключи для доступа к ноде |
| `k8s-1` | одноузловой kubeadm-кластер Kubernetes `1.36.0`, containerd и **Calico** |
| `worker` | рабочая машина с `kubectl`, `check_result` и SSH-доступом к ноде как `control-plane` |

Для экономии ресурсов control-plane является единственной workload-нодой: с неё снят
`NoSchedule` taint. Она помечена label
`security.cks.io/localhost-profiles-106=true`. Все Pod этой лабы должны выбирать именно
эту ноду — plan-профиль не переносится планировщиком (scheduler) на другую ноду.

Bootstrap уже подготовил **только на этой ноде**:

- `/etc/apparmor.d/k8s-106-deny-write`, загруженный в режиме `complain`;
- `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json`;
- label ноды для безопасного placement.

Не меняйте путь seccomp profile и не создавайте profile внутри обычного Pod. Это задача
администратора ноды, а не workload.

## Развёртывание

```bash
TASK=106 make run_cks_task
```

Подключитесь по SSH к рабочей машине. Контекст уже настроен:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Проверьте нодовый доступ до начала работы:

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ssh control-plane sudo jq empty \
  /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json
```

## Задания

---
| **1** | **Перевести AppArmor profile в enforce** |
| :---: | :--- |
| Что делаем | На ноде `control-plane` переведите profile `k8s-106-deny-write` в режим `enforce`. Исходный режим `complain` записывает нарушения, но не является защитой. Не удаляйте profile и не меняйте его имя. |
| Критерии приёмки | Нода с label `security.cks.io/localhost-profiles-106=true` существует; `/etc/apparmor.d/k8s-106-deny-write` доступен; `aa-status` показывает `k8s-106-deny-write (enforce)`. |

---
| **2** | **Localhost AppArmor Pod и блокировка записи** |
| :---: | :--- |
| Что делаем | Создайте namespace `security-106` и Pod `apparmor-writer`. Pod должен выбрать label ноды из инфраструктуры, отключить automount ServiceAccount token и на уровне Pod задать `appArmorProfile.type: Localhost`, `localhostProfile: k8s-106-deny-write`. Используйте `busybox:1.36`, контейнер `app`, команду сна `sleep 3600` и `emptyDir`, смонтированный в `/work`. После запуска попытайтесь записать файл в `/work`; операция обязана завершиться отказом. |
| Критерии приёмки | Pod запущен, использует именно Localhost profile и правильный nodeSelector; команда записи в `/work/cks-106-denied.txt` завершилась неуспешно. |

---
| **3** | **Безопасный baseline seccomp RuntimeDefault** |
| :---: | :--- |
| Что делаем | Создайте в `security-106` Pod `runtime-default` с `busybox:1.36` и `sleep 3600`. На уровне Pod явно укажите `securityContext.seccompProfile.type: RuntimeDefault`; Pod также должен выбрать подготовленную ноду. Проверьте в контейнере `/proc/1/status`: ожидается `Seccomp: 2`. |
| Критерии приёмки | Pod `Running`, в его Pod-level securityContext выбран `RuntimeDefault`, а процесс находится в seccomp filter mode. |

---
| **4** | **Custom Localhost seccomp profile** |
| :---: | :--- |
| Что делаем | Создайте Pod `localhost-seccomp` в `security-106` на подготовленной ноде. На уровне Pod укажите `seccompProfile.type: Localhost` и относительный путь `profiles/cks-106-deny-unshare.json` — без `/var/lib/kubelet/seccomp/`. Контейнер `app` должен использовать `busybox:1.36`, получить capability `SYS_ADMIN` и остаться запущенным после проверки. **Не выдавайте эту комбинацию за hardened baseline:** `SYS_ADMIN` остаётся одной из самых опасных capabilities, а `allowPrivilegeEscalation: false` не отнимает уже выданные права. Это capability-focused experiment, где безопасность показывает конкретный seccomp deny. |
| Критерии приёмки | Pod с правильным nodeSelector использует profile `Localhost:profiles/cks-106-deny-unshare.json`; JSON profile существует на ноде и содержит `SCMP_ACT_ERRNO`/`errnoRet: 1` для `unshare`; в контейнере добавлен только требуемый для эксперимента `SYS_ADMIN`. |

---
| **5** | **Доказать отказ syscall `unshare(2)`** |
| :---: | :--- |
| Что делаем | В команде контейнера `localhost-seccomp` выполните `unshare -m true`, сохраните успешное подтверждение ожидаемого отказа в `/tmp/unshare-result` как строку `unshare denied by seccomp`, затем удерживайте контейнер через `sleep 3600`. Повторная команда `kubectl exec ... -- unshare -m true` должна вернуть ненулевой код. Для attack-minded negative control создайте Pod `sysadmin-control` на той же ноде с `seccompProfile.type: Unconfined` и той же единственной capability `SYS_ADMIN`; его `unshare -m true` должен завершиться успешно. Удалите control Pod после проверки. |
| Критерии приёмки | Localhost Pod запущен; `Seccomp: 2`; `unshare` блокируется custom profile. В control Pod тот же syscall с той же capability и без seccomp filter проходит. Это доказывает kernel behavior, а не только наличие YAML. |

Linux capabilities и privilege escalation — разные оси. `allowPrivilegeEscalation: false`
включает `no_new_privs` и запрещает получать **новые** права через `execve` (setuid/setgid и
file capabilities), но не удаляет `SYS_ADMIN`, уже добавленную в bounding/effective set.
Для обычной рабочей нагрузки используйте `capabilities.drop: ["ALL"]` и отдельно
`allowPrivilegeEscalation: false`; эксперимент выше намеренно не является таким baseline.

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и пять независимых тестов. Она читает state Pod через API, проверяет
profile на ноде по SSH и выполняет контролируемые отрицательные сценарии. Если Localhost
Pod не создаётся, сначала посмотрите `kubectl describe pod`: обычная причина — абсолютный
путь вместо относительного или назначение Pod на ноду без profile.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=106 make delete_cks_task
```
