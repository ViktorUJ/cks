[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 15 - Solution de référence

Version d'Istio utilisée : `1.29.1` (`istioctl` est préinstallé sur le PC worker).

## Objectif

Installer Istio avec une configuration **personnalisée** à l'aide d'un manifeste `IstioOperator` :
- partir du profil `default` ;
- définir deux options `meshConfig` :
  - `accessLogFile: /dev/stdout` (journaux d'accès Envoy vers stdout),
  - `outboundTrafficPolicy.mode: REGISTRY_ONLY` (bloquer les sorties vers des hôtes inconnus) ;
- ajouter un **second** composant de passerelle d'entrée `ingressgateway-internal` en plus de la
  passerelle `istio-ingressgateway` par défaut.

## Étape 1. Écrire le manifeste IstioOperator

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

## Étape 2. Installer Istio avec le manifeste personnalisé

```bash
istioctl install -f custom-istio.yaml -y
```

## Étape 3. Vérifier l'installation

```bash
# control plane
kubectl get pods -n istio-system

# both ingress gateways
kubectl get deploy -n istio-system | grep -E 'ingressgateway'

# meshConfig landed in the istio configmap
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy|REGISTRY_ONLY'
```

Résultat attendu :
- `istiod` est `Running` ;
- les déploiements `istio-ingressgateway` et `ingressgateway-internal` sont tous deux prêts ;
- la configmap `istio` contient `accessLogFile: /dev/stdout` et
  `outboundTrafficPolicy.mode: REGISTRY_ONLY`.

## (facultatif) Étape 4. Voir REGISTRY_ONLY en action

```bash
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
kubectl -n demo run curl --image=curlimages/curl -it --rm --restart=Never -- \
  sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://httpbin.org/get'
# -> 502 : egress is blocked because the host is not in the mesh registry
```

Avec `outboundTrafficPolicy: REGISTRY_ONLY`, les appels vers des hôtes externes qui ne sont pas
déclarés via un `ServiceEntry` sont rejetés. Pour autoriser ce trafic, vous ajouteriez un
`ServiceEntry` (voir le Lab 05).