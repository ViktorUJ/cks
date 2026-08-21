[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)


# Travaux pratiques : Autoscaling d'une application avec KEDA et Prometheus

## Description

Ces travaux pratiques montrent comment mettre automatiquement à l'échelle une application web dans Amazon EKS à l'aide de **KEDA** (Kubernetes Event-Driven Autoscaling), sur la base de métriques **Prometheus**. L'application exporte ses propres métriques de requêtes, Prometheus les collecte et KEDA augmente ou réduit le déploiement en fonction du nombre réel de requêtes par seconde (RPS).

Le cluster est déjà préparé avec **Karpenter** et deux NodePool dédiés :
- `monitoring` — pour la pile de supervision (Prometheus, KEDA, metrics-server)
- `default` — pour l'application de test

**Ce que vous apprendrez :**
- Comment installer l'opérateur Prometheus officiel (kube-prometheus-stack) avec Helm
- Comment affecter les charges à des nœuds dédiés à l'aide de nodeAffinity et de tolerations
- Comment publier Prometheus via LoadBalancer pour un accès rapide
- Comment collecter les métriques personnalisées de l'application avec ServiceMonitor
- Comment installer KEDA et configurer un ScaledObject à partir d'une requête Prometheus
- Comment générer une charge et observer la mise à l'échelle automatique vers le haut/bas
- Comment supprimer correctement les ressources cloud (LoadBalancer, nœuds Karpenter)

