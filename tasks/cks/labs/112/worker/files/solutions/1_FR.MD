[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 112 - solution de référence : Falco, audit-logs et immutabilité

Nous travaillons comme à l'examen. Ouvrez **deux terminaux** et laissez-les ouverts tous les deux jusqu'à la fin du lab :

- **Terminal 1 - control-plane :** `ssh control-plane`, puis `sudo -i` (ensuite, toutes les commandes sur le nœud
  s'exécutent en root, sans `sudo`). L'unique nœud de control plane exécute aussi les workloads.
- **Terminal 2 - machine de travail :** c'est ici que se trouvent `kubectl`, `scp` et les vérifications.

Les artefacts obtenus sur le nœud sont enregistrés dans `/tmp/art/<numéro de la tâche>/` sur le control-plane et
copiés sur la machine de travail avec la commande `scp` vers `/var/work/tests/artifacts/<numéro>/`.

## Où trouver des exemples dans la documentation

| Ce qu'il faut | Page et section |
| :--- | :--- |
| Installation de Falco depuis apt (clé, dépôt, `apt-get install -y falco`), variables `FALCO_DRIVER_CHOICE` / `FALCO_FRONTEND`, `systemctl enable falco-modern-bpf.service` | [Falco - Install: apt (Debian/Ubuntu), Environment variables, Systemd setup](https://falco.org/docs/setup/packages/#install-with-apt) |
| Override des règles et des macros de Falco (`override: condition/output: replace/append`) | [Falco - Overriding rules: Examples of using the override section](https://falco.org/docs/concepts/rules/overriding/#examples-of-using-the-override-section) |
| Audit Policy (niveaux `None`/`Metadata`/`Request`/`RequestResponse`, `omitStages`, `rules`), flags `--audit-policy-file`, `--audit-log-path`, `--audit-log-maxage/-maxbackup/-maxsize`, montage `hostPath`, webhook backend | [Kubernetes - Auditing: Audit policy, Log backend, Webhook backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) |
| `readOnlyRootFilesystem` et `emptyDir` | [Kubernetes - Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| `NetworkPolicy` deny-all | [Kubernetes - Network Policies: Default deny all ingress and all egress traffic](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress-traffic) |
| Kyverno `ValidatingPolicy` | [Kyverno - Validating Policies](https://kyverno.io/docs/policy-types/validating-policy/) |

Premier lancement sur la machine de travail (terminal 2) :

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5,6,9,10}
```

Premier lancement sur le nœud (terminal 1) :

```bash
ssh control-plane
sudo -i
mkdir -p /tmp/art/{2,3,4,6,9,10}
```

## 1. Installation de Falco avec modern eBPF

Nous installons Falco depuis le dépôt APT officiel (les commandes proviennent de la page Install de la documentation
de Falco). Modern eBPF n'exige ni compilation ni chargement manuel d'un kernel module.

```bash
# terminal 1 (control-plane, root)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" >> /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
```

**Exécutez l'installation comme une commande distincte :** `apt-get` vide le tampon d'entrée du terminal, donc
les lignes collées juste après disparaissent.

```bash
# terminal 1 (control-plane, root)
FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED='' FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
```

```bash
# terminal 1 (control-plane, root)
mkdir -p /etc/falco/config.d
cat > /etc/falco/config.d/engine-kind.yaml <<EOF
engine:
  kind: modern_ebpf
EOF
# Le paquet installe l'unit falco-modern-bpf.service, et falco.service n'est qu'un alias vers elle ;
# `systemctl enable falco` via l'alias échoue avec une erreur, donc on active l'unit réelle.
systemctl enable --now falco-modern-bpf
falco --version; systemctl is-active falco; grep -R modern_ebpf /etc/falco
sleep 20
```

`sleep 20` est nécessaire parce qu'au premier lancement la modern eBPF probe s'ouvre avec plusieurs
tentatives répétées (dans le journal, on voit plusieurs lignes `Opening 'syscall' source`) : tant qu'elle n'est pas
ouverte, Falco ne consigne pas d'événements, et le shell de la tâche 2 peut passer inaperçu. S'il n'y a
pas d'alert, répétez l'`exec` quelques secondes plus tard.

Si le service ne démarre pas, regardez d'abord `journalctl -u falco-modern-bpf -b --no-pager`.
Ne remplacez pas l'engine par un kernel module : ce lab exige précisément `modern_ebpf`.

## 2. Règle standard pour un shell dans un conteneur

```bash
# terminal 2 (machine de travail)
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
# Dans le shell : exit
```

Enregistrez le véritable événement de Falco : il est pris dans le journal du control-plane. Falco écrit l'événement avec
un petit délai, donc attendez quelques secondes après être sorti du shell. Ne créez pas l'artefact
à la main :

```bash
# terminal 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'A shell was spawned in a container with an attached terminal' | tail -1 > /tmp/art/2/falco-shell.log
cat /tmp/art/2/falco-shell.log
```

```bash
# terminal 2
scp control-plane:/tmp/art/2/falco-shell.log /var/work/tests/artifacts/2/
```

## 3. Règle locale et marker contrôlé

Falco charge déjà `/etc/falco/falco_rules.local.yaml` ; c'est précisément là que nous ajoutons la règle.
`spawned_process` préserve la compatibilité avec les règles de Falco, et `container` empêche de
matcher le même marker lancé sur l'hôte.

```bash
# terminal 1 (control-plane, root)
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
# terminal 2
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT >/dev/null'
```

```bash
# terminal 1
sleep 2
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 custom shell marker' | tail -1 > /tmp/art/3/falco-custom.log
cat /tmp/art/3/falco-custom.log
```

```bash
# terminal 2
scp control-plane:/tmp/art/3/falco-custom.log /var/work/tests/artifacts/3/
```

Après chaque `restart falco`, la solution contient un `sleep 10` : Falco charge les règles et les métadonnées des
conteneurs en environ 5 secondes, et les événements survenus avant cela, il ne les écrira pas dans le journal.

## 4. Audit : RequestResponse pour ConfigMap, Metadata pour Secret

Créons la policy selon la règle du chapitre 32 : le request/response complet n'est consigné que pour
`configmaps` (non sensible) dans `runtime-112` ; pour `secrets`, nous prenons `Metadata`, afin que le corps du Secret
(tokens, mots de passe) n'arrive pas dans le journal. `None` et `omitStages` réduisent réellement le high-volume
noise ; le catch-all final `Metadata` est du fallback logging, et non de la suppression de bruit. L'ordre des règles est important :
les règles spécifiques passent avant le catch-all. La structure du fichier vient de l'exemple de la documentation (section Audit
policy).

```bash
# terminal 1 (control-plane, root)
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

Modifiez `/etc/kubernetes/manifests/kube-apiserver.yaml` sur le control-plane (`vim`). Dans la `command`
du conteneur `kube-apiserver`, ajoutez :

```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log
- --audit-log-maxage=7
- --audit-log-maxbackup=3
- --audit-log-maxsize=100
```

Dans les `volumeMounts` du même conteneur, ajoutez :

```yaml
- name: audit-policy
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes/audit
```

Dans `spec.volumes`, ajoutez :

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
# terminal 1 (control-plane, root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

C'est un static Pod : le kubelet recréera automatiquement l'API server (environ une minute, jusque-là
`kubectl` répond `connection refused`). Attendez qu'il soit prêt :

```bash
# terminal 2 : répétez jusqu'à ce que la commande renvoie "ok"
kubectl get --raw=/readyz
```

```bash
# terminal 1 : les flags figurent bien dans le manifest actif
grep -E -- '--audit-(policy-file|log-path|log-max)' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Créez le ConfigMap et générez les deux requêtes, puis enregistrez un JSON event approprié pour chacune
comme artefacts :

```bash
# terminal 2
kubectl create configmap audit-config -n "$NS" --from-literal=note=cks112 --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap audit-config -n "$NS" -o json >/dev/null
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
```

```bash
# terminal 1 (control-plane, root)
# ConfigMap : RequestResponse event complet (données non sensibles).
jq -c 'select(.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-config")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/configmap-request-response.json

# Secret : uniquement Metadata, sans corps.
jq -c 'select(.objectRef.resource == "secrets" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-secret")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/secret-metadata.json
```

```bash
# terminal 2
scp control-plane:/tmp/art/4/*.json /var/work/tests/artifacts/4/
```

Vérifiez que le ConfigMap est journalisé avec son corps, et que le Secret ne l'est qu'au niveau `Metadata` et
**sans** `requestObject`/`responseObject` :

```bash
# terminal 2
jq '{level, verb, objectRef, hasBody: (has("requestObject") or has("responseObject"))}' \
  /var/work/tests/artifacts/4/configmap-request-response.json
jq '{level, verb, objectRef, hasRequestObject: has("requestObject"), hasResponseObject: has("responseObject")}' \
  /var/work/tests/artifacts/4/secret-metadata.json
```

## 5. Root filesystem immuable

`emptyDir` donne à l'application un emplacement contrôlé pour les fichiers de runtime ; le root filesystem
reste read-only. `hostPath` n'est pas nécessaire et n'est pas admis.

```bash
# terminal 2
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

Démontrons les deux propriétés et enregistrons le message de refus :

```bash
# terminal 2
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /cks-112-write-denied' > /var/work/tests/artifacts/5/rootfs-write-denied.log 2>&1
cat /var/work/tests/artifacts/5/rootfs-write-denied.log
# touch: /cks-112-write-denied: Read-only file system
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed'
```

## 6. Chaîne minimale de containment de l'alert à l'isolation

L'audit backend fonctionne déjà, donc un nouveau `kubectl exec` laissera une API evidence. Nous lançons
un processus contrôlé de longue durée : le marker reste dans la command line suffisamment longtemps pour
la vérification de `/proc`. En production, on ne relance pas un processus suspect ; ici, c'est une
planted evidence sûre d'un lab jetable.

```bash
# terminal 1 (control-plane, root) : moment du début de l'exécution (on prend l'heure sur le control-plane,
# où l'on lira ensuite le journal)
START=$(date '+%Y-%m-%d %H:%M:%S')
```

```bash
# terminal 2
DIR=/var/work/tests/artifacts/6
kubectl exec -n "$NS" falco-shell -- \
  sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT >/tmp/cks112-incident-exec.log 2>&1 &
INCIDENT_EXEC_PID=$!
```

Ensuite, nous faisons tout sur le control-plane tant que le processus est vivant : nous prenons l'alert et nous en extrayons le container id et le
host pid (nous partons de l'alert, sans deviner) :

```bash
# terminal 1 (control-plane, root)
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

Maintenant, nous corrélons l'API event. Le `kubectl exec` moderne fonctionne par-dessus WebSocket, donc dans l'audit, il
apparaît comme `get` (en cas de SPDY-fallback - `create`) ; les deux variantes conviennent. Pour `pods/exec`, il suffit de
`Metadata` : la command du request body peut contenir un secret, donc `RequestResponse` n'est pas nécessaire ici.

```bash
# terminal 1 (control-plane, root)
jq -c 'select(.level == "Metadata" and (.verb == "create" or .verb == "get") and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell")' /var/log/kubernetes/audit/audit.log | tail -1 > audit-exec.json
jq '{verb, level, hasRequestObject: has("requestObject")}' audit-exec.json
```

```bash
# terminal 2 : récupérer tous les fichiers de la chaîne et constituer le summary final
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

D'abord, nous enregistrons l'evidence, puis nous isolons le namespace au niveau réseau et supprimons le
Pod compromis. C'est une chaîne de containment minimale, et non une investigation complète :
la credential revocation/rotation, la recherche d'autres workloads et la restauration de l'owner/controller relèvent
d'un processus IR distinct. La dernière commande démontre un outcome négatif, et ne cherche pas un
texte d'erreur précis.

```bash
# terminal 2
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
# exec_exit=1 (pas 0)
```

## 7. Override d'une macro upstream et sortie en JSON/fichier

La règle standard **Terminal shell in container** se déclenchera aussi sur un outil
légitime. L'endroit correct pour une exception environment-specific n'est pas la modification de
la règle elle-même, mais l'override de la macro upstream réservée précisément à cette règle :
`user_expected_terminal_shell_in_container_conditions` (par défaut `(never_true)`, c'est-à-dire
qu'il n'y a pas d'exceptions). Ne la confondez pas avec `user_shell_container_exclusions`, de nom proche -
celle-ci relève de la règle distincte **Run shell untrusted** (« Shell spawned by untrusted
binary ») et n'influe pas sur **Terminal shell in container**. Utilisez `k8s.pod.name` et
`k8s.ns.name`, et non `container.name` : `container.name` est le nom du **conteneur** (ici
`app`), et non du Pod, et la correspondance par le nom du conteneur donne presque toujours un allowlist incorrect ou trop
large.

```bash
# terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
EOF
systemctl restart falco && sleep 10
```

Créez un Pod avec un shell interactif sous le nom qui est désormais exclu :

```bash
# terminal 2
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

Vérifiez séparément que `immutable-app` de la tâche 5 (sans exception) continue à produire un alert - l'override
ne doit pas éteindre silencieusement toute la règle :

```bash
# terminal 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# terminal 1
journalctl -u falco-modern-bpf -b --no-pager -n 200 | grep -F 'A shell was spawned in a container with an attached terminal'
```

L'output standard de la règle **Terminal shell in container** ne contient pas `k8s.pod.name`/
`k8s.ns.name` (on peut s'en assurer sur le control-plane : `grep -A3 "rule: Terminal shell in container" /etc/falco/falco_rules.yaml`
montrera l'`output` sans ces champs). Sans l'evidence de Pod/namespace dans l'alert lui-même, une corrélation fiable
d'un déclenchement précis avec un Pod précis est impossible - un `grep` textuel sur le nom du Pod dans le journal
ne trouvera tout simplement aucune correspondance. Nous ajoutons ces champs par le même mécanisme `override`, mais avec
`output: append` au lieu de `condition: replace` :

```bash
# terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: Terminal shell in container
  output: ' k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name'
  override:
    output: append
EOF
systemctl restart falco && sleep 10
```

Dans `/etc/falco/config.d/`, activez le format JSON et la sortie fichier. Falco 0.38+ prend par défaut
en compte les `config_files` de ce répertoire ; ajouter directement dans `falco.yaml` crée des
clés top-level en double lors d'une nouvelle exécution et survit moins bien à la mise à jour du paquet -
`config.d` est destiné précisément aux ajouts locaux :

```bash
# terminal 1 (control-plane, root)
mkdir -p /var/log/falco /etc/falco/config.d
cat > /etc/falco/config.d/cks112-output.yaml <<EOF
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
EOF
systemctl restart falco && sleep 10
```

Nous confirmons de façon structurée, via `output_fields`, et non par un `grep` textuel sur le nom du Pod -
cela fonctionne de manière fiable, quelle que soit la façon dont la ligne `output` est formatée :

```bash
# terminal 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# terminal 1 (control-plane, root)
sleep 2
tail -n 20 /var/log/falco/events.log \
  | jq -c 'select(.rule == "Terminal shell in container" and .output_fields["k8s.pod.name"] == "immutable-app" and .output_fields["k8s.ns.name"] == "runtime-112")' \
  | tail -1 \
  | jq '{pod: .output_fields["k8s.pod.name"], ns: .output_fields["k8s.ns.name"]}'
# {"pod": "immutable-app", "ns": "runtime-112"}
```

## 8. Audit webhook backend

`audit-receiver` est déjà déployé par le script de démarrage. Créez un webhook kubeconfig pointant
vers son Service ; pour le lab, HTTP est admis, en production le webhook exige HTTPS et un client
certificate (chapitre 32).

```bash
# terminal 2 : ClusterIP du Service audit-receiver
kubectl get svc audit-receiver -n runtime-112 -o jsonpath='{.spec.clusterIP}'; echo
```

```bash
# terminal 1 (control-plane, root)
RECEIVER_IP=10.111.15.20     # saisissez le ClusterIP affiché par le terminal 2
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

Ajoutez les flags webhook dans le static manifest, en **conservant** les flags du file backend déjà configurés
à la tâche 4 - le webhook complète le log local, et ne le remplace pas :

```bash
# terminal 1 (control-plane, root)
mkdir -m 700 /etc/kubernetes/backup
cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/backup/kube-apiserver.yaml.pre-webhook
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Ajouter dans command :
#   - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
#   - --audit-webhook-batch-max-wait=1s
```

Attendez le rétablissement de l'API et exécutez une requête auditable :

```bash
# terminal 2 : répétez readyz jusqu'à ce qu'il renvoie "ok", puis la requête auditable
kubectl get --raw=/readyz
kubectl get configmap audit-config -n runtime-112 -o json >/dev/null
```

Vérifiez que le webhook a livré l'événement au récepteur :

```bash
# terminal 2
sleep 3
RECEIVER_POD=$(kubectl get pod -n runtime-112 -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n runtime-112 "$RECEIVER_POD" --tail=50 | grep -A5 objectRef
```

Vérification intermédiaire :

```bash
check_result
```

## 9. Tâche d'intégration : contournement de l'admission via containerd et détection via Falco

Cette tâche relie Supply Chain Security (lab 111, chapitre 26) au Runtime Security de ce
lab : la vérification d'admission (Kyverno) ne voit pas un conteneur s'il est créé directement via
containerd, en contournant kube-apiserver. Falco, à la différence de l'admission controller, travaille au
niveau des kernel syscalls et voit **tous** les conteneurs du nœud, quelle que soit la manière dont ils ont été
lancés.

**Il est important de ne pas la confondre avec le lab 111** : là-bas, la policy vérifie la signature cryptographique
(Cosign). Ici, la policy ne vérifie que le registry/repository allowlist - un admission
control plus simple, sans signature/attestor. Le principe général est le même pour les deux : l'admission ne fonctionne
que sur l'API admission path.

Les noms du lab-owned local registry sont préparés par le bootstrap (pas le Docker Hub public - le controlled
abuse fixture de cette tâche doit être safe et lab-owned, et ne pas dépendre de la disponibilité d'un
registry externe au moment de la vérification). Ils se trouvent dans `/etc/cks112/registry.env` sur le control-plane ; chargez-les
dans les deux terminaux :

```bash
# terminal 1 (control-plane, root)
source /etc/cks112/registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
START_TS=$(date '+%Y-%m-%d %H:%M:%S')     # moment du début de l'exécution
install-kyverno
```

```bash
# terminal 2
scp control-plane:/etc/cks112/registry.env /tmp/cks112-registry.env
source /tmp/cks112-registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
```

(`install-kyverno` est la même version de Kyverno que dans le lab 111.)

Nous créons une `ValidatingPolicy` native avec un allowlist sur le trusted registry. Nous utilisons la Kyverno CEL
Image library (`image(...).registry()`/`.repository()`) pour une comparaison exacte, et non
`startsWith` - sinon `${CKS112_TRUSTED_REPO}-evil` passerait aussi la policy, parce que son
image string commence simplement par la sous-chaîne autorisée. Le message de denial contient le
marqueur unique `CKS112_TRUSTED_REPO_POLICY`, afin que BATS puisse plus tard distinguer précisément cette
policy de toute autre admission webhook/policy du cluster :

```bash
# terminal 2
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

Nous confirmons l'admission denial pour une image hors de l'allowlist :

```bash
# terminal 2 (attendez environ 10 secondes après la création de la policy)
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

Maintenant, nous simulons le chemin que l'admission controller ne voit pas : le conteneur est créé directement
dans le container runtime via CRI, en contournant entièrement kube-apiserver. Pour cela, le control-plane dispose
du helper `cks112-run <image> <id> '<commande>'` (une surcouche de `crictl runp/create/start`) et de
`cks112-rm <id>` pour le nettoyage. Pourquoi pas `ctr run` : les conteneurs créés via `ctr` ne sont pas
connus de CRI, et Falco écrit toujours pour eux `container.image.repository = <NA>` - les images trusted et
untrusted seraient indiscernables. Un conteneur créé via CRI, Falco le voit avec son image.
Chaque lancement reçoit un suffixe unique `$RUN_ID`, et tous les ID qu'il a créés utilisent
ce suffixe, donc une nouvelle exécution n'entrera pas en collision avec les restes de la tentative précédente :

```bash
# terminal 1 (control-plane, root)
RUN_ID="$(date +%s%N)"
BYPASS_1="cks112-bypass-1-$RUN_ID"
OBSERVE_REPO="cks112-observe-repo-$RUN_ID"
PROBE_ALLOWED="cks112-probe-allowed-$RUN_ID"
BYPASS_2="cks112-bypass-2-$RUN_ID"
PREFIX_TRAP="cks112-prefix-trap-$RUN_ID"

# CKS112_UNTRUSTED_IMAGE est déjà dans le stockage local de containerd après le bootstrap - pas besoin de pull.
cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_1 'echo CKS112_CTR_BYPASS; sleep 5'
```

> `container.id != host` est obligatoire : la commande `cks112-run ... 'echo CKS112_CTR_BYPASS'` est elle-même
> lancée sur l'hôte, et sa command line contient le marker. Sans cette condition, la règle
> se déclencherait sur le processus hôte de lancement (son repository est vide, c'est-à-dire différent de trusted),
> et même une image de confiance donnerait un faux alert.
>
> Falco affiche pour l'image non pas le tag avec lequel le conteneur est lancé, mais, par ordre alphabétique, le premier
> nom d'image (une image peut avoir plusieurs noms). C'est pourquoi les noms des images du lab utilisent
> l'hôte de registry `cks112.local:5000`, qui est trié avant `docker.io`.

Avant d'écrire la condition exacte, nous déterminons la valeur RÉELLEMENT observée de
`%container.image.repository` pour l'image de confiance sur cette stack containerd/Falco -
sans la présumer à l'avance. Différentes versions de container runtime/Falco peuvent former
ce champ différemment (avec ou sans le hostname du registry), donc la seule façon fiable est de
lancer un conteneur de confiance avec une règle d'observation temporaire et de regarder ce que
Falco écrit réellement :

```bash
# terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Observe Trusted Repository Value
  desc: Temporary rule to capture the exact observed container.image.repository string for the trusted image
  condition: spawned_process and container.id != host and proc.cmdline contains "CKS112_OBSERVE_REPO"
  output: "CKS112 observed repository=%container.image.repository tag=%container.image.tag"
  priority: INFORMATIONAL
EOF
systemctl restart falco && sleep 10

# CKS112_TRUSTED_IMAGE est déjà disponible localement après le bootstrap - pas besoin de pull.
cks112-run $CKS112_TRUSTED_IMAGE $OBSERVE_REPO 'echo CKS112_OBSERVE_REPO; sleep 5'
sleep 3
TRUSTED_REPO=$(journalctl -u falco-modern-bpf -b --no-pager -n 50 | grep -oP 'CKS112 observed repository=\K[^ ]+' | tail -1)
echo "TRUSTED_REPO=$TRUSTED_REPO"
cks112-rm $OBSERVE_REPO
```

Enregistrez la valeur `$TRUSTED_REPO` (par exemple `cks112/trusted` ou
`cks112.local:5000/cks112/trusted` - précisément ce que votre version de Falco/containerd a réellement
affiché) comme evidence, afin que la condition ci-dessous soit rattachée de façon vérifiable à la valeur observée,
et non à une supposition :

```bash
# terminal 1
echo "$TRUSTED_REPO" > /tmp/art/9/observed-trusted-repo.txt
cat /tmp/art/9/observed-trusted-repo.txt
```

Maintenant, nous ajoutons la règle finale à la suite de la règle d'observation temporaire (`>>`, sans
écraser le fichier, pour ne pas perdre les règles des tâches 3 et 7). La condition utilise une comparaison **exacte**
avec le `$TRUSTED_REPO` observé, et non une vérification `startswith`/prefix :
`not container.image.repository startswith "$TRUSTED_REPO"` laisserait passer (ne remarquerait pas)
un repository comme `<TRUSTED_REPO>-evil`, parce que son nom COMMENCE simplement par la sous-chaîne
autorisée - c'est-à-dire que Falco le considérerait comme faisant partie de l'allowlist, alors qu'en réalité il est hors du
repository admissible. C'est le même piège qu'évite la Kyverno policy ci-dessus via `==`, et non
`startsWith` ; la condition d'admission et la condition de Falco doivent vérifier la même propriété du repository
de la même manière (exacte) et avec la même valeur observée, sinon elles
ne sont pas équivalentes en tant que security control :

```bash
# terminal 1 (control-plane, root)
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

Avant de répéter le bypass avec l'image untrusted, nous vérifions les deux cas contrôlés, afin de
démontrer que la comparaison est réellement exacte, et non prefix-based. D'abord l'image de confiance - pour
elle, il ne doit pas y avoir d'alert (negative control) :

```bash
# terminal 1 (control-plane, root)
cks112-run $CKS112_TRUSTED_IMAGE $PROBE_ALLOWED 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F 'CKS112_CTR_BYPASS' > /tmp/art/9/probe-trusted.log
wc -l < /tmp/art/9/probe-trusted.log        # 0 : pas d'alert pour le repository autorisé
cks112-rm $PROBE_ALLOWED
```

Nous retirons le premier container/task avant la répétition, pour ne pas laisser un processus « suspendu », et
nous lançons le second avec un nouvel ID unique - pour lui, l'alert est obligatoire :

```bash
# terminal 1 (control-plane, root)
cks112-rm $BYPASS_1

cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_2 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep 'CKS112 runtime bypass of admission' > /tmp/art/9/falco-bypass-attempt.log
cp /tmp/art/9/falco-bypass-attempt.log /tmp/art/9/probe-untrusted.log
cks112-rm $BYPASS_2
```

Enfin, nous démontrons le prefix-trap lui-même : un repository construit comme `${TRUSTED_REPO}-evil`
COMMENCE par la même sous-chaîne que le `$TRUSTED_REPO` autorisé, mais ne lui est pas exactement égal.
Si la Falco condition utilisait `startswith` (comme dans la variante naïve
de cette règle), cette image passerait INAPERÇUE - c'est précisément pourquoi la condition corrigée
`!=` doit l'attraper. L'image prefix-trap est préparée par le bootstrap (`$CKS112_PREFIX_IMAGE`,
avec un digest distinct) :

```bash
# terminal 1 (control-plane, root)
cks112-run $CKS112_PREFIX_IMAGE $PREFIX_TRAP 'sleep 2; echo CKS112_CTR_BYPASS; sleep 6'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F "${TRUSTED_REPO}-evil" > /tmp/art/9/probe-prefix.log
cat /tmp/art/9/probe-prefix.log >> /tmp/art/9/falco-bypass-attempt.log
cks112-rm $PREFIX_TRAP
```

```bash
# terminal 2 : récupérer les fichiers de la tâche 9
scp 'control-plane:/tmp/art/9/*' /var/work/tests/artifacts/9/
```

> **Structure des fichiers d'evidence de la tâche 9.** `falco-bypass-attempt.log` est l'artefact
> combiné principal, que contrôlent les tests d'acceptation automatiques (il contient les deux alerts :
> untrusted et prefix-trap, mais ne doit pas contenir d'alert pour le trusted repo). De plus,
> chaque probe écrit son propre fichier pour le diagnostic manuel : `probe-trusted.log` (doit être
> vide - c'est le negative control), `probe-untrusted.log` et `probe-prefix.log`.

La conclusion clé de cette tâche : le registry allowlist à l'admission et Falco au runtime ne sont pas des
couches interchangeables, mais complémentaires. L'admission arrête le chemin via la Kubernetes
API, mais ne sait rien des processus lancés directement via le container runtime sur le nœud ;
Falco ne peut pas **bloquer** à l'avance la création d'un tel conteneur, mais le voit après
son lancement, quelle que soit l'API (ou son absence) utilisée. Le même principe
s'applique à la signature verification du lab 111 - la seule différence est que là-bas, la policy
vérifie la signature, et ici simplement le registry/repository. Une conclusion supplémentaire issue de la
vérification prefix-trap ci-dessus : la Falco condition et la Kyverno CEL policy doivent utiliser la MÊME
sémantique de comparaison (`==`/`!=`, et non `startsWith`/prefix), sinon elles cessent d'être
des contrôles de sécurité équivalents, même si les deux vérifient formellement « le même » repository.

## 10. Détecter l'accès à `/dev/mem` via une file/device-open condition

Les tâches 3, 7 et 9 construisaient la condition autour de `spawned_process`/`proc.cmdline` - détection
par le LANCEMENT d'un processus et ses arguments. Ici, on utilise une classe de
condition Falco fondamentalement différente : la détection par l'OUVERTURE d'un fichier/périphérique précis, indépendamment de
l'identité du processus qui le fait et de ses arguments de ligne de commande.

Le Deployment `mem-scanner` (2 répliques) est déjà déployé par le bootstrap ; les deux répliques ouvrent périodiquement
`/dev/mem` depuis l'intérieur du conteneur. Le chemin `/dev/mem` dans le conteneur est un synthetic
safe fixture (le backing device est en réalité le `/dev/null` de l'hôte, et non la mémoire physique
réelle de l'hôte) ; pour la condition Falco par nom de fichier (`fd.name = /dev/mem`), c'est indiscernable -
c'est l'appel système `open`/`openat`/`openat2` lui-même qui est détecté. Ajoutez la règle sur le
`control-plane` :

```bash
# terminal 1 (control-plane, root)
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

Attendez le prochain cycle périodique de `mem-scanner` (toutes les ~15 secondes) et trouvez le
déclenchement. Prenez l'identifiant du Pod DANS l'alert lui-même (`k8s_pod=`), et ne devinez pas à l'avance
laquelle des deux répliques est coupable - c'est la même règle de principe « commencez par
l'alert » que dans la tâche 6 :

```bash
# terminal 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 Container access to /dev/mem' | tail -1 > /tmp/art/10/falco-devmem.log
cat /tmp/art/10/falco-devmem.log
exit   # de root
exit   # du control-plane
```

```bash
# terminal 2
scp control-plane:/tmp/art/10/falco-devmem.log /var/work/tests/artifacts/10/
```

Après vous être assuré que la détection est confirmée par Falco lui-même (et non par le Pod manifest), enregistrez le Pod
nommé dans l'alert avant le scaling (dans le JSON enregistré, la chaîne d'owner contiendra un ReplicaSet
appartenant au Deployment `mem-scanner`) :

```bash
# terminal 2
ALERT_POD=$(sed -n 's/.*k8s_pod=\([^ ]*\).*/\1/p' /var/work/tests/artifacts/10/falco-devmem.log | tail -1)
echo "$ALERT_POD"
kubectl get pod "$ALERT_POD" -n runtime-112 -o json > /var/work/tests/artifacts/10/detected-pod.json
```

Ensuite, nous arrêtons le workload :

```bash
# terminal 2
kubectl scale deployment mem-scanner -n runtime-112 --replicas=0
kubectl get deployment mem-scanner -n runtime-112 -o json > /var/work/tests/artifacts/10/scaled-down.json
jq '.spec.replicas' /var/work/tests/artifacts/10/scaled-down.json
# attendu : 0
```

`container.id != host` dans la condition n'est pas un détail décoratif : sans cette condition, la règle se déclencherait
aussi sur des processus système légitimes du nœud (par exemple, des outils de diagnostic de la mémoire),
lancés hors des conteneurs, en créant de bruyants false positives sur chaque nœud du cluster.

À la fin, exécutez `check_result`.
