# Лаба 106 — эталонное решение: AppArmor и seccomp

> Выполняйте Kubernetes-команды с рабочей машины. Для заданий 1–2 нужен SSH-доступ к
> ноде `control-plane`. Namespace `security-106` создаётся в задании 3.

## 1. Перенос и загрузка AppArmor profile

Профиль лежит только на рабочей машине. Копируем его на ноду и загружаем в ядро -
файл уже содержит флаг `complain`, поэтому одного `apparmor_parser -r` достаточно для
первичной загрузки (без `aa-complain`, который, как и `aa-enforce`, парсит все файлы в
`/etc/apparmor.d/` и упал бы на ещё сломанном `k8s-106-broken-profile` из задания 9):

```bash
scp -o StrictHostKeyChecking=no /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/k8s-106-deny-write
ssh control-plane 'sudo mv /tmp/k8s-106-deny-write /etc/apparmor.d/k8s-106-deny-write'
ssh control-plane 'sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write'
ssh control-plane "sudo cat /sys/kernel/security/apparmor/profiles | grep -F 'k8s-106-deny-write'"
# ожидается: k8s-106-deny-write (complain)
```

## 2. Перевод AppArmor profile в enforce

Profile сейчас в режиме `complain` (загружен с этим флагом в задании 1). На
workload-ноде переведём именно существующий profile в enforcing mode и проверим
результат:

```bash
ssh control-plane "sudo sed -i 's/, complain,/,/' /etc/apparmor.d/k8s-106-deny-write"
ssh control-plane 'sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write'
ssh control-plane "sudo cat /sys/kernel/security/apparmor/profiles | grep -F 'k8s-106-deny-write'"
# ожидается: k8s-106-deny-write (enforce)
# Не проверяйте это через 'aa-status | grep ...': aa-status группирует профили под
# заголовками секций ('N profiles are in enforce mode.') и печатает под ними голые
# имена БЕЗ суффикса (enforce)/(complain) на каждой строке - такой суффикс есть только
# в /proc/<pid>/attr/current и в файле ядра /sys/kernel/security/apparmor/profiles.
```

Не используйте `aa-enforce`/`aa-complain`/`aa-status` и другие инструменты пакета
`apparmor-utils`, написанные на Python, для ЭТОГО профиля, пока не выполнено задание 9:
все они внутри вызывают `apparmor.read_profiles()`, который при старте разбирает
(парсит) **все** файлы в `/etc/apparmor.d/`, включая ещё не загруженный и заведомо
сломанный `/etc/apparmor.d/k8s-106-broken-profile` из задания 9 - и падают с ошибкой
парсера на ЧУЖОМ файле, даже не пытаясь дойти до вашего профиля. `apparmor_parser`
(бинарник, а не Python-обёртка), вызванный напрямую с ОДНИМ конкретным файлом, разбирает
только его и не подвержен этой проблеме - именно поэтому мы правим флаг профиля
(убираем `complain` из `flags=(...)`) вручную через `sed`, а затем перезагружаем именно
этот файл через `apparmor_parser -r`.

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
kubectl apply -f apparmor-writer.yaml
kubectl wait -n security-106 --for=condition=Ready pod/apparmor-writer --timeout=120s

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

# Ненулевой exit code и текст 'permission denied' сами по себе НЕ доказывают, что именно
# AppArmor это правило сработало - обычная DAC/filesystem ошибка выглядела бы идентично
# с точки зрения shell. Свяжите отказ именно с этим profile через kernel audit log.
# Выполняйте сразу после попытки выше.
ssh control-plane "sudo journalctl -k --no-pager -n 500 | grep -F 'apparmor=\"DENIED\"' | grep -F 'profile=\"k8s-106-deny-write\"' | grep -F 'cks-106-denied.txt'"
# ожидается запись вида: ... apparmor="DENIED" ... profile="k8s-106-deny-write" name=".../cks-106-denied.txt" ... denied_mask="w" ...
```

Если `/proc/1/attr/current` недоступен в конкретном runtime, зафиксируйте это и опирайтесь
на назначение Localhost profile вместе с kernel `apparmor="DENIED"` для данного profile;
один ненулевой код без этих evidence недостаточен, так как его может дать mount или обычное
Unix permission.

## 4. RuntimeDefault для обычного Pod

`RuntimeDefault` — переносимый baseline, который выбирает стандартный профиль
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
kubectl apply -f runtime-default.yaml
kubectl wait -n security-106 --for=condition=Ready pod/runtime-default --timeout=120s
kubectl exec -n security-106 runtime-default -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2
```

