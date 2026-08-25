[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 104 - solution de référence (workload identity: IRSA et Pod Identity)

Toutes les commandes s'exécutent sur la machine de travail (worker) par SSH. kubectl est
déjà configuré pour le cluster, et terraform a déjà créé le bucket S3, le secret Secrets
Manager et les deux rôles IAM - leurs noms et ARN se trouvent dans le fichier d'indices
`/home/ubuntu/lab104_hints.txt`.

```bash
cat ~/lab104_hints.txt
```

Les exemples ci-dessous utilisent les variables de ce fichier - remplacez par vos propres
valeurs ou exportez-les au début de la session :

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab104_hints.txt | awk '{print $3}')
export SECRET_NAME=$(grep '^secret_name' ~/lab104_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export POD_IDENTITY_ROLE_ARN=$(grep '^pod_identity_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab104_hints.txt | awk '{print $3}')
```

## Tâche 1. Namespace `eks-104`

```bash
kubectl create namespace eks-104
```

## Tâche 2. ServiceAccount avec annotation IRSA

Le rôle `irsa_role_arn` est déjà créé par terraform avec une trust policy qui fait
confiance exactement à ce `ServiceAccount`
(`system:serviceaccount:eks-104:s3-reader-irsa` - chapitre 16). Créons le SA avec
l'annotation :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader-irsa
  namespace: eks-104
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

kubectl get sa s3-reader-irsa -n eks-104 -o yaml
```

## Tâche 3. Pod avec IRSA : vérification de l'identité

Créons un pod qui utilise ce SA. Le Pod Identity Webhook injectera les variables
`AWS_ROLE_ARN` et `AWS_WEB_IDENTITY_TOKEN_FILE` (chapitre 16) au démarrage du pod :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-104
spec:
  serviceAccountName: s3-reader-irsa
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-104 --timeout=120s
```

Vérifions que le SDK à l'intérieur du pod a obtenu ses identifiants via web identity, et
non via le rôle de la node :

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec irsa-app -n eks-104 -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/3/irsa_identity.txt
cat /var/work/tests/artifacts/3/irsa_identity.txt
```

Dans la sortie, `Arn` doit ressembler à
`arn:aws:sts::<account>:assumed-role/<prefix>-irsa-role/...` - cela prouve que le pod tourne
sous le rôle IRSA, pas sous le rôle de la node.

## Tâche 4. Lecture d'un objet depuis S3 via IRSA

Le rôle `irsa` ne porte que `s3:ListBucket` et `s3:GetObject` sur ce bucket précis
(chapitre 16, principe du moindre privilège). Lisons l'objet que terraform a placé dans le
bucket :

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec irsa-app -n eks-104 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" - \
  > /var/work/tests/artifacts/4/s3_read.txt
cat /var/work/tests/artifacts/4/s3_read.txt
```

Le fichier doit contenir la ligne `hello from s3` - le contenu de l'objet placé par le
module `eks_v2_workload_identity_demo`.

## Tâche 5. Association Pod Identity

Contrairement à IRSA, Pod Identity n'a pas besoin d'annotation sur le SA - la liaison
`namespace + SA -> rôle` vit dans l'API EKS, pas dans Kubernetes (chapitre 17). Créons le
SA et l'association :

```bash
kubectl create serviceaccount secret-reader-podid -n eks-104

aws eks create-pod-identity-association \
  --cluster-name "${CLUSTER_NAME}" \
  --namespace eks-104 \
  --service-account secret-reader-podid \
  --role-arn "${POD_IDENTITY_ROLE_ARN}"

mkdir -p /var/work/tests/artifacts/5
aws eks list-pod-identity-associations --cluster-name "${CLUSTER_NAME}" --namespace eks-104 \
  > /var/work/tests/artifacts/5/association.txt
cat /var/work/tests/artifacts/5/association.txt
```

## Tâche 6. Pod avec Pod Identity : secret au lieu du rôle de la node

Créons un pod avec le SA `secret-reader-podid`. L'agent `eks-pod-identity-agent` (déjà
installé comme managed addon dans cette lab) lui fournira les identifiants du rôle
`pod_identity_role_arn` via l'endpoint local `169.254.170.23` (chapitre 17) :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: podid-app
  namespace: eks-104
spec:
  serviceAccountName: secret-reader-podid
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/podid-app -n eks-104 --timeout=120s
```

Lisons le secret et vérifions l'identité en une seule commande :

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "--- caller identity ---"
  kubectl exec podid-app -n eks-104 -- aws sts get-caller-identity
  echo "--- secret value ---"
  kubectl exec podid-app -n eks-104 -- aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" --query SecretString --output text
} > /var/work/tests/artifacts/6/secret_read.txt
cat /var/work/tests/artifacts/6/secret_read.txt
```

`Arn` renvoyé par `get-caller-identity` montrera `assumed-role/<prefix>-pod-identity-role/...`,
et la valeur du secret sera un JSON avec les champs `username`/`password` (`demo`/`demo123`)
que terraform a placés dans Secrets Manager.

## Tâche 7. Symptôme : le rôle de la node n'a pas accès au bucket

Créons un pod **sans** liaison à IRSA ou à Pod Identity - il n'héritera que des droits du
rôle de la node (chapitre 16, section 16.1 : « donner un rôle à la node fait fuiter les
droits vers tous les pods » fonctionne aussi dans l'autre sens, le rôle de la node ne porte
aucun droit applicatif) :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: plain-app
  namespace: eks-104
spec:
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/plain-app -n eks-104 --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl exec plain-app -n eks-104 -- aws s3 ls "s3://${BUCKET_NAME}/" \
  > /var/work/tests/artifacts/7/node_role_denied.txt 2>&1
cat /var/work/tests/artifacts/7/node_role_denied.txt
```

La commande doit échouer avec `AccessDenied` (ou `is not authorized to perform`) - le rôle
de la node ne porte pas `s3:*` sur ce bucket, il n'a que les droits des composants système
(pull depuis ECR, fonctionnement du CNI). Cela montre clairement la différence : sans IRSA
ou Pod Identity, un pod n'obtient que ce que possède le rôle de la node, et non « tout ce
qui est configuré quelque part dans le compte ».

## Vérification rapide

```bash
check_result
```
