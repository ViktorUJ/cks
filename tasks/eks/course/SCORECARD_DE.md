[Русская версия](SCORECARD_RU.md) · [Eng version](SCORECARD.md) · [Versión en español](SCORECARD_ES.md) · [Version française](SCORECARD_FR.md) · [ქართული ვერსია](SCORECARD_GE.md) · [繁體中文版](SCORECARD_TW.md) · [日本語版](SCORECARD_JP.md)

# EKS-Reifegradmatrix: Bereitschaftsfragebogen

[Kursübersicht](README_DE.md) · [Kapitel 48](48/de.md) · [Glossar](GLOSSARY_DE.md)

Dies ist das Arbeitsblatt zu Kapitel 48: dieselben Bereitschaftsdomänen, aber als Fragebogen,
den das Team durchgeht und in eine Liste technischer Schulden überführt. Es enthält kein neues Material.

## So gehen Sie vor

- Gehen Sie die acht Domänen nacheinander durch und überspringen Sie keine: Jede Domäne ist eine eigene
  Achse des Betriebs, und eine Schwäche auf einer Achse wird nicht durch Stärken auf einer anderen ausgeglichen.
- Beantworten Sie jeden Punkt ehrlich mit Ja oder Nein. „Teilweise“, „fast“ und „eingerichtet, aber nicht
  geprüft“ zählen als Nein.
- Füllen Sie den Fragebogen als Team aus, nicht allein: Verantwortliche für Netzwerk, Sicherheit und Kosten
  sehen unterschiedliche Lücken, und „sieht wohl fertig aus“ zeigt sich genau dort, wo Meinungen aufeinandertreffen.
- Es geht nicht um die Punktzahl. Sie dient nur dazu, die Stufe zu erkennen; das Ergebnis des Fragebogens ist eine
  Liste offener Punkte mit Verantwortlichen und Fristen.
- Kennzeichnen Sie jeden offenen Punkt als bekanntes Risiko mit einer Aufgabe, statt ihn still zu übergehen,
  damit das Formular grün aussieht.
- Wiederholen Sie ihn jedes Quartal und nach größeren Änderungen: Versionen altern, Lasten wachsen,
  und das gestrige „erledigt“ ist heute bereits eine Lücke.
- Der Fragebogen gehört neben die IaC ins Repository, damit seine Änderungen im Pull Request sichtbar sind.

## Stufenskala

Der Fragebogen umfasst 51 Punkte. Ein erfüllter Punkt entspricht einem Punkt.

| Stufe | Punkte | Bedeutung | Nächste Schritte |
|---|---|---|---|
| Stufe 1. Instabil und manuell | 0-20 | Der Cluster läuft, solange nichts kaputtgeht: Vieles wurde per Klick eingerichtet, Wiederherstellung und Sicherheitsgrenzen sind nicht geprüft | Blockierende Punkte und die gesamte Spalte „Must have“ vor der Aktivierung von Produktivtraffic schließen |
| Stufe 2. Beherrschbar | 21-33 | Die Grundlage steht: Cluster aus Code, Zugriff und Compute sind bewusst gestaltet, doch Prüfungen und Observability hängen an einzelnen Personen | Sicherheit und Betrieb vervollständigen: Audit, Retention, Alarme, Upgrade-Plan |
| Stufe 3. Wiederholbar und beobachtbar | 34-44 | Praktiken sind verankert und wiederholbar: Upgrade, Backup und Restore wurden durchlaufen, ein Incident wird über das Runbook eingegrenzt | Priorität „Wichtig in den ersten Wochen“ abschließen und Ownership für jede Domäne zuweisen |
| Stufe 4. Autonome Resilienz | 45-51 | Die Bereitschaft verschlechtert sich nicht zwischen Releases: DR wurde in Übungen geprüft, Kosten und Traffic stehen unter Kontrolle, GitOps ist die Quelle der Wahrheit | Niveau halten: vierteljährlicher Fragebogen, Game Day, „Nice to have“ vervollständigen |

Bei einem offenen blockierenden Punkt kann die Stufe unabhängig von der Gesamtpunktzahl nicht über zwei
liegen. Die Regel wird im Abschnitt „Auswertung und Umgang mit dem Ergebnis“ erklärt.

## 1. Cluster und Control Plane

Das Fundament. Wenn die Version nicht mehr unterstützt wird oder die Subnetze nur in einer AZ liegen, ist alles andere unwichtig.

