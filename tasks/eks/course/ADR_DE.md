[Русская версия](ADR_RU.md) · [Eng version](ADR.md) · [Versión en español](ADR_ES.md) · [Version française](ADR_FR.md) · [ქართული ვერსია](ADR_GE.md) · [繁體中文版](ADR_TW.md) · [日本語版](ADR_JP.md)

# Architekturentscheidungen des EKS-Kurses (ADR)

[Kursübersicht](README_DE.md) · [Glossar](GLOSSARY_DE.md)

## Verwendung

Ein ADR (Architecture Decision Record) ist eine kurze Aufzeichnung einer Entscheidung: warum
sie so getroffen wurde, welche Optionen es gab und welchen Preis die Wahl hat. Es geht nicht
um Dokumentation um der Dokumentation willen, sondern darum, in einem Jahr nicht erneut zu
streiten und neuen Teammitgliedern die Begründung statt nur das Ergebnis verständlich zu machen.

Die Vorlagen unten sind bereits mit dem Kursmaterial ausgefüllt: Optionen, ihre Vorteile und
Kosten stammen aus den Kapiteln und wurden nicht hier erfunden. Aber **Kontext, Status, Datum
und die Entscheidung selbst werden von den Engineers** für das jeweilige Projekt eingetragen:
Der Kurs kennt weder Ihren Clusterbestand noch Compliance-Anforderungen oder das Vorhandensein
eines Plattformteams.

Eine „verworfene Option“ bedeutet nicht „schlecht“. Bei fast allen Verzweigungen des Kurses
sind beide Optionen valide; die verworfene wird mit anderen Eingabedaten richtig. Dafür gibt es
das Feld „Bedingungen für eine Neubewertung“.

## Leere Vorlage

```markdown
## ADR-NN. Kurzer Titel der Entscheidung

Status: vorgeschlagen / angenommen / verworfen / ersetzt ADR-NN
Datum: YYYY-MM-DD

**Kontext.** Welche Aufgabe, welche Einschränkungen und welche Fragen müssen geklärt werden.

**Geprüfte Optionen.**

| Option | Was sie bietet | Welchen Preis sie hat | Wann sie geeignet ist |
|---|---|---|---|
|  |  |  |  |

**Folgen der angenommenen Entscheidung.**

- Was wir erhalten:
- Welchen Preis wir zahlen:

**Entscheidung.** Was ausgewählt wurde und in welchem Umfang (gesamter Bestand, ein Cluster, Pilotprojekt).

**Bedingungen für eine Neubewertung.** Konkrete Auslöser, bei denen der Eintrag erneut geöffnet wird.

**Links.** Kurskapitel und interne Projektdokumente.
```

## ADR-01. Compute: EKS Auto Mode gegenüber eigenem Karpenter-Stack

Status: _wird von den Engineers ausgefüllt_
Datum: _wird von den Engineers ausgefüllt_

**Kontext.** Vor der Auswahl beantworten:

- Gibt es von der Sicherheit eine Anforderung an das Node-Image (attestiertes AMI, eigener Bootstrap)?
- Ist Zugriff auf die Node für Debugging oder für Node-Agenten als DaemonSet erforderlich?
- Wird ein anderes CNI als VPC CNI und Kontrolle über den Karpenter-Controller selbst benötigt,
  nicht nur über NodePool?
- Wie kritisch sind die Kosten: Ist der Verwaltungsaufschlag zusätzlich zu EC2 tragbar?
- Gibt es ein Team, das bereit ist, Nodes zu betreiben, oder ist das Ziel ausdrücklich ein Minimum
  an Betriebsaufwand?

**Geprüfte Optionen.**

| Option | Was sie bietet | Welchen Preis sie hat | Wann sie geeignet ist |
|---|---|---|---|
| EKS Auto Mode | Nodes als Appliance: Bottlerocket, SELinux enforcing, schreibgeschütztes Root-Dateisystem, Rotation spätestens nach 21 Tagen, integrierte Komponenten Karpenter, IPAM, Network Policy, EBS CSI, ELB und Pod Identity | Verwaltungsaufschlag zusätzlich zu EC2 (nicht für Reserved- und Savings-Plans-Rabatte berechtigt), kein SSH oder SSM, Standard-NodePool und -NodeClass können nicht geändert werden, fremdes CNI nicht möglich | Ziel ist minimaler Betriebsaufwand für Nodes, keine Anforderungen an Image oder Zugriff auf die Node |
| Eigener Stack: Managed Node Groups oder Self-Managed plus eigener Karpenter | eigenes Launch Template und AMI, Zugriff auf die Node, beliebiges CNI, vollständige Kontrolle über Version und Konfiguration von Karpenter | Nodes, Add-ons, Upgrades und Unterbrechungsbehandlung liegen bei Ihnen, Kosten nur für EC2 | Es gibt eine Anforderung, die Auto Mode nicht erfüllt, oder die Wirtschaftlichkeit lässt den Aufschlag nicht zu |