## 5–6. Localhost seccomp и доказательство блокировки `unshare`

Файл лежит только на рабочей машине, в `/opt/lab106-fixtures/cks-106-deny-unshare.json`.
Определяем целевую ноду по её label и копируем JSON в kubelet seccomp root:

```bash
ssh control-plane 'sudo mkdir -p /var/lib/kubelet/seccomp/profiles'
scp -o StrictHostKeyChecking=no /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/cks-106-deny-unshare.json
ssh control-plane 'sudo mv /tmp/cks-106-deny-unshare.json /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json'
ssh control-plane 'sudo jq empty /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json && echo valid'
```

В API указываем путь относительно seccomp root: `profiles/cks-106-deny-unshare.json`.

`SYS_ADMIN` здесь — намеренное опасное исключение только для laboratory control. Без custom
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
kubectl apply -f localhost-seccomp.yaml
kubectl wait -n security-106 --for=condition=Ready pod/localhost-seccomp --timeout=120s
kubectl exec -n security-106 localhost-seccomp -- cat /tmp/unshare-result
# unshare denied by seccomp

kubectl exec -n security-106 localhost-seccomp -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2

kubectl exec -n security-106 localhost-seccomp -- unshare -n true
# ожидается ненулевой код: Operation not permitted / Permission denied
```

Теперь выполните negative control: тот же syscall с той же capability, но без seccomp
filter. Успех control Pod доказывает, что отказ выше дал именно custom profile.

```bash
kubectl run sysadmin-control -n security-106 --rm -i --restart=Never \
  --image=busybox:1.36 \
  --overrides='{"spec":{"nodeSelector":{"security.cks.io/localhost-profiles-106":"true"},"securityContext":{"seccompProfile":{"type":"Unconfined"}},"containers":[{"name":"sysadmin-control","image":"busybox:1.36","securityContext":{"capabilities":{"add":["SYS_ADMIN"]}},"command":["unshare","-n","true"]}]}}'
# ожидается exit 0; Pod удаляется из-за --rm
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
kubectl apply -f userns-probe.yaml
kubectl wait -n security-106 --for=condition=Ready pod/userns-probe --timeout=120s
mkdir -p /var/work/tests/artifacts/6

kubectl exec -n security-106 userns-probe -- id | tee /var/work/tests/artifacts/6/userns.txt
# uid=0(root) gid=0(root) groups=0(root)
```

Host PID контейнера не совпадает ни с PID внутри контейнера, ни виден напрямую через
`kubectl`; получаем его через `crictl inspect` на ноде, где реально запущен Pod:

```bash
CONTAINER_ID=$(kubectl get pod userns-probe -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}' | sed 's#^containerd://##')
ssh control-plane "sudo crictl inspect '$CONTAINER_ID'" > /tmp/userns-inspect.json
HOST_PID=$(jq -r '.info.pid' /tmp/userns-inspect.json)
echo "host_pid=$HOST_PID"
```

`/proc/<host PID>/uid_map` на ноде описывает трансляцию: три числа - `<container-uid-start>
<host-uid-start> <length>`. Для `hostUsers: false` первая строка должна начинаться с `0`
(container UID 0), но host-uid-start обязан быть **не нулевым** - это и есть
непривилегированный диапазон хоста, а `length` - стандартный per-Pod блок `65536` UID.

```bash
ssh control-plane "sudo cat /proc/$HOST_PID/uid_map" | tee -a /var/work/tests/artifacts/6/userns.txt
# 0     100000      65536
```

Если `host-uid-start` равен `0` - user namespace не применился (например, из-за
несовместимого containerd/runc или отсутствия `hostUsers: false` в реально применённом
Pod) - это не hardening, а обычный root на хосте. Сравните с обычным Pod без
`hostUsers: false`, чтобы увидеть разницу:

```bash
kubectl run runc-baseline-userns -n security-106 --rm -i --restart=Never \
  --image=busybox:1.36 --overrides='{"spec":{"nodeSelector":{"security.cks.io/localhost-profiles-106":"true"}}}' \
  -- sh -c 'echo baseline-no-userns; sleep 5' &
