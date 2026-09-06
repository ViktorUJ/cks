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

## Threat model

Предположим RCE в контейнере. Вопрос после compromise — не «мог ли атакующий получить shell», а «что этот shell может сделать дальше» и насколько велик его blast radius.

AppArmor в заданиях 1–2 ограничивает объекты и операции: профиль переводится в enforce и затем доказывается отказ записи. Так уже скомпрометированный процесс не получает неограниченное действие только потому, что он выполняется в контейнере.

seccomp в заданиях 3–5 ограничивает доступный системный вызов: сначала применяется baseline, затем custom profile, а затем проверяется реальный отказ `unshare(2)`. Задание 5 уже содержит negative control через Pod `sysadmin-control`: при той же capability без seccomp filter вызов проходит, поэтому сравнение показывает именно границу после compromise.

## Проверьте себя перед стартом

<details>
<summary>1. Чем `complain` отличается от `enforce` в AppArmor, и почему `complain` нельзя показывать как доказательство защиты?</summary>

В режиме `complain` AppArmor только логирует нарушения профиля, но НЕ блокирует их - операция, которая должна быть запрещена, всё равно выполнится, просто появится запись в журнале. В `enforce` операция реально блокируется. Задание 1 явно требует перевести профиль в `enforce`, потому что демонстрация "вот нарушение в логе" при `complain` не доказывает защиту - процесс всё равно смог выполнить действие.
</details>

<details>
<summary>2. Почему `allowPrivilegeEscalation: false` не убирает уже выданную capability `SYS_ADMIN`?</summary>

`allowPrivilegeEscalation: false` включает kernel-флаг `no_new_privs`, который запрещает процессу получать НОВЫЕ права через `execve` (например, через setuid-бинарник или file capabilities). Это не влияет на права, которые процесс УЖЕ имеет в своём effective/bounding set - если контейнер запущен с capability `SYS_ADMIN` явно в манифесте, эта capability остаётся доступной независимо от значения `allowPrivilegeEscalation`.
</details>

<details>
<summary>3. Почему `localhostProfile` в манифесте Pod указывается как относительный путь, а не абсолютный?</summary>

Kubelet сам разрешает относительный путь относительно своего seccomp root (по умолчанию `/var/lib/kubelet/seccomp/`). Если указать абсолютный путь, kubelet будет искать файл ПО ЭТОМУ АБСОЛЮТНОМУ ПУТИ внутри seccomp root, что почти всегда не совпадёт с реальным расположением файла - Pod получит `CreateContainerError`.
</details>

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

<details>
<summary>💡 Подсказка к заданию 1</summary>

Команда `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` перезагружает уже существующий профиль - если он был в `complain`, а файл на диске уже описывает `enforce`, этой команды достаточно. Проверьте себя через `aa-status | grep k8s-106-deny-write` - вывод должен явно показывать `(enforce)`, не просто наличие профиля в списке.
</details>

---
| **2** | **Localhost AppArmor Pod и блокировка записи** |
| :---: | :--- |
| Что делаем | Создайте namespace `security-106` и Pod `apparmor-writer`. Pod должен выбрать label ноды из инфраструктуры, отключить automount ServiceAccount token и на уровне Pod задать `appArmorProfile.type: Localhost`, `localhostProfile: k8s-106-deny-write`. Используйте `busybox:1.36`, контейнер `app`, команду сна `sleep 3600` и `emptyDir`, смонтированный в `/work`. После запуска подтвердите эффективный profile командой `cat /proc/1/attr/current` (если интерфейс доступен), выполните разрешённую операцию чтения, например `cat /etc/hostname >/dev/null`, и затем попытайтесь записать файл в `/work`; операция обязана завершиться отказом. На ноде зафиксируйте AppArmor denial для profile/process из `journalctl -k | grep -i apparmor` либо `dmesg | grep -i apparmor`. |
| Критерии приёмки | Pod запущен, использует именно Localhost profile и правильный nodeSelector; effective profile процесса показывает `k8s-106-deny-write` в enforce mode (когда `/proc/.../attr/current` доступен); разрешённая операция проходит, а запись в `/work/cks-106-denied.txt` завершается AppArmor-отказом. В kernel journal/audit log есть относящееся к попытке событие `apparmor="DENIED"` с этим profile. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

