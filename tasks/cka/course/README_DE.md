[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# CKA + CKAD: praktisches Selbstlernbuch zu Kubernetes

Ein gemeinsamer Praxiskurs zur Vorbereitung auf zwei Zertifizierungen von CNCF und
Linux Foundation gleichzeitig:

- **CKA** (Certified Kubernetes Administrator) - Administration des Clusters:
  Installation, Wartung, Netzwerk, Storage, Sicherheit, troubleshooting.
- **CKAD** (Certified Kubernetes Application Developer) - Entwicklung und Betrieb
  von Anwendungen in Kubernetes: Workloads, Konfiguration, Observability,
  Services.

Die Prüfungen überschneiden sich stark (Workloads, Services, Konfiguration, Storage,
Observability), deshalb ist es effizienter, sie gemeinsam zu lernen als getrennt. Der
gemeinsame Kern wird einmal durchgearbeitet, die Besonderheiten jeder Prüfung stehen in
eigenen Teilen. Der Kurs ist an die Laborübungen in `tasks/cka/labs` gebunden.

> **Kubernetes-Version.** Der Kurs orientiert sich an der aktuellen Prüfungsversion -
> Kubernetes `v1.35` (Programme von CKA und CKAD 2025-2026). Beide Prüfungen sind
> praktisch, in einem laufenden Cluster über die Kommandozeile: CKA - 2 Stunden, CKAD -
> 2 Stunden, Bestehensgrenze 66%.

## Wie der Kurs aufgebaut ist

Jedes Thema ist ein Ordner mit einer Nummer. Darin liegen lokalisierte Dateien. Die
Hauptsprache ist Russisch (`ru.md`), daraus entstehen die Übersetzungen: Englisch
(`README.md`), Spanisch (`es.md`), Französisch (`fr.md`), Deutsch (`de.md`) und
Georgisch (`ge.md`). Der Sprachumschalter steht in der ersten Zeile jeder Datei.

Jedes Kapitel ist markiert, zu welcher Prüfung es gehört:

- 🟦 **CKA** - nur für Administratoren
- 🟩 **CKAD** - nur für Entwickler
- 🟪 **CKA + CKAD** - gemeinsames Thema für beide Prüfungen

Am Ende des Kurses gibt es zwei separate Wegweiser, die Kapitel und Labs für eine
konkrete Prüfung zusammenstellen:

- [Programm und Labs für CKA](CKA_DE.md)
- [Programm und Labs für CKAD](CKAD_DE.md)

Alle Begriffe des Kurses sind in einem einzigen Nachschlagewerk gesammelt:

- [Glossar des Kurses](GLOSSARY_DE.md) - alle Begriffe nach Kapiteln mit Links

## Offizielle Prüfungsprogramme

CKA (Domänen und Gewichtung):

| Domäne | Gewicht |
|-------|-----|
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Storage | 10% |
| Services & Networking | 20% |
| Troubleshooting | 30% |

CKAD (Domänen und Gewichtung):

| Domäne | Gewicht |
|-------|-----|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services and Networking | 20% |

## Inhalt

### Teil 0. Fundament für Einsteiger (optional) 🟪 CKA + CKAD

Vorbereitender Teil für alle, die ohne solide Grundlagen zu Netzwerken, DNS, TLS,
Containern, Linux und YAML einsteigen. Wenn Sie diese Themen sicher beherrschen -
können Sie direkt zu Teil 1 übergehen. Eigene Labs hat dieser Teil nicht: es ist das
Fundament, auf dem die übrigen Kapitel aufbauen (die Fertigkeiten aus 0.5-0.7 werden
direkt in den Node- und Netzwerk-Labs angewendet).

- 0.1. [Netzwerke von Grund auf: IP, Ports, CIDR und NAT](00-1-net/de.md)
- 0.2. [DNS von Grund auf: wie Namen zu Adressen werden](00-2-dns/de.md)
- 0.3. [TLS und Zertifikate von Grund auf: HTTPS, Schlüssel und Zertifizierungsstellen](00-3-tls/de.md)
- 0.4. [Container und Docker von Grund auf: Images, Layer, Registries und Runtime](00-4-containers/de.md)
- 0.5. [Linux und Node-Werkzeuge von Grund auf: SSH, sudo, systemd, Logs, Dateien](00-5-linux/de.md)
- 0.6. [YAML von Grund auf: Einrückung, Listen, Wörterbücher und Manifeste](00-6-yaml/de.md)
- 0.7. [Linux-Netzwerk unter der Haube: network namespaces, veth und Routing](00-7-netns/de.md)
- 0.8. [vim in 15 Minuten: überleben und für YAML einrichten](00-8-vim/de.md)

### Teil 1. Grundlagen von Kubernetes 🟪 CKA + CKAD

1. [Einführung: Kubernetes, die Prüfungen CKA und CKAD und der Aufbau des Kurses](01/de.md)
2. [Architektur von Kubernetes: Control Plane und Worker-Knoten](02/de.md)
3. [Arbeiten mit kubectl: der imperative und der deklarative Ansatz](03/de.md)
4. [Pods: Lebenszyklus, Erstellung und Konfiguration](04/de.md)
5. [ReplicaSet und Deployment](05/de.md)
6. [Namespaces, Labels, Selektoren und Annotations](06/de.md)
7. [Services: ClusterIP, NodePort, LoadBalancer, Endpoints](07/de.md)

### Teil 2. Workloads und Scheduling 🟪 CKA + CKAD

8. [Deployment: rolling update und rollback](08/de.md)
9. [Deployment-Strategien: blue/green und canary](09/de.md) 🟩 CKAD
10. [Jobs und CronJobs](10/de.md)
11. [DaemonSet und StatefulSet](11/de.md)
12. [Planung von Pods: nodeName, nodeSelector, affinity](12/de.md)
13. [Taints und tolerations](13/de.md)
14. [Ressourcen: requests, limits, LimitRange, ResourceQuota](14/de.md)
15. [Static Pods, PriorityClass, mehrere Scheduler](15/de.md)
16. [Autoscaling von Lasten: HPA](16/de.md)

### Teil 3. Konfiguration und Sicherheit von Anwendungen 🟪 CKA + CKAD

17. [Befehle, Argumente und Umgebungsvariablen](17/de.md)
18. [ConfigMap](18/de.md)
19. [Secret](19/de.md)
20. [SecurityContext und capabilities](20/de.md)
21. [ServiceAccount; Authentifizierung, Autorisierung, Admission](21/de.md)

### Teil 4. Design und Build von Anwendungen 🟩 CKAD

22. [Multi-Container-Pods: sidecar, adapter, ambassador, init](22/de.md)
23. [Container-Images: Build, Dockerfile, Optimierung](23/de.md)
24. [Volumes für Anwendungen: emptyDir und ephemere Volumes](24/de.md)

### Teil 5. Datenspeicherung 🟪 CKA + CKAD

25. [Volumes, PersistentVolume und PersistentVolumeClaim](25/de.md)
26. [StorageClass, dynamisches Provisioning, Speicher im StatefulSet](26/de.md)

### Teil 6. Observability und Wartung 🟪 CKA + CKAD

27. [Zustandsprüfungen: liveness, readiness, startup probes](27/de.md)
28. [Logging und Monitoring: logs, metrics-server, kubectl top](28/de.md)
29. [Debuggen von Anwendungen und Veralten von APIs](29/de.md)

### Teil 7. Services und Netzwerk 🟪 CKA + CKAD

30. [Das Netzwerkmodell von Kubernetes, Pod-Netz und CNI](30/de.md)
31. [Service von innen, DNS und CoreDNS](31/de.md)
32. [Ingress und Ingress-Controller](32/de.md)
33. [Gateway API](33/de.md)
34. [NetworkPolicy](34/de.md)

### Teil 8. Cluster-Architektur, Installation und Konfiguration 🟦 CKA

35. [Installation eines Clusters mit kubeadm](35/de.md)
- 35A. [Hochverfügbarkeit (HA): mehrere Control-Plane-Nodes, etcd-Topologien und Load Balancer](35-2-ha/de.md) 🟦 CKA
- 35B. [Cluster-Design und Sizing: Infrastruktur, Topologie, IaC](35-3-design/de.md) 🟦 CKA
36. [Upgrade des Clusters (lifecycle)](36/de.md)
37. [Backup und Wiederherstellung von etcd](37/de.md)
38. [RBAC: Role, ClusterRole und bindings](38/de.md)
39. [TLS-Zertifikate, kubeconfig und CSR API](39/de.md)
40. [Erweiterungsschnittstellen: CNI, CSI, CRI](40/de.md)
41. [CRD und Operatoren](41/de.md)
42. [Helm](42/de.md)
43. [Kustomize](43/de.md)

### Teil 9. Troubleshooting 🟦 CKA

44. [Debugging von Anwendungsfehlern](44/de.md)
45. [Debugging der Control Plane und der Worker-Nodes](45/de.md)
46. [Debugging von Services und Netzwerk](46/de.md)

### Teil 10. Prüfungsvorbereitung

47. [Prüfung CKAD: Format, Zeitmanagement, JSONPath und Produktivität von kubectl](47/de.md) 🟩 CKAD
48. [Prüfung CKA: Format, Zeitmanagement und Strategie](48/de.md) 🟦 CKA

## Praxis

- 🧪 [Laborübungen](../labs) - 25 Labs im Prüfungsstil mit automatischer Prüfung `check_result`
- 🧪 [CKA-Mock-Prüfungen](../mock) - Mock-Prüfungen für CKA unter Zeitdruck (Multicluster, SSH, Gewichtung der Aufgaben)
- 🧪 [CKAD-Mock-Prüfungen](../../ckad/mock) - Mock-Prüfungen für CKAD unter Zeitdruck

## Praxis

- 🧪 [Laborübungen](../labs) - 25 Labs im Prüfungsstil mit automatischer Prüfung `check_result`
- 🧪 [CKA-Mock-Prüfungen](../mock) - Probelauf des CKA unter Zeitdruck (Multicluster, SSH, Aufgabengewichte)
- 🧪 [CKAD-Mock-Prüfungen](../../ckad/mock) - Probelauf des CKAD unter Zeitdruck
