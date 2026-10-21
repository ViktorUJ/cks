[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 106 - эталонное решение: AppArmor и seccomp

> Kubernetes-команды (`kubectl`) выполняйте на рабочей машине (`worker`). Всё, что касается
> самой ноды (AppArmor, kubelet, `crictl`), делайте **прямо на ноде**: зайдите по `ssh` один
> раз и станьте root (`sudo -i`) - это быстрее, чем отправлять каждую команду отдельным
> `ssh control-plane '...'`, и именно так нужно работать на экзамене. Namespace
> `security-106` создаётся в задании 3.
>
> ```bash
> ssh control-plane
> sudo -i
> # ... команды на ноде ...
> exit   # из root
> exit   # с ноды обратно на worker
> ```
>
> Артефакты проверка читает с **рабочей машины** (`/var/work/tests/artifacts/<номер>/`), они
> нужны только для лабы - на экзамене их нет. Сохраняем их короткой командой с `worker`
> (`> файл`), содержимое смотрим отдельно через `cat <файл>`.

## 1. Перенос и загрузка AppArmor profile

Профиль лежит только на рабочей машине. Копируем его на ноду (с `worker`), затем на ноде
кладём на место и загружаем в ядро. Файл уже содержит флаг `complain`, поэтому одного
`apparmor_parser -r` достаточно для первичной загрузки (без `aa-complain`, который, как и
`aa-enforce`, парсит все файлы в `/etc/apparmor.d/` и упал бы на ещё сломанном
`k8s-106-broken-profile` из задания 9):

```bash
# на worker
scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/k8s-106-deny-write

# на ноде
ssh control-plane
sudo -i
mv /tmp/k8s-106-deny-write /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# ожидается: "k8s-106-deny-write":	"complain",
```

## 2. Перевод AppArmor profile в enforce

Profile сейчас в режиме `complain` (загружен с этим флагом в задании 1). Остаёмся на ноде
(под root) и переводим именно существующий profile в enforcing mode:

```bash
sed -i 's/, complain,/,/' /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# ожидается: "k8s-106-deny-write":	"enforce",
# Обычный 'aa-status | grep ...' режим профиля не покажет: в текстовом выводе профили
# сгруппированы под заголовками ('N profiles are in enforce mode.'), имена идут без суффикса.
# Для проверки конкретного профиля используйте 'aa-status --pretty-json' (или '--json').
exit
exit
```

Не используйте `aa-enforce`/`aa-complain` и другие инструменты изменения профилей из
пакета `apparmor-utils`, написанные на Python, для ЭТОГО профиля, пока не выполнено
задание 9: они внутри вызывают `apparmor.read_profiles()`, который при старте разбирает
(парсит) **все** файлы в `/etc/apparmor.d/`, включая ещё не загруженный и заведомо
сломанный `/etc/apparmor.d/k8s-106-broken-profile` из задания 9 - и падают с ошибкой
парсера на ЧУЖОМ файле, даже не пытаясь дойти до вашего профиля. `apparmor_parser`
(бинарник, а не Python-обёртка), вызванный напрямую с ОДНИМ конкретным файлом, разбирает
только его и не подвержен этой проблеме - именно поэтому мы правим флаг профиля
(убираем `complain` из `flags=(...)`) вручную через `sed`, а затем перезагружаем именно
этот файл через `apparmor_parser -r`.

`aa-status` - отдельный инструмент просмотра состояния, а не изменения профилей, и сюда он
не относится. Режим конкретного профиля показывает `aa-status --pretty-json` (проверено на
ноде лабы, apparmor 3.0.4; `--json` даёт то же в одну строку, например
`aa-status --json | jq -r '.profiles["k8s-106-deny-write"]'`). Альтернатива - файл ядра
`grep -F 'k8s-106-deny-write' /sys/kernel/security/apparmor/profiles`: там формат
`name (enforce|complain)`.

## 3. Pod с Localhost AppArmor и отказом записи

Создадим namespace и Pod. `emptyDir` гарантирует наличие `/work`; profile разрешает
запуск процесса, но запрещает запись в этом каталоге. Node selector связывает Pod с
нодой, на которой profile действительно загружен.

```yaml
# apparmor-writer.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security-106
---
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-writer
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-106-deny-write
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

```bash
# на worker
kubectl apply -f apparmor-writer.yaml
kubectl get pod -n security-106 apparmor-writer
# дождитесь STATUS Running (повторите get), затем выполняйте exec

# Evidence: профиль действительно назначен процессу PID 1, а не только записан в Pod YAML.
kubectl exec -n security-106 apparmor-writer -- cat /proc/1/attr/current
# k8s-106-deny-write (enforce)

# Положительный контроль ДО отказа: разрешённая read-операция именно на том же /work,
# где будет проверяться denial - без этого шага отказ записи было бы невозможно отличить
# от полностью неработающего mount/mountPath (в этом случае даже чтение было бы недоступно).
kubectl exec -n security-106 apparmor-writer -- sh -c 'ls /work'

# Отрицательный контроль: denial должен быть именно отказом записи AppArmor.
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# ожидается ненулевой код: Permission denied / Operation not permitted
```

Ненулевой exit code и текст 'permission denied' сами по себе НЕ доказывают, что именно
AppArmor это правило сработало - обычная DAC/filesystem ошибка выглядела бы идентично с
точки зрения shell. Свяжите отказ именно с этим profile через kernel audit log; смотрим его
на ноде сразу после попытки выше:

```bash
# на ноде
ssh control-plane
sudo -i
journalctl -k --no-pager -n 500 | grep -F 'apparmor="DENIED"' | grep -F 'profile="k8s-106-deny-write"' | grep -F 'cks-106-denied.txt'
# ожидается запись вида: ... apparmor="DENIED" ... profile="k8s-106-deny-write" name=".../cks-106-denied.txt" ... denied_mask="c" ... (mknod: создание файла; при записи в существующий файл будет "w")
exit
exit
```

Если `/proc/1/attr/current` недоступен в конкретном runtime, зафиксируйте это и опирайтесь
на назначение Localhost profile вместе с kernel `apparmor="DENIED"` для данного profile;
один ненулевой код без этих evidence недостаточен, так как его может дать mount или обычное
Unix permission.

## 4. RuntimeDefault для обычного Pod

`RuntimeDefault` - переносимый baseline, который выбирает стандартный профиль
containerd/runtime. Поле задано явно на уровне Pod.

```yaml
# runtime-default.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
# на worker
kubectl apply -f runtime-default.yaml
kubectl get pod -n security-106 runtime-default
kubectl exec -n security-106 runtime-default -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2
```

## 5–6. Localhost seccomp и доказательство блокировки `unshare`

Файл лежит только на рабочей машине, в `/opt/lab106-fixtures/cks-106-deny-unshare.json`.
Копируем его на ноду (с `worker`) и кладём в kubelet seccomp root (на ноде):

```bash
# на worker
scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/cks-106-deny-unshare.json

# на ноде
ssh control-plane
sudo -i
mkdir -p /var/lib/kubelet/seccomp/profiles
mv /tmp/cks-106-deny-unshare.json /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json
jq empty /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json && echo valid
exit
exit
```

В API указываем путь относительно seccomp root: `profiles/cks-106-deny-unshare.json`.

`SYS_ADMIN` здесь - намеренное опасное исключение только для лабы (проверку control без seccomp делает checker). Без custom
filter `unshare -n` с этой capability может сработать; seccomp должен вернуть `EPERM`.
Это не hardened combination. `allowPrivilegeEscalation: false` включает `no_new_privs`, но
не отнимает capabilities, уже выданные процессу, поэтому мы не используем это поле как
«компенсацию» для `SYS_ADMIN`. В production такую capability удаляют, если нет доказанной
необходимости. В Kubernetes capability записывается как `SYS_ADMIN`, без префикса `CAP_`.

Используем `unshare -n` (network namespace, `CLONE_NEWNET`), а НЕ `unshare -m` (mount
namespace). Обе операции требуют одну и ту же `CAP_SYS_ADMIN`, но BusyBox `unshare -m`
после успешного `unshare(2)` дополнительно выполняет самостоятельный `mount(2)` syscall
для forced private propagation - а containerd default AppArmor-профиль (`RuntimeDefault`,
который получает этот Pod, так как явный `appArmorProfile` здесь не задан) содержит
`deny mount,` без каких-либо условий на флаги, независимо от capabilities/seccomp. Поэтому
`unshare -m true` может провалиться с `EPERM` из-за AppArmor, даже если seccomp вообще не
ограничивает `unshare` - такой probe смешивал бы две разные security control. `unshare -n`
вызывает только сам syscall `unshare(2)`, без побочного `mount()`.

```yaml
# localhost-seccomp.yaml
apiVersion: v1
kind: Pod
metadata:
  name: localhost-seccomp
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/cks-106-deny-unshare.json
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      if unshare -n true 2>/tmp/unshare.err; then
        echo 'unshare unexpectedly succeeded' >/tmp/unshare-result
        exit 1
      fi
      grep -Eqi 'operation not permitted|permission denied' /tmp/unshare.err
      echo 'unshare denied by seccomp' >/tmp/unshare-result
      exec sleep 3600
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
```

```bash
# на worker
kubectl apply -f localhost-seccomp.yaml
kubectl get pod -n security-106 localhost-seccomp
kubectl exec -n security-106 localhost-seccomp -- cat /tmp/unshare-result
# unshare denied by seccomp

kubectl exec -n security-106 localhost-seccomp -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2

kubectl exec -n security-106 localhost-seccomp -- unshare -n true
# ожидается ненулевой код: Operation not permitted / Permission denied
```

## 7. User namespaces: `hostUsers: false` и `uid_map`

`hostUsers: false` просит kubelet выделить Pod отдельный user namespace: root (UID 0)
внутри контейнера отображается на непривилегированный диапазон UID хоста. Не задаём
`runAsUser`, чтобы процесс реально стартовал как UID 0 **внутри** namespace - именно этот
случай показывает трансляцию, а не отсутствие привилегий с самого начала.

```yaml
# userns-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: userns-probe
  namespace: security-106
spec:
  hostUsers: false
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# на worker
kubectl apply -f userns-probe.yaml
kubectl get pod -n security-106 userns-probe
mkdir -p /var/work/tests/artifacts/6

kubectl exec -n security-106 userns-probe -- id > /var/work/tests/artifacts/6/userns.txt
cat /var/work/tests/artifacts/6/userns.txt
# uid=0(root) gid=0(root) groups=0(root)
```

Host PID контейнера не совпадает ни с PID внутри контейнера, ни виден напрямую через
`kubectl`. Берём ID контейнера на worker, а PID получаем через `crictl inspect` на ноде,
где реально запущен Pod:

```bash
# на worker
kubectl get pod userns-probe -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}'
# containerd://<ID> - скопируйте <ID> без префикса containerd://