`appArmorProfile` для профиля с типом `Localhost` указывается через два отдельных поля: `type: Localhost` и `localhostProfile: k8s-106-deny-write` (имя профиля БЕЗ пути `/etc/apparmor.d/`) - это то же имя, под которым профиль был загружен в задании 1. Если Pod не запускается (CreateContainerError), проверьте, что profile действительно уже загружен на НУЖНОЙ ноде через nodeSelector - AppArmor-профили node-local, они не переносятся автоматически.
</details>

---
| **3** | **Безопасный baseline seccomp RuntimeDefault** |
| :---: | :--- |
| Что делаем | Создайте в `security-106` Pod `runtime-default` с `busybox:1.36` и `sleep 3600`. На уровне Pod явно укажите `securityContext.seccompProfile.type: RuntimeDefault`; Pod также должен выбрать подготовленную ноду. Проверьте в контейнере `/proc/1/status`: ожидается `Seccomp: 2`. |
| Критерии приёмки | Pod `Running`, в его Pod-level securityContext выбран `RuntimeDefault`, а процесс находится в seccomp filter mode. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

`Seccomp: 2` в `/proc/1/status` означает "filter mode активен" (SECCOMP_MODE_FILTER) - это то, что вы должны увидеть. `Seccomp: 0` означало бы отсутствие seccomp filter вообще (`Unconfined`). Это самое простое задание из пяти в этой группе - если оно не проходит, скорее всего проблема в nodeSelector, а не в самом seccompProfile.
</details>

---
| **4** | **Custom Localhost seccomp profile** |
| :---: | :--- |
| Что делаем | Создайте Pod `localhost-seccomp` в `security-106` на подготовленной ноде. На уровне Pod укажите `seccompProfile.type: Localhost` и относительный путь `profiles/cks-106-deny-unshare.json` — без `/var/lib/kubelet/seccomp/`. Контейнер `app` должен использовать `busybox:1.36`, получить capability `SYS_ADMIN` и остаться запущенным после проверки. **Не выдавайте эту комбинацию за hardened baseline:** `SYS_ADMIN` остаётся одной из самых опасных capabilities, а `allowPrivilegeEscalation: false` не отнимает уже выданные права. Это capability-focused experiment, где безопасность показывает конкретный seccomp deny. |
| Критерии приёмки | Pod с правильным nodeSelector использует profile `Localhost:profiles/cks-106-deny-unshare.json`; JSON profile существует на ноде и содержит `SCMP_ACT_ERRNO`/`errnoRet: 1` для `unshare`; в контейнере добавлен только требуемый для эксперимента `SYS_ADMIN`. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Путь `profiles/cks-106-deny-unshare.json` - относительный к kubelet seccomp root `/var/lib/kubelet/seccomp/`, то есть реальный файл на ноде лежит по адресу `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json`. Не пишите в манифесте полный абсолютный путь - kubelet сам добавит корень. `SYS_ADMIN` даётся здесь ИМЕННО для эксперимента (нужна capability, позволяющая в принципе вызвать `unshare`), а не как рекомендуемая практика - не путайте учебный сценарий с production baseline.
</details>

