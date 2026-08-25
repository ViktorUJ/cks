[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 21 - Referenzlösung

Istio `1.29.1` ist installiert. Zwei Namespaces sind bereitgestellt:
- `app` mit `ping-pong` (Sidecar injiziert);
- `other` mit `backend` (Sidecar injiziert).

Standardmäßig erhält jedes Sidecar die Envoy-Konfiguration für **alle** Services im Mesh, daher enthält der
`app`-Proxy auch einen Cluster für `backend.other`, obwohl er nie mit ihm kommuniziert.

## Ziel

Begrenze die Proxys im Namespace `app` mit einer `Sidecar`-Ressource, sodass sie nur Konfiguration
für ihren eigenen Namespace und `istio-system` erhalten.

## Schritt 1. Die Standardkonfiguration (ohne Begrenzung) beobachten

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config clusters "$POD" -n app | grep backend.other
# a cluster for backend.other.svc.cluster.local is present
```

## Schritt 2. Eine Sidecar-Ressource zur Begrenzung des Egress anwenden

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

- `./*` - jeder Service im **lokalen** Namespace (`app`);
- `istio-system/*` - der Control-Plane-Namespace (erforderlich für Telemetrie usw.).

Ein `Sidecar` namens `default` ohne `workloadSelector` gilt für alle Workloads im
Namespace.

## Schritt 3. Verifizieren, dass die Konfiguration kleiner wurde

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# 'other' namespace clusters are gone
istioctl proxy-config clusters "$POD" -n app | grep backend.other || echo "pruned ✅"

# own namespace clusters remain
istioctl proxy-config clusters "$POD" -n app | grep ping-pong.app
```

## Funktionsweise und Bedeutung

- Die Ressource **`Sidecar`** steuert den Umfang der Konfiguration, die istiod an einen
  Proxy übermittelt. `egress.hosts` legt per Whitelist fest, über welche Services der Proxy informiert wird.
- Standardmäßig ist das Mesh ein "vollständiges Mesh": Jeder Proxy kennt jeden Service. In einem großen
  Cluster (Tausende von Services) bedeutet das riesige Envoy-Konfigurationen, hohen Speicherbedarf pro Pod
  und hohe istiod-CPU-Last bei jeder Änderung.
- Das Begrenzen von Proxys mit `Sidecar`-Ressourcen ist der Standardweg, damit Istio skaliert:
  kleinere Konfigurationen, schnellere Übermittlungen, geringere istiod-Last und engere Egress-Grenzen.
- `outboundTrafficPolicy` innerhalb von `Sidecar` kann zusätzlich `REGISTRY_ONLY` pro
  Namespace festlegen, um nicht deklarierte Egress-Verbindungen zu blockieren.

> Hinweis: Die Begrenzung betrifft die *Konfigurationsverteilung*, nicht die Autorisierung. Um Aufrufe tatsächlich zu verbieten,
> verwende `AuthorizationPolicy` (Labor 04) oder `outboundTrafficPolicy: REGISTRY_ONLY`.
