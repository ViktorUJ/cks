[Русская версия](APPENDIX_K8S_137_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_137_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_137_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_137_SECURITY_DELTA_FR.md) · [ქართული ვერსია](APPENDIX_K8S_137_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_137_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_137_SECURITY_DELTA_JP.md)

# Anhang. Kubernetes v1.37 Sicherheitsdelta

> Markierung: PRODUCTION / VERSION-SENSITIVE. Die Aufnahme in diesen Anhang bedeutet nicht, dass ein Thema zum aktuellen CKS-Prüfungspool gehört. Der offizielle Prüfungs-Snapshot des Kurses (siehe [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) verwendet Kubernetes v1.35, während die Basislinie des Kurstrainings v1.36 ist. Die neueste stabile Upstream-Version ist Kubernetes v1.37. Übernehmen Sie eine Funktion aus diesem Anhang nicht in 🎯 CKS Core ohne separate Bestätigung ihrer Prüfungs-/Lehrplanrelevanz.

In diesem Anhang sind sicherheitsrelevante Kubernetes v1.37-Änderungen zusammengefasst. Die Hauptkapitel und Übungen bleiben an den überprüften Prüfungs-/Trainingskontext gebunden; In diesem Dokument wird das Delta der aktuellen Produktionsänderungen erfasst.

## 1. Manifest-Based Admission Control: Beta und standardmäßig aktiviert

**CKS-Relevanz:** Deep Dive / Produktion / Versionssensitiv.

In der Trainingsbaseline v1.36 bleibt Manifest-Based Admission Control Alpha und standardmäßig deaktiviert. In Version 1.37 wurde es zur Betaversion, wobei das Feature-Gate `ManifestBasedAdmissionControlConfig` standardmäßig aktiviert war. Der API-Server lädt Webhooks und CEL-basierte Zulassungsrichtlinien aus statischen Dateien: Sie sind beim Start des API-Servers aktiv, verlassen sich nicht auf etcd, um die Zulassungskonfiguration selbst zu speichern, und können API-basierte Zulassungsressourcen vor Änderungen schützen.

Dies schließt die Bootstrap- und Selbstschutzlücke, erhöht jedoch das Betriebsrisiko: Ein ungültiges Manifest beim ersten Laden verhindert, dass der API-Server betriebsbereit wird. In HA liest jeder API-Server seine eigenen Dateien, was eine konsistente, atomare Bereitstellung erfordert.

Quelle: [Manifest-Based Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/manifest-admission-control/).

## 2. SELinuxMount: GA und standardmäßig aktiviert

**CKS-Relevanz:** Deep Dive / Produktion / Versionssensitiv.

In v1.36 war `SELinuxMount` standardmäßig deaktiviert; In Version 1.37 ist es GA und standardmäßig aktiviert. Für berechtigte CSI-PVCs verwendet Kubernetes nur dann eine SELinux-Label-Mount-Option anstelle einer langsameren rekursiven Neukennzeichnung, wenn `CSIDriver.spec.seLinuxMount: true` und alle anderen Berechtigungsbedingungen erfüllt sind. Dadurch ändert sich das Verhalten: Bei einem gemeinsam genutzten Volume auf einem Knoten kann ein Pod mit einem inkompatiblen SELinux-Label im `ContainerCreating` verbleiben.

Bevor Sie einen SELinux-fähigen Cluster aktualisieren, aktivieren Sie `SELinuxWarningController`, lösen Sie erkannte Konflikte und beobachten Sie seine Metrik. Eine Arbeitslast, die absichtlich ein Volume über verschiedene Bezeichnungen hinweg teilt, kann das vorherige Verhalten beibehalten, indem sie Folgendes verwendet:

```yaml
spec:
  securityContext:
    seLinuxChangePolicy: Recursive
```

Quelle: [Konfigurieren Sie einen Sicherheitskontext für einen Pod oder Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).

## 3. Pod Certificates und ClusterTrustBundles: Stabil

**CKS-Relevanz:** Deep Dive / Produktion.

Ein ServiceAccount-JWT bleibt ein Bearer-Credential: Das Token ist durch Gültigkeitsdauer, Objektbindung und Audience beschränkt, wird dem Gegenüber aber vorgelegt. Pod Certificates ergänzt X.509-Workload-Credentials mit privatem Schlüssel und Besitznachweis. Kubelet erstellt einen `PodCertificateRequest`, erhält eine Zertifikatskette vom Signierer und rotiert das Credential. Zertifikat und Trust-Bundle gelangen über projizierte Volumes zum Workload; `ClusterTrustBundle` liefert die Vertrauensanker.

Die Signierer-Implementierung bleibt austauschbar. Kubernetes v1.37 liefert keinen universellen, gebrauchsfertigen Kernsignierer für SPIFFE oder alle Workloads. Pod Certificates ersetzt daher nicht automatisch ServiceAccount-JWTs und macht bestehende Istio/SPIFFE-Identitätsmechanismen nicht unnötig.

Quelle: [Kubernetes v1.37: Pod Certificates und Cluster Trust Bundles](https://kubernetes.io/blog/2026/08/28/kubernetes-v1-37-pod-certificates-and-cluster-trust-bundles/).

## 4. KubeletInUserNamespace: Beta-Rootless-Knotenpfad

**CKS-Relevanz:** Deep Dive / Produktion.

`KubeletInUserNamespace` ist Beta in v1.37. Wenn diese Option aktiviert ist, können kubelet, die Laufzeit CRI/OCI, CNI und kube-proxy als Nicht-Root-Hostbenutzer innerhalb eines Linux-Benutzernamespace ausgeführt werden. Diese Rootless-Knotenarchitektur reduziert die Auswirkungen kompromittierter Knotenkomponenten und erfordert möglicherweise CNI- und CSI-Kompatibilitätsprüfungen.

Verwechseln Sie dies nicht mit `spec.hostUsers: false`, das einen Benutzernamensraum für einen Pod erstellt, während Knotenkomponenten weiterhin als Host-Root ausgeführt werden können. Dabei handelt es sich um unterschiedliche, kompatible Sicherheitsgrenzen. Durch die Aktivierung des Feature Gate werden vorhandene Root-Knoten nicht automatisch in den Rootless-Modus konvertiert.

Quelle: [Kubernetes v1.37: KubeletInUserNamespace wechselt zur Beta](https://kubernetes.io/blog/2026/09/04/kubernetes-v1-37-rootless-beta/).

## 5. Löschen unlesbarer/beschädigter Ressourcen: unsicherer Wiederherstellungspfad

**CKS-Relevanz:** Produktion / Wiederherstellung / Gefährlicher Vorgang.

In Version 1.37 ermöglicht das standardmäßig aktivierte Beta-Feature-Gate `AllowUnsafeMalformedObjectDeletion` das unsichere Löschen eines Objekts, das aufgrund eines Entschlüsselungsfehlers oder einer Decodierungsbeschädigung nicht aus dem Speicher gelesen werden kann. Die Löschanforderung verwendet `ignoreStoreReadErrorWithClusterBreakingPotential`; Es sind sowohl die Berechtigungen `delete` als auch `unsafe-delete-ignore-read-errors` erforderlich.

> ⚠️ Hierbei handelt es sich um einen Wiederherstellungsmechanismus der letzten Instanz mit Cluster-Breaking-Potenzial. Es umgeht Finalizer- und Vorbedingungsprüfungen, ersetzt nicht die Aufbewahrung alter Verschlüsselungsschlüssel oder die Sicherung/Wiederherstellung und ist keine normale Methode zur Behebung eines EncryptionConfiguration-Fehlers.

Quelle: [Kubernetes API Konzepte: Löschung erzwingen](https://kubernetes.io/docs/reference/using-api/api-concepts/#force-deletion).

## 6. StorageVersionMigration: GA und standardmäßig aktiviert

**CKS-Relevanz:** Produktion / Deep Dive.

In Version 1.37 wurden der integrierte `storagemigration.k8s.io/v1` API und der Controller GA und standardmäßig aktiviert. Storage Version Migration schreibt persistente API-Objekte deklarativ in die aktuelle Speicherversion um. Dies ist nützlich für die API-Speicherversionsmigration und kann Teil einer kontrollierten Neuverschlüsselung nach einer Änderung des Verschlüsselungsanbieters oder Schlüssels sein.

SVM ist nicht dasselbe wie die Rotation von Verschlüsselungsanbietern: Die Reihenfolge der Anbieter, die Entschlüsselung alter Daten, Backups und die Wiederherstellungsstrategie bleiben separate Verantwortlichkeiten des Betreibers.

Quelle: [Kubernetes v1.37: Storage Version Migration standardmäßig aktiviert](https://kubernetes.io/blog/2026/08/31/kubernetes-v1-37-storage-version-migration-ga/).

---
[Inhalt](README_DE.md)
