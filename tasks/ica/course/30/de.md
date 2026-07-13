[RU version](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md)

# Kapitel 30. Performance der control plane und Betrieb

> **Was kommt als Nächstes.** Wir haben den Weg von den Grundlagen bis zu Multicluster und
> VMs zurückgelegt. Dieses Kapitel schließt den Betriebsblock ab: wie die control plane
> funktioniert, wovon ihre Performance abhängt, was man überwachen sollte, wie man tunt und
> wie man das Mesh in Produktion gesund hält. Vor uns liegen noch zwei Kapitel - Härtung und
> Bedrohungsmodell (Kapitel 31) und die Vorbereitung auf die ICA-Prüfung (Kapitel 32).

## 30.1. Funktionsweise der control plane und was die Performance beeinflusst

Zur Erinnerung aus Kapitel 4: istiod (control plane) verarbeitet selbst keinen Traffic.
Seine Aufgabe ist es, den Zustand des Clusters zu beobachten (Dienste, Pods, deine Configs)
und die **aktuelle Konfiguration** über xDS an alle Envoys zu verteilen. Genau diese Arbeit
belastet die control plane.

```mermaid
flowchart LR
    E["Änderung<br>(Pod / Config)"] --> D["debounce / Batching"]
    D --> C["istiod berechnet neu"]
    C --> P["Push über xDS an alle Proxys"]
    style E fill:#673ab7,color:#fff
    style D fill:#f4b400,color:#000
    style C fill:#326ce5,color:#fff
    style P fill:#0f9d58,color:#fff
```

Die Performance von istiod beeinflussen:

- **Anzahl der Dienste und Pods** - je mehr, desto mehr Konfiguration muss berechnet und
  verschickt werden.
- **Änderungshäufigkeit (churn)** - jeder neue Pod, jede Änderung an einem Dienst oder einer
  Regel stößt eine Neuberechnung und Verteilung an.
- **Anzahl der verbundenen Proxys** - jedem muss die Konfiguration zugestellt werden.
- **Größe der Konfiguration pro Proxy** - wenn jeder sidecar über das gesamte Mesh Bescheid
  weiß (Kapitel 19), wächst das Volumen quadratisch.

## 30.2. Monitoring der control plane

istiod muss getrennt von den Anwendungen überwacht werden. Orientiere dich an seinen
„goldenen Signalen“:

- **Verzögerung der Konfigurationsverteilung** - `pilot_proxy_convergence_time`. Das
  Hauptsignal: wie lange eine Änderung bis zum Proxy braucht. Ein Anstieg ist das erste
  Anzeichen, dass die control plane nicht hinterherkommt.
- **Pushes und Fehler** - `pilot_xds_pushes` (Anzahl der Verteilungen) und Zähler für
  abgelehnte Konfigurationen/xDS-Fehler. Ein Fehleranstieg deutet auf Konfigurations- oder
  Verbindungsprobleme hin.
- **Verbundene Proxys** - wie viele Envoys mit istiod verbunden sind.
- **Sättigung** - CPU und Speicher von istiod. Stößt es an die Limits, leidet die gesamte
  Konfigurationsverteilung.

Diese Metriken sind die Grundlage für Alerts auf die control plane (Kapitel 17).
Funktionierende Proxys arbeiten auch bei nicht erreichbarem istiod weiter (auf der zuletzt
empfangenen Konfiguration), aber neue Änderungen kommen nicht an - deshalb ist die
Gesundheit von istiod kritisch.

**Prüfe deine Arbeit.** Grundlegende PromQL-Abfragen für die goldenen Signale von istiod:

```promql
# p99 der Konfigurations-Konvergenzzeit (Sek.) - das Hauptsignal
histogram_quantile(0.99, sum(rate(pilot_proxy_convergence_time_bucket[5m])) by (le))

# Häufigkeit der xDS-Pushes nach Typ (cds/eds/lds/rds)
sum(rate(pilot_xds_pushes[5m])) by (type)

# abgelehnte Konfigurationen - sollte 0 sein
sum(rate(pilot_total_xds_rejects[5m]))

# wie viele Proxys mit istiod verbunden sind
pilot_xds
```

Ein Anstieg der p99-Konvergenz oder ein von null verschiedenes `pilot_total_xds_rejects` ist
ein Signal, dem nachzugehen: Überlastung von istiod, kaputte Config oder
Verbindungsprobleme.

## 30.3. Performance-Tuning

Die wichtigsten Hebel (viele haben wir bereits erwähnt):

- **discovery selectors** (Kapitel 19) - istiod verfolgt nur die benötigten Namespaces und
  ignoriert die übrigen. Der größte Gewinn, wenn ein Teil des Clusters nicht im Mesh ist.
- **Sidecar scope** (Kapitel 19) - jeder Proxy erhält nur die Konfiguration der für ihn
  nötigen Dienste, nicht des gesamten Mesh. Senkt das Konfigurationsvolumen und die Last auf
  istiod drastisch.