sleep 2
kubectl get pod runc-baseline-userns -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}' 2>/dev/null
# Обычный Pod без hostUsers: false использует host user namespace напрямую -
# у него отдельного /proc/<PID>/uid_map с непривилегированной трансляцией не будет.
```

## 8. `seccompDefault: true` на kubelet

Все предыдущие Pod явно задавали `seccompProfile`. Здесь проверяем node-level baseline:
если разработчик забудет это поле, kubelet должен сам применить `RuntimeDefault`, а не
оставить процесс `Unconfined`.

```bash
ssh control-plane 'sudo grep -q "^seccompDefault:" /var/lib/kubelet/config.yaml \
  && sudo sed -i "s/^seccompDefault:.*/seccompDefault: true/" /var/lib/kubelet/config.yaml \
  || echo "seccompDefault: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh control-plane 'sudo systemctl restart kubelet'
ssh control-plane 'sudo systemctl is-active kubelet'
# Имя Node в API - не алиас 'control-plane' из /etc/hosts, а реальное имя ноды (ip-10-...).
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
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
kubectl apply -f no-seccomp-field.yaml
kubectl wait -n security-106 --for=condition=Ready pod/no-seccomp-field --timeout=60s
kubectl exec -n security-106 no-seccomp-field -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2  -- kubelet применил RuntimeDefault сам, без поля в манифесте

# Проверьте себя через РЕАЛЬНО ПРИМЕНЁННУЮ конфигурацию kubelet, не через текст файла на
# диске - drop-in или флаг командной строки могли бы переопределить значение без
# изменения самого config.yaml:
node=$NODE
kubectl get --raw "/api/v1/nodes/${node}/proxy/configz" | jq '.kubeletconfig.seccompDefault'
# true
```

Без `seccompDefault: true` тот же манифест дал бы `Seccomp: 0` (`Unconfined`) - это легко
проверить, откатив флаг и пересоздав Pod, если нужно убедиться в разнице.

## 9. Отладка сломанного AppArmor-профиля

`/etc/apparmor.d/k8s-106-broken-profile` уже на диске, но никогда не загружался: в нём не
хватает запятой после правила `deny /work/** w`. Сначала находим ошибку без загрузки в
ядро. `-p`/`--preprocess` здесь НЕ подходит - это preprocessing (разворачивает
`#include` в stdout), а не safe dry-run/syntax-check. Используем `-Q`/`--skip-kernel-load`
(полная компиляция/проверка без загрузки в ядро, без привилегий) или `-d`/`--debug`
(однократно - только syntax check):

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile' \
  2>&1 | tee /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

Обязательно с `sudo`, даже с флагом `-Q`/`--skip-kernel-load`: этот флаг лишь пропускает
загрузку профиля в ЯДРО, но `apparmor_parser` всё равно пытается настроить policy cache в
`/var/cache/apparmor` при каждом запуске. Без привилегий это падает с "Failed setting up
policy cache (/var/cache/apparmor): Permission denied" ДО того, как парсер доходит до
проверки синтаксиса - вы получите обманчивую ошибку о правах доступа вместо реальной
синтаксической ошибки, а `apparmor-debug.txt` не будет содержать нужный текст "syntax
error" для проверки.

Исправляем: правило AppArmor обязано завершаться запятой.

```bash
ssh control-plane "sudo sed -i 's/^\(\s*deny \/work\/\*\* w\)\$/\1,/' /etc/apparmor.d/k8s-106-broken-profile"
ssh control-plane 'sudo tail -5 /etc/apparmor.d/k8s-106-broken-profile'
```

Загружаем исправленный профиль в ядро - именно `-r -v` (reload + verbose), а не `-Q`/`-p`,
которые ничего не загружают:

```bash
ssh control-plane 'sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile' \
  | tee -a /var/work/tests/artifacts/8/apparmor-debug.txt
ssh control-plane 'sudo aa-status | grep k8s-106-broken-profile'
```

Финальная проверка, что файл теперь валиден без ошибок:

```bash
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile'
echo "exit: $?"
# exit: 0
```

В конце запустите:

```bash
check_result
```
