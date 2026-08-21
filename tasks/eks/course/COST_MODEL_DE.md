[Русская версия](COST_MODEL_RU.md) · [Eng version](COST_MODEL.md) · [Versión en español](COST_MODEL_ES.md) · [Version française](COST_MODEL_FR.md) · [ქართული ვერსია](COST_MODEL_GE.md) · [繁體中文版](COST_MODEL_TW.md) · [日本語版](COST_MODEL_JP.md)

# Kostenmodell eines EKS-Clusters: Vorlage für die Bewertung

[Kursübersicht](README_DE.md) · [Kapitel 43](43/de.md) · [Glossar](GLOSSARY_DE.md)

Dies ist ein Arbeitsblatt zu Kapitel 43: dieselbe Kostenstruktur, jedoch als Tabelle und
Formeln, anhand derer ein Engineer die Schätzung für den eigenen Cluster erstellt. Es enthält
kein neues Material.

## Verwendung

- Das Formular enthält **keine** Preise. Die Tarife sind regionsabhängig, ändern sich und
  veralten schneller als der Kurs; deshalb bleibt die Spalte „Tarif (ausfüllen)“ absichtlich leer.
- Tarife werden für die jeweilige Region dem AWS Pricing Calculator entnommen und in die leere
  Spalte eingetragen; für Ist-Werte eines bereits laufenden Clusters dem Cost and Usage Report
  (Kapitel 43).
- Der Wert der Vorlage liegt nicht in der Genauigkeit einer Zahl, sondern in der Vollständigkeit
  der Liste: Sie verhindert, dass ein Kostenpunkt vergessen wird, der später auf der Rechnung
  auftaucht, aber nicht in der Schätzung war.
- Die Schätzung wird zweimal erstellt: VOR und NACH dem Right-Sizing. Die Differenz zwischen
  beiden Durchläufen ist der gemessene Effekt einer technischen Entscheidung, kein
  Einsparversprechen.
- Verwenden Sie im gesamten Formular dieselben Einheiten (Stunden im Monat, GB statt GiB),
  sonst lassen sich die Zeilen nicht miteinander addieren.
- Führen Sie das Formular erneut aus, nachdem Sie das Beschaffungsmodell für Nodes geändert,
  eine AZ hinzugefügt, neue Log-Typen aktiviert oder die Egress-Topologie geändert haben.

## Kostenpositionen

| Position | Wovon sie abhängt | Einheit | Tarif (ausfüllen) | Kapitel |
|---|---|---|---|---|
| Control Plane des Clusters | Anzahl der Cluster, Laufzeit | Cluster-Stunde |  | [02](02/de.md) |
| Zuschlag für Extended Support | Version außerhalb des Standard Support | Cluster-Stunde |  | [38](38/de.md) |
| EC2-Nodes | Instanztyp, Anzahl der Nodes, Beschaffungsmodell | Instanz-Stunde |  | [09](09/de.md) |
| Auto-Mode-Zuschlag für Verwaltung | Managed Instances unter Auto Mode | Instanz-Stunde |  | [09](09/de.md) |
| Fargate: vCPU | CapacityProvisioned des Pods, Lebensdauer | vCPU-Stunde |  | [15](15/de.md) |
| Fargate: Arbeitsspeicher | CapacityProvisioned des Pods, Lebensdauer | GB-Stunde |  | [15](15/de.md) |
| EBS-Volumes | Volume-Typ, Größe, konfigurierte IOPS und Throughput | GiB-Monat |  | [23](23/de.md) |
| EBS-Snapshots | Umfang der gesicherten Daten, Aufbewahrungszeit | GiB-Monat |  | [23](23/de.md) |
| NAT Gateway: Betrieb | Anzahl der NATs (eines pro AZ), Laufzeit | NAT-Stunde |  | [31](31/de.md) |
| NAT Gateway: Verarbeitung | Egress der Pods, Image Pulls, AWS-API-Aufrufe | GB |  | [31](31/de.md) |
| Cross-AZ-Datenverkehr | East-West-Verkehr zwischen Zonen, Datenbankzugriffe in einer anderen AZ | GB |  | [31](31/de.md) |
| Ausgehender Internetverkehr | Antworten an Clients, Datenexport nach außen | GB |  | [31](31/de.md) |
| Interface Endpoints (PrivateLink) | Anzahl der Endpoints, verarbeitetes Volumen | Endpoint-Stunde und GB |  | [31](31/de.md) |
| Logs: Aufnahme (Ingestion) | Umfang der aufgenommenen Pod- und Control-Plane-Logs | GB |  | [34](34/de.md) |
| Logs: Speicherung | Volumen bei festgelegter Aufbewahrungszeit | GB-Monat |  | [34](34/de.md) |
| Load Balancer (NLB, ALB) | Anzahl der Load Balancer, verarbeitetes Volumen | Stunde und Volumen |  | [26](26/de.md) |