**Folgen der angenommenen Entscheidung.**

- Was wir erhalten: ein einheitliches Betriebsmodell für Nodes je Cluster und eine vorhersehbare
  Verantwortungsgrenze zwischen AWS und dem Team.
- Welchen Preis wir zahlen: In Auto Mode bleiben Container, Cluster- und VPC-Konfiguration,
  Volumes aus PVCs und Load Balancer bei Ihnen; eigene NodePool übernehmen die Einschränkungen
  der Standard-Pools nicht, daher müssen Limits und Instanztypen manuell festgelegt werden,
  sonst wächst der Pool ohne Obergrenze.

**Entscheidung.** _für das eigene Projekt ausfüllen_

**Bedingungen für eine Neubewertung.** Es entstand eine Anforderung an ein attestiertes
Node-Image; ein Node-Agent wird benötigt, der nicht als Sidecar funktioniert; Cilium als
primäres CNI wird benötigt; Disruption Budgets blockieren Updates länger als die Lebensdauer
einer Node; der Bestand ist auf ein Volumen angewachsen, bei dem Peaks durch Node-Ersatz und
der Verwaltungsaufschlag in der Rechnung sichtbar werden.

**Links.** [Kapitel 9](09/de.md) - Compute-Typen, Abschnitte 9.6-9.8;
[Kapitel 10](10/de.md) - Launch Template und eigene AMIs; [Kapitel 12](12/de.md) - NodePool und
Disruption; [Kapitel 43](43/de.md) - Kostenanalyse.

## ADR-02. Pod-Identität: IRSA gegenüber EKS Pod Identity

Status: _wird von den Engineers ausgefüllt_
Datum: _wird von den Engineers ausgefüllt_

**Kontext.** Vor der Auswahl beantworten:

- Wie viele Cluster gibt es, und werden Rollen zwischen ihnen übertragen?
- Gibt es Workloads auf Fargate oder auf Windows-Nodes?
- Wird die Identität außerhalb von EKS (EC2, ECS, Lambda) mit denselben Rollen benötigt?
- Wird Cross-Account benötigt, und in welcher Form?
- Welche Platform Version haben bestehende Cluster?

**Geprüfte Optionen.**

| Option | Was sie bietet | Welchen Preis sie hat | Wann sie geeignet ist |
|---|---|---|---|
| IRSA | OIDC-Föderation über STS, funktioniert außerhalb von EKS, Cross-Account direkt, unterstützt Fargate und Windows-Nodes | IAM-OIDC-Provider für jeden Cluster, Trust Policy muss für jeden Cluster neu geschrieben werden, Session Tags manuell | Fargate, Windows, Identität außerhalb von EKS, Cross-Account über Föderation |
| EKS Pod Identity | eine Trust Policy für `pods.eks.amazonaws.com` für alle Cluster, Bindung durch eine Assoziation in der EKS-API ohne Annotationen, Session Tags und ABAC sofort verfügbar | nur Linux-Nodes auf Amazon EC2, kein Fargate, Windows, Outposts oder EKS Anywhere, Add-on-Agent und minimale Platform Version erforderlich | neue Cluster auf EC2-Nodes, Clusterbestand mit wiederverwendbaren Rollen |

**Folgen der angenommenen Entscheidung.**

- Was wir erhalten: einen einheitlichen Weg zur Rechtevergabe an Pods und eine eindeutige Quelle
  der Wahrheit darüber, wo eine Rolle an ein ServiceAccount gebunden ist.
- Welchen Preis wir zahlen: Ein gemischter Bestand erfordert beide Modelle; bei gleichzeitiger
  Konfiguration auf einem ServiceAccount gewinnt IRSA, weil Web Identity in der SDK-Kette vor
  dem Container-Provider steht und die Pod-Identity-Assoziation stillschweigend ignoriert wird.

**Entscheidung.** _für das eigene Projekt ausfüllen_

