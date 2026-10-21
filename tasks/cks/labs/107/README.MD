[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 107 - Pod Security Admission: restricted, audit/warn, and a read-only root filesystem

## Goal

In this CKS lab you configure the built-in **Pod Security Admission (PSA)** through
namespace labels. For the production namespace, `restricted` will be enabled in the
`enforce` mode, the rejection of an insecure Pod will be checked, and a passing hardened Pod will be deployed.
For a separate namespace you will enable the observing modes `audit` and `warn` of the level
`baseline`. Finally, the root filesystem of the container will become read-only, and the single
required write will be allowed into an `emptyDir`.

Work only with the objects from the tasks. The empty namespaces
`psa-restricted-107`, `psa-observe-107`, and `psa-controller-107` have been created in the cluster in advance; there are no PSA labels or workloads in them.

## Self-check before you start

<details>
<summary>1. How does `enforce` differ from `audit`/`warn` in Pod Security Admission?</summary>

`enforce` really blocks the creation of a Pod that violates the chosen PSS level - the admission request fails with an error. `audit`/`warn` do NOT block the request: the Pod is still created, but `audit` adds an annotation to the kube-apiserver audit log, and `warn` shows the user a text warning on `kubectl apply`. These are different levels of responsibility: `audit`/`warn` are for observation before enabling real blocking; `enforce` is the protection itself.
</details>

<details>
<summary>2. Why must the `*-version` label be pinned for a namespace together with the PSS level?</summary>

Without a pinned version (`enforce-version`) PSA will use the current Kubernetes version on every check - if the cluster is upgraded, the set of `restricted`/`baseline` rules may change without you noticing, and a Pod that passed yesterday may start being rejected today without any action of yours. Pinning the version makes the behavior predictable and reproducible regardless of future cluster upgrades.
</details>

<details>
<summary>3. Why does the `ValidatingAdmissionPolicy` from task 6 not duplicate PSA but complement it?</summary>

PSS `restricted` defines a fixed, standardized set of security fields (non-root, capabilities, seccomp, escalation). `automountServiceAccountToken` is NOT part of this set - PSA does not check it at all. This means a Pod can be fully compatible with `restricted` and still silently receive a mounted API token that it does not need. A custom `ValidatingAdmissionPolicy` closes exactly this gap, without trying to replace or duplicate what PSA already does.
</details>

## Infrastructure

The environment is deployed via Terragrunt in AWS `eu-central-1`:

| Component | Purpose |
|---|---|
| `vpc` | VPC `10.10.0.0/16` with public subnets |
| `ssh-keys` | SSH keys for access to the machines |
| `k8s-1` | a single-node kubeadm Kubernetes `1.36.0` cluster, containerd, and **Calico** |
| `worker` | a work machine with `kubectl`, the context `cluster1-admin@cluster1`, and `check_result` |

The control-plane accepts regular Pods, so a separate Kubernetes worker node is not
needed. All the tasks are performed on the work machine.

## Deployment

```bash
TASK=107 make run_cks_task
```

Connect to the work machine over SSH and check access to the cluster:

```bash
time_left
kubectl get nodes
check_result
```

## Tasks

---
| **1** | **Enforce restricted with a pinned version** |
| :---: | :--- |
| What to do | On the namespace `psa-restricted-107` set `pod-security.kubernetes.io/enforce=restricted` and `pod-security.kubernetes.io/enforce-version=v1.36`. Make sure that PSA really rejects an insecure Pod: a server-side dry-run of a Pod with `hostNetwork: true` in this namespace must fail with an error containing `violates PodSecurity`. Do not change the labels of the system namespaces. |
| Acceptance criteria | Both enforce labels have the exact values; the insecure Pod does not pass admission in `psa-restricted-107`; the system namespaces `kube-system`, `kube-public`, and `kube-node-lease` do not get `pod-security.kubernetes.io/*` labels within this lab. |

<details>
<summary>💡 Hint for task 1</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36` - both labels take effect instantly; PSA does not require restarting anything. Check yourself via `kubectl apply --dry-run=server` with `hostNetwork: true` - specifically `--dry-run=server` (not `client`), because admission controllers, including PSA, work only on the server side.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

First the baseline - BEFORE setting the labels make sure that the same insecure manifest
passes (otherwise it is unclear whether the denial is caused by your enforce label or by something else):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "baseline exit: $?"
```

Set both labels, then repeat THE SAME manifest - now there must be an admission error
with the text `violates PodSecurity`:

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "after-label exit: $?"
```
</details>

---
| **2** | **A hardened Pod that passes restricted** |
| :---: | :--- |
| What to do | Create a Pod `restricted-app` in `psa-restricted-107` from `busybox:1.36`, running as non-root and not exiting immediately. Set the pod-level `runAsNonRoot: true`, `runAsUser: 1000`, and `seccompProfile: RuntimeDefault`. In the container securityContext forbid privilege escalation, drop the capability `ALL`, explicitly leave `privileged: false`, and set `seccompProfile: RuntimeDefault`. |
| Acceptance criteria | The Pod is accepted by PSA and running; it runs as UID 1000/non-root, and no container/init/ephemeral container overrides the pod-level `runAsUser: 1000`; seccomp is `RuntimeDefault`; escalation and privileged are forbidden; the capabilities `ALL` are dropped. |

<details>
<summary>💡 Hint for task 2</summary>

If the Pod gets an admission rejection - read the error message carefully; it usually names the EXACT missing field (for example, "container has no capabilities.drop"). An important detail about the semantics of PSS `restricted` in Kubernetes 1.36: it requires an effective (not necessarily literally duplicated) allowed `seccompProfile` - the pod-level profile (`spec.securityContext.seccompProfile.type`) can be inherited by containers that have no field of their own set, and conversely, the container-level field is enough if it is explicitly set for ALL containers, even without a pod-level profile. That is, PSS itself does not literally require BOTH levels at the same time. **In this lab we deliberately ask you to set `RuntimeDefault` explicitly both on the Pod and on the container** - not because PSS requires it, but so that you practice both levels of configuration. Likewise `runAsUser: 1000` is an explicit hardening decision of this lab: PSS `restricted` forbids UID `0`, but does not require specifically `1000` (any non-zero value or the complete absence of the field is acceptable for PSS itself).
</details>

---
| **3** | **The baseline observing modes** |
| :---: | :--- |
| What to do | On the namespace `psa-observe-107` enable both PSA modes: `pod-security.kubernetes.io/audit=baseline`, `pod-security.kubernetes.io/audit-version=v1.36`, `pod-security.kubernetes.io/warn=baseline`, `pod-security.kubernetes.io/warn-version=v1.36`. Do not add `enforce`: this is a namespace for gradual observation before blocking. |
| Acceptance criteria | The four audit/warn labels with level `baseline` and version `v1.36` are present; the enforce label is absent. |

<details>
<summary>💡 Hint for task 3</summary>

There are four separate labels - it is easy to forget one of them (especially the `-version` for one of the modes). Check all four at once: `kubectl get namespace psa-observe-107 -o jsonpath='{.metadata.labels}' | jq`.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

Baseline - BEFORE setting the labels a violating manifest must pass without a PSA warning
(the namespace is not yet observed):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
```

Set all four labels, then repeat THE SAME manifest - now `kubectl apply`
must print `Warning: ... would violate PodSecurity "baseline:v1.36"`, and the command
must still end with success (exit 0), and not with an error:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "exit code: $?"
```
</details>

---
| **4** | **Warn/audit do not block a legacy workload** |
| :---: | :--- |
| What to do | Create a Pod `baseline-audit-sample` in `psa-observe-107` from `busybox:1.36` that runs with `hostNetwork: true` and executes `sleep 3600`. On `kubectl apply` record the PSA warning about the baseline violation: the Pod must be created, because `warn` and `audit` by themselves do not forbid the request. |
| Acceptance criteria | `baseline-audit-sample` exists, has `hostNetwork: true`, and was admitted by the API; the namespace still has no enforce mode. |

<details>
<summary>💡 Hint for task 4</summary>

If the Pod was NOT created - check whether you accidentally set the `enforce` label in task 3 instead of only `audit`/`warn`. The PSA warning appears right in the output of `kubectl apply` (`Warning: would violate PodSecurity "baseline:v1.36"`); you do not need to look for it in a separate log.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

This task effectively repeats the self-check of task 3, but with a persistent Pod. After
creating `baseline-audit-sample` make sure that it really exists and is
`Running`/`Pending` (was not rejected):

```bash
kubectl get pod baseline-audit-sample -n psa-observe-107 -o jsonpath='{.status.phase}{"\n"}{.spec.hostNetwork}'
```

Compare with the namespace `psa-restricted-107` (task 1): the very same unsafe manifest there
MUST be rejected, while here it is accepted. The difference is exactly the `enforce` label, which one
namespace has and the other lacks:

```bash
kubectl get namespace psa-restricted-107 psa-observe-107 --show-labels
```
</details>

---
| **5** | **A read-only root filesystem with a writable emptyDir** |
| :---: | :--- |
| What to do | Refine `restricted-app`: on the container enable `readOnlyRootFilesystem: true`. Create a volume `writable-tmp` of type `emptyDir` (`medium: Memory` is recommended, so that temporary files do not land on the node disk) and mount it at `/tmp` without `readOnly: true`. The container is allowed to write only into this temporary volume; do not use `hostPath`. Prove both outcomes with a live call inside the Pod: an attempt to write to the root of the container (for example, `touch /root-write-test.txt`) must end with the error `Read-only file system`, and a write to `/tmp/test.txt` must succeed. When changing immutable fields of the Pod, delete and recreate `restricted-app` with the same name. |
| Acceptance criteria | The container has a read-only root filesystem; an `emptyDir` named `writable-tmp` is mounted at `/tmp` as writable; for regular containers this is the only writable declarative `volumeMount`, and all additional `volumeMounts` are read-only; the hardened settings from task 2 are preserved; a live attempt to write to the root of the container returns `Read-only file system`, and a write to `/tmp/test.txt` succeeds with readable content. |

<details>
<summary>💡 Hint for task 5</summary>

`readOnlyRootFilesystem` is among the fields that cannot be changed on an already existing Pod (an immutable field) - `kubectl apply` with a changed securityContext will return an error. Delete the Pod (`kubectl delete pod restricted-app`) and create it again with the same name, rather than trying to update the existing one in place.
</details>

---
| **6** | **Native ValidatingAdmissionPolicy: require `automountServiceAccountToken: false`** |
| :---: | :--- |
| What to do | • PSA `restricted` already requires `allowPrivilegeEscalation: false`, `capabilities.drop` containing `ALL`, non-root, and seccomp - task 2 shows exactly this.<br/>• But PSS `restricted` **does not check** `automountServiceAccountToken`: a Pod that does not need the Kubernetes API can silently receive a mounted ServiceAccount token and fully pass PSA. This is a separate control not covered by PSS, which is why a custom `ValidatingAdmissionPolicy` is appropriate here, rather than duplicating the built-in PSA.<br/>• Create a `ValidatingAdmissionPolicy` `require-no-automount-token` with a CEL expression requiring `automountServiceAccountToken == false` at the Pod level.<br/>• Apply a `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding`, restricted by `matchResources.namespaceSelector` to `psa-restricted-107`, with `validationActions: [Deny]`.<br/>• Prove all three states with a server-side dry-run: a fully PSA-compatible Pod (with all the fields from task 2 - non-root, seccomp, drop ALL, escalation false) without the field must get a DENY from the exact policy+binding pair; `automountServiceAccountToken: false` must get ALLOW; `automountServiceAccountToken: true` must again get DENY from the same pair.<br/>• After the policy is created, new Pods in `psa-restricted-107` (including the recreated `restricted-app`) must themselves contain `automountServiceAccountToken: false`, otherwise the policy will reject them. |
| Acceptance criteria | • **Objects:** the `ValidatingAdmissionPolicy require-no-automount-token` and its `ValidatingAdmissionPolicyBinding` exist, `validationActions` contains `Deny`, the Binding matches only `psa-restricted-107`. Exactly one Binding exists in the lab for this policy - `require-no-automount-token-binding`; additional Bindings of this policy for other namespaces are not created.<br/>• **Three states:** the server-side dry-run of a PSA-compatible Pod without `automountServiceAccountToken: false` is rejected exactly by the pair `ValidatingAdmissionPolicy 'require-no-automount-token'` and `ValidatingAdmissionPolicyBinding 'require-no-automount-token-binding'` (not by the PSA message `violates PodSecurity` and not by another policy); a Pod with `automountServiceAccountToken: false` is accepted, and a Pod with `automountServiceAccountToken: true` is rejected by the same exact pair.<br/>• **Coverage of all Pods:** the policy covers all the Pods selected by its `resourceRules` inside `psa-restricted-107`. Do not add `spec.matchConditions`, `matchConstraints.objectSelector`, or `matchConstraints.namespaceSelector` to the `ValidatingAdmissionPolicy`, nor an `objectSelector` in the Binding `matchResources` - they narrow the coverage to part of the Pods, and a workload could fall out of the check by a label or a request condition.<br/>• **Namespace scope:** set only by the Binding `matchResources.namespaceSelector`, bound exactly to `psa-restricted-107`; the selector contains no conditions on other namespace label keys and by itself unambiguously restricts the scope to this namespace.<br/>• **CEL:** the validation contains no exceptions by Pod name/labels/annotations, user/request, `namespaceObject`, `params`, `variables`, or other fields: the decision depends only on `object.spec.automountServiceAccountToken` (any correct CEL form is acceptable, including the optional syntax `object.spec.?automountServiceAccountToken.orValue(true) == false`). `spec.auditAnnotations` is absent or empty: its separate CEL expressions can affect admission through `failurePolicy`, so admission control is defined only by `spec.validations`. `variables` and `paramKind` are not used.<br/>• **Resource scope:** `matchConstraints.resourceRules` restrict the policy to exactly `core/v1 pods` for the operations `CREATE` and `UPDATE`, without `resourceNames`; `scope` is absent, equals `*` or `Namespaced`, but not `Cluster`; `excludeResourceRules` are not used. The Binding does not narrow the resource/operation scope through its own `resourceRules`/`excludeResourceRules`.<br/>• This makes it possible to prove the full boolean contract with three states `missing / false / true`, and not with a few selected workload examples. |

<details>
<summary>💡 Hint for task 6</summary>

The test Pod for this task must be FULLY PSA-compatible (all the fields from task 2), except for the missing `automountServiceAccountToken: false` - if the test Pod violates both PSS and your new policy at the same time, you will not be able to prove that exactly YOUR policy fired, and not the built-in PSA. A `ValidatingAdmissionPolicyBinding` without `matchResources.namespaceSelector` will apply to the WHOLE cluster - be sure to restrict the scope to EXACTLY one namespace `psa-restricted-107` (for example, through `matchLabels: {kubernetes.io/metadata.name: psa-restricted-107}`), and not through `matchExpressions` with several values, where `psa-restricted-107` is only one of several matching namespaces: if your selector accidentally matches `psa-observe-107` as well, the same rule will unexpectedly start acting there too.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

Baseline - BEFORE creating the VAP/Binding the same PSA-compatible Pod without the automount opt-out
must pass (PSA itself does not reject it, `automountServiceAccountToken` is not part
of PSS):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "baseline exit: $?"
```

Create the VAP + Binding and repeat the manifest without the field - now the request must get
a DENY exactly from the `ValidatingAdmissionPolicy 'require-no-automount-token'` via the binding
`require-no-automount-token-binding`, NOT from PSA. Then check both explicit values:
`false` must pass, and `true` must get a DENY from the same exact pair.

```bash
kubectl apply -f require-no-automount-token.yaml   # your VAP + Binding

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# expected: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

With the same PSA-compatible manifest set `automountServiceAccountToken: false` - the request
must pass:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-false
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# expected: pod/self-check-automount-false created (or server-side dry-run success)
```

Now set `automountServiceAccountToken: true` - the request must again be rejected
by exactly the same policy and binding:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-true
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# expected: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

Finally, the most important thing - check the scope BOUNDARY, and not only the fact of a denial: the very same
manifest (without the automount opt-out), but in the namespace `psa-observe-107`, must PASS - if
it is rejected too, then your `namespaceSelector` matches more than one namespace:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-other-ns
  namespace: psa-observe-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "exit code in psa-observe-107: $?"
# expected: 0 (not denied) - otherwise the scope of the binding is too wide
```
</details>

---

| **7** | **Controller-driven admission denial: diagnostics via ReplicaSet events** |
| :---: | :--- |
| What to do | In the empty namespace `psa-controller-107` create a Deployment `controller-app` (label `app=controller-app`, replicas=1) with a simple Pod template without hardening (for example `busybox:1.36`, `sleep 3600`, without `securityContext`) - it must start successfully, PSA does not interfere yet. Then enable `pod-security.kubernetes.io/enforce=restricted` and `enforce-version=v1.36` on this namespace (the already existing Pod keeps running - PSA does not touch already created objects). Delete the current Pod: the ReplicaSet will try to create a replacement, and now admission will reject it. Check the reason via `kubectl -n psa-controller-107 describe rs` and `kubectl -n psa-controller-107 get events` - there will be a `FailedCreate` with the text `violates PodSecurity "restricted:v1.36"`. Fix the Pod template of the Deployment (add the same hardening fields as in task 2: non-root, `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`) and wait until the ReplicaSet successfully creates a new, passing Pod. |
| Acceptance criteria | The namespace has `restricted:v1.36` enforced; the Pod template in the Deployment fully complies with PSS `restricted`; after deleting the current Pod the ReplicaSet really creates a new Ready Pod under the current enforce mode (not just "the object exists" - this is checked by a live deletion and recreation). |

<details>
<summary>💡 Hint for task 7</summary>

The order matters: first a Deployment without hardening (it passes, PSA is not enforcing yet), then the
enforce=restricted label on the namespace (the existing Pod is not affected), then `kubectl
delete pod -l app=controller-app` - this is where the ReplicaSet runs into the admission deny.
If you do not delete the Pod manually, you will not see the denial at all until some reschedule
happens naturally. What needs to be fixed is exactly the `spec.template` in the Deployment (`kubectl
edit deployment controller-app` or `kubectl apply` with a corrected manifest), and not the
namespace label - rolling back enforce is not a solution to this task.
</details>

---

## Verification

On the work machine run:

```bash
check_result
```

The check contains Init and seven independent tasks. It additionally performs a
server-side dry-run of an insecure Pod, so the absence of a persistent "bad" Pod in the
restricted namespace is the expected and correct result. In task 7 the checker itself deletes
the current Pod `controller-app` and checks that the ReplicaSet really recreates a Ready Pod -
it does not accept the text of the events as proof.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Deletion

```bash
TASK=107 make delete_cks_task
```

## A note on the PSA version and audit observability

The lab deliberately pins the PSA labels to `v1.36`, since the training cluster itself runs
Kubernetes 1.36.0. As of 2026-09-06 the official CKS blueprint targets Kubernetes
`v1.35`; therefore this is a **forward-looking** training configuration, and not a statement about the exam version.
To prepare for the current exam, replace the `*-version` suffixes with `v1.35` and
compare the behavior with the documentation of that version.

The `audit` mode adds the annotation
`pod-security.kubernetes.io/audit-violations` to the **kube-apiserver audit event** for the violating Pod. The training infrastructure
neither configures nor provides an audit-log sink, so this annotation cannot be read here via `kubectl`.
The observable proof in task 4 is the PSA warning
(`Warning: ... would violate PodSecurity "baseline"`) at server-side admission and the successful
creation of the Pod without `enforce`; the audit mode is explained, but its log annotation is not
checked by this lab.
