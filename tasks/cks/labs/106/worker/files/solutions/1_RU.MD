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
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# ожидается ненулевой код: Permission denied / Operation not permitted
```

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

`SYS_ADMIN` здесь — узкое, намеренное исключение для лабораторного опыта: без custom
filter `unshare -m` потребовал бы эту capability и мог бы сработать. Seccomp возвращает
`EPERM` раньше, поэтому capability не превращается в обход policy.

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
      allowPrivilegeEscalation: false
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

В конце запустите:

```bash
check_result
```
