[Русская версия](APPENDIX_K8S_136_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_136_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_136_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_136_SECURITY_DELTA_FR.md) · [ქართული ვერსია](APPENDIX_K8S_136_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_136_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_136_SECURITY_DELTA_JP.md)

# Anhang. Kubernetes v1.36 Sicherheitsdelta

> Markierung: PRODUCTION / VERSION-SENSITIVE. Die Aufnahme in diesen Anhang bedeutet nicht, dass ein Thema zum aktuellen CKS-Prüfungspool gehört. Der offizielle Prüfungs-Snapshot des Kurses (siehe [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) verwendet Kubernetes v1.35, während die Basislinie des Kurstrainings v1.36 ist. Überprüfen Sie jeden Punkt, bevor Sie ihn als Prüfungsfakt behandeln: Einige Änderungen sind in der Produktion von Bedeutung, aber der Lehrplan kann hinter einer Nebenversion zurückbleiben.

Dieser Anhang ergänzt die Hauptkurskapitel. Es sammelt sicherheitsrelevante Kubernetes v1.36-Änderungen an einem Ort, anstatt sie über alle 33 Kapitel zu verteilen oder Produktionsaktualität mit Prüfungstreue zu verwechseln.

## 1. User Namespaces GA

**CKS-Relevanz:** Deep Dive / Produktion.

- `spec.hostUsers: false` platziert einen Pod in einem Benutzernamensraum: Root innerhalb des Containers wird einem unprivilegierten UID auf dem Host zugeordnet.
- Dies ist eine zusätzliche Tiefenverteidigungsgrenze und kein Ersatz für bestehende Kontrollen (Fähigkeiten, seccomp, AppArmor, RBAC). Siehe [Kapitel 03](03/de.md).
- Nur Linux; Spezifische Einschränkungen (Rohblock-Volumes, NFS) finden Sie in Kapitel 03.

## 2. Fine-Grained Kubelet API Authorization GA

**CKS-Relevanz:** Kern (verwendet in [Kapitel 05](05/de.md)).

- Bisher war `nodes/proxy` die einzige Unterressource für fast alle kubelet API Pfade, einschließlich scheinbar sicherer `/metrics` und gefährlicher `/exec`.
- GA führt separate Unterressourcen ein: `nodes/stats`, `nodes/metrics`, `nodes/log`, `nodes/pods`, `nodes/healthz`, `nodes/configz`, `nodes/spec`, `nodes/checkpoint`.
- Für `/pods`, `/runningPods/`, `/healthz` und `/configz` überprüft kubelet zunächst die feinkörnige Unterressource und greift bei Ablehnung aus Gründen der Abwärtskompatibilität auf `nodes/proxy` zurück.
- **Warum dies für die Sicherheitsüberprüfung wichtig ist:** Ein Überwachungsagent mit `nodes/proxy GET` kann durch die WebSocket-Semantik kubelet API für RCE in jedem Container auf dem Knoten missbraucht werden. `GET` wird auf RBAC `get` abgebildet, aber `kubelet` prüft `create` nicht separat für den nachfolgenden Schreibvorgang. Siehe Kapitel 05 und seinen Block „Perspektive des Angreifers“.
- Quelle: [Kubernetes v1.36 Blog - Fine-Grained Kubelet API Authorization Graduates to GA](https://kubernetes.io/blog/2026/04/24/kubernetes-v1-36-fine-grained-kubelet-authorization-ga/).

## 3. Änderung/Validierung der Zulassungsrichtlinie GA und Manifest-Based Admission Control (Alpha)

**CKS-Relevanz:** Core für VAP (verwendet in [Kapitel 20](20/de.md)); Manifest-Based Admission Control ist Deep Dive (Alpha, standardmäßig deaktiviert).

- Die native CEL-basierte Richtlinienschicht reduziert die Notwendigkeit eines zusätzlichen Zulassungs-Webhooks für viele gängige Regeln. Es ersetzt nicht Kyverno/Gatekeeper für die Generierung, Mutation komplexer Objekte oder die Bildverifizierung in der Lieferkette (siehe Kapitel 20 und 26).
- Manifest-Based Admission Control (v1.36, Alpha) unterstützt statische Zulassungsobjekte: Alle Objekte erfordern ein `.static.k8s.io`-Namenssuffix; `paramRef` in Bindungen ist verboten; Statische Webhooks erlauben nur `clientConfig.url`, nicht `clientConfig.service`. Ein ungültiges statisches Manifest kann verhindern, dass der API-Server bereit ist.

## 4. Service.spec.externalIPs offiziell veraltet

**CKS-Relevanz:** Produktion/Deep Dive.

- `externalIPs` ist in Kubernetes v1.36 offiziell veraltet. Es wird erwartet, dass eine zukünftige Nebenversion das Verhalten von kube-proxy und seine Supportanforderung aus den Konformitätskriterien entfernt.
- **Sicherheitsgrund:** Das Feld stellt seit langem ein Risiko dar: Ein nicht privilegierter Benutzer, der Services erstellen/bearbeiten kann, kann eine beliebige IP ohne Besitzüberprüfung beanspruchen. Dies führt zu einem MITM-Risiko in Multitenant-Clustern und steht in direktem Zusammenhang mit **CVE-2020-8554** (Man in the Middle mit LoadBalancer oder ExternalIPs).
- **Aktuelle Alternative:** ein LoadBalancer Service über einen Cloud-/lokalen Controller oder ein Gateway API anstelle der direkten Verwendung von `externalIPs`.
- Quellen: [Kubernetes v1.36 Blog - Einstellung und Entfernung von Service ExternalIPs](https://v1-36.docs.kubernetes.io/blog/2026/05/14/kubernetes-v1-36-deprecation-and-removal-of-service-externalips/), [CVE-2020-8554 Advisory](https://discuss.kubernetes.io/t/security-advisory-cve-2020-8554-man-in-the-middle-using-loadbalancer-or-externalips/14003).

## 5. GitRepo-Volume dauerhaft deaktiviert

**CKS-Relevanz:** Produktion/Deep Dive (Lektion zur Lieferkette/veränderlichen Quellen).

- Der Volume-Typ `gitRepo` ist in Kubernetes v1.36 **dauerhaft deaktiviert** und kann nicht durch ein Feature-Gate wieder aktiviert werden. Der Kubernetes API akzeptiert weiterhin einen Pod mit einem `gitRepo`-Volume, aber kubelet weigert sich, ihn zu starten, und gibt einen Fehler zurück.
- **Sicherheitsgrund:** Der `gitRepo`-Volume-Treiber hat `git clone` in einem von kubelet verwalteten Prozess auf dem Knoten ohne ausreichende Isolierung ausgeführt. Ein speziell gestaltetes Git-Repository könnte daher RCE durch einen Schreib-Hook während `git clone` verursachen.
- **Lektion zur Lieferkette:** Ein Volume-Typ, der während der Bereitstellung beliebigen externen Code ausführt (sogar „nur“ `git clone`), birgt die gleiche Risikoklasse wie ein veränderbares Image-Tag ohne Digest-Pinning. Vertrauen wird zur Laufzeit auf eine externe, unvollständig kontrollierte Quelle übertragen, anstatt vorher überprüft zu werden.
- Quellen: [AWS EKS-Versionshinweise - GitRepo-Volume-Entfernung](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html), [kubernetes/kubernetes#125983 - GitRepo-Volume-Typ entfernen](https://github.com/kubernetes/kubernetes/issues/125983).

## 6. SELinux Änderungen an der Datenträgerbezeichnung (Umbenennung zur Bereitstellungszeit)

**CKS-Relevanz:** Deep Dive (verwendet in [Kapitel 18](18/de.md)).

- Anstelle von kubelet führt die Containerlaufzeit eine rekursive SELinux-Umbenennung durch.
- Für PVCs mit einem anderen Zugriffsmodus als `ReadWriteOncePod` erfordert die mountbasierte Neukennzeichnung (`-o context=`) das Feature-Gate `SELinuxMount` (standardmäßig in Version 1.36 deaktiviert) und `CSIDriver.spec.seLinuxMount: true` auf dem jeweiligen CSI-Treiber. Andernfalls wird eine langsamere rekursive Umbenennung verwendet.
- Zur Unterscheidung zwischen rekursiver Umbenennung und `MountOption` siehe Kapitel 18.

## So verwenden Sie diesen Anhang

Bevor Sie in einer Vorlesung oder Prüfungsvorbereitung einen Punkt als „aktuelle Tatsache“ zitieren:

1. Überprüfen Sie `checked_at` in [`metadata/tool-compatibility.yaml`](../metadata/tool-compatibility.yaml) und [`metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml).
2. Prüfen Sie, ob die spezifische Funktion im aktuellen Lehrplan enthalten ist (`CKS_Curriculum` PDF). Gehen Sie nicht davon aus, dass produktionsaktuell automatisch prüfungsrelevant bedeutet.
3. Wenn ein Element als *Kernmaterial* in einem Labor oder Kapitel verwendet wird (siehe [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml)), halten Sie seinen Wortlaut hier und in diesem Kapitel synchron.

---
[Inhalt](README_DE.md)
