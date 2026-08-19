[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laba 130 - solution de référence (ECR et supply chain)

Toutes les commandes s'exécutent sur la machine de travail (worker) par SSH. L'AWS CLI est
déjà configuré sur le bon compte via le rôle de l'instance (pas besoin d'un `aws configure`
supplémentaire), kubectl - sur le cluster de la laba. À la place de `docker`, on utilise
`podman` (déjà installé sur le worker).

Définissons une fois l'account id et l'adresse du registre privé :

```bash
export AWS_REGION=eu-central-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "$ECR_HOST"
```

## Tâche 1. Repository avec tags IMMUTABLE et scanOnPush

```bash
aws ecr create-repository \
  --repository-name eks-lab130/app \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --region "$AWS_REGION"

aws ecr describe-repositories --repository-names eks-lab130/app --region "$AWS_REGION"
```

Assurez-vous que dans la sortie figurent `imageTagMutability: IMMUTABLE` et
`imageScanningConfiguration.scanOnPush: true`.

## Tâche 2. Push d'une image avec le tag v1

On se connecte au registre avec un token de 12 heures et on retague une image publique :

```bash
aws ecr get-login-password --region "$AWS_REGION" \
  | podman login --username AWS --password-stdin "$ECR_HOST"

podman pull docker.io/library/alpine:3.19
podman tag docker.io/library/alpine:3.19 "$ECR_HOST/eks-lab130/app:v1"
podman push "$ECR_HOST/eks-lab130/app:v1"

aws ecr describe-images --repository-name eks-lab130/app --region "$AWS_REGION"
```

Dans la sortie de `describe-images`, il doit y avoir une seule image avec le tag `v1`.

Deux points pratiques. Premièrement : `alpine` est choisi ici non pas pour « peser moins »,
mais parce que le scan de base d'ECR sait analyser sa base de paquets - la tâche 4 aura de
vraies findings (vérifié : HIGH 1, MEDIUM 1, LOW 2 sur `alpine:3.19`). Deuxièmement : gardez
les tâches 2-6 dans une seule session SSH. `podman login` écrit le token dans
`$XDG_RUNTIME_DIR/containers/auth.json`, et ce répertoire est supprimé avec la session de
l'utilisateur, donc après reconnexion, push répond `unauthorized: authentication required`
alors que le token ECR de 12 heures est encore valide.

## Tâche 3. Symptôme : un nouveau push du tag v1 est rejeté

On prend une autre image, on la tague avec le même `v1` et on essaie de l'écraser :

```bash
podman pull docker.io/library/busybox:1.36
podman tag docker.io/library/busybox:1.36 "$ECR_HOST/eks-lab130/app:v1"

mkdir -p /var/work/tests/artifacts/3
podman push "$ECR_HOST/eks-lab130/app:v1" 2>&1 \
  | tee /var/work/tests/artifacts/3/denied.txt
```

Le push se termine par un refus du registre (vérifié sur le stand) :

```
tag invalid: The image tag 'v1' already exists in the 'eks-lab130/app' repository
and cannot be overwritten because the tag is immutable.
```

C'est exactement ainsi qu'IMMUTABLE fonctionne : le tag `v1` est déjà occupé par la première
image, et il ne peut pas être écrasé. La sortie sera longue - `podman` essaie
successivement plusieurs formats de manifeste (OCI, docker v2, docker v1) et reçoit chaque
fois le même refus ; dans l'artefact `denied.txt`, la ligne recherchée apparaît dans chaque
tentative. Notez que les layers sont déjà téléchargés à ce moment-là : IMMUTABLE protège
précisément le LIEN DU TAG, pas le stockage des blobs.

## Tâche 4. Findings du scan (scan on push)

Le scan démarre automatiquement au push (tâche 2). On attend la fin via une boucle de retry
(dans cette version du CLI, il existe une commande d'attente prête à l'emploi) :

