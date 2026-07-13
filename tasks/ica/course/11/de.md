[RU version](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md)

# Kapitel 11. Kubernetes Gateway API

> **Was kommt als Nächstes.** In den Kapiteln 5-10 haben wir den Traffic über
> Istio-Ressourcen gesteuert: Gateway und VirtualService. Aber in Kubernetes ist ein
> gemeinsamer Standard für dasselbe erschienen - die Kubernetes Gateway API. Istio
> unterstützt sie vollwertig und betrachtet sie als Zukunft für Ingress. In diesem Kapitel
> klären wir, was das ist, vergleichen sie mit den Istio-Ressourcen und verstehen vor
> allem, was und wann man besser verwendet.

## 11.1. Wozu ein eigener Standard nötig wurde

Die Ressourcen `Gateway` und `VirtualService` aus `networking.istio.io` funktionieren
hervorragend, aber sie haben einen Nachteil: Es ist eine **Istio-spezifische** API.
Entscheiden Sie sich morgen, das Mesh oder den Ingress-Controller zu wechseln, müssen alle
Manifeste für ein anderes Produkt neu geschrieben werden. Jede Lösung (Istio, nginx,
Traefik, Cloud-Gateways) hatte ihren eigenen Satz von Ressourcen.

Die Kubernetes-Community hat dieses Problem mit einem einheitlichen Standard gelöst - der
**Kubernetes Gateway API** (`gateway.networking.k8s.io`). Das ist eine
herstellerneutrale API zur Steuerung von eingehendem Traffic, die viele Produkte
implementieren, darunter Istio. Sie schreiben einmal nach dem Standard - und es
funktioniert auf jeder kompatiblen Implementierung.

Wir warnen gleich vor der Verwechslung bei den Namen. Es gibt zwei verschiedene Ressourcen
mit dem Wort `Gateway`:

- `Gateway` aus `networking.istio.io` - eine Istio-Ressource (wir haben sie ab Kapitel 5
  verwendet).
- `Gateway` aus `gateway.networking.k8s.io` - eine Ressource des Standards Kubernetes
  Gateway API.

Das sind verschiedene APIs mit unterschiedlicher Struktur. Im Folgenden meinen wir mit
„Gateway API" genau die zweite, die standardisierte.

## 11.2. Rollen und Ressourcen der Gateway API

In der Gateway API ist die Verantwortung auf mehrere Ressourcen aufgeteilt, jede für ihre
Rolle:

| Ressource | Zuständig für | Entsprechung in Istio |
|--------|-------------|----------------|
| `GatewayClass` | Typ der Implementierung (wer den Traffic verarbeitet) | wird bei der Installation festgelegt |
| `Gateway` | worauf gelauscht wird: Ports, Protokolle, TLS | Istio `Gateway` |
| `HTTPRoute` | Regeln für HTTP-Routing | Istio `VirtualService` |

Außer `HTTPRoute` gibt es auch andere Routen für verschiedene Protokolle: `TCPRoute`,
`TLSRoute`, `GRPCRoute`. Die Idee ist dieselbe wie in Istio: getrennt „worauf wir lauschen"
(Gateway), getrennt „wohin wir leiten" (Route).

## 11.3. Installation der CRD der Gateway API

Ein wichtiger praktischer Punkt, über den man häufig stolpert: Die Ressourcen der Gateway
API sind **CRD, die standardmäßig im Cluster fehlen können**. Istio implementiert den
Standard, aber die Definitionen selbst (`GatewayClass`, `Gateway`, `HTTPRoute`…) muss
entweder die Community oder Istio bereitstellen. Sind die CRD nicht installiert, werden
Ihre Manifeste einfach nicht angewendet.

Vorhandensein prüfen:

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

Wenn die CRD fehlen, installieren Sie sie aus dem offiziellen Release des Standards (der
Kanal `standard` enthält stabile Ressourcen, `experimental` - zusätzlich noch
`TCPRoute`/`TLSRoute` und Weiteres):

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Istio installiert bei der Installation automatisch eine `GatewayClass` mit dem Namen
`istio` (istiod beobachtet die CRD und erstellt die Klasse). Prüfen, dass die Klasse
vorhanden ist:

