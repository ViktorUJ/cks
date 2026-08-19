[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 126 - solution de référence (security groups for pods)

Toutes les commandes s'exécutent sur la machine de travail par SSH, comme dans le reste
des labs du cours : le rôle du worker a reçu des permissions pour créer une security
group, y ajouter des règles, et attacher la politique
`AmazonEKSVPCResourceController` au rôle du cluster (voir le README, section
« Infrastructure »).

Variables partagées dans toute la solution :

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "cluster=$CLUSTER vpc=$VPC_ID"
```

## Tâche 1. Namespace `eks-126`

```bash
kubectl create namespace eks-126
```

## Tâche 2. Vérification des prérequis

Trouvez le nom du rôle du control plane et vérifiez les politiques attachées (sur le
worker) :

```bash
ROLE_ARN=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.roleArn' --output text)
ROLE_NAME=$(echo "$ROLE_ARN" | sed 's|.*/||')
echo "cluster role: $ROLE_NAME"
aws iam list-attached-role-policies --role-name "$ROLE_NAME"
```

Par défaut elle n'y est pas (le rôle n'a que `AmazonEKSClusterPolicy` et la politique de
chiffrement), donc on l'attache :

```bash
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
```

La politique va sur le rôle du **control plane** (le cluster), pas sur le rôle des
nodes Karpenter - c'est lui qui permet à EKS de créer/supprimer des branch ENI et de
gérer leurs IP.

On vérifie les trois variables du VPC CNI - toutes déjà définies par terraform via la
`configuration` de l'addon `vpc-cni` :

```bash
kubectl describe daemonset aws-node -n kube-system \
  | grep -E 'ENABLE_POD_ENI|POD_SECURITY_GROUP_ENFORCING_MODE|DISABLE_TCP_EARLY_DEMUX'
```

Sortie attendue : `ENABLE_POD_ENI: true`, `POD_SECURITY_GROUP_ENFORCING_MODE: strict`,
`DISABLE_TCP_EARLY_DEMUX: true`. La première active le trunk interface, la deuxième
garde active la vérification des règles de la SG du pod pour le trafic venant de la
node (en mode `standard` elle ne l'est pas, et le symptôme de la tâche 4 n'apparaîtrait
pas), la troisième laisse `kubelet` ouvrir une connexion TCP vers un pod sur une branch
ENI.

Enregistrez les deux confirmations :

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "cluster role: $ROLE_NAME"
  aws iam list-attached-role-policies --role-name "$ROLE_NAME"
  echo "---"
  kubectl describe daemonset aws-node -n kube-system | grep ENABLE_POD_ENI
} > /var/work/tests/artifacts/2/prereqs.txt
cat /var/work/tests/artifacts/2/prereqs.txt
```

## Tâche 3. Security group incomplète et SecurityGroupPolicy

Créez la SG dans le VPC de la lab. Important : ne mettez PAS le tag
`karpenter.sh/discovery`, sinon l'EC2NodeClass la sélectionnerait comme SG de node :

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name eks-task126-secured-pod-sg \
  --description "security group for secured-app pods (lab 126, intentionally incomplete)" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
echo "$SG_ID"
```

On n'ajoute encore aucun `authorize-security-group-ingress` ni `egress` : une SG
fraîche n'a que l'allow-all egress par défaut d'AWS et zéro règle inbound - exactement
l'état qui produit le symptôme.

Créez la `SecurityGroupPolicy` :

```bash
mkdir -p /var/work/tests/artifacts/3
echo -n "$SG_ID" > /var/work/tests/artifacts/3/sg_id.txt

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: secured-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: secured
  securityGroups:
    groupIds:
      - ${SG_ID}
EOF

kubectl get securitygrouppolicy secured-sgp -n eks-126 -o yaml
```

## Tâche 4. Le symptôme : Running, mais jamais Ready

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secured-app
  namespace: eks-126
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secured
  template:
    metadata:
      labels:
        app: secured
    spec:
      nodeSelector:
        work_type: nitro
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
EOF

kubectl rollout status deployment/secured-app -n eks-126 --timeout=180s || true
kubectl get pod -n eks-126 -l app=secured
```

Le pod reste bloqué `0/1 Ready`, même si la phase est `Running` - la branch ENI a bien
été créée, mais la SG du pod ne laisse pas passer la probe du kubelet. Enregistrez le
diagnostic :

```bash
mkdir -p /var/work/tests/artifacts/4
POD=$(kubectl get pod -n eks-126 -l app=secured -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n eks-126 > /var/work/tests/artifacts/4/pod_not_ready.txt
grep -i 'readiness probe failed\|unhealthy' /var/work/tests/artifacts/4/pod_not_ready.txt
```

L'événement ressemble à ceci (vérifié sur le banc de test) :

```
Warning  Unhealthy  49s (x33 over 5m44s)  kubelet  Readiness probe failed:
Get "http://10.10.16.177:8080/": context deadline exceeded
```

On confirme que le pod est bien sur une branch ENI, et non sur l'ENI de la node :

```bash
kubectl get pod "$POD" -n eks-126 \
  -o jsonpath='{.metadata.annotations.vpc\.amazonaws\.com/pod-eni}{"\n"}'
kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.containers[0].resources.limits}{"\n"}'
aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,InterfaceType,Status,PrivateIpAddress]' \
  --output text
```

L'annotation contiendra `eniId`, `vlanId` et un `associationID` du type
`trunk-assoc-...`, les limites montreront `vpc.amazonaws.com/pod-eni: 1`, et le type
d'interface sera `branch` avec la même IP que le pod.

## Tâche 5. Correction des probes : une règle inbound depuis la SG des nodes

Trouvez la SG des nodes Karpenter via la node sur laquelle tourne `secured-app` (sur le
worker) :

```bash
NODE=$(kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
INSTANCE_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | sed 's|.*/||')
NODE_SG=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
echo "node=$NODE instance=$INSTANCE_ID node_sg=$NODE_SG"
```

Ajoutez une règle inbound à la SG du pod :

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 8080 \
  --source-group "$NODE_SG"
```

Attendez que la probe passe et enregistrez le résultat :

```bash
sleep 15
kubectl get pod -n eks-126 -l app=secured
mkdir -p /var/work/tests/artifacts/5
kubectl get pod "$POD" -n eks-126 > /var/work/tests/artifacts/5/pod_ready.txt
cat /var/work/tests/artifacts/5/pod_ready.txt
```

`READY` doit maintenant afficher `1/1` - kubelet peut désormais atteindre la branch ENI
du pod sur le port de la probe.

## Tâche 6. Diagnostic et correction du DNS

Vérifiez la résolution depuis l'intérieur de `secured-app`. L'image
`viktoruj/ping_pong:latest` n'a aucun utilitaire shell pour le DNS (construite depuis
`scratch`), donc on utilise un pod de diagnostic séparé avec le même label
`app: secured`, pour que `secured-sgp` s'applique aussi à lui :

```bash
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never \
  --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  -- sleep 3600
kubectl wait --for=condition=Ready pod/dns-probe -n eks-126 --timeout=120s || true

mkdir -p /var/work/tests/artifacts/6
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_before.txt 2>&1 || true
cat /var/work/tests/artifacts/6/dns_before.txt
```

La sortie est `;; connection timed out; no servers could be reached`. Il est important
de bien nommer la cause : l'egress n'est pas le problème ici, une SG fraîche a la règle
allow-all egress par défaut, et la requête part bien. Le paquet est perdu du côté
inbound du destinataire, qui n'a aucune règle pour notre SG. CoreDNS dans cette lab
tourne sur Fargate et vit derrière la cluster primary security group :

```bash
CLUSTER_PRIMARY_SG=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo "cluster primary sg (CoreDNS on Fargate): $CLUSTER_PRIMARY_SG"
```

On ajoute un inbound `53` TCP et UDP à la cluster primary SG, avec comme source notre
SG de pod. Cette seule règle suffit, puisqu'une security group est stateful : la
réponse à une requête inbound autorisée revient sans règle séparée.

```bash
aws ec2 authorize-security-group-ingress --group-id "$CLUSTER_PRIMARY_SG" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]"
```

On vérifie la résolution à nouveau :

```bash
sleep 5
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_after.txt 2>&1
cat /var/work/tests/artifacts/6/dns_after.txt
```

Maintenant la deuxième étape, selon le principe du moindre privilège. L'allow-all
egress par défaut de la SG du pod signifie « le pod peut tout faire sortir » - pour un
pod avec sa propre security group, c'est exactement ce qu'on voulait éviter. On réduit
l'egress à `53` et on confirme que le DNS continue de fonctionner :

```bash
aws ec2 revoke-security-group-egress --group-id "$SG_ID" \
  --protocol -1 --port all --cidr 0.0.0.0/0