---
| **5** | **Доказать отказ syscall `unshare(2)`** |
| :---: | :--- |
| Что делаем | В команде контейнера `localhost-seccomp` выполните `unshare -m true`, сохраните успешное подтверждение ожидаемого отказа в `/tmp/unshare-result` как строку `unshare denied by seccomp`, затем удерживайте контейнер через `sleep 3600`. Повторная команда `kubectl exec ... -- unshare -m true` должна вернуть ненулевой код. Для attack-minded negative control создайте Pod `sysadmin-control` на той же ноде с `seccompProfile.type: Unconfined` и той же единственной capability `SYS_ADMIN`; его `unshare -m true` должен завершиться успешно. Удалите control Pod после проверки. |
| Критерии приёмки | Localhost Pod запущен; `Seccomp: 2`; `unshare` блокируется custom profile. В control Pod тот же syscall с той же capability и без seccomp filter проходит. Это доказывает kernel behavior, а не только наличие YAML. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Порядок команд важен для доказательности: сначала выполните `unshare -m true` и убедитесь, что он падает с ошибкой (ненулевой exit code), ТОЛЬКО ПОТОМ запишите строку `unshare denied by seccomp` в `/tmp/unshare-result` - не пишите строку заранее, "предполагая" результат. Negative control (`sysadmin-control`) должен использовать ТУ ЖЕ capability `SYS_ADMIN`, но `seccompProfile.type: Unconfined` - если забыть указать `Unconfined` явно, Pod может получить `RuntimeDefault` по умолчанию (если включён `seccompDefault` из задания 7) и тест не покажет разницу.
</details>

Linux capabilities и privilege escalation — разные оси. `allowPrivilegeEscalation: false`
включает `no_new_privs` и запрещает получать **новые** права через `execve` (setuid/setgid и
file capabilities), но не удаляет `SYS_ADMIN`, уже добавленную в bounding/effective set.
Для обычной рабочей нагрузки используйте `capabilities.drop: ["ALL"]` и отдельно
`allowPrivilegeEscalation: false`; эксперимент выше намеренно не является таким baseline.

---
| **6** | **User namespaces: `hostUsers: false` и трансляция UID через `uid_map`** |
| :---: | :--- |
| Что делаем | User namespaces GA в Kubernetes v1.36 (см. [главу 03](../../course/03/ru.md), [главу 18](../../course/18/ru.md) и Security Delta v1.36). Теория объясняет, что `hostUsers: false` транслирует root контейнера в непривилегированный host UID; здесь нужно это доказать на живом процессе. Создайте в `security-106` Pod `userns-probe` на подготовленной ноде с `spec.hostUsers: false`, образом `busybox:1.36`, командой `sleep 3600`; не задавайте Pod-level `runAsUser`, чтобы процесс стартовал как UID 0 **внутри** контейнера. Подтвердите `id` внутри контейнера (`uid=0`). Определите host PID процесса контейнера через `crictl inspect` (по аналогии с лабой 112) или через `kubectl get pod -o jsonpath` + `crictl ps`, затем на ноде прочитайте `/proc/<host PID>/uid_map`. Сохраните оба вывода (`id` внутри контейнера и содержимое `uid_map`) в `/var/work/tests/artifacts/6/userns.txt`. |
| Критерии приёмки | Pod `Running`, `spec.hostUsers == false`, выбирает подготовленную ноду; `id` внутри контейнера показывает `uid=0(root)`; `/proc/<host PID>/uid_map` на ноде содержит строку вида `0 <host-uid> <length>`, где `<host-uid>` **не равен 0** (root контейнера транслирован в непривилегированный host UID) и `<length>` равен как минимум `65536` (стандартный per-Pod диапазон UID); артефакт содержит обе части evidence. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

`id` ВНУТРИ контейнера будет показывать `uid=0(root)` независимо от `hostUsers` - это ожидаемо, контейнер видит СВОЙ собственный namespace, где его root - действительно UID 0 в этом namespace. Реальная защита видна только СНАРУЖИ: на самой ноде, в `/proc/<host PID>/uid_map`, где UID 0 внутри контейнера транслируется в какой-то большой непривилегированный UID на хосте. Чтобы найти host PID, используйте `crictl inspect <container-id>` - именно оттуда, а не `kubectl get pod`, который знает только про Kubernetes-объект, а не про host-level PID процесса.
</details>