| Erledigt | Punkt | Warum das wichtig ist | Kapitel |
|---|---|---|---|
| [ ] | Kubernetes-Version innerhalb des Standard-Supports | Eine nicht unterstützte Version ist ein Risiko, das sich nicht durch Konfiguration schließen lässt | [38](38/de.md) |
| [ ] | Es gibt einen Versionsupgrade-Plan statt einer Reaktion einen Monat vor Ende des Supports | Ein Upgrade unter Zeitdruck erfolgt ohne Rückfallfenster | [38](38/de.md) |
| [ ] | Endpoint-Zugriff ist durchdacht: public oder private, Source Ranges passend zur Aufgabe | Der Zugriffsmodus auf die API bestimmt die Angriffsfläche des Clusters | [02](02/de.md) |
| [ ] | Cluster-Subnetze liegen in drei AZs, der IP-Plan reicht für das Wachstum der Pods | Eine AZ ist ein Single Point of Failure; fehlende IPs halten die Pod-Planung an | [06](06/de.md) |
| [ ] | Der Cluster wurde aus Code erstellt (Terraform oder eksctl), nicht durch Klicks in der Konsole | Ein manueller Cluster lässt sich bei DR nicht neu erstellen und nicht im Pull Request prüfen | [04](04/de.md) |
| [ ] | Ressourcen sind mit Tags versehen: Team, Umgebung, Cost Allocation | Ohne Tags lassen sich Kosten und Ownership nicht auf Teams verteilen | [43](43/de.md) |

## 2. Compute

Nodes liegen vollständig in der Verantwortung des Engineers: Hier entscheiden sich sowohl Resilienz als auch die Rechnung.

| Erledigt | Punkt | Warum das wichtig ist | Kapitel |
|---|---|---|---|
| [ ] | Die Node-Strategie wurde bewusst gewählt: Auto Mode, Karpenter oder Managed Node Groups | Eine stehen gelassene Standardeinstellung führt zu unklaren Folgen für Preis und Resilienz | [09](09/de.md) |
| [ ] | Ein Spot-Mix wird für unterbrechungstolerante Workloads verwendet | Spot spart dort, wo die Workload eine Unterbrechung verkraftet | [13](13/de.md) |
| [ ] | Instanztypen im Spot-Pool sind diversifiziert | Spot ohne Diversifizierung ist keine Einsparung, sondern das Risiko, Kapazität auf einmal zu verlieren | [13](13/de.md) |
| [ ] | requests sind nach Bedarf gesetzt (Right-Sizing), nicht nach Gefühl | Zu hohe requests bezahlen Luft, zu niedrige bringen die Workload zum Scheitern | [14](14/de.md) |
| [ ] | Karpenter Disruption und Consolidation sind konfiguriert, Drift wird nicht ignoriert | Ohne Consolidation wächst der Node-Park unkontrolliert, Drift häuft Abweichungen vom Code an | [12](12/de.md) |
| [ ] | Pod-Dichte pro Node ist mit ENI- und IP-Limits abgestimmt | Zu hohe Dichte lässt Pods ohne ersichtlichen Grund in `Pending` | [14](14/de.md) |

## 3. Identität und Sicherheit

Die breiteste Domäne und die häufigste Quelle stiller Lücken. Punkt für Punkt prüfen.

| Erledigt | Punkt | Warum das wichtig ist | Kapitel |
|---|---|---|---|
| [ ] | Pods greifen über IRSA oder Pod Identity auf AWS zu, ohne statische Schlüssel | Ein langlebiger Schlüssel im Pod gelangt zusammen mit Image oder Log nach außen | [16](16/de.md) |
| [ ] | **Blockierend.** Nicht nur der Cluster Creator hat Zugriff auf den Cluster, Access Entries sind eingerichtet | Ein Cluster, auf den nur eine Person zugreifen kann, geht mit dieser Person verloren | [05](05/de.md) |
| [ ] | Secrets stammen aus Secrets Manager oder SSM (External Secrets, CSI), nicht aus Manifesten | Ein Secret im Manifest gelangt in Git und in jede Kopie des Repositorys | [18](18/de.md) |
| [ ] | Nodes und Pods sind gehärtet: IMDSv2, Hop Limit, Pod Security Admission | Zugriff auf Node-Metadaten aus einem Pod macht aus dem Pod die Rechte der Node | [19](19/de.md) |
| [ ] | Images werden in ECR gescannt, die Basis stammt aus vertrauenswürdigen Quellen | Eine verwundbare Basis gelangt sofort in alle Services | [20](20/de.md) |
| [ ] | Das Audit der Control Plane ist aktiviert: api, audit, authenticator in den Logs | Audit muss vor dem Incident aktiviert werden, nachträglich gibt es keine Logs | [21](21/de.md) |
| [ ] | Kyverno- oder Gatekeeper-Richtlinien schließen gefährliche Muster in Manifesten aus | Eine menschliche Prüfung übersieht, was eine Richtlinie immer findet | [22](22/de.md) |