**Bedingungen für eine Neubewertung.** Fargate-Profile oder Windows-Nodes wurden zum Bestand
hinzugefügt; eine Anforderung an ABAC nach Session Tags entstand; Einschränkungen von Pod
Identity wurden in der Dokumentation reduziert; dieselbe Rolle wird für Workloads innerhalb
und außerhalb von EKS benötigt.

**Links.** [Kapitel 16](16/de.md) - IRSA und OIDC-Provider; [Kapitel 17](17/de.md) - Pod
Identity, Vergleich und Migrationsreihenfolge.

## ADR-03. Netzwerk: VPC CNI gegenüber Cilium (Chaining oder vollständiger Ersatz)

Status: _wird von den Engineers ausgefüllt_
Datum: _wird von den Engineers ausgefüllt_

**Kontext.** Vor der Auswahl beantworten:

- Werden Richtlinien auf L7 (HTTP, gRPC, Kafka) oder nach DNS-Namen benötigt, und wer wird sie schreiben?
- Wird Observability für Pod-zu-Pod-Flows auf Hubble-Ebene benötigt?
- Sind echte Pod-Adressen in der VPC, Security Groups for Pods und Flow Logs nach Pods wichtig?
- Ist IPv4-Knappheit nicht auf andere Weise zu beheben?
- Ist das Team bereit, CNI-Upgrades und seine Kompatibilität mit der Cluster-Version zu verantworten?

**Geprüfte Optionen.**

| Option | Was sie bietet | Welchen Preis sie hat | Wann sie geeignet ist |
|---|---|---|---|
| VPC CNI mit integriertem NetworkPolicy | Managed Add-on, AWS-Support, reguläre Upgrades, Standard-`NetworkPolicy` auf L3/L4 und administrative `ClusterNetworkPolicy`, echte VPC-Adressen | keine L7-Regeln, keine Richtlinien nach FQDN, keine Cilium-CRDs und kein Hubble | L3/L4-Isolation ist erforderlich, das VPC-Adressmodell ist geeignet |
| Cilium im CNI-Chaining-Modus | `CiliumNetworkPolicy`, L7- und DNS-Richtlinien, Hubble, während IPAM und VPC-Integrationen bei VPC CNI bleiben | eigene Cilium-Installation und deren Wartung, zweites CRD-Modell, Schulung des Teams | L7- oder DNS-Richtlinien oder Hubble werden benötigt, und das Adressmodell ist geeignet |
| Cilium als vollständiger Ersatz (ENI IPAM oder Cluster-Pool) | eigenes IPAM, optionales Overlay und Abhilfe für IPv4-Knappheit, ClusterMesh, Ersatz von kube-proxy durch eBPF | Upgrades und Kompatibilität liegen bei Ihnen, AWS-Support wird eingeschränkt, bei Overlay gehen echte Pod-Adressen, SG for Pods und Pod-Adressen in Flow Logs verloren | Overlay oder ein Multi-Cluster-Netzwerk wird benötigt, oder Anforderungen, die das ENI-Modell nicht erfüllt |

**Folgen der angenommenen Entscheidung.**

- Was wir erhalten: eine explizite Grenze zwischen dem durch AWS-Support abgedeckten Bereich
  und dem Bereich, den das Plattformteam verantwortet.
- Welchen Preis wir zahlen: Das CNI lässt sich nicht durch Umschalten eines Flags wechseln; das
  CNI wird einem Pod beim Erstellen zugewiesen. Der Übergang erfolgt daher als Blue/Green über
  einen neuen Node-Pool oder einen neuen Cluster; die Fehlerdiagnose verlagert sich in die
  CNI-Werkzeuge; außerdem wird ein Zeitfenster ohne Richtlinien beim Pod-Start eingeplant
  (`NETWORK_POLICY_ENFORCING_MODE` liefert im Modus `standard` Default Allow).

**Entscheidung.** _für das eigene Projekt ausfüllen_

**Bedingungen für eine Neubewertung.** Eine Anforderung an L7- oder DNS-Namen-Richtlinien
entstand; eine Karte der Pod-zu-Pod-Flows wird benötigt; IPv4-Knappheit lässt sich nicht mehr
mit den Mitteln aus Kapitel 7 beheben; ein gemeinsames Pod Network für mehrere Cluster wird
benötigt; iptables kube-proxy wurde zum Engpass.