# на ноде
ssh control-plane
sudo -i
crictl inspect <ID> | jq -r '.info.pid'
# например: 15205 - это <host PID>
```

`/proc/<host PID>/uid_map` на ноде описывает трансляцию: три числа - `<container-uid-start>
<host-uid-start> <length>`. Для `hostUsers: false` первая строка должна начинаться с `0`
(container UID 0), но host-uid-start обязан быть **не нулевым** - это и есть
непривилегированный диапазон хоста, а `length` - стандартный per-Pod блок `65536` UID.

```bash
# на ноде (под root)
cat /proc/<host PID>/uid_map
# 0 1349844992 65536   (host-uid-start на каждом Pod свой, главное - не 0)
exit
exit
```

Сохраняем строку `uid_map` в артефакт (на `worker`):

```bash
ssh control-plane "sudo cat /proc/<host PID>/uid_map" >> /var/work/tests/artifacts/6/userns.txt
```

Если `host-uid-start` равен `0` - user namespace не применился (например, из-за
несовместимого containerd/runc или отсутствия `hostUsers: false` в реально применённом
Pod) - это не hardening, а обычный root на хосте. Для сравнения: у обычного Pod без
`hostUsers: false` файл `/proc/<host-PID>/uid_map` тоже существует, но процесс остаётся в
host (initial) user namespace. Поэтому mapping начинается с UID 0 -> host UID 0 (обычно
строка вида `0 0 4294967295`, например `cat /proc/1/uid_map` на ноде), а не с
непривилегированного per-Pod host UID. У `userns-probe` с `hostUsers: false` ожидаем
противоположное: `0 <ненулевой-host-uid> <диапазон-per-pod>`.

## 8. `seccompDefault: true` на kubelet

Все предыдущие Pod явно задавали `seccompProfile`. Здесь проверяем node-level baseline:
если разработчик забудет это поле, kubelet должен сам применить `RuntimeDefault`, а не
оставить процесс `Unconfined`. Правим конфигурацию kubelet на ноде:

```bash
# на ноде
ssh control-plane
sudo -i
grep -q '^seccompDefault:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^seccompDefault:.*/seccompDefault: true/' /var/lib/kubelet/config.yaml \
  || echo 'seccompDefault: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