## 4. Speicher

Eine kleine, aber tückische Domäne: EBS-Standardeinstellungen und ungeprüfte Volume-Backups treffen unerwartet.

| Erledigt | Punkt | Warum das wichtig ist | Kapitel |
|---|---|---|---|
| [ ] | Die Standard-StorageClass verwendet gp3 statt des veralteten gp2 | gp2 bleibt aus Gewohnheit Standard und unterliegt bei Eigenschaften und Preis | [23](23/de.md) |
| [ ] | `volumeBindingMode: WaitForFirstConsumer` ist gesetzt | Andernfalls entsteht das Volume in der falschen AZ und der Pod bleibt dauerhaft `Pending` | [23](23/de.md) |
| [ ] | Persistente Volumes werden gesichert | Ein Volume ohne Backup enthält Daten, die nur in einer Kopie existieren | [41](41/de.md) |
| [ ] | Volume-Snapshots wurden durch Wiederherstellung geprüft, nicht nur erstellt | Ein ungeprüfter Snapshot ist gleichbedeutend mit keinem Snapshot | [41](41/de.md) |
| [ ] | Die Bindung von EBS an eine AZ wird bei Migration und Workload-Planung berücksichtigt | Das Übertragen von Manifesten „wie sie sind“ scheitert gerade an Volumes | [23](23/de.md) |
| [ ] | Shared Storage wurde bewusst gewählt: EFS oder FSx dort, wo ReadWriteMany erforderlich ist | EBS bietet kein ReadWriteMany, deshalb wird der Umgang damit in der Designphase entschieden | [24](24/de.md) |

## 5. Netzwerk und Traffic

Fehler in dieser Domäne sind von außen sichtbar: ein nicht erreichbarer Service, offener Egress, Traffic durch alle AZs.

| Erledigt | Punkt | Warum das wichtig ist | Kapitel |
|---|---|---|---|
| [ ] | Load Balancer werden über AWS Load Balancer Controller erstellt: NLB | Manuelle Load Balancer weichen vom Cluster-Zustand ab | [26](26/de.md) |
| [ ] | Ingress läuft über ALB mit bewusst gewähltem target-type | Der Target-Typ bestimmt Traffic-Pfad und Verhalten beim Drain | [27](27/de.md) |
| [ ] | TLS-Zertifikate kommen über ACM, HTTPS wird am Load Balancer terminiert | Manuelle Zertifikate laufen im ungünstigsten Moment ab | [27](27/de.md) |
| [ ] | **Blockierend.** NetworkPolicy mit Default Deny, Traffic zwischen Pods ist explizit erlaubt | Ohne Default Deny sieht ein kompromittierter Pod alle Nachbarn | [30](30/de.md) |
| [ ] | DNS-Einträge werden über external-dns verwaltet, nicht manuell in Route 53 | Ein manueller Eintrag überlebt das Löschen des Service und zeigt ins Leere | [29](29/de.md) |
| [ ] | VPC Endpoints für AWS-Services, NAT pro AZ, Egress-Traffic unter Kontrolle | Egress über ein einziges NAT ist sowohl Single Point of Failure als auch Kostenfaktor | [31](31/de.md) |

## 6. Observability

Ohne diese Domäne wird ein Incident blind debuggt. Daten müssen nicht nur fließen, sondern auch die
benötigte Zeit gespeichert werden und Alarme auslösen.

