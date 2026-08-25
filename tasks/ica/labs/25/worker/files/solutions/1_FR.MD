[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 25 - Solution de référence

Istio `1.29.1` + Prometheus sont installés. **Flagger** s’exécute dans `istio-system`. L’espace de noms
`test` (istio-injection) contient l’application de démonstration **podinfo** (`6.0.0`), un
**flagger-loadtester** (génère du trafic pendant l’analyse), et un `public-gateway` existe
dans `istio-system`.

## Objectif

Créez une ressource `Canary` afin que Flagger assure la **livraison progressive** : pour chaque
nouvelle image, déplacez progressivement le trafic vers le canary, vérifiez les métriques et
promouvez automatiquement (ou annulez automatiquement en cas d’échec).

## Étape 1. Créer le Canary

```bash
kubectl apply -f - <<'EOF'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 300
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: podinfo
  service:
    port: 9898
    targetPort: 9898
    gateways:
    - istio-system/public-gateway
    hosts:
    - app.example.com
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 20
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 2m -q 10 -c 2 http://podinfo-canary.test:9898/"
EOF
```

## Étape 2. Attendre que Flagger s’initialise

```bash
kubectl -n test get canary podinfo -w   # wait until STATUS = Initialized
kubectl -n test get deploy
# Flagger created: podinfo-primary, services podinfo/podinfo-canary/podinfo-primary,
# destinationrules and a virtualservice.
```

## Étape 3. Déclencher une version canary

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.1
```

Flagger détecte la nouvelle révision et lance l’analyse : il déplace 20 % → 40 % → 50 % du
trafic vers le canary, en vérifiant `request-success-rate` et `request-duration` à chaque
intervalle. Le loadtester continue d’envoyer du trafic afin que les métriques existent.

## Étape 4. Observer la promotion

```bash
kubectl -n test describe canary/podinfo
# ... Advance podinfo.test canary weight 20/40/50
# ... Copying podinfo.test template spec to podinfo-primary.test
# ... Promotion completed!

kubectl -n test get canary podinfo         # STATUS = Succeeded
kubectl -n test get deploy podinfo-primary -o jsonpath='{.spec.template.spec.containers[*].image}'
# -> ghcr.io/stefanprodan/podinfo:6.0.1
```

La promotion prend environ 2 à 3 minutes avec les paramètres ci-dessus. Exécutez `check_result` après
la mise à jour de `podinfo-primary` vers `6.0.1`.

## Annulation automatisée (facultatif)

Déclenchez une autre version et injectez des échecs pendant l’analyse :

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.2
POD=$(kubectl -n test get pod -l app=flagger-loadtester -o jsonpath='{.items[0].metadata.name}')
kubectl -n test exec -it "$POD" -- hey -z 1m -c 5 -q 10 http://podinfo-canary.test:9898/status/500
```

Lorsque les vérifications de métriques en échec atteignent le seuil, Flagger s’arrête et annule la version - le trafic
retourne vers la version primary, le canary se réduit à zéro et STATUS devient `Failed`.

## Fonctionnement

- Flagger surveille le `Deployment` cible. Lors d’un changement de spécification, il crée/met à jour un
  déploiement **canary** et déplace progressivement le trafic via les pondérations
  `VirtualService`/`DestinationRule` d’Istio.
- À chaque étape, il interroge **Prometheus** pour les métriques configurées ; si elles restent dans
  les seuils, il progresse, sinon il annule après `threshold` échecs.
- `podinfo-primary` contient toujours la version « connue comme fiable » ; le trafic en direct est servi par la
  version primary jusqu’à ce que le canary réussisse entièrement et soit promu.
- Cela transforme un canary manuel risqué (Lab 06 traffic shifting) en une version automatisée,
  contrôlée par les métriques, avec annulation intégrée - l’essence de la livraison progressive.