```bash
kubectl get gatewayclass istio
```

## 11.4. Gateway und HTTPRoute am Beispiel

Bringen wir ein Gateway auf Port 80 hoch und leiten den gesamten Traffic an den Service
`reviews`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio    # diese Implementierung stellt Istio bereit
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-route
spec:
  parentRefs:
  - name: my-gateway         # an welches Gateway die Route gebunden ist
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: reviews          # direkt der Name des Kubernetes Service
      port: 8080
```

```mermaid
flowchart LR
    C["Client"] --> GW["Gateway<br>class: istio"]
    GW --> HR["HTTPRoute<br>Routing-Regeln"]
    HR --> S["Service reviews"]
    style C fill:#673ab7,color:#fff
    style GW fill:#326ce5,color:#fff
    style HR fill:#326ce5,color:#fff
    style S fill:#0f9d58,color:#fff
```

Schlüsselfelder:

- **`gatewayClassName: istio`** - sagt, dass dieses Gateway Istio implementiert. Das ist
  die Entsprechung dazu, wie wir uns in einem Istio-Gateway über `selector` an das
  Ingress-Gateway gebunden haben.
- **`parentRefs`** in HTTPRoute verbindet die Route mit einem konkreten Gateway. In Istio
  spielte diese Rolle das Feld `gateways` im VirtualService.
- **`backendRefs`** verweist direkt auf einen Kubernetes Service und Port. Keine Subsets und
  DestinationRule gibt es in der Basis-Gateway-API - Versionen und Policies werden anders
  beschrieben.

Noch eine Annehmlichkeit: Wenn Sie ein `Gateway` mit `gatewayClassName: istio` erstellen,
kann Istio unter dieses Gateway automatisch ein separates Envoy-Deployment ausrollen. Man
muss das Ingress-Gateway nicht im Voraus installieren - es erscheint unter dem konkreten
Gateway.

## 11.5. TLS: HTTPS auf der Gateway API

Edge TLS aus Kapitel 9 wird in der Gateway API mit eigenen Feldern beschrieben. Einen
HTTPS-Listener deklariert man mit `protocol: HTTPS` und einem `tls`-Block, wo der Modus und
der Verweis auf das Secret mit dem Zertifikat stehen:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: myapp.example.com
    tls:
      mode: Terminate                # das Gateway terminiert TLS (Entsprechung von SIMPLE in Istio)
      certificateRefs:
      - kind: Secret
        name: myapp-cert             # dasselbe tls-Secret wie in Kapitel 9
    allowedRoutes:
      namespaces:
        from: All                    # welche Namespaces Routen binden dürfen (siehe 11.7)
```

Entsprechung der Modi zu Kapitel 9:

- **`mode: Terminate`** - das Gateway entschlüsselt TLS (wie `SIMPLE`/`MUTUAL` in Istio).
  Das Client-Zertifikat (Entsprechung von `MUTUAL`) wird über
  `frontendValidation`/`BackendTLSPolicy` konfiguriert und hängt von der Version des
  Standards ab.
- **`mode: Passthrough`** - das Gateway entschlüsselt nicht, der Traffic geht durchgereicht
  nach SNI (wie `PASSTHROUGH`); dafür verwendet man `TLSRoute`, nicht `HTTPRoute`.

Das Zertifikat wird in einem gewöhnlichen Kubernetes-`Secret` vom Typ `tls` gespeichert -
man kann es genauso mit cert-manager ausstellen (Kapitel 9), nur verweist die Route jetzt
über `certificateRefs` darauf und nicht über `credentialName`.

## 11.6. Canary und Filter in HTTPRoute

Die gewichtete Aufteilung des Traffics (Canary aus Kapitel 6) ist in der Gateway API eine
**Standard**-Möglichkeit und keine Erweiterung: `backendRefs` hat das Feld `weight`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-canary
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - backendRefs:
    - name: reviews-v1       # 90% des Traffics auf v1
      port: 8080
      weight: 90
    - name: reviews-v2       # 10% auf v2
      port: 8080
      weight: 10
