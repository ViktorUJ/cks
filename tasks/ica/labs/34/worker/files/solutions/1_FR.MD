[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 34 - Solution de référence

Istio `1.29.1` (profil par défaut, mTLS PERMISSIVE, sortie `ALLOW_ANY`, aucune authz) et OPA
Gatekeeper sont préinstallés. L’espace de noms `app` (injecté) contient `frontend` ainsi que deux clients curl,
`good` (SA `good`) et `bad` (SA `bad`), et la SA `mesh-editor` ; l’espace de noms
`legacy` (non injecté) contient un client curl `legacy` sans sidecar. `istioctl` se trouve sur le
PC de travail.

## Objectif (défense en profondeur)

1. mTLS **STRICT** à l’échelle du maillage.
2. Autorisation **refus par défaut** + une autorisation ciblée pour `good`.
3. **Contrôle de la sortie** : `REGISTRY_ONLY`.
4. **RBAC sur les CRD Istio** : autoriser la configuration Istio mais interdire `EnvoyFilter`.
5. **OPA Gatekeeper** : rejeter `PeerAuthentication` avec `mode: DISABLE`.
6. **Résilience au contournement du sidecar** : NetworkPolicy comme couche L3/L4 indépendante.

## Étape 1. mTLS STRICT (à l’échelle du maillage)

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system      # root namespace -> mesh-wide
spec:
  mtls:
    mode: STRICT
EOF
```

Le client `legacy` sans sidecar (en texte clair) ne peut désormais plus atteindre `frontend` :

```bash
kubectl exec -n legacy deploy/legacy -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://frontend.app.svc.cluster.local:8080/
# connection reset / 000
```

## Étape 2. Refus par défaut + autorisation ciblée

```bash
# default-deny for the whole app namespace (empty spec)
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: app
spec: {}
EOF

# allow only the "good" identity to call frontend
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-good
  namespace: app
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/app/sa/good"]
EOF
```

```bash
kubectl exec -n app deploy/good -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 200
kubectl exec -n app deploy/bad  -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 403
```

## Étape 3. Contrôle de la sortie : REGISTRY_ONLY

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
EOF
istioctl install -f /tmp/iop.yaml -y

# external host that is not in the registry is now blocked
kubectl exec -n app deploy/good -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://www.example.com/   # 502 (blocked)
```

(Pour autoriser un hôte externe précis, vous ajouteriez un `ServiceEntry`, voir le lab 05.)

## Étape 4. RBAC sur les CRD Istio (interdire EnvoyFilter)

`EnvoyFilter` est la CRD Istio la plus dangereuse : elle injecte une configuration Envoy brute. Accordez la
gestion de la configuration Istio à `mesh-editor`, mais **excluez** `envoyfilters` :

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mesh-editor
  namespace: app
rules:
  - apiGroups: ["networking.istio.io"]
    resources: ["virtualservices","destinationrules","gateways","serviceentries","sidecars","workloadentries"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["security.istio.io"]
    resources: ["authorizationpolicies","requestauthentications"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  # envoyfilters intentionally NOT granted
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mesh-editor
  namespace: app
roleRef:
  kind: Role
  name: mesh-editor
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: mesh-editor
    namespace: app
EOF
```

```bash
kubectl auth can-i create virtualservices.networking.istio.io --as=system:serviceaccount:app:mesh-editor -n app   # yes
kubectl auth can-i create envoyfilters.networking.istio.io     --as=system:serviceaccount:app:mesh-editor -n app   # no
```

## Étape 5. OPA Gatekeeper : interdire la désactivation du mTLS

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdenymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: K8sDenyMtlsDisable
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenymtlsdisable
        violation[{"msg": msg}] {
          input.review.object.spec.mtls.mode == "DISABLE"
          msg := "PeerAuthentication with mode: DISABLE is not allowed"
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
      - apiGroups: ["security.istio.io"]
        kinds: ["PeerAuthentication"]
EOF
```

```bash
# should be DENIED
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: try-disable
  namespace: app
spec:
  mtls:
    mode: DISABLE
EOF
```

## Étape 6. NetworkPolicy (résilience au contournement du sidecar)

Le mTLS/l’authz réside dans le sidecar ; si le trafic contourne le sidecar, ils ne s’appliquent pas.
NetworkPolicy est appliquée dans le noyau par le CNI (Calico), une couche L3/L4 indépendante :

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-allow-app
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
  ingress:
    # app port 8080 only from pods in the app namespace
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: app
      ports:
        - port: 8080
          protocol: TCP
    # istio sidecar health (15021) / metrics (15090) from anywhere (kubelet, prometheus)
    - ports:
        - port: 15021
          protocol: TCP
        - port: 15090
          protocol: TCP
EOF
```

Seuls les pods de `app` peuvent atteindre `frontend` sur `8080` ; le trafic de `legacy` est abandonné avant même
qu’il n’atteigne le sidecar. Le port `15021` reste ouvert pour que la sonde de disponibilité kubelet du sidecar
Istio continue de réussir (sinon, le pod deviendrait NotReady).

## Pourquoi cela fonctionne (modèle de menace)

- **mTLS STRICT** : seul le trafic de maillage mutuellement authentifié est accepté ; le texte clair et
  les clients hors maillage sont rejetés. Chiffrement + identité de service.
- **Authz par refus par défaut** : moindre privilège : rien n’est autorisé à moins qu’une règle ALLOW explicite
  corresponde, limitant le rayon d’impact d’une charge de travail compromise.
- **Sortie REGISTRY_ONLY** : un pod compromis ne peut pas exfiltrer vers des hôtes externes arbitraires ;
  seules les destinations déclarées sont accessibles.
- **RBAC sur les CRD** : restreindre `EnvoyFilter` (et la configuration Istio en général) empêche un
  utilisateur trop privilégié de reprogrammer le plan de données.
- **OPA Gatekeeper** : transforme « ne jamais désactiver le mTLS » en règle d’admission stricte, et non en convention.
- **NetworkPolicy** : contrôle indépendant au niveau du noyau qui demeure efficace si le sidecar est
  contourné : défense en profondeur.
