[Русская версия](CHEATSHEET_RU.md) · [Versión en español](CHEATSHEET_ES.md) · [Version française](CHEATSHEET_FR.md) · [Deutsche Version](CHEATSHEET_DE.md) · [ქართული ვერსია](CHEATSHEET_GE.md) · [繁體中文版](CHEATSHEET_TW.md) · [日本語版](CHEATSHEET_JP.md)

[← Course contents](README.md) · [Glossary](GLOSSARY.md) · [Troubleshooting index (RU)](TROUBLESHOOTING_INDEX_RU.md)

# CKS cheatsheet: ready-to-use YAML and CLI commands

A single file without theory or lengthy explanations: canonical working snippets
from the solutions to course labs `101-114`. Every block identifies its source (lab/task),
so you can find the full explanation in `worker/files/solutions/1.MD`
of the corresponding lab. Use `Ctrl+F`/page search during a lab or exam.

> These snippets were adapted and shortened from lab `101-114` solutions for quick reference
> (variables, indentation, and supporting steps may have been simplified). If something
> differs from the latest lab version, follow that lab’s README/solution.

## How to use this file

- [Decision trees](#decision-trees): when you need to choose the right tool for a task.
- The domain sections below: when you know what you need and want a ready-to-use snippet.
- [Alphabetical index of terms and labs](GLOSSARY.md): for a term/CLI flag linked to a chapter.
- [Symptom reference (RU)](TROUBLESHOOTING_INDEX_RU.md): when something has failed and you need to find the cause quickly.

---

## Decision trees

### Restricting privileges/access: PSA vs ValidatingAdmissionPolicy vs AppArmor vs seccomp

```mermaid
flowchart TD
    A["Task: restrict Pod privileges/access"] --> B{"Where is the control enforced?"}
    B -->|"At API admission"| C{"What is being checked?"}
    C -->|"Standard flags: non-root, drop ALL, no privilege escalation"| D["Pod Security Admission (PSA)<br/>label pod-security.kubernetes.io/enforce=restricted"]
    C -->|"Custom condition: automountServiceAccountToken, labels, custom fields"| E["ValidatingAdmissionPolicy (CEL)<br/>or Kyverno ValidatingPolicy"]
    B -->|"At the node Linux kernel during execution"| F{"Type of restriction"}
    F -->|"Access to files, paths, network sockets"| G["AppArmor Profile<br/>spec.securityContext.appArmorProfile"]
    F -->|"System calls (syscalls)"| H["Seccomp Profile<br/>spec.securityContext.seccompProfile"]
    F -->|"Loading kernel modules on a node"| I["modprobe blacklist /etc/modprobe.d/"]
    B -->|"Isolate the workload kernel from the host"| J["Container runtime sandbox (gVisor/Kata)<br/>RuntimeClass handler: runsc"]
```

### Traffic encryption: NetworkPolicy vs CNI encryption vs mTLS mesh

```mermaid
flowchart TD
    A["Task: protect Pod-to-Pod traffic"] --> B{"What is needed?"}
    B -->|"Restrict WHO can connect (L3/L4)"| C["Kubernetes NetworkPolicy"]
    B -->|"L3/L4 plus HTTP method/path or another L7 condition (Cilium only)"| C2["CiliumNetworkPolicy"]
    B -->|"Encrypt traffic BETWEEN nodes transparently to applications"| D["Cilium WireGuard/IPsec transparent encryption<br/>ConfigMap enable-wireguard / Helm encryption.enabled"]
    B -->|"Require mTLS and identity-based authentication BETWEEN services"| E["Service mesh (Istio) PeerAuthentication STRICT"]
    C --> C3["Kubernetes NetworkPolicy: L3/L4 only,<br/>without HTTP/protocol-content awareness"]
    D --> F["Does not verify application identity,<br/>only protects traffic at the node level"]
    E --> G["Does not replace NetworkPolicy.<br/>Lab110 uses sidecar mode.<br/>Modern Istio also supports ambient mode (ztunnel)"]
```

### Supply chain: scanning vs signatures vs provenance/attestations vs SBOM vs admission enforcement

```mermaid
flowchart TD
    A["Task: secure an image supply chain"] --> B{"Which property must be proven?"}
    B -->|"Known OS/library vulnerabilities"| C["trivy image --scanners vuln"]
    B -->|"Package inventory, not vulnerabilities"| D["SBOM: bom generate (SPDX) / syft (CycloneDX)"]
    B -->|"Signature matches digest and trusted key/identity"| E["cosign sign / cosign verify"]
    B -->|"How and from what the image was built: provenance/attestation"| E2["cosign attest / cosign verify-attestation"]
    B -->|"Mandatory condition for cluster admission"| F{"What is checked at admission?"}
    F -->|"Signature (Cosign)"| G["Kyverno ImageValidatingPolicy<br/>verifyImageSignatures"]
    F -->|"Registry/repository allowlist"| H["Kyverno ValidatingPolicy CEL<br/>image().registry()/.repository() == exact"]
    C --> I["Does not prove origin, only known CVEs"]
    D --> J["Does not prove safety, only inventory"]
    E --> K["cosign verify proves signature/identity,<br/>NOT provenance, a separate claim (E2)"]
    E --> L["Local cosign verify in CI does not block kubectl apply.<br/>Admission enforcement (F) is required for that"]
```

### Runtime detection: audit logs vs Falco vs both

```mermaid
flowchart TD
    A["Task: detect/investigate a runtime event"] --> B{"What happened?"}
    B -->|"Kubernetes API request: kubectl/API client"| C["Audit log<br/>RequestResponse/Metadata by resource"]
    B -->|"System call inside a container/on a node"| D["Falco<br/>condition on spawned_process/proc.cmdline/container.*"]
    B -->|"Action bypassing kube-apiserver: direct ctr/crictl"| E["Visible to Falco,<br/>NOT to the audit log: different observation layers"]
    C --> F["Request-level evidence:<br/>who/when/verb/result, NOT continuous configuration-state monitoring"]
    D --> G["Syscall-level evidence:<br/>actual process behavior at event time"]
```

---

## 1. Cluster Setup

### NetworkPolicy: AND, OR, and `ipBlock.except`
*Source: lab 101, task 6.*

AND: both selectors in the same `from` item:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-ingress-from-legacy
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101-legacy
          podSelector:
            matchLabels:
              app: legacy-client
      ports:
        - protocol: TCP
          port: 8080
```

OR: separate `from` items (different from AND above):

```yaml
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101-legacy
        - podSelector:
            matchLabels:
              app: legacy-client
```

`ipBlock` with an exception (for example, the node metadata endpoint):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-legacy-egress
  namespace: cks-101-legacy
spec:
  podSelector:
    matchLabels:
      app: legacy-client
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32
```

### CiliumNetworkPolicy: L3/L4/L7
*Source: lab 102, task 3.*

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/"
```

### kube-bench: running and interpreting output
*Source: lab 103, task 1.*

```bash
mkdir -p /var/work/tests/artifacts/1
scp -r /opt/kube-bench control-plane:/tmp/kube-bench
ssh control-plane 'sudo rm -rf /opt/kube-bench && sudo mv /tmp/kube-bench /opt/kube-bench'
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,controlplane,node' \
  | tee /var/work/tests/artifacts/1/kube-bench.txt
grep -E '\[(PASS|WARN|FAIL)\]' /var/work/tests/artifacts/1/kube-bench.txt | head
```

> Pinned `kube-bench 0.16.0` has no profile newer than `cis-1.12` (its built-in
> `version_mapping` ends at `"1.34": "cis-1.12"`). Specify this profile explicitly
> instead of relying on autodetection, and mark results for newer Kubernetes versions
> as `forced-approximate`.

---

## 2. Cluster Hardening

### RBAC: minimal Role and RoleBinding
*Source: lab 104, task 1.*

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: auditor
  namespace: security-104
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-observer
  namespace: security-104
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: auditor-pod-observer
  namespace: security-104
subjects:
- kind: ServiceAccount
  name: auditor
  namespace: security-104
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-observer
```

### ServiceAccount without automatic token mounting
*Source: lab 104, task 3.*

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-token-sa
  namespace: security-104
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: no-token
  namespace: security-104
spec:
  serviceAccountName: no-token-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

### Secret volume: `defaultMode: 0400` (= `256` decimal)
*Source: lab 104, task 6.*

> `kubectl get pod -o json` displays `defaultMode: 0400` as decimal `256`. Writing
> `defaultMode: 400` (without a leading zero) means decimal `400`, NOT octal `0400`/`256`:
> a common exam mistake.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-vulnerable
  namespace: security-104
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: db-creds-vol
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: db-creds-vol
    secret:
      secretName: db-creds
      defaultMode: 0400
```

### kubeadm minor upgrade: control plane first, workers afterward
*Source: lab 113, tasks 1-2.*

> Order matters: finish the ENTIRE control-plane upgrade (including uncordon) before
> upgrading a worker, or you violate the version skew policy. On the control plane use
> `kubeadm upgrade apply`; on workers use `kubeadm upgrade node` (not `apply`).
> `pkgs.k8s.io` has a separate apt repository for each minor version. Switch
> `sources.list.d/kubernetes.list` to the target minor BEFORE `apt install kubeadm`.

```bash
# Switch the repository to the target minor (example: 1.36)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -qq

# Control plane: update kubeadm, inspect the plan, run the upgrade
sudo apt-mark unhold kubeadm && sudo apt-get install -y --allow-change-held-packages kubeadm && sudo apt-mark hold kubeadm
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.36.1 -y

# Only AFTER successful apply: drain -> update kubelet/kubectl -> restart -> uncordon
kubectl drain <control-plane-node> --ignore-daemonsets --delete-emptydir-data
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y --allow-change-held-packages kubelet kubectl && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon <control-plane-node>

# Worker (after control plane is Ready on target version): kubeadm upgrade NODE, not apply
sudo kubeadm upgrade node
```

---

## 3. System Hardening

### AppArmor: load a profile and assign it to a Pod
*Source: lab 106, tasks 2 and 8.*

```bash
ssh control-plane 'sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile'
ssh control-plane 'sudo aa-status | grep k8s-106-broken-profile'
```

The current field is `spec.securityContext.appArmorProfile` (NOT the old beta annotation `container.apparmor.security.beta.kubernetes.io/...`):

```yaml
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

### Seccomp: Localhost JSON profile and Pod reference
*Source: lab 106, tasks 4-5.*

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["unshare"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
```

```yaml
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
    command: ["sh", "-c", "sleep 3600"]
```

> `localhostProfile` is always relative to the kubelet seccomp root (usually
> `/var/lib/kubelet/seccomp/`), not an absolute file path.

---

## 4. Minimize Microservice Vulnerabilities

### Pod Security Admission: `restricted`
*Source: lab 107, task 1.*

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

### ValidatingAdmissionPolicy + Binding: CEL for `automountServiceAccountToken`
*Source: lab 107, task 6.*

> `allowPrivilegeEscalation: false` and `capabilities.drop: ["ALL"]` are already covered by PSA
> `restricted` above and deliberately NOT duplicated in this VAP. Here CEL is used only for
> a custom condition that PSA does not check.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-no-automount-token
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: >-
      has(object.spec.automountServiceAccountToken) &&
      object.spec.automountServiceAccountToken == false
    message: "spec.automountServiceAccountToken must be explicitly set to false"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-no-automount-token-binding
spec:
  policyName: require-no-automount-token
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: psa-restricted-107
```

### EncryptionConfiguration: encrypting Secrets in etcd (`aescbc`)
*Source: lab 109, task 2.*

```bash
umask 077
key=$(head -c 32 /dev/urandom | base64 -w0)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
```

> Provider order matters: the first provider handles NEW writes; later providers
> only read old records. A final `identity: {}` allows reading existing
> unencrypted Secrets until full re-encryption.

### gVisor: containerd `runsc` and RuntimeClass
*Source: lab 110, task 1.*

```bash
ssh k8s110_node_gvisor 'sudo tee -a /etc/containerd/config.toml > /dev/null <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
sudo systemctl restart containerd'
```

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox.runtime/gvisor: "true"
```

### Cilium WireGuard: enabling transparent encryption
*Source: lab 110, task 4.*

Helm-managed installation:

```bash
helm upgrade cilium cilium/cilium -n kube-system --reuse-values \
  --set encryption.enabled=true --set encryption.type=wireguard
```

ConfigMap-based installation (when there is no Helm release):

```bash
kubectl -n kube-system patch configmap cilium-config --type merge \
  -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
```

### Istio PeerAuthentication: `STRICT` mTLS
*Source: lab 110, task 6.*

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: market-strict
  namespace: market
spec:
  mtls:
    mode: STRICT
```

---

## 5. Supply Chain Security

### Trivy: JSON image scan
*Source: lab 111, task 1.*

```bash
trivy image --scanners vuln --vuln-type os,library --format json \
  --output trivy-report.json "$IMAGE"
```

### Trivy: complete package list
*Source: lab 111, task 5.*

```bash
trivy image --list-all-pkgs --format json "$IMAGE" > packages.json
jq -r '[.Results[].Packages[]? | "\(.Name)=\(.Version)"] | unique | .[:3][]' packages.json
```

### SBOM: SPDX with `bom`, CycloneDX with `syft`
*Source: lab 111, tasks 6-7.*

```bash
bom generate --format json --output bom.spdx.json --image "$IMAGE"
syft "$IMAGE" -o "cyclonedx-json=syft.cdx.json"
```

### `trivy sbom`: scanning an existing SBOM file
*Source: lab 111, task 8.*

```bash
trivy sbom --format json --output sbom-scan.json bom.spdx.json
```

> Use `trivy sbom <file>`, NOT `trivy image <file>`; the path is passed as an SBOM, not as
> image reference.

### Cosign: key generation, signing, verification (key-based and keyless)
*Source: lab 111, tasks 7, 9a, 9c.*

```bash
cosign generate-key-pair
cosign sign --key cosign.key --yes "$HARDENED_IMAGE"
cosign verify --key cosign.pub "$HARDENED_IMAGE"
```

Keyless verification of a public OIDC-signed artifact:

```bash
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static:nonroot
```

### Kyverno ImageValidatingPolicy: Cosign signature verification at admission
*Source: lab 111, task 9a.*

```yaml
apiVersion: policies.kyverno.io/v1
kind: ImageValidatingPolicy
metadata:
  name: require-signed-catalog-images
spec:
  failurePolicy: Fail
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  matchImageReferences:
  - glob: "${HARDENED_REPO}*"
  attestors:
  - name: catalogReleaseKey
    cosign:
      key:
        data: |-
          <indented cosign.pub PEM>
  validations:
  - message: "catalog image must have a valid release signature"
    expression: >-
      (images.containers + images.?initContainers.orValue([]) +
      images.?ephemeralContainers.orValue([])).map(image,
        verifyImageSignatures(image, [attestors.catalogReleaseKey]) > 0).all(ok, ok)
```

### Kyverno ValidatingPolicy: exact registry/repository allowlist (not prefix matching)
*Source: lab 112, task 9.*

> Use exact `==`, not `startsWith`/prefix matching. Otherwise `library/busybox-evil` passes
> the policy simply because its name STARTS with the permitted string.

```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-trusted-registry-runtime-112
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods"]
      operations: ["CREATE"]
  matchConditions:
  - name: only-runtime-112
    expression: "object.metadata.namespace == 'runtime-112'"
  validations:
  - expression: >
      object.spec.containers.all(c,
        image(c.image).registry() == 'docker.io' &&
        image(c.image).repository() == 'library/busybox')
    message: "CKS112_TRUSTED_REPO_POLICY: only docker.io/library/busybox is allowed in runtime-112"
  validationActions: [Deny]
```

---

## 6. Monitoring, Logging & Runtime Security

### AuditPolicy: correct rule order
*Source: lab 112, task 4.*

> Order matters: the API server applies the FIRST matching rule from top to bottom. Specific
> rules must precede the general catch-all at the end.

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
# 1. Noise reduction for high-volume/low-risk events
- level: None
  resources:
  - group: ""
    resources: ["events"]
- level: None
  nonResourceURLs: ["/healthz*", "/livez*", "/readyz*", "/version"]
# 2. Specific rule: complete ConfigMaps (body is not sensitive)
- level: RequestResponse
  namespaces: ["runtime-112"]
  resources:
  - group: ""
    resources: ["configmaps"]
# 3. Secrets: Metadata only, to avoid logging secret bodies
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
# 4. Fallback logging for the remaining API (must be LAST)
- level: Metadata
```

### Falco: custom rule (condition/output/priority)
*Source: lab 112, task 3.*

```yaml
- rule: CKS112 Custom Shell Marker
  desc: Detect the controlled CKS lab marker in a container process command line
  condition: spawned_process and container and proc.cmdline contains "CKS112_CUSTOM_EVENT"
  output: "CKS112 custom shell marker container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name command=%proc.cmdline"
  priority: WARNING
```

### Falco: override the `user_expected_terminal_shell_in_container_conditions` macro
*Source: lab 112, task 7.*

```yaml
- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
```

> This differs from `user_shell_container_exclusions` (which belongs to another rule,
> **Run shell untrusted**). The similar macro names are easy to confuse.

### Falco: JSON and file output
*Source: lab 112, task 7.*

```yaml
# /etc/falco/config.d/output.yaml
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
```

### `crictl`: correlating an alert with a Pod/namespace
*Source: lab 112, task 6.*

```bash
# 1. Short container ID and host PID have already been extracted from the Falco alert
CONTAINER_ID=$(sudo crictl ps -a -q | awk "/^${SHORT_ID}/ {print; exit}")
sudo crictl inspect "$CONTAINER_ID" > cri-container.json
SANDBOX_ID=$(jq -r '.status.sandboxId' cri-container.json)
sudo crictl inspectp "$SANDBOX_ID" > cri-sandbox.json
POD=$(jq -r '.status.metadata.name' cri-sandbox.json)
NAMESPACE=$(jq -r '.status.metadata.namespace' cri-sandbox.json)
```

### `/proc/<PID>/`: navigating during an investigation
*Source: lab 112, task 6.*

```bash
sudo cat /proc/$HOST_PID/status
sudo tr '\0' ' ' </proc/$HOST_PID/cmdline; echo
sudo cat /proc/$HOST_PID/cgroup
sudo ps -eo pid,ppid,user,lstart,args --forest
```

> Collect these artifacts WHILE the process is alive. After its Pod is deleted,
> the corresponding `/proc/<PID>` disappears permanently.

### Immutable root filesystem with writable `/tmp`
*Source: lab 112, task 5.*

```yaml
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
```

---

[← Course contents](README.md) · [Glossary](GLOSSARY.md) · [Troubleshooting index (RU)](TROUBLESHOOTING_INDEX_RU.md)