| Erledigt | Punkt | Warum das wichtig ist | Kapitel |
|---|---|---|---|
| [ ] | metrics-server läuft | Ohne ihn reagieren weder `kubectl top` noch HPA | [33](33/de.md) |
| [ ] | Es gibt ein Metrik-Backend: Prometheus oder Container Insights | Metriken werden mit Historie benötigt, nicht nur „genau jetzt“ | [33](33/de.md) |
| [ ] | Logs werden von Nodes und Pods exportiert | Logs, die auf der Node bleiben, verschwinden mit der Node | [34](34/de.md) |
| [ ] | Die Log-Retention ist bewusst festgelegt | Retention ohne Plan bedeutet beim Incident verlorene Logs oder unnötigen Speicher | [34](34/de.md) |
| [ ] | Alarme für zentrale Symptome sind eingerichtet, nicht nur Dashboards | Ein Dashboard, das niemand betrachtet, ersetzt keinen Alarm | [33](33/de.md) |
| [ ] | Tracing (ADOT oder X-Ray) wird dort eingesetzt, wo die Aufrufkette wichtig ist | In Microservices liegt die Ursache eines Ausfalls nicht in dem Service, in dem das Symptom sichtbar wird | [36](36/de.md) |

## 7. Betrieb

Die Domäne, die „der Cluster läuft heute“ von „der Cluster übersteht Upgrade und Ausfall“ trennt.

| Erledigt | Punkt | Warum das wichtig ist | Kapitel |
|---|---|---|---|
| [ ] | Es gibt einen Upgrade-Plan für Cluster und Add-ons, veraltete APIs sind bereinigt | Eine veraltete API stoppt das Upgrade im ungünstigsten Moment | [37](37/de.md) |
| [ ] | Die Rollback-Bereitschaft ist klar: Rückfallfenster und Reihenfolge sind bekannt | Ein Rollback wird im Voraus geplant, nicht während eines fehlgeschlagenen Upgrades | [39](39/de.md) |
| [ ] | PDB und Topology Spread schützen die Verfügbarkeit bei Drain und Upgrade | Ohne sie entfernt ein Node-Upgrade alle Replikate eines Service auf einmal | [40](40/de.md) |
| [ ] | PDBs blockieren den Drain nicht dauerhaft (`maxUnavailable: 0` ist ein Warnsignal) | Ein solcher PDB stoppt das Upgrade und sieht wie ein hängender Drain aus | [40](40/de.md) |
| [ ] | AWS Backup ist für Cluster-Zustand und persistente Volumes eingerichtet | Ein Backup nur der Volumes stellt nicht den Cluster selbst wieder her | [41](41/de.md) |
| [ ] | **Blockierend.** DR-Restore wurde an einem Game Day tatsächlich getestet | Ein eingerichteter, aber nie geprüfter Restore ist Hoffnung, kein Backup | [42](42/de.md) |
| [ ] | Kosten sind nach Teams und Namespace sichtbar (OpenCost oder Kubecost) | Unsichtbare Kosten werden nicht optimiert und haben keinen Owner | [43](43/de.md) |
| [ ] | GitOps ist die Quelle der Wahrheit für Manifeste (Argo CD oder Flux) | Weicht der Cluster von Git ab, kennt niemand seinen Zustand | [44](44/de.md) |

## 8. Bereitschaft für Incidents

Die letzte Domäne: Wenn alles kaputtgeht, ist nicht die Architektur wichtig, sondern die Geschwindigkeit der Eingrenzung.

| Erledigt | Punkt | Warum das wichtig ist | Kapitel |
|---|---|---|---|
| [ ] | Es gibt ein Runbook für eine Node, die dem Cluster nicht beigetreten ist | Ursachen unterscheiden sich (IAM, SG, User Data, kubelet), die Prüfreihenfolge spart Stunden | [45](45/de.md) |
| [ ] | Es gibt ein Runbook für Netzwerkstörungen: ENI, SG und NACL, DNS, unhealthy targets | Eine Netzwerkstörung sieht bei unterschiedlichen Ursachen gleich aus | [46](46/de.md) |
| [ ] | Es gibt ein Runbook für Zugriff: 401 gegenüber 403, IRSA und Pod Identity, kubeconfig | Ein Zugriffsfehler blockiert sowohl die Arbeit als auch die Incident-Analyse | [47](47/de.md) |
| [ ] | SSM-Zugriff auf Nodes funktioniert ohne blankes SSH, ein Zugriff auf die Node ist möglich | Zugriff auf eine Node einzurichten, wenn sie bereits defekt ist, ist zu spät | [45](45/de.md) |
| [ ] | Control-Plane-Logging ist aktiviert, authenticator- und API-Logs werden geschrieben | Ohne diese Logs lässt sich die Ursache eines Zugriffsfehlers nicht rekonstruieren | [21](21/de.md) |
| [ ] | Control-Plane-Logs sind zur Analyse verfügbar und werden nicht vorzeitig gelöscht | Logs werden bei der Analyse benötigt, nicht bei der Einrichtung | [34](34/de.md) |

