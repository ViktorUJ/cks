[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 110 - ეტალონური ამოხსნა: gVisor, WireGuard და Istio STRICT

> ვმუშაობთ როგორც გამოცდაზე: `kubectl`, `cilium` და `istioctl` - სამუშაო მანქანაზე, ხოლო ოპერაციები
> node-ზე (containerd, tcpdump) - თავად node-ზე: შედით მასზე `ssh <node>`-ით, გადადით root-ზე
> (`sudo -i`), შეასრულეთ ბრძანებები და გამოდით (`exit`, `exit`). სახელები `gvisor-sandbox`,
> `runc-baseline`, `gvisor-echo`, `market-api`, `market-client`, `mesh-outside` და artifacts-ის გზები
> ლაბის შემოწმებადი კონტრაქტის ნაწილია.

## სად ვიპოვოთ მაგალითები დოკუმენტაციაში

| რა არის საჭირო | გვერდი და განყოფილება |
| :--- | :--- |
| სექცია `runsc` `/etc/containerd/config.toml`-ში (`runtime_type = "io.containerd.runsc.v1"`), containerd-ის გადატვირთვა და `RuntimeClass`-ის YAML `handler: runsc`-ით | [gVisor - Containerd Quick Start: Configure containerd, Restart containerd, Set up the Kubernetes RuntimeClass](https://gvisor.dev/docs/user_guide/containerd/quick_start/) |
| `RuntimeClass`, ველები `scheduling.nodeSelector` და `scheduling.tolerations` | [Kubernetes - Runtime Class: Scheduling](https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling) |
| WireGuard-ის ჩართვა (`encryption.enabled=true`, `encryption.type=wireguard`) და შემოწმება (`cilium-dbg status \| grep Encryption`) | [Cilium - WireGuard Transparent Encryption: Enable WireGuard in Cilium, Validate the Setup](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) |
| `PeerAuthentication` `mtls.mode: STRICT`-ით | [Istio - PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) |

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 1. containerd runtime-ის აღდგენა და RuntimeClass-ის შექმნა

Node `k8s110_node_gvisor` უკვე მიწოდებულია როგორც dedicated pool დაყენებული `runsc`-ით, მაგრამ
bootstrap-მა განზრახ ამოიღო runtime-სექცია `runsc` `/etc/containerd/config.toml`-იდან -
გამოცდის ტიპური სიტუაცია, როცა binary არის, მაგრამ containerd მის შესახებ არაფერი იცის.

```bash
ssh k8s110_node_gvisor
sudo -i
```

```bash
# gVisor-node-ზე (root): binary არის, containerd აქტიურია, კონფიგში სექცია runsc არ არის
runsc --version
systemctl is-active containerd
grep runsc /etc/containerd/config.toml

# დაამატეთ სექცია runsc (runtime_type-ის მნიშვნელობა აუცილებლად ზუსტი უნდა იყოს) და გადატვირთეთ containerd
cat >> /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
systemctl restart containerd
systemctl is-active containerd
grep -A1 runtimes.runsc /etc/containerd/config.toml
exit   # root-იდან
exit   # gVisor-node-იდან
```

Kubelet-ის გადატვირთვა საჭირო არ არის: `RuntimeClass` containerd runtime handler-ს
სახელით იძახებს Pod-ის ყოველი შექმნისას, და არა kubelet-ის გაშვებისას.

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

`scheduling.nodeSelector` - მნიშვნელოვანი საზღვარია: scheduler `runsc` workload-ს არ მიანიჭებს
control-plane-ს, სადაც ასეთი handler არ არის. gVisor-node ამასთან მონიშნულია taint-ით
`sandbox.runtime/gvisor=true:NoSchedule` (`kubectl describe node <gvisor-node> | grep Taints`):
მასზე ვერც ერთი Pod ვერ მოხვდება, გარდა იმათი, რომლებიც მას იტანენ. `scheduling.tolerations` RuntimeClass-ში
ავტომატურად ემატება ამ კლასის ყველა Pod-ს, ამიტომ `gvisor-sandbox` იქ ხვდება,
დანარჩენები - არა.

## 2. sandboxed Pod-ისა და Service-ის გაშვება

`busybox httpd` ერთდროულად იძლევა shell-ს `uname`-ისთვის და პატარა HTTP endpoint-ს
WireGuard-ის node-თაშორისი ცდისთვის. `runtimeClassName` გამოყენებულია Pod-ზე, და არა კონტეინერზე.

`nodeSelector` და `tolerations` Pod-ში აშკარად არის მითითებული: ასე ჩანს, რომელ node-ზე და რატომ ხვდება ის.
ეს იგივეა, რაც თავად `RuntimeClass`-ის `scheduling`-შია აღწერილი. თუ Pod-ში მათ არ მიუთითებთ,
არაფერი გაფუჭდება: `runtimeClassName`-ით Pod-ის შექმნისას Kubernetes თავად **ამატებს** მასში
`nodeSelector`-სა და `tolerations`-ს `RuntimeClass.scheduling`-იდან (შესამოწმებლად: `kubectl -n sandbox-110 get
pod gvisor-sandbox -o jsonpath='{.spec.nodeSelector}'`). მაგრამ მაშინ manifest-ში ეს არ ჩანს, ხოლო RuntimeClass-ში
`scheduling`-ის გარეშე Pod-ს შეეძლო მოხვედრა node-ზე `runsc`-ის გარეშე და ვერ გაშვებულიყო.

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

gVisor Sentry workload-ს უჩვენებს სინთეტიკურ kernel view-ს; `dmesg` შეიძლება შეზღუდული იყოს.
ეს მოსალოდნელია და კონტეინერისთვის ზედმეტი privileges-ის გაცემის მიზეზი არ არის.

## 3. ჩვეულებრივი runc Pod შედარებისთვის

`runtimeClassName`-ის არარსებობა default handler `runc`-ს ტოვებს. Selector განზრახ
ათავსებს ამ Pod-ს control-plane-ზე, ამიტომ შემდეგი დავალებები node-თაშორის
ტრაფიკს აგენერირებენ.

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

ჩვეულებრივი `runc` კონტეინერი ხედავს host kernel release-ს, ხოლო gVisor workload - Sentry view-ს.
ეს შესრულების დამატებითი საზღვარია, და არა `SecurityContext`-ის, seccomp-ის ან
image-ის შემოწმების შემცვლელი.

## 4. Cilium WireGuard-ის ჩართვა

Cilium WireGuard keys-სა და peers-ს თავად მართავს. ვრთავთ დაშიფვრის ერთ backend-ს - IPsec-ს
არ ვამატებთ. მნიშვნელოვანია: **კლიენტურ** `cilium` CLI-ს (დაყენებულია worker-ზე) არ აქვს
ქვებრძანება `encrypt enable`; WireGuard ირთვება Cilium-ის კონფიგურაციით, და არა
runtime-ბრძანებით. ჯერ დავაფიქსიროთ ვერსიები და agent შევადაროთ requirements matrix-ს:

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

კლასტერი განთავსებულია ბრძანებით `cilium install`, რომელიც Cilium-ს აყენებს **Helm-ით**.
გრძელვადიანი source of truth — release `cilium`-ის Helm values; ვიყენებთ pinned Cilium CLI upgrade-ს და მის შემდეგ ვამოწმებთ live ConfigMap-სა და agents-ს:

```bash
cilium upgrade --version 1.20.1 \
  --set encryption.enabled=true --set encryption.type=wireguard --wait
# Helm მხოლოდ ConfigMap-ს ცვლის: DaemonSet-ის შაბლონი არ იცვლება, ამიტომ აგენტები თავად
# არ გადაიტვირთებიან და WireGuard-ის გარეშე აგრძელებენ მუშაობას - გადატვირთეთ ისინი აშკარად.
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
test "$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')" = true
cilium status --wait
```

დაშიფვრის სტატუსს ვკითხულობთ აგენტთან `cilium-dbg`-ით: ეს in-pod debug CLI-ია, რომელიც Cilium agent-ს მოჰყვება. ლოკალური `cilium` CLI რჩება install/cluster-level ინსტრუმენტად და მას Pod-ის შიგნით არ ანაცვლებს. `cilium-dbg status`-ს ფლაგი `--all-encryption` არ აქვს (1.20.x-ში ხელმისაწვდომია მხოლოდ `--all-addresses`, `--all-clusters`, `--all-controllers`, `--all-health`, `--all-nodes`, `--all-redirects`, `--verbose`) - peer/allowed-IP/remote-node evidence-ის დეტალურ მონაცემებს ვიღებთ `cilium-dbg debuginfo --output json`-ით, და არა არარსებული ფლაგით.

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

## 5. node-თაშორისი WireGuard პაკეტის დაჭერა

WireGuard ნაგულისხმევად იყენებს UDP/51871-ს. ფილტრი მხოლოდ `udp port 51871`-ით წინასწარ
გამორიცხავს plaintext TCP-ს შედეგიდან და ამიტომ მის არარსებობას **არ** ამტკიცებს - ამის ნაცვლად
ვიყენებთ ერთსა და იმავე capture scope-ს (`host <remote-node-ip>`, port-ფილტრის გარეშე) და ვადარებთ
WireGuard-ის ჩართვამდე/შემდეგ ერთსა და იმავე node-თაშორის flow-ზე.

Capture `any`-ზე on-wire state-ის დაკვირვების სწორი წერტილი **არ არის**: `any` ხედავს Cilium-ის შიდა
ინტერფეისსაც `cilium_wg0`, რომელზეც გვირაბის კონსტრუქციით უკვე გაშიფრული
ტრაფიკი გადის. დასაჭერია ფიზიკური egress-ინტერფეისი დისტანციურ node-თან (და არა `any`, `cilium_*`,
`lxc*`, `veth*`).

დაგჭირდებათ ორი ტერმინალი: **ტერმინალი 1** - control-plane (იქ `tcpdump`), **ტერმინალი 2** -
სამუშაო მანქანა (მოთხოვნები და `kubectl`).

```bash
# ტერმინალი 2 (სამუშაო მანქანა): gVisor-Pod-იანი node-ის IP - ეს control-plane-ისთვის "დისტანციური" node-ია
gvisor_node=$(kubectl get pod gvisor-sandbox -n sandbox-110 -o jsonpath='{.spec.nodeName}')
remote_ip=$(kubectl get node "$gvisor_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "remote_ip=$remote_ip"
```

```bash
# ტერმინალი 1: შედით control-plane-ზე და გაიგეთ ფიზიკური ინტერფეისი remote_ip-მდე
ssh k8s110_controlPlane_1
sudo -i
```

```bash
# ტერმინალი 1 (control-plane, root): ჩაწერეთ remote_ip-ის მნიშვნელობა ტერმინალი 2-იდან
remote_ip=10.110.2.172
ip route get $remote_ip
# 10.110.2.172 dev ens5 src 10.110.1.x   <- ინტერფეისი (ens5), და არა any / cilium_* / lxc* / veth*
```

**Baseline: WireGuard გამორთულია.** დროებით ვთიშავთ WireGuard-ს და ვიმეორებთ იგივე მოთხოვნას იგივე
capture scope-ით. ბოლოს აუცილებლად დავაბრუნებთ `enable-wireguard: "true"`-ს.

```bash
# ტერმინალი 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# ტერმინალი 1 (control-plane, root): capture 20 წამი, შემდეგ მაშინვე გაუშვით მოთხოვნა ტერმინალი 2-ში
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-baseline.txt
```

```bash
# ტერმინალი 2: სანამ capture მიმდინარეობს (პირველი ~15 წამი)
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# ტერმინალი 1 (capture-ის დასრულების შემდეგ): plaintext marker ჩანს, WireGuard გამორთულია
grep CKS110-WIREGUARD-MARKER /tmp/wireguard-baseline.txt
```

**შემდეგ: WireGuard ჩართულია.** ვაბრუნებთ WireGuard-ს და ვიმეორებთ იგივე მოთხოვნას იგივე capture
scope-ით: ახლა უნდა ჩანდეს WireGuard UDP/51871 და marker არ უნდა იყოს.

```bash
# ტერმინალი 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# ტერმინალი 1 (control-plane, root): capture 20 წამი
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-tcpdump.txt
```

```bash
# ტერმინალი 2: სანამ capture მიმდინარეობს
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# ტერმინალი 1 (capture-ის დასრულების შემდეგ)
grep -E 'UDP' /tmp/wireguard-tcpdump.txt | head -3      # 51871 > 51871: UDP
grep -c CKS110-WIREGUARD-MARKER /tmp/wireguard-tcpdump.txt   # 0
exit   # root-იდან
exit   # control-plane-იდან
```

```bash
# ტერმინალი 2: ავიღოთ capture შესამოწმებლად
scp k8s110_controlPlane_1:/tmp/wireguard-tcpdump.txt /var/work/tests/artifacts/5/wireguard-tcpdump.txt
```

დასკვნა `tcpdump`-ზე Pod netns-ში ნუ გამოიტანთ: იქ ტრაფიკი Cilium encryption point-მდე ჯერ კიდევ შეიძლება
plaintext იყოს. დადასტურება აქ - გადასვლაა ხილული marker-იდან (WireGuard გამორთულია) მის
არარსებობამდე (WireGuard ჩართულია) ერთსა და იმავე capture scope-ზე.

## 6. Istio და PeerAuthentication STRICT

ვაყენებთ მხოლოდ Istio control plane-ს minimal profile-ში. Namespace მომზადებული იყო
`istio-injection=enabled`-ით, ამიტომ workloads `market`-ში შექმნისას იღებენ Envoy sidecar-ს.
`market-api` თავსდება gVisor worker-ზე, client - control-plane-ზე, რაც
მოთხოვნასაც node-თაშორისს ხდის.

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

# Baseline (STRICT ჯერ არ არის გამოყენებული): mesh-ის გარეთ plaintext client-მა უნდა მიიღოს 200 -
# ეს ამტკიცებს, რომ კავშირი პრინციპში მუშაობს და ნებისმიერი შემდგომი უარი
# გამოწვეული იქნება სწორედ STRICT mTLS-ით, და არა დამოუკიდებელი DNS/network-პრობლემით.
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside-baseline.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside-baseline.txt
cat /var/work/tests/artifacts/6/market-outside-baseline.txt
# ველით: HTTP/1.1 200 OK და ბოლოს exit_code=0
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

# მოთხოვნა mesh-ის შიგნიდან (client sidecar-ით)
kubectl exec -n market deploy/market-client -- \
  curl -si --max-time 10 http://market-api \
  > /var/work/tests/artifacts/6/market-inside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-inside.txt
cat /var/work/tests/artifacts/6/market-inside.txt
# ველით: HTTP/1.1 200 OK და ბოლოს exit_code=0

# იგივე მოთხოვნა mesh-ის გარედან (plaintext, sidecar-ის გარეშე)
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside.txt
cat /var/work/tests/artifacts/6/market-outside.txt
# ველით: Recv failure: Connection reset by peer და ბოლოს exit_code=56 (არა 0)
```

`PeerAuthentication` მართავს inbound server mode-ს. შიდა client იღებს
სერტიფიკატს და mTLS-ს ავტომატურად იყენებს; Pod `default`-ში sidecar-ს არ აქვს და აგზავნის
plaintext-ს, ამიტომ Envoy server `STRICT`-ის დროს კავშირს წყვეტს. დაასრულეთ:

```bash
check_result
```