```

Beachten Sie: In der Gateway API gibt es keine Subsets/DestinationRule, deshalb sind
verschiedene Versionen **verschiedene Kubernetes Services** (`reviews-v1`, `reviews-v2`)
und kein Subset eines Services.

HTTPRoute kann Anfragen über **Filter** (`filters`) verändern - das ist die Entsprechung
eines Teils der Möglichkeiten des VirtualService:

```yaml
  rules:
  - filters:
    - type: RequestHeaderModifier      # Header hinzufügen/entfernen
      requestHeaderModifier:
        add:
        - name: x-env
          value: prod
    - type: RequestMirror              # Spiegelung des Traffics (Kapitel 6)
      requestMirror:
        backendRef:
          name: reviews-shadow
          port: 8080
    backendRefs:
    - name: reviews
      port: 8080
```

Nützliche Filtertypen: `RequestHeaderModifier`/`ResponseHeaderModifier` (Header),
`RequestRedirect` (Redirects, u. a. HTTP→HTTPS), `URLRewrite` (Umschreiben von Pfad/Host),
`RequestMirror` (Spiegelung). Aber **Fault Injection** gibt es im Standard nicht - das
bleibt exklusiv der Istio-API vorbehalten (Kapitel 8).

## 11.7. Routen zwischen Namespaces: allowedRoutes und ReferenceGrant

Eine Stärke der Gateway API ist die explizite und sichere Aufteilung der Rechte zwischen
Namespaces. Hier gibt es zwei Mechanismen.

**`allowedRoutes` am Listener** - das Gateway entscheidet selbst, aus welchen Namespaces es
Routen binden lassen darf (`from: Same` - nur der eigene, `All` - jeder, `Selector` - nach
Labels der Namespaces):

```yaml
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            team: frontend      # nur Routen aus Namespaces mit diesem Label
```

**`ReferenceGrant`** - wenn eine Ressource aus einem Namespace auf eine Ressource in einem
**anderen** verweist (zum Beispiel möchte eine HTTPRoute in `apps` Traffic an einen Service
in `data` senden), ist das standardmäßig verboten. Die Erlaubnis erteilt ein
`ReferenceGrant` im **Ziel**-Namespace:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-apps-to-data
  namespace: data              # Namespace, in dem der Ziel-Service liegt
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: apps            # wer verweist
  to:
  - group: ""
    kind: Service              # worauf zu verweisen erlaubt ist
```

Das schützt davor, dass eine fremde Route den Traffic auf einen Service in Ihrem Namespace
ohne Ihre Zustimmung „abzieht" - in der Istio-API gibt es keinen solchen eingebauten
Mechanismus.

## 11.8. Vergleich mit der Istio-API

| | Istio-API | Kubernetes Gateway API |
|---|-----------|------------------------|
| Eingangsressourcen | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| Bindung der Route | Feld `gateways` im VirtualService | `parentRefs` in Route |
| Wahl der Implementierung | `selector` am Ingress-Gateway | `gatewayClassName` |
| Versionen/Subsets | `DestinationRule` (Subsets) | verschiedene Services + `weight` in `backendRefs` |
| Canary nach Gewichten | `VirtualService` weight | `backendRefs.weight` (standardmäßig) |
| Spiegelung | `VirtualService` mirror | Filter `RequestMirror` (standardmäßig) |
| Fault Injection | vorhanden | nein (nur Istio) |
| Policies zum Backend | `DestinationRule` (LB, circuit breaking) | nein (nur Istio) |
| Aufteilung der Rechte nach Namespace | kein eingebauter | `allowedRoutes` + `ReferenceGrant` |
| Standard | spezifisch für Istio | allgemein, herstellerneutral |
| Portierbarkeit | nur Istio | jeder kompatible Ingress/Mesh |

Die Hauptaussage der Tabelle: Die Gateway API gewinnt bei Standardisierung, Portierbarkeit
und Rechteaufteilung zwischen Teams, während die Istio-API bei der Vollständigkeit der
Möglichkeiten beim Empfänger gewinnt (`DestinationRule`: Lastverteilung, circuit breaking,
Subsets) und bei Fault Injection. Spiegelung und Canary nach Gewichten gibt es in beiden
APIs.

