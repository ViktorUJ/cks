[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: Praxisleitfaden für Cloud-Native- und Kubernetes-Sicherheit

KCSA (Kubernetes and Cloud Native Security Associate) ist eine Associate-Zertifizierung von CNCF und Linux Foundation für Cloud-Native- und Kubernetes-Sicherheit, die sich an angehende Fachleute richtet und konzeptionell ausgerichtet ist. Der Kurs nimmt in der Lernlaufbahn KCNA (optional) → KCSA → CKA → CKS seinen Platz ein: KCSA erklärt Grundlagen und Bedrohungsmodelle, CKA vermittelt das für CKS erforderliche praktische Fundament, und CKS erweitert die Security Skills hands-on. Es gibt keine formalen Voraussetzungen; ein grundlegendes Verständnis von `Pod`, `Deployment`, `Service` und `kubectl` genügt.

> **Zu Links auf CKA und CKS.** Das eigenständige KCSA-Archiv enthält keine CKA- und CKS-Verzeichnisse. Daher bleiben Links innerhalb von KCSA in der Standalone-Distribution anklickbar, während kursübergreifende Verweise auf CKA/CKS als normaler Text ohne relative URLs veröffentlicht werden. Im Monorepo-Build können sie als funktionierende Links zu benachbarten Kursen oder als stabile absolute URLs generiert werden.

> **Prüfungsformat und Beispielversion.** KCSA ist eine Multiple-Choice-Prüfung. Nach den am 1. September 2026 überprüften Regeln der Linux Foundation umfasst die Standard-MCQ-Prüfung (multiple choice question, Frage mit Antwortauswahl) 60 Fragen, dauert 90 Minuten und erfordert 75 % zum Bestehen; hands-on Aufgaben gibt es nicht. Prüfen Sie die aktuellen LF-Anforderungen vor der Registrierung unbedingt erneut, da sich diese Parameter ändern können. Die Kursbeispiele beziehen sich auf Kubernetes `v1.36`. Aktuelle Gewichtungen, Quellen und Änderungen des Curriculums sind in der [Versionsrichtlinie](../VERSION_POLICY.md) dokumentiert.

## Aufbau des Kurses

Jedes Thema ist ein Verzeichnis mit einer Nummer und dem kanonischen russischen Quelltext `ru.md`. Für jedes Kapitel sind außerdem Übersetzungen veröffentlicht: English `README.md`, Español `es.md`, Français `fr.md`, Deutsch `de.md`, ქართული `ge.md`, 繁體中文 `tw.md` und 日本語 `jp.md`. Die Kapitel sind nach KCSA-Domains gruppiert und farblich markiert:

- 🟦 Overview of Cloud Native Security - 14%
- 🟥 Kubernetes Cluster Component Security - 22%
- 🟩 Kubernetes Security Fundamentals - 22%
- 🟪 Kubernetes Threat Model - 16%
- 🟨 Platform Security - 16%
- 🟫 Compliance and Security Frameworks - 10%
- ⬜ Einführung, Grundlagen und Prüfungsvorbereitung

Die KCSA-Praxis besteht aus Multiple-Choice-Fragen und Mock-Prüfungen, nicht aus Laborübungen. Diese Datei enthält einen einheitlichen Vorbereitungspfad und die Prüfungsnavigation. Begriffe sind im [Glossar](GLOSSARY_DE.md) zusammengefasst.

## Offizielles Prüfungsprogramm

| Domain | Gewichtung |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

## Inhalt

### Teil 0. Einführung und Grundlagen ⬜

1. [Einführung: KCSA-Prüfung, Format, Platz in der Zertifizierungsabfolge, Versionen](01/de.md)
2. [Cloud Native und warum Sicherheit](02/de.md)

### Teil 1. Overview of Cloud Native Security - 14% 🟦

3. [4C der Cloud-Sicherheit: Cloud, Cluster, Container, Code](03/de.md)
4. [Sicherheit von Cloud-Anbieter und Infrastruktur](04/de.md)
5. [Kontrollmechanismen, Frameworks und Isolationstechniken](05/de.md)
6. [Sicherheit von Artefakten, Images und Code](06/de.md)

### Teil 2. Kubernetes Cluster Component Security - 22% 🟥

7. [Sicherheit der Control Plane: API Server, Controller Manager, Scheduler, Etcd](07/de.md)
8. [Knotensicherheit: Kubelet, Container Runtime, KubeProxy](08/de.md)
9. [Pod, Container-Netzwerk, Storage und Client-Sicherheit](09/de.md)

### Teil 3. Kubernetes Security Fundamentals - 22% 🟩

10. [Authentifizierung und Autorisierung](10/de.md)
11. [Pod Security Standards und Pod Security Admission](11/de.md)
12. [Secrets](12/de.md)
13. [Network Policy, Isolation und Segmentierung](13/de.md)
14. [Audit Logging](14/de.md)

### Teil 4. Kubernetes Threat Model - 16% 🟪

15. [Vertrauensgrenzen, Datenflüsse und Bedrohungsmodell](15/de.md)
16. [Kategorien von Kubernetes-Bedrohungen](16/de.md)

### Teil 5. Platform Security - 16% 🟨

17. [Supply Chain, Image-Registries und Admission Control](17/de.md)
18. [Observability, PKI, Connectivity und Service Mesh](18/de.md)

### Teil 6. Compliance and Security Frameworks - 10% 🟫

19. [Compliance und Sicherheits-Frameworks](19/de.md)

### Teil 7. Prüfungsvorbereitung ⬜

20. [KCSA-Prüfung: Strategie, Zeitmanagement, Checkliste](20/de.md)

## Praxis

- 📝 [KCSA-Mock-Prüfungen](../mock) - verfügbar sind die englischen Mock 01 und Mock 02 im MCQ-Format für unabhängige Übungseinheiten. Die Fragen sind nach den Domain-Gewichtungen verteilt; terragrunt/bats-Labs werden für KCSA nicht erstellt.

Beginnen Sie mit den Kapiteln 01-02 und bearbeiten Sie die Domains anschließend der Reihe nach. Die abschließende Taktik und Checkliste sind in [Kapitel 20](20/de.md) zusammengefasst.

## Weiterführende Lektüre

- [Offizielle Kubernetes-Dokumentation: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- Der CKS-Kurs ist der nächste Schritt für eine Vertiefung in praktisches Hardening und Untersuchungen.