## Auswertung und Umgang mit dem Ergebnis

Zählen Sie wie folgt:

- Ein erfüllter Punkt entspricht einem Punkt, maximal 51. Die Domänen sind gleichwertig: Netzwerk ist nicht wichtiger
  als Speicher, und eine hohe Punktzahl in einer Domäne schließt keine Lücke in einer anderen.
- Drei Punkte sind als **blockierend** gekennzeichnet: DR-Restore ist nicht getestet, nur eine Person hat Zugriff
  auf den Cluster, und im Netzwerk gibt es keine Default-Deny-NetworkPolicy.
- Wenn mindestens ein blockierender Punkt offen ist, kann die Stufe bei jeder Punktzahl nicht über zwei liegen.
  Ein blockierender Punkt ist nicht „minus ein Punkt“, sondern ein Stopp für Produktivtraffic.

Überführen Sie die offenen Punkte anschließend in eine Liste technischer Schulden mit Priorität:

| Priorität | Was dazugehört | Umgang damit |
|---|---|---|
| Must have vor Produktion | unterstützte Version, Zugriff nicht nur für eine Person, Audit und Control-Plane-Logs, Default-Deny-NetworkPolicy, Secrets nicht in Manifesten, getesteter Restore, PDBs blockieren kein Upgrade | Vor der Aktivierung von Produktivtraffic schließen: Der erste Incident oder Einbruch ist teurer als eine verzögerte Einführung |
| Wichtig in den ersten Wochen | Right-Sizing von requests, Spot-Mix, Log-Retention, Alarme, Upgrade-Plan, VPC Endpoints | Direkt nach dem Start als Aufgaben mit Verantwortlichen und Fristen anlegen |
| Nice to have | Tracing von Microservices, detaillierte Kostenallokation, ausgereiftes GitOps für einen Cluster-Park | Iterativ bereits in Produktion umsetzen, ohne den Start zu blockieren |

Die Liste technischer Schulden wird als explizite Aufgaben mit Owner und Frist geführt. Die Formulierung „irgendwann
später“ bedeutet, dass der Punkt offen ist und beim nächsten Durchgang wieder dort stehen wird.

Was danach mit dem Ergebnis zu tun ist:

- Weisen Sie den Domänen Ownership zu: Netzwerk, Sicherheit und Kosten haben je eine verantwortliche Person, die
  sicherstellt, dass ihre Punkte erfüllt bleiben und nicht degradieren.
- Gehen Sie den Fragebogen vor jedem Produktionsgang durch: Ein neuer Cluster oder großer neuer Service geht nicht
  live, bevor die Priorität „Must have“ vollständig und explizit erfüllt ist.
- Verknüpfen Sie das Ergebnis mit Game Days und Upgrades: Die Prüfung des DR-Restore und des Upgrade-Plans kehrt als
  bestätigter oder fehlgeschlagener Punkt in den Fragebogen zurück, nicht als Versprechen.
- Vergleichen Sie mit dem vorherigen Durchgang: Interessant ist nicht die Summe der Punkte, sondern welche Punkte
  erfüllt wurden, welche wieder offen sind und warum.

## Grenzen dieses Fragebogens

- Er ersetzt keine Architekturprüfung: Die Bereitschaftsachsen sind sichtbar, Designentscheidungen jedoch nicht.
- Er bewertet das Vorhandensein einer Praxis, nicht ihre Qualität: Aktiviertes Audit und nützliches Audit ergeben
  dieselbe Punktzahl, der Unterschied zeigt sich erst bei der Incident-Analyse.
- Er deckt nicht den Anwendungsteil ab: Service-Code und Datenschemata bleiben außerhalb des Fragebogens.
- Die Punktzahl ist zwischen Clustern mit unterschiedlichen Zwecken nicht vergleichbar: Einem Nicht-Produktiv-Cluster
  fehlen einige erforderliche Punkte, und eine niedrige Punktzahl bedeutet dort nichts Schlechtes.
