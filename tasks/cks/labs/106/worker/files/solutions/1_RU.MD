# Лаба 106 — эталонное решение: AppArmor и seccomp

> Выполняйте Kubernetes-команды с рабочей машины. Для задания 1 нужен SSH-доступ к
> ноде `control-plane`. Namespace `security-106` создаётся в задании 2.

## 1. Перевод AppArmor profile в enforce

Bootstrap загрузил profile, но намеренно включил режим `complain`. На workload-ноде
переведём именно существующий profile в enforcing mode и проверим результат:

```bash
ssh control-plane sudo aa-enforce /etc/apparmor.d/k8s-106-deny-write
ssh control-plane "sudo aa-status | grep -F 'k8s-106-deny-write'"
# ожидается: k8s-106-deny-write (enforce)
```

`aa-enforce` меняет режим загруженной policy. Не требуется и небезопасно копировать
profile через Pod или заменять `Localhost` на `Unconfined`.

## 2. Pod с Localhost AppArmor и отказом записи

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

# Положительный контроль: разрешённая операция чтения по-прежнему работает.
kubectl exec -n security-106 apparmor-writer -- sh -c 'cat /etc/hostname >/dev/null'

# Отрицательный контроль: denial должен быть именно отказом записи AppArmor.
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# ожидается ненулевой код: Permission denied / Operation not permitted

# На ноде свяжите отказ с profile в kernel/audit log. Выполняйте сразу после попытки выше.
ssh control-plane 'sudo journalctl -k --since "5 minutes ago" | grep -i apparmor || sudo dmesg | grep -i apparmor'
# ожидается запись с apparmor="DENIED" и profile="k8s-106-deny-write"
```

Если `/proc/1/attr/current` недоступен в конкретном runtime, зафиксируйте это и опирайтесь
на назначение Localhost profile вместе с kernel `apparmor="DENIED"` для данного profile;
один ненулевой код без этих evidence недостаточен, так как его может дать mount или обычное
Unix permission.

## 3. RuntimeDefault для обычного Pod

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

## 4–5. Localhost seccomp и доказательство блокировки `unshare`

Файл уже доставлен администрацией ноды в
`/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json`. В API указываем путь
относительно seccomp root: `profiles/cks-106-deny-unshare.json`.

`SYS_ADMIN` здесь — намеренное опасное исключение только для laboratory control. Без custom
filter `unshare -m` с этой capability может сработать; seccomp должен вернуть `EPERM`.
Это не hardened combination. `allowPrivilegeEscalation: false` включает `no_new_privs`, но
не отнимает capabilities, уже выданные процессу, поэтому мы не используем это поле как
«компенсацию» для `SYS_ADMIN`. В production такую capability удаляют, если нет доказанной
необходимости. В Kubernetes capability записывается как `SYS_ADMIN`, без префикса `CAP_`.

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
      if unshare -m true 2>/tmp/unshare.err; then
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

kubectl exec -n security-106 localhost-seccomp -- unshare -m true
# ожидается ненулевой код: Operation not permitted / Permission denied
```

Теперь выполните negative control: тот же syscall с той же capability, но без seccomp
filter. Успех control Pod доказывает, что отказ выше дал именно custom profile.

```bash
kubectl run sysadmin-control -n security-106 --rm -i --restart=Never \
  --image=busybox:1.36 \
  --overrides='{"spec":{"nodeSelector":{"security.cks.io/localhost-profiles-106":"true"},"securityContext":{"seccompProfile":{"type":"Unconfined"}},"containers":[{"name":"sysadmin-control","image":"busybox:1.36","securityContext":{"capabilities":{"add":["SYS_ADMIN"]}},"command":["unshare","-m","true"]}]}}'
# ожидается exit 0; Pod удаляется из-за --rm
```

## 6. User namespaces: `hostUsers: false` и `uid_map`

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

## 7. `seccompDefault: true` на kubelet

Все предыдущие Pod явно задавали `seccompProfile`. Здесь проверяем node-level baseline:
если разработчик забудет это поле, kubelet должен сам применить `RuntimeDefault`, а не
оставить процесс `Unconfined`.

```bash
ssh control-plane 'sudo grep -q "^seccompDefault:" /var/lib/kubelet/config.yaml \
  && sudo sed -i "s/^seccompDefault:.*/seccompDefault: true/" /var/lib/kubelet/config.yaml \
  || echo "seccompDefault: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh control-plane 'sudo systemctl restart kubelet'
ssh control-plane 'sudo systemctl is-active kubelet'
kubectl get node control-plane -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
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
```

Без `seccompDefault: true` тот же манифест дал бы `Seccomp: 0` (`Unconfined`) - это легко
проверить, откатив флаг и пересоздав Pod, если нужно убедиться в разнице.

## 8. Отладка сломанного AppArmor-профиля

`/etc/apparmor.d/k8s-106-broken-profile` уже на диске, но никогда не загружался: в нём не
хватает запятой после правила `deny /work/** w`. Сначала находим ошибку без загрузки в
ядро - `-p` только парсит файл:

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -p /etc/apparmor.d/k8s-106-broken-profile' \
  2>&1 | tee /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

Исправляем: правило AppArmor обязано завершаться запятой.

```bash
ssh control-plane "sudo sed -i 's/^\(\s*deny \/work\/\*\* w\)\$/\1,/' /etc/apparmor.d/k8s-106-broken-profile"
ssh control-plane 'sudo tail -5 /etc/apparmor.d/k8s-106-broken-profile'
```

Загружаем исправленный профиль в ядро - именно `-r -v` (reload + verbose), а не только
`-p`, которое ничего не загружает:

```bash
ssh control-plane 'sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile' \
  | tee -a /var/work/tests/artifacts/8/apparmor-debug.txt
ssh control-plane 'sudo aa-status | grep k8s-106-broken-profile'
```

Финальная проверка, что файл теперь валиден без ошибок:

```bash
ssh control-plane 'sudo apparmor_parser -p /etc/apparmor.d/k8s-106-broken-profile'
echo "exit: $?"
# exit: 0
```

В конце запустите:

```bash
check_result
```