---
| **7** | **`seccompDefault: true` на уровне kubelet: baseline без явного профиля** |
| :---: | :--- |
| Что делаем | Все Pod в заданиях 3–5 явно указывают `seccompProfile` в манифесте. В реальности разработчик может забыть это поле — тогда без node-level baseline Pod получает `Unconfined`. На ноде включите `seccompDefault: true` в `/var/lib/kubelet/config.yaml` и перезапустите kubelet (`systemctl restart kubelet`). Создайте Pod `no-seccomp-field` в `security-106` на подготовленной ноде из `busybox:1.36` (`sleep 3600`), **не указывая securityContext.seccompProfile вообще** ни на уровне Pod, ни на уровне контейнера. Через `/proc/1/status` внутри контейнера подтвердите, что kubelet применил `RuntimeDefault` автоматически (`Seccomp: 2`), а не оставил `Unconfined` (`Seccomp: 0`). |
| Критерии приёмки | `/var/lib/kubelet/config.yaml` содержит `seccompDefault: true`; `systemctl is-active kubelet` возвращает `active`, нода остаётся `Ready`; Pod `no-seccomp-field` не имеет `seccompProfile` ни на одном уровне своей спецификации; `/proc/1/status` внутри контейнера показывает `Seccomp: 2`. |

<details>
<summary>💡 Подсказка к заданию 7</summary>

Ключевое требование - Pod ДЕЙСТВИТЕЛЬНО не должен упоминать `seccompProfile` вообще, ни на уровне Pod, ни на уровне контейнера. Если вы скопируете манифест из задания 3 и просто забудете удалить это поле - тест не докажет то, что должен: что именно node-level `seccompDefault` (а не явное указание в манифесте) обеспечило `Seccomp: 2`.
</details>

---
| **8** | **Отладка и пересборка сломанного AppArmor-профиля (`apparmor_parser -r -v`)** |
| :---: | :--- |
| Что делаем | На диске уже лежит `/etc/apparmor.d/k8s-106-broken-profile` — профиль с синтаксической ошибкой (пропущена запятая после правила `deny /work/** w`), который **никогда не был загружен** в ядро. Найдите ошибку через `apparmor_parser -p /etc/apparmor.d/k8s-106-broken-profile` (либо `apparmor_parser -r -v`, который также покажет syntax error при попытке загрузки), исправьте файл и загрузите профиль в ядро через `sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile`. Подтвердите загрузку через `aa-status \| grep k8s-106-broken-profile`. Сохраните вывод ошибки **до** исправления и подтверждение загрузки **после** в `/var/work/tests/artifacts/8/apparmor-debug.txt`. |
| Критерии приёмки | `apparmor-debug.txt` содержит текст ошибки парсера (например, `syntax error`) из попытки **до** исправления; `/etc/apparmor.d/k8s-106-broken-profile` на диске больше не содержит исходную синтаксическую ошибку; `aa-status` показывает `k8s-106-broken-profile` среди загруженных профилей (в любом режиме - `enforce` или `complain`); повторный `apparmor_parser -p` на исправленном файле завершается без ошибки. |

<details>
<summary>💡 Подсказка к заданию 8</summary>

`apparmor_parser -p` (dry-run, "parse only") не загружает профиль в ядро - используйте его сначала, чтобы БЕЗОПАСНО найти синтаксическую ошибку без побочных эффектов. Только после исправления файла используйте `-r` (reload/load) для реальной загрузки в ядро. Ошибка в этом профиле - пропущенная запятая после `deny /work/** w` перед следующим правилом; AppArmor-синтаксис требует запятую как разделитель правил внутри блока.
</details>

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и восемь независимых тестов. Она читает state Pod через API, проверяет
profile на ноде по SSH и выполняет контролируемые отрицательные сценарии. Если Localhost
Pod не создаётся, сначала посмотрите `kubectl describe pod`: обычная причина — абсолютный
путь вместо относительного или назначение Pod на ноду без profile.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=106 make delete_cks_task
```
