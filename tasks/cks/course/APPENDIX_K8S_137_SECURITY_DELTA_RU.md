<!-- Standalone RU release: ссылки на переводы удалены, потому что соответствующие файлы не входят в архив. -->

# Приложение. Kubernetes v1.37 Security Delta

> Маркер: PRODUCTION / VERSION-SENSITIVE. Наличие пункта в этом приложении не означает,
> что он входит в текущий CKS exam pool: официальный exam snapshot курса (см.
> [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) использует
> Kubernetes v1.35, тогда как training baseline курса - v1.36. Upstream latest stable -
> Kubernetes v1.37. Не переносите feature из этого приложения в 🎯 CKS Core без отдельного
> подтверждения exam/curriculum relevance.

Это приложение собирает security-relevant изменения Kubernetes v1.37. Основные главы и
лаборатории остаются привязаны к проверенному exam/training context; здесь зафиксирован
production-current delta.

## 1. Manifest-Based Admission Control: Beta и enabled by default

**CKS relevance:** Deep Dive / Production / Version-Sensitive.

В training baseline v1.36 Manifest-Based Admission Control остаётся alpha и выключен по
умолчанию. В v1.37 функция стала Beta, а feature gate
`ManifestBasedAdmissionControlConfig` включён по умолчанию. API server загружает webhook и
CEL-based admission policies из static files: они активны при старте API server, не зависят
от etcd для хранения самой admission-конфигурации и могут защищать API-based admission
resources от изменения.

Это закрывает bootstrap и self-protection gap, но повышает операционный риск: невалидный
manifest при первоначальной загрузке не даст API server стать ready. Для HA каждый API
server читает собственные файлы, поэтому нужна согласованная и атомарная доставка.

Источник: [Manifest-Based Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/manifest-admission-control/).

## 2. SELinuxMount: GA и enabled by default

**CKS relevance:** Deep Dive / Production / Version-Sensitive.

В v1.36 `SELinuxMount` был выключен по умолчанию; в v1.37 он GA и включён по умолчанию.
Для подходящих CSI PVC Kubernetes применяет SELinux label mount option вместо медленного
recursive relabel только при `CSIDriver.spec.seLinuxMount: true` и выполнении остальных
eligibility conditions. Это меняет поведение: при совместном томе на одной ноде Pod с
несовместимой SELinux label может остаться в `ContainerCreating`.

До upgrade SELinux-enabled кластера включите `SELinuxWarningController`, устраните
обнаруженные conflicts и наблюдайте его metric. Если workload намеренно разделяет том
между разными labels, он может сохранить старое поведение через:

```yaml
spec:
  securityContext:
    seLinuxChangePolicy: Recursive
```

Источник: [Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).

## 3. Pod Certificates и ClusterTrustBundles: Stable

**CKS relevance:** Deep Dive / Production.

ServiceAccount JWT остаётся bearer credential: token ограничен временем, object binding и
audience, но предъявляется peer. Pod Certificates добавляют X.509 workload credential с
private key и proof-of-possession model. Kubelet создаёт `PodCertificateRequest`, получает
certificate chain от signer и ротирует credential; certificate и trust bundle передаются
workload через projected volumes. `ClusterTrustBundle` поставляет trust anchors.

Signer остаётся pluggable. Kubernetes v1.37 не поставляет готовый универсальный core signer
для SPIFFE или всех workload. Поэтому Pod Certificates не заменяют ServiceAccount JWT
автоматически и не делают существующие Istio/SPIFFE identity mechanisms ненужными.

Источник: [Kubernetes v1.37: Pod Certificates and Cluster Trust Bundles](https://kubernetes.io/blog/2026/08/28/kubernetes-v1-37-pod-certificates-and-cluster-trust-bundles/).

## 4. KubeletInUserNamespace: Beta rootless node path

**CKS relevance:** Deep Dive / Production.

`KubeletInUserNamespace` в v1.37 Beta. При включении kubelet, CRI/OCI runtime, CNI и
kube-proxy могут работать как non-root host user внутри Linux user namespace. Это
rootless node architecture, уменьшающая последствия компрометации node components; она
может требовать проверки совместимости CNI и CSI.

Не путайте её с `spec.hostUsers: false`: последний создаёт user namespace для Pod, но node
components всё ещё могут работать host-root. Это разные и сочетаемые security boundaries.
Включённый feature gate не переводит существующие rootful nodes в rootless mode автоматически.

Источник: [Kubernetes v1.37: KubeletInUserNamespace Graduates to Beta](https://kubernetes.io/blog/2026/09/04/kubernetes-v1-37-rootless-beta/).

## 5. Удаление unreadable/corrupt resources: unsafe recovery path

**CKS relevance:** Production / Recovery / Dangerous operation.

В v1.37 Beta и enabled by default feature gate `AllowUnsafeMalformedObjectDeletion` разрешает
unsafe delete объекта, который невозможно прочитать из storage из-за decryption failure или
decode corruption. Для этого delete request использует
`ignoreStoreReadErrorWithClusterBreakingPotential`; нужны права `delete` и
`unsafe-delete-ignore-read-errors`.

> ⚠️ Это последний recovery mechanism с cluster-breaking potential. Он пропускает finalizer
> и precondition checks, не заменяет retention старых encryption keys, backup/restore и не
> является обычным способом исправить ошибку EncryptionConfiguration.

Источник: [Kubernetes API Concepts: Force deletion](https://kubernetes.io/docs/reference/using-api/api-concepts/#force-deletion).

## 6. StorageVersionMigration: GA и enabled by default

**CKS relevance:** Production / Deep Dive.

В v1.37 встроенные `storagemigration.k8s.io/v1` API и controller стали GA и включены по
умолчанию. Storage Version Migration декларативно переписывает persisted API objects в
current storage version; это полезно при API storage-version migration и может быть частью
контролируемой re-encryption после смены encryption provider или key.

SVM не равна encryption-provider rotation: порядок providers, decrypt старых данных,
backup и restore strategy остаются отдельными обязанностями оператора.

Источник: [Kubernetes v1.37: Storage Version Migration Enabled by Default](https://kubernetes.io/blog/2026/08/31/kubernetes-v1-37-storage-version-migration-ga/).

---
[Оглавление](README_RU.md)
