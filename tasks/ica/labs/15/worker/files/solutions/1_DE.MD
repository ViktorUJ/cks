[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 15 - Referenzlösung

Verwendete Istio-Version: `1.29.1` (istioctl ist auf dem Worker-PC vorinstalliert).

## Ziel

Installiere Istio mit einer **angepassten** Konfiguration unter Verwendung eines `IstioOperator`-Manifests:
- beginne mit dem Profil `default`;
- setze zwei `meshConfig`-Optionen:
  - `accessLogFile: /dev/stdout` (Envoy-Zugriffsprotokolle an stdout),
  - `outboundTrafficPolicy.mode: REGISTRY_ONLY` (blockiert ausgehenden Datenverkehr zu unbekannten Hosts);
- füge neben dem standardmäßigen `istio-ingressgateway` eine **zweite** Ingress-Gateway-Komponente
  `ingressgateway-internal` hinzu.

## Schritt 1. Das IstioOperator-Manifest erstellen

```bash
cat > custom-istio.yaml <<'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: custom-istio
spec:
  profile: default
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
      - name: ingressgateway-internal
        enabled: true
        label:
          istio: ingressgateway-internal
        k8s:
          service:
            type: ClusterIP
EOF
```

## Schritt 2. Istio mit dem angepassten Manifest installieren

```bash
istioctl install -f custom-istio.yaml -y
```

## Schritt 3. Die Installation überprüfen

```bash
# control plane
kubectl get pods -n istio-system

# both ingress gateways
kubectl get deploy -n istio-system | grep -E 'ingressgateway'

# meshConfig landed in the istio configmap
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy|REGISTRY_ONLY'
```

Erwartet:
- `istiod` hat den Status `Running`;
- die Deployments `istio-ingressgateway` und `ingressgateway-internal` sind beide bereit;
- die ConfigMap `istio` enthält `accessLogFile: /dev/stdout` und
  `outboundTrafficPolicy.mode: REGISTRY_ONLY`.

## (optional) Schritt 4. REGISTRY_ONLY in Aktion sehen

```bash
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
kubectl -n demo run curl --image=curlimages/curl -it --rm --restart=Never -- \
  sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://httpbin.org/get'
# -> 502 : egress is blocked because the host is not in the mesh registry
```

Mit `outboundTrafficPolicy: REGISTRY_ONLY` werden Aufrufe an externe Hosts, die nicht
über einen `ServiceEntry` deklariert sind, abgewiesen. Um solchen Datenverkehr zu erlauben,
würdest du einen `ServiceEntry` hinzufügen (siehe Lab 05).