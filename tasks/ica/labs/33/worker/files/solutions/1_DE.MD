[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 33 - Referenzlösung

Istio `1.29.1` (Standardprofil, clusterweite Erkennung, kein Sidecar-Scope) und OPA
Gatekeeper sind vorinstalliert. Es gibt drei Namespaces:

- `app` (injiziert, `mesh=enabled`) - `frontend`;
- `shop` (injiziert, `mesh=enabled`) - `catalog` + ein sidecar-loses `probe`;
- `legacy` (NICHT injiziert, kein `mesh`-Label) - `legacy-app`.

`istioctl` ist auf dem Worker-PC verfügbar.

## Ziel

1. **Discovery-Selektoren** aktivieren, sodass istiod nur Namespaces mit `mesh=enabled`
   verfolgt (`legacy` wird ausgeschlossen).
2. Einen **Sidecar**-Egress-Scope in `app` hinzufügen, sodass dessen Proxys nur `app` + `istio-system`
   kennen (`shop` wird ausgeschlossen).
3. Die **Golden Signals** von istiod beobachten.
4. Eine Bereitstellungsrichtlinie mit **OPA Gatekeeper** durchsetzen.

## Schritt 1. Discovery-Selektoren

Die Installation mit `meshConfig.discoverySelectors`, das auf `mesh=enabled` passt, erneut anwenden
(`istio-system`, `app`, `shop` tragen es; `legacy` nicht):

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    discoverySelectors:
      - matchLabels:
          mesh: enabled
EOF
istioctl install -f /tmp/iop.yaml -y
```

Überprüfen, dass `legacy` aus dem Mesh verschwindet (von einem Proxy, der noch keinen Sidecar-Scope hat):

```bash
istioctl proxy-config clusters deploy/catalog.shop | grep legacy-app || echo "legacy dropped"
```

## Schritt 2. Sidecar-Egress-Scope in app

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

`./*` = der eigene Namespace des Proxys (`app`), plus `istio-system/*` für Control Plane und
Gateways. Alles andere (einschließlich `shop`) wird aus den `app`-Proxys entfernt:

```bash
istioctl proxy-config clusters deploy/frontend.app | grep catalog.shop || echo "shop dropped from app"
```

## Schritt 3. Golden Signals von istiod

```bash
# convergence time + push count (the key control-plane signals)
kubectl exec -n shop deploy/probe -c probe -- \
  curl -s http://istiod.istio-system:15014/metrics \
  | grep -E 'pilot_proxy_convergence_time|pilot_xds_pushes'

# how many proxies are connected / config sync state
istioctl proxy-status
```

`pilot_proxy_convergence_time` ist das wichtigste Signal: wie lange eine Änderung braucht, um die
Proxys zu erreichen. `pilot_xds_pushes` zählt Pushes. Steigende Konvergenzzeit oder Push-Fehler bedeuten,
dass die Control Plane unter Druck steht - die Scope-Hebel in den Schritten 1-2 reduzieren ihn.

## Schritt 4. OPA-Gatekeeper-Bereitstellungsrichtlinie

Verlangen, dass jeder Namespace das Injektionslabel deklariert (eine klassische Richtlinie für
Bereitstellungshygiene aus dem Kapitel). Vorlage und Constraint erstellen:

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("namespace is missing required labels: %v", [missing])
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-injection
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["istio-injection"]
EOF
```

Überprüfen, dass die Richtlinie durchgesetzt wird (sollte **denied** ergeben):

```bash
kubectl create ns test-no-label
# Error ... admission webhook "validation.gatekeeper.sh" denied the request:
# namespace is missing required labels: {"istio-injection"}
```

## Warum das funktioniert

- **Discovery-Selektoren** begrenzen, welche Namespaces istiod überhaupt überwacht. Namespaces ohne
  das Selektorlabel sind für die Control Plane unsichtbar - ihre Services werden auf keinem Proxy zu
  Clustern/Endpoints, was die Konfigurationsgröße und den Push-Aufwand reduziert. Der größte Gewinn entsteht,
  wenn ein Teil des Clusters nicht im Mesh ist.
- **Sidecar-Egress-Scope** begrenzt pro Namespace, über welche Services ein Proxy informiert wird.
  Mit `./*` + `istio-system/*` enthält ein `app`-Proxy keine Konfiguration mehr für `shop` (oder den
  Rest des Mesh). Das verkleinert die Konfiguration jedes Proxys und den Push-Fan-out von istiod.
- **Golden Signals** (`pilot_proxy_convergence_time`, `pilot_xds_pushes`, verbundene Proxys,
  istiod CPU/mem) zeigen, ob die Control Plane mithalten kann; die Scope-Hebel sind die wichtigsten
  Mittel, um die Konvergenzzeit zu senken.
- **OPA Gatekeeper** macht Best Practices zu Admission-Regeln: nicht konforme Ressourcen werden bei
  der Erstellung abgelehnt, statt lediglich davon abzuraten.
