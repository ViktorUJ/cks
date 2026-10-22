[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 112 - ეტალონური ამოხსნა: Falco, audit-ლოგები და იმუტაბელობა

ვმუშაობთ როგორც გამოცდაზე. გახსენით **ორი ტერმინალი** და ორივე ღია დატოვეთ ლაბის დასრულებამდე:

- **ტერმინალი 1 - control-plane:** `ssh control-plane`, შემდეგ `sudo -i` (შემდგომ node-ზე ყველა ბრძანება
  სრულდება root-ით, `sudo`-ს გარეშე). ერთადერთი control plane node ასევე უშვებს workload-ებს.
- **ტერმინალი 2 - სამუშაო მანქანა:** აქ `kubectl`, `scp` და შემოწმებები.

Artifacts, რომლებიც node-ზეა მიღებული, ინახება `/tmp/art/<დავალების ნომერი>/`-ში control-plane-ზე და
კოპირდება სამუშაო მანქანაზე ბრძანებით `scp` `/var/work/tests/artifacts/<ნომერი>/`-ში.

## სად ვიპოვოთ მაგალითები დოკუმენტაციაში

| რა არის საჭირო | გვერდი და განყოფილება |
| :--- | :--- |
| Falco-ს დაყენება apt-იდან (გასაღები, repository, `apt-get install -y falco`), ცვლადები `FALCO_DRIVER_CHOICE` / `FALCO_FRONTEND`, `systemctl enable falco-modern-bpf.service` | [Falco - Install: apt (Debian/Ubuntu), Environment variables, Systemd setup](https://falco.org/docs/setup/packages/#install-with-apt) |
| Falco-ს წესებისა და მაკროების გადაფარვა (`override: condition/output: replace/append`) | [Falco - Overriding rules: Examples of using the override section](https://falco.org/docs/concepts/rules/overriding/#examples-of-using-the-override-section) |
| Audit Policy (დონეები `None`/`Metadata`/`Request`/`RequestResponse`, `omitStages`, `rules`), ფლაგები `--audit-policy-file`, `--audit-log-path`, `--audit-log-maxage/-maxbackup/-maxsize`, `hostPath`-ის მიმაგრება, webhook backend | [Kubernetes - Auditing: Audit policy, Log backend, Webhook backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) |
| `readOnlyRootFilesystem` და `emptyDir` | [Kubernetes - Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| Deny-all `NetworkPolicy` | [Kubernetes - Network Policies: Default deny all ingress and all egress traffic](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress-traffic) |
| Kyverno `ValidatingPolicy` | [Kyverno - Validating Policies](https://kyverno.io/docs/policy-types/validating-policy/) |

პირველი გაშვება სამუშაო მანქანაზე (ტერმინალი 2):

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5,6,9,10}
```

პირველი გაშვება node-ზე (ტერმინალი 1):

```bash
ssh control-plane
sudo -i
mkdir -p /tmp/art/{2,3,4,6,9,10}
```

## 1. Falco-ს დაყენება modern eBPF-ით

Falco-ს ვაყენებთ ოფიციალური APT-repository-დან (ბრძანებები Falco-ს დოკუმენტაციის Install გვერდიდან).
Modern eBPF არ მოითხოვს kernel module-ის ხელით აწყობას ან ჩატვირთვას.

```bash
# ტერმინალი 1 (control-plane, root)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" >> /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
```

**დაყენება ცალკე ბრძანებით შეასრულეთ:** `apt-get` ასუფთავებს ტერმინალის შეყვანის ბუფერს, ამიტომ
მის უშუალოდ შემდეგ ჩასმული სტრიქონები იკარგება.

```bash
# ტერმინალი 1 (control-plane, root)
FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED='' FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
```

```bash
# ტერმინალი 1 (control-plane, root)
mkdir -p /etc/falco/config.d
cat > /etc/falco/config.d/engine-kind.yaml <<EOF
engine:
  kind: modern_ebpf
EOF
# პაკეტი აყენებს unit falco-modern-bpf.service-ს, ხოლო falco.service მხოლოდ alias-ია მასზე;
# `systemctl enable falco` alias-ით შეცდომით სრულდება, ამიტომ რეალურ unit-ს ვრთავთ.
systemctl enable --now falco-modern-bpf
falco --version; systemctl is-active falco; grep -R modern_ebpf /etc/falco
sleep 20
```

`sleep 20` საჭიროა, რადგან პირველი გაშვებისას modern eBPF probe რამდენიმე
განმეორებითი მცდელობით იხსნება (journal-ში ჩანს რამდენიმე სტრიქონი `Opening 'syscall' source`): სანამ ის
არ გახსნილა, Falco მოვლენებს არ აფიქსირებს, და shell დავალება 2-დან შეიძლება შეუმჩნეველი დარჩეს. თუ
alert არ არის, გაიმეორეთ `exec` რამდენიმე წამის შემდეგ.

თუ სერვისი არ ეშვება, ჯერ ნახეთ `journalctl -u falco-modern-bpf -b --no-pager`.
Engine-ს kernel module-ით ნუ ჩაანაცვლებთ: ამ ლაბში საჭიროა სწორედ `modern_ebpf`.

## 2. სტანდარტული წესი shell-ისთვის კონტეინერში

```bash
# ტერმინალი 2 (სამუშაო მანქანა)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: falco-shell
  namespace: runtime-112
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    stdin: true
    tty: true
EOF
kubectl wait -n "$NS" --for=condition=Ready pod/falco-shell --timeout=120s
kubectl exec -it -n "$NS" falco-shell -- /bin/sh
# shell-ის შიგნით: exit
```

შეინახეთ Falco-ს ნამდვილი მოვლენა: ის იღება journal-იდან control-plane-ზე. Falco წერს მოვლენას
მცირე დაყოვნებით, ამიტომ shell-იდან გამოსვლის შემდეგ რამდენიმე წამი დაელოდეთ. Artifact
ხელით ნუ შექმნით:

```bash
# ტერმინალი 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'A shell was spawned in a container with an attached terminal' | tail -1 > /tmp/art/2/falco-shell.log
cat /tmp/art/2/falco-shell.log
```

```bash
# ტერმინალი 2
scp control-plane:/tmp/art/2/falco-shell.log /var/work/tests/artifacts/2/
```

## 3. ლოკალური წესი და კონტროლირებადი marker

Falco უკვე ტვირთავს `/etc/falco/falco_rules.local.yaml`-ს; წესს სწორედ იქ დავამატებთ.
`spawned_process` ინარჩუნებს თავსებადობას Falco-ს წესებთან, ხოლო `container` არ იძლევა იმავე marker-ის დაჭერის საშუალებას,
რომელიც ჰოსტზე გაეშვა.

```bash
# ტერმინალი 1 (control-plane, root)
cat > /etc/falco/falco_rules.local.yaml <<EOF
- rule: CKS112 Custom Shell Marker
  desc: Detect the controlled CKS lab marker in a container process command line
  condition: spawned_process and container and proc.cmdline contains "CKS112_CUSTOM_EVENT"
  output: "CKS112 custom shell marker container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name command=%proc.cmdline"
  priority: WARNING
EOF
systemctl restart falco && systemctl is-active falco && sleep 10
```

```bash
# ტერმინალი 2
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT >/dev/null'
```

```bash
# ტერმინალი 1
sleep 2
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 custom shell marker' | tail -1 > /tmp/art/3/falco-custom.log
cat /tmp/art/3/falco-custom.log
```

```bash
# ტერმინალი 2
scp control-plane:/tmp/art/3/falco-custom.log /var/work/tests/artifacts/3/
```

ამოხსნაში ყოველი `restart falco`-ის შემდეგ დგას `sleep 10`: Falco წესებსა და კონტეინერების მეტამონაცემებს ტვირთავს
დაახლოებით 5 წამი, და მანამდე მომხდარ მოვლენებს ის journal-ში არ ჩაწერს.

## 4. Audit: RequestResponse ConfigMap-ისთვის, Metadata Secret-ისთვის

შევქმნათ policy თავი 32-ის წესით: სრულ request/response-ს ვწერთ მხოლოდ
არამგრძნობიარე `configmaps`-ისთვის `runtime-112`-ში; `secrets`-ისთვის ვიღებთ `Metadata`-ს, რომ Secret-ის სხეული
(token-ები, პაროლები) ჟურნალში არ მოხვდეს. `None` და `omitStages` მართლაც ამცირებენ high-volume
noise-ს; საბოლოო catch-all `Metadata` - fallback logging-ია, და არა ხმაურის ჩახშობა. წესების თანმიმდევრობა მნიშვნელოვანია:
სპეციფიკური წესები catch-all-მდე მოდის. ფაილის სტრუქტურა - დოკუმენტაციის მაგალითიდანაა (განყოფილება Audit
policy).

```bash
# ტერმინალი 1 (control-plane, root)
cat > /etc/kubernetes/audit/policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
# 1. Noise reduction: high-volume events and health probes are not forensic evidence here.
- level: None
  resources:
  - group: ""
    resources: ["events"]
- level: None
  nonResourceURLs: ["/healthz*", "/livez*", "/readyz*", "/version"]
# 2. ConfigMap: constrained forensic RequestResponse example.
- level: RequestResponse
  namespaces: ["runtime-112"]
  resources:
  - group: ""
    resources: ["configmaps"]
# 3. Secret matters for investigation, but its body must not be logged.
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
# 4. Fallback logging for the rest of the API (not noise reduction).
- level: Metadata
EOF
```

დაარედაქტირეთ `/etc/kubernetes/manifests/kube-apiserver.yaml` control-plane-ზე (`vim`). `kube-apiserver` კონტეინერის `command`-ში
დაამატეთ:

```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log
- --audit-log-maxage=7
- --audit-log-maxbackup=3
- --audit-log-maxsize=100
```

იმავე კონტეინერის `volumeMounts`-ში დაამატეთ:

```yaml
- name: audit-policy
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes/audit
```

`spec.volumes`-ში დაამატეთ:

```yaml
- name: audit-policy
  hostPath:
    path: /etc/kubernetes/audit
    type: Directory
- name: audit-log
  hostPath:
    path: /var/log/kubernetes/audit
    type: DirectoryOrCreate
```

```bash
# ტერმინალი 1 (control-plane, root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

ეს static Pod-ია: kubelet API server-ს ავტომატურად თავიდან შექმნის (დაახლოებით ერთი წუთი, მანამდე
`kubectl` პასუხობს `connection refused`-ით). დაელოდეთ მის მზადყოფნას:

```bash
# ტერმინალი 2: გაიმეორეთ, სანამ ბრძანება არ დააბრუნებს "ok"-ს
kubectl get --raw=/readyz
```

```bash
# ტერმინალი 1: ფლაგები მოხვდა მოქმედ manifest-ში
grep -E -- '--audit-(policy-file|log-path|log-max)' /etc/kubernetes/manifests/kube-apiserver.yaml
```

შექმენით ConfigMap და დააგენერირეთ ორივე მოთხოვნა, შემდეგ შეინახეთ თითო შესაფერისი JSON event
როგორც artifacts:

```bash
# ტერმინალი 2
kubectl create configmap audit-config -n "$NS" --from-literal=note=cks112 --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap audit-config -n "$NS" -o json >/dev/null
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
```

```bash
# ტერმინალი 1 (control-plane, root)
# ConfigMap: სრული RequestResponse event (არამგრძნობიარე მონაცემები).
jq -c 'select(.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-config")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/configmap-request-response.json

# Secret: მხოლოდ Metadata, სხეულის გარეშე.
jq -c 'select(.objectRef.resource == "secrets" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-secret")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/secret-metadata.json
```

```bash
# ტერმინალი 2
scp control-plane:/tmp/art/4/*.json /var/work/tests/artifacts/4/
```

შეამოწმეთ, რომ ConfigMap დალოგილია სხეულით, ხოლო Secret - მხოლოდ `Metadata` დონეზე და
`requestObject`/`responseObject`-ის **გარეშე**:

```bash
# ტერმინალი 2
jq '{level, verb, objectRef, hasBody: (has("requestObject") or has("responseObject"))}' \
  /var/work/tests/artifacts/4/configmap-request-response.json
jq '{level, verb, objectRef, hasRequestObject: has("requestObject"), hasResponseObject: has("responseObject")}' \
  /var/work/tests/artifacts/4/secret-metadata.json
```

## 5. უცვლელი root filesystem

`emptyDir` აპლიკაციას runtime-ფაილებისთვის კონტროლირებად ადგილს აძლევს; root filesystem
რჩება read-only. `hostPath` საჭირო არ არის და დაშვებული არ არის.

```bash
# ტერმინალი 2
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: immutable-app
  namespace: runtime-112
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir: {}
EOF
kubectl wait -n "$NS" --for=condition=Ready pod/immutable-app --timeout=120s
```

დავამტკიცოთ ორივე თვისება და შევინახოთ უარყოფის შეტყობინება:

```bash
# ტერმინალი 2
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /cks-112-write-denied' > /var/work/tests/artifacts/5/rootfs-write-denied.log 2>&1
cat /var/work/tests/artifacts/5/rootfs-write-denied.log
# touch: /cks-112-write-denied: Read-only file system
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed'
```

## 6. containment-ის მინიმალური ჯაჭვი alert-იდან იზოლაციამდე

Audit backend უკვე მუშაობს, ამიტომ ახალი `kubectl exec` API evidence-ს დატოვებს. ვუშვებთ
კონტროლირებად დიდხანს მცხოვრებ პროცესს: marker command line-ში საკმარისად დიდხანს რჩება
`/proc`-ის შესამოწმებლად. production-ში საეჭვო პროცესს ხელახლა არ უშვებენ; აქ ეს
ერთჯერადი ლაბის უსაფრთხო planted evidence-ია.

```bash
# ტერმინალი 1 (control-plane, root): გაშვების დაწყების მომენტი (დროს ვიღებთ control-plane-დან,
# სადაც შემდეგ journal-ს ვკითხულობთ)
START=$(date '+%Y-%m-%d %H:%M:%S')
```

```bash
# ტერმინალი 2
DIR=/var/work/tests/artifacts/6
kubectl exec -n "$NS" falco-shell -- \
  sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT >/tmp/cks112-incident-exec.log 2>&1 &
INCIDENT_EXEC_PID=$!
```

შემდეგ ყველაფერს control-plane-ზე ვაკეთებთ, სანამ პროცესი ცოცხალია: ვიღებთ alert-ს, ხოლო მისგან - container id-სა და
host pid-ს (ვიწყებთ alert-ით და არ ვარაუდობთ):

```bash
# ტერმინალი 1 (control-plane, root)
cd /tmp/art/6
journalctl -u falco-modern-bpf -b --since "$START" --no-pager | grep -F 'CKS112 custom shell marker' | tail -1 > falco-alert.log
cat falco-alert.log

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' falco-alert.log | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' falco-alert.log | tail -1)
echo "SHORT_ID=$SHORT_ID HOST_PID=$HOST_PID"

CONTAINER_ID=$(crictl ps -a -q | grep "^$SHORT_ID" | head -1)
crictl inspect $CONTAINER_ID > cri-container.json
SANDBOX_ID=$(jq -r '.status.sandboxId // .status.sandboxID // .info.sandboxID // empty' cri-container.json)
crictl inspectp $SANDBOX_ID > cri-sandbox.json
printf 'container_init_pid=%s\n' "$(jq -r '.info.pid // empty' cri-container.json)" > cri-mapping.txt

cat /proc/$HOST_PID/status > proc-status.txt
tr '\0' ' ' < /proc/$HOST_PID/cmdline > proc-cmdline.txt; echo >> proc-cmdline.txt
cat /proc/$HOST_PID/cgroup > proc-cgroup.txt
ps -eo pid,ppid,user,lstart,args --forest > process-tree.txt
```

ახლა ვაკორელირებთ API event-ს. თანამედროვე `kubectl exec` მუშაობს WebSocket-ზე, ამიტომ audit-ში ის
ჩანს როგორც `get` (SPDY-fallback-ის დროს - `create`), ორივე ვარიანტი გამოდგება. `pods/exec`-ისთვის საკმარისია
`Metadata`: command request body-დან შეიძლება secret-ს შეიცავდეს, ამიტომ `RequestResponse` აქ საჭირო არ არის.

```bash
# ტერმინალი 1 (control-plane, root)
jq -c 'select(.level == "Metadata" and (.verb == "create" or .verb == "get") and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell")' /var/log/kubernetes/audit/audit.log | tail -1 > audit-exec.json
jq '{verb, level, hasRequestObject: has("requestObject")}' audit-exec.json
```

```bash
# ტერმინალი 2: ჯაჭვის ყველა ფაილის აღება და საბოლოო summary-ის აწყობა
scp 'control-plane:/tmp/art/6/*' /var/work/tests/artifacts/6/

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' "$DIR/falco-alert.log" | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' "$DIR/falco-alert.log" | tail -1)
CONTAINER_ID=$(jq -r '.status.id' "$DIR/cri-container.json")
POD=$(jq -r '.status.metadata.name' "$DIR/cri-sandbox.json")
NAMESPACE=$(jq -r '.status.metadata.namespace' "$DIR/cri-sandbox.json")
NODE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
CONTAINER_INIT_PID=$(jq -r '.info.pid // empty' "$DIR/cri-container.json")

cat > "$DIR/evidence-summary.txt" <<EOF
alert_rule=CKS112 Custom Shell Marker
namespace=$NAMESPACE
pod=$POD
node=$NODE
runtime=containerd
container_id=$CONTAINER_ID
container_init_pid=$CONTAINER_INIT_PID
host_pid=$HOST_PID
audit_verb=$(jq -r .verb "$DIR/audit-exec.json")
audit_subresource=exec
attack_phase=Execution
technique=Container Administration Command
containment=quarantine-and-delete
EOF
cat "$DIR/evidence-summary.txt"
```

ჯერ evidence-ს ვინახავთ, შემდეგ ვაიზოლირებთ namespace-ს ქსელურ დონეზე და ვშლით
კომპრომეტირებულ Pod-ს. ეს containment-ის მინიმალური ჯაჭვია, და არა სრული გამოძიება:
credential revocation/rotation, სხვა workload-ების ძიება და owner/controller-ის აღდგენა
ცალკე IR-პროცესით სრულდება. ბოლო ბრძანება უარყოფით outcome-ს ამტკიცებს, და არ ეძებს შეცდომის კონკრეტულ
ტექსტს.

```bash
# ტერმინალი 2
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: incident-quarantine
  namespace: runtime-112
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress: []
  egress: []
EOF

kubectl delete pod falco-shell -n "$NS" --wait=true
wait "$INCIDENT_EXEC_PID" 2>/dev/null
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT' > "$DIR/post-containment-exec.log" 2>&1
printf 'pod=deleted\nnetworkpolicy=incident-quarantine\nexec_exit=%s\n' "$?" > "$DIR/containment.txt"
cat "$DIR/containment.txt"
# exec_exit=1 (არა 0)
```

## 7. upstream-მაკროს override და გამოტანა JSON-ში/ფაილში

სტანდარტული წესი **Terminal shell in container** ლეგიტიმურ ინსტრუმენტზეც
გააქტიურდება. environment-specific გამონაკლისის სწორი ადგილია არა
თავად წესის რედაქტირება, არამედ სწორედ ამ წესისთვის სპეციალურად გათვალისწინებული upstream-მაკროს override:
`user_expected_terminal_shell_in_container_conditions` (ნაგულისხმევად `(never_true)`, ანუ
გამონაკლისები არ არის). ნუ აგრევთ მას სახელით მსგავს `user_shell_container_exclusions`-თან -
ის ცალკე წესს ეკუთვნის **Run shell untrusted** ("Shell spawned by untrusted
binary") და **Terminal shell in container**-ზე გავლენას არ ახდენს. გამოიყენეთ `k8s.pod.name` და
`k8s.ns.name`, და არა `container.name`: `container.name` - **კონტეინერის** სახელია (აქ
`app`), და არა Pod-ის, და კონტეინერის სახელით დამთხვევა თითქმის ყოველთვის არასწორ ან ძალიან
ფართო allowlist-ს იძლევა.

```bash
# ტერმინალი 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
EOF
systemctl restart falco && sleep 10
```

შექმენით Pod ინტერაქტიული shell-ით სახელით, რომელიც ახლა გამონაკლისია:

```bash
# ტერმინალი 2
kubectl apply -n runtime-112 -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ci-runner
  labels:
    app: ci-runner
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    stdin: true
    tty: true
EOF
kubectl wait -n runtime-112 --for=condition=Ready pod/ci-runner --timeout=60s
kubectl exec -n runtime-112 -it ci-runner -- sh -c 'echo shell-open; sleep 2'
```

ცალკე შეამოწმეთ, რომ `immutable-app` დავალება 5-დან (გამონაკლისის გარეშე) აგრძელებს alert-ის მიცემას - override-მა
წესი მთლიანად ჩუმად არ უნდა ჩააქროს:

```bash
# ტერმინალი 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# ტერმინალი 1
journalctl -u falco-modern-bpf -b --no-pager -n 200 | grep -F 'A shell was spawned in a container with an attached terminal'
```

წესის **Terminal shell in container** სტანდარტული output არ შეიცავს `k8s.pod.name`/
`k8s.ns.name`-ს (control-plane-ზე შეგიძლიათ დარწმუნდეთ: `grep -A3 "rule: Terminal shell in container" /etc/falco/falco_rules.yaml`
აჩვენებს `output`-ს ამ ველების გარეშე). Pod/namespace evidence-ის გარეშე თავად alert-ში კონკრეტული გააქტიურების
კონკრეტულ Pod-თან საიმედო correlation შეუძლებელია - ტექსტური `grep` Pod-ის სახელით journal-ში
უბრალოდ დამთხვევას ვერ იპოვის. ამ ველებს ვამატებთ იმავე `override` მექანიზმით, მაგრამ
`output: append`-ით `condition: replace`-ის ნაცვლად:

```bash
# ტერმინალი 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: Terminal shell in container
  output: ' k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name'
  override:
    output: append
EOF
systemctl restart falco && sleep 10
```

`/etc/falco/config.d/`-ში ჩართეთ JSON-ფორმატი და ფაილური გამოტანა. Falco 0.38+ ნაგულისხმევად
იღებს `config_files`-ს ამ დირექტორიიდან; პირდაპირ `falco.yaml`-ში დამატება ქმნის
დუბლირებულ top-level გასაღებებს განმეორებითი გაშვებისას და პაკეტის განახლებას უარესად უძლებს -
`config.d` განკუთვნილია სწორედ ლოკალური დამატებებისთვის:

```bash
# ტერმინალი 1 (control-plane, root)
mkdir -p /var/log/falco /etc/falco/config.d
cat > /etc/falco/config.d/cks112-output.yaml <<EOF
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
EOF
systemctl restart falco && sleep 10
```

ვადასტურებთ სტრუქტურირებულად, `output_fields`-ით, და არა ტექსტური `grep`-ით Pod-ის სახელზე -
ეს საიმედოდ მუშაობს იმის მიუხედავად, როგორაა ზუსტად დაფორმატებული სტრიქონი `output`:

```bash
# ტერმინალი 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# ტერმინალი 1 (control-plane, root)
sleep 2
tail -n 20 /var/log/falco/events.log \
  | jq -c 'select(.rule == "Terminal shell in container" and .output_fields["k8s.pod.name"] == "immutable-app" and .output_fields["k8s.ns.name"] == "runtime-112")' \
  | tail -1 \
  | jq '{pod: .output_fields["k8s.pod.name"], ns: .output_fields["k8s.ns.name"]}'
# {"pod": "immutable-app", "ns": "runtime-112"}
```

## 8. Audit webhook backend

`audit-receiver` უკვე განთავსებულია საწყისი სკრიპტით. შექმენით webhook kubeconfig, რომელიც
მის Service-ზე მიუთითებს; ლაბისთვის HTTP დასაშვებია, production-ში webhook მოითხოვს HTTPS-სა და client
certificate-ს (თავი 32).

```bash
# ტერმინალი 2: Service audit-receiver-ის ClusterIP
kubectl get svc audit-receiver -n runtime-112 -o jsonpath='{.spec.clusterIP}'; echo
```

```bash
# ტერმინალი 1 (control-plane, root)
RECEIVER_IP=10.111.15.20     # ჩაწერეთ ClusterIP, რომელიც ტერმინალმა 2 გამოიტანა
cat > /etc/kubernetes/audit/webhook-config.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- name: audit-receiver
  cluster:
    server: http://${RECEIVER_IP}:8080/audit
users:
- name: kube-apiserver-audit
  user: {}
contexts:
- name: audit-webhook
  context:
    cluster: audit-receiver
    user: kube-apiserver-audit
current-context: audit-webhook
EOF
```

დაამატეთ webhook-ფლაგები static manifest-ში, დავალება 4-დან უკვე გამართული file backend-ის ფლაგების
**შენარჩუნებით** - webhook ავსებს ლოკალურ ლოგს და არ ანაცვლებს მას:

```bash
# ტერმინალი 1 (control-plane, root)
mkdir -m 700 /etc/kubernetes/backup
cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/backup/kube-apiserver.yaml.pre-webhook
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# დაამატეთ command-ში:
#   - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
#   - --audit-webhook-batch-max-wait=1s
```

დაელოდეთ API-ს აღდგენას და შეასრულეთ აუდირებადი მოთხოვნა:

```bash
# ტერმინალი 2: გაიმეორეთ readyz, სანამ "ok"-ს არ დააბრუნებს, შემდეგ აუდირებადი მოთხოვნა
kubectl get --raw=/readyz
kubectl get configmap audit-config -n runtime-112 -o json >/dev/null
```

შეამოწმეთ, რომ webhook-მა მოვლენა მიმღებს მიაწოდა:

```bash
# ტერმინალი 2
sleep 3
RECEIVER_POD=$(kubectl get pod -n runtime-112 -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n runtime-112 "$RECEIVER_POD" --tail=50 | grep -A5 objectRef
```

შუალედური შემოწმება:

```bash
check_result
```

## 9. ინტეგრაციული დავალება: admission-ის შემოვლა containerd-ით და აღმოჩენა Falco-ით

ეს დავალება აკავშირებს Supply Chain Security-ს (ლაბ 111, თავი 26) ამ ლაბის Runtime Security-სთან:
admission-შემოწმება (Kyverno) კონტეინერს ვერ ხედავს, თუ ის პირდაპირ
containerd-ით არის შექმნილი, kube-apiserver-ის გვერდის ავლით. Falco, admission controller-ისგან განსხვავებით, მუშაობს
kernel syscalls-ის დონეზე და ხედავს node-ზე **ყველა** კონტეინერს იმის მიუხედავად, როგორ იყო ისინი
გაშვებული.

**მნიშვნელოვანია, არ აურიოთ ეს ლაბ 111-თან**: იქ policy ამოწმებს კრიპტოგრაფიულ ხელმოწერას
(Cosign). აქ policy ამოწმებს მხოლოდ registry/repository allowlist-ს - უფრო მარტივ
admission control-ს signature/attestor-ის გარეშე. ორივესთვის საერთო პრინციპი ერთია: admission მუშაობს
მხოლოდ API admission path-ზე.

Lab-owned local registry names მომზადებულია bootstrap-ით (არა საჯარო Docker Hub - ამ დავალების controlled
abuse fixture უნდა იყოს safe და lab-owned, და არ უნდა იყოს დამოკიდებული გარე
registry-ის ხელმისაწვდომობაზე შემოწმების მომენტში). ისინი დევს `/etc/cks112/registry.env`-ში control-plane-ზე; ჩატვირთეთ
ისინი ორივე ტერმინალში:

```bash
# ტერმინალი 1 (control-plane, root)
source /etc/cks112/registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
START_TS=$(date '+%Y-%m-%d %H:%M:%S')     # გაშვების დაწყების მომენტი
install-kyverno
```

```bash
# ტერმინალი 2
scp control-plane:/etc/cks112/registry.env /tmp/cks112-registry.env
source /tmp/cks112-registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
```

(`install-kyverno` - იგივე ვერსიის Kyverno-ა, რაც ლაბ 111-ში.)

ვქმნით native `ValidatingPolicy`-ს trusted registry-ის allowlist-ით. ვიყენებთ Kyverno CEL
Image library-ს (`image(...).registry()`/`.repository()`) ზუსტი შედარებისთვის, და არა
`startsWith`-ს - წინააღმდეგ შემთხვევაში `${CKS112_TRUSTED_REPO}-evil`-იც გაივლიდა policy-ს, რადგან მისი
image string უბრალოდ დაშვებული ქვესტრიქონით იწყება. denial-ის შეტყობინება შეიცავს
უნიკალურ marker-ს `CKS112_TRUSTED_REPO_POLICY`, რომ BATS-მა მოგვიანებით გაარჩიოს სწორედ ეს
policy კლასტერში ნებისმიერი სხვა admission webhook/policy-სგან:

```bash
# ტერმინალი 2
kubectl apply -f - <<YAML
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-trusted-registry-runtime-112
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods", "pods/ephemeralcontainers"]
      operations: ["CREATE", "UPDATE"]
  matchConditions:
  - name: only-runtime-112
    expression: "object.metadata.namespace == 'runtime-112'"
  validations:
  - expression: >
      object.spec.containers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}') &&
      (!has(object.spec.initContainers) || object.spec.initContainers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}')) &&
      (!has(object.spec.ephemeralContainers) || object.spec.ephemeralContainers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}'))
    message: "CKS112_TRUSTED_REPO_POLICY: only ${CKS112_TRUSTED_IMAGE} is allowed in runtime-112"
  validationActions: [Deny]
YAML
```

ვადასტურებთ admission denial-ს allowlist-ის გარეთ არსებული image-ისთვის:

```bash
# ტერმინალი 2 (policy-ის შექმნის შემდეგ დაელოდეთ დაახლოებით 10 წამს)
kubectl apply -n runtime-112 -f - > /var/work/tests/artifacts/9/admission-deny.txt 2>&1 <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: blocked-attempt
spec:
  containers:
  - name: app
    image: ${CKS112_UNTRUSTED_IMAGE}
    imagePullPolicy: IfNotPresent
    command: ["sleep", "60"]
YAML
cat /var/work/tests/artifacts/9/admission-deny.txt
# Error from server: ... CKS112_TRUSTED_REPO_POLICY: only ... is allowed in runtime-112
```

ახლა ვახდენთ იმ გზის სიმულაციას, რომელსაც admission controller ვერ ხედავს: კონტეინერი იქმნება პირდაპირ
container runtime-ში CRI-ით, kube-apiserver-ის მთლიანად გვერდის ავლით. ამისთვის control-plane-ზე არის
helper `cks112-run <image> <id> '<ბრძანება>'` (wrapper `crictl runp/create/start`-ზე) და
`cks112-rm <id>` გასაწმენდად. რატომ არა `ctr run`: `ctr`-ით შექმნილი კონტეინერები
CRI-ისთვის უცნობია, და Falco მათთვის ყოველთვის წერს `container.image.repository = <NA>` - trusted და
untrusted image-ები ერთმანეთისგან გარჩევადი არ იქნებოდა. CRI-ით შექმნილ კონტეინერს Falco image-ით ხედავს.
ყოველი გაშვება იღებს ერთ უნიკალურ სუფიქსს `$RUN_ID`, ხოლო მის მიერ შექმნილი ყველა ID იყენებს
ამ სუფიქსს, ამიტომ განმეორებითი გაშვება წინა მცდელობის ნარჩენებს არ შეეჯახება:

```bash
# ტერმინალი 1 (control-plane, root)
RUN_ID="$(date +%s%N)"
BYPASS_1="cks112-bypass-1-$RUN_ID"
OBSERVE_REPO="cks112-observe-repo-$RUN_ID"
PROBE_ALLOWED="cks112-probe-allowed-$RUN_ID"
BYPASS_2="cks112-bypass-2-$RUN_ID"
PREFIX_TRAP="cks112-prefix-trap-$RUN_ID"

# CKS112_UNTRUSTED_IMAGE bootstrap-ის შემდეგ უკვე არის containerd-ის ლოკალურ საცავში - pull საჭირო არ არის.
cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_1 'echo CKS112_CTR_BYPASS; sleep 5'
```

> `container.id != host` აუცილებელია: ბრძანება `cks112-run ... 'echo CKS112_CTR_BYPASS'` თავად
> ჰოსტზე სრულდება, და მისი command line marker-ს შეიცავს. ამ პირობის გარეშე წესი
> გააქტიურდებოდა გაშვების ჰოსტურ პროცესზე (მისი repository ცარიელია, ანუ trusted-ის ტოლი არ არის),
> და სანდო image-იც კი ცრუ alert-ს მისცემდა.
>
> Falco image-ისთვის აჩვენებს არა იმ ტეგს, რომლითაც კონტეინერია გაშვებული, არამედ ანბანით პირველ
> image-ის სახელს (image-ს შეიძლება რამდენიმე სახელი ჰქონდეს). ამიტომ lab-image-ების სახელები იყენებენ
> registry-ჰოსტს `cks112.local:5000`, რომელიც `docker.io`-ზე ადრე ლაგდება.

სანამ ზუსტ პირობას დავწერთ, ვადგენთ სანდო image-ისთვის `%container.image.repository`-ის რეალურ observed-მნიშვნელობას
ამ containerd/Falco სტეკზე -
წინასწარ მას არ ვვარაუდობთ. სხვადასხვა container runtime/Falco ვერსიას შეუძლია ეს ველი სხვადასხვაგვარად
ჩამოაყალიბოს (registry hostname-ით ან მის გარეშე), ამიტომ ერთადერთი საიმედო
გზა - სანდო კონტეინერის გაშვებაა დროებითი observe-წესით და დაკვირვება, რას
წერს Falco რეალურად:

```bash
# ტერმინალი 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Observe Trusted Repository Value
  desc: Temporary rule to capture the exact observed container.image.repository string for the trusted image
  condition: spawned_process and container.id != host and proc.cmdline contains "CKS112_OBSERVE_REPO"
  output: "CKS112 observed repository=%container.image.repository tag=%container.image.tag"
  priority: INFORMATIONAL
EOF
systemctl restart falco && sleep 10

# CKS112_TRUSTED_IMAGE bootstrap-ის შემდეგ ლოკალურად უკვე არის - pull საჭირო არ არის.
cks112-run $CKS112_TRUSTED_IMAGE $OBSERVE_REPO 'echo CKS112_OBSERVE_REPO; sleep 5'
sleep 3
TRUSTED_REPO=$(journalctl -u falco-modern-bpf -b --no-pager -n 50 | grep -oP 'CKS112 observed repository=\K[^ ]+' | tail -1)
echo "TRUSTED_REPO=$TRUSTED_REPO"
cks112-rm $OBSERVE_REPO
```

შეინახეთ მნიშვნელობა `$TRUSTED_REPO` (მაგალითად `cks112/trusted` ან
`cks112.local:5000/cks112/trusted` - სწორედ ის, რაც თქვენმა Falco/containerd
ვერსიამ რეალურად გამოიტანა) როგორც evidence, რომ ქვემოთ პირობა დაკვირვებულ მნიშვნელობასთან იყოს შემოწმებადად
მიბმული, და არა ვარაუდთან:

```bash
# ტერმინალი 1
echo "$TRUSTED_REPO" > /tmp/art/9/observed-trusted-repo.txt
cat /tmp/art/9/observed-trusted-repo.txt
```

ახლა ვამატებთ საბოლოო წესს დროებითი observe-წესის შემდეგ (`>>`, ფაილის
გადაუწერლად, რომ არ დავკარგოთ წესები დავალებებიდან 3 და 7). პირობა იყენებს დაკვირვებულ `$TRUSTED_REPO`-თან **ზუსტ**
შედარებას, და არა `startswith`/prefix-შემოწმებას:
`not container.image.repository startswith "$TRUSTED_REPO"` გამოტოვებდა (ვერ შეამჩნევდა)
ისეთ repository-ს, როგორიცაა `<TRUSTED_REPO>-evil`, რადგან მისი სახელი უბრალოდ დაშვებული
ქვესტრიქონით იწყება - ანუ Falco მას allowlist-ის ნაწილად ჩათვლიდა, თუმცა რეალურად ის დასაშვები
repository-ს გარეთაა. ეს იგივე ხაფანგია, რომელსაც ზემოთ Kyverno policy თავს არიდებს `==`-ით, და არა
`startsWith`-ით; admission-ის პირობამ და Falco-ს პირობამ ერთი და იგივე repository-თვისება
ერთნაირი (exact) გზით და ერთი და იმავე დაკვირვებული მნიშვნელობით უნდა შეამოწმონ, წინააღმდეგ შემთხვევაში ისინი
security control-ად ექვივალენტური არ არის:

```bash
# ტერმინალი 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Runtime Bypass of Admission
  desc: Process spawned in a container whose image is outside the runtime-112 trusted registry allowlist, indicating a container started outside kube-apiserver/admission (e.g. via crictl/CRI directly)
  condition: >
    spawned_process and
    container.id != host and
    proc.cmdline contains "CKS112_CTR_BYPASS" and
    container.image.repository != "$TRUSTED_REPO"
  output: >
    CKS112 runtime bypass of admission detected
    (command=%proc.cmdline container_id=%container.id
    repo=%container.image.repository tag=%container.image.tag
    pid=%proc.pid ppid=%proc.ppid user=%user.name)
  priority: CRITICAL
  tags: [cks112, supply_chain, admission_bypass]
EOF
systemctl restart falco && sleep 10
```

untrusted-image-ით bypass-ის განმეორებამდე ვამოწმებთ ორივე კონტროლირებად შემთხვევას, რათა
დავამტკიცოთ, რომ შედარება მართლაც ზუსტია, და არა prefix-based. ჯერ სანდო image - მისთვის
alert არ უნდა იყოს (negative control):

```bash
# ტერმინალი 1 (control-plane, root)
cks112-run $CKS112_TRUSTED_IMAGE $PROBE_ALLOWED 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F 'CKS112_CTR_BYPASS' > /tmp/art/9/probe-trusted.log
wc -l < /tmp/art/9/probe-trusted.log        # 0: დაშვებული repository-სთვის alert არ არის
cks112-rm $PROBE_ALLOWED
```

ვშლით პირველ container/task-ს გამეორებამდე, რომ "გაჭედილი" პროცესი არ დავტოვოთ, და
ვუშვებთ მეორეს ახალი უნიკალური ID-ით - მისთვის alert აუცილებელია:

```bash
# ტერმინალი 1 (control-plane, root)
cks112-rm $BYPASS_1

cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_2 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep 'CKS112 runtime bypass of admission' > /tmp/art/9/falco-bypass-attempt.log
cp /tmp/art/9/falco-bypass-attempt.log /tmp/art/9/probe-untrusted.log
cks112-rm $BYPASS_2
```

და ბოლოს, ვამტკიცებთ თავად prefix-trap-ს: repository, აგებული როგორც `${TRUSTED_REPO}-evil`,
იწყება იმავე ქვესტრიქონით, რაც დაშვებული `$TRUSTED_REPO`, მაგრამ მას ზუსტად არ უდრის.
თუ Falco condition იყენებდა `startswith`-ს (როგორც ამ წესის ნაივურ ვარიანტში), ეს image
გაივლიდა შეუმჩნევლად - სწორედ ამიტომ გასწორებულმა პირობამ
`!=` ეს image აუცილებლად უნდა დაიჭიროს. prefix-trap image მომზადებულია bootstrap-ით (`$CKS112_PREFIX_IMAGE`,
ცალკე digest):

```bash
# ტერმინალი 1 (control-plane, root)
cks112-run $CKS112_PREFIX_IMAGE $PREFIX_TRAP 'sleep 2; echo CKS112_CTR_BYPASS; sleep 6'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F "${TRUSTED_REPO}-evil" > /tmp/art/9/probe-prefix.log
cat /tmp/art/9/probe-prefix.log >> /tmp/art/9/falco-bypass-attempt.log
cks112-rm $PREFIX_TRAP
```

```bash
# ტერმინალი 2: დავალება 9-ის ფაილების აღება
scp 'control-plane:/tmp/art/9/*' /var/work/tests/artifacts/9/
```

> **დავალება 9-ის evidence-ფაილების სტრუქტურა.** `falco-bypass-attempt.log` - ძირითადი
> გაერთიანებული artifact-ია, რომელსაც ავტომატური მიღება ამოწმებს (შეიცავს ორივე alert-ს:
> untrusted და prefix-trap, მაგრამ არ უნდა შეიცავდეს alert-ს trusted repo-სთვის). დამატებით
> თითოეული probe წერს საკუთარ ფაილს ხელით დიაგნოსტიკისთვის: `probe-trusted.log` (უნდა იყოს
> ცარიელი - ეს არის negative control), `probe-untrusted.log` და `probe-prefix.log`.

ამ დავალების ძირითადი დასკვნა: registry allowlist admission-ზე და Falco runtime-ზე - ერთმანეთის
შემცვლელი ფენები არ არის, არამედ ურთიერთშემავსებელია. Admission აჩერებს გზას Kubernetes
API-ით, მაგრამ არაფერი იცის პროცესების შესახებ, რომლებიც პირდაპირ container runtime-ით არის გაშვებული node-ზე;
Falco **ვერ დაბლოკავს** ასეთი კონტეინერის შექმნას წინასწარ, მაგრამ ხედავს მას გაშვების შემდეგ,
იმის მიუხედავად, რომელი API (ან მისი არარსებობა) იყო გამოყენებული. იგივე პრინციპი ვრცელდება
signature verification-ზე ლაბ 111-ში - განსხვავება მხოლოდ იმაშია, რომ იქ policy
ამოწმებს ხელმოწერას, აქ კი უბრალოდ registry/repository-ს. დამატებითი დასკვნა
ზემოთ prefix-trap-შემოწმებიდან: Falco condition და Kyverno CEL policy უნდა იყენებდნენ ერთსა და იმავე
შედარების სემანტიკას (`==`/`!=`, და არა `startsWith`/prefix), წინააღმდეგ შემთხვევაში ისინი აღარ არიან
ექვივალენტური security-კონტროლები, თუნდაც ორივე ფორმალურად "იმავე" repository-ს ამოწმებდეს.

## 10. `/dev/mem`-ზე წვდომის აღმოჩენა file/device-open condition-ით

დავალებები 3, 7 და 9 condition-ს აგებდნენ `spawned_process`/`proc.cmdline`-ის გარშემო - აღმოჩენა
პროცესის გაშვებითა და მისი არგუმენტებით. აქ გამოიყენება Falco-ს პირობის პრინციპულად სხვა კლასი:
აღმოჩენა კონკრეტული ფაილის/მოწყობილობის გახსნით, იმის მიუხედავად,
რომელი პროცესი და რა ბრძანების ხაზის არგუმენტებით აკეთებს ამას.

Deployment `mem-scanner` (2 replica) უკვე განთავსებულია bootstrap-ით; ორივე replica პერიოდულად
ხსნის `/dev/mem`-ს კონტეინერის შიგნიდან. გზა `/dev/mem` კონტეინერის შიგნით - synthetic
safe fixture-ია (backing device სინამდვილეში ჰოსტის `/dev/null`-ია, და არა ჰოსტის რეალური ფიზიკური
მეხსიერება); Falco-ს პირობისთვის ფაილის სახელით (`fd.name = /dev/mem`) ეს არ განირჩევა -
წესი აღმოაჩენს თავად სისტემურ გამოძახებას `open`/`openat`/`openat2`. დაამატეთ წესი
`control-plane`-ზე:

```bash
# ტერმინალი 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF
- rule: CKS112 Container access to /dev/mem
  desc: Detect an open of /dev/mem from a container process
  condition: >
    evt.type in (open, openat, openat2) and
    fd.name = /dev/mem and
    container.id != host
  output: >
    CKS112 Container access to /dev/mem
    (container_id=%container.id k8s_pod=%k8s.pod.name k8s_ns=%k8s.ns.name
    proc=%proc.name pid=%proc.pid user=%user.name)
  priority: CRITICAL
  tags: [container, mitre_privilege_escalation, mitre_defense_evasion]
EOF
systemctl restart falco && sleep 10
```

დაელოდეთ `mem-scanner`-ის შემდეგ პერიოდულ ციკლს (ყოველ ~15 წამში) და იპოვეთ
გააქტიურება. Pod-ის იდენტიფიკატორი აიღეთ თავად alert-იდან (`k8s_pod=`), და წინასწარ ნუ გამოიცნობთ,
ორი replica-დან რომელია დამნაშავე - ეს იგივე პრინციპული წესია "დაიწყეთ
alert-ით", რაც დავალება 6-ში:

```bash
# ტერმინალი 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 Container access to /dev/mem' | tail -1 > /tmp/art/10/falco-devmem.log
cat /tmp/art/10/falco-devmem.log
exit   # root-იდან
exit   # control-plane-იდან
```

```bash
# ტერმინალი 2
scp control-plane:/tmp/art/10/falco-devmem.log /var/work/tests/artifacts/10/
```

მას შემდეგ, რაც დარწმუნდებით, რომ აღმოჩენა დადასტურებულია თავად Falco-ს მიერ (და არა Pod manifest-ით), შეინახეთ alert-ში
დასახელებული Pod მასშტაბირებამდე (შენახულ JSON-ში ჩანს owner-ის ჯაჭვი:
Deployment `mem-scanner`-ის ReplicaSet):

```bash
# ტერმინალი 2
ALERT_POD=$(sed -n 's/.*k8s_pod=\([^ ]*\).*/\1/p' /var/work/tests/artifacts/10/falco-devmem.log | tail -1)
echo "$ALERT_POD"
kubectl get pod "$ALERT_POD" -n runtime-112 -o json > /var/work/tests/artifacts/10/detected-pod.json
```

შემდეგ ვაჩერებთ workload-ს:

```bash
# ტერმინალი 2
kubectl scale deployment mem-scanner -n runtime-112 --replicas=0
kubectl get deployment mem-scanner -n runtime-112 -o json > /var/work/tests/artifacts/10/scaled-down.json
jq '.spec.replicas' /var/work/tests/artifacts/10/scaled-down.json
# მოსალოდნელია: 0
```

`container.id != host` პირობაში - დეკორატიული დეტალი არ არის: მის გარეშე წესი გააქტიურდებოდა
node-ის ლეგიტიმურ სისტემურ პროცესებზეც (მაგალითად, მეხსიერების დიაგნოსტიკის ინსტრუმენტებზე),
რომლებიც კონტეინერების გარეთაა გაშვებული, და კლასტერის ყველა node-ზე ხმაურიან false positives-ს შექმნიდა.

ბოლოს გაუშვით `check_result`.