**Links.** [Kapitel 8](08/de.md) - alternative CNIs, Kosten des Übergangs, Migration;
[Kapitel 6](06/de.md) - Pod-Adressierung über ENI; [Kapitel 7](07/de.md) - Adressknappheit;
[Kapitel 30](30/de.md) - Netzwerk-Richtlinien in Produktion.

## ADR-04. Automatische Node-Skalierung: Cluster Autoscaler gegenüber Karpenter

Status: _wird von den Engineers ausgefüllt_
Datum: _wird von den Engineers ausgefüllt_

**Kontext.** Vor der Auswahl beantworten:

- Läuft der Cluster auf Auto Mode oder auf einem eigenen Stack (in Auto Mode ist die Frage
  beantwortet, Karpenter ist bereits integriert)?
- Wie heterogen sind die Workloads, und wie viele Node Groups müssen vorgehalten werden?
- Gibt es eine Anforderung an schnelle Reaktion auf Traffic-Spitzen?
- Wird eine Vereinheitlichung mit Clustern in anderen Clouds durch ein Werkzeug benötigt?
- Ist CA bereits vorhanden, gut abgestimmt und tatsächlich ein Hindernis?

**Geprüfte Optionen.**

| Option | Was sie bietet | Welchen Preis sie hat | Wann sie geeignet ist |
|---|---|---|---|
| Cluster Autoscaler | arbeitet auf einer Auto Scaling Group, ein einheitlicher Weg bei vielen Providern, vertrauter Betrieb ohne neue CRDs | Reaktion auf Gruppen- statt Pod-Ebene; Instanztypen sind im Launch Template festgelegt; langsamer durch die ASG-Schicht; entfernt leere Nodes, konsolidiert aber nicht | einfache, vorhersehbare Cluster, Multi-Cloud-Vereinheitlichung, funktionierende Installation |
| Karpenter | ruft EC2 direkt auf, wählt den Instanztyp für konkrete Pods aus, aktive Konsolidierung, Diversifizierung der Typen für Spot | eigene CRDs `NodePool` und `EC2NodeClass`, Verantwortung für Version und Konfiguration des Controllers, AWS-first | neue EKS-Cluster, heterogene Workloads, Anforderung an Geschwindigkeit und dichte Packung |

**Folgen der angenommenen Entscheidung.**

- Was wir erhalten: einen Mechanismus, der für das Hinzufügen und Entfernen von Nodes zuständig
  ist, sowie eine Stelle, an der die Bestandslimits festgelegt werden.
- Welchen Preis wir zahlen: Beide gleichzeitig zu betreiben ist nur auf unterschiedlichen
  Node-Mengen und nur als zeitweilige Migration zulässig, sonst konkurrieren sie bei
  Scale-Down-Entscheidungen; die Migration erfolgt über neue Nodes, nicht durch das Verschieben
  von Pods auf einer laufenden Node.

**Entscheidung.** _für das eigene Projekt ausfüllen_

**Bedingungen für eine Neubewertung.** Der Zoo der Node Groups ist gewachsen und unbeherrschbar
geworden; Leerlauf durch schwache Packung wird auf der Rechnung sichtbar; die Reaktion auf
Traffic-Spitzen erfüllt das SLO nicht mehr; der Cluster wurde auf Auto Mode umgestellt; Cluster
in anderen Clouds mit der Anforderung an ein einheitliches Werkzeug kamen hinzu.

**Links.** [Kapitel 11](11/de.md) - Vergleich der Ansätze und Auswahl-Checkliste;
[Kapitel 12](12/de.md) - NodePool, Consolidation, Disruption Budgets;
[Kapitel 13](13/de.md) - Spot; [Kapitel 9](09/de.md) - Verbindung mit Auto Mode.

## ADR-05. GitOps für einen Clusterbestand: Hub-and-Spoke gegenüber Dezentralisierung

Status: _wird von den Engineers ausgefüllt_
Datum: _wird von den Engineers ausgefüllt_

**Kontext.** Vor der Auswahl beantworten:

- Wie viele Cluster gibt es derzeit im Bestand, und wie viele werden erwartet?
- Wird Clusterautonomie bei Verlust des Hubs oder der Verbindung zu ihm benötigt?
- Wird ein einheitliches Übersichts-Dashboard für den gesamten Bestand benötigt?
- Wer aktualisiert die Agenten, und ist das Team auf unterschiedliche Versionen vorbereitet?
- Wie hoch sind die Kosten für Reconciliation-Traffic über Clustergrenzen hinweg?

**Geprüfte Optionen.**