```bash
aws ecr wait image-scan-complete \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION"

mkdir -p /var/work/tests/artifacts/4
aws ecr describe-image-scan-findings \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
  --query '{status: imageScanStatus.status, bySeverity: imageScanFindings.findingSeverityCounts}' \
  > /var/work/tests/artifacts/4/scan-summary.txt

cat /var/work/tests/artifacts/4/scan-summary.txt
```

Si `aws ecr wait image-scan-complete` n'est pas disponible dans votre version du CLI,
remplacez-le par une boucle de retry manuelle :

```bash
for i in $(seq 1 30); do
  status=$(aws ecr describe-image-scan-findings \
    --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
    --query 'imageScanStatus.status' --output text 2>/dev/null)
  [[ "$status" == "COMPLETE" ]] && break
  sleep 5
done
```

`findingSeverityCounts` montrera le nombre de findings par severity - pour `alpine:3.19`,
c'était `{"HIGH": 1, "MEDIUM": 1, "LOW": 2}` (vérifié sur le stand, les chiffres exacts
dépendent de la date du scan et de la base de vulnérabilités).

Une limite d'applicabilité importante, qu'il vaut la peine de vérifier soi-même. Le scan de
base d'ECR lit la base de paquets des distributions connues, donc une image construite
`FROM scratch` (par exemple un binaire Go statique) ou distroless, il NE PEUT PAS la
scanner :

```bash
aws ecr describe-image-scan-findings --repository-name eks-lab130/app \
  --image-id imageTag=<tag de l'image scratch> --region "$AWS_REGION" \
  --query 'imageScanStatus' --output json
# {
#   "status": "FAILED",
#   "description": "UnsupportedImageError: The operating system and/or package manager
#                   are not supported."
# }
```

D'où une conclusion pratique : « le scanner n'a pas trouvé de vulnérabilités » et « le
scanner n'a pas pu regarder » sont deux choses différentes, et dans les rapports agrégés,
elles se confondent facilement en « pas de remarques ». Si la politique de gate exige un
scan propre, vérifiez précisément le statut, pas seulement le nombre de findings.

## Tâche 5. Déploiement par digest

Le digest de l'image `v1` peut être récupéré depuis ECR (plus fiable que `podman inspect`,
car c'est le digest exact du manifeste présent dans le registre) :

```bash
DIGEST=$(aws ecr describe-images --repository-name eks-lab130/app --image-ids imageTag=v1 \
  --region "$AWS_REGION" --query 'imageDetails[0].imageDigest' --output text)
echo "$DIGEST"

kubectl create namespace eks-130 --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: digest-app
  namespace: eks-130
  labels:
    app: digest-app
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
  - name: app
    image: ${ECR_HOST}/eks-lab130/app@${DIGEST}
    command: ["sh", "-c", "sleep 86400"]
EOF

kubectl wait --for=condition=Ready pod/digest-app -n eks-130 --timeout=600s
kubectl get po -n eks-130 digest-app -o wide
```

