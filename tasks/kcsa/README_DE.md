[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: Kubernetes and Cloud Native Security Associate - Lernmaterialien

Vollständige Vorbereitung auf die Zertifizierung **Kubernetes and Cloud Native Security Associate (KCSA)**: ein Selbststudienkurs und vollständige Mock-Prüfungen - alles an einem Ort.

KCSA ist eine Associate-Zertifizierung von CNCF und Linux Foundation für Cloud-Native- und Kubernetes-Sicherheit, die sich an angehende Fachleute richtet und konzeptionell ausgerichtet ist. Der Kurs nimmt in der Lernlaufbahn KCNA (optional) → KCSA → CKA → CKS seinen Platz ein: KCSA erklärt Grundlagen und Bedrohungsmodelle, CKA vermittelt das für CKS erforderliche praktische Fundament, und CKS erweitert die Security Skills hands-on. Es gibt keine formalen Voraussetzungen; ein grundlegendes Verständnis von `Pod`, `Deployment`, `Service` und `kubectl` genügt.

## Was dieses Verzeichnis enthält

| Teil | Pfad | Was es ist |
|------|------|-----------|
| **Kurs** | [`course/`](course/README_DE.md) | 20 Kapitel im Selbststudium, die alle 6 offiziellen KCSA-Domains abdecken |
| **Mock-Prüfungen** | [`mock/`](mock/README.md) | 2 vollständige Mock-Prüfungen mit je 60 Fragen im MCQ-Format |

Die KCSA-Praxis besteht aus Multiple-Choice-Fragen und Mock-Prüfungen, nicht aus Laborübungen. Empfohlener Weg: die Kapitel des Kurses der Reihe nach lesen und anschließend beide Mock-Prüfungen unter prüfungsnahem Zeitdruck absolvieren.

## Der Kurs

Der Kurs ([`course/README_DE.md`](course/README_DE.md)) umfasst 20 Kapitel, die jeweils in 8 Sprachen veröffentlicht sind: Englisch (`README.md`), Russisch (`ru.md`, kanonische Quelle), Spanisch (`es.md`), Französisch (`fr.md`), Deutsch (`de.md`), Georgisch (`ge.md`), traditionelles Chinesisch (`tw.md`) und Japanisch (`jp.md`). Die Kapitel sind nach den offiziellen KCSA-Domains gruppiert:

| Domain | Gewichtung |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

Begriffe sind im [Glossar](course/GLOSSARY_DE.md) zusammengefasst. Die Kapitel 1-2 führen in die Prüfung und die Cloud-Native-Sicherheit ein; Kapitel 20 fasst die abschließende Prüfungsstrategie, das Zeitmanagement und eine Checkliste zusammen.

## Mock-Prüfungen

Zwei vollständige Mock-Prüfungen ([`mock/`](mock/README.md)) simulieren die reale KCSA-Prüfung:

- **Mock 01** ([`mock/01`](mock/01/README.md)) - 60 Fragen, verteilt auf die Domains.
- **Mock 02** ([`mock/02`](mock/02/README.md)) - ein unabhängiger Satz von 60 Fragen mit derselben Verteilung.

Bearbeiten Sie jede Mock-Prüfung in einer Closed-Book-Sitzung von 90 Minuten: ohne Dokumentation, Suche, Notizen, Tools oder externe Websites. Bei der letzten Überprüfung nannte die LF Multiple Choice FAQ eine Bestehensgrenze von 75 % oder mehr; bestätigen Sie die aktuellen KCSA-Anmeldevoraussetzungen vor der Registrierung bei der Linux Foundation.

## Prüfungsformat und Kursversion

KCSA ist eine Multiple-Choice-Prüfung: 60 Fragen, 90 Minuten, 75 % zum Bestehen, keine hands-on Aufgaben (prüfen Sie die aktuellen Parameter vor der Registrierung bei der Linux Foundation, da sie sich ändern können). Die Kursbeispiele beziehen sich auf Kubernetes `v1.36`. Aktuelle Gewichtungen, Quellen und Änderungen des Curriculums sind in der [Versionsrichtlinie](VERSION_POLICY.md) dokumentiert.

## Weiterführende Lektüre

- [Offizielle Kubernetes-Dokumentation: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- Der CKS-Kurs ist der nächste Schritt für eine Vertiefung in praktisches Hardening und Untersuchungen.
