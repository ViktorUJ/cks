[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 121 - solution de référence (diagnostic d'accès : access entries, IRSA, kubeconfig)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà configuré
pour le cluster, et terraform a déjà créé le bucket S3 et le rôle IRSA du composant
`eks_irsa_break_demo` - leurs noms et ARN sont dans le fichier d'indices
`/home/ubuntu/lab121_hints.txt`.

```bash
cat ~/lab121_hints.txt
```

Le reste de la solution utilise les variables de ce fichier :

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab121_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab121_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab121_hints.txt | awk '{print $3}')
```

Le lab couvre deux axes d'accès indépendants du chapitre 47 : un humain/une CI ne peut pas
entrer dans le cluster (tâches 1-4), et un pod obtient `AccessDenied` sur AWS (tâches 5-8).

## Tâche 1. Namespace `eks-121`

```bash
kubectl create namespace eks-121
```

## Tâche 2. Symptôme Unauthorized : un rôle sans access entry

Nous créons un rôle IAM de test sans aucun access entry. Le rôle du worker n'autorise à
gérer que les rôles contenant `-test-` dans le nom (voir `iam.tf` du module
`eks_v2_work_pc`), le nom doit donc contenir cette sous-chaîne :

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEST_ROLE_NAME="eks-task121-test-noaccess"

cat > /tmp/trust-worker.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "$(aws sts get-caller-identity --query Arn --output text)" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-worker.json

export TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)
```

Le rôle du worker porte `sts:AssumeRole` spécifiquement pour les ARN contenant `-test-`
dans le nom, donc nous pouvons assumer ce rôle directement :

L'ordre compte ici. Nous construisons le kubeconfig séparé **avec les identifiants du
worker, avant** `assume-role` : `aws eks update-kubeconfig` appelle `eks:DescribeCluster`,
et le rôle de test n'a aucune policy IAM du tout, donc sous ce rôle la commande échouerait
avec `AccessDeniedException` et le fichier ne serait pas créé. C'est d'ailleurs le
troisième type d'échec de cette chaîne : `AccessDenied` venant d'IAM (pas de permission
pour l'API AWS) est différent à la fois d'`Unauthorized` (l'identité n'est pas mappée dans
le cluster) et de `Forbidden` (RBAC). `kubectl` lui-même obtient ensuite un token via
`aws eks get-token`, et ce token viendra de l'identité dont les identifiants se trouvent
dans les variables d'environnement :

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --kubeconfig /tmp/kubeconfig-test

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-noaccess --duration-seconds 900)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
```

Nous vérifions l'accès de cette identité au cluster - sans access entry elle n'est pas
mappée, donc nous attendons `Unauthorized` (chapitre 47, section 47.3) :

```bash
mkdir -p /var/work/tests/artifacts/2
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/2/unauthorized.txt 2>&1
cat /var/work/tests/artifacts/2/unauthorized.txt
```

Le fichier doit contenir une ligne avec le mot `Unauthorized` - l'API server n'a pas pu
faire correspondre cette identité IAM à un access entry ou un enregistrement aws-auth.

Nous restaurons les identifiants du worker (les variables de session ne sont plus
nécessaires) :

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Tâche 3. Correction d'Unauthorized : access entry + AmazonEKSViewPolicy

Nous créons un access entry pour le rôle de test et lui accordons la policy d'accès
`AmazonEKSViewPolicy` au niveau du cluster (chapitre 47, section 47.4) :

```bash
aws eks create-access-entry --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" --type STANDARD

aws eks associate-access-policy --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster
```

Nous refaisons `assume-role` (la première session a déjà expiré ou s'est terminée) et la
même requête avec le même kubeconfig temporaire - elle doit désormais renvoyer la liste
des pods, et non `Unauthorized` :

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-access --duration-seconds 900)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

mkdir -p /var/work/tests/artifacts/3
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/3/authorized.txt 2>&1
cat /var/work/tests/artifacts/3/authorized.txt
```

Le fichier contient désormais des lignes comme `NAMESPACE ... POD ...` - l'access entry a
fait disparaître l'erreur `Unauthorized`.

## Tâche 4. Symptôme Forbidden : l'accès View n'autorise pas l'écriture

Le rôle n'a que `AmazonEKSViewPolicy` (lecture). Nous essayons de créer un namespace avec
le même kubeconfig temporaire - RBAC doit le refuser avec `Forbidden` (chapitre 47, section
47.3) :

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl --kubeconfig /tmp/kubeconfig-test create namespace test-forbidden \
  > /var/work/tests/artifacts/4/forbidden.txt 2>&1
cat /var/work/tests/artifacts/4/forbidden.txt
```

Nous ajoutons au même fichier une explication de la différence entre la tâche 2
(`Unauthorized`) et la tâche 4 (`Forbidden`) :

```bash
cat >> /var/work/tests/artifacts/4/forbidden.txt <<'EOF'

Différence : dans la tâche 2 le rôle n'était pas du tout mappé dans le cluster - le serveur
d'API n'a pas pu prouver l'identité, c'est Unauthorized (un échec d'authentification, la
couche authn). Dans la tâche 4 l'identité est déjà prouvée et mappée via un access entry,
mais RBAC (AmazonEKSViewPolicy n'accorde que la lecture) n'autorise pas create namespace -
c'est Forbidden (un échec d'autorisation, la couche authz). Les corrections diffèrent :
Unauthorized se corrige dans le mapping (access entry / aws-auth), Forbidden se corrige dans
RBAC (Role, ClusterRole, liaison de politique).
EOF
cat /var/work/tests/artifacts/4/forbidden.txt

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Tâche 5. Un ServiceAccount avec l'annotation IRSA correcte

Le rôle `eks_irsa_break_demo` a déjà été créé par terraform avec une trust policy qui fait
confiance exactement à `system:serviceaccount:eks-121:demo-reader` (chapitre 16, chapitre
47 section 47.6) :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader
  namespace: eks-121
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-121
spec:
  serviceAccountName: demo-reader
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-121 --timeout=120s
```

Nous vérifions l'identité et lisons l'objet depuis S3 :

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "--- caller identity ---"
  kubectl exec irsa-app -n eks-121 -- aws sts get-caller-identity
  echo "--- s3 object ---"
  kubectl exec irsa-app -n eks-121 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" -
} > /var/work/tests/artifacts/5/irsa_ok.txt
cat /var/work/tests/artifacts/5/irsa_ok.txt
```

`Arn` dans la sortie doit ressembler à `assumed-role/<prefix>-irsa-role/...`, et le second
bloc doit être la ligne `hello from s3` (l'objet que terraform y a placé).

## Tâche 6. Symptôme AccessDenied : une annotation cassée dans un autre namespace

Nous créons une seconde SA avec LA MÊME annotation sur le même rôle, mais dans le
namespace `default`. La trust policy du rôle attend
`sub = system:serviceaccount:eks-121:demo-reader`, alors que le `sub` de cette SA sera
`system:serviceaccount:default:demo-reader-broken` - la condition ne correspondra pas
(chapitre 47, section 47.6) :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader-broken
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
  namespace: default
spec:
  serviceAccountName: demo-reader-broken
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-app -n default --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec broken-app -n default -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/6/broken.txt 2>&1
cat /var/work/tests/artifacts/6/broken.txt
```

La commande doit échouer avec une erreur d'échange de token : `AccessDenied` ou
`WebIdentityErr` (le message exact varie selon la version du SDK/CLI, mais le principe est
le même - STS a rejeté `sts:AssumeRoleWithWebIdentity` parce que le `sub` du token ne
correspondait pas à la condition de la trust policy).

## Tâche 7. Diagnostic : comparer les annotations et la cause racine du `sub`

Nous comparons l'annotation de la SA dans les deux namespaces et expliquons la cause :

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "--- eks-121/demo-reader ---"
  kubectl get sa demo-reader -n eks-121 \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo "--- default/demo-reader-broken ---"
  kubectl get sa demo-reader-broken -n default \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo
  cat <<'TXT'
Les deux annotations pointent vers le même rôle IRSA, mais la trust policy du rôle vérifie
la condition sub sur le token STS : system:serviceaccount:<namespace>:<serviceaccount>. Pour
demo-reader c'est system:serviceaccount:eks-121:demo-reader - cela correspond à la condition
du rôle, donc l'échange est autorisé. Pour demo-reader-broken le token porte
sub=system:serviceaccount:default:demo-reader-broken - un namespace différent et un nom de
SA différent, de sorte que la condition StringEquals ne correspond pas et
sts:AssumeRoleWithWebIdentity est rejeté sans égard au fait que l'ARN du rôle dans
l'annotation soit le même.
TXT
} > /var/work/tests/artifacts/7/diagnostics.txt
cat /var/work/tests/artifacts/7/diagnostics.txt
```

## Tâche 8. Synthèse : les deux axes d'accès

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<'EOF'
L'axe humain (tâches 2-4) vit dans la chaîne kubectl - IAM - EKS authenticator - RBAC :
Unauthorized signifie que l'identité IAM n'a pas pu être prouvée ni mappée dans le cluster
du tout (corrigé via un access entry ou aws-auth), tandis que Forbidden signifie que
l'identité est déjà connue, mais que RBAC n'a pas autorisé cette action précise (corrigé via
Role/ClusterRoleBinding). L'axe du pod (tâches 5-7) vit dans la chaîne pod - ServiceAccount
- STS - IAM role : AccessDenied ou WebIdentityErr signifie que la trust policy du rôle n'a
pas correspondu au sub du token du ServiceAccount (corrigé en modifiant la condition sub
dans la trust policy ou l'annotation du SA). La différence clé : sur le premier axe la
correction est RBAC à l'intérieur du cluster, sur le second axe la correction est la trust
policy du rôle IAM dans AWS, et les deux ne doivent pas être confondus.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## Vérification rapide

```bash
check_result
```