`nodeSelector` est obligatoire ici, et c'est un piège facile à ne pas voir. La machine de
travail est en x86_64, donc `podman push` a envoyé à ECR un manifeste MONO-ARCHITECTURE
(seulement `amd64`), alors que le NodePool de la laba autorise aussi `arm64`. Vérifié sur le
stand : sans selector, Karpenter a démarré un `t4g.small`, l'image s'est téléchargée sans
problème, mais le conteneur est mort avec `exitCode 255` et des logs vides -
`CrashLoopBackOff` sans raison compréhensible. Le même type de problème est traité dans la
laba 124 (l'image `polinux/stress` était uniquement `amd64`). Conclusion pour la production :
construisez des manifestes multi-architectures, ou bien liez explicitement la charge à
l'architecture.

Le rôle du node Karpenter porte déjà la managed policy `AmazonEC2ContainerRegistryReadOnly`
(configurée dans le module `eks_v2_karpenter`), donc le pod tire l'image avec succès et
passe en `Running` sans `imagePullSecrets`. La référence par `@sha256:` fixe exactement
l'ensemble d'octets que vous avez scanné et vérifié dans les tâches 2-4 - le tag aurait pu
bouger, le digest ne le peut pas.

## Tâche 6. Pull through cache pour registry.k8s.io

Une règle sans authentification - l'upstream est public :

```bash
aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix k8s-cache \
  --upstream-registry-url registry.k8s.io \
  --region "$AWS_REGION"
```

Lors de la création de la PREMIÈRE règle du compte, ECR crée le service-linked role
`AWSServiceRoleForECRPullThroughCache`, donc l'appelant a besoin du droit
`iam:CreateServiceLinkedRole` (dans la politique de la machine de travail, il est présent,
avec la condition `iam:AWSServiceName = pullthroughcache.ecr.amazonaws.com`). Sans lui, ECR
ne répond pas directement à propos de l'IAM utilisateur, mais avec un wrapper facile à
confondre avec une erreur de paramètres : `ValidationException ... The Amazon ECR action
failed due to an IAM exception: ... is not authorized to perform:
iam:CreateServiceLinkedRole` (reproduit sur le stand).

Le premier pull via le cache crée le repository `k8s-cache/pause` dans votre ECR et met
l'image en cache :

```bash
podman pull "${ECR_HOST}/k8s-cache/pause:3.9"

aws ecr describe-repositories --region "$AWS_REGION" \
  --query "repositories[?starts_with(repositoryName,'k8s-cache/pause')].repositoryName"
```

## Tâche 7. Docker Hub pull through cache avec un secret (sans vrai pull)

Le thème de la laba demande précisément un secret, donc on le crée réellement, mais avec
une valeur factice à la place d'un vrai token Docker Hub : un vrai pull avec ces
identifiants ne passera pas, mais la configuration (secret plus cache rule) n'en est pas
dégradée et est entièrement vérifiée.

```bash
aws secretsmanager create-secret \
  --name ecr-pullthroughcache/dockerhub-creds \
  --description "Docker Hub creds for ECR pull through cache (lab placeholder)" \
  --secret-string '{"username":"lab-placeholder-user","accessToken":"lab-placeholder-token"}' \
  --region "$AWS_REGION"

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id ecr-pullthroughcache/dockerhub-creds --region "$AWS_REGION" \
  --query 'ARN' --output text)
echo "$SECRET_ARN"

aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix docker-hub \
  --upstream-registry-url registry-1.docker.io \
  --credential-arn "$SECRET_ARN" \
  --region "$AWS_REGION"

aws ecr describe-pull-through-cache-rules --region "$AWS_REGION"
```

Le secret doit obligatoirement avoir le préfixe `ecr-pullthroughcache/` - sinon ECR ne
l'accepte pas pour la cache rule. Un vrai `podman pull` via `docker-hub/...` avec cette
valeur factice échouera comme prévu (les identifiants ne sont pas réels) - la tâche vérifie
la configuration (le secret et la règle existent), pas le fait d'un pull réussi. Pour le
fait d'un pull réussi via le cache, c'est la tâche 6 (registry.k8s.io, sans
authentification).

Important : n'utilisez pas ici de vrais identifiants Docker Hub. Le secret ne sert qu'à
vérifier la configuration de la laba elle-même.

## Tâche 8. Lifecycle policy

Règle : conserver au plus 5 images avec le tag `v.*`, supprimer le reste selon l'âge du
tag :

```bash
cat <<'EOF' > /tmp/lifecycle.json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "keep last 5 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": { "type": "expire" }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name eks-lab130/app \
  --lifecycle-policy-text file:///tmp/lifecycle.json \
  --region "$AWS_REGION"

aws ecr get-lifecycle-policy --repository-name eks-lab130/app --region "$AWS_REGION"
aws ecr start-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION" >/dev/null
sleep 5
aws ecr get-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION"
```

`get-lifecycle-policy-preview` peut ne pas renvoyer le résultat immédiatement (l'aperçu est
calculé de manière asynchrone) - si le statut est encore `IN_PROGRESS`, répétez la requête
après quelques secondes.

## Vérification rapide

```bash
check_result
```
