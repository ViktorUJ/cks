[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 110 - solución de referencia: gVisor, WireGuard e Istio STRICT

> Trabajamos como en el examen: `kubectl`, `cilium` e `istioctl` en la máquina de trabajo, y las operaciones sobre el
> nodo (containerd, tcpdump) en el propio nodo: entra en él con `ssh <nodo>`, pasa a root
> (`sudo -i`), ejecuta los comandos y sal (`exit`, `exit`). Los nombres `gvisor-sandbox`,
> `runc-baseline`, `gvisor-echo`, `market-api`, `market-client`, `mesh-outside` y las rutas de los
> artefactos forman parte del contrato comprobable del laboratorio.

## Dónde encontrar ejemplos en la documentación

| Qué se necesita | Página y sección |
| :--- | :--- |
| La sección `runsc` en `/etc/containerd/config.toml` (`runtime_type = "io.containerd.runsc.v1"`), el reinicio de containerd y el YAML de `RuntimeClass` con `handler: runsc` | [gVisor - Containerd Quick Start: Configure containerd, Restart containerd, Set up the Kubernetes RuntimeClass](https://gvisor.dev/docs/user_guide/containerd/quick_start/) |
| `RuntimeClass`, los campos `scheduling.nodeSelector` y `scheduling.tolerations` | [Kubernetes - Runtime Class: Scheduling](https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling) |
| Habilitar WireGuard (`encryption.enabled=true`, `encryption.type=wireguard`) y comprobar (`cilium-dbg status \| grep Encryption`) | [Cilium - WireGuard Transparent Encryption: Enable WireGuard in Cilium, Validate the Setup](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) |
| `PeerAuthentication` con `mtls.mode: STRICT` | [Istio - PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) |

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 1. Restaurar el runtime de containerd y crear el RuntimeClass

El nodo `k8s110_node_gvisor` ya se entregó como un dedicated pool con `runsc` instalado, pero
el bootstrap quitó deliberadamente la sección runtime de `runsc` de `/etc/containerd/config.toml`:
la situación típica de examen en la que el binario está, pero containerd no sabe nada de él.

```bash
ssh k8s110_node_gvisor
sudo -i
```

```bash
# en el nodo gVisor (root): el binario está, containerd está activo, la sección runsc no está en la config
runsc --version
systemctl is-active containerd
grep runsc /etc/containerd/config.toml

# añadir la sección runsc (el valor de runtime_type debe ser exacto) y reiniciar containerd
cat >> /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
systemctl restart containerd
systemctl is-active containerd
grep -A1 runtimes.runsc /etc/containerd/config.toml
exit   # de root
exit   # del nodo gVisor
```

No hace falta reiniciar el kubelet: el kubelet pasa a containerd el nombre del handler de `RuntimeClass` en
cada creación de un Pod, y no al arrancar el kubelet.

```yaml
# runtimeclass-gvisor.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox.runtime/gvisor: "true"
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
```

```bash
kubectl apply -f runtimeclass-gvisor.yaml
kubectl get runtimeclass gvisor -o yaml
printf 'RuntimeClass gvisor: handler runsc\n' \
  > /var/work/tests/artifacts/1/runsc-runtime.txt
```

`scheduling.nodeSelector` es un límite importante: el scheduler no asignará un workload `runsc` al
control-plane, donde no existe tal handler. El nodo gVisor, además, está marcado con el taint
`sandbox.runtime/gvisor=true:NoSchedule` (`kubectl describe node <nodo-gvisor> | grep Taints`):
en él no caerá ningún Pod, salvo los que lo toleran. `scheduling.tolerations` en el RuntimeClass
se añaden automáticamente a todos los Pods con esta clase, por eso `gvisor-sandbox` cae allí,
y los demás no.

## 2. Ejecutar un Pod sandboxed y un Service

`busybox httpd` da a la vez una shell para `uname` y un pequeño HTTP endpoint para el
experimento entre nodos de WireGuard. `runtimeClassName` se aplica al Pod, y no al contenedor.

`nodeSelector` y `tolerations` en el Pod se indican explícitamente: así se ve en qué nodo cae y por qué.
Es lo mismo que está descrito en el `scheduling` del propio `RuntimeClass`. Si no se indican en el Pod,
no se romperá nada: al crear un Pod con `runtimeClassName`, Kubernetes le **añade** por sí mismo
el `nodeSelector` y los `tolerations` de `RuntimeClass.scheduling` (comprobación: `kubectl -n sandbox-110 get
pod gvisor-sandbox -o jsonpath='{.spec.nodeSelector}'`). Pero entonces en el manifiesto eso no se ve, y sin
`scheduling` en el RuntimeClass el Pod podría caer en un nodo sin `runsc` y no arrancar.

```yaml
# gvisor-sandbox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gvisor-sandbox
  namespace: sandbox-110
  labels:
    app: gvisor-echo
spec:
  runtimeClassName: gvisor
  nodeSelector:
    sandbox.runtime/gvisor: "true"
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      mkdir -p /www
      printf 'CKS110-WIREGUARD-MARKER\n' >/www/index.html
      exec httpd -f -p 8080 -h /www
    ports:
    - containerPort: 8080
      name: http
---
apiVersion: v1
kind: Service
metadata:
  name: gvisor-echo
  namespace: sandbox-110
spec:
  selector:
    app: gvisor-echo
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f gvisor-sandbox.yaml
kubectl wait -n sandbox-110 --for=condition=Ready pod/gvisor-sandbox --timeout=180s
{
  printf 'gvisor uname -r: '
  kubectl exec -n sandbox-110 gvisor-sandbox -- uname -r
  printf '\n--- gvisor dmesg ---\n'
  kubectl exec -n sandbox-110 gvisor-sandbox -- dmesg 2>&1 || true
} > /var/work/tests/artifacts/2/gvisor-kernel.txt
cat /var/work/tests/artifacts/2/gvisor-kernel.txt
kubectl get pod -n sandbox-110 gvisor-sandbox -o wide
```

gVisor Sentry muestra al workload un kernel view sintético; `dmesg` muestra no el log del kernel
del nodo, sino un breve log sintético que empieza con la línea `Starting gVisor...` (precisamente la que espera
el checker). Es lo esperado y no es motivo para conceder al contenedor privileges de más.

## 3. Un Pod runc normal para comparar

La ausencia de `runtimeClassName` deja el handler por defecto `runc`. El selector coloca
deliberadamente este Pod en el control-plane, por lo que las siguientes tareas generan tráfico
entre nodos.

```yaml
# runc-baseline.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runc-baseline
  namespace: sandbox-110
spec:
  nodeSelector:
    lab.cks.io/role: control-plane
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f runc-baseline.yaml
kubectl wait -n sandbox-110 --for=condition=Ready pod/runc-baseline --timeout=180s
{
  printf 'gvisor uname -r: '
  kubectl exec -n sandbox-110 gvisor-sandbox -- uname -r
  printf 'runc uname -r: '
  kubectl exec -n sandbox-110 runc-baseline -- uname -r
} > /var/work/tests/artifacts/3/runtime-comparison.txt
cat /var/work/tests/artifacts/3/runtime-comparison.txt
```

Un contenedor `runc` normal ve el host kernel release, y el workload de gVisor, el Sentry view.
Es un límite de ejecución adicional, y no un sustituto de `SecurityContext`, seccomp o de la
comprobación de la image.

## 4. Habilitar Cilium WireGuard

Cilium gestiona por sí mismo las keys y los peers de WireGuard. Habilitamos un solo backend de cifrado: no
añadimos IPsec. Importante: el CLI `cilium` **cliente** (instalado en el worker) no tiene
el subcomando `encrypt enable`; WireGuard se habilita mediante la configuración de Cilium, y no con un
comando de runtime. Primero registraremos las versiones y contrastaremos el agent con la requirements matrix:

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  printf 'Kubernetes='
  kubectl version -o json | jq -r '.serverVersion.gitVersion'
  printf 'Cilium agent='
  kubectl -n kube-system get pod "$agent" -o jsonpath='{.spec.containers[?(@.name=="cilium-agent")].image}'
  printf '\n'
  cilium version --client
  printf 'Cilium CLI=v0.19.7\n'
  printf 'Cilium data plane=verify current supported lab build against Kubernetes 1.36 requirements matrix\n'
  printf 'Istio=1.30.4\n'
} > /var/work/tests/artifacts/4/tool-versions.txt
cat /var/work/tests/artifacts/4/tool-versions.txt
```

El clúster se desplegó con el comando `cilium install`, que instala Cilium **mediante Helm**.
El source of truth duradero son los Helm values del release `cilium`; usamos un upgrade con el Cilium CLI fijado y después comprobamos el ConfigMap live y los agents:

```bash
cilium upgrade --version 1.20.1 \
  --set encryption.enabled=true --set encryption.type=wireguard --wait
# Helm cambia solo el ConfigMap: la plantilla del DaemonSet no cambia, por lo que los agentes por sí mismos
# no se reinician y siguen funcionando sin WireGuard: reinícialos explícitamente.
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
test "$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')" = true
cilium status --wait
```

El estado del cifrado lo leemos del agente mediante `cilium-dbg`: es el debug CLI in-pod, que viene con el Cilium agent. El CLI `cilium` local sigue siendo una herramienta de install/cluster-level y no lo sustituye dentro del Pod. `cilium-dbg status` NO tiene el flag `--all-encryption` (en 1.20.x solo están disponibles `--all-addresses`, `--all-clusters`, `--all-controllers`, `--all-health`, `--all-nodes`, `--all-redirects`, `--verbose`): la evidence detallada de peer/allowed-IP/remote-node la obtenemos mediante `cilium-dbg debuginfo --output json`, y no mediante un flag inexistente.

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  printf '$ cilium-dbg encrypt status
'
  kubectl -n kube-system exec "$agent" -- cilium-dbg encrypt status
  printf '$ cilium-dbg debuginfo --output json
'
  kubectl -n kube-system exec "$agent" -- cilium-dbg debuginfo --output json
} > /var/work/tests/artifacts/4/cilium-encrypt-status.txt
cat /var/work/tests/artifacts/4/cilium-encrypt-status.txt
grep -Eqi 'peer|allowed[ -]?ip|remote node' /var/work/tests/artifacts/4/cilium-encrypt-status.txt
```

## 5. Captura de un paquete WireGuard entre nodos

WireGuard por defecto usa UDP/51871. Un filtro SOLO por `udp port 51871` excluye de antemano
el TCP plaintext del resultado y por eso NO demuestra su ausencia; en su lugar
usamos un mismo capture scope (`host <remote-node-ip>`, sin filtro de puerto) y comparamos
ANTES/DESPUÉS de habilitar WireGuard sobre un mismo flow entre nodos.

La captura en `any` NO es un punto de observación correcto del on-wire state: `any` ve también la
interfaz interna de Cilium `cilium_wg0`, por la que, por diseño del túnel, pasa tráfico YA DESCIFRADO.
Hay que capturar en la interfaz física de egress hacia el nodo remoto (no `any`, `cilium_*`,
`lxc*`, `veth*`).

Harán falta dos terminales: el **terminal 1** es el control-plane (allí `tcpdump`), el **terminal 2** es la
máquina de trabajo (peticiones y `kubectl`).

```bash
# terminal 2 (máquina de trabajo): IP del nodo con el gVisor-Pod: es el nodo "remoto" para el control-plane
gvisor_node=$(kubectl get pod gvisor-sandbox -n sandbox-110 -o jsonpath='{.spec.nodeName}')
remote_ip=$(kubectl get node "$gvisor_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "remote_ip=$remote_ip"
```

```bash
# terminal 1: entrar en el control-plane y averiguar la interfaz física hacia remote_ip
ssh k8s110_controlPlane_1
sudo -i
```

```bash
# terminal 1 (control-plane, root): escribe el valor de remote_ip del terminal 2
remote_ip=10.110.2.172
ip route get $remote_ip
# 10.110.2.172 dev ens5 src 10.110.1.x   <- la interfaz (ens5), no any / cilium_* / lxc* / veth*
```

**Baseline: WireGuard desactivado.** Desactivamos temporalmente WireGuard y repetimos LA MISMA petición con EL MISMO
capture scope. Al final restableceremos obligatoriamente `enable-wireguard: "true"`.

```bash
# terminal 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# terminal 1 (control-plane, root): captura de 20 segundos, luego lanza enseguida la petición en el terminal 2
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-baseline.txt
```

```bash
# terminal 2: mientras dura la captura (los primeros ~15 segundos)
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# terminal 1 (tras terminar la captura): el plaintext marker se ve, WireGuard está desactivado
grep CKS110-WIREGUARD-MARKER /tmp/wireguard-baseline.txt
```

**Después: WireGuard habilitado.** Restablecemos WireGuard y repetimos LA MISMA petición con EL MISMO scope
de captura: ahora debe verse WireGuard UDP/51871 y no debe haber marker.

```bash
# terminal 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# terminal 1 (control-plane, root): captura de 20 segundos
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-tcpdump.txt
```

```bash
# terminal 2: mientras dura la captura
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# terminal 1 (tras terminar la captura)
grep -E 'UDP' /tmp/wireguard-tcpdump.txt | head -3      # 51871 > 51871: UDP
grep -c CKS110-WIREGUARD-MARKER /tmp/wireguard-tcpdump.txt   # 0
exit   # de root
exit   # del control-plane
```

```bash
# terminal 2: recoger el capture para la comprobación
scp k8s110_controlPlane_1:/tmp/wireguard-tcpdump.txt /var/work/tests/artifacts/5/wireguard-tcpdump.txt
```

No saques conclusiones de un `tcpdump` en el Pod netns: allí el tráfico antes del Cilium encryption point aún puede ser
plaintext. La prueba aquí es el paso de un marker visible (WireGuard desactivado) a su
ausencia (WireGuard habilitado) con UN MISMO capture scope.

## 6. Istio y PeerAuthentication STRICT

Instalamos solo el Istio control plane en minimal profile. El namespace se preparó con
`istio-injection=enabled`, por lo que los workloads en `market` reciben un Envoy sidecar al
crearse. `market-api` se sitúa en el gVisor worker, el client en el control-plane, lo que
también hace que la petición sea entre nodos.

```bash
istioctl install --set profile=minimal -y
kubectl -n istio-system rollout status deployment/istiod --timeout=180s
kubectl get namespace market --show-labels
```

```yaml
# market-workloads.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-api
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels: {app: market-api}
  template:
    metadata:
      labels: {app: market-api}
    spec:
      nodeSelector:
        lab.cks.io/role: gvisor
      tolerations:
      - key: sandbox.runtime/gvisor
        operator: Equal
        value: "true"
        effect: NoSchedule
      automountServiceAccountToken: false
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-ec", "mkdir -p /www; printf 'market-110\\n' >/www/index.html; exec httpd -f -p 8080 -h /www"]
        ports:
        - containerPort: 8080
          name: http
        readinessProbe:
          httpGet:
            path: /
            port: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: market-api
  namespace: market
spec:
  selector: {app: market-api}
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-client
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels: {app: market-client}
  template:
    metadata:
      labels: {app: market-client}
    spec:
      nodeSelector:
        lab.cks.io/role: control-plane
      automountServiceAccountToken: false
      containers:
      - name: app
        image: curlimages/curl:8.11.0
        command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: mesh-outside
  namespace: default
spec:
  nodeSelector:
    lab.cks.io/role: control-plane
  automountServiceAccountToken: false
  containers:
  - name: app
    image: curlimages/curl:8.11.0
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f market-workloads.yaml
kubectl rollout status -n market deployment/market-api --timeout=180s
kubectl rollout status -n market deployment/market-client --timeout=180s
kubectl wait -n default --for=condition=Ready pod/mesh-outside --timeout=180s
kubectl get pods -n market

# Baseline (STRICT todavía no aplicada): un plaintext client fuera del mesh debe recibir 200:
# esto demuestra que la conectividad funciona en principio y que cualquier denegación posterior
# la causará precisamente STRICT mTLS, y no un problema independiente de DNS/network.
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside-baseline.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside-baseline.txt
cat /var/work/tests/artifacts/6/market-outside-baseline.txt
# esperamos: HTTP/1.1 200 OK y al final exit_code=0
```

```yaml
# market-strict.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: market-strict
  namespace: market
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f market-strict.yaml
kubectl get peerauthentication -n market market-strict -o yaml

# petición desde dentro del mesh (client con sidecar)
kubectl exec -n market deploy/market-client -- \
  curl -si --max-time 10 http://market-api \
  > /var/work/tests/artifacts/6/market-inside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-inside.txt
cat /var/work/tests/artifacts/6/market-inside.txt
# esperamos: HTTP/1.1 200 OK y al final exit_code=0

# la misma petición desde fuera del mesh (plaintext, sin sidecar)
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside.txt
cat /var/work/tests/artifacts/6/market-outside.txt
# esperamos: Recv failure: Connection reset by peer y al final exit_code=56 (no 0)
```

`PeerAuthentication` controla el inbound server mode. El client interno recibe un
certificado y usa mTLS automáticamente; el Pod en `default` no tiene sidecar y envía
plaintext, por lo que el Envoy server con `STRICT` corta la conexión con un reset (RST). Termina con:

```bash
check_result
```
