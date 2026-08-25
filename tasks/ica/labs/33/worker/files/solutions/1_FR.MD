[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 33 - Solution de référence

Istio `1.29.1` (profil par défaut, découverte à l’échelle du cluster, sans périmètre Sidecar) et OPA
Gatekeeper sont préinstallés. Trois espaces de noms existent :

- `app` (injecté, `mesh=enabled`) - `frontend`;
- `shop` (injecté, `mesh=enabled`) - `catalog` + un `probe` sans sidecar ;
- `legacy` (NON injecté, sans étiquette `mesh`) - `legacy-app`.

`istioctl` est disponible sur le PC de travail.

## Objectif

1. Activer les **sélecteurs de découverte** afin que istiod ne suive que les espaces de noms `mesh=enabled`
   (exclut `legacy`).
2. Ajouter un périmètre de sortie **Sidecar** dans `app` afin que ses proxys ne connaissent que `app` + `istio-system`
   (exclut `shop`).
3. Observer les **signaux clés** d’istiod.
4. Appliquer une politique de déploiement avec **OPA Gatekeeper**.

## Étape 1. Sélecteurs de découverte

Réappliquez l’installation avec `meshConfig.discoverySelectors` correspondant à `mesh=enabled`
(`istio-system`, `app`, `shop` portent cette étiquette ; `legacy` ne la porte pas) :

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

Vérifiez que `legacy` disparaît du mesh (depuis un proxy qui n’a pas encore de périmètre Sidecar) :

```bash
istioctl proxy-config clusters deploy/catalog.shop | grep legacy-app || echo "legacy dropped"
```

## Étape 2. Périmètre de sortie Sidecar dans app

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

`./*` = l’espace de noms du proxy lui-même (`app`), plus `istio-system/*` pour le plan de contrôle et
les gateways. Tout le reste (y compris `shop`) est supprimé des proxys `app` :

```bash
istioctl proxy-config clusters deploy/frontend.app | grep catalog.shop || echo "shop dropped from app"
```

## Étape 3. Signaux clés d’istiod

```bash
# convergence time + push count (the key control-plane signals)
kubectl exec -n shop deploy/probe -c probe -- \
  curl -s http://istiod.istio-system:15014/metrics \
  | grep -E 'pilot_proxy_convergence_time|pilot_xds_pushes'

# how many proxies are connected / config sync state
istioctl proxy-status
```

`pilot_proxy_convergence_time` est le signal principal : il indique combien de temps met une modification à atteindre les
proxys. `pilot_xds_pushes` compte les envois. Une augmentation du temps de convergence ou des erreurs d’envoi signifie que
le plan de contrôle est sous pression ; les leviers de périmètre des étapes 1-2 sont ceux qui le réduisent.

## Étape 4. Politique de déploiement OPA Gatekeeper

Exigez que chaque espace de noms déclare l’étiquette d’injection (une politique classique d’hygiène de déploiement
issue du chapitre). Créez le modèle et la contrainte :

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

Vérifiez que la politique est appliquée (elle doit être **refusée**) :

```bash
kubectl create ns test-no-label
# Error ... admission webhook "validation.gatekeeper.sh" denied the request:
# namespace is missing required labels: {"istio-injection"}
```

## Pourquoi cela fonctionne

- Les **sélecteurs de découverte** limitent les espaces de noms qu’istiod surveille. Les espaces de noms sans
  l’étiquette du sélecteur sont invisibles pour le plan de contrôle ; leurs services ne deviennent jamais des
  clusters/endpoints sur aucun proxy, ce qui réduit la taille de la configuration et le travail d’envoi. Le gain le plus important survient lorsqu’une
  partie du cluster n’est pas dans le mesh.
- Le **périmètre de sortie Sidecar** limite, par espace de noms, les services dont un proxy est informé.
  Avec `./*` + `istio-system/*`, un proxy `app` ne contient plus la configuration de `shop` (ni celle du
  reste du mesh). Cela réduit la configuration de chaque proxy et la diffusion des envois depuis istiod.
- Les **signaux clés** (`pilot_proxy_convergence_time`, `pilot_xds_pushes`, proxys connectés,
  CPU/mem d’istiod) permettent de voir si le plan de contrôle suit le rythme ; les leviers de périmètre sont les
  principaux outils pour réduire le temps de convergence.
- **OPA Gatekeeper** transforme les bonnes pratiques en règles d’admission : les ressources non conformes sont
  rejetées lors de leur création, et non simplement déconseillées.