Gateway Endpoints für S3 und DynamoDB benötigen keine eigene Zeile in dieser Tabelle: Sie sind
kostenlos, leiten aber Volumen vom kostenpflichtigen NAT weg und beeinflussen daher die Zeile
„NAT Gateway: Verarbeitung“ (Kapitel 31).

## Formeln in allgemeiner Form

```text
Bezeichnungen: HOURS - Stunden im Abrechnungsmonat, RATE_* - Tarif aus der obigen Tabelle,
alle Verbrauchswerte stammen aus Metriken und Billing, nicht aus Entwurfsplänen.

control_plane = CLUSTERS * HOURS * RATE_CP
              + CLUSTERS_EXT * HOURS * RATE_CP_EXT_DELTA
# CLUSTERS_EXT - Cluster mit einer Version im Extended Support: Dies ist ein ZUSCHLAG zur
# regulären stündlichen Clustergebühr, nicht derselbe Tarif (Kapitel 38).

nodes = Summe über Pools P: NODES[P] * HOURS[P] * RATE_INSTANCE[P, Beschaffungsmodell]
# Beschaffungsmodell: On-Demand, Spot, Abdeckung durch Reserved oder Savings Plans (Kapitel 43).

auto_mode = nodes(Auto-Mode-Pools)                         # EC2-Anteil
          + MANAGED_INSTANCES * HOURS * RATE_AM_MGMT       # Verwaltungszuschlag
# VERPFLICHTEND: Reserved Instances und Savings Plans reduzieren NUR den EC2-Anteil.
# Der Verwaltungszuschlag von Auto Mode fällt nicht unter diese Rabatte und erscheint auf der
# Rechnung als eigene Position (Kapitel 09). Auch die stündliche Gebühr für die EKS Control Plane
# fällt nicht unter Compute Savings Plans (Kapitel 43).

fargate = Summe über Pods: VCPU_PROV * LIFETIME_H * RATE_VCPU
        + MEM_PROV_GB * LIFETIME_H * RATE_MEM
# VCPU_PROV und MEM_PROV_GB - die aus der CapacityProvisioned-Annotation zugeteilte Kombination,
# also nach oben gerundete requests, nicht die requests selbst (Kapitel 15).

commit_base = BASELINE_COMPUTE - SPOT_SUSTAINED
# BASELINE_COMPUTE wird NACH dem Right-Sizing berechnet, andernfalls wird Leerlauf gebunden.
# SPOT_SUSTAINED - der nachhaltig erreichbare Spot-Anteil, nicht der geplante: Savings Plans
# decken Spot nicht ab, das stündliche Commitment wird nicht zwischen Stunden übertragen und eine
# Unterdeckung verfällt jede Stunde; ein Fallback auf On-Demand bringt einen Teil des Verbrauchs
# wieder unter das Commitment (Kapitel 43 und 13). Das Commitment wird anhand von tatsächlicher
# utilization und coverage überprüft.

nat = NAT_COUNT * HOURS * RATE_NAT_HOUR
    + PROCESSED_GB * RATE_NAT_GB
# Zwei unabhängige Anteile: für die Existenz des NAT und für jedes verarbeitete Gigabyte.

cross_az = CROSS_AZ_GB * RATE_CROSS_AZ
# Abrechnung erfolgt in beide Richtungen: CROSS_AZ_GB enthält Anfrage und Antwort (Kapitel 31).

storage = Summe über Volumes: SIZE_GIB * RATE_VOLUME[Typ]
        + SNAPSHOT_GIB * RATE_SNAPSHOT
# Bezahlt wird die bereitgestellte Volume-Größe, nicht der im Dateisystem belegte Platz.

logs = INGEST_GB * RATE_INGEST + STORED_GB * RATE_STORAGE
# INGEST_GB - das aufgenommene Volumen: Es ist gewöhnlich die größte Kostenposition (Kapitel 34).

total_month = control_plane + nodes + auto_mode + fargate
            + nat + cross_az + egress_internet + storage + logs
            + endpoints + load_balancers
```

