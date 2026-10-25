[Русская версия](APPENDIX_K8S_137_SECURITY_DELTA_RU.md) · [Versión en español](APPENDIX_K8S_137_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_137_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_137_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_137_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_137_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_137_SECURITY_DELTA_JP.md)

# Appendix. Kubernetes v1.37 Security Delta

> Marker: PRODUCTION / VERSION-SENSITIVE. Inclusion in this appendix does not mean a topic belongs to the current CKS exam pool. The course's official exam snapshot (see [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) uses Kubernetes v1.35, while the course training baseline is v1.36. The latest upstream stable version is Kubernetes v1.37. Do not promote a feature from this appendix into 🎯 CKS Core without separate confirmation of its exam/curriculum relevance.

This appendix gathers security-relevant Kubernetes v1.37 changes. The main chapters and labs remain tied to the verified exam/training context; this document records the production-current delta.

## 1. Manifest-Based Admission Control: Beta and enabled by default

**CKS relevance:** Deep Dive / Production / Version-Sensitive.

In the v1.36 training baseline, Manifest-Based Admission Control remains alpha and disabled by default. In v1.37 it became Beta, with the `ManifestBasedAdmissionControlConfig` feature gate enabled by default. The API server loads webhooks and CEL-based admission policies from static files: they are active at API server startup, do not rely on etcd to store the admission configuration itself, and can protect API-based admission resources against modification.

This closes the bootstrap and self-protection gap but increases operational risk: an invalid manifest on initial loading prevents the API server from becoming ready. In HA, each API server reads its own files, requiring consistent, atomic delivery.

Source: [Manifest-Based Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/manifest-admission-control/).

## 2. SELinuxMount: GA and enabled by default

**CKS relevance:** Deep Dive / Production / Version-Sensitive.

In v1.36, `SELinuxMount` was disabled by default; in v1.37 it is GA and enabled by default. For eligible CSI PVCs, Kubernetes uses a SELinux label mount option instead of slower recursive relabeling only when `CSIDriver.spec.seLinuxMount: true` and all other eligibility conditions are met. This changes behavior: with a shared volume on one node, a Pod with an incompatible SELinux label may remain in `ContainerCreating`.

Before upgrading a SELinux-enabled cluster, enable `SELinuxWarningController`, resolve detected conflicts, and observe its metric. A workload intentionally sharing a volume across different labels can retain the previous behavior using:

```yaml
spec:
  securityContext:
    seLinuxChangePolicy: Recursive
```

Source: [Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).

## 3. Pod Certificates and ClusterTrustBundles: Stable

**CKS relevance:** Deep Dive / Production.

A ServiceAccount JWT remains a bearer credential: the token is limited by time, object binding, and audience, but is presented to a peer. Pod Certificates add an X.509 workload credential with a private key and proof-of-possession model. Kubelet creates a `PodCertificateRequest`, obtains a certificate chain from a signer, and rotates the credential. The certificate and trust bundle reach the workload through projected volumes; `ClusterTrustBundle` supplies trust anchors.

The signer remains pluggable. Kubernetes v1.37 does not ship a universal, ready-to-use core signer for SPIFFE or all workloads. Pod Certificates therefore do not automatically replace ServiceAccount JWTs or make existing Istio/SPIFFE identity mechanisms unnecessary.

Source: [Kubernetes v1.37: Pod Certificates and Cluster Trust Bundles](https://kubernetes.io/blog/2026/08/28/kubernetes-v1-37-pod-certificates-and-cluster-trust-bundles/).

## 4. KubeletInUserNamespace: Beta rootless node path

**CKS relevance:** Deep Dive / Production.

`KubeletInUserNamespace` is Beta in v1.37. When enabled, kubelet, the CRI/OCI runtime, CNI, and kube-proxy can run as a non-root host user inside a Linux user namespace. This rootless node architecture reduces the impact of compromised node components and may require CNI and CSI compatibility checks.

Do not confuse this with `spec.hostUsers: false`, which creates a user namespace for a Pod while node components may still run as host root. These are different, compatible security boundaries. Enabling the feature gate does not automatically convert existing rootful nodes to rootless mode.

Source: [Kubernetes v1.37: KubeletInUserNamespace Graduates to Beta](https://kubernetes.io/blog/2026/09/04/kubernetes-v1-37-rootless-beta/).

## 5. Deleting unreadable/corrupt resources: unsafe recovery path

**CKS relevance:** Production / Recovery / Dangerous operation.

In v1.37, the Beta, enabled-by-default feature gate `AllowUnsafeMalformedObjectDeletion` permits unsafe deletion of an object that cannot be read from storage because of decryption failure or decoding corruption. The delete request uses `ignoreStoreReadErrorWithClusterBreakingPotential`; both `delete` and `unsafe-delete-ignore-read-errors` permissions are required.

> ⚠️ This is a last-resort recovery mechanism with cluster-breaking potential. It bypasses finalizer and precondition checks, does not replace retention of old encryption keys or backup/restore, and is not a normal way to fix an EncryptionConfiguration error.

Source: [Kubernetes API Concepts: Force deletion](https://kubernetes.io/docs/reference/using-api/api-concepts/#force-deletion).

## 6. StorageVersionMigration: GA and enabled by default

**CKS relevance:** Production / Deep Dive.

In v1.37, the built-in `storagemigration.k8s.io/v1` API and controller became GA and enabled by default. Storage Version Migration declaratively rewrites persisted API objects into the current storage version. This is useful for API storage-version migration and can form part of controlled re-encryption after an encryption-provider or key change.

SVM is not the same as encryption-provider rotation: provider order, decryption of old data, backups, and the restore strategy remain separate operator responsibilities.

Source: [Kubernetes v1.37: Storage Version Migration Enabled by Default](https://kubernetes.io/blog/2026/08/31/kubernetes-v1-37-storage-version-migration-ga/).

---
[Contents](README.md)