```bash
# на worker: имя Node в API - не алиас 'control-plane' из /etc/hosts, а реальное имя ноды (ip-10-...)
kubectl get nodes     # Ready
```

Создаём Pod без единого упоминания `seccompProfile` - ни на Pod, ни на container level:

```yaml
# no-seccomp-field.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-seccomp-field
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# на worker
kubectl apply -f no-seccomp-field.yaml
kubectl get pod -n security-106 no-seccomp-field
kubectl exec -n security-106 no-seccomp-field -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2  -- kubelet применил RuntimeDefault сам, без поля в манифесте

# Проверьте себя через РЕАЛЬНО ПРИМЕНЁННУЮ конфигурацию kubelet, не через текст файла на
# диске - drop-in или флаг командной строки могли бы переопределить значение без
# изменения самого config.yaml:
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" | jq '.kubeletconfig.seccompDefault'
# true
```

Без `seccompDefault: true` тот же манифест дал бы `Seccomp: 0` (`Unconfined`) - это легко
проверить, откатив флаг и пересоздав Pod, если нужно убедиться в разнице.

## 9. Отладка сломанного AppArmor-профиля

`/etc/apparmor.d/k8s-106-broken-profile` уже на диске, но никогда не загружался: в нём не
хватает запятой после правила `deny /work/** w`. Сначала находим ошибку без загрузки в
ядро. `-p`/`--preprocess` здесь НЕ подходит - это preprocessing (разворачивает
`#include` в stdout), а не safe dry-run/syntax-check. Используем `-Q`/`--skip-kernel-load`
(полная компиляция/проверка без загрузки в ядро) или `-d`/`--debug`
(однократно - только syntax check).

