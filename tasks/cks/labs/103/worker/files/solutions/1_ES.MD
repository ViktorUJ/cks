[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 103 - solución de referencia

> Los comandos se ejecutan en el worker, salvo que se indique explícitamente `control-plane`. Antes de editar los
> static Pod manifests, guarda copias. El kubelet notará por sí mismo el cambio de los archivos y recreará
> los static Pods correspondientes; no los elimines a través de la Kubernetes API.
>
> En el examen, `k` (`alias k=kubectl`) y el bash-completion para él ya están configurados en el SSH-host:
> no pierdas tiempo en configurarlos, simplemente usa `k` (consulta el capítulo 33.6).

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
k config use-context "$CTX"
ssh control-plane hostname
```

## Tarea 1. Informe de kube-bench

`kube-bench` `0.16.0` ya está instalado en `control-plane` (igual que en el examen real, donde
las herramientas de CIS Benchmark ya están en los nodos): no hace falta copiarlo allí desde el worker. Kubernetes
`1.36` todavía no figura en la support table oficial de kube-bench; el version mapping integrado
de esta versión termina con la entrada `"1.34": "cis-1.12"`: no hay perfiles más nuevos (incluido
cualquier perfil para 1.35/1.36) en `0.16.0`, por lo que usamos precisamente `cis-1.12`
como el más cercano existente. Lo lanzamos de forma forzada como approximate
hardening signal, y no como authoritative CIS compliance assessment.

```bash
mkdir -p /var/work/tests/artifacts/1
{
  printf 'kubernetes_version=%s\n' "$(k version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-1.12\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,node,controlplane,etcd,policies'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

grep '== Summary' /var/work/tests/artifacts/1/kube-bench.txt
# == Summary master ==
# == Summary node ==
# == Summary controlplane ==
# == Summary etcd ==
# == Summary policies ==
```

Asegúrate a simple vista de que están presentes las cinco líneas `== Summary <target> ==`: sin un
`--targets` explícito, parte de ellas (`etcd`, `policies`) no entrará en el informe.

## Tarea 2. Hardening del kubelet

No intentes recordar de memoria los nombres de los campos: en el examen es más rápido sacarlos directamente del informe
de kube-bench ya generado (tarea 1). Cada check tiene allí una sección `== Remediations <target> ==`
con el texto de la corrección ya listo: `grep -A1` por el número del check da de inmediato el campo necesario:

```bash
grep -A1 '^4.2.1 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.1 If using a Kubelet config file, edit the file to set `authentication: anonymous: enabled` to
# `false`.

grep '^4.2.4 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.4 If using a Kubelet config file, edit the file to set `readOnlyPort` to 0.
```

En el control-plane el kubelet lee `/var/lib/kubelet/config.yaml`. En el YAML deben estar precisamente
los siguientes campos (no añadas dos veces claves con el mismo nombre):

```yaml
readOnlyPort: 0
authentication:
  anonymous:
    enabled: false
```

En el examen no prefijes cada comando con `sudo`: conviértete en root una sola vez (`sudo -i`), es más
rápido:

```bash
ssh control-plane
sudo -i
cp /var/lib/kubelet/config.yaml ~/2-kubelet-config.yaml
vim /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet
exit   # salir del shell de root
exit   # salir de control-plane
```

No comprobamos el texto estático del archivo, sino la configuración en vigor que el kubelet
realmente aplicó, a través de la API `configz` (el parseo de texto del YAML se engaña fácilmente con campos parecidos
como `webhook.enabled`, mientras que `configz` refleja lo que el propio kubelet considera su
configuración):

```bash
NODE=$(k get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}')

k get --raw="/api/v1/nodes/${NODE}/proxy/configz" \
  | jq -e '
      (.kubeletconfig.readOnlyPort // 0) == 0 and
      .kubeletconfig.authentication.anonymous.enabled == false
    '

k wait --for=condition=Ready "node/${NODE}" --timeout=120s
```

## Tarea 3. Desactivar profiling de kube-apiserver

La misma técnica que en la tarea 2: usa el informe de kube-bench de la tarea 1 como fuente de
verdad, no intentes recordar el flag de memoria:

```bash
grep -A2 '^1.2.15 ' /var/work/tests/artifacts/1/kube-bench.txt
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
# --profiling=false
```

Añade el parámetro a la lista `command` del contenedor `kube-apiserver`.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/3-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Añade al array command una línea con la misma indentación que el resto de los argumentos:
# - --profiling=false
exit
exit

ssh control-plane "sudo grep -n -- '--profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
k get po -n kube-system -l component=kube-apiserver
# STATUS debe pasar a Running; si todavía no, espera un par de segundos y repite
```

## Tarea 4. TLS Secret e Ingress

Crea una aplicación mínima y un Service, genera un certificado autofirmado para
el nombre DNS exacto y después crea el TLS Secret y el Ingress. El controller `ingress-nginx` ya está
instalado y Ready en este laboratorio (lab-owned fixture, versión fijada en el bootstrap): nos aseguraremos
de ello antes de crear el Ingress.

Los nombres cortos de recursos (`ns` = namespace, `deploy` = deployment, `svc` = service,
`ing` = ingress, `po` = pod) ahorran tecleo bajo la presión del tiempo.

```bash
k get ingressclass
k -n ingress-nginx get deploy ingress-nginx-controller
k -n ingress-nginx get endpoints ingress-nginx-controller

k create ns cks-103
k -n cks-103 create deploy secure-app --image=viktoruj/ping_pong:alpine
k -n cks-103 set env deploy/secure-app SERVER_NAME=secure-app SRV_PORT=80
k -n cks-103 expose deploy secure-app --name=secure-app --port=80 --target-port=80
k -n cks-103 wait --for=condition=Available deploy/secure-app --timeout=60s

mkdir -p /tmp/cks-103-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/cks-103-tls/tls.key \
  -out /tmp/cks-103-tls/tls.crt \
  -subj '/CN=secure.cks.local' \
  -addext 'subjectAltName=DNS:secure.cks.local'

k -n cks-103 create secret tls secure-ingress-tls \
  --cert=/tmp/cks-103-tls/tls.crt --key=/tmp/cks-103-tls/tls.key

cat <<'EOF' | k apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: cks-103
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.cks.local
    secretName: secure-ingress-tls
  rules:
  - host: secure.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port:
              number: 80
EOF

k get secret,ing -n cks-103
k get ing secure-ingress -n cks-103 -o yaml
```

No nos quedamos en `k get ... -o yaml`: confirmamos que el TLS Ingress realmente
funciona a través de un controller de verdad. `secure.cks.local` ya se resuelve a una node IP real
(el bootstrap añadió la entrada en `/etc/hosts`), y `ingress-nginx-controller` es un Service de tipo
`NodePort`, abierto en cada nodo, por lo que curl se ejecuta directamente desde esta máquina, sin SSH
al clúster:

```bash
HTTPS_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -k "https://secure.cks.local:${HTTPS_NODEPORT}/"
# HTTPCODE 200, el cuerpo contiene "Server Name: secure-app"

HTTP_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
curl -v "http://secure.cks.local:${HTTP_NODEPORT}/"
# < HTTP/1.1 308 Permanent Redirect
# < Location: https://secure.cks.local
```

Este redirect HTTP→HTTPS es una pregunta real del examen, no un requisito artificial del
laboratorio (consulta el mock-examen `tasks/cks/mock/04`, tarea 4).

## Tarea 5. TLS hardening de kube-apiserver y etcd

No busques el nombre exacto del flag en la documentación: es más rápido preguntárselo al propio binario desde dentro de un
Pod ya en ejecución (`--help` lo tiene cualquier componente del control plane) y filtrar con grep lo necesario:

```bash
k exec -n kube-system $(k get po -n kube-system -l component=kube-apiserver -o name) -- kube-apiserver --help | grep -i tls
# --tls-min-version string   Minimum TLS version supported. Possible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13
# --tls-cipher-suites strings   Comma-separated list of cipher suites for the server. Preferred values: TLS_AES_128_GCM_SHA256, ...

k exec -n kube-system $(k get po -n kube-system -l component=etcd -o name) -- etcd --help | grep -i cipher
# --cipher-suites ''   Comma-separated list of supported TLS cipher suites between client/server and peers
```

En ambos static Pod manifests añade los parámetros al `command`. En kube-apiserver la tarea exige
AMBOS flags, aunque la protección real con `VersionTLS13` la da precisamente `--tls-min-version`
(Go elige por sí mismo las TLS 1.3 cipher suites, `--tls-cipher-suites` no influye en ellas; consulta la pregunta
2 de la sección "Compruébate antes de empezar"). `--tls-cipher-suites` sigue siendo necesario explícitamente como
defense-in-depth: si más adelante se rebaja la versión mínima a 1.2, los conjuntos de cifrados débiles no
se activarán por sí solos. En etcd (donde se admite TLS 1.2) `--cipher-suites` ya limita realmente
el conjunto ahora mismo, y no de cara al futuro.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
cp /etc/kubernetes/manifests/etcd.yaml ~/5-etcd.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Añade al command:
# - --tls-min-version=VersionTLS13
# - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
vim /etc/kubernetes/manifests/etcd.yaml
# Añade al command:
# - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
exit
exit

k get po -n kube-system -l component=etcd
# STATUS debe pasar a Running; si todavía no, espera un par de segundos y repite
ssh control-plane "sudo grep -E -- '--tls-min-version=VersionTLS13|--tls-cipher-suites=' /etc/kubernetes/manifests/kube-apiserver.yaml"
ssh control-plane "sudo grep -- '--cipher-suites=' /etc/kubernetes/manifests/etcd.yaml"

mkdir -p /var/work/tests/artifacts/5
ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_3 -brief </dev/null' \
  > /var/work/tests/artifacts/5/tls13.txt 2>&1
# Protocol version: TLSv1.3 - la conexión se estableció

ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null' \
  >> /var/work/tests/artifacts/5/tls13.txt 2>&1
# ssl3_read_bytes:tlsv1 alert protocol version - el handshake debe fallar, eso es justo lo que hace falta

echo 'TLS 1.2 correctly rejected (non-zero exit / handshake failure)' \
  >> /var/work/tests/artifacts/5/tls13.txt
cat /var/work/tests/artifacts/5/tls13.txt
```

Se espera una línea del tipo `Protocol version: TLSv1.3` o `Protocol : TLSv1.3`, y la terminación de
`openssl s_client -tls1_2` con un error de handshake/non-zero exit debe quedar registrada como
`TLS 1.2 correctly rejected`.

## Tarea 6. Verificar el SHA-256 de kubelet y kubectl

La referencia no se calcula a partir de archivos locales. Descarga las sumas oficiales publicadas de
Kubernetes `v1.36.0`, genera los archivos en el formato de `sha256sum -c` y guarda los resultados.

```bash
mkdir -p /var/work/tests/artifacts/6 /tmp/cks-103-sha
cd /tmp/cks-103-sha
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl.sha256
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubelet.sha256

printf '%s  %s\n' "$(cat kubectl.sha256)" "$(command -v kubectl)" > kubectl.check
scp kubelet.sha256 control-plane:/tmp/kubelet.sha256
ssh control-plane 'printf "%s  %s\\n" "$(cat /tmp/kubelet.sha256)" "$(command -v kubelet)" > /tmp/kubelet.check && sha256sum -c /tmp/kubelet.check' \
  | tee /var/work/tests/artifacts/6/binaries.sha256.txt
sha256sum -c kubectl.check | tee -a /var/work/tests/artifacts/6/binaries.sha256.txt

cat /var/work/tests/artifacts/6/binaries.sha256.txt
```

Ambas líneas deben terminar en `: OK`. Si la ruta al binario es distinta de `/usr/bin`,
`command -v` igualmente genera una entrada correcta para `sha256sum -c`.

## Tarea 7. Remediation cycle: de un kube-bench FAIL concreto a PASS

A diferencia de la tarea 1 (una instantánea de todo el informe), aquí hay que vincular un check concreto
con su corrección. `kube-bench` admite una ejecución puntual mediante `--check`, por lo que
no hace falta releer manualmente todo el informe:

```bash
mkdir -p /var/work/tests/artifacts/7

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/before.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/before.txt
# [FAIL] 1.1.1 Ensure that the API server pod specification file permissions ...
```

Comprueba los permisos de acceso reales en el nodo y corrígelos a `600`: es un cambio
file-only, el kubelet no recrea el static Pod por un cambio de permisos, solo por un cambio del
contenido del manifest:

```bash
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 644 /etc/kubernetes/manifests/kube-apiserver.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 600 /etc/kubernetes/manifests/kube-apiserver.yaml
```

La nueva ejecución puntual del mismo check debe mostrar `PASS`:

```bash
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/after.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/after.txt
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions ...
```

Confirma que kube-apiserver sigue sano: cambiar los permisos del archivo no modifica su
contenido, por lo que el kubelet no debe recrear el static Pod.

```bash
k get --raw='/readyz'
k -n kube-system get pods -l component=kube-apiserver
```

## Tarea 8. Remediation cycle: kube-controller-manager

La misma técnica que en la tarea 7, para otro componente y otro check ID (`1.1.3` -
kube-controller-manager pod specification file permissions):

```bash
mkdir -p /var/work/tests/artifacts/8

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/before.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/before.txt
# [FAIL] 1.1.3 Ensure that the controller manager pod specification file permissions ...

ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 644 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-controller-manager.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 600 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/after.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/after.txt
# [PASS] 1.1.3 Ensure that the controller manager pod specification file permissions ...

k -n kube-system get pods -l component=kube-controller-manager
```

## Tarea 9. Remediation cycle: profiling en kube-controller-manager y kube-scheduler

La misma técnica que en las tareas 7-8 (encontrar el `[FAIL]` concreto mediante kube-bench, corregir,
confirmar `[PASS]`), para los checks `1.3.2` (kube-controller-manager profiling) y `1.4.1`
(kube-scheduler profiling). Ambos, igual que toda la sección `1.x`, pertenecen al target `master` en
`cis-1.12`, por lo que no hace falta un `--targets` explícito, exactamente igual que en las tareas 7-8. La tarea 3
ya desactivó profiling solo en kube-apiserver; kubeadm por defecto NO añade
`--profiling=false` a los manifests de kube-controller-manager/kube-scheduler en absoluto.

```bash
mkdir -p /var/work/tests/artifacts/9

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-before.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-before.txt
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-before.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-before.txt
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false ...
```

Corregimos ambos static Pod manifests: la misma técnica que en la tarea 3, solo que para otros dos
componentes:

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-controller-manager.yaml ~/9-controller-manager.yaml
cp /etc/kubernetes/manifests/kube-scheduler.yaml ~/9-scheduler.yaml
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# Añade al array command una línea con la misma indentación que el resto de los argumentos:
# - --profiling=false
vim /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
exit
exit

k -n kube-system get pods -l component=kube-controller-manager
k -n kube-system get pods -l component=kube-scheduler
```

No comprobamos el texto del archivo, sino el Pod realmente en ejecución (el kubelet no recrea el static Pod
al instante tras cambiar el manifest), y la nueva ejecución puntual del mismo check debe
mostrar `PASS`:

```bash
k -n kube-system get pod -l component=kube-controller-manager -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

k -n kube-system get pod -l component=kube-scheduler -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-after.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-after.txt
# [PASS] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-after.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-after.txt
# [PASS] 1.4.1 Ensure that the --profiling argument is set to false ...
```

`jq -e` debe imprimir `true` para ambos componentes, y ambos comandos `k get pods`
de arriba deben mostrar `Running`.

## Tarea 10. Remediation cycle: protect-kernel-defaults en el nodo worker

La misma técnica que en las tareas 7-9, ahora en el nodo worker REAL (no en el control-plane), pero para
OTRO perfil. El `kube-bench 0.16.0`/`cis-1.12` fijado (usado en todas las demás
tareas de este laboratorio) no contiene en absoluto el check protect-kernel-defaults: CIS lo eliminó/
renumeró a partir de esta versión del perfil; el propio `4.2.6` en `cis-1.12` es OTRO
check (`--make-iptables-util-chains`, `PASS` por defecto, no tiene relación
con protect-kernel-defaults). El check necesario con el mismo ID `4.2.6` existe en el perfil más antiguo
`cis-1.24` del mismo binario: usa precisamente ese, con un `--benchmark cis-1.24` explícito, solo
para esta tarea.

A diferencia del control-plane, en el nodo worker `kube-bench` NO está preinstalado: instálalo
aquí por ti mismo (una instalación real, no una copia desde el control-plane o el worker PC): descarga la misma
release fijada de GitHub, desempaqueta `binary` y `cfg` en el default `--config-dir`
(`/etc/kube-bench/cfg`) para no indicar ese flag explícitamente en cada comando:

```bash
WORKER_NODE=$(k get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')

cat <<'EOF' > /tmp/install-kube-bench.sh
KUBE_BENCH_VERSION=0.16.0
arch=$(dpkg --print-architecture)
workdir=$(mktemp -d)
asset="kube-bench_${KUBE_BENCH_VERSION}_linux_${arch}.tar.gz"
base="https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}"
curl -fsSL -o "$workdir/$asset" "$base/$asset"
# La misma técnica que en la tarea 6: contrastamos con una suma publicada de forma independiente, y no con una
# suma calculada a partir del propio archivo.
curl -fsSL -o "$workdir/checksums.txt" "$base/kube-bench_${KUBE_BENCH_VERSION}_checksums.txt"
(cd "$workdir" && grep -E "[[:space:]]${asset}\$" checksums.txt | sha256sum --check --strict -)
tar -xzf "$workdir/$asset" -C "$workdir"
sudo install -d -m 0755 /opt/kube-bench /etc/kube-bench
sudo cp -a "$workdir"/cfg /etc/kube-bench/cfg
sudo install -m 0755 "$workdir/kube-bench" /opt/kube-bench/kube-bench
sudo ln -sf /opt/kube-bench/kube-bench /usr/local/bin/kube-bench
rm -rf "$workdir"
EOF
scp /tmp/install-kube-bench.sh "$WORKER_NODE":/tmp/install-kube-bench.sh
ssh "$WORKER_NODE" 'bash /tmp/install-kube-bench.sh'
ssh "$WORKER_NODE" 'kube-bench version'

mkdir -p /var/work/tests/artifacts/10
ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/before.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/before.txt
# [FAIL] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```

`protectKernelDefaults` no forma parte del `KubeletConfiguration` generado por kubeadm en absoluto:
el campo no existe físicamente (equivalente al default inseguro `false`), por lo que simplemente
añádelo, y no busques una línea existente que reemplazar:

```bash
ssh "$WORKER_NODE" 'echo "protectKernelDefaults: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh "$WORKER_NODE" 'sudo systemctl restart kubelet'
k get node "$WORKER_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

Confirma a través de `/configz` (la configuración realmente aplicada, no el texto del archivo) y
con una nueva ejecución puntual del check:

```bash
k get --raw="/api/v1/nodes/$WORKER_NODE/proxy/configz" \
  | jq -e '.kubeletconfig.protectKernelDefaults == true'

ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/after.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/after.txt
# [PASS] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```
