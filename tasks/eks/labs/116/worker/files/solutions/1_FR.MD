[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 116 - solution de référence (IMDSv2 hop limit, Pod Security Admission, endpoint privé)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà
configuré pour le cluster (le kubeconfig a été généré via `aws eks update-kubeconfig` au
démarrage de la machine).

## Tâche 1. Namespace `eks-116`

```bash
kubectl create namespace eks-116
```

## Tâche 2. Symptôme : IMDS inaccessible depuis le pod

Le NodePool `hardened` (le seul dans cette lab) définit `httpPutResponseHopLimit=1` sur
tous ses nodes via `metadataOptions` de l'EC2NodeClass. Un paquet issu d'un processus sur
l'hôte atteint IMDS en un seul hop, tandis qu'un paquet venant d'un pod fait un hop
supplémentaire (le network namespace du conteneur) - et dépasse la limite. On crée un
Deployment avec un conteneur endormi pour pouvoir y entrer via exec :

```bash
kubectl create deployment probe --image=curlimages/curl:latest -n eks-116 \
  -- sleep 3600
kubectl rollout status deployment/probe -n eks-116
```

Requête IMDSv2 depuis le pod (d'abord le token, puis les données), avec une limite de
temps :

```bash
POD=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].metadata.name}')
mkdir -p /var/work/tests/artifacts/2

kubectl exec -n eks-116 "$POD" -- sh -c '
  echo "=== PUT token ===";
  TOKEN=$(curl -sX PUT --max-time 5 "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600");
  if [ -z "$TOKEN" ]; then
    echo "no token received: request timed out (hop limit blocked the pod)";
  else
    echo "=== GET with token ===";
    curl -s --max-time 5 -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/ \
      || echo "GET timed out (hop limit blocked the pod)";
  fi
' 2>&1 | tee /var/work/tests/artifacts/2/imds.txt

cat /var/work/tests/artifacts/2/imds.txt
```

Avec un hop limit de `1`, `curl` ne reçoit pas de réponse dans les `5` secondes
imparties, et le fichier contient une ligne mentionnant le timeout (`curl` affiche
`curl: (28) ... timeout` avec `-v`, et sans token le script ajoute lui-même la mention
`timed out`).

## Tâche 3. Vérification via l'API AWS : hop limit et IMDSv2 sur le node

On cherche sur quel node vit `probe`, on récupère son `providerID` et on en extrait
l'id de l'instance :

```bash
NODE=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].spec.nodeName}')
PROVIDER_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}')
# providerID de la forme aws:///eu-central-1a/i-0abc123def456789
INSTANCE_ID=$(echo "$PROVIDER_ID" | awk -F'/' '{print $NF}')
echo "node=$NODE instance=$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/3
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].MetadataOptions' --output json \
  | tee /var/work/tests/artifacts/3/metadata_options.txt
```

La sortie doit contenir `"HttpTokens": "required"` et `"HttpPutResponseHopLimit": 1` -
exactement ce que `vng.metadataOptions` a défini dans
`eks_karpenter_hardened_vng/terragrunt.hcl`, et ce que l'EC2NodeClass a transmis au
launch template du node.

## Tâche 4. Pod Security Admission : refus d'un pod privilégié

On active restricted sur le namespace via des labels (PSA est intégré à EKS, mais par
défaut un namespace sans labels se comporte comme `privileged` - rien n'est restreint) :

```bash
kubectl label namespace eks-116 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

On essaie un pod privilégié - admission doit refuser la création :

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl run priv-test -n eks-116 --image=busybox --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"priv-test","image":"busybox","securityContext":{"privileged":true}}]}}' \
  2>&1 | tee /var/work/tests/artifacts/4/psa_reject.txt

kubectl get pod priv-test -n eks-116 2>&1 | tee -a /var/work/tests/artifacts/4/psa_reject.txt
cat /var/work/tests/artifacts/4/psa_reject.txt
```

Sortie attendue, ressemblant à :

```
Error from server (Forbidden): pods "priv-test" is forbidden: violates PodSecurity "restricted:latest": privileged (container "priv-test" must not set securityContext.privileged=true)
```

Le pod n'est pas créé (`kubectl get pod priv-test` renvoie `NotFound`), et le message
contient les mots `privileged` et `restricted`/`violates` - ce qui est exactement ce que
demandent les critères d'acceptation.

## Tâche 5. La voie autorisée : un pod compatible avec restricted

On construit un pod avec tous les champs exigés par le profil `restricted`.
`runAsNonRoot: true` interdit seulement de s'exécuter en root - l'image `busybox:latest`
ne déclare pas d'utilisateur non-root par défaut, donc sans `runAsUser` explicite
(n'importe quel UID non nul) kubelet bloque le démarrage du conteneur avec une erreur
distincte, `container has runAsNonRoot and image will run as root`, déjà après que
admission a laissé passer le pod :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: safe-pod
  namespace: eks-116
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

kubectl get pod safe-pod -n eks-116 -o wide
```

Le pod passe admission et arrive à l'état `Running` - même namespace, même profil
`restricted`, mais les exigences sont pleinement satisfaites : `runAsNonRoot` avec un
`runAsUser` explicite, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`,
`seccompProfile` `RuntimeDefault`.

## Tâche 6. Accès privé au control plane et VPC endpoints

On vérifie le `resourcesVpcConfig` du cluster - le module `eks_v2_control_plane` active
déjà les deux flags (`endpoint_public_access = true`, `endpoint_private_access = true`) :

```bash
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
mkdir -p /var/work/tests/artifacts/6

aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig' --output json \
  | tee /var/work/tests/artifacts/6/private_endpoint.txt
```

La sortie affiche `"endpointPrivateAccess": true`. On complète le fichier avec une
explication :

```bash
cat >> /var/work/tests/artifacts/6/private_endpoint.txt <<'EOF'

Pour un cluster entièrement privé (nodes sans accès à internet), il faut des VPC
endpoints : ecr.api et ecr.dkr (pour tirer les images de conteneurs), le s3 gateway
endpoint (les couches d'images ECR résident physiquement dans S3, donc sans lui l'image
ne sera pas téléchargée même avec ecr.api et ecr.dkr en place), sts (échanger le token
IRSA contre des identifiants temporaires), ec2 (enregistrement du node et nom DNS), logs
(envoi des logs vers CloudWatch) et eks (accès à l'API EKS depuis le VPC). L'accès privé
au control plane (déjà activé sur ce cluster) est requis séparément de la liste des
endpoints - sans lui, les nodes ne pourraient pas s'enregistrer auprès de l'API server
depuis un subnet privé.
EOF

cat /var/work/tests/artifacts/6/private_endpoint.txt
```

## Vérification rapide

```bash
check_result
```