## Table des matières
- [Préparation de l'environnement](#préparation-de-lenvironnement)
  - [Démarrage des travaux pratiques](#démarrage-des-travaux-pratiques)
  - [Ressources créées](#ressources-créées)
  - [Prérequis](#prérequis)
- [Consultation des NodePool](#consultation-des-nodepool)
- [Installation de la pile de supervision](#installation-de-la-pile-de-supervision)
  - [Prometheus Operator et metrics-server](#prometheus-operator-et-metrics-server)
  - [Vérification de l'installation](#vérification-de-linstallation)
- [Déploiement de l'application](#déploiement-de-lapplication)
- [Collecte des métriques de l'application](#collecte-des-métriques-de-lapplication)
  - [Création d'un ServiceMonitor](#création-dun-servicemonitor)
  - [Vérification de la cible](#vérification-de-la-cible)
  - [Vérification des métriques dans Prometheus](#vérification-des-métriques-dans-prometheus)
- [Installation de KEDA](#installation-de-keda)
- [Configuration de l'autoscaling](#configuration-de-lautoscaling)
  - [Métriques d'application disponibles](#métriques-dapplication-disponibles)
  - [Création d'un ScaledObject](#création-dun-scaledobject)
- [Génération de charge et observation de la mise à l'échelle](#génération-de-charge-et-observation-de-la-mise-à-léchelle)
- [Nettoyage des ressources](#nettoyage-des-ressources)
- [Conclusion](#conclusion)


## Préparation de l'environnement

### Démarrage des travaux pratiques
[Démarrage de la plateforme avec docker](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)

Pour démarrer les travaux pratiques, exécutez la commande :

```bash
TASK=03 make run_eks_task
```

**Ce qui se produit lors de l'exécution de cette commande :**
- Terraform/Terragrunt déploie automatiquement toute l'infrastructure nécessaire dans AWS
- Le processus prend environ 15 à 20 minutes
- La sortie de la commande affiche des informations importantes (connexion SSH, noms des ressources)

### Ressources créées

Lors de l'exécution de la commande, l'infrastructure AWS suivante est déployée :

#### Infrastructure réseau (VPC)
- **VPC** avec le bloc CIDR `10.10.0.0/16` dans la région `eu-central-1`
- **Sous-réseaux publics** pour les ressources ayant accès à Internet (`eks-AZ-1`, `eks-AZ-2`)
- **Sous-réseaux privés** pour les nœuds EKS et RDS
- **NAT Gateway** pour le trafic Internet sortant depuis les sous-réseaux privés

#### Cluster EKS
- **EKS Control Plane** version `1.35`
- **Profil Fargate** pour les pods système (`kube-system`, `karpenter`) — attention : CoreDNS s'exécute sur Fargate
- **Karpenter** version `1.8.1` (contrôleur d'autoscaling)
- **EKS Add-ons** : coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### NodePool Karpenter préconfigurés
- **`default`** — pour les charges de l'application (consolide les nœuds vides après 30 s)
- **`monitoring`** — dédié à la pile de supervision, avec le taint `dedicated=monitoring:NoSchedule` et le label `work_type=monitoring` (consolide après 300 s)

#### Fichier de configuration principal

Tous les paramètres de l'infrastructure sont définis dans le fichier `tasks/eks/labs/03/env.hcl`. Pour modifier la configuration, éditez les paramètres correspondants dans ce fichier.

### Prérequis

Assurez-vous de disposer de :
- **AWS CLI** avec les droits d'accès appropriés
- Limites de nœuds augmentées dans la région `eu-central-1` (si nécessaire)
- Connexion SSH au nœud worker (consultez la chaîne de connexion dans la sortie de `make run_eks_task`)
- `kubectl`, `helm` et `jq` disponibles sur le nœud worker


## Consultation des NodePool

Deux NodePool sont déjà préparés. Vérifions-les :

```bash
kubectl get nodepools.karpenter.sh
```

**Résultat attendu :**
```
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s
```

- **`monitoring`** — pour Prometheus, KEDA et metrics-server
- **`default`** — pour l'application de test

Examinons plus en détail le NodePool `monitoring` :

```bash
kubectl get nodepools.karpenter.sh monitoring -o yaml
```

**Éléments clés de la spécification :**
```yaml
spec:
  template:
    metadata:
      labels:
        work_type: monitoring        # utilisé dans nodeAffinity
    spec:
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring            # seuls les pods avec une toleration appropriée seront placés ici
```

**Ce que cela signifie :** les pods de supervision doivent disposer à la fois d'une `nodeAffinity` sur `work_type=monitoring` et d'une `toleration` pour `dedicated=monitoring:NoSchedule`. Cela garantit que la pile de supervision s'exécute sur ses propres nœuds et qu'aucun élément superflu ne s'y place.


## Installation de la pile de supervision

### Prometheus Operator et metrics-server

Nous installons **kube-prometheus-stack** (l'opérateur Prometheus officiel) et **metrics-server** avec Helm. Grafana est désactivé. Tous les composants sont affectés au NodePool `monitoring` par `nodeAffinity` + `tolerations`.

> **Remarque de sécurité :** le Service Prometheus ci-dessous est publié via un LoadBalancer public **sans authentification**. Ceci est fait uniquement pour la commodité des travaux pratiques. En production, Prometheus doit être protégé (authentification / proxy OAuth2, restriction IP via Security Groups ou NetworkPolicy, Ingress avec TLS).

```bash
# Ajout des dépôts Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Création du fichier values pour Prometheus
cat <<'EOF' > prometheus-values.yaml
# ATTENTION : le LoadBalancer de Prometheus est ouvert sans authentification.
# Ceci est réservé aux travaux pratiques. En production, protégez Prometheus
# avec une authentification, une restriction IP (Security Groups / NetworkPolicy) et TLS.

grafana:
  enabled: false

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

prometheus:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    loadBalancerSourceRanges:
      - "0.0.0.0/0"
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelector: {}
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

prometheusOperator:
  admissionWebhooks:
    patch:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: work_type
                    operator: In
                    values:
                      - monitoring
      tolerations:
        - key: dedicated
          value: monitoring
          effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

alertmanager:
  alertmanagerSpec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

kube-state-metrics:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

prometheus-node-exporter:
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule
EOF

# Création du fichier values pour metrics-server
cat <<'EOF' > metrics-server-values.yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule
EOF

# Installation de Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# Installation de metrics-server
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

**Explications sur les values :**
- `serviceMonitorSelectorNilUsesHelmValues: false` + les sélecteurs vides permettent à Prometheus de récupérer les ServiceMonitor de **tous** les namespaces (nécessaire pour collecter ultérieurement les métriques de l'application).
- Chaque composant déclare une `nodeAffinity` (`work_type=monitoring`) et est donc planifié **uniquement** sur les nœuds de supervision. Un simple `nodeSelector` ne suffit pas — l'affinity garantit le placement.
- `node-exporter` reçoit seulement une toleration (il doit s'exécuter sur chaque nœud comme DaemonSet).

### Vérification de l'installation

```bash
# Tous les pods de supervision doivent être Running sur les nœuds de supervision
kubectl get pods -n monitoring -o wide

# Les nœuds de supervision doivent démarrer
kubectl get nodes -l work_type=monitoring

# metrics-server doit fonctionner
kubectl top nodes

# Obtention de l'adresse du LoadBalancer Prometheus (UI Prometheus sur le port 9090)
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo
```

Ouvrez `http://<LB-ADDRESS>:9090` dans le navigateur pour accéder à l'interface Prometheus.


## Déploiement de l'application

Déployez l'application de test (`ping_pong`). Le Service publie deux ports : `http` (80 → 8080) et `metrics` (9090 → 9090).

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

Vérifiez que l'application a démarré :

```bash
kubectl get po -n team-19
```

**Résultat attendu :**
```
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s
```

Vérifiez le NodeClaim — il doit y avoir un nœud distinct pour la supervision et un autre pour l'application :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat attendu :**
```
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m
```


## Collecte des métriques de l'application

### Création d'un ServiceMonitor

L'application exporte les métriques Prometheus sur le port `9090` au chemin `/metrics`. Le port `metrics` est déjà défini dans le Service de l'application ; seul un ServiceMonitor est donc nécessaire. Le label `release: prometheus` permet à Prometheus Operator de le récupérer.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: team19
  namespace: team-19
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: team19
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
EOF
```

### Vérification de la cible

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# La cible doit être présente et saine (health: up)
curl -s "http://${PROM_URL}:9090/api/v1/targets" \
  | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

### Vérification des métriques dans Prometheus

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Vérification de la métrique requests_total
curl -s "http://${PROM_URL}:9090/api/v1/query" \
  --data-urlencode 'query=requests_total{namespace="team-19"}' | jq '.data.result'
```

Si le résultat est vide `[]`, cela signifie que le ServiceMonitor n'a pas encore été récupéré. Attendez un peu et réessayez, ou vérifiez l'état de santé de la cible ci-dessus.

Vous pouvez également ouvrir `http://<PROM_URL>:9090` dans le navigateur et saisir `requests_total` dans le champ Expression.

> **Conseil :** la valeur de la métrique est renvoyée sous la forme `"value": [<timestamp>, "<valeur>"]`. Le premier nombre est l'heure du scrape, le second (une chaîne) est la valeur elle-même. Elle sera à `0` tant qu'aucun trafic n'atteint l'application.


## Installation de KEDA

KEDA s'exécute sur les mêmes nœuds que Prometheus (NodePool `monitoring`). Le chart Helm KEDA applique les `tolerations` et l'`affinity` de niveau supérieur à **tous** ses composants (operator, metrics apiserver, webhooks).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

cat <<'EOF' > keda-values.yaml
# tolerations et affinity globales pour tous les composants KEDA
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
EOF

helm install keda kedacore/keda \
  --namespace monitoring \
  -f keda-values.yaml
```

### Vérification de KEDA

```bash
# Les pods KEDA doivent être Running sur les nœuds de supervision
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# Les CRD KEDA doivent être installés
kubectl get crd | grep keda
```

> **Remarque :** le `metrics-apiserver` de KEDA est un composant interne de KEDA (il fournit des métriques externes au Kubernetes HPA). Ce n'est **pas** la même chose que le `metrics-server` du cluster, installé précédemment — les deux sont nécessaires.


## Configuration de l'autoscaling

### Métriques d'application disponibles

L'application `ping_pong` exporte les métriques Prometheus suivantes (port 9090, chemin `/metrics`) :

| Métrique | Type | Description |
|---------|-----|----------|
| `requests_total` | Counter | Nombre total de requêtes |
| `requests_per_second` | Gauge | RPS instantané (bruyant, ne retombe pas à 0 au repos) |
| `requests_per_minute` | Gauge | RPM instantané |
| `goroutines` | Gauge | Nombre actuel de goroutines |

Pour le scaling, nous utilisons **`rate(requests_total[1m])`**, et non le gauge brut `requests_per_second`. Le `rate()` basé sur un compteur fournit un véritable RPS lissé, qui croît linéairement avec la charge et retombe honnêtement à 0 lorsque le trafic s'arrête — le seuil est ainsi facile à choisir.

### Création d'un ScaledObject

Règle : réplicas = `ceil(sum(rate(requests_total[1m])) / threshold)`. Une réduction rapide est configurée par `behavior`, afin que les pods soient supprimés rapidement après la baisse de charge.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: team19-scaledobject
  namespace: team-19
spec:
  scaleTargetRef:
    name: team19
  minReplicaCount: 1
  maxReplicaCount: 10
  pollingInterval: 10
  cooldownPeriod: 10
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          # Réduction rapide : fenêtre de stabilisation de 10 s, jusqu'à 100 % des pods peuvent être supprimés
          stabilizationWindowSeconds: 10
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
      # rate(requests_total[1m]) -> véritable RPS issu du compteur ; somme sur tous les pods.
      # réplicas = ceil(sum(rate) / threshold)
      query: sum(rate(requests_total{namespace="team-19", service="team19"}[1m]))
      threshold: "10"
      activationThreshold: "3"
EOF
```

**Explications :**
- `threshold` — RPS cible **par pod** que le HPA tente de maintenir.
- `activationThreshold: 3` signifie que KEDA maintient une réplique tant que le RPS total ne dépasse pas 3, ce qui évite les oscillations au repos.
- La `query` utilise `sum(...)` (RPS total, indépendant du nombre de réplicas), ce qui stabilise le nombre de réplicas souhaité. L'utilisation de `avg(...)` entraînerait ici une oscillation à l'ajout de pods.

Vérifiez le ScaledObject et le HPA qu'il a créé :

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```


## Génération de charge et observation de la mise à l'échelle

Lancez un pod qui génère de la charge sur le Service de l'application. La boucle interne envoie N requêtes ; le `sleep 1` externe définit le rythme — le nombre dans `seq 1 N` correspond donc approximativement au RPS cible.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: traffic-generator
  namespace: team-19
spec:
  containers:
  - name: loader
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Starting traffic generation..."
      while true; do
        for i in $(seq 1 50); do
          wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        done
        sleep 1
      done
EOF
```

### Observation de la mise à l'échelle

Une seule commande `watch` affiche immédiatement les pods, le HPA et le RPS par pod depuis Prometheus. La requête PromQL est encodée dans l'URL (`--data-urlencode`), sinon les symboles `{`, `}` et `=` cassent le parseur.

```bash
export PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

watch 'kubectl get pods -n team-19 ; echo ; kubectl get hpa -n team-19 ; echo ; echo -n "rps per pod = " ; curl -s "http://${PROM_URL}:9090/api/v1/query" --data-urlencode "query=sum(rate(requests_total{namespace=\"team-19\", service=\"team19\"}[1m])) / count(up{namespace=\"team-19\", service=\"team19\"})" | jq -r ".data.result[0].value[1]"'
```

**Ce que vous devriez voir :** à mesure que la charge augmente, le nombre de pods tend vers `ceil(rps_total / threshold)`. La colonne HPA `TARGETS` (RPS par pod) correspond à `rps per pod`, affiché par watch.

> **Conseil de réglage :** pods ≈ (nombre dans `seq 1 N`) / threshold. Avec `seq 1 50` et `threshold: 10`, vous obtiendrez environ 5 pods. Augmentez le nombre pour obtenir davantage de pods.

### Arrêt de la charge

```bash
kubectl delete pod traffic-generator -n team-19
```

Après l'arrêt du trafic, `rate(requests_total[1m])` retombe à 0. Pendant le `cooldownPeriod` (10 s), plus la fenêtre de stabilisation de réduction (10 s), KEDA ramène le scaling à `minReplicaCount: 1`.


## Nettoyage des ressources

### Suppression de l'application

```bash
# Suppression du ScaledObject (KEDA cessera de gérer le HPA)
kubectl delete scaledobject team19-scaledobject -n team-19

# Suppression du générateur de trafic (s'il est encore en cours d'exécution)
kubectl delete pod traffic-generator -n team-19 --ignore-not-found

# Suppression du ServiceMonitor
kubectl delete servicemonitor team19 -n team-19 --ignore-not-found

# Suppression de l'application elle-même (deployment, service, namespace)
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

### Suppression de Prometheus (important : supprime le LoadBalancer)

La suppression de la release Helm supprime le Service de type LoadBalancer, et AWS libère l'ELB.

```bash
# Suppression de prometheus (cela supprimera le Service LoadBalancer -> AWS ELB)
helm uninstall prometheus -n monitoring

# Suppression de metrics-server et keda
helm uninstall metrics-server -n monitoring
helm uninstall keda -n monitoring
```

Vérifiez que le LoadBalancer (ELB) a bien été supprimé :

```bash
# Le Service prometheus ne doit pas exister
kubectl get svc -n monitoring | grep prometheus

# Confirmation dans AWS que l'ELB a été supprimé
aws elb describe-load-balancers --region eu-central-1 \
  --query "LoadBalancerDescriptions[].DNSName"
```

Si le Service est resté pour une raison quelconque et bloque la suppression de l'ELB, supprimez-le manuellement :

```bash
kubectl delete svc prometheus-kube-prometheus-prometheus -n monitoring --ignore-not-found
```

Supprimez ensuite le namespace :

```bash
kubectl delete namespace monitoring
```

> **Important :** supprimez toujours le Service de type LoadBalancer **avant** de supprimer les nœuds ou le cluster.
> Si vous supprimez d'abord les nœuds/le cluster, AWS ELB peut rester « suspendu » en tant que ressource orpheline,
> et vous devrez le supprimer manuellement via la console ou la CLI.

### Vérification que Karpenter a supprimé tous les nœuds

Après la suppression de toutes les charges, les nœuds `default` et `monitoring` deviennent vides et Karpenter doit les consolider (les supprimer).

```bash
# Observation de la diminution du nombre de nodeclaims jusqu'à zéro
watch kubectl get nodeclaims.karpenter.sh
```

Karpenter supprime les nœuds vides conformément au `consolidateAfter` de chaque NodePool
(`default` = 30 s, `monitoring` = 300 s), les nœuds de supervision sont donc supprimés plus tard.

Attendez que les deux commandes renvoient un résultat vide :

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type
```

Si un nœud n'est pas supprimé, vérifiez les pods empêchant la consolidation (par exemple, des pods sans contrôleur ou avec `karpenter.sh/do-not-disrupt`) :

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<имя-ноды>
```

### Suppression de l'infrastructure

Uniquement après que Karpenter a supprimé tous les nœuds, supprimez l'infrastructure des travaux pratiques :

```bash
TASK=03 make delete_eks_task
```

Saisissez `y` pour confirmer. La suppression prend environ 10 à 15 minutes.

> La suppression de l'infrastructure avant que Karpenter ne supprime ses nœuds peut laisser des instances EC2 orphelines.


## Conclusion

Félicitations ! Vous avez construit un système d'autoscaling event-driven sur EKS.

**Ce que vous avez fait :**

1. **Pile de supervision** — installation de l'opérateur Prometheus officiel et de metrics-server, affectés à des nœuds dédiés via nodeAffinity et tolerations
2. **Publication** — publication de Prometheus via LoadBalancer pour un accès rapide (uniquement pour les travaux pratiques, sans authentification)
3. **Métriques personnalisées** — collecte des propres métriques de requêtes de l'application avec ServiceMonitor
4. **KEDA** — installation de KEDA et configuration d'un ScaledObject à partir d'une requête Prometheus
5. **Autoscaling** — mise à l'échelle de l'application selon le RPS réel via `rate(requests_total[1m])` avec une réduction rapide
6. **Nettoyage** — suppression correcte du LoadBalancer et possibilité donnée à Karpenter de libérer les nœuds avant la suppression de l'infrastructure

**Points clés :**

- Utilisez `rate()` basé sur un compteur pour un autoscaling stable et prévisible plutôt que des gauges instantanés bruyants
- Utilisez `sum(...)` (et non `avg(...)`) dans la requête du scaler afin que le nombre de réplicas souhaité n'oscille pas à l'ajout de pods
- Affectez les charges d'infrastructure à des nœuds dédiés avec nodeAffinity **et** tolerations
- Supprimez toujours le Service de type LoadBalancer avant de supprimer le cluster pour éviter les ELB orphelins

**Ressources supplémentaires :**
- [Documentation KEDA](https://keda.sh/docs/)
- [Scaler Prometheus dans KEDA](https://keda.sh/docs/latest/scalers/prometheus/)
- [Chart kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Documentation Karpenter](https://karpenter.sh/docs/)