Артефакт `apparmor-debug.txt` должен содержать **исходную** ошибку парсера, поэтому
сохраняем его до исправления (на `worker`):

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile' \
  > /var/work/tests/artifacts/8/apparmor-debug.txt 2>&1
cat /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

Используем `sudo` и для compile-only проверки `-Q`: на ноде лабы (apparmor 3.0.4, Ubuntu)
без привилегий парсер при каждом запуске пытается настроить policy cache в
`/var/cache/apparmor` и падает с "Failed setting up policy cache (/var/cache/apparmor):
Permission denied" ДО проверки синтаксиса - вы получите обманчивую ошибку о правах вместо
реальной синтаксической ошибки, а `apparmor-debug.txt` не будет содержать нужный текст
"syntax error". Проверено на самой ноде, в том числе на заведомо сломанном профиле.
Альтернатива без `sudo` - добавить `-K`/`--skip-cache` (`apparmor_parser -Q -K ...`): без
кэширования парсер доходит до разбора профиля. `sudo` в этой лабе выбран для единого
workflow с последующим `-r`, который в любом случае требует привилегий.

Исправляем на ноде: правило AppArmor обязано завершаться запятой. Затем загружаем
исправленный профиль в ядро - именно `-r -v` (reload + verbose), а не `-Q`/`-p`, которые
ничего не загружают:

```bash
# на ноде
ssh control-plane
sudo -i
sed -i 's/^\(\s*deny \/work\/\*\* w\)$/\1,/' /etc/apparmor.d/k8s-106-broken-profile
tail -5 /etc/apparmor.d/k8s-106-broken-profile
apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile
aa-status --pretty-json | grep k8s-106-broken-profile
# ожидается: "k8s-106-broken-profile":	"enforce",
```

Финальная проверка, что файл теперь валиден без ошибок:

```bash
apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile
echo "exit: $?"
# exit: 0
exit
exit
```

Теперь на `worker` допишите подтверждение загрузки ПОСЛЕ исправления в тот же артефакт:

```bash
ssh control-plane 'sudo aa-status --pretty-json' | grep k8s-106-broken-profile >> /var/work/tests/artifacts/8/apparmor-debug.txt
cat /var/work/tests/artifacts/8/apparmor-debug.txt
```

В конце запустите (на `worker`):

```bash
check_result
```