## 11.9. Was und wann verwenden (Best Practices)

Praktische Empfehlungen, was man in realen Projekten wählt.

**Nehmen Sie die Kubernetes Gateway API, wenn:**

- Sie ein neues Projekt beginnen und auf dem aktuellen Standard sein möchten;
- Portierbarkeit wichtig ist: Sie sich auf der Ebene der Manifeste nicht an Istio binden
  möchten;
- eine klare Aufteilung der Verantwortung zwischen Teams nötig ist (das Plattform-Team
  besitzt das `Gateway`, die Produkt-Teams ihre `HTTPRoute`);
- die Standardmöglichkeiten des Routings ausreichen (nach Pfad, Headern, Gewichten);
- Sie mit dem **ambient mode** arbeiten: Waypoint-Proxys (Kapitel 22) werden genau über die
  Gateway API konfiguriert.

**Bleiben Sie bei der Istio-API (VirtualService/DestinationRule), wenn:**

- Features nötig sind, die es im Standard nicht gibt: **Fault Injection** (Kapitel 8),
  Policies der `DestinationRule` (feine Lastverteilung, circuit breaking, outlier detection,
  Subsets), Delegierung von Routen;
- Sie bereits viele funktionierende Manifeste auf der Istio-API haben und keinen Grund, sie
  neu zu schreiben.

(Spiegelung und Canary nach Gewichten gibt es in beiden APIs, deshalb muss man ihretwegen
weder wechseln noch bleiben.)

### Klassische Kubernetes-Ingress-Ressource (Legacy)

Es gibt auch eine dritte Eingangsvariante - das gewöhnliche Kubernetes-`Ingress`
(`networking.k8s.io/v1`), genau das, was man mit nginx-ingress, Traefik und
Cloud-Controllern verwendet hat. Istio kann dafür als Ingress-Controller auftreten: Das
Istio-Ingress-Gateway liest `Ingress`-Ressourcen, wenn bei ihnen die Klasse `istio`
angegeben ist.

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: istio
spec:
  controller: istio.io/ingress-controller
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reviews-ingress
  namespace: app
