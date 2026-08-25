[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labo 128 - solution de référence (Gateway API sur AWS : ALB Gateway API et VPC Lattice)

Toutes les commandes s'exécutent sur la machine de travail (worker) par SSH. kubectl est
déjà configuré sur le cluster. Terraform a déjà créé les rôles IAM pour les deux
contrôleurs (composants `eks_lbc_irsa`, `eks_vpclattice_irsa`) - leurs ARN se trouvent
dans `~/lab128_hints.txt`.

```bash
cat ~/lab128_hints.txt
export CLUSTER=$(kubectl config current-context | sed 's|.*/||')
export LBC_ROLE_ARN=$(grep '^lbc_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export LATTICE_ROLE_ARN=$(grep '^vpclattice_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab128_hints.txt | awk '{print $3}')
export VPC_ID=$(grep '^vpc_id' ~/lab128_hints.txt | awk '{print $3}')
export ACCOUNT_ID=$(grep '^account_id' ~/lab128_hints.txt | awk '{print $3}')
export REGION=eu-central-1
```

## Tâche 1. CRD Gateway API et namespaces du labo

```bash
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl create namespace eks-128
kubectl create namespace eks-128-backend
```

## Tâche 2. AWS Load Balancer Controller et un Gateway de classe ALB (L7)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LBC_ROLE_ARN}
EOF

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

`region` et `vpcId` sont obligatoires ici, et ce n'est pas cosmétique. Le pod du
contrôleur atterrit dans `kube-system`, et ce namespace est couvert par un profil Fargate,
où il n'y a pas d'IMDS du tout. Sans les flags, le contrôleur tombe en `CrashLoopBackOff`
avec `failed to get VPC ID ... ec2imds: GetMetadata ... context deadline exceeded`
(vérifié sur le banc de test). Le même piège attend tout contrôleur que vous installez
dans `kube-system` sur Fargate (chapitres 15 et 26).

Nous créons le `GatewayClass` pour ALB et le `Gateway` lui-même :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web
  namespace: eks-128
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway web -n eks-128 -o wide
```

`gateway.k8s.aws/alb` est le même AWS Load Balancer Controller que dans les labos
108/109, sauf que l'entrée est décrite avec des ressources Gateway API au lieu d'Ingress :
les routes L7 `HTTPRoute` et `GRPCRoute` se transforment en listeners et règles de l'ALB
(chapitre 28, section 28.4).

## Tâche 3. HTTPRoute sur ALB : routage applicatif

```bash
kubectl create deployment frontend --image=viktoruj/ping_pong:latest \
  --replicas=2 -n eks-128
kubectl rollout status deployment/frontend -n eks-128
kubectl expose deployment frontend -n eks-128 --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - backendRefs:
        - name: frontend
          port: 80
EOF
```

Une seule route ne suffit pas : il faut dire au contrôleur quel type de cibles enregistrer.
Le type par défaut est déduit comme `instance`, et `instance` exige un Service de type
`NodePort` ou `LoadBalancer`. Avec `ClusterIP`, le load balancer reste sous-programmé : le
`Gateway` passe en `Accepted: False` avec `reason: Invalid`, et le log du contrôleur
répète `TargetGroup port is empty. When using Instance targets, your service must be of
type 'NodePort' or 'LoadBalancer'` (reproduit sur le banc de test). Dans le monde Ingress,
cela se réglait avec l'annotation `alb.ingress.kubernetes.io/target-type: ip`, dans
Gateway API il y a à la place un objet typé séparé, et il doit se trouver dans le
namespace de son propre Service :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: frontend
  namespace: eks-128
spec:
  targetReference:
    name: frontend
  defaultConfiguration:
    targetType: ip
EOF
```

Nous attendons l'adresse et confirmons via AWS CLI qu'il s'agit bien d'un ALB :

```bash
for i in $(seq 1 30); do
  ADDR=$(kubectl get gateway web -n eks-128 -o jsonpath='{.status.addresses[0].value}')
  [[ -n "$ADDR" ]] && break
  sleep 10
done
echo "gateway address: $ADDR"

LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${ADDR}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/3
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/3/alb.txt
cat /var/work/tests/artifacts/3/alb.txt
```

Dans la sortie, `Type` doit être `application` - un `Gateway` de classe `aws-alb` crée un
ALB de la même façon qu'un `Ingress` avec `ingressClassName: alb` dans le labo 109, juste
via une ressource typée au lieu d'annotations.

Il ne reste qu'à attendre `Programmed: True` et à vérifier que le trafic circule vraiment.
Le load balancer est interne (`internal-...`), donc la requête se fait depuis le worker -
il est dans le même VPC :

```bash
for i in $(seq 1 30); do
  p=$(kubectl get gateway web -n eks-128 \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')
  [[ "$p" == "True" ]] && break
  sleep 10
done
kubectl get gateway web -n eks-128 -o wide

curl -s -o /dev/null -w "http=%{http_code}\n" "http://${ADDR}/"
```

La réponse `http=200` arrive une à deux minutes après `Programmed: True` : d'abord l'ALB
devient actif, puis les cibles passent le health check (l'état des cibles se voit avec
`aws elbv2 describe-target-health`).

## Tâche 4. AWS Gateway API Controller et un Gateway de classe VPC Lattice

D'abord, ouvrons le SG des nœuds pour le trafic VPC Lattice - sans cette règle, les pods
ne recevront pas de trafic depuis le Service Network (chapitre 28, section 28.4 de la
documentation de déploiement du contrôleur) :

```bash
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists \
  --query "PrefixLists[?PrefixListName=='com.amazonaws.eu-central-1.vpc-lattice'].PrefixListId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id "$NODE_SG" \
  --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID}}],IpProtocol=-1"
```

Nous installons le contrôleur : namespace, ServiceAccount avec le rôle, chart Helm avec le
paramètre `defaultServiceNetwork` - le contrôleur créera lui-même le Service Network
`eks-task128-mesh` et y associera le VPC du cluster. Le chart et l'image se trouvent dans
un ECR public et sont tirés de façon anonyme, `helm registry login` n'est pas nécessaire
(le rôle du worker n'a pas `ecr-public:GetAuthorizationToken`, et c'est normal - un
registre public se lit sans jeton) :

```bash
kubectl create namespace aws-application-networking-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gateway-api-controller
  namespace: aws-application-networking-system
  annotations:
    eks.amazonaws.com/role-arn: ${LATTICE_ROLE_ARN}
EOF

helm install gateway-api-controller \
  oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
  --version=v1.1.0 \
  --namespace aws-application-networking-system \
  --set=serviceAccount.create=false \
  --set=defaultServiceNetwork=eks-task128-mesh \
  --set=awsRegion="${REGION}" \
  --set=awsAccountId="${ACCOUNT_ID}" \
  --set=clusterVpcId="${VPC_ID}" \
  --set=clusterName="${CLUSTER}"

kubectl rollout status deployment -n aws-application-networking-system --timeout=180s
```

Ces quatre derniers flags sont obligatoires pour la même raison que `region` et `vpcId`
pour le LBC, mais le symptôme est différent et vaut la peine d'être retenu. Le pod de ce
contrôleur tourne sur un nœud EC2 ordinaire, donc l'IMDS existe en principe, mais IMDSv2
a un hop limit de 1, et la requête depuis le namespace réseau du pod est rejetée. Sans les
flags, le contrôleur échoue instantanément avec
`init config failed: vpcId is not specified: EC2MetadataError ... status code: 401`
(vérifié sur le banc de test). C'est exactement ce hop limit qui est traité dans les
chapitres 10 et 19 : il protège les identifiants du rôle du nœud contre les pods, et au
passage casse tout contrôleur qui compte sur les métadonnées.

Nous créons le `GatewayClass` pour VPC Lattice et le `Gateway` lui-même :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: amazon-vpc-lattice
spec:
  controllerName: application-networking.k8s.aws/gateway-api-controller
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eks-task128-mesh
  namespace: eks-128
spec:
  gatewayClassName: amazon-vpc-lattice
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway eks-task128-mesh -n eks-128 -o wide
```

Le nom du `Gateway` n'est pas arbitraire ici, et c'est le principal piège de la tâche. Le
contrôleur VPC Lattice recherche le Service Network par le NOM de l'objet `Gateway`, pas
par la valeur de `defaultServiceNetwork`. Appelez le `Gateway` `mesh`, et il restera pour
toujours `Programmed: False` avec le message `VPC Lattice Service Network not found`,
parce que le réseau dans le compte s'appelle `eks-task128-mesh` (vérifié sur le banc de
test : deux `Gateway` côte à côte, celui avec le nom correspondant affiche
`Programmed: True` et l'ARN du réseau dans le message, celui avec un nom différent affiche
`not found`). D'où la règle : nom du `Gateway` = nom du Service Network.

Un `Gateway` de classe `amazon-vpc-lattice` se reflète dans un Service Network VPC
Lattice : c'est une connexion east-west entre services du cluster, pas une entrée depuis
l'extérieur comme `aws-alb` (chapitre 28, section 28.5).

## Tâche 5. Symptôme : HTTPRoute sans ReferenceGrant

Nous montons le backend dans un namespace voisin :

```bash
kubectl create deployment backend --image=viktoruj/ping_pong:latest \
  --replicas=1 -n eks-128-backend
kubectl rollout status deployment/backend -n eks-128-backend
kubectl expose deployment backend -n eks-128-backend --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: backend
  namespace: eks-128-backend
spec:
  targetReference:
    name: backend
  defaultConfiguration:
    targetType: ip
EOF
```

`TargetGroupConfiguration` est nécessaire pour la même raison qu'à la tâche 3, et montre
en même temps la séparation de la propriété : l'objet vit dans le namespace du
propriétaire du Service, pas à côté de la route.

La route `rates` vit dans `eks-128`, mais fait référence à un Service dans
`eks-128-backend`. Son parent est le `Gateway` `web` de classe `aws-alb` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /rates
      backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF
```

La même route, mais sur un `Gateway` de classe `amazon-vpc-lattice` - c'est l'expérience de
contrôle, nécessaire pour la conclusion de la tâche :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates-lattice
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: eks-task128-mesh
      sectionName: http
  rules:
    - backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF

sleep 25
mkdir -p /var/work/tests/artifacts/5
{
  echo "rates status=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates reason=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
  echo "rates message=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].message}')"
  echo "rates-lattice status=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates-lattice reason=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
} > /var/work/tests/artifacts/5/refnotpermitted.txt
cat /var/work/tests/artifacts/5/refnotpermitted.txt
```

Nous n'utilisons pas `kubectl -o yaml | grep -A...` : pour les objets CRD (unstructured),
les champs de condition sont sérialisés dans l'ordre alphabétique (`reason`, `status`
viennent avant `type`), donc il est plus fiable d'extraire la condition voulue directement
via `jsonpath`.

Un `backendRefs` avec un champ `namespace` fait référence à un Service dans un autre
namespace - par défaut cette référence est interdite, pour qu'un développeur de `eks-128`
ne puisse pas router du trafic vers un service qui ne lui appartient pas sans
l'autorisation de son propriétaire (chapitre 28, section 28.2). Pour la route `rates`, la
condition `ResolvedRefs` sera `status: "False"`, `reason: RefNotPermitted`, message
`No explicit ReferenceGrant exists to allow the reference.`

Mais voici le résultat autour duquel tourne l'expérience de contrôle : la condition de
`rates-lattice` est immédiatement `ResolvedRefs: True`, alors qu'il n'existe encore aucun
`ReferenceGrant` dans `eks-128-backend` (vérifié sur le banc de test). La règle
`ReferenceGrant` fait partie de la spécification Gateway API, mais c'est l'implémentation
qui la RESPECTE, pas l'API server : l'AWS Load Balancer Controller la vérifie, le
contrôleur VPC Lattice version v1.1.0 non. D'où la conclusion pratique : le même YAML dans
deux implémentations de Gateway API donne une frontière de confiance différente entre les
équipes, et on ne peut se fier à `ReferenceGrant` comme protection que là où vous avez
vérifié le comportement du contrôleur.

## Tâche 6. Fix : ReferenceGrant autorise la référence cross-namespace

`ReferenceGrant` est créé par le propriétaire du backend **cible** - le namespace
`eks-128-backend`, pas celui qui fait la référence :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-from-eks-128
  namespace: eks-128-backend
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: eks-128
  to:
    - group: ""
      kind: Service
EOF

sleep 15
mkdir -p /var/work/tests/artifacts/6
{
  echo "ResolvedRefs status=$(kubectl get httproute rates -n eks-128 \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "curl /rates http=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://${ADDR}/rates")"
} > /var/work/tests/artifacts/6/resolved.txt
cat /var/work/tests/artifacts/6/resolved.txt
```

À la deuxième ligne de l'artefact, nous vérifions non pas le statut mais le trafic
lui-même : `http=200` depuis le pod `backend` signifie que toute la chaîne s'est assemblée
- la route a été autorisée par le grant, le target group de type `ip` a été créé, les
cibles ont passé le health check. Si `ResolvedRefs` est déjà `True` mais que `curl` renvoie
`503`, attendez une minute : l'enregistrement des cibles a lieu après l'apparition du
target group.

Après l'apparition du `ReferenceGrant`, la condition `ResolvedRefs` de `rates` passe à
`True` en quelques secondes - le contrôleur réévalue les références autorisées à la
réconciliation suivante, et la route commence à résoudre `backend` dans le namespace
voisin. Notez que l'autorisation est accordée par le namespace PROPRIÉTAIRE de la cible :
supprimez le `ReferenceGrant`, et la route revient à `RefNotPermitted`, même si personne
n'a touché la route elle-même.

## Vérification rapide

```bash
check_result
```
