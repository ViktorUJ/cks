[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 102 - solution de référence (accès au cluster : IAM, RBAC, access entries)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà configuré
pour le cluster. Le rôle worker dispose de `eks:*` (suffisant pour toutes les commandes
access entry/access policy) ainsi que de droits ciblés `iam:CreateRole/GetRole/DeleteRole/PutRolePolicy`
plus `sts:AssumeRole`, limités aux rôles nommés comme `*-test-*` - cela suffit pour créer
un rôle de test et réellement faire un assume-role sur celui-ci, sans toucher aux droits
des autres labs.

## Choix du second principal

Le cluster est déjà créé par le module `eks_v2_control_plane` en mode
`authenticationMode = API` (v21 `terraform-aws-modules/eks/aws` avec
`enable_cluster_creator_admin_permissions = true`). Le rôle worker possède déjà sa propre
access entry avec `AmazonEKSClusterAdminPolicy` (`terraform/modules/eks_v2_work_pc/iam.tf`) -
cela confirme que les access entries API sont activées et fonctionnelles dans le cluster.

Les tâches de ce lab nécessitent un **second** principal IAM qui n'a pas encore accès au
cluster. Le rôle de nœud Karpenter ne convient pas : le submodule
`terraform-aws-modules/eks/aws//modules/karpenter` crée automatiquement pour lui une access
entry de type `EC2_LINUX` (`create_access_entry = true` par défaut), et un même principal
IAM ne peut pas figurer dans deux access entries à la fois. Le lab crée donc un rôle de
test séparé via l'AWS CLI directement depuis le worker, avec une confiance limitée au rôle
worker lui-même (`sts:AssumeRole` est autorisé exclusivement pour l'ARN du rôle worker, et
pour personne d'autre).

## Tâche 1. Inventaire : authenticationMode

```bash
mkdir -p /var/work/tests/artifacts/1
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.accessConfig' \
  > /var/work/tests/artifacts/1/accessconfig.json
cat /var/work/tests/artifacts/1/accessconfig.json
```

Le résultat attendu ressemble à :

```json
{
    "authenticationMode": "API",
    "bootstrapClusterCreatorAdminPermissions": true
}
```

`authenticationMode` vaut `API` - le cluster n'a pas de ConfigMap `aws-auth`, tous les
mappings de principaux passent par les access entries.

## Tâche 2. Rôle IAM de test comme second principal

Récupérons l'ARN et l'account id du rôle worker (c'est lui qu'on autorisera à assumer le
rôle de test) :

```bash
WORKER_ARN=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "$WORKER_ARN"
```

`get-caller-identity` sur une instance avec profil EC2 affiche l'ARN de la **session**
(`assumed-role/.../i-...`), pas l'ARN du rôle lui-même. La trust policy et l'access entry
ont besoin de l'ARN du rôle, on le reconstitue donc à partir de la session :

```bash
ROLE_NAME=$(echo "$WORKER_ARN" | sed -E 's#.*assumed-role/([^/]+)/.*#\1#')
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "$ROLE_ARN"
```

Créons le rôle de test. Le nom doit obligatoirement contenir `-test-`, sinon le worker ne
pourra ni le créer ni l'assumer (sa politique IAM est restreinte à cette sous-chaîne) :

```bash
TEST_ROLE_NAME="eks-task102-test-viewer"

cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": { "AWS": "${ROLE_ARN}" }
    }
  ]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json

TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)

mkdir -p /var/work/tests/artifacts/2
echo "$TEST_ROLE_ARN" > /var/work/tests/artifacts/2/test_role_arn.txt
cat /var/work/tests/artifacts/2/test_role_arn.txt
```

Le rôle n'a besoin d'aucun droit IAM en interne à part assume - tous ses droits réels sont
accordés par le cluster via l'access entry et l'access policy/RBAC, pas par IAM.

## Tâche 3. Access entry pour le rôle de test, groupe viewers

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers \
  --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

On ne définit pas `username` - EKS le renseigne lui-même, comme le recommande la
documentation. Le principal est désormais connu du cluster et se retrouve dans le groupe
Kubernetes `viewers`, mais sans aucun droit pour l'instant : l'entry elle-même n'accorde
aucun droit, elle fournit seulement un sujet pour le RBAC.

## Tâche 4. ClusterRole et ClusterRoleBinding pour le groupe viewers

RBAC classique par-dessus l'access entry, sans access policy :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewers-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-pod-reader
subjects:
- kind: Group
  name: viewers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewers-pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl get clusterrole viewers-pod-reader -o yaml
kubectl get clusterrolebinding viewers-pod-reader -o yaml
```

Le groupe `viewers` peut désormais lire les pods dans tous les namespaces, et rien de plus.

## Tâche 5. Vérification manuelle des droits via assume-role

C'est une étape que l'étudiant réalise à la main - le test automatique ne vérifie que
l'artefact résultat, pas l'assume-role lui-même (les identifiants temporaires ne sont pas
nécessaires dans `tests.bats`).

Récupérons des identifiants temporaires pour le rôle de test et un kubeconfig séparé sous
un alias :

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name test-viewer-session)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-viewer --kubeconfig /tmp/test-viewer.kubeconfig

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
```

Résultat attendu : `get pods -A` fonctionne (seule la lecture est autorisée par le binding
RBAC sur le groupe `viewers`), tandis que `create namespace test` échoue avec `Forbidden` -
le RBAC de `viewers` ne contient pas de droit sur `namespaces`. On revient aux droits du
worker :

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

Sauvegardons le résultat de la vérification manuelle dans un artefact :

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/rbac_check.txt <<'EOF'
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> a fonctionné : le binding RBAC viewers-pod-reader donne get/list sur pods.

kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
  -> Forbidden : le groupe viewers n'a pas le droit de créer un namespace,
     l'access entry a fourni un sujet, mais le RBAC n'autorise pas cette action.
EOF
cat /var/work/tests/artifacts/5/rbac_check.txt
```

## Tâche 6. Access policy AmazonEKSViewPolicy par-dessus l'access entry

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

Le rôle de test dispose maintenant de deux sources de droits indépendantes : le groupe
RBAC `viewers` (get/list sur les pods) et l'access policy `AmazonEKSViewPolicy` (lecture de
la plupart des ressources du cluster, à l'exception des secrets). Notez que `kubectl
--kubeconfig /tmp/test-viewer.kubeconfig auth can-i --list` n'affichera pas les droits
issus de l'access policy - elle n'est pas exprimée sous forme d'objets RBAC, le seul moyen
de la voir est `list-associated-access-policies`.

## Tâche 7. Diagnostic : Unauthorized contre Forbidden

Montrons la différence avec des commandes réelles. Créons un autre rôle **sans** access
entry - il sera inconnu du cluster :

```bash
NOBODY_ROLE_NAME="eks-task102-test-nobody"
aws iam create-role --role-name "$NOBODY_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json
NOBODY_ARN=$(aws iam get-role --role-name "$NOBODY_ROLE_NAME" --query 'Role.Arn' --output text)

CREDS2=$(aws sts assume-role --role-arn "$NOBODY_ARN" --role-session-name nobody-session)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-nobody --kubeconfig /tmp/test-nobody.kubeconfig

kubectl --kubeconfig /tmp/test-nobody.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws iam delete-role --role-name "$NOBODY_ROLE_NAME"
```

Comparons cela avec la tentative de créer un namespace avec le rôle de test de la tâche 5
(`test-viewer.kubeconfig`) - là, le cluster connaît le principal, mais le RBAC n'autorise
pas l'action, d'où `Forbidden`. La différence se résume à ceci : `Unauthorized` signifie
que le cluster n'a trouvé aucune access entry pour cet ARN (`aws eks list-access-entries`
ne montrera pas cet ARN du tout), `Forbidden` signifie qu'une access entry existe, mais que
le RBAC/l'access policy n'autorisent pas cette action.

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

Sauvegardons l'explication dans un artefact :

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt <<'EOF'
Unauthorized (401) : le rôle eks-task102-test-nobody n'a pas d'access entry dans le
cluster. kubectl get pods -A avec son kubeconfig répond "You must be logged in to the
server (Unauthorized)" - on n'a même pas atteint le RBAC, l'authentification elle-même a
échoué. Vérification : aws eks list-access-entries --cluster-name <cluster> ne contient
pas son ARN.

Forbidden (403) : le rôle eks-task102-test-viewer a une access entry (groupe viewers) et
peut lire les pods, mais kubectl create namespace test avec le même rôle répond Forbidden -
le cluster a reconnu le principal, mais le RBAC du groupe viewers n'autorise pas la
création d'un namespace.
EOF
cat /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt
```

## Tâche 8. Suppression et restauration de l'access entry

Supprimons l'access entry et vérifions que l'accès a disparu, puis recréons l'entry (le
cluster reste dans un état fonctionnel pour la correction) :

```bash
aws eks delete-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" --role-session-name test-viewer-2)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

`delete-access-entry` supprime en même temps toutes les associations d'access policy liées
à l'entry - la policy de la tâche 6 (`AmazonEKSViewPolicy`) ne revient pas d'elle-même une
fois l'entry supprimée. On la restaure explicitement, pour que l'environnement retrouve
l'état atteint à la tâche 6 :

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

Sauvegardons le résultat du cycle suppression/restauration dans un artefact :

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/delete_recreate.txt <<'EOF'
aws eks delete-access-entry --cluster-name <cluster> --principal-arn <test_role_arn>
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> error: You must be logged in to the server (Unauthorized) : l'access entry supprimée
     a rendu le principal inconnu du cluster immédiatement.

aws eks create-access-entry --cluster-name <cluster> --principal-arn <test_role_arn> \
  --kubernetes-groups viewers --type STANDARD
  -> accès restauré, le binding RBAC sur le groupe viewers n'a jamais changé et
     fonctionne à nouveau.
EOF
cat /var/work/tests/artifacts/8/delete_recreate.txt
```

## Vérification rapide

```bash
check_result
```