| Option | Was sie bietet | Welchen Preis sie hat | Wann sie geeignet ist |
|---|---|---|---|
| Hub-and-Spoke | eine Instanz von Argo CD oder Flux auf dem Hub, kein Agent in jedem Cluster nötig, ApplicationSet mit Cluster- und Git-Generator über Matrix rollt das Add-on-Set im gesamten Bestand aus, einheitliche Übersicht | Hub als Fehlerdomäne: Workloads auf Spokes laufen weiter, aber Anwenden von Commits, Self-Heal und Rollbacks stehen im gesamten Bestand still; Reconciliation über das Netzwerk verursacht Latenz, Kosten für ausgehenden Traffic und Abhängigkeit von der Verbindung | kleiner und mittlerer Bestand, bei dem einfacher Betrieb und einheitliche Übersicht zählen |
| Hub-Sharding | Cluster werden auf Replikate von application-controller verteilt, die Anzahl der Replikate wird in `ARGOCD_CONTROLLER_REPLICAS` dupliziert | eine Fehlerdomäne bleibt bestehen; hash-basierte Verteilung ist ungleichmäßig, Round-Robin ist gleichmäßiger | der Bestand ist einem Controller entwachsen, aber Clusterautonomie wird nicht benötigt |
| Dezentralisierung | der Hub rollt nur die Basis und einen lokalen Agenten aus, danach zieht der Cluster selbst aus Git und bleibt bei Verlust des Hubs autonom | so viele Agenten wie Cluster, sie müssen aktualisiert und konfiguriert werden, keine einheitliche Übersicht, Agent-Versionen driften auseinander | großer Bestand oder harte Anforderung an Autonomie |
| argocd-agent | eine zentrale Argo-CD-Instanz sieht die `Application` aller Cluster, aber die Synchronisierung zieht ein Agent auf der Spoke-Seite | Projekt `argoproj-labs`, inkubierend und nicht Kern von Argo CD; die Topologie bleibt Hub-and-Spoke | ein inkubierendes Projekt für rückwärts gerichteten Datenfluss ist akzeptabel |

**Folgen der angenommenen Entscheidung.**

- Was wir erhalten: eine klare Antwort auf die Frage „Was geschieht mit der Auslieferung, wenn
  der Hub nicht verfügbar ist?“
- Welchen Preis wir zahlen: Die Grenze zwischen IaC und GitOps ist in jeder Topologie zwingend:
  Infrastruktur (VPC, Cluster, Node Groups, IAM) läuft über Terraform, Add-ons und Workloads
  über GitOps; eine Vermischung führt entweder zur Neuerstellung des Clusters für eine Änderung
  am Deployment oder zum Henne-Ei-Problem mit einem Agenten, der im selben Cluster lebt.

**Entscheidung.** _für das eigene Projekt ausfüllen_

**Bedingungen für eine Neubewertung.** Der Bestand ist so gewachsen, dass ein Controller nicht
mehr ausreicht; die Anforderung, die Reconciliation bei Verlust des Hubs fortzusetzen, entstand;
die Kosten für ausgehenden Reconciliation-Traffic wurden sichtbar; argocd-agent hat die
Inkubation verlassen.

**Links.** [Kapitel 44](44/de.md) - Bestandstopologien, Abschnitt 44.6;
[Kapitel 32](32/de.md) - Clusterbestand; [Kapitel 4](04/de.md) - IaC und Terraform;
[Kapitel 31](31/de.md) - Traffic-Kosten; [Kapitel 38](38/de.md) - Blue/Green-Migration.

## Was hier bewusst nicht entschieden wird

Einige Verzweigungen betrachtet der Kurs nicht als architektonisch: Die Technik ist darin
annähernd gleichwertig, und der Kontext des Unternehmens entscheidet. Die Wahl zwischen Argo
CD und Flux ist eine Frage, welche Werkzeuge das Team bereits bedienen kann und welche
Schnittstelle es braucht, nicht der Eigenschaften der Werkzeuge. Die Wahl zwischen eigenem
Prometheus und einem Managed Service betrifft die Frage, wer Rufbereitschaft übernimmt und was
Speicherung kostet, nicht die Architektur der Metriksammlung. Gleiches gilt für die Wahl einer
Image Registry, eines Secrets-Werkzeugs und die Kontenstruktur: Das sind organisatorische
Grenzen. Die zusammenfassende Liste der vor dem Produktivgang zu prüfenden Punkte steht in
[Kapitel 48](48/de.md).