- **Batching und Debounce von Ereignissen** - istiod verteilt die Konfiguration nicht bei
  jedem Muckser, sondern gruppiert Änderungen über ein kurzes Intervall (debounce) und
  drosselt die Push-Häufigkeit. Diese Parameter (etwa `PILOT_DEBOUNCE_AFTER`,
  `PILOT_PUSH_THROTTLE`) werden auf die Last abgestimmt: mehr Batching - weniger Pushes, aber
  etwas höhere Verteilungsverzögerung.
- **Ressourcen und HA von istiod** (Kapitel 27) - mehrere Replicas + HPA, ausreichend
  CPU/Speicher.
- **Reduzierung von churn** - weniger überflüssige Änderungen (z. B. Configs nicht ohne
  Grund anfassen) = weniger Neuberechnungen.

Die Batching-Parameter werden als Umgebungsvariablen von istiod gesetzt - im
`IstioOperator` über `components.pilot.k8s.env`:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    pilot:
      k8s:
        env:
        - name: PILOT_DEBOUNCE_AFTER      # vor Neuberechnung auf Ruhe warten
          value: "100ms"
        - name: PILOT_DEBOUNCE_MAX        # aber nicht länger als das
          value: "10s"
        - name: PILOT_PUSH_THROTTLE       # max. gleichzeitige Pushes
          value: "100"
```

Mehr debounce - weniger Neuberechnungen und Pushes bei einem Änderungsschub, aber etwas
höhere Verteilungsverzögerung (achte auf `pilot_proxy_convergence_time`, Abschnitt 30.2).
Die Standardwerte passen für die meisten; ändere sie bewusst und gezielt für ein konkretes
Problem.

## 30.4. Deploy-Policies: OPA Gatekeeper

In einem großen Mesh ist es wichtig, dass Teams keine unsicheren oder brechenden
Konfigurationen ausrollen. Hier hilft **OPA Gatekeeper** - ein admission-Controller, der
Ressourcen bei der Erstellung prüft (wie der Webhook aus Kapitel 4) und regelwidrige
ablehnt.

Typische Policies für Istio:

- ein Injection-Label (oder `istio.io/rev`) auf Namespaces mit Anwendungen verlangen;
- `PeerAuthentication` mit `mode: DISABLE` verbieten (damit niemand versehentlich mTLS
  abschaltet);
- verlangen, dass die Ports eines Service korrekt benannt sind (Kapitel 10);
- zu weit gefasste `AuthorizationPolicy` oder `EnvoyFilter` ohne Review verbieten.

Gatekeeper überführt die Best Practices aus diesem Kurs in **automatisch durchgesetzte
Regeln**: nicht „wir haben uns darauf geeinigt, es so zu machen“, sondern „sonst wird es
schlicht nicht deployt“.

Beispiel: `PeerAuthentication` mit `mode: DISABLE` verbieten. Die Policy wird durch zwei
Ressourcen beschrieben - `ConstraintTemplate` (was geprüft wird, in Rego) und `Constraint`
(worauf es angewendet wird):

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: denymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: DenyMtlsDisable
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package denymtlsdisable
      violation[{"msg": msg}] {
        input.review.object.spec.mtls.mode == "DISABLE"
        msg := "PeerAuthentication mode DISABLE ist durch Policy verboten"
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
    - apiGroups: ["security.istio.io"]
      kinds: ["PeerAuthentication"]
```

Jetzt wird jedes `PeerAuthentication` mit abgeschaltetem mTLS beim admission abgelehnt -
niemand „durchlöchert“ versehentlich das Mesh. Eine Alternative zu Gatekeeper mit
einfacherer YAML-Syntax (ohne Rego) ist **Kyverno**; die Wahl zwischen beiden richtet sich
meist nach dem im Team etablierten Werkzeug.

## 30.5. Betrieb auf EKS/AWS

Ein paar EKS-spezifische Punkte, die die control plane betreffen.

- **Monitoring von istiod über managed Services.** Die goldenen Signale von istiod schreibt
  man bequem in **Amazon Managed Prometheus (AMP)** und betrachtet sie in **Grafana (AMG)**,
  während die Metriken der **ADOT**-Agent sammelt (Kapitel 17). istiod kann dabei auf
  **Fargate** leben (Kapitel 27) - es ist stateless.
- **Karpenter und Spot-Nodes erhöhen den churn.** Das Autoscaling von Nodes (Karpenter) und
  Spot mit seinen Unterbrechungen bedeuten häufiges Auftauchen/Verschwinden von Nodes und
  Pods. Für die control plane ist das ein **Anstieg des churn**: jeder neu erzeugte Pod
  bedeutet Endpoints-Ereignisse und neue xDS-Pushes. Was hilft: eine nicht zu aggressive
  **consolidation** bei Karpenter, ein `disruption budget` auf dem Node-Pool, PDBs auf den
  Anwendungen - damit Nodes nicht ständig „neu zusammengebaut“ werden. Plus derselbe scope
  wie zuvor (Kapitel 19), damit ein Änderungsschub in einem Teil des Clusters nicht an alle
  Proxys verteilt wird.
