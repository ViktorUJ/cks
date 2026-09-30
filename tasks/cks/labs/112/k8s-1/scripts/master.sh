#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** control-plane / workload node CKS lab 112 bootstrap"
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

# This is a one-node lab; workloads used to generate Falco events run on the control plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: runtime-112
---
apiVersion: v1
kind: Secret
metadata:
  name: audit-secret
  namespace: runtime-112
type: Opaque
stringData:
  token: cks-112-audit-value
EOF

# Стартовый ресурс для задания 8: HTTP-приёмник audit webhook. Развёрнут заранее, чтобы
# задание фокусировалось на конфигурации webhook backend kube-apiserver, а не на
# создании самого echo-сервера. Digest фиксирует конкретный образ.
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-receiver
  namespace: runtime-112
  labels:
    app: audit-receiver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: audit-receiver
  template:
    metadata:
      labels:
        app: audit-receiver
    spec:
      automountServiceAccountToken: false
      containers:
      - name: receiver
        image: ghcr.io/mendhak/http-https-echo:40
        ports:
        - containerPort: 8080
        env:
        - name: HTTP_PORT
          value: "8080"
---
apiVersion: v1
kind: Service
metadata:
  name: audit-receiver
  namespace: runtime-112
spec:
  selector:
    app: audit-receiver
  ports:
  - name: http
    port: 8080
    targetPort: 8080
EOF

# Falco and audit logging are intentionally not configured. The packages below only make
# the intended administration work reproducible on a fresh Ubuntu control-plane node.
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  ca-certificates curl gpg jq apt-transport-https
install -d -m 0755 /etc/kubernetes/audit /var/log/kubernetes/audit
chmod 0750 /var/log/kubernetes/audit

# Helm и install-kyverno нужны для задания 9 (интеграция с Supply Chain: admission policy
# на trusted registry). Kyverno намеренно НЕ установлен здесь - установка часть задания,
# как в лабе 111.
arch=$(dpkg --print-architecture)
HELM_VERSION="v3.17.3"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
helm_dist="helm-${HELM_VERSION}-linux-${arch}.tar.gz"
helm_url="https://get.helm.sh/${helm_dist}"
curl --fail --location --silent --show-error -o "$workdir/$helm_dist" "$helm_url"
curl --fail --location --silent --show-error -o "$workdir/${helm_dist}.sha256sum" "${helm_url}.sha256sum"
# get.helm.sh's .sha256sum asset is "<hex>  <filename>" (hash plus filename column), so take
# only the first field and compare it with the computed digest.
helm_actual_sha=$(sha256sum "$workdir/$helm_dist" | awk '{print $1}')
helm_expected_sha=$(awk '{print $1}' "$workdir/${helm_dist}.sha256sum")
[[ -n "$helm_expected_sha" && "$helm_actual_sha" == "$helm_expected_sha" ]]
tar -xzf "$workdir/$helm_dist" -C "$workdir"
install -m 0755 "$workdir/linux-${arch}/helm" /usr/local/bin/helm

cat >/usr/local/bin/install-kyverno <<'KYVERNO_EOF'
#!/usr/bin/env bash
set -euo pipefail
# Kyverno 1.19 / chart 3.9.0: та же версия, что в лабе 111.
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --version 3.9.0 \
  --set admissionController.replicas=1 \
  --wait --timeout 5m
KYVERNO_EOF
chmod 0755 /usr/local/bin/install-kyverno

# Task 9's controlled admission-bypass/Falco abuse fixture must be a safe, lab-owned
# fixture isolated from external systems (ADVERSARIAL_ACCEPTANCE_STANDARD.md), not a live
# dependency on Docker Hub reachability at grading time. Pull the two base images once here
# at bootstrap time and retag them under lab-owned repository names; they stay in
# containerd's local content store under the k8s.io namespace, so kubelet (via CRI,
# imagePullPolicy: IfNotPresent) and `crictl` both resolve them from cache afterwards without
# any further network access to docker.io.
install -d -m 0755 /etc/cks112
ctr -n k8s.io images pull docker.io/library/busybox:1.36 >/dev/null
ctr -n k8s.io images pull docker.io/library/alpine:3.20 >/dev/null
ctr -n k8s.io images tag docker.io/library/busybox:1.36 cks112.local:5000/cks112/trusted:1 >/dev/null
ctr -n k8s.io images tag docker.io/library/alpine:3.20 cks112.local:5000/cks112/untrusted:1 >/dev/null

