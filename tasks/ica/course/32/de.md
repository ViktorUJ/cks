[RU version](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md)

# Kapitel 32. Die ICA-Prüfung: Format und Vorbereitung

> **Abschlusskapitel.** Den ganzen Kurs über haben wir Theorie und Praxis auf die
> Zertifizierung **Istio Certified Associate (ICA)** hin vorbereitet. Hier fassen wir
> zusammen, wie die Prüfung aufgebaut ist, wie man sich darauf vorbereitet und wo man
> Probeläufe herbekommt - unsere Mock-Prüfungen.

## 32.1. Was für eine Prüfung das ist

**ICA (Istio Certified Associate)** ist eine Zertifizierung von CNCF und Linux Foundation
(ursprünglich von Tetrate entwickelt), die die Fähigkeit belegt, mit Istio zu arbeiten. Die
Prüfung ist **online, mit Proctoring**, und im Format **hybrid - praktische
(performance-based) Aufgaben plus Multiple-Choice-Fragen**. Im praktischen Teil erhältst du
Zugriff auf einen Cluster und sollst Aufgaben von Hand lösen - Routing konfigurieren, mTLS
aktivieren, eine Policy schreiben, ein Problem finden und beheben; im theoretischen Teil wird
das Verständnis von Prinzipien und Terminologie geprüft. Dauer - **2 Stunden**, die Umgebung
ist auf **Istio v1.26** aktualisiert.

Während der Prüfung ist der Zugriff auf die offizielle Dokumentation erlaubt (istio.io und
ihre Subdomains; in der Regel auch der Istio-Blog und die Kubernetes-Dokumentation - die
aktuelle Liste der erlaubten Ressourcen findest du im Candidate Handbook). Das ist wichtig:
niemand verlangt, alle YAML-Felder auswendig zu kennen, aber man muss das Nötige **schnell**
finden und anwenden.