- **Kosten der Observability.** Istio-Metriken sind hochkardinal; auf einem großen
  EKS-Cluster wächst die Rechnung für AMP/Speicher schnell - steuere das über die Telemetry
  API (Kapitel 18): schalte unnötige Dimensionen ab, sample Traces mit Augenmaß.

## 30.6. Betrieb im großen Maßstab: Checkliste

Fassen wir die über den Kurs verteilten Betriebspraktiken zusammen:

- **Überwache die control plane** getrennt (goldene Signale von istiod), nicht nur die
  Anwendungen.
- **Optimiere den scope** (discovery selectors + Sidecar) auf großen Clustern - der
  wichtigste Performance-Hebel.
- **Aktualisiere über Revisionen/Canary** (Kapitel 3), nicht in-place auf laufender
  Produktion.
- **Plane PKI und gemeinsame CA im Voraus** (Kapitel 16, 28), plane die Rotation des Roots.
- **Halte einheitliche Versionen** von Istio über die Cluster eines Multiclusters
  (Kapitel 28).
- **Automatisiere Policies** über Gatekeeper - Best Practices als verpflichtende Regeln.
- **Observability über das gesamte Mesh** mit Alerts (Kapitel 17-18), sinnvolles Sampling.
- **Probe Upgrades und Rollbacks**, bevor sie im Ernstfall gebraucht werden.
- **Verkompliziere nichts vorzeitig** - ambient, Multicluster, VMs führe für einen konkreten
  Bedarf ein, nicht „weil man kann“.

## 30.7. Zusammenfassung des Kapitels

- Die control plane (istiod) trägt keinen Traffic, berechnet und verteilt aber die
  Konfiguration an alle Proxys; genau das ist ihre Last.
- Die Performance hängt ab von der Anzahl der Dienste/Pods, der Änderungshäufigkeit, der
  Anzahl der Proxys und der Größe der Konfiguration pro Proxy.
- Überwache die goldenen Signale von istiod: Verteilungszeit der Konfiguration
  (`pilot_proxy_convergence_time`), Pushes und Fehler, Anzahl der Proxys, CPU/Speicher.
- Tuning: **discovery selectors** und **Sidecar scope** (Kapitel 19), Batching/Throttle von
  Pushes (`PILOT_DEBOUNCE_AFTER`/`PILOT_PUSH_THROTTLE` über `IstioOperator`), Ressourcen und
  HA von istiod, Reduzierung von churn.
- **OPA Gatekeeper** (oder Kyverno) verwandelt Best Practices in verpflichtende
  admission-Regeln (`ConstraintTemplate` + `Constraint`), etwa das Verbot von mTLS
  `DISABLE`.
- Auf EKS: Monitoring von istiod über AMP/AMG/ADOT, istiod auf Fargate; **Karpenter/Spot**
  erhöhen den churn - bremse die consolidation und halte den scope eng; achte auf die Kosten
  hochkardinaler Metriken.
- Betrieb im großen Maßstab: Monitoring der control plane, Optimierung des scope, Upgrades
  über Revisionen, PKI im Voraus, einheitliche Versionen, Automatisierung von Policies,
  durchgängige Observability, geprobte Rollbacks, Verzicht auf überflüssige Komplexität.

## 30.8. Fragen zur Selbstüberprüfung

1. Womit ist die control plane belastet, wenn sie doch keinen Benutzer-Traffic verarbeitet?
2. Welche Faktoren beeinflussen die Performance von istiod?
3. Nenne die goldenen Signale der control plane und was ein Anstieg von
   `pilot_proxy_convergence_time` bedeutet.
4. Welche Performance-Tuning-Hebel kennst du? Wie setzt man die Batching-Parameter von
   istiod?
5. Was bringt OPA Gatekeeper im Kontext des Istio-Betriebs? Aus welchen Ressourcen besteht
   eine Policy und wodurch lässt sie sich ersetzen?
6. Mit welchen PromQL-Abfragen würdest du die Gesundheit der control plane prüfen?
7. Wie beeinflussen Karpenter und Spot-Nodes die Last auf istiod und was tut man dagegen?

## Praxis

Übe Betrieb und Performance in der Praxis: discovery selectors und Sidecar scope, Monitoring
der goldenen Signale von istiod, Deploy-Policies über OPA Gatekeeper.

🧪 Lab 33: [tasks/ica/labs/33](../../labs/33/README_DE.MD)

---
[Inhaltsverzeichnis](../README_DE.md) · [Kapitel 29](../29/de.md) · [Kapitel 31](../31/de.md)