spec:
  ingressClassName: istio          # wird vom Istio-Ingress-Gateway bedient
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /reviews
        pathType: Prefix
        backend:
          service:
            name: reviews
            port:
              number: 8080
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-cert          # tls-Secret, wie in Kapitel 9
```

Warum das **Legacy** ist und warum man es für neuen Traffic nicht wählen sollte:

- Der Standard `Ingress` selbst hat einen sehr dürftigen Satz von Möglichkeiten: Host,
  Pfad, TLS - und das war's. Keine Gewichte, keine Spiegelung, keine Redirects, kein Split
  nach Headern.
- Alles, was darüber hinausgeht, wird über **nicht standardisierte Annotationen** des
  Controllers realisiert (wie bei nginx, Kapitel 26). Die Annotationen sind zwischen
  Controllern inkompatibel, und Istio unterstützt nur eine kleine Teilmenge davon - die
  meisten der gewohnten `nginx.ingress.kubernetes.io/*` funktionieren nicht.
- Die Entwicklung der Branche und von Istio selbst geht in Richtung Gateway API, die genau
  als „`Ingress` der nächsten Generation" geschaffen wurde.

Praktisches Fazit: Das klassische `Ingress` hält man in Istio nur wegen der Kompatibilität
mit alten Manifesten bei der Migration (Kapitel 26). Für neuen Ingress nehmen Sie die
Kubernetes Gateway API oder, wenn Istio-Features nötig sind, - Istio `Gateway` +
`VirtualService`.

**Allgemeine Regeln:**

- Beschreiben Sie ein und dieselbe Route nicht gleichzeitig über VirtualService und über
  HTTPRoute - das führt zu Verwirrung und Konflikten. Für einen Service wählen Sie eines von
  beiden.
- Die Istio-API verschwindet nirgendwohin und wird vollständig unterstützt, sodass die
  Migration schrittweise erfolgen kann: neue Services auf der Gateway API, alte bleiben, wie
  sie sind.
- Die Richtung der Branche geht in Richtung Gateway API, deshalb sollte man sie kennen und
  sich mit ihr vertraut machen, auch wenn Ihr Haupt-Traffic heute auf der Istio-API läuft.

## 11.10. Zusammenfassung des Kapitels

- Die Kubernetes Gateway API (`gateway.networking.k8s.io`) ist ein herstellerneutraler
  Standard zur Steuerung von eingehendem Traffic; Istio implementiert ihn.
- Verwechseln Sie das Istio-`Gateway` nicht mit dem `Gateway` aus der Gateway API - das
  sind verschiedene Ressourcen.
- Rollen in der Gateway API: `GatewayClass` (Implementierung), `Gateway` (worauf lauschen),
  `HTTPRoute` und andere Routes (wohin leiten).
- Die Bindung der Route an das Gateway - über `parentRefs`, die Wahl der Implementierung -
  über `gatewayClassName: istio`.
- Die CRD der Gateway API können standardmäßig fehlen - man installiert sie separat (Kanal
  `standard`), und die `GatewayClass istio` erstellt Istio selbst.
- TLS: HTTPS-Listener mit `tls.mode: Terminate`/`Passthrough` und Verweis auf das Secret
  über `certificateRefs` (Entsprechung von `credentialName`); Zertifikate stellt genauso
  cert-manager aus.
- Canary nach Gewichten (`backendRefs.weight`, aber Versionen sind verschiedene Services)
  und Spiegelung (Filter `RequestMirror`) gibt es standardmäßig; Fault Injection und die
  Policies der `DestinationRule` - nur in der Istio-API.
- Rechteaufteilung zwischen Namespaces: `allowedRoutes` am Listener und `ReferenceGrant`
  für Cross-Namespace-Verweise - eine eingebaute Entsprechung gibt es in der Istio-API
  nicht.
- Best Practice: Gateway API für neuen Ingress, Standardszenarien und ambient; Istio-API -
  wenn Fault Injection oder Policies der DestinationRule nötig sind; beide nicht für ein und
  dieselbe Route mischen.
- Das klassische Kubernetes-`Ingress` (`ingressClassName: istio`) bedient Istio ebenfalls,
  aber das ist Legacy: Die Möglichkeiten sind dürftig, Fortgeschrittenes - über nicht
  standardisierte Annotationen (kleine Teilmenge). Man hält es wegen der Kompatibilität bei
  der Migration, für neuen Traffic wählt man es nicht.

## 11.11. Fragen zur Selbstüberprüfung

1. Welches Problem löst die Kubernetes Gateway API im Vergleich zur Istio-API?
2. Wodurch unterscheiden sich die zwei Ressourcen mit dem Namen `Gateway`?
3. Welche Ressourcen der Gateway API entsprechen dem Istio-Gateway und dem VirtualService?
4. Wofür sind `gatewayClassName` und `parentRefs` zuständig?
5. In welchen Fällen bleibt man besser bei Istio VirtualService/DestinationRule? Welche
   Features gibt es in der Gateway API nicht?
6. Warum sollte man eine Route nicht gleichzeitig in beiden APIs beschreiben?
7. Wie konfiguriert man in der Gateway API HTTPS und Canary nach Gewichten? Wodurch
   unterscheidet sich Canary von Istio (was ist mit Subsets)?
8. Wozu braucht man `allowedRoutes` und `ReferenceGrant`? Welches Sicherheitsproblem lösen
   sie?
9. Was prüft man, wenn die Manifeste der Gateway API im Cluster nicht angewendet werden?
10. Kann Istio das klassische Kubernetes-`Ingress` bedienen und warum gilt es als Legacy?
    Wann verwendet man es dennoch?

## Praxis

Konfigurieren Sie Ingress über die Kubernetes Gateway API (Gateway + HTTPRoute):

🧪 Lab 16: [tasks/ica/labs/16](../../labs/16/README_DE.MD)

---
[Inhaltsverzeichnis](../README_DE.md) · [Kapitel 10](../10/de.md) · [Kapitel 12](../12/de.md)
