[Русская версия](ru.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# Chapter 10. Authentication and authorization

> **What is next.** In chapters 07-09, we secured cluster components, worker nodes, Pods, and network boundaries. Now we will examine the path of a request to the Kubernetes API: first, the cluster establishes an identity, then it decides whether that identity is allowed to perform the action. This is part of the KCSA domain **Kubernetes Security Fundamentals**, weighted at 22%.

## 10.1 Who calls the API: users and `ServiceAccount`

Every request to the Kubernetes API undergoes authentication. Its purpose is to answer the question "who is this?" After successful authentication, the API Server passes the user name and groups to the next stage, authorization.

An ordinary user, such as an engineer or a CI system outside the cluster, is not a Kubernetes `User` object. Kubernetes receives that identity from a configured authentication mechanism. A `ServiceAccount` is a Kubernetes API object designed primarily for processes in a `Pod`. Its full name includes the namespace: `system:serviceaccount:shop:catalog`.

| Method | When used | Important limitation |
|---|---|---|
| TLS client certificate | Administrator, cluster component, or automation | The private key and certificate expiration must be protected. |
| Bearer token | Automation or integration | The token conveys its holder's permissions and must not be placed in code or logs. |
| `ServiceAccount` token | A process inside a `Pod` calls the API | Permissions are determined by RBAC, not simply by having a token. |
| OIDC | External identity provider, such as corporate SSO | The API Server must trust the issuer and validate token claims. |
| Authentication webhook | An external service validates client credentials | This is an authentication integration, not an admission webhook or authorizer. |
| Bootstrap token | A purpose-limited token for initial node joining | It is for bootstrap/TLS bootstrap, not a long-lived application identity. |

An anonymous request, when anonymous authentication is enabled, becomes user `system:anonymous` and group `system:unauthenticated`. This is not a convenient mode for ordinary API access. In a secure configuration, anonymous access is disabled or granted only intentionally public, safe endpoints.

Authentication does not grant access by itself. A certificate, token, or OIDC identity only names the subject. Authorization determines what that subject can do.

## 10.2 `ServiceAccount` tokens and the risk of the `default` account

Every `Namespace` contains a `ServiceAccount` named `default`. If `serviceAccountName` is not specified in a `Pod` specification, Kubernetes assigns that account. This does not mean `default` automatically has broad permissions: the risk appears when it has been given a `RoleBinding` or `ClusterRoleBinding` for convenience.

Modern Kubernetes, including v1.36, normally issues a projected bound token to a `Pod` through the TokenRequest mechanism. Such a token is bound to the `ServiceAccount` and a specific `Pod`, has a limited lifetime, and is automatically refreshed by kubelet. A long-lived Secret containing a `ServiceAccount` token should not be created without a justified reason.

If an application does not require the Kubernetes API, it does not need a token. Its mounting can be disabled in the `Pod` or in the `ServiceAccount` itself:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: shop
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: shop
spec:
  serviceAccountName: web
  automountServiceAccountToken: false
  containers:
    - name: web
      image: nginx:1.30.4
```

If a container is compromised, a mounted token can be read and used from outside the cluster while it remains valid. Therefore, choose a separate `ServiceAccount` with minimal permissions for each `Pod`, and do not use `default` as a shared application account. Disabling automount does not revoke RBAC, but it removes a secret from the pod filesystem when the API is not needed.

## 10.3 Authorization: RBAC and other authorizers

Authorization answers the question "can an already authenticated subject perform this action?" The API Server evaluates the combination of user or group, `verb`, resource, namespace, and sometimes the object name and API path.

Several authorizers can be enabled in Kubernetes. They are evaluated in their configured order: the first one that returns `Allow` or `Deny` immediately completes the decision; only if all return `NoOpinion` is the request denied by default. RBAC is the primary and recommended mechanism for most clusters.

| Mechanism | Purpose | Practical meaning |
|---|---|---|
| RBAC | Rules in `Role`, `ClusterRole`, and bindings | The usual choice for managed, auditable access. |
| Node | Limits kubelet actions on behalf of a node | Used for node identities, not instead of user RBAC. |
| Webhook | Queries an external authorization service | Suitable when the decision depends on an external system. |
| ABAC | Compares a request with a static policy file | An outdated approach for new projects that is difficult to audit and maintain. |

Do not confuse RBAC with authentication. A `RoleBinding` does not verify identity and does not create a token. It associates an already known subject with a set of permissions. Likewise, a `NetworkPolicy` limits network connections but does not replace the API Server's decision about permissions for a resource.

### Node authorizer and `NodeRestriction`: adjacent but distinct layers

**Node authorizer** is a special authorizer for the kubelet/node identity `system:node:<nodeName>` in the `system:nodes` group. It limits which API operations kubelet can perform for its node and the Pods assigned to it, including the required `Secret`, `ConfigMap`, and volume information. This is **authorization**.

**`NodeRestriction`** is a validating admission plugin. It additionally limits which `Node` objects and related `Pod` objects kubelet can modify: a correctly identified kubelet must not modify another node or Pod, or independently set protected labels. This is **admission**, not an authorizer.

> **Do not confuse them.** Node authorizer answers "is this API action allowed for the node identity?" `NodeRestriction` answers "even after authorization, is this object change permitted?" Both mechanisms matter for kubelet least privilege, but neither replaces user RBAC, TLS, or node security.

## 10.4 RBAC: roles, bindings, and least privilege

A `Role` describes rules in only one `Namespace`. A `ClusterRole` describes cluster-wide rules or can be bound to one namespace through a `RoleBinding`. A `RoleBinding` applies in its own namespace, while a `ClusterRoleBinding` applies across the entire cluster.

RBAC permissions are additive: multiple bindings accumulate, and there is no separate "deny" rule. Therefore, the principle of least privilege means granting only the required `apiGroups`, `resources`, and `verbs`, and selecting the narrowest scope.

The `Role` below allows an application to read only one `ConfigMap` in the `shop` namespace. This is an example of a narrow rule, not a template for every task.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-site-config
  namespace: shop
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["site-config"]
    verbs: ["get"]
```

You can verify an expected permission with the `kubectl auth can-i` command. For example, an administrator can check an action for a specific account:

```bash
kubectl auth can-i get configmap/site-config -n shop \
  --as=system:serviceaccount:shop:web
```

The command is useful for verification, but it does not replace manifest review and review of actual bindings. Permissions to `get`, `list`, and `watch` `secrets`, as well as `create`, `update`, `patch`, and `delete` permissions for workloads, require special attention. Access to RBAC resources, `bind`, `escalate`, and `impersonate` can make it possible to grant or use additional permissions. `cluster-admin`, `verbs: ["*"]`, and `resources: ["*"]` are not a safe starting point.

These special authorization checks serve different purposes:

- `bind` applies to creating or modifying a `RoleBinding` / `ClusterRoleBinding`. Usually, the caller must already possess the permissions contained in the bound `Role`/`ClusterRole` at the relevant scope. Explicit `bind` permission for a specific role allows the binding even without holding the complete set of those permissions.

- `escalate` applies not to binding, but to creating or modifying a `Role` / `ClusterRole`. Usually, a caller cannot write permissions to a role that the caller does not possess. Explicit `escalate` permission is an exception to this protection.

- Classic `impersonate` allows requests to be sent on behalf of the specified user/group/ServiceAccount or another supported identity attribute. This is a separate capability and must not be conflated with `bind` or `escalate`.

In Kubernetes v1.36, the beta `ConstrainedImpersonation` mechanism is also available and enabled by default. It adds narrower verbs from the `impersonate:*` and `impersonate-on:*` families to limit not only the identity but also the actions performed on its behalf. Existing RBAC rules with classic `impersonate` continue to work; the API Server can use constrained checks and, when needed, fall back to classic `impersonate`.

Permission to `create` `pods` deserves separate attention: the ability to create a `Pod` can itself be a step toward increasing a subject's influence, even if that subject does not have direct access to the target data. The reasoning chain is as follows: the subject has permission to create a `Pod` → the new `Pod` can specify any `ServiceAccount` available in the namespace through `serviceAccountName` unless an explicit restriction is configured separately → through the chosen `ServiceAccount` or mounted `Secret`/`ConfigMap`/volumes, that `Pod` can gain access to data or API permissions that the original subject did not directly have. The final scope depends on which `ServiceAccount` objects and volumes are actually available in the namespace, and on separate limiting controls (for example, `automountServiceAccountToken: false`, PSA/PSS, and restricted RBAC bindings for existing `ServiceAccount` objects). The permission to create a workload should not be treated as an unconditional path to every `Secret` or every `ServiceAccount` in the cluster: it expands potential influence only to the extent that the rest of the namespace configuration permits.

## 10.5 How this is applied in practice

The platform team separates human and machine identities. Employees sign in through corporate OIDC, automation receives separate credentials, and each component in a `Namespace` uses a separate `ServiceAccount`.

For an application HTTP service that does not call the Kubernetes API, they set `automountServiceAccountToken: false`. A controller that needs the API receives a separate `ServiceAccount` and a `Role` with specific resources and verbs. Before releasing a change, they check `kubectl auth can-i`, then review `RoleBinding` and `ClusterRoleBinding`.

They regularly look for bindings to `default` and broad `ClusterRoleBinding` objects. When an employee leaves, a token leaks, or a certificate key is lost, credentials are revoked or replaced and the associated permissions are reviewed. This prevents a single token leak from becoming permanent access to the entire cluster.

## 10.6 Exam vocabulary / Mini-glossary

| Term | Meaning |
|---|---|
| authentication | Establishing the identity of the sender of an API request. |
| authorization | Deciding whether that identity is allowed to perform a specific action. |
| `ServiceAccount` | A Kubernetes identity for processes usually running in a `Pod`. |
| bearer token | A token whose bearer receives the permissions associated with it. |
| OIDC | A protocol for connecting Kubernetes to an external identity provider. |
| RBAC | Access control through roles and role bindings. |
| `Role` / `ClusterRole` | A set of rules in one namespace / at cluster scope. |
| `RoleBinding` / `ClusterRoleBinding` | A binding of a role to a user, group, or `ServiceAccount`. |
| `bind` | A special RBAC permission to bind a Role/ClusterRole without needing to hold all permissions of the role being bound. |
| `escalate` | A special RBAC permission to create/modify a Role/ClusterRole with permissions beyond the caller's own permissions. |
| `impersonate` | The classic Kubernetes permission to impersonate another identity; v1.36 also includes beta ConstrainedImpersonation with narrower verbs. |

## 10.7 Exam Essentials / Chapter summary

- Ordinary users authenticate through external mechanisms, while a `ServiceAccount` is a Kubernetes object for processes in a `Pod`.
- Client certificates, bearer tokens, `ServiceAccount` tokens, and OIDC establish identity, but do not grant permissions without authorization.
- `default` does not automatically have broad permissions, but a binding to it makes all Pods that implicitly use it potential bearers of those permissions.
- A `ServiceAccount` token that an application does not need is not mounted with `automountServiceAccountToken: false`.
- RBAC is the primary authorizer; `Role` and `RoleBinding` usually reduce access scope compared with their cluster-wide variants.
- Permissions accumulate, so dangerous verbs and broad wildcard rules increase the impact of a compromise.

## 10.8 Do not confuse these concepts and how they appear on the exam

In an MCQ (multiple choice question), you usually need to distinguish authentication from authorization and choose the narrowest safe access. Common traps include:

- assuming that a `ServiceAccount` or token grants permissions on its own; RBAC bindings determine permissions;
- confusing a `RoleBinding` with a `ClusterRoleBinding`: the former is limited to its namespace;
- treating `default` as unconditionally dangerous: the risk depends on the permissions granted to it and token mounting;
- mistaking OIDC for an authorization method: OIDC validates an external identity, while an authorizer decides access;
- choosing `cluster-admin` or a wildcard instead of a dedicated role with the exact set of resources and verbs.

First determine what the question is about: who is making the request, how the identity was established, or which action is allowed. Then check the scope: one namespace or the entire cluster.

## 10.9 Self-check questions

### 1. Which statement about `ServiceAccount` is correct?

   - a. It automatically receives `cluster-admin` in its namespace.

   - b. It is a Kubernetes identity for processes in a `Pod`; its permissions are defined by RBAC bindings.

   - c. It replaces `NetworkPolicy` for network access.

   - d. It is an external user that always authenticates through OIDC.

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Processes in Pods commonly use `ServiceAccount`, and roles and bindings determine its capabilities. OIDC, `cluster-admin`, and network rules do not follow from creating a `ServiceAccount` itself.

</details>

### 2. What reduces risk for a `Pod` that does not need the Kubernetes API?

   - a. Enable anonymous authentication on the API Server.

   - b. Add `verbs: ["*"]` to a `ClusterRole`.

   - c. Assign the `default` `ServiceAccount` `cluster-admin`.

   - d. Set `automountServiceAccountToken: false`.

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** Kubernetes then does not mount a `ServiceAccount` token in the pod. The other options expand access or create an unnecessary attack surface.

</details>

### 3. Which object defines permissions limited to one `Namespace`?

   - a. `Role`

   - b. `ClusterRoleBinding`

   - c. `NetworkPolicy`

   - d. `ServiceAccount`

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** A `Role` defines namespace-scoped rules (which verbs are allowed for which resources), but it does not itself grant those permissions to a subject. To actually grant permissions, use a `RoleBinding` in the same namespace to associate the `Role` with specific subjects.

</details>

### 4. Which Kubernetes mechanism is the primary choice for managing permissions for users and `ServiceAccount` objects?

   - a. Node authorizer

   - b. ABAC

   - c. RBAC

   - d. OIDC

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** RBAC defines auditable access rules through roles and bindings. OIDC is for authentication, Node authorizer serves node identities, and ABAC is based on static policies.

</details>

### 5. Why does permission to `get` `secrets` require special caution?

   - a. It can reveal credentials, keys, and tokens that then grant access to Kubernetes or external systems.
   - b. It returns only Secret metadata and never allows an API client to obtain the stored value.
   - c. It automatically grants the subject permission to create a `Pod`, even if RBAC does not contain that permission.
   - d. It forces the API Server to re-encrypt a Secret on every read and therefore increases client permissions.

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** A `Secret` often contains data that unlocks access to other resources. Therefore, `get`, and especially broader `list/watch`, should be granted according to least privilege. Reading a Secret does not automatically create other RBAC permissions.

</details>

> **Where to go next.** Deepen your practical skills in CKS chapter 10: RBAC and minimizing access, CKS chapter 11: ServiceAccounts and tokens, and CKS chapter 12: restricting access to the Kubernetes API. The basic syntax of roles is also covered in CKA chapter 38: RBAC, and the `ServiceAccount` and admission chain is covered in CKA chapter 21. In KCSA, continue with [chapter 11](../11/README.md) on Pod Security Standards and Pod Security Admission.

[Table of contents](../README.md) · [Chapter 09](../09/README.md) · [Chapter 11](../11/README.md)
