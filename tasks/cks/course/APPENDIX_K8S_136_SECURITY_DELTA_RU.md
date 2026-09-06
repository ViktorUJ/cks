<!-- Standalone RU release: ссылки на переводы удалены, потому что соответствующие файлы не входят в архив. -->

# Приложение. Kubernetes v1.36 Security Delta

> Маркер: PRODUCTION / VERSION-SENSITIVE. Наличие пункта в этом приложении не означает,
> что он входит в текущий CKS exam pool: официальный exam snapshot курса (см.
> [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) использует
> Kubernetes v1.35, тогда как training baseline курса - v1.36. Проверяйте каждый пункт
> перед использованием как экзаменационный факт: часть изменений производственно значима,
> но curriculum может отставать от minor-релиза.

Это приложение не заменяет основные главы курса. Оно собирает security-relevant изменения
Kubernetes v1.36 в одном месте, чтобы не размазывать их по всем 33 главам и не путать
production-currentness с exam-fidelity.

## 1. User Namespaces GA

**CKS relevance:** Deep Dive / Production.

- `spec.hostUsers: false` переводит Pod в user namespace: root внутри контейнера
  отображается на непривилегированный UID на хосте.
- Дополнительная граница defense-in-depth, а не замена existing controls
  (capabilities, seccomp, AppArmor, RBAC) - подробнее в [главе 03](03/ru.md).
- Linux-only; конкретные ограничения (raw block volumes, NFS) - см. главу 03.

## 2. Fine-Grained Kubelet API Authorization GA

**CKS relevance:** Core (используется в [главе 05](05/ru.md)).

- До этого изменения `nodes/proxy` был единственным subresource почти для всех kubelet
  API paths, включая безопасные-на-первый-взгляд `/metrics` и опасный `/exec`.
- GA вводит отдельные subresources: `nodes/stats`, `nodes/metrics`, `nodes/log`,
  `nodes/pods`, `nodes/healthz`, `nodes/configz`, `nodes/spec`, `nodes/checkpoint`.
- Для `/pods`, `/runningPods/`, `/healthz`, `/configz` kubelet сначала проверяет
  fine-grained subresource, при отказе - fallback на `nodes/proxy` (backward compatibility).
- **Почему это важно для security review:** monitoring agent с `nodes/proxy GET` может
  быть абьюзнут через WebSocket-семантику kubelet API для RCE в любом контейнере на ноде
  (`GET` маппится на RBAC `get`, но `kubelet` не проверяет отдельно `create` для
  последующей write-операции). Подробности - в главе 05 и блоке "Взгляд атакующего".
- Источник: [Kubernetes v1.36 blog - Fine-Grained Kubelet API Authorization Graduates to GA](https://kubernetes.io/blog/2026/04/24/kubernetes-v1-36-fine-grained-kubelet-authorization-ga/).

## 3. Mutating/Validating Admission Policy GA и Manifest-Based Admission Control (alpha)

**CKS relevance:** Core для VAP (используется в [главе 20](20/ru.md)); Manifest-Based
Admission Control - Deep Dive (alpha, disabled by default).

- Native CEL-based policy layer снижает потребность в дополнительном admission webhook
  для многих типовых правил, но не заменяет Kyverno/Gatekeeper там, где нужен generation,
  mutation сложных объектов или image verification supply chain (см. главу 20 и 26).
- Manifest-Based Admission Control (v1.36, alpha) позволяет static admission objects:
  все объекты требуют суффикс имени `.static.k8s.io`; `paramRef` в bindings запрещён;
  для static webhook разрешён только `clientConfig.url` (не `clientConfig.service`).
  Невалидный static manifest может помешать API server стать ready.

## 4. Service.spec.externalIPs формально deprecated

**CKS relevance:** Production/Deep Dive.

- `externalIPs` формально помечен deprecated в Kubernetes v1.36; ожидается, что будущий
  minor удалит поведение из kube-proxy и требование его поддержки из conformance criteria.
- **Security reason:** поле долгое время считалось риском - непривилегированный
  пользователь, способный создавать/редактировать Service, может заявить произвольный
  IP без валидации владения, что связано с MITM-риском (multitenant clusters) и
  напрямую относится к **CVE-2020-8554** (Man in the middle using LoadBalancer or
  ExternalIPs).
- **Современная альтернатива:** LoadBalancer Service через облачный/on-prem контроллер,
  либо Gateway API вместо прямого использования `externalIPs`.
- Источники: [Kubernetes v1.36 blog - Deprecation and removal of Service ExternalIPs](https://v1-36.docs.kubernetes.io/blog/2026/05/14/kubernetes-v1-36-deprecation-and-removal-of-service-externalips/), [CVE-2020-8554 advisory](https://discuss.kubernetes.io/t/security-advisory-cve-2020-8554-man-in-the-middle-using-loadbalancer-or-externalips/14003).

## 5. gitRepo volume permanently disabled

**CKS relevance:** Production/Deep Dive (supply-chain/mutable-source lesson).

- `gitRepo` volume type **permanently disabled** в Kubernetes v1.36 и не может быть
  повторно включён feature-gate'ом. Kubernetes API всё ещё принимает Pod с `gitRepo`
  volume, но kubelet откажется его запускать и вернёт ошибку.
- **Security reason:** `gitRepo` volume driver выполнял `git clone` внутри kubelet-managed
  процесса на ноде без должной изоляции; это создавало risk RCE через специально
  сформированный git-репозиторий (write hook при `git clone`).
- **Урок для supply chain:** volume type, который выполняет произвольный внешний код
  (даже "просто" `git clone`) во время provisioning, - тот же класс риска, что и mutable
  image tag без digest pinning: доверие переносится на внешний, не полностью
  контролируемый источник в момент выполнения, а не заранее проверяется.
- Источники: [AWS EKS release notes - gitRepo Volume Removal](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html), [kubernetes/kubernetes#125983 - Remove gitRepo volume type](https://github.com/kubernetes/kubernetes/issues/125983).

## 6. SELinux Volume Label Changes (mount-time relabeling)

**CKS relevance:** Deep Dive (используется в [главе 18](18/ru.md)).

- Recursive SELinux relabel выполняет container runtime (не kubelet).
- Для PVC с access mode, отличным от `ReadWriteOncePod`, mount-based relabel (`-o context=`)
  требует включённого feature gate `SELinuxMount` (выключен по умолчанию в v1.36) и
  `CSIDriver.spec.seLinuxMount: true` у конкретного CSI-драйвера; иначе используется
  более медленный recursive relabel.
- Подробности разделения recursive relabel vs `MountOption` - см. главу 18.

## Как использовать это приложение

Для каждого пункта перед тем, как ссылаться на него как на "текущий факт" в лекции или
экзаменационной подготовке:

1. сверьте `checked_at` в [`metadata/tool-compatibility.yaml`](../metadata/tool-compatibility.yaml)
   и [`metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml);
2. проверьте, входит ли конкретная фича в текущий curriculum (`CKS_Curriculum` PDF) -
   не предполагайте, что production-current автоматически означает exam-relevant;
3. если пункт используется в лабе или главе как *core* материал (см.
   [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml)), убедитесь что
   формулировка в этом приложении и в самой главе синхронизированы.

---
[Оглавление](README_RU.md)