aws ec2 authorize-security-group-egress --group-id "$SG_ID" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]"

kubectl delete pod dns-probe -n eks-126 --ignore-not-found
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  --command -- sh -c 'nslookup kubernetes.default.svc.cluster.local'
sleep 45
kubectl logs dns-probe -n eks-126 | tee -a /var/work/tests/artifacts/6/dns_after.txt
```

Construisez l'artefact :

```bash
cat > /var/work/tests/artifacts/6/dns_fix.txt <<EOF
Avant la correction (dns_before.txt) : le nslookup vers kubernetes.default a échoué avec
";; connection timed out; no servers could be reached".

La cause n'est PAS l'egress : une security group fraîche ${SG_ID} a la règle allow-all
egress par défaut, et la requête part bien du pod. Le paquet est perdu du côté INBOUND
du destinataire - la cluster primary security group ${CLUSTER_PRIMARY_SG}, derrière
laquelle tourne CoreDNS sur Fargate, n'a aucune règle inbound pour notre SG. La règle
est nécessaire exactement là, et une seule suffit : une security group est stateful, la
réponse à une requête inbound autorisée revient d'elle-même.

Correction : inbound 53 TCP et UDP sur ${CLUSTER_PRIMARY_SG} avec source-group ${SG_ID}.
Ensuite, nslookup résout kubernetes.default.svc.cluster.local (dns_after.txt).

Deuxième étape : l'allow-all egress par défaut a été retiré de la SG du pod, remplacé
par un egress explicite 53 TCP et UDP vers ${CLUSTER_PRIMARY_SG}. Le DNS continue de
fonctionner - cela montre que l'egress côté source et l'inbound côté destinataire sont
deux règles indépendantes, et qu'autoriser tout le trafic sortant du pod n'est pas
nécessaire pour le DNS.
EOF
cat /var/work/tests/artifacts/6/dns_fix.txt
```

## Tâche 7. Piège : une seule node, des security group différentes

Faites une expérience : deux pods avec des security group DIFFÉRENTES sur la même
node. Mettez en place une deuxième SG et une deuxième `SecurityGroupPolicy` pour le
label `app: other` :

```bash
mkdir -p /var/work/tests/artifacts/7
SG2=$(aws ec2 create-security-group \
  --group-name eks-task126-other-pod-sg \
  --description "second pod sg for the same-node experiment (lab 126)" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)
echo "second pod sg: $SG2"

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: other-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: other
  securityGroups:
    groupIds:
      - ${SG2}
EOF
```

On trouve le pod du Deployment (celui-là précisément, pas les pods de diagnostic - eux
aussi portent le label `app: secured`) et on lance un pod avec une SG différente à côté
de lui :

```bash
APP_POD=$(kubectl get pod -n eks-126 -l app=secured \
  -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].kind=="ReplicaSet")]}{.metadata.name}{"\n"}{end}' \
  | head -1)
APP_IP=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.status.podIP}')
APP_NODE=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
echo "secured-app=$APP_POD ip=$APP_IP node=$APP_NODE"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/before.txt
```

Le résultat est `wget: download timed out` : le pod a sa propre SG, le voisin a la
sienne, et aucune règle n'autorise le trafic entre eux. Ajoutez la règle et répétez :

```bash
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 8080 --source-group "$SG2"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/after.txt
```

Maintenant la requête passe (`RC=0`). Cela signifie qu'en mode `strict`, les règles de
SG du pod s'appliquent même à l'intérieur d'une seule node - les deux pods ont chacun
leur branch ENI, et c'est la règle qui décide du résultat. Construisez l'artefact :

```bash
{
  echo "=== Deployment's pod with SecurityGroupPolicy secured-sgp (branch ENI) ==="
  kubectl get pod "$APP_POD" -n eks-126 -o wide
  echo
  echo "=== pod with a DIFFERENT security group (other-sgp), same node ==="
  kubectl get pod othersg -n eks-126 -o wide
  echo
  echo "=== before the rule ==="
  cat /var/work/tests/artifacts/7/before.txt
  echo "=== after the inbound 8080 rule from the second SG ==="
  cat /var/work/tests/artifacts/7/after.txt
  echo
  echo "=== where CoreDNS is ==="
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
  cat <<'TXT'

Conclusion de l'expérience. Notre POD_SECURITY_GROUP_ENFORCING_MODE est strict, et dans
ce mode les règles de security group du pod s'appliquent même au trafic à l'intérieur
d'une seule node : deux pods avec des SG différentes sur la même node n'ont d'abord pas
pu se connecter (download timed out), puis se sont connectés après l'ajout d'une règle
inbound. Le diagnostic ici est donc l'ordinaire - regarder les règles, pas la topologie.

Le contraste à connaître (documentation AWS, mode standard) : en mode standard, les
règles de SG du pod ne s'appliquent PAS au trafic entre pods et services sur la même
node, y compris kubelet et nodeLocalDNS, et des pods avec des security group différentes
sur la même node ne communiquent pas du tout, car ils se trouvent dans des subnets
différents avec le routage désactivé entre eux. Là, la même situation ne peut pas être
corrigée par une règle, seulement en répartissant les pods sur des nodes différentes.
C'est aussi exactement pourquoi standard ne reproduit pas le symptôme des tâches 4 et
5 : la probe du kubelet contourne les règles de SG, et la readiness passe même avec une
security group qui n'a pas une seule règle inbound.
TXT
} > /var/work/tests/artifacts/7/same_node_trap.txt
cat /var/work/tests/artifacts/7/same_node_trap.txt
```

## Vérification rapide

```bash
check_result
```