# Direct-to-runtime launcher for task 9. It talks to containerd over CRI (crictl), so the
# container is created WITHOUT kube-apiserver/admission, yet stays visible to Falco's
# container plugin, which resolves image metadata (container.image.repository) only for
# CRI-known containers. `ctr run` containers always show <NA> there. Falco reports the
# alphabetically first name of the image, which is why the lab-owned registry host
# (cks112.local) sorts before docker.io.
cat >/usr/local/bin/cks112-run <<'RUN_EOF'
#!/usr/bin/env bash
# usage: cks112-run <image> <unique-id> '<shell command>'
set -euo pipefail
image=$1; id=$2; cmd=$3
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/pod.json" <<J
{"metadata":{"name":"$id","namespace":"runtime-112","uid":"$id","attempt":1},"log_directory":"/tmp","linux":{"cgroup_parent":"/kubepods.slice/kubepods-besteffort.slice","security_context":{"namespace_options":{"network":2}}}}
J
jq -n --arg id "$id" --arg image "$image" --arg cmd "$cmd" \
  '{metadata:{name:$id},image:{image:$image},command:["sh","-c",$cmd],log_path:($id+".log"),linux:{}}' >"$tmp/ctr.json"
# kubelet treats a sandbox it does not own as an orphan and may remove it between runp and
# start ("can't find shim for sandbox"), so retry the whole sequence with a fresh sandbox.
for attempt in 1 2 3 4 5; do
  if pod=$(crictl runp "$tmp/pod.json" 2>/dev/null) \
     && ctr=$(crictl create "$pod" "$tmp/ctr.json" "$tmp/pod.json" 2>/dev/null) \
     && crictl start "$ctr" >/dev/null 2>&1; then
    echo "$ctr"
    exit 0
  fi
  [[ -n "${pod:-}" ]] && { crictl stopp "$pod" >/dev/null 2>&1 || true; crictl rmp "$pod" >/dev/null 2>&1 || true; }
  pod=""
  sleep 1
done
echo "cks112-run: could not start container for $image" >&2
exit 1
RUN_EOF
cat >/usr/local/bin/cks112-rm <<'RM_EOF'
#!/usr/bin/env bash
# usage: cks112-rm <unique-id>  (removes the sandbox and its container created by cks112-run)
for pod in $(crictl pods --name "^$1\$" -q 2>/dev/null); do
  crictl stopp "$pod" >/dev/null 2>&1 || true
  crictl rmp "$pod" >/dev/null 2>&1 || true
done
exit 0
RM_EOF
chmod 0755 /usr/local/bin/cks112-run /usr/local/bin/cks112-rm

cat >/etc/cks112/registry.env <<'EOF'
export CKS112_REGISTRY='cks112.local:5000'
export CKS112_TRUSTED_REPO='cks112/trusted'
export CKS112_UNTRUSTED_REPO='cks112/untrusted'
export CKS112_TRUSTED_IMAGE='cks112.local:5000/cks112/trusted:1'
export CKS112_UNTRUSTED_IMAGE='cks112.local:5000/cks112/untrusted:1'
EOF
chmod 0644 /etc/cks112/registry.env

install -d -m 0755 /var/work/tests/artifacts/9
install -d -m 0755 /var/work/tests/artifacts/10

# Стартовый ресурс для задания 10: mem-scanner периодически открывает /dev/mem изнутри
# контейнера - обычное application workload не имеет причины делать это. Ресурс
# развёрнут заранее (обнаружение через Falco - часть задания, не создание workload).
# /dev/mem внутри контейнера - synthetic safe fixture: backing device на самом деле
# host /dev/null (ADVERSARIAL_ACCEPTANCE_STANDARD.md запрещает пробрасывать в контейнер
# реальный host /dev/mem без отдельного documented exception). Falco по-прежнему видит
# controlled open/openat/openat2 на fd.name=/dev/mem - для правила достаточно самого
# системного вызова с этим именем файла, независимо от того, какое реальное устройство
# стоит за ним.
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mem-scanner
  namespace: runtime-112
  labels:
    app: mem-scanner
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mem-scanner
  template:
    metadata:
      labels:
        app: mem-scanner
    spec:
      automountServiceAccountToken: false
      containers:
      - name: scanner
        image: busybox:1.36
        command: ["sh", "-c", "while true; do cat /dev/mem >/dev/null 2>&1; sleep 15; done"]
        volumeMounts:
        - name: devmem
          mountPath: /dev/mem
          readOnly: true
      volumes:
      - name: devmem
        hostPath:
          path: /dev/null
          type: CharDevice
EOF

echo "*** CKS lab 112 prerequisites are ready: namespace runtime-112 and audit-secret"
