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

Bootstrap подготовил **только**:

- label ноды `security.cks.io/localhost-profiles-106=true` для безопасного placement;
- на рабочей машине (worker), в `/opt/lab106-fixtures/`: исходники `k8s-106-deny-write`
  (AppArmor profile) и `cks-106-deny-unshare.json` (custom seccomp profile).

Ни AppArmor profile, ни seccomp profile **не** предустановлены на workload-ноде и не
загружены в её ядро — перенос и первичная загрузка каждого из них - часть заданий 1 и 5.
Не меняйте путь seccomp profile и не создавайте profile внутри обычного Pod: перенос
файлов на ноду выполняется вами как администратором ноды через SSH, а не изнутри workload.

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

Проверьте нодовый доступ и worker-side fixtures до начала работы:

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ls -la /opt/lab106-fixtures/
```

## Задания

---
| **1** | **Перенести и загрузить AppArmor profile** |
| :---: | :--- |
| Что делаем | Исходник profile `k8s-106-deny-write` лежит только на рабочей машине, в `/opt/lab106-fixtures/k8s-106-deny-write`. Скопируйте его на ноду `control-plane` в `/etc/apparmor.d/k8s-106-deny-write` (например, через `scp`) и загрузите в ядро через `sudo apparmor_parser -r`. Profile уже содержит флаг `complain` — второй раз включать его не нужно, это задача задания 2. |
| Критерии приёмки | `/etc/apparmor.d/k8s-106-deny-write` присутствует на ноде; `/sys/kernel/security/apparmor/profiles` содержит строку с именем `k8s-106-deny-write` (в любом режиме — `complain` или `enforce`), то есть profile реально загружен в ядро, а не просто скопирован на диск. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

`scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/` копирует файл на ноду
во временный каталог; переместите его оттуда с `sudo` в `/etc/apparmor.d/` (обычный
пользователь не имеет прав записи туда напрямую). Затем `sudo apparmor_parser -r
/etc/apparmor.d/k8s-106-deny-write` компилирует и загружает profile в ядро — без этого
шага файл на диске не даёт вообще никакой защиты и не появится в
`/sys/kernel/security/apparmor/profiles`.
</details>

---
| **2** | **Перевести AppArmor profile в enforce** |
| :---: | :--- |
| Что делаем | На ноде `control-plane` переведите загруженный в задании 1 profile `k8s-106-deny-write` в режим `enforce`. Исходный режим `complain` записывает нарушения, но не является защитой. Не удаляйте profile и не меняйте его имя. |
| Критерии приёмки | Нода с label `security.cks.io/localhost-profiles-106=true` существует; `/etc/apparmor.d/k8s-106-deny-write` доступен; `/sys/kernel/security/apparmor/profiles` содержит строку `k8s-106-deny-write (enforce)`. Checker-owned bootstrap-baseline (зафиксирован ДО выдачи лабы, на транзитной копии этого же profile, пока она была ещё в `complain`) подтверждает, что запись, соответствующая паттерну `/work/**` этого profile, тогда действительно проходила - без этого нельзя доказать, что именно переход в `enforce` вызвал последующий отказ. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Команда `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` перезагружает уже существующий профиль - если он был в `complain`, а файл на диске уже описывает `enforce`, этой команды достаточно. Проверьте себя через `sudo cat /sys/kernel/security/apparmor/profiles | grep k8s-106-deny-write` - вывод должен явно показывать `(enforce)`. Не проверяйте это через `aa-status`: эта команда группирует профили под заголовками секций (`N profiles are in enforce mode.`) и печатает под ними только голые имена профилей, БЕЗ суффикса `(enforce)`/`(complain)` у каждой строки - такой суффикс есть только в `/proc/<pid>/attr/current` и в файле ядра `/sys/kernel/security/apparmor/profiles`, а не в списке профилей `aa-status`.

Не используйте `aa-enforce`/`aa-complain` для этого профиля, пока не выполнено задание 9:
эти Python-инструменты из `apparmor-utils` перед своей основной работой разбирают
(парсят) **все** файлы в `/etc/apparmor.d/`, включая ещё сломанный `k8s-106-broken-profile`
из задания 8, и падают с ошибкой парсера на чужом файле. Правьте флаг `complain` в файле
профиля напрямую (`sed`) и перезагружайте именно ЭТОТ файл через `apparmor_parser -r` -
этот бинарник, в отличие от `aa-enforce`, разбирает только переданный ему файл.
</details>

---
| **3** | **Localhost AppArmor Pod и блокировка записи** |
| :---: | :--- |
| Что делаем | Создайте namespace `security-106` и Pod `apparmor-writer`. Pod должен выбрать label ноды из инфраструктуры, отключить automount ServiceAccount token и на уровне Pod задать `appArmorProfile.type: Localhost`, `localhostProfile: k8s-106-deny-write`. Используйте `busybox:1.36`, контейнер `app`, команду сна `sleep 3600` и `emptyDir`, смонтированный в `/work`. После запуска подтвердите эффективный profile командой `cat /proc/1/attr/current` (если интерфейс доступен), выполните разрешённую операцию чтения, например `cat /etc/hostname >/dev/null`, и затем попытайтесь записать файл в `/work`; операция обязана завершиться отказом. На ноде зафиксируйте AppArmor denial для profile/process из `journalctl -k | grep -i apparmor` либо `dmesg | grep -i apparmor`. |
| Критерии приёмки | Pod запущен, использует именно Localhost profile и правильный nodeSelector; effective profile процесса показывает `k8s-106-deny-write` в enforce mode (когда `/proc/.../attr/current` доступен); разрешённая операция чтения в `/work` проходит, а checker independently пишет свой собственный уникальный (per-run) файл в `/work` и получает AppArmor-отказ. В kernel journal/audit log есть относящееся именно к ЭТОЙ попытке (по уникальному имени файла) событие `apparmor="DENIED"` с этим profile - это исключает false pass от устаревшего denial-события в журнале. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

`appArmorProfile` для профиля с типом `Localhost` указывается через два отдельных поля: `type: Localhost` и `localhostProfile: k8s-106-deny-write` (имя профиля БЕЗ пути `/etc/apparmor.d/`) - это то же имя, под которым профиль был загружен в задании 1. Если Pod не запускается (CreateContainerError), проверьте, что profile действительно уже загружен на НУЖНОЙ ноде через nodeSelector - AppArmor-профили node-local, они не переносятся автоматически.
</details>

---
| **4** | **Безопасный baseline seccomp RuntimeDefault** |
| :---: | :--- |
| Что делаем | Создайте в `security-106` Pod `runtime-default` с `busybox:1.36` и `sleep 3600`. На уровне Pod явно укажите `securityContext.seccompProfile.type: RuntimeDefault`; Pod также должен выбрать подготовленную ноду. Проверьте в контейнере `/proc/1/status`: ожидается `Seccomp: 2`. |
| Критерии приёмки | Pod `Running`, в его Pod-level securityContext выбран `RuntimeDefault`, а процесс находится в seccomp filter mode. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

`Seccomp: 2` в `/proc/1/status` означает "filter mode активен" (SECCOMP_MODE_FILTER) - это то, что вы должны увидеть. `Seccomp: 0` означало бы отсутствие seccomp filter вообще (`Unconfined`). Это самое простое задание из пяти в этой группе - если оно не проходит, скорее всего проблема в nodeSelector, а не в самом seccompProfile.
</details>

---
| **5** | **Перенести и использовать custom Localhost seccomp profile** |
| :---: | :--- |
| Что делаем | Исходник `cks-106-deny-unshare.json` лежит только на рабочей машине, в `/opt/lab106-fixtures/cks-106-deny-unshare.json`. Определите ноду с label `security.cks.io/localhost-profiles-106=true`, создайте на ней каталог `/var/lib/kubelet/seccomp/profiles/` (если его ещё нет) и скопируйте туда JSON под тем же именем. Затем создайте Pod `localhost-seccomp` в `security-106` на этой ноде. На уровне Pod укажите `seccompProfile.type: Localhost` и относительный путь `profiles/cks-106-deny-unshare.json` — без `/var/lib/kubelet/seccomp/`. Контейнер `app` должен использовать `busybox:1.36`, получить capability `SYS_ADMIN` и остаться запущенным после проверки. **Не выдавайте эту комбинацию за hardened baseline:** `SYS_ADMIN` остаётся одной из самых опасных capabilities, а `allowPrivilegeEscalation: false` не отнимает уже выданные права. Это capability-focused experiment, где безопасность показывает конкретный seccomp deny. |
| Критерии приёмки | JSON profile перенесён и существует на ноде по правильному пути; Pod с правильным nodeSelector использует profile `Localhost:profiles/cks-106-deny-unshare.json`; JSON profile содержит `SCMP_ACT_ERRNO`/`errnoRet: 1` для `unshare`; в контейнере добавлен только требуемый для эксперимента `SYS_ADMIN`. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Путь `profiles/cks-106-deny-unshare.json` - относительный к kubelet seccomp root `/var/lib/kubelet/seccomp/`, то есть реальный файл на ноде должен лежать по адресу `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json` - именно туда его нужно скопировать с рабочей машины (например, `scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/`, затем `sudo mkdir -p` и `sudo mv` на ноде). Не пишите в манифесте полный абсолютный путь - kubelet сам добавит корень. `SYS_ADMIN` даётся здесь ИМЕННО для эксперимента (нужна capability, позволяющая в принципе вызвать `unshare`), а не как рекомендуемая практика - не путайте учебный сценарий с production baseline.
</details>

---
| **6** | **Доказать отказ syscall `unshare(2)`** |
| :---: | :--- |
| Что делаем | В команде контейнера `localhost-seccomp` выполните `unshare -n true`, сохраните успешное подтверждение ожидаемого отказа в `/tmp/unshare-result` как строку `unshare denied by seccomp`, затем удерживайте контейнер через `sleep 3600`. Повторная команда `kubectl exec ... -- unshare -n true` должна вернуть ненулевой код. Для attack-minded negative control создайте Pod `sysadmin-control` на той же ноде с `seccompProfile.type: Unconfined` и той же единственной capability `SYS_ADMIN`; его `unshare -n true` должен завершиться успешно. Удалите control Pod после проверки. |
| Критерии приёмки | Localhost Pod запущен; `Seccomp: 2`; `unshare` блокируется custom profile. В control Pod тот же syscall с той же capability и без seccomp filter проходит. Это доказывает kernel behavior, а не только наличие YAML. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

Используйте именно `unshare -n true` (unshare network namespace, `CLONE_NEWNET`), а НЕ
`unshare -m true`. `-m` (mount namespace) требует `CAP_SYS_ADMIN` так же, как и `-n`, но
BusyBox `unshare -m` после успешного `unshare(2)` дополнительно выполняет ВТОРОЙ,
самостоятельный `mount(2)` syscall (`mount("none", "/", NULL, MS_REC|MS_PRIVATE, NULL)`
для принудительной private propagation - это поведение unshare, активное по умолчанию,
если явно не передан `--propagation unchanged`, и даже тогда `mount()` всё равно
вызывается, просто с нулевыми флагами). containerd's default AppArmor-профиль (`RuntimeDefault`,
который получает Pod без явного `securityContext.appArmorProfile`) содержит `deny mount,`
БЕЗ каких-либо условий на флаги - этот запрет действует независимо от capabilities и от
seccomp. Поэтому `unshare -m true` может провалиться с `EPERM` из-за AppArmor ДАЖЕ когда
seccomp вообще не ограничивает `unshare`, что делает такой probe ненадёжным доказательством
именно seccomp-отказа. `unshare -n` (`CLONE_NEWNET`) вызывает ТОЛЬКО сам syscall
`unshare(2)` без какого-либо последующего `mount()` - и `localhost-seccomp`, и
`sysadmin-control` используют один и тот же `SYS_ADMIN`, поэтому разница в результате
однозначно объясняется именно seccomp filter, а не побочным эффектом AppArmor.

Порядок команд важен для доказательности: сначала выполните `unshare -n true` и убедитесь, что он падает с ошибкой (ненулевой exit code), ТОЛЬКО ПОТОМ запишите строку `unshare denied by seccomp` в `/tmp/unshare-result` - не пишите строку заранее, "предполагая" результат. Negative control (`sysadmin-control`) должен использовать ТУ ЖЕ capability `SYS_ADMIN`, но `seccompProfile.type: Unconfined` - если забыть указать `Unconfined` явно, Pod может получить `RuntimeDefault` по умолчанию (если включён `seccompDefault` из задания 8) и тест не покажет разницу.
</details>

Linux capabilities и privilege escalation — разные оси. `allowPrivilegeEscalation: false`
включает `no_new_privs` и запрещает получать **новые** права через `execve` (setuid/setgid и
file capabilities), но не удаляет `SYS_ADMIN`, уже добавленную в bounding/effective set.
Для обычной рабочей нагрузки используйте `capabilities.drop: ["ALL"]` и отдельно
`allowPrivilegeEscalation: false`; эксперимент выше намеренно не является таким baseline.

---
| **7** | **User namespaces: `hostUsers: false` и трансляция UID через `uid_map`** |
| :---: | :--- |
| Что делаем | User namespaces GA в Kubernetes v1.36 (см. [главу 03](../../course/03/ru.md), [главу 18](../../course/18/ru.md) и Security Delta v1.36). Теория объясняет, что `hostUsers: false` транслирует root контейнера в непривилегированный host UID; здесь нужно это доказать на живом процессе. Создайте в `security-106` Pod `userns-probe` на подготовленной ноде с `spec.hostUsers: false`, образом `busybox:1.36`, командой `sleep 3600`; не задавайте Pod-level `runAsUser`, чтобы процесс стартовал как UID 0 **внутри** контейнера. Подтвердите `id` внутри контейнера (`uid=0`). Определите host PID процесса контейнера через `crictl inspect` (по аналогии с лабой 112) или через `kubectl get pod -o jsonpath` + `crictl ps`, затем на ноде прочитайте `/proc/<host PID>/uid_map`. Сохраните оба вывода (`id` внутри контейнера и содержимое `uid_map`) в `/var/work/tests/artifacts/6/userns.txt`. |
| Критерии приёмки | Pod `Running`, `spec.hostUsers == false`, выбирает подготовленную ноду; `id` внутри контейнера показывает `uid=0(root)`; `/proc/<host PID>/uid_map` на ноде содержит строку вида `0 <host-uid> <length>`, где `<host-uid>` **не равен 0** (root контейнера транслирован в непривилегированный host UID) и `<length>` равен как минимум `65536` (стандартный per-Pod диапазон UID); артефакт содержит обе части evidence. |

<details>
<summary>💡 Подсказка к заданию 7</summary>

`id` ВНУТРИ контейнера будет показывать `uid=0(root)` независимо от `hostUsers` - это ожидаемо, контейнер видит СВОЙ собственный namespace, где его root - действительно UID 0 в этом namespace. Реальная защита видна только СНАРУЖИ: на самой ноде, в `/proc/<host PID>/uid_map`, где UID 0 внутри контейнера транслируется в какой-то большой непривилегированный UID на хосте. Чтобы найти host PID, используйте `crictl inspect <container-id>` - именно оттуда, а не `kubectl get pod`, который знает только про Kubernetes-объект, а не про host-level PID процесса.
</details>

---
| **8** | **`seccompDefault: true` на уровне kubelet: baseline без явного профиля** |
| :---: | :--- |
| Что делаем | Все Pod в заданиях 4–6 явно указывают `seccompProfile` в манифесте. В реальности разработчик может забыть это поле — тогда без node-level baseline Pod получает `Unconfined`. На ноде включите `seccompDefault: true` в `/var/lib/kubelet/config.yaml` и перезапустите kubelet (`systemctl restart kubelet`). Создайте Pod `no-seccomp-field` в `security-106` на подготовленной ноде из `busybox:1.36` (`sleep 3600`), **не указывая securityContext.seccompProfile вообще** ни на уровне Pod, ни на уровне контейнера. Через `/proc/1/status` внутри контейнера подтвердите, что kubelet применил `RuntimeDefault` автоматически (`Seccomp: 2`), а не оставил `Unconfined` (`Seccomp: 0`). |
| Критерии приёмки | Эффективная (применённая) конфигурация kubelet - через `/api/v1/nodes/<node>/proxy/configz`, поле `.kubeletconfig.seccompDefault` - равна `true`; `systemctl is-active kubelet` возвращает `active`, нода остаётся `Ready`; Pod `no-seccomp-field` не имеет `seccompProfile` ни на одном уровне своей спецификации; `/proc/1/status` внутри контейнера показывает `Seccomp: 2`. |

<details>
<summary>💡 Подсказка к заданию 8</summary>

Ключевое требование - Pod ДЕЙСТВИТЕЛЬНО не должен упоминать `seccompProfile` вообще, ни на уровне Pod, ни на уровне контейнера. Если вы скопируете манифест из задания 3 и просто забудете удалить это поле - тест не докажет то, что должен: что именно node-level `seccompDefault` (а не явное указание в манифесте) обеспечило `Seccomp: 2`.

Проверка ориентируется на РЕАЛЬНО ПРИМЕНЁННУЮ конфигурацию kubelet, а не на текст файла на
диске: `curl`/`kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq .kubeletconfig.seccompDefault`.
Простой grep по `/var/lib/kubelet/config.yaml` не доказывает, что именно этот файл
использует запущенный kubelet - командный флаг или drop-in могли бы переопределить
значение без изменения самого файла. Обязательно перезапустите kubelet после правки
файла - конфигурация не подхватывается на лету.
</details>

---
| **9** | **Отладка и пересборка сломанного AppArmor-профиля (`apparmor_parser -r -v`)** |
| :---: | :--- |
| Что делаем | На диске уже лежит `/etc/apparmor.d/k8s-106-broken-profile` — профиль с синтаксической ошибкой, который **никогда не был загружен** в ядро. Найдите ошибку самостоятельно через `sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile` (`-Q`/`--skip-kernel-load`: полностью выполняет проверку/компиляцию профиля, но не загружает его в ядро) или `sudo apparmor_parser -d /etc/apparmor.d/k8s-106-broken-profile` (`-d`/`--debug`, однократно - только проверка синтаксической корректности), исправьте файл и загрузите профиль в ядро через `sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile`. Подтвердите загрузку через `aa-status \| grep k8s-106-broken-profile`. Сохраните вывод ошибки **до** исправления и подтверждение загрузки **после** в `/var/work/tests/artifacts/8/apparmor-debug.txt`. |
| Критерии приёмки | `apparmor-debug.txt` содержит текст ошибки парсера (например, `syntax error`) из попытки **до** исправления; checker-owned bootstrap-baseline (зафиксирован ДО выдачи лабы, независимо от вашего artifact) независимо подтверждает, что исходный профиль действительно содержал syntax error; `/etc/apparmor.d/k8s-106-broken-profile` на диске больше не содержит исходную синтаксическую ошибку; `aa-status` показывает `k8s-106-broken-profile` среди загруженных профилей (в любом режиме - `enforce` или `complain`); повторный `apparmor_parser -Q` на исправленном файле завершается без ошибки. |

<details>
<summary>💡 Подсказка к заданию 9</summary>

`apparmor_parser -p` (`--preprocess`) НЕ является safe dry-run/syntax-check режимом - это
всего лишь preprocessing: разворачивает `#include` директивы и печатает получившийся
профиль в stdout, само по себе не гарантируя отсутствие побочных эффектов и не будучи
предназначенным именно для проверки синтаксиса. Используйте `-Q`/`--skip-kernel-load`
(выполняет полную компиляцию/проверку, но не загружает в ядро) или `-d`/`--debug`
(однократно - только проверка синтаксической корректности), чтобы БЕЗОПАСНО найти
синтаксическую ошибку без побочных эффектов. Только после исправления файла используйте
`-r` (reload/load) для реальной загрузки в ядро. AppArmor-синтаксис требует запятую как
разделитель правил внутри блока - изучите вывод парсера, чтобы найти, какого символа не
хватает и где именно.

Всегда запускайте `apparmor_parser`, даже с `-Q`/`-d`, через `sudo` - несмотря на то, что
эти режимы не загружают профиль в ЯДРО, сам парсер при каждом запуске всё равно пытается
настроить policy cache в `/var/cache/apparmor`. Без привилегий это падает с "Failed
setting up policy cache: Permission denied" ДО проверки синтаксиса, и вы получите
обманчивую ошибку о правах вместо реальной синтаксической ошибки профиля.
</details>

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и девять независимых тестов. Она читает state Pod через API, проверяет
profile на ноде по SSH и выполняет контролируемые отрицательные сценарии. Если Localhost
Pod не создаётся, сначала посмотрите `kubectl describe pod`: обычная причина — абсолютный
путь вместо относительного или назначение Pod на ноду без profile.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=106 make delete_cks_task
```
