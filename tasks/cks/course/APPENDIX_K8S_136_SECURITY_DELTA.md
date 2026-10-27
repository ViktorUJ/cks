[Русская версия](APPENDIX_K8S_136_SECURITY_DELTA_RU.md) · [Versión en español](APPENDIX_K8S_136_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_136_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_136_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_136_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_136_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_136_SECURITY_DELTA_JP.md)

# Appendix. Kubernetes v1.36 Security Delta

> Marker: PRODUCTION / VERSION-SENSITIVE. Inclusion in this appendix does not mean a topic belongs to the current CKS exam pool. The course's official exam snapshot (see [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) uses Kubernetes v1.35, while the course training baseline is v1.36. Check each item before treating it as an exam fact: some changes matter in production, but the curriculum may lag behind a minor release.

This appendix complements the main course chapters. It gathers security-relevant Kubernetes v1.36 changes in one place, rather than spreading them across all 33 chapters or confusing production currentness with exam fidelity.

## 1. User Namespaces GA

**CKS relevance:** Deep Dive / Production.

- `spec.hostUsers: false` places a Pod in a user namespace: root inside the container maps to an unprivileged UID on the host.
- This is an additional defense-in-depth boundary, not a replacement for existing controls (capabilities, seccomp, AppArmor, RBAC). See [chapter 03](03/README.md).
- Linux only; see chapter 03 for specific limitations (raw block volumes, NFS).

## 2. Fine-Grained Kubelet API Authorization GA

**CKS relevance:** Core (used in [chapter 05](05/README.md)).

- Previously, `nodes/proxy` was the sole subresource for almost all kubelet API paths, including seemingly safe `/metrics` and dangerous `/exec`.
- GA introduces separate subresources: `nodes/stats`, `nodes/metrics`, `nodes/log`, `nodes/pods`, `nodes/healthz`, `nodes/configz`, `nodes/spec`, `nodes/checkpoint`.
- For `/pods`, `/runningPods/`, `/healthz`, and `/configz`, kubelet first checks the fine-grained subresource and falls back to `nodes/proxy` on denial for backward compatibility.
- **Why this matters for security review:** a monitoring agent with `nodes/proxy GET` can be abused through kubelet API WebSocket semantics for RCE in any container on the node. `GET` maps to RBAC `get`, but `kubelet` does not separately check `create` for the subsequent write operation. See chapter 05 and its “Attacker's perspective” block.
- Source: [Kubernetes v1.36 blog - Fine-Grained Kubelet API Authorization Graduates to GA](https://kubernetes.io/blog/2026/04/24/kubernetes-v1-36-fine-grained-kubelet-authorization-ga/).

## 3. Mutating/Validating Admission Policy GA and Manifest-Based Admission Control (alpha)

**CKS relevance:** Core for VAP (used in [chapter 20](20/README.md)); Manifest-Based Admission Control is Deep Dive (alpha, disabled by default).

- The native CEL-based policy layer reduces the need for an additional admission webhook for many common rules. It does not replace Kyverno/Gatekeeper for generation, complex object mutation, or supply-chain image verification (see chapters 20 and 26).
- Manifest-Based Admission Control (v1.36, alpha) supports static admission objects: all objects require a `.static.k8s.io` name suffix; `paramRef` in bindings is forbidden; static webhooks allow only `clientConfig.url`, not `clientConfig.service`. An invalid static manifest can prevent the API server from becoming ready.

## 4. Service.spec.externalIPs formally deprecated

**CKS relevance:** Production/Deep Dive.

- `externalIPs` is formally deprecated in Kubernetes v1.36. A future minor release is expected to remove the behavior from kube-proxy and its support requirement from the conformance criteria.
- **Security reason:** the field has long been a risk: an unprivileged user able to create/edit Services can claim an arbitrary IP without ownership validation. This creates a MITM risk in multitenant clusters and directly relates to **CVE-2020-8554** (Man in the middle using LoadBalancer or ExternalIPs).
- **Current alternative:** a LoadBalancer Service through a cloud/on-premises controller, or Gateway API instead of direct `externalIPs` use.
- Sources: [Kubernetes v1.36 blog - Deprecation and removal of Service ExternalIPs](https://v1-36.docs.kubernetes.io/blog/2026/05/14/kubernetes-v1-36-deprecation-and-removal-of-service-externalips/), [CVE-2020-8554 advisory](https://discuss.kubernetes.io/t/security-advisory-cve-2020-8554-man-in-the-middle-using-loadbalancer-or-externalips/14003).

## 5. gitRepo volume permanently disabled

**CKS relevance:** Production/Deep Dive (supply-chain/mutable-source lesson).

- The `gitRepo` volume type is **permanently disabled** in Kubernetes v1.36 and cannot be re-enabled by a feature gate. The Kubernetes API still accepts a Pod with a `gitRepo` volume, but kubelet refuses to start it and returns an error.
- **Security reason:** the `gitRepo` volume driver ran `git clone` inside a kubelet-managed process on the node without sufficient isolation. A specially crafted Git repository could therefore cause RCE through a write hook during `git clone`.
- **Supply-chain lesson:** a volume type executing arbitrary external code during provisioning (even “just” `git clone`) has the same class of risk as a mutable image tag without digest pinning. Trust is transferred at runtime to an external, incompletely controlled source instead of being verified beforehand.
- Sources: [AWS EKS release notes - gitRepo Volume Removal](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html), [kubernetes/kubernetes#125983 - Remove gitRepo volume type](https://github.com/kubernetes/kubernetes/issues/125983).

## 6. SELinux Volume Label Changes (mount-time relabeling)

**CKS relevance:** Deep Dive (used in [chapter 18](18/README.md)).

- The container runtime, rather than kubelet, performs recursive SELinux relabeling.
- For PVCs with an access mode other than `ReadWriteOncePod`, mount-based relabeling (`-o context=`) requires the `SELinuxMount` feature gate (disabled by default in v1.36) and `CSIDriver.spec.seLinuxMount: true` on the particular CSI driver. Otherwise, slower recursive relabeling is used.
- See chapter 18 for the distinction between recursive relabeling and `MountOption`.

## How to use this appendix

Before citing an item as a “current fact” in a lecture or exam preparation:

1. Check `checked_at` in [`metadata/tool-compatibility.yaml`](../metadata/tool-compatibility.yaml) and [`metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml).
2. Check whether the specific feature is in the current curriculum (`CKS_Curriculum` PDF). Do not assume that production-current automatically means exam-relevant.
3. If an item is used as *core* material in a lab or chapter (see [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml)), keep its wording here and in that chapter synchronized.

---
[Contents](README.md)