> Die genauen Details (Dauer, Bestehensgrenze, Anzahl der Aufgaben, Regeln für die
> Wiederholung) ändern sich mit der Zeit und hängen von der Programmversion ab. Gleiche sie
> immer mit der offiziellen Seite ab:
> [Istio Certified Associate (ICA)](https://training.linuxfoundation.org/certification/istio-certified-associate-ica).

## 32.2. Domänen und worauf man den Schwerpunkt legt

Die Prüfung ist nach Domänen mit Gewichten aufgebaut. Aktuelle Aufteilung (nach dem
Programm-Update im August 2025):

| Domäne | Gewicht | Kapitel des Kurses |
|-------|-----|-------------|
| Traffic Management | 35% | 5-12 |
| Securing Workloads | 25% | 9, 13-16 |
| Installation, Upgrade & Configuration | 20% | 2-4, 22 (ambient) |
| Troubleshooting | 20% | 24, 30 |

Was über das neue Programm wichtig zu wissen ist:

- **Eine eigene Domäne „Advanced Scenarios“ gibt es nicht mehr** - ihre Themen wurden
  umverteilt: die Installation von ambient ist zu Installation gewandert, Egress und die
  Anbindung an externe Dienste zu Traffic Management.
- **Installation ist auf 20% gewachsen** und umfasst jetzt explizit die Installation **im
  sidecar- und im ambient-Modus**, die Anpassung und das Upgrade (Canary/in-place).
- **Traffic Management umfasst Egress, Ingress, Resilience** (circuit breaking, failover,
  outlier detection, Timeouts, Retries) **und fault injection**.
- **Securing Workloads** - Autorisierung, Authentifizierung (mTLS, JWT) und **Absicherung des
  Edge-Traffics mit TLS**.
- **Troubleshooting** - Konfiguration, control plane und data plane.

Fazit: **trainiere vor allem das Traffic Management** (Gateway, VirtualService,
DestinationRule, Routing, Resilience, Egress, fault injection) - das ist die größte Domäne
(35%). Danach liegen die Prioritäten fast gleichauf: Sicherheit (25%), Installation/Upgrade
und Troubleshooting (je 20%) - überspringe Installation und Debugging nicht, ihr Gewicht ist
merklich gewachsen.

## 32.3. Praktische Tipps

Erfahrung aus CKA/CKS überträgt sich direkt:

- **Aliase und Autovervollständigung.** Richte `alias k=kubectl` ein, aktiviere die
  completion für `kubectl` und `istioctl` - das spart bei jeder Aufgabe Zeit.
- **Prüfe den Kontext.** Gleiche immer ab, in welchem Cluster und Namespace du arbeitest
  (`kubectl config current-context`), besonders bei vielen Aufgaben.
- **Lies die Aufgabe wörtlich.** Genaue Ressourcennamen, Namespaces, Ports, Versionen - ein
  Fehler im subset-Namen oder selector, und die Regel greift nicht (Kapitel 5).
- **Prüfe das Ergebnis.** Nach der Konfiguration führe `curl` aus einem Pod aus, schau dir
  Codes und Header an - vergewissere dich, dass der Traffic wirklich dorthin geht, wohin er
  soll.
- **`istioctl analyze` ist dein Freund.** Fängt Konfigurationsfehler schnell ab (Kapitel 24).
  Bei einem Problem - `proxy-status` (SYNCED?) und `proxy-config`.
- **Zeitmanagement.** Verbeiße dich nicht in einer Aufgabe. Überspringe eine schwierige,
  komm später zurück - wie bei CKA.
- **Dokumentation griffbereit.** Wisse im Voraus, wo in istio.io die Beispiele für Gateway,
  VirtualService, PeerAuthentication liegen - in der Prüfung kopierst du von dort und passt
  an.

## 32.4. Probeprüfungen (Mock)

Die beste Vorbereitung ist, realistische Prüfungen auf Zeit durchzuspielen. In diesem
Repository gibt es **zwei Mock-Prüfungen**, die das ICA-Format imitieren:

- **Mock 01** - 17 Aufgaben zu grundlegenden Themen: Installation, Gateway/VirtualService,
  AuthorizationPolicy, Steuerung der Injection.
  [tasks/ica/mock/01](../../mock/01/README.MD)
- **Mock 02** - 16 Aufgaben zu fortgeschrittenen Mustern: Canary-Upgrade per Operator,
  Installation über Helm, egress gateway, port-level-Balancing, fault injection,
  namespace-übergreifende Autorisierung.
  [tasks/ica/mock/02](../../mock/02/README.MD)

Eine allgemeine Beschreibung der Umgebung, die Befehle (`check_result`, `time_left`, `hosts`)
und Tipps findest du im Root-README der Infrastruktur:
[tasks/ica/README.MD](../../README.MD).

So nutzt du die Mocks:

1. Arbeite die entsprechenden Kapitel und Labs zum Thema durch.
2. Spiel den Mock **auf Zeit** durch, wie eine echte Prüfung, ohne Hilfestellungen.
3. Prüfe dich über `check_result`, analysiere die Fehler anhand der Lösungen.
4. Wiederhole, bis du sicher im Zeitrahmen bleibst und ein Ergebnis von **70%+** erreichst.

Die Mocks trainieren den **praktischen** Teil der Prüfung. Denk aber daran, dass das Format
hybrid ist: es gibt auch Multiple-Choice-Fragen zum Verständnis von Prinzipien und
Terminologie. Wiederhole daher neben den Mocks die **Theorie** nach Kapiteln (was jede
Ressource tut, wie mTLS, xDS, locality-Balancing funktionieren) - „ich kann es von Hand“ und
„ich verstehe, warum es so ist“ werden beide geprüft.

## 32.5. Wie man sich mit diesem Kurs vorbereitet

Empfohlener Weg:

1. **Teil 1 (Kapitel 1-24)** - Grundlagen und alle Prüfungsdomänen. Festige jedes Kapitel mit
   einem Lab (🧪).
2. **Mocks** (Kapitel 32.4) - spiele sie nach Teil 1 durch, auf Zeit.
3. **Teil 2 (Kapitel 25-31)** - Best Practices für die echte Arbeit. Für die Prüfung selbst
   nicht zwingend, machen aber aus dir einen Ingenieur, der Istio in Produktion versteht und
   nicht nur einen Test besteht.

## 32.6. Zusammenfassung

- ICA ist eine Online-Prüfung mit Proctoring, das Format ist **hybrid**: praktische Aufgaben
  im Cluster plus Multiple-Choice-Fragen; der Zugriff auf die istio.io-Dokumentation ist
  erlaubt, Dauer 2 Stunden, Umgebung v1.26.
- Aktuelle Domänen (ab August 2025): **Traffic Management 35%**, Securing Workloads 25%,
  Installation/Upgrade/Config 20%, Troubleshooting 20%; die Domäne „Advanced Scenarios“ gibt
  es nicht mehr.
- Trainiere vor allem das Traffic Management, überspringe aber Installation und
  Troubleshooting nicht - ihr Gewicht ist auf 20% gewachsen.
- Übertrage die Gewohnheiten aus CKA/CKS: Aliase, Autovervollständigung, Prüfung des
  Kontexts, wörtliches Lesen der Aufgaben, Prüfung des Ergebnisses, Zeitmanagement.
- Spiele **Mock 01 und Mock 02** auf Zeit zur Praxis durch und wiederhole die Theorie nach
  Kapiteln (für den Multiple-Choice-Teil); erreiche stabile 70%+.
- Genaue Logistik und Regeln (Bestehensgrenze, Anzahl der Fragen, erlaubte Ressourcen)
  gleiche auf der offiziellen ICA-Seite ab.

---

Damit endet der Kurs. Du hast den Weg von der Idee eines Service Mesh bis zum
Produktionsbetrieb von Istio zurückgelegt: Traffic Management, Resilience, Sicherheit,
Observability, fortgeschrittene Szenarien, Troubleshooting, echte Migrationen, Härtung - und
die Prüfungsvorbereitung. Kehre nach Bedarf zu den Kapiteln, Labs und Mocks zurück. Viel
Erfolg mit ICA und mit Istio im Ernstfall.

[Inhaltsverzeichnis](../README_DE.md) · [Kapitel 31](../31/de.md)
