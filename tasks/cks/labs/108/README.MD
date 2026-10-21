[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 108 - Admission policies with Kyverno

## Goal

In this CKS lab you install Kyverno and protect the namespace `policy-108` with policy-as-code
rules. The practice covers validating admission: forbidding the `latest` tag, a mandatory
`runAsNonRoot`, a registry allowlist; the last, optional stage covers the mutation of a Pod at
admission. Task 6 compares this approach with another mechanism - the built-in
`ImagePolicyWebhook`, where the decision about an image is made by an external HTTP(S) backend through the
`ImageReview` API, and not by a CEL expression inside the cluster. The final task 7 is a third, separate
admission engine: **Gatekeeper (OPA/Rego)**, where you fix an already deployed but incomplete
policy, rather than writing CEL inside Kyverno. Work only with the objects and names specified
in the tasks.

## Self-check before you start

<details>
<summary>1. Why does forbidding only an explicit `:latest` tag not close the whole mutable-tag risk?</summary>

If an image is specified without a tag at all (for example, `nginx`), Docker/OCI resolves it by default as `nginx:latest` - an implicit latest. A policy that checks only for a literal match of the string `:latest` will let such an image through, although semantically it is the same as an explicit `:latest`. A correct policy must reject both the explicit and the implicit latest - or require an explicit versioned tag/digest.
</details>

<details>
<summary>2. Why must a validating policy check `ephemeralContainers` separately from `containers`/`initContainers`?</summary>

`kubectl debug` adds an ephemeral container to an ALREADY existing Pod through a separate subresource API (`pods/ephemeralcontainers`), and not through a regular Pod CREATE/UPDATE. If a policy matches only the resource `pods` without explicitly including this subresource, an attempt to add an unchecked/untrusted ephemeral container can bypass all the validating policies written for regular containers.
</details>

<details>
<summary>3. What is the fundamental difference between a `ValidatingPolicy` and a `MutatingPolicy` in Kyverno?</summary>

A `ValidatingPolicy` only checks the request and either allows or rejects it (Allow/Deny) - the object is not changed. A `MutatingPolicy` CHANGES the object before it is saved (adds/changes fields, for example a label) - the request still passes, but with changed content. Task 5 uses mutation precisely because the goal is to add a label automatically, and not to reject the Pod.
</details>

## Infrastructure

The environment is deployed by Terragrunt in AWS `eu-central-1`:

| Component | Purpose |
|---|---|
| `vpc` | VPC `10.10.0.0/16` with public subnets |
| `ssh-keys` | keys for access to the nodes |
| `k8s-1` | a single-node kubeadm Kubernetes `1.36.0` cluster, containerd, and **Calico** |
| `worker` | a work machine with `kubectl`, Helm, and `/usr/local/bin/install-kyverno` |

The control-plane allows regular Pods, so a separate Kubernetes worker is not created.
Kyverno is deliberately **not installed** in the initial state: this is part of task 1. A pinned
installer, which does not require choosing the chart by hand, is prepared on the work machine.
The lab pins Kyverno `1.19` (Helm chart `3.9.0`) and uses the stable CEL-based APIs
`policies.kyverno.io/v1`. The legacy `Policy`/`ClusterPolicy` in `kyverno.io/v1` are
deprecated since this version and are considered only as migration material.

Unlike Kyverno, **Gatekeeper (OPA) for task 7 is already installed** by the cluster bootstrap,
together with a starting (deliberately incomplete) `ConstraintTemplate` and `Constraint`.
This is done on purpose: task 7 checks the ability to find and complete the Rego in an already
existing `ConstraintTemplate`, rather than to install an admission engine from scratch - that part
is already practiced by task 1 for Kyverno. Task 7 works in a separate namespace
`gatekeeper-108`, isolated from the Kyverno tasks 1-5 (`policy-108`), so that a Pod cannot
be rejected by two different admission engines at once.

## Deployment

```bash
TASK=108 make run_cks_task
```

Connect to the work machine over SSH. The context `cluster1-admin@cluster1` is already configured.

```bash
time_left
check_result
```

## Tasks

---
| **1** | **Install Kyverno** |
| :---: | :--- |
| What to do | • Install Kyverno in the namespace `kyverno`.<br/>• Use the command `/usr/local/bin/install-kyverno` prepared on the worker; it applies the pinned Helm chart.<br/>• Wait until the admission controller is available. |
| Acceptance criteria | • The cluster has the CRD `validatingpolicies.policies.kyverno.io`<br/>• The Kyverno version is `1.19.x`<br/>• At least one Deployment of the namespace `kyverno` has an available replica |

<details>
<summary>💡 Hint for task 1</summary>

`/usr/local/bin/install-kyverno` is already configured for the pinned version - do not try to install Kyverno via `helm install` by hand with a different chart, this may lead to an incompatible version of the CRDs. After the installation wait: the admission controller Pod must become `Available`, and this does not happen instantly.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

```bash
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
kubectl get deployment -n kyverno -o wide
kubectl get deployment -n kyverno -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | grep kyverno
```

The first command must return the CRD itself (not a `NotFound` error); the image version must
contain `v1.19.`; at least one Deployment must have `AVAILABLE` greater than `0`.
</details>

---
| **2** | **Forbid images with the `latest` tag** |
| :---: | :--- |
| What to do | • Create a CEL-based `ValidatingPolicy` `deny-latest-tag` (`policies.kyverno.io/v1`) with `validationActions: [Deny]`.<br/>• It must apply to Pods and the subresource `pods/ephemeralcontainers` of the namespace `policy-108`.<br/>• It must reject any image in `containers`, `initContainers`, or `ephemeralContainers` that is an explicit `:latest` OR an implicit latest (an image with no tag and no digest at all). |
| Acceptance criteria | • The policy exists and works in Deny mode<br/>• Admission rejects both an explicit `:latest` and an implicit latest (untagged) in each of the three container lists, including an image with a registry port and no tag (`registry.example:5000/app`), and accepts versioned trusted images and digest-pinned images in each list<br/>• On an UPDATE of an existing Pod, changing `spec.containers[*].image` or `spec.initContainers[*].image` to `:latest` is also rejected by this policy (regular Pod image fields allow an in-place UPDATE) |

<details>
<summary>💡 Hint for task 2</summary>

`matchConstraints.resourceRules` must cover both `pods` and the subresource
`pods/ephemeralcontainers` separately - otherwise `kubectl debug` will bypass the policy. For
the CEL logic itself: split the image string into `registry/path` and `tag` at the last `:`
AFTER the last `/` (a `:` before the last `/` may be part of the registry port, and not
of the tag); if after the split there is no tag at all - it is an implicit latest; if there is a tag but it
equals `latest` - it is also a forbidden case; a digest (`@sha256:...`) is a separate, always
allowed case that does not fall under the tag at all.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

Before applying the policy, make sure that the violating Pod passes admission at all
(the baseline) - otherwise it is unclear whether the denial is caused by your policy or by something else:

```bash
# baseline: before applying the policy - must pass (exit 0)
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "baseline exit: $?"
```

Apply the policy, then repeat THE SAME manifest - now it must fail with an
admission error (exit not 0), and the message must reference your policy:

```bash
kubectl apply -f deny-latest-tag.yaml   # your policy file
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "after-policy exit: $?"
```

Repeat the same baseline→apply→probe→compare cycle for: an image with no tag at all
(`registry.k8s.io/pause`), `registry.example:5000/app` (the colon before the last `/` is a registry port, not a tag), `:latest` in `initContainers`, and `:latest`/untagged via
`kubectl debug --image=...` on an already running allowed Pod (the `pods/ephemeralcontainers`
subresource). Finally, check the positive control - a versioned tag must pass after the policy is applied
too, not only before.
</details>

---
| **3** | **Require running as non-root** |
| :---: | :--- |
| What to do | • Create a CEL-based `ValidatingPolicy` `require-run-as-non-root` in Deny mode.<br/>• For every Pod in `policy-108` the field `spec.securityContext.runAsNonRoot` must be explicitly equal to `true`.<br/>• At the Pod level and for all containers `runAsUser: 0` and a container-level `runAsNonRoot: false` are forbidden: the container settings can override the Pod-level securityContext. |
| Acceptance criteria | • The policy exists and is Deny<br/>• A Pod with `runAsNonRoot: false` or without this field, a Pod-level `runAsUser: 0`, as well as a container with `runAsNonRoot: false` / `runAsUser: 0` in `containers`, `initContainers`, `ephemeralContainers`, are rejected by exactly this policy<br/>• A safe explicit container-level `runAsNonRoot: true`, `runAsUser: 1000` is accepted |

<details>
<summary>💡 Hint for task 3</summary>

Check for the EXPLICIT value `true`, and not for "the absence of `false`" - a CEL expression of the form `object.spec.securityContext.runAsNonRoot == true` will not pass if the field is not set at all (`null != true`), and that is REQUIRED here: the task rejects both an explicit `false` and a missing field - both cases must be denied, and not only an explicit `false`.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

```bash
# baseline: before applying the policy, both variants must pass
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-false
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-unset
  namespace: policy-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

Apply the policy and repeat both manifests - BOTH must now fail with an
admission error. Then check the positive control: the same Pod, but with
`runAsNonRoot: true` explicitly, must pass after the policy is applied too.
</details>

---
| **4** | **A container registry allowlist** |
| :---: | :--- |
| What to do | • Create a CEL-based `ValidatingPolicy` `allow-approved-registries` in Deny mode.<br/>• For every container (`containers`, `initContainers`, `ephemeralContainers`) allow only `registry.k8s.io/*` or `ghcr.io/cks-lab/*`.<br/>• Forbid all the other image registries. |
| Acceptance criteria | • The policy exists and is Deny<br/>• An untrusted image is rejected in all three lists<br/>• Both approved prefixes (`registry.k8s.io/` and `ghcr.io/cks-lab/`) are allowed in each of the three lists<br/>• A regular Pod UPDATE that changes the image to an unapproved registry is rejected by the policy itself<br/>• Other unapproved registries and host/path lookalikes in the init/ephemeral lists are also checked |

<details>
<summary>💡 Hint for task 4</summary>

`startsWith('registry.k8s.io/')` is the most reliable prefix check, but make sure that both allowed registries are checked with OR (either of the two fits), and not AND (both at once, which is impossible for a single image). Check specifically an ALLOWLIST (an image is allowed ONLY if it matched one of the two prefixes), and not a denylist of `docker.io` specifically - a policy written as "if `docker.io` - deny, otherwise allow" will let through `quay.io`, unqualified images, and any other third-party registry. Also make sure that the prefix is compared with the TRAILING `/` (`registry.k8s.io/`, not just `registry.k8s.io`), otherwise a host with a similar spelling (`registry.k8s.io.evil.example`) could pass an incomplete or case-insensitive match. As in task 2, do not forget `ephemeralContainers` - this is the same pattern of checking three container lists.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

```bash
# baseline: before applying the policy - an untrusted registry must pass
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF
```

Apply the policy, repeat the same manifest - now it must be denied. This is ONE
specific untrusted value (`docker.io`), and not a proof of a full
allowlist - a policy that simply forbids literally `docker.io`, but lets through,
for example, an unqualified image (an implicit Docker Hub with no explicit host), `quay.io`, or
a host with a similar spelling (`registry.k8s.io.evil.example`) will also pass this ONE
check. Repeat the same baseline→apply→probe→compare at least for: an unqualified
image (`busybox:1.36` with no host at all), another explicit third-party registry
(`quay.io/...`), a host/path with a similar spelling (`registry.k8s.io.evil.example/...`,
`ghcr.io/cks-lab.evil/...`), an untrusted image in `initContainers`, and an untrusted/trusted
image via `kubectl debug` on an already running allowed Pod. Finally, the positive control: a Pod with BOTH containers (main + init) from
`registry.k8s.io`/`ghcr.io/cks-lab` must pass; also check `ghcr.io/cks-lab/*`
in the init and ephemeral containers, and not only in `containers`.
</details>

---
| **5** | **Optional: mutate a label via Kyverno** |
| :---: | :--- |
| What to do | • Create a CEL-based `MutatingPolicy` `add-kyverno-managed-label` (`policies.kyverno.io/v1`) that adds to Pods of the namespace `policy-108` the label `security.cks.io/managed-by: kyverno` if it is missing.<br/>• Use mutation, not validation.<br/>• Do not mutate Pods in other namespaces. |
| Acceptance criteria | • A server-side dry-run of a Pod with an allowed registry and `runAsNonRoot: true` that does NOT yet have this label gets it after mutation with the value `kyverno`<br/>• A Pod that ALREADY has the label set with a different value keeps the original value<br/>• A Pod in `default` stays without this label<br/>• This stage is shown in `check_result`, but skipping it is acceptable |

<details>
<summary>💡 Hint for task 5</summary>

This stage is optional - if you have run out of time, you can skip it without risk to the rest of the lab. The test Pod for checking the mutation must already pass the policies from tasks 2-4 (trusted registry, non-root) - if it is itself rejected by one of the previous policies, you will not see the result of the mutation at all. "If it is missing" in the task is not just a wish: the mutation must explicitly check for the presence of the label and not touch the object if it is already there, otherwise the task is not completed, even if a Pod without the label gets the correct value.
</details>

---
| **6** | **ImagePolicyWebhook: an external backend instead of a CEL policy** |
| :---: | :--- |
| What to do | • On the work machine `/opt/image-policy-backend/server.py` is already prepared - a minimal HTTPS server implementing the `ImageReview` API (it rejects an image with the tag `:latest` or with no tag at all).<br/>• Deploy it as a Deployment in the namespace `image-policy`, behind a Service `image-policy-backend` on port `8443`. The backend must accept connections over TLS (the upstream `ImagePolicyWebhook` contract requires HTTPS, plain HTTP is not supported).<br/>• On the `control-plane` (`ssh`, then `sudo -i`) configure an `AdmissionConfiguration` for the plugin `ImagePolicyWebhook` (`defaultAllow: false`) and a kubeconfig pointing to your backend.<br/>• In the static manifest `kube-apiserver.yaml` **add** `ImagePolicyWebhook` to the already existing list `--enable-admission-plugins` (do not replace the whole list - otherwise you risk disabling the plugins that are already enabled) and enable `--runtime-config=imagepolicy.k8s.io/v1alpha1=true`.<br/>• After the API recovers, create a Pod with `:latest` - it must be rejected; then a Pod with a pinned tag - it must be created. |
| Acceptance criteria | • `image-policy-backend` is Available<br/>• Kube-apiserver is healthy with the plugin added (not replaced) and `--runtime-config`<br/>• The backend kubeconfig uses HTTPS `https://<ClusterIP Service image-policy-backend>:8443/imagepolicy`<br/>• A Pod with `:latest` and an implicit latest (including a registry port with no tag) is rejected exactly by ImagePolicyWebhook in the namespace `default` — both in a regular Pod and in an init/ephemeral container<br/>• The user annotation `alpha.image-policy.k8s.io/break-glass: "true"` does not give an exception<br/>• The namespace `policy-108` is dedicated to the Kyverno of Tasks 2–4, so that the two independent admission mechanisms do not mask each other's denial<br/>• For this the backend, on `ImageReview.spec.namespace == policy-108`, delegates the decision to Kyverno, while in all the other namespaces ImagePolicyWebhook keeps working<br/>• A Pod with a pinned tag is created and Running<br/>• The Service really loses its Endpoints during a backend outage, the API denies because this endpoint is unavailable (`defaultAllow: false`), then the Service selector and admission are restored exactly to the original state |

<details>
<summary>💡 Hint for task 6</summary>

`ImagePolicyWebhook` is a fundamentally different mechanism from the Kyverno of tasks 1-5: the decision is made by an external HTTPS backend through the `ImageReview` API, and not by a CEL expression inside the cluster. Copy the ready `/opt/image-policy-backend/server.py` to the `control-plane` (for example `scp`/`cat` over SSH) - the task checks understanding of the wiring of the admission plugin, the TLS contract, and the ImageReview API, and not the ability to write an HTTP server from scratch. For TLS: first create the Service (to learn the `ClusterIP`), then a self-signed certificate with this IP in the SAN (`openssl req -x509 -newkey ... -addext "subjectAltName=IP:<ClusterIP>"`), then a Deployment that mounts both the code and the certificate. Do not replace the existing `--enable-admission-plugins` with a new value entirely - append `ImagePolicyWebhook` with a comma to the already enabled plugins (usually `NodeRestriction` is already there). Also do not forget `--runtime-config=imagepolicy.k8s.io/v1alpha1=true` - without explicitly enabling this API the backend will not be called at all. The namespace `image-policy` is not created in advance - create it yourself before the Deployment/Service. If you are stuck on the detailed sequence of resources/paths/flags - the reference order of actions is given in the solution.
</details>

---
| **7** | **Gatekeeper ConstraintTemplate: complete the Rego blocklist** |
| :---: | :--- |
| What to do | • The cluster already has **Gatekeeper** (OPA) installed, as well as a `ConstraintTemplate` `k8sblockedregistries` and a `Constraint` `K8sBlockedRegistries/deny-bad-registries`, restricted to the separate namespace `gatekeeper-108` (not `policy-108` - this is a separate range from the Kyverno tasks 1-5, so that Kyverno and Gatekeeper do not reject the same Pod at once).<br/>• The Rego inside the `ConstraintTemplate` already contains several blocked registries (`untrusted-registry.example`, `docker-fake.test`), but **deliberately does not contain** `very-bad-registry.test`.<br/>• Find `ConstraintTemplate.spec.targets[].rego` and add to it a rule for `very-bad-registry.test` - in the Rego exactly, and not in the `Constraint` parameters.<br/>• `deny-bad-registries` is already completely correct and does not use `spec.parameters` at all - you do not need to touch it. |
| Acceptance criteria | • The `ConstraintTemplate k8sblockedregistries` and the original Constraint `K8sBlockedRegistries/deny-bad-registries` exist<br/>• The Rego keeps both original active rules (`untrusted-registry.example`, `docker-fake.test`) and contains a new active rule for `very-bad-registry.test`<br/>• A Pod with each of these three registries in `gatekeeper-108` is rejected exactly by the Constraint `deny-bad-registries`<br/>• A Pod with an image from the trusted `registry.k8s.io` passes<br/>• The Constraint stays Pod-only, restricted to `gatekeeper-108`, without parameters/selectors/exclusions<br/>• An additional Constraint of this kind is not created |

<details>
<summary>💡 Hint for task 7</summary>

Find the ConstraintTemplate via `kubectl get constrainttemplate k8sblockedregistries -o yaml`. The Rego lies in `spec.targets[].rego` as a multi-line string - it is this that needs to be edited (`kubectl edit constrainttemplate k8sblockedregistries`, or `get -o yaml` → edit → `apply`). The existing Rego declares the blocked registries through separate facts of the form `blocked_registry("untrusted-registry.example")` - add one more such line for `very-bad-registry.test`, without deleting or replacing the existing ones. Do not confuse this with `Constraint.spec.parameters` - in this version of the policy the Constraint does not use parameters at all, so there is nothing to edit there.
</details>

<details>
<summary>🔍 Self-check before `check_result`</summary>

Baseline - BEFORE the fix: a Pod from `very-bad-registry.test` must pass (the Rego does not
cover it yet), while the already blocked `untrusted-registry.example` must be rejected:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad baseline exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad baseline exit: $?"
```

Complete the Rego, repeat THE SAME manifest (under a new name, the old Pod has already been
"created" via dry-run and is not saved) - now an admission error from
Gatekeeper is expected, referencing exactly `k8sblockedregistries`, for BOTH registries:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad after-fix exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad after-fix exit: $?"
```

Check the positive control - the trusted registry must pass after the fix too:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-trusted-registry
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
echo "trusted exit: $?"
```
</details>

## Verification

On the work machine run:

```bash
check_result
```

The check contains Init and seven tests. The first four, the sixth, and the seventh are mandatory. The fifth
test performs the mutation check, but does not fail the lab if the optional
policy is not created. Tasks 2-4 and 7 use `--dry-run=server`, so images are not
downloaded and Pods do not remain in the namespace; task 6 checks real (not dry-run)
admission through ImagePolicyWebhook, so the Pod `webhook-pinned-ok` is really
created.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Deletion

```bash
TASK=108 make delete_cks_task
```

## Compatibility and the exact semantics of the image prohibition

The lab pins Kubernetes 1.36.0 and Kyverno 1.19 to get to know the new
`policies.kyverno.io/v1` API. This is a **forward-looking / unsupported combination**: Kyverno
1.19 is officially tested with Kubernetes 1.33–1.35, and not 1.36. Before applying outside the
lab choose a supported version matrix and check the release notes.

In task 2 the "prohibition of `latest`" also means the prohibition of an implicit `latest`: `nginx`
without a tag and digest is just as unacceptable as `nginx:latest`. Only images with an explicit
tag other than `latest`, or with a digest (`@sha256:...`), are allowed. The task does not give the exact CEL logic for this
criterion ready-made - see the hint for task 2 if you need additional
support.
