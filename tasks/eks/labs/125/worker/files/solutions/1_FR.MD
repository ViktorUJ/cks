[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 125 - solution de référence (EKS Auto Mode contre votre propre stack)

Toutes les commandes s'exécutent sur la machine de travail (worker) via SSH. kubectl est
déjà configuré pour le cluster. Le cluster a été créé avec Auto Mode activé et un seul
NodePool intégré `general-purpose` - il n'y a ni profil Fargate, ni add-ons managés, ni
Karpenter dans ce lab.

Nous récupérons le nom du cluster depuis le kubeconfig : `list-clusters[0]` renverrait le
premier cluster du compte, qui n'est pas forcément le nôtre.

```bash
export CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
echo "$CLUSTER"
```

## Tâche 1. Confirmation du mode : Auto Mode est activé

```bash
mkdir -p /var/work/tests/artifacts/1
{
  echo "=== aws eks describe-cluster computeConfig ==="
  aws eks describe-cluster --name "$CLUSTER" --query 'cluster.computeConfig'
  echo
  echo "=== kubectl get nodepools ==="
  kubectl get nodepools
} > /var/work/tests/artifacts/1/automode.txt
cat /var/work/tests/artifacts/1/automode.txt
```

`computeConfig.enabled` doit être `true`, et `nodePools` doit contenir `general-purpose`.
`kubectl get nodepools` montre le même NodePool comme une ressource Kubernetes normale -
Auto Mode matérialise les pools intégrés activés via l'API Kubernetes (chapitre 9).

## Tâche 2. Le second NodePool intégré est désactivé

```bash
kubectl get nodepools
```

`system` n'est pas dans la liste - un NodePool intégré apparaît comme ressource du cluster
uniquement quand son nom figure dans `computeConfig.nodePools` ; dans ce lab seul
`general-purpose` y est listé.

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/twopools.txt <<'EOF'
EKS Auto Mode a deux NodePool intégrés : general-purpose et system. Le NodePool system
porte le taint CriticalAddonsOnly, toléré par des composants critiques pour le cluster (par
exemple CoreDNS) - c'est un moyen de les séparer de la charge normale afin qu'ils ne
concurrencent pas les applications pour les ressources et ne soient pas évincés lors de la
consolidation des nœuds de general-purpose.

Dans ce lab, node_pools ne contient que general-purpose, donc system n'est pas créé comme
ressource du cluster : kubectl get nodepools ne le montre pas. L'activer signifie éditer
computeConfig.nodePools sur le control plane, pas créer un objet avec kubectl.
EOF
cat /var/work/tests/artifacts/2/twopools.txt
```

## Tâche 3. Charge de travail sur general-purpose et tentative de réparer le NodePool intégré

```bash
kubectl create namespace eks-125
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-125
kubectl rollout status deployment/web -n eks-125

kubectl get pods -n eks-125 -o wide
```

Les deux réplicas atteignent `Running` sur un nœud qu'Auto Mode a lui-même levé sous
`general-purpose` - sans profil Fargate ni Karpenter externe, qui eux sont nécessaires dans
la base du lab 101.

Nous essayons d'éditer le NodePool intégré. AWS documente les NodePool intégrés comme
« enabled or disabled but not modified », mais il faut vérifier de ses propres mains - il
n'y a pas d'interdiction au niveau de l'admission :

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "=== kubectl patch du pool intégré ==="
  kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":{"cpu":"100"}}}'
  echo "limits après l'édition : $(kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}')"
  echo
  echo "=== qui possède l'objet ==="
  kubectl get nodepool general-purpose -o jsonpath='labels={.metadata.labels}{"\n"}'
  kubectl get nodepool general-purpose \
    -o jsonpath='managedFields managers={range .metadata.managedFields[*]}{.manager}{","}{end}{"\n"}'
  echo
  echo "=== conclusion ==="
  echo "L'édition est acceptée : la commande a renvoyé patched, la valeur est restée dans"
  echo "l'objet. Mais l'objet appartient au service : label"
  echo "app.kubernetes.io/managed-by=eks, champs possédés par le manager eks-auto-mode."
  echo "Il n'existe qu'une seule méthode de gestion prise en charge - activer et désactiver"
  echo "le nom du pool dans computeConfig.nodePools. Changer cette liste supprime la"
  echo "ressource avec ses nœuds et la recrée depuis zéro, sans nos modifications."
} > /var/work/tests/artifacts/3/builtin.txt
cat /var/work/tests/artifacts/3/builtin.txt
```

Nous remettons le pool dans son état initial - nous n'avons pas besoin d'un `limits`
superflu sur un objet qui n'est pas le nôtre :

```bash
kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":null}}'
kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}{"\n"}'
```

Attention : `kubectl delete nodepool general-purpose` passe aussi, mais EKS NE recrée PAS
l'objet, alors que les nœuds du pool se drainent - le cluster reste sans compute. La
récupération ne passe que par `computeConfig` (recette dans la section « Suppression » du
README).

## Tâche 4. Aucun accès au nœud : SSH et SSM fermés par conception

En Auto Mode, le nom du nœud est l'instance ID lui-même, pas besoin d'analyser
`providerID` séparément :

```bash
NODE=$(kubectl get pods -n eks-125 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node=$NODE"
```

Nous réunissons trois preuves. Première - l'instance n'a pas de paire de clés (`KeyName`),
donc le SSH par clé est impossible, que quelqu'un écoute ou non sur le port 22 :

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "=== paire de clés et image du nœud ==="
  aws ec2 describe-instances --instance-ids "$NODE" \
    --query 'Reservations[0].Instances[0].[KeyName,ImageId,PlatformDetails]' --output text
  echo "KeyName est vide (None) - le nœud n'a pas de paire de clés"
  echo
  echo "=== SSM : pas de connexion ==="
  aws ssm get-connection-status --target "$NODE" --output json
  echo "inventaire SSM (le nœud ne devrait pas y être) :"
  aws ssm describe-instance-information \
    --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
} > /var/work/tests/artifacts/4/nossh.txt
```

N'utilisez pas `aws ssm start-session` ici : la machine de travail n'a pas le droit
`ssm:StartSession`, donc la commande renvoie `AccessDeniedException` - c'est un fait sur la
politique du worker, pas sur le nœud. La réponse à la question de la tâche vient de
`get-connection-status` avec le statut `notconnected`.

La troisième preuve va dans l'autre sens : l'hôte n'est pas isolé du cluster. Un pod
privilégié avec un `hostPath` sur `/` lit le système de fichiers du nœud :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostprobe
  namespace: eks-125
spec:
  nodeName: $NODE
  restartPolicy: Never
  containers:
  - name: p
    image: busybox
    command: ["sh","-c","cat /host/etc/os-release; echo ---; ls /host/bin | head -5"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: h
      mountPath: /host
  volumes:
  - name: h
    hostPath:
      path: /
EOF

kubectl wait --for=condition=Ready pod/hostprobe -n eks-125 --timeout=90s 2>/dev/null
sleep 5
{
  echo
  echo "=== l'hôte vu depuis un pod privilégié ==="
  kubectl logs hostprobe -n eks-125
  echo
  echo "=== conclusion ==="
  echo "Le SSH est impossible (pas de paire de clés KeyName), SSM n'est pas connecté"
  echo "(notconnected) - il n'y a pas d'accès opérateur au nœud. Mais l'image Bottlerocket"
  echo "peut être lue depuis un pod privilégié : Auto Mode ferme la porte de l'opérateur,"
  echo "pas la porte cluster-admin. C'est Pod Security Admission et les politiques"
  echo "d'admission qui s'en occupent (chapitres 19 et 22)."
} >> /var/work/tests/artifacts/4/nossh.txt

kubectl delete pod hostprobe -n eks-125
cat /var/work/tests/artifacts/4/nossh.txt
```

Les nœuds Auto Mode sont des Bottlerocket avec une racine en lecture seule et SELinux en
mode enforcing, sans shell ni gestionnaire de paquets, avec une durée de vie maximale de
21 jours et un remplacement automatique (chapitre 9). Les déboguer avec les outils SSH et
SSM habituels est fondamentalement impossible - c'est le prix d'une exploitation minimale.

## Tâche 5. Votre propre NodePool avec des limits explicites

Les pools intégrés n'ont pas de `limits` - avec une demande illimitée, ils croîtraient sans
plafond (chapitre 9, section 9.7). Votre propre NodePool référence le `NodeClass` intégré
`default` et définit les limites lui-même :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: custom-limited
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: ["c", "m", "r"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
  limits:
    cpu: "10"
    memory: 10Gi
EOF

kubectl get nodepool custom-limited
```

Vos propres NodePool n'héritent pas des restrictions des pools intégrés (uniquement C/M/R,
uniquement on-demand, génération 5+) - vous les définissez vous-même, y compris `limits`,
sinon le pool croît sans plafond (chapitre 9, section 9.7).

## Vérification rapide

```bash
check_result
```
