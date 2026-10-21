[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 104 - Restricting access to the Kubernetes API: RBAC, ServiceAccount, and anonymous-auth

## Goal

In this CKS lab you restrict access to the Kubernetes API according to the principle of least
privilege. The practice covers minimal namespaced RBAC, modern short-lived ServiceAccount tokens, a Pod without an API token, removing outdated excessive permissions, and disabling anonymous access to the API server.

Work only with the objects named in the tasks. The namespace `security-104` and the deliberately dangerous binding `legacy-operator-admin` have already been prepared by the startup script, as have the fixtures for tasks 10-12: the Secret `legacy-config`, the namespaces `rbac-a`/`rbac-b`, and the namespace `development`. This is a training configuration, not an example for production.

## Threat model

Assume that an attacker is already executing code in a Pod and is trying to use the workload identity, or the absence of authentication, to move toward the Kubernetes API. In that case what matters is not only the initial access but also the blast radius after the compromise.

Task 1 closes an excessive RBAC scope, task 2 a long-lived token, and task 3 unnecessary API access from a Pod. This reduces the opportunities to abuse the workload identity after a compromise.

Task 4 removes wildcard cluster-wide permissions, and task 5 removes anonymous access. Each of these paths on its own can widen the blast radius up to the Kubernetes API.

Task 6 closes a separate leak path: a secret passed through an environment variable becomes part of the process environment and can be read from `/proc/1/environ` by any process with `exec` access to the container, and it can also end up in application logs, a crash dump, or other diagnostic output if the program itself or a diagnostic tool prints the environment. `kubectl describe pod` for `env` with `secretKeyRef` shows only a reference to the Secret and its key (`<set to the key ... in secret ...>`), and for `envFrom` with `secretRef` only the name of the Secret, not the resolved value - do not confuse this reference with a leak of the value itself. A volume mount with `defaultMode: 0400` does not remove the access of an authorized container process to the value, but it removes the secret from the process environment and restricts the file read permissions to the owner only.

Task 7 closes hidden RBAC privilege escalation paths: `impersonate`, `bind`/`escalate`, and CSR approval do not directly widen the list of available resources, but give the ability to act on behalf of someone else or to grant oneself broader permissions - this is a separate risk category from the wildcard `*` of task 4. Task 8 provides systemic rather than point-wise protection: automount at the namespace/default SA level works even for a Pod where the developer forgot to explicitly disable the token.

Task 9 shows that prevention (tasks 1-8) and detection are different, complementary layers. Even if the specific escalation paths are closed in task 7, for a future incident you need a way to see a **dangerous RBAC change** (for example, an erroneous or malicious grant of `cluster-admin` to someone) without constant manual `kubectl get`: the audit log gives reproducible forensic evidence of exactly who initiated the change, and not just a current snapshot of the RBAC state.

ATT&CK T1528 (Steal Application Access Token) and T1613 give context to this scenario: the tasks do not model a separate attack but limit the consequences of an already compromised workload.

Tasks 10-12 cover three basic workflows that are common on the exam, not new threats: task 10 - safe reuse of an existing secret without hardcoding values in manifests case by case; task 11 - a point repair of an excessive Role and a correct cross-namespace RBAC binding, where it is easy to make a mistake with the scope; task 12 - the full onboarding of a new user via a certificate, from the private key to verifiable access, and not just analyzing an already prepared kubeconfig.

## Self-check before you start

Before opening `check_result`, make sure you can confidently answer these questions. If not, go back to [chapter 10](../../course/10/README.md) (RBAC), [chapter 11](../../course/11/README.md) (ServiceAccounts), and [chapter 12](../../course/12/README.md) (restricting access to the API).

<details>
<summary>1. How do `Role`+`RoleBinding` differ from `ClusterRole`+`ClusterRoleBinding` in the context of task 1?</summary>

A `Role` is valid only in one namespace, but its `RoleBinding` CAN reference a subject (for example a ServiceAccount) from ANY other namespace - Kubernetes officially supports a `subjects[].namespace` that differs from the namespace of the `RoleBinding` itself. What stays fixed is the SCOPE of the granted permissions: the permissions are valid only in the namespace where the `RoleBinding` was created, regardless of where the subject comes from. A `RoleBinding` can also reference a `ClusterRole` (not only a `Role`) - in this case the permissions come from a cluster-wide template but are granted only in the namespace of the specific `RoleBinding`. `ClusterRole`+`ClusterRoleBinding` gives access across the whole cluster. Task 1 requires minimal **namespaced** access, hence `Role` and not `ClusterRole` - otherwise the scope is wider than required.
</details>

<details>
<summary>2. Why is a bound projected token (task 2) considered safer than a legacy Secret-based token?</summary>

A bound projected token is short-lived (set via `expirationSeconds`), expires automatically and is rotated by the kubelet, and is bound to a specific Pod - when the Pod is deleted the token becomes invalid. A legacy Secret token has no expiration, is stored as a regular `Secret` in etcd, and remains valid indefinitely, even if the Pod no longer exists.
</details>

<details>
<summary>3. What is the difference between what `automountServiceAccountToken: false` gives at the Pod level and at the ServiceAccount level?</summary>

At the ServiceAccount level it is a baseline: the value applies to all Pods that use this SA, unless a Pod overrides it explicitly. At the Pod level it is an override: the explicit field in the Pod spec takes priority over the SA value. Task 8 specifically checks the baseline at the SA/namespace level, and tasks 2-3 check the explicit setting at the level of a specific Pod.
</details>

<details>
<summary>4. Why are `impersonate`/`bind`/`escalate` (task 7) not in the same risk class as the wildcard `*` (task 4)?</summary>

The wildcard `*` in `resources`/`verbs` directly widens the **list of available operations and resources**. `impersonate`/`bind`/`escalate` do not give access to new resources by themselves - they give the ability to **act on behalf of someone else** (`impersonate`) or to **grant yourself permissions you did not originally have** (`bind`/`escalate`). This is a separate category of privilege escalation that is easy to miss in an RBAC audit if you look only at `verbs`/`resources` without taking these three special verbs into account.
</details>

## Infrastructure

The environment is deployed via Terragrunt in AWS `eu-central-1`:

| Component | Purpose |
|---|---|
| `vpc` | VPC `10.10.0.0/16` with public subnets |
| `ssh-keys` | keys for access to the nodes |
| `k8s-1` | a single-node kubeadm Kubernetes `1.36.0` cluster, containerd, and **Calico** |
| `worker` | a work machine with a configured `kubectl` and `check_result` |

The control-plane allows regular Pods to run, so a separate worker node is not needed.
For task 5 you will need SSH access to the control-plane: that is where the manifest of the
API server static Pod is located.

## Deployment

```bash
TASK=104 make run_cks_task
```

Connect to the work machine over SSH. The context `cluster1-admin@cluster1` is already configured.

```bash
time_left
check_result
```

## Tasks

---
| **1** | **Minimal RBAC for reading Pods** |
| :---: | :--- |
| What to do | In the namespace `security-104` create a ServiceAccount `auditor`, a Role `pod-observer`, and a RoleBinding `auditor-pod-observer`. The Role must allow **only** `get`, `list`, `watch` of the `pods` resource of the core API. Bind it only to the ServiceAccount `auditor`. |
| Acceptance criteria | The Role contains exactly one rule for `pods` with the verbs `get`, `list`, `watch`; the RoleBinding references this Role and the ServiceAccount `auditor`; on behalf of `auditor` it is not possible to delete `secrets`. |

<details>
<summary>💡 Hint for task 1</summary>

A common mistake is to add extra verbs (for example, `create` "just in case") or to use a `ClusterRole` instead of a `Role`. Check yourself: `kubectl auth can-i list pods -n security-104 --as=system:serviceaccount:security-104:auditor` must return `yes`, and `kubectl auth can-i delete secrets -n security-104 --as=system:serviceaccount:security-104:auditor` - `no`. If the Role and the RoleBinding are in different namespaces, the binding will not take effect - the `RoleBinding` must be in the same namespace as the `Role`, and the subject in it must match exactly by `name`/`namespace`.
</details>

---
| **2** | **Short-lived projected ServiceAccount token** |
| :---: | :--- |
| What to do | Create a ServiceAccount `api-client` and a Pod `token-client` in `security-104`. Do not use a legacy Secret token. Disable the regular automounting of the token and mount the needed token via **exactly one** projected `serviceAccountToken` source at `/var/run/secrets/tokens/api-token` with `path: api-token` and `expirationSeconds` from `600` to `3600` inclusive - do not add any additional `serviceAccountToken` sources to the same (or another) projected volume. **Do not set `audience`**, so that the kubelet requests the default API server identifier. If the application needs a separate audience, first check it against `--api-audiences` (or the default from `--service-account-issuer`) on the API server and only then set it explicitly. |
| Acceptance criteria | The Pod uses `api-client`, has `automountServiceAccountToken: false`, and contains **exactly one** projected `serviceAccountToken` source in the whole Pod specification - without a hard-coded audience, with the specified path and an `expirationSeconds` in the range `600`-`3600` (both bounds inclusive). A TokenReview performed from the admin context for the mounted token returns `authenticated: true` and the name `system:serviceaccount:security-104:api-client`; a separate RBAC check confirms that this ServiceAccount cannot delete `secrets`. |

<details>
<summary>💡 Hint for task 2</summary>

You do not need to remember the exact syntax of `projected.sources[].serviceAccountToken` by heart - `kubernetes.io/docs` has a ready example: Concepts → Storage → [Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), the section **"serviceAccountToken projected volumes"**. The most common mistake is to explicitly set `audience: kubernetes.default.svc`, assuming it is the standard value. For a kubeadm cluster this is NOT a guaranteed default - if you set an audience that the API server does not accept via `--api-audiences`, the TokenReview will return `authenticated: false`. Simply do not specify the `audience` field at all - the kubelet will then request the default API server identifier, which the server definitely accepts. Also do not forget `automountServiceAccountToken: false` on the Pod itself - otherwise Kubernetes will add a regular (legacy-style) token volume in addition to your projected volume. Another common mistake is to choose too small an `expirationSeconds` (for example `300`): the Kubernetes API requires a minimum of `600` seconds for a `serviceAccountToken` projected volume - a smaller value will be rejected by the API server at `kubectl apply` as invalid (`must be at least 10 minutes`).
</details>

---
| **3** | **A Pod without a Kubernetes API token** |
| :---: | :--- |
| What to do | Create a ServiceAccount `no-token-sa` with `automountServiceAccountToken: false` and a Pod `no-token` in `security-104` with this ServiceAccount. On the Pod itself also explicitly set `automountServiceAccountToken: false`. Use any safe long-lived image, for example `busybox:1.36` with `sleep 3600`. Do not separately mount any Secret with a ServiceAccount token manually - the Pod must have no API token at all, neither via automount nor via an explicitly mounted legacy Secret. |
| Acceptance criteria | Automounting is disabled on both the ServiceAccount and the Pod; the Pod uses `no-token-sa`; its specification has no automatically added ServiceAccount token volume and no manually mounted Secret of type `kubernetes.io/service-account-token`; an attempt to read `/var/run/secrets/kubernetes.io/serviceaccount/token` inside the container ends with an error (the file is absent), while the `kubectl exec` itself must complete successfully. |

<details>
<summary>💡 Hint for task 3</summary>

The difference from task 8: technically it would be enough to disable automount at one level (the SA or the Pod), but the task requires **both** levels at the same time (defense in depth). Check yourself: `kubectl get pod no-token -o jsonpath='{.spec.volumes}'` must not contain anything resembling `kube-api-access-*`. If a volume still appeared - check that you disabled automount BEFORE creating the Pod and not after (a change to the SA does not affect Pods that already exist). A disabled automount does not prevent you from manually mounting an old (legacy) `Secret` with `type: kubernetes.io/service-account-token` via `volumes[].secret` - if you do this, the Pod formally has no automounted volume, but in fact it will still get a valid API token. The task requires the complete absence of a token, not only the absence of automount.
</details>

---
| **4** | **Remove excessive cluster-wide permissions** |
| :---: | :--- |
| What to do | The cluster deliberately contains a ClusterRole `legacy-operator-admin` with wildcard permissions and a ClusterRoleBinding with the same name for the ServiceAccount `legacy-operator` from `security-104`. Delete **both** objects. Do not replace the wildcard access with another broad ClusterRole. |
| Acceptance criteria | `legacy-operator-admin` exists neither as a ClusterRole nor as a ClusterRoleBinding; the ServiceAccount `legacy-operator` can no longer read `secrets` in `security-104`. |

<details>
<summary>💡 Hint for task 4</summary>

Deleting only the `ClusterRoleBinding` without deleting the `ClusterRole` leaves a dangerous template in the cluster - someone can create a new binding to it later. Delete both objects. Check yourself with two separate commands: `kubectl get clusterrole legacy-operator-admin` and `kubectl get clusterrolebinding legacy-operator-admin` - both must return `NotFound`.
</details>

---
| **5** | **Disable anonymous access to the API server** |
| :---: | :--- |
| What to do | • Create on the control-plane the file `/etc/kubernetes/authentication-config.yaml` with an `AuthenticationConfiguration` that disables anonymous access to all endpoints except `/livez`, `/readyz`, and `/healthz` - these are exactly the paths kubeadm uses for the HTTPS liveness/readiness/startup probes of the API server static Pod, and a full `--anonymous-auth=false` breaks the probes themselves, not only the attacker's access.<br/>• Connect the file via a `hostPath` volume and the argument `--authentication-config=<path-in-container>` in `/etc/kubernetes/manifests/kube-apiserver.yaml`, and **remove** the existing `--anonymous-auth=true` - the two ways of configuring anonymous access are mutually exclusive, and kube-apiserver will not start if both are set. The kubelet will restart the static Pod automatically.<br/>• Wait for the API server to become ready (the Pod stays Running/Ready) and make sure that an unauthenticated request to `/version` gets `401`, and to `/livez` and `/readyz` - `200`.<br/>• Additionally check that the effective `--authorization-mode` contains `Node,RBAC` and does **not** contain `AlwaysAllow` (authentication without restrictive authorization is pointless).<br/>• Audit the ClusterRoleBindings whose subjects are `system:anonymous`/the group `system:unauthenticated`: the cluster deliberately contains one dangerous (lab-owned) such binding, `lab104-unintended-anonymous-access`; delete it together with its ClusterRole. **Do not touch** the standard kubeadm binding `system:public-info-viewer` - it is also bound to `system:unauthenticated`, but gives access only to the non-resource URLs `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`; this is a normal part of the bootstrap (default Kubernetes RBAC) and not a finding for this task.<br/>• This is a separate layer from the `AuthenticationConfiguration` of this same task: `anonymous.conditions` there deliberately allows the anonymous identity only on `/livez`/`/readyz`/`/healthz` - `/version` is not anonymously accessible precisely because a request to it does not get an anonymous identity at the authentication stage at all, and it never reaches authorization via `system:public-info-viewer`, even with this broader non-resource URL list. |
| Acceptance criteria | • The API server static Pod uses `--authentication-config` referencing an `AuthenticationConfiguration` with `anonymous.enabled: true` and `conditions` containing exactly `/livez`, `/readyz`, `/healthz`.<br/>• The argument `--anonymous-auth` is absent.<br/>• The kube-apiserver Pod stays `Running`/`Ready` after the restart.<br/>• An unauthenticated `GET /version` returns `401`.<br/>• Unauthenticated `GET /livez` and `GET /readyz` return `200`.<br/>• An authenticated request to `/readyz` (with valid credentials) also works.<br/>• The effective `--authorization-mode` contains `Node,RBAC` and does not contain `AlwaysAllow`.<br/>• The ClusterRole/ClusterRoleBinding `lab104-anonymous-debug-access`/`lab104-unintended-anonymous-access` are deleted.<br/>• The standard `system:public-info-viewer` is left untouched.<br/>• The group `system:unauthenticated` cannot read `pods`/`secrets`/`configmaps` in any namespace. |

<details>
<summary>💡 Hint for task 5</summary>

Do not edit the Pod object via `kubectl edit pod` - the kubelet watches the manifest file and will overwrite any change made through the API back to the original state. Edit the file `/etc/kubernetes/manifests/kube-apiserver.yaml` on the node's disk. After saving, wait: the kubelet does not detect the file change instantly, and the API server will be unavailable for a few seconds during the restart of the static Pod - do not panic if `curl` returns nothing right after the file is saved.

A plain `--anonymous-auth=false` is **not suitable** here: kubeadm `release-1.36` generates the kube-apiserver static Pod with HTTPS liveness/readiness/startup probes exactly on `/livez` and `/readyz`, and kubelet HTTP probes do not pass client credentials - when anonymous access is completely disabled these requests get `401`, the kubelet considers the container unhealthy and may restart kube-apiserver in a loop, which breaks not only this task but also the subsequent task 9. The correct way is an `AuthenticationConfiguration` with `anonymous.enabled: true` and `anonymous.conditions` that restrict anonymous access to only the needed health paths:

```yaml
# /etc/kubernetes/authentication-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
```

`--authentication-config` and `--anonymous-auth` cannot be set at the same time - kube-apiserver will not start if both arguments are present in the manifest. Make sure you removed `--anonymous-auth=true` completely and did not just change the value to `false`.

To audit anonymous ClusterRoleBindings: `kubectl get clusterrolebinding -o json | jq -r
'.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name ==
"system:unauthenticated")] | length > 0) | .metadata.name'`. You will see at least TWO
bindings - the standard `system:public-info-viewer` (do not touch it) and the lab-owned
`lab104-unintended-anonymous-access` (delete it together with its ClusterRole
`lab104-anonymous-debug-access`). You can tell them apart by the name of the ClusterRole they
reference: `kubectl get clusterrolebinding system:public-info-viewer -o
jsonpath='{.roleRef.name}'` will show `system:public-info-viewer` - this is a ClusterRole
restricted to non-resource URLs, not to regular resources.
</details>

---
| **6** | **A Secret leak via env into `/proc/1/environ`: moving to a volume** |
| :---: | :--- |
| What to do | • The Pod `app-vulnerable` in `security-104` receives `db-creds` via `envFrom.secretRef` - the value is available to anyone who can `kubectl exec` into the container (`cat /proc/1/environ`) or read the logs/describe when the env is accidentally printed.<br/>• Confirm this leak: run `kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ` and save the output (with `DB_PASSWORD`) in `/var/work/tests/artifacts/6/env-leak-before.txt`.<br/>• Recreate the Pod with the same name `app-vulnerable`: remove the `envFrom`/`env` with this secret, mount `db-creds` as a volume `db-creds-vol` at `/etc/secrets` **read-only**, with `defaultMode: 0400`.<br/>• Confirm that the variable `DB_PASSWORD` is absent from the new `/proc/1/environ` and save the `stat -L -c '%a'` of the mounted file in `/var/work/tests/artifacts/6/secret-file-mode.txt` (the `-L` flag is required - the secret is mounted via a chain of symlinks `..data`, and without `-L` `stat` will show the mode of the symlink itself, not of the real file). |
| Acceptance criteria | `env-leak-before.txt` contains the REAL value of `DB_PASSWORD` from the Secret `db-creds` (not just the word `DB_PASSWORD`); the final Pod `app-vulnerable` has no `env`/`envFrom` referencing `db-creds` and no second way of mounting the same Secret; the volume `db-creds-vol` is mounted at `/etc/secrets` as `readOnly: true` with `defaultMode: 0400` (`256` decimal) - the checker itself checks `stat -L -c %a` inside the container and requires exactly `400`; `DB_PASSWORD` is absent from `/proc/1/environ` of the final Pod (with a successfully executed `exec` - a failed `exec` does not count as proof); the application process can still actually read the secret value from `/etc/secrets/DB_PASSWORD` (positive control). |

<details>
<summary>💡 Hint for task 6</summary>

`/proc/1/environ` in the leak confirmation step is not the only way to see the value
(the same result is given by `kubectl exec ... -- env` or `echo $DB_PASSWORD`, because the
container runtime by default gives the exec'd process the same environment as PID 1).
`/proc/1/environ` reads the environment of PID 1 itself directly via `/proc`, and does not rely on
what your specific exec shell inherited - this is the same technique that is actually used
in security analysis to look at the environment of any process, not only your own.

A volume mount **does not take away access from someone who already has `kubectl exec`** - `cat
/etc/secrets/DB_PASSWORD` after the fix reads the value just as easily as `cat
/proc/1/environ` read it before the fix, and this is expected (the positive control in the task
checks exactly this). The task is not about closing exec access - that is impossible for both a file and
a variable if the process has the right to read the value. The real difference is in the leak
paths that work WITHOUT an explicit `exec`:
- environment variables are automatically inherited by **any** child process (`fork()`
  copies the whole env) - a third-party library, plugin, or accidental subprocess inside the
  application will receive `DB_PASSWORD`, even if the developer did not think about it; a file is not passed on like that -
  the child process must explicitly know the path and open it;
- crash handlers and error loggers often print the whole `environ` of the process on
  a crash - this goes to the logs automatically; the content of a file does not get into the logs by itself
  until the code explicitly reads and logs it;
- environment variables have no access permission model - they are visible to any process in the namespace
  of the container; a file with `defaultMode: 0400` has one - only a process with the needed UID reads it.

```text
[FAIL] The defaultMode for the Secret Volume is specified incorrectly.
💡 You specified defaultMode: 400 (decimal 400).
   YAML supports an octal literal with a leading zero (0400), which Kubernetes
   interprets as regular Unix permissions; without the leading zero 400 is read as the decimal
   number 400, and not as the permissions 0400 (that is decimal 256).
```

This is the most common mistake in this task: `defaultMode` is a numeric field with POSIX mode bits, and
Kubernetes YAML supports both octal and decimal notation for it - unlike
JSON, where only decimal is allowed. If you write `defaultMode: 400` (without a leading
zero), Kubernetes will take it as **decimal** 400, and not as the familiar Unix permissions
`0400`. The right way is either to write `defaultMode: 0400` (with a leading zero, YAML
recognizes an octal literal), or to explicitly specify the decimal equivalent `256`. Check
yourself: `kubectl get pod app-vulnerable -o jsonpath='{.spec.volumes[0].secret.defaultMode}'`
must return `256`, and `stat -L -c '%a' /etc/secrets/DB_PASSWORD` inside the container - `400`.
</details>

---
| **7** | **Audit and revocation of hidden RBAC privilege escalation paths (`impersonate`, `bind`, `escalate`, CSR approval)** |
| :---: | :--- |
| What to do | • The ClusterRole `build-agent-hidden-privesc` does not contain the wildcard `*` (that is a separate path, already eliminated in task 4), but it gives the ServiceAccount `build-agent` from `security-104` three really exploitable privilege escalation paths:<br/>• `impersonate` over `users`/`groups`/`serviceaccounts` - identity spoofing, including cluster-admin, if such a user is known to the attacker.<br/>• `create`/`update`/`bind`/`escalate` over `clusterroles` and `create`/`update` over `clusterrolebindings` - the base verbs give the ability to create/modify the objects themselves, while `bind`/`escalate` bypass the built-in RBAC check that would otherwise forbid granting/binding permissions broader than your own (without the base `create`/`update`, `bind`/`escalate` alone are not enough for a real escalation).<br/>• `update` on `certificatesigningrequests/approval` + `approve` on the signer `kubernetes.io/kube-apiserver-client` - the ability to approve a CSR with an arbitrary identity (but this ClusterRole alone does not give `create certificatesigningrequests`: to carry the attack through to the issuing of a certificate, the identity also needs a separate ability to create a CSR, for example through another compromised role or compromised automation that can already submit a CSR).<br/>• Find **all** ClusterRoleBindings whose ClusterRoles allow `impersonate`, `bind`, or `escalate` (for example, via `kubectl get clusterrole -o json \| jq` over `rules[].verbs`), and write them to `/var/work/tests/artifacts/7/dangerous-bindings-before.txt`.<br/>• Delete the ClusterRoleBinding `build-agent-hidden-privesc` **and** the ClusterRole `build-agent-hidden-privesc` (and, if you find other unintended ones - those too, but not the system `system:*` ClusterRoleBindings).<br/>• Confirm the revocation via `kubectl auth can-i` for ALL found permissions: `impersonate users`, `bind clusterroles`, `escalate clusterroles`, `update certificatesigningrequests/approval`, as well as `approve` on the signer `kubernetes.io/kube-apiserver-client` - all must return `no`. |
| Acceptance criteria | • `dangerous-bindings-before.txt` contains `build-agent-hidden-privesc` among the found ones as a ClusterRoleBinding (and not the name of a ClusterRole, if they do not match).<br/>• The ClusterRoleBinding **and** the ClusterRole `build-agent-hidden-privesc` do not exist after the fix.<br/>• `build-agent` cannot `impersonate`, `bind`, `escalate`, `update certificatesigningrequests/approval`.<br/>• `build-agent` cannot perform `approve` on the signer `kubernetes.io/kube-apiserver-client`.<br/>• The system `system:*` ClusterRoleBindings are not touched. |

<details>
<summary>💡 Hint for task 7</summary>

CSR approval is a separate category from `impersonate`/`bind`/`escalate`: it is not in the same `jq` filter over `verbs`, because it is a separate rule on the resource `certificatesigningrequests/approval` with the verb `update`, plus `approve` on a specific `signer`. If you filter only by `impersonate`/`bind`/`escalate`, you will find one path but miss the CSR - look for both separately, and for each save exactly the name of the **ClusterRoleBinding**, not of the ClusterRole it references (in this lab the names match, but in general this is not guaranteed). Do not delete the system `ClusterRoleBinding` objects with the prefix `system:` - they are needed by the core Kubernetes components for legitimate `impersonate` (for example, `system:kube-controller-manager`).
</details>

---
| **8** | **Namespace-level baseline: the `default` ServiceAccount without automount** |
| :---: | :--- |
| What to do | • Task 3 disabled automount point-wise, inside a specific Pod and its own ServiceAccount. Here you need a baseline at the **namespace** level.<br/>• Create the namespace `security-104-baseline` and wait for the automatically created ServiceAccount `default` to appear in it (the creation of the ServiceAccount happens asynchronously by a separate controller, not simultaneously with the namespace itself).<br/>• Only then set `automountServiceAccountToken: false` on this ServiceAccount: `kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`.<br/>• Create in this namespace a Pod `implicit-default-sa` from `busybox:1.36` (`sleep 3600`), **without specifying** either `serviceAccountName` or `automountServiceAccountToken` explicitly - it must implicitly use the `default` SA and inherit its value.<br/>• Confirm that in the specification of the final Pod the field `automountServiceAccountToken` is absent (rather than equal to `false`), there is no token volume, and an attempt to read the token file inside the container ends specifically with a file-not-found error (the `kubectl exec` itself must complete successfully). |
| Acceptance criteria | • The ServiceAccount `default` in `security-104-baseline` has `automountServiceAccountToken: false`.<br/>• The Pod `implicit-default-sa` uses `serviceAccountName: default` (implicitly or explicitly).<br/>• Its specification **does not contain** the field `automountServiceAccountToken` (it is set explicitly neither to `true` nor to `false`).<br/>• There is no automatically added `projected`/`secret` volume with a ServiceAccount token and no manually mounted legacy `Secret` of type `kubernetes.io/service-account-token`.<br/>• `kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token` completes successfully (exit code `0`), confirming the absence of the file specifically through a successful exec, and not through an arbitrary error. |

<details>
<summary>💡 Hint for task 8</summary>

The order of operations is critical: if you create the Pod BEFORE the `patch` is applied to the `default` SA of the namespace, the Pod will receive a token according to the old (default `true`) value. Also do not patch the `default` SA RIGHT after `kubectl create namespace` without checking - the ServiceAccount `default` is created by a separate controller and may not exist yet in the first fractions of a second after the namespace is created; wait for it to appear (`kubectl get serviceaccount default -n security-104-baseline`), and only then patch. The task deliberately does not specify `serviceAccountName` in the Pod - this models the real situation where the developer simply forgot about the ServiceAccount, and the baseline must protect them by default. An explicit `automountServiceAccountToken: false` ON THE POD ITSELF would prove only a point setting (as in task 3) - here the field must be left completely unspecified to prove the inheritance from the SA/namespace.
</details>

---
| **9** | **Integration task: detect an RBAC escalation via the audit log and contain it** |
| :---: | :--- |
| What to do | • This task combines RBAC (this lab) with audit logging (see [chapter 32](../../course/32/README.md)) - without an audit log the very fact of a dangerous RBAC change would be visible only post-hoc via `kubectl get`, and not as reproducible forensic evidence.<br/>• On the control-plane enable a minimal audit backend: create `/etc/kubernetes/audit/policy.yaml` with a `RequestResponse` rule for `apiGroups: ["rbac.authorization.k8s.io"]`, the resources `clusterroles` and `clusterrolebindings`, and a catch-all `Metadata` as a fallback.<br/>• In the static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` add `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log`, and the needed hostPath volume/volumeMount (create the directories in advance). Wait for the API to recover.<br/>• As the administrator (`cluster1-admin`) create a ClusterRoleBinding `incident-simulated-escalation` that binds the ClusterRole `cluster-admin` to the ServiceAccount `build-agent` from `security-104` - this is **not** an escalation attempt by `build-agent` itself (task 7 has already revoked its real privilege escalation paths), but a dangerous RBAC change modeled by the administrator: a real scenario where someone (a human operator, a script, a compromised CI/CD) by mistake or maliciously grants `cluster-admin` to a ServiceAccount, and the job of the SOC/security engineer is to detect exactly such an event via the audit log, and not via constant manual `kubectl get`.<br/>• Find in the audit log the `create` event for `clusterrolebindings` with this name, with `requestObject.roleRef` pointing at `cluster-admin` and `system:serviceaccount:security-104:build-agent` in `requestObject.subjects`, and save the whole event (including `user.username` - who actually initiated the request) in `/var/work/tests/artifacts/9/audit-escalation-event.json`. This is not just "making sure the audit rule works" - the real job of the SOC engineer here is to **extract and save a specific record** as forensic evidence (the checker itself independently reads `audit.log` on the control-plane and compares the `auditID` of your artifact with the real record - an invented, even similar-looking JSON will not pass).<br/>• Perform containment: delete `incident-simulated-escalation` and confirm via `kubectl auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent` that the access has been revoked; save the final `no` in `/var/work/tests/artifacts/9/containment-result.txt` (`can-i` without `-n`/`-A` checks only the current namespace of your kubeconfig context, not the whole cluster - specify the namespace explicitly). |
| Acceptance criteria | • The kube-apiserver static manifest contains `--audit-policy-file` and `--audit-log-path`, the API server is healthy.<br/>• `/var/work/tests/artifacts/9/audit-escalation-event.json` is a valid JSON audit event with `verb: create`, `objectRef.resource: clusterrolebindings`, `objectRef.name: incident-simulated-escalation`, `requestObject.roleRef.name: cluster-admin`, and the ServiceAccount `build-agent` from `security-104` among `requestObject.subjects`.<br/>• The ClusterRoleBinding `incident-simulated-escalation` does not exist after containment.<br/>• `containment-result.txt` contains `no`. |

<details>
<summary>💡 Hint for task 9</summary>

The `RequestResponse` rule for `rbac.authorization.k8s.io` must be FIRST in the list of the policy rules - the more specific rule must come before the general `Metadata` catch-all, otherwise the catch-all intercepts the event first and you will get only the `Metadata` level instead of `RequestResponse` with the request body. Add `omitStages: [RequestReceived]` at the level of the whole policy - this stage does not yet have `requestObject`/`responseStatus`, and the `Metadata` catch-all applies to absolutely all requests of the cluster, so without `omitStages` the `audit.log` grows twice as fast without any additional benefit for this task. Create `incident-simulated-escalation` AFTER the API server has restarted with the new audit backend - otherwise the event simply will not get into the log. This task checks the detection of a dangerous RBAC change per se, and not that `build-agent` itself made it - in the audit log the field `user.username` will show the real initiator (the administrator), not `build-agent`; `build-agent` appears in this event only as the recipient of the permissions (`requestObject.subjects`). `audit-escalation-event.json` must be a **real** record copied from `/var/log/kubernetes/audit/audit.log` (including its `auditID`) - a JSON assembled by hand with a few matching lines will not pass the check, because the self-check itself reads the log on the control-plane and compares the `auditID`. Do not forget containment: deleting the `ClusterRoleBinding` is only half of the task, the other half is proving via `kubectl auth can-i` that the access has really been revoked, and not that the object has simply become unreadable.
</details>

---
| **10** | **Decode, create and mount a Secret** |
| :---: | :--- |
| What to do | • In `security-104` there is already an Opaque Secret `legacy-config` with two keys: `SERVICE_USER` and `SERVICE_TOKEN`. Read it via the API and decode both values from base64.<br/>• Create a new generic Secret `rehydrated-config` from literal values (`kubectl create secret generic ... --from-literal=...`), with the SAME key names and the SAME decoded values.<br/>• Create a Pod `secret-workflow` from `busybox:1.36` (`sleep 3600`) that mounts `rehydrated-config` as a **read-only** volume at `/etc/rehydrated`.<br/>• Confirm that both files inside the container are really readable and contain the expected values. |
| Acceptance criteria | • `rehydrated-config` exists and its decoded `SERVICE_USER`/`SERVICE_TOKEN` match the original `legacy-config`.<br/>• The Pod `secret-workflow` mounts exactly this Secret at `/etc/rehydrated` with `readOnly: true`.<br/>• `kubectl exec` inside the container reads both files with the correct content. |

<details>
<summary>💡 Hint for task 10</summary>

`kubectl get secret legacy-config -o jsonpath='{.data.SERVICE_USER}' | base64 -d` gives you
the real value - do not write an arbitrary string into the new Secret, the checker itself decodes the
original again and compares. `kubectl create secret generic rehydrated-config
--from-literal=SERVICE_USER=... --from-literal=SERVICE_TOKEN=...` encodes the values
automatically - you do not need to base64-encode them yourself when creating via `--from-literal`.
Do not forget `readOnly: true` on the volumeMount - a mounted but writable Secret
literally fails the acceptance criterion because of that flag, even if the Pod itself works correctly.
</details>

---
| **11** | **Repair an existing Role and bind it to an SA from another namespace** |
| :---: | :--- |
| What to do | • In the namespace `rbac-a` there are already a ServiceAccount `dev`, a Role `pod-role`, and a RoleBinding `pod-role-binding`. The Role currently allows `get`, `list`, `delete` on `pods` - `delete` is excessive here (remove it), and `watch` is missing although it is needed (add it). Fix the existing Role, do not create a new one.<br/>• Separately, in the namespace `rbac-b` there is already a ConfigMap `shared-config`. Create in `rbac-b` a new Role and RoleBinding that give the ServiceAccount `dev` **from the namespace `rbac-a`** `get`/`list` access (and only that) on `configmaps` in `rbac-b`.<br/>• Create a Pod in `rbac-a` with `serviceAccountName: dev`. |
| Acceptance criteria | • The Role `pod-role` in `rbac-a` allows exactly `get`, `list`, `watch` on `pods`.<br/>• `dev` cannot `delete pods` in `rbac-a`.<br/>• `dev` can `get`/`list configmaps` in `rbac-b`, but cannot `delete configmaps` and cannot read `secrets` there.<br/>• In `rbac-a` there is a Pod that uses the ServiceAccount `dev`. |

<details>
<summary>💡 Hint for task 11</summary>

A `RoleBinding` can reference a subject (`ServiceAccount`) from ANY other namespace -
Kubernetes officially supports this via `subjects[].namespace`. But the `RoleBinding` itself,
and the permissions associated with it, are always valid only in the namespace where IT ITSELF was created - so
the new Role+RoleBinding must be created IN `rbac-b`, not in `rbac-a`. Check yourself:
`kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev` must
return `yes`, and `kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev` -
`no`.
</details>

---
| **12** | **Client certificate user via CSR + namespaced RBAC** |
| :---: | :--- |
| What to do | • Create a new Kubernetes user `john` authenticated by a client certificate: generate a private key, then a CSR (`openssl req -new`) with `CN=john`.<br/>• Submit it as a Kubernetes `CertificateSigningRequest` `john-csr` with `signerName: kubernetes.io/kube-apiserver-client`; approve the CSR (`kubectl certificate approve`).<br/>• Extract the issued certificate from `status.certificate` (base64-decode) and save it together with the private key in `/var/work/tests/artifacts/12/john.crt` and `.../john.key`.<br/>• In the namespace `development` (already created) create a Role that allows `create`/`list`/`get` on `pods`, and a RoleBinding to the subject `{kind: User, name: john}`.<br/>• Build a separate kubeconfig for John (`kubectl config set-cluster`/`set-credentials --client-certificate/--client-key`/`set-context`) and save it as `/var/work/tests/artifacts/12/john.kubeconfig`; make sure that `kubectl --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development` actually works, while the same request to another namespace gets `Forbidden` - this proves a working certificate just like a direct TLS request, but through the familiar `kubectl` and not `curl`.<br/>• Confirm with live `kubectl auth can-i --as=john` checks: John can `create`/`list`/`get` pods in `development`, cannot `delete` them there, and does not have the same permissions in another namespace. |
| Acceptance criteria | • `john-csr` uses the right signer and is `Approved`.<br/>• The issued certificate has `CN=john` and actually verifies against the CA of this cluster.<br/>• The Role+RoleBinding in `development` give John exactly `create`/`list`/`get` on `pods`.<br/>• John cannot `delete` pods there and has no access in other namespaces.<br/>• The saved `john.crt`/`john.key` are actually accepted by the API server in a direct TLS request (and not only via `--as=john` impersonation).<br/>• The built kubeconfig exists at the path `/var/work/tests/artifacts/12/john.kubeconfig`, and `kubectl --kubeconfig=<this file> get pods -n development` actually works, while the same request to another namespace ends with `Forbidden`. |

<details>
<summary>💡 Hint for task 12</summary>

Do not confuse this task with Lab 114: there you analyze an ALREADY existing certificate from a
kubeconfig, while here you need to issue a completely new, really working identity from scratch.
RBAC for a certificate-based user is bound via `subjects: [{kind: User, name:
john}]`, and not a `ServiceAccount` - a `User` in Kubernetes has no separate API object, its
"existence" is determined entirely by the CN in the client certificate matching the
`name` in the binding. `--as=john` in `kubectl auth can-i` checks only the RBAC logic
(impersonation) and does not prove that the certificate is really valid - separately make sure
that `openssl verify` against `/etc/kubernetes/pki/ca.crt` on the control-plane returns `OK`.
</details>

## Checking the Result

On the work machine run:

```bash
check_result
```

The check contains Init and twelve independent tasks. After the API server is changed,
some tests may briefly wait for the static Pod to restart.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Deletion

```bash
TASK=104 make delete_cks_task
```