## Was häufig vergessen wird

- **Auto-Mode-Zuschlag.** Auf der Rechnung ist dies eine eigene Position zusätzlich zum
  EC2-Tarif, und Rabattmodelle betreffen ihn nicht; beim Vergleich von Auto Mode mit dem eigenen
  Stack wird er explizit berechnet (Kapitel 09).
- **Extended Support als Zuschlag.** Ein Cluster mit einer veralteten Version kostet pro
  Betriebsstunde mehr, nicht gleich viel; in der Schätzung ist dies ein eigener Summand
  (Kapitel 38).
- **Cross-AZ in beide Richtungen.** Ein Service in einer Zone, der eine Datenbank in einer
  anderen aufruft, zahlt für den Austausch, nicht nur für die Anfrage; beide Richtungen zählen
  (Kapitel 31).
- **NAT wird zweimal abgerechnet.** Die Stundengebühr läuft, solange das NAT existiert,
  und unabhängig davon wird jedes verarbeitete Gigabyte bezahlt; meist wird der zweite Anteil
  vergessen (Kapitel 31).
- **Logs kosten hauptsächlich bei der Aufnahme.** Eine Verkürzung der Aufbewahrungszeit betrifft
  nur die Speicherung und spart wenig; wirksam sind Sammelintervall, Log-Level und die Filterung
  von Serien (Kapitel 34).
- **Vergessene Volumes und Snapshots.** Ein PVC wurde gelöscht, das Volume blieb; Snapshots
  sammeln sich jahrelang an. Dies ist ein stiller Verlust, der nur im Billing sichtbar wird
  (Kapitel 23).
- **Load Balancer nach einem gelöschten Service.** Der Service wurde nicht über Kubernetes
  gelöscht, NLB oder ALB bleibt bestehen und wird weiter abgerechnet (Kapitel 26).
- **Leerlaufkapazität.** Sie zahlen für reservierte requests, nicht für die Nutzung: Die
  Differenz zwischen requested und used ist bezahlter Leerlauf, multipliziert mit den Replikas
  (Kapitel 43).

## Reihenfolge der Optimierung

1. **Right-Size und Bin-Pack** - requests an den tatsächlichen Verbrauch anpassen und
   consolidation die Nodes verdichten lassen (Kapitel 43, 14, 12).
2. **Commitment auf einen stabilen Baseline-Wert** - Savings Plans für ein Volumen, das über
   Monate besteht, erst nach der Reduzierung (Kapitel 43).
3. **Spot für flexible Workloads** - Unterbrechbare Workloads auf Spot mit Diversifizierung über
   Typen und Zonen verlagern (Kapitel 13).
4. **Datenverkehr, Logs und Speicherung** - Gateway Endpoint für S3, NAT je Zone, Log-Volumen
   an der Quelle, Volumes und Snapshots (Kapitel 31, 34, 23).

Diese Reihenfolge ist bewusst so gewählt, weil jeder folgende Schritt auf eine Basis angewendet
wird, die der vorherige verkleinert hat: Ein aufgeblähtes Volumen zu committen oder auf Spot zu
setzen bedeutet, die Bezahlung von Leerlauf festzuschreiben.

## Grenzen der Vorlage

- Das Formular ersetzt weder den AWS Pricing Calculator für die Prognose noch den Cost and Usage
  Report für Ist-Werte: Es liefert die Liste der Kostenpositionen und die Formeln; die Zahlen
  stammen von dort.
- Anwendungsservices außerhalb des Clusters (Datenbanken, Queues, Caches, S3 für
  Anwendungsdaten) werden hier nicht berechnet, obwohl sie Teil der Produktrechnung sind.
- Die Allokation auf Teams und Namespaces erfolgt mit dem Allokationswerkzeug aus Kapitel 43,
  nicht mit dieser Tabelle: Sie betrifft den gesamten Cluster und nicht die Frage, wer darin wie
  viel ausgegeben hat.
- Geteilte Kosten (Control Plane, System-Namespaces, Leerlauf) zeigt das Formular als
  Clusterzeilen; die Regel für ihre Verteilung auf Teams wird separat gewählt (Kapitel 43).
- Rabatte aus Vereinbarungen mit AWS und die Reihenfolge der Anwendung von Commitments modelliert
  das Formular nicht: Sie sind nur im tatsächlichen Billing sichtbar.
