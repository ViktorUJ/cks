[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 124 - solution de référence (HPA, KEDA, Prometheus)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl et helm sont déjà
configurés (le kubeconfig est assemblé via `aws eks update-kubeconfig` au démarrage de la
machine).

## Tâche 1. Namespace `eks-124`

```bash
kubectl create namespace eks-124
```

## Tâche 2. kube-prometheus-stack dans le namespace `monitoring`

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi
```

Ces trois flags ne sont pas cosmétiques. La lab n'a pas besoin de Grafana ni d'Alertmanager,
et Grafana est le pod le plus lourd du chart (environ 325 MiB sur le banc de test). Les
`requests` explicites font passer Prometheus de `BestEffort` à `Burstable` : le scheduler et
Karpenter, qui dimensionne le nœud selon la somme des `requests`, voient tous les deux ses
besoins. Sans cela, la stack de monitoring atterrit sur l'instance la moins chère, et
kubelet évince Prometheus sous pression mémoire - voir le détail dans le README de la lab.

Attendons que les pods soient prêts :

```bash
kubectl get pods -n monitoring -w
```

Attendez que tous les pods passent en `Running` et `1/1` (ou `2/2`) Ready - cela prend
généralement 2-3 minutes. Vérifions le Service que KEDA va surveiller, et la classe QoS du
pod :

```bash
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
kubectl get pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 \
  -o jsonpath='{.status.qosClass}{"\n"}'
```

La sortie attendue de la deuxième commande est `Burstable`.

## Tâche 3. KEDA dans le namespace `keda`

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda --namespace keda --create-namespace
```

Vérifions que l'operator et le metrics apiserver sont opérationnels :

```bash
kubectl get pods -n keda
```

Résultat attendu : des pods nommés comme `keda-operator-...` et
`keda-operator-metrics-apiserver-...` en état `Running`.

## Tâche 4. Deployment `demo-app`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: eks-124
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/demo-app -n eks-124
```

## Tâche 5. ScaledObject avec le scaler `prometheus`

La métrique cAdvisor `container_cpu_usage_seconds_total` est collectée par
kube-prometheus-stack sur chaque pod dès l'installation, sans ServiceMonitor nécessaire.
Nous calculons l'usage CPU total des pods du GÉNÉRATEUR de charge de la tâche 6, pas de
`demo-app` lui-même : l'application scale en fonction de la charge de quelqu'un d'autre, et
un HPA classique basé sur le CPU ne peut pas faire ça - les métriques externes existent
précisément pour ça.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: demo-app
  namespace: eks-124
spec:
  scaleTargetRef:
    name: demo-app
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
      query: sum(rate(container_cpu_usage_seconds_total{namespace="eks-124", pod=~"stress-generator.*"}[1m]))
      threshold: "0.1"
EOF
```

On peut vérifier que la requête renvoie effectivement quelque chose directement depuis le
cluster (tant qu'il n'y a pas encore de générateur, la réponse sera vide, et c'est normal -
dans ce cas KEDA remonte zéro au HPA) :

```bash
kubectl run promq --rm -i --restart=Never -n default --image=curlimages/curl -- \
  -sG --data-urlencode \
  'query=sum(rate(container_cpu_usage_seconds_total{namespace="eks-124",pod=~"stress-generator.*"}[1m]))' \
  http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/query
```

Vérifions que KEDA a pris le ScaledObject en charge et créé le HPA :

```bash
kubectl get scaledobject demo-app -n eks-124
kubectl get hpa -A | grep keda-hpa
kubectl get hpa keda-hpa-demo-app -n eks-124
```

Le HPA s'appelle `keda-hpa-demo-app` - c'est la preuve que KEDA ne remplace pas HPA, il crée
et gère un `HorizontalPodAutoscaler` classique sous le capot.

## Tâche 6. Test de charge : montée en échelle

D'abord, enregistrons l'état avant la charge :

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_before.txt
cat /var/work/tests/artifacts/6/hpa_before.txt
```

Créons le générateur de charge. Il a son propre label (`app=stress-generator`) - la requête
PromQL de la tâche 5 sélectionne les pods par NOM, pas par label, donc mélanger le générateur
dans le selector de `demo-app` est inutile et nuisible : deux Deployment avec des selectors
qui se chevauchent est un anti-pattern. `limits.cpu` est obligatoire, sinon les quatre
workers CPU privent kubelet de CPU et le nœud passe en `NotReady`. `nodeSelector` est
nécessaire car `polinux/stress` n'est construit que pour `amd64`, alors que le NodePool de
cette lab autorise aussi `arm64` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-generator
  namespace: eks-124
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stress-generator
  template:
    metadata:
      labels:
        app: stress-generator
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--cpu", "2"]
        resources:
          requests:
            cpu: "200m"
          limits:
            cpu: "500m"
EOF
```

Observons la métrique et le nombre de réplicas croître :

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

Attendez 1-2 minutes (KEDA interroge Prometheus, HPA calcule les réplicas, Karpenter ajoute
un nœud si nécessaire). Sur le banc de test, cela ressemblait à ceci :

```
06:36:41 replicas=1 0/100m (avg)
06:37:04 replicas=1 1251m/100m (avg)
06:37:26 replicas=4 382m/100m (avg)
```

Dès que `REPLICAS` devient supérieur à `1`, sauvegardez :

```bash
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_after.txt
cat /var/work/tests/artifacts/6/hpa_after.txt
```

## Tâche 7. Retrait de la charge : descente en échelle

```bash
kubectl delete deployment stress-generator -n eks-124
```

Les pods du générateur disparaissent, leurs séries n'existent plus dans Prometheus, KEDA
remonte zéro au HPA. La valeur `TARGETS` retombe à zéro en environ 30 secondes, mais le
nombre de réplicas se maintient : `stabilizationWindowSeconds` pour le scaleDown sur HPA
vaut 300 secondes par défaut. Une mesure du banc de test - métrique à zéro à 06:40:07,
réplicas `5 -> 2 -> 1` à 06:44:40 et 06:45:07 :

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

Dès que `REPLICAS` revient à `1`, sauvegardez l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/7/hpa_after_cooldown.txt
cat /var/work/tests/artifacts/7/hpa_after_cooldown.txt
```

## Tâche 8. Un HPA classique face à un HPA créé par KEDA

```bash
kubectl get hpa -A
```

Dans la sortie, le HPA `keda-hpa-demo-app` ressemble colonne par colonne à un HPA classique -
mêmes `TARGETS`, `MINPODS`, `MAXPODS`, `REPLICAS`. La seule différence est le nom (préfixe
`keda-hpa-`) et qui le contrôle : un ingénieur crée et modifie un HPA classique directement
via un manifest `HorizontalPodAutoscaler`, tandis que `keda-hpa-demo-app` est créé et
contrôlé - en russe, `управляется` - par l'operator KEDA à partir de la ressource
`ScaledObject` - supprimez le `ScaledObject`, et KEDA supprime ce HPA avec lui.

Sauvegardons l'explication dans l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/hpa_compare.txt <<'EOF'
Dans kubectl get hpa -A, un HPA classique et le HPA keda-hpa-demo-app se ressemblent
colonne par colonne : TARGETS/MINPODS/MAXPODS/REPLICAS - la seule différence est le nom et
l'origine de l'objet.

KEDA ne remplace pas HPA : l'operator KEDA surveille le ScaledObject et crée et управляет
(contrôle) lui-même un HorizontalPodAutoscaler classique nommé keda-hpa-<nom du
ScaledObject>, tandis que le metrics adapter de KEDA lui fournit la valeur de la métrique
via external.metrics.k8s.io. Les réplicas sont toujours calculés par le même mécanisme HPA
que d'habitude.
EOF
cat /var/work/tests/artifacts/8/hpa_compare.txt
```

## Vérification rapide

```bash
check_result
```
