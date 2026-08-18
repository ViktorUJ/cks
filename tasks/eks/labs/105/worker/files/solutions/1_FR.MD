[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 105 - solution de référence (secrets : KMS envelope encryption, External Secrets)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà configuré
pour le cluster, et terraform a déjà créé le secret Secrets Manager et le rôle IRSA pour le
contrôleur ESO - leurs noms et ARN se trouvent dans le fichier-indice
`/home/ubuntu/lab105_hints.txt`.

```bash
cat ~/lab105_hints.txt
```

Variables issues du fichier-indice pour les commandes suivantes :

```bash
export SECRET_NAME=$(grep '^secret_name' ~/lab105_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^role_arn' ~/lab105_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab105_hints.txt | awk '{print $3}')
```

## Tâche 1. Namespace `eks-105`

```bash
kubectl create namespace eks-105
```

## Tâche 2. Couche 1 : vérification du KMS envelope encryption

Depuis Kubernetes 1.28, EKS chiffre tous les objets API (y compris `Secret`) avec une clé
AWS par défaut, sans aucune action de votre part. On vérifie la configuration de
chiffrement du cluster :

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.encryptionConfig' \
  > /var/work/tests/artifacts/2/encryption_config.txt
cat /var/work/tests/artifacts/2/encryption_config.txt
```

Dans la sortie, l'élément de la liste contient `"resources": ["secrets"]` - c'est ce qui
confirme que la couche 1 (envelope encryption des secrets dans etcd) est activée. Si vous
avez besoin d'une customer managed key (CMK) au lieu de la clé AWS owned, cela se fait par
une commande séparée `aws eks associate-encryption-config` - mais activer sa propre CMK est
possible, tandis que désactiver le chiffrement est impossible (c'est une opération
irréversible), donc on reste ici sur la clé AWS par défaut.

## Tâche 3. Installation d'External Secrets Operator via Helm

Le rôle `role_arn` a déjà été créé par terraform avec une trust policy qui ne fait
confiance qu'au SA `external-secrets` dans le namespace `external-secrets` (chapitre 16,
IRSA). On installe ESO via Helm et on lie immédiatement le rôle par une annotation sur le
ServiceAccount :

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ROLE_ARN}"

kubectl rollout status deployment/external-secrets -n external-secrets
kubectl get pods -n external-secrets
```

On vérifie que l'annotation a bien été posée sur le SA du contrôleur :

```bash
kubectl get sa external-secrets -n external-secrets -o yaml | grep -A1 annotations
```

## Tâche 4. SecretStore et ExternalSecret

On crée un `SecretStore` (namespace-scoped - isolation par équipe, chapitre 18.5), puis un
`ExternalSecret` qui référence le secret de démo créé par terraform :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-sm
  namespace: eks-105
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: eks-105
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-sm
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: ${SECRET_NAME}
        property: password
EOF
```

On attend la synchronisation et on vérifie le `Secret` natif :

```bash
kubectl wait --for=jsonpath='{.status.conditions[0].reason}'=SecretSynced \
  externalsecret/db-credentials -n eks-105 --timeout=120s

kubectl get externalsecret db-credentials -n eks-105
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

La valeur doit correspondre au mot de passe que terraform a placé dans Secrets Manager
(`S3cr3tPass123`). `refreshInterval: 1m` est délibérément court - à la tâche 6, il nous
faut voir rapidement la resynchronisation après une modification manuelle du secret dans
AWS.

## Tâche 5. Pod avec volume : chemin de synchronisation résistant

On monte le `Secret` comme un volume (volumeMount), pas via env - c'est exactement ce que
recommande le chapitre 18.5 pour les valeurs qui doivent se mettre à jour sans recréer le
pod (kubelet met lui-même à jour les fichiers du volume quand le `Secret` change) :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: vol-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: db-creds
      mountPath: /etc/db-creds
      readOnly: true
  volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
EOF

kubectl wait --for=condition=Ready pod/vol-reader -n eks-105 --timeout=120s
```

On lit la valeur depuis le fichier dans le volume :

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl exec vol-reader -n eks-105 -- cat /etc/db-creds/password \
  > /var/work/tests/artifacts/5/volume_password.txt
echo >> /var/work/tests/artifacts/5/volume_password.txt
cat /var/work/tests/artifacts/5/volume_password.txt
```

## Tâche 6. Pod avec env : symptôme de la valeur obsolète

On crée un second pod, qui lit le même `Secret`, mais via une variable d'environnement :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

kubectl wait --for=condition=Ready pod/env-reader -n eks-105 --timeout=120s
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

On change la valeur du secret directement dans Secrets Manager (pas via Kubernetes) :

```bash
aws secretsmanager put-secret-value --secret-id "${SECRET_NAME}" \
  --secret-string '{"username":"appuser","password":"RotatedPass456"}'
```

On attend `refreshInterval` (fixé à `1m` à la tâche 4) plus une marge, et on vérifie que
ESO a resynchronisé le `Secret` natif :

```bash
sleep 90
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

La valeur dans le `Secret` est déjà nouvelle (`RotatedPass456`) - ESO a fait son travail.
On regarde maintenant le pod avec env, qui a été créé avant la rotation :

```bash
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

Le pod affiche toujours l'ancienne valeur (`S3cr3tPass123`). Raison : les variables
d'environnement du conteneur sont fixées au démarrage du processus, donc la mise à jour du
`Secret` dans etcd ne les affecte pas - le pod doit être recréé (`kubectl rollout restart`
pour un Deployment, ou suppression puis création manuelle pour un Pod isolé) pour obtenir
la nouvelle valeur via env. Ce n'est pas un bug d'ESO, mais une particularité du
fonctionnement d'env dans Kubernetes - contrairement au volume, que kubelet met à jour sur
le disque sans recréer le pod (tâche 5).

On consigne l'observation dans un artefact :

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/rotation.txt <<'EOF'
Après put-secret-value dans Secrets Manager et la resynchronisation d'ExternalSecret, le
Secret natif db-credentials dans etcd a été mis à jour avec la nouvelle valeur du mot de
passe - ESO a fonctionné normalement.

Le pod env-reader lit le mot de passe via env (secretKeyRef), et les variables
d'environnement du conteneur sont fixées une seule fois au démarrage du processus. La
valeur de env ne se met pas à jour après un changement du Secret sans recréer le pod -
ce n'est pas une panne d'ESO, mais une particularité d'env dans Kubernetes. Le pod
vol-reader (tâche 5) lit le même Secret via volumeMount - un tel volume est mis à jour
sur le disque automatiquement par kubelet, sans recréer le pod.
EOF
cat /var/work/tests/artifacts/7/rotation.txt
```

## Vérification rapide

```bash
check_result
```
