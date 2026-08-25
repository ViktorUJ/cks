[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ126 - 参考解答(security groups for pods)

すべてのコマンドはコースの他のラボと同様、worker機上でSSH経由で実行します。worker機のロー
ルにはsecurity groupの作成、そのルールの作成、そしてクラスタのロールへのポリシー
`AmazonEKSVPCResourceController`のアタッチ権限が付与されています(README、「インフラストラ
クチャ」セクション参照)。

解答全体で使う共通変数:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "cluster=$CLUSTER vpc=$VPC_ID"
```

## 課題1. Namespace `eks-126`

```bash
kubectl create namespace eks-126
```

## 課題2. 前提条件の確認

control planeのロール名を調べ、アタッチ済みのポリシーを確認します(worker機上で実行):

```bash
ROLE_ARN=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.roleArn' --output text)
ROLE_NAME=$(echo "$ROLE_ARN" | sed 's|.*/||')
echo "cluster role: $ROLE_NAME"
aws iam list-attached-role-policies --role-name "$ROLE_NAME"
```

デフォルトでは付いていません(このロールには`AmazonEKSClusterPolicy`と暗号化用のポリシーし
かありません)。そのためアタッチします:

```bash
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
```

このポリシーは**control plane**(クラスタ)のロールに付けるものであり、Karpenterのノードの
ロールには付けません。まさにこのポリシーがEKSにbranch ENIの作成/削除とそのIPの管理を許可
します。

VPC CNIの3つの変数を確認します。すべてterraformがアドオン`vpc-cni`の`configuration`経由で
すでに設定済みです:

```bash
kubectl describe daemonset aws-node -n kube-system \
  | grep -E 'ENABLE_POD_ENI|POD_SECURITY_GROUP_ENFORCING_MODE|DISABLE_TCP_EARLY_DEMUX'
```

期待される出力: `ENABLE_POD_ENI: true`、`POD_SECURITY_GROUP_ENFORCING_MODE: strict`、
`DISABLE_TCP_EARLY_DEMUX: true`。1つ目はtrunk interfaceを有効にし、2つ目はノードからPodへ
のトラフィックに対してPodのSGのルールチェックを残します(`standard`ではこのチェックがなく、
課題4の症状は発生しません)。3つ目は`kubelet`がbranch ENI上のPodへTCPを開くことを許可しま
す。

両方の確認結果を保存します:

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

## 課題3. 不完全なsecurity groupとSecurityGroupPolicy

ラボのVPC内にSGを作成します。重要な点: タグ`karpenter.sh/discovery`を付けないでください。
付けるとEC2NodeClassがこのSGをノード用のSGとして選んでしまいます:

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name eks-task126-secured-pod-sg \
  --description "security group for secured-app pods (lab 126, intentionally incomplete)" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
echo "$SG_ID"
```

`authorize-security-group-ingress`や`egress`はまだ何も追加しません: 新規作成したSGには
AWSデフォルトのallow-all egressのみがあり、inboundルールはゼロです - まさにこれが症状を引
き起こす状態です。

`SecurityGroupPolicy`を作成します:

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

## 課題4. 症状: RunningだがReadyには絶対にならない

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

Podは`0/1 Ready`のまま止まります。フェーズは`Running`ですが、branch ENIは作成されたもの
の、PodのSGがkubeletのプローブを通していません。診断結果を保存します:

```bash
mkdir -p /var/work/tests/artifacts/4
POD=$(kubectl get pod -n eks-126 -l app=secured -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n eks-126 > /var/work/tests/artifacts/4/pod_not_ready.txt
grep -i 'readiness probe failed\|unhealthy' /var/work/tests/artifacts/4/pod_not_ready.txt
```

イベントは次のようになります(実機で確認済み):

```
Warning  Unhealthy  49s (x33 over 5m44s)  kubelet  Readiness probe failed:
Get "http://10.10.16.177:8080/": context deadline exceeded
```

Podが実際にbranch ENI上にあり、ノードのENI上ではないことを確認します:

```bash
kubectl get pod "$POD" -n eks-126 \
  -o jsonpath='{.metadata.annotations.vpc\.amazonaws\.com/pod-eni}{"\n"}'
kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.containers[0].resources.limits}{"\n"}'
aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,InterfaceType,Status,PrivateIpAddress]' \
  --output text
```

アノテーションには`eniId`、`vlanId`、`trunk-assoc-...`という形の`associationID`が入り、
limitには`vpc.amazonaws.com/pod-eni: 1`が入り、インターフェースのタイプは`branch`でPodと
同じIPを持ちます。

## 課題5. プローブの修正: ノードSGからのinboundルール

`secured-app`が乗っているノードから、KarpenterのノードのSGを見つけます(worker機上で実
行):

```bash
NODE=$(kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
INSTANCE_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | sed 's|.*/||')
NODE_SG=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
echo "node=$NODE instance=$INSTANCE_ID node_sg=$NODE_SG"
```

PodのSGにinboundルールを追加します:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 8080 \
  --source-group "$NODE_SG"
```

プローブが通るまで待ち、結果を保存します:

```bash
sleep 15
kubectl get pod -n eks-126 -l app=secured
mkdir -p /var/work/tests/artifacts/5
kubectl get pod "$POD" -n eks-126 > /var/work/tests/artifacts/5/pod_ready.txt
cat /var/work/tests/artifacts/5/pod_ready.txt
```

`READY`は`1/1`になるはずです - kubeletはこれでPodのbranch ENI上のプローブ用ポートに到達
できるようになりました。

## 課題6. DNSの診断と修正

`secured-app`のPodから名前解決を確認します。イメージ`viktoruj/ping_pong:latest`には
DNS用のシェルユーティリティがありません(`scratch`からビルドされています)。そのため、同じ
ラベル`app: secured`を持つ別の診断用Podを使い、それにも`secured-sgp`が適用されるようにし
ます:

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

出力は`;; connection timed out; no servers could be reached`です。原因を正しく特定するこ
とが重要です。egressは関係ありません。新規作成したSGにはデフォルトのallow-all egressのル
ールがあるため、リクエストは出ていきます。パケットは受け側の入り口、つまりinboundの部分で
失われます - 受け側には我々のSGに対するルールがありません。このラボのCoreDNSはFargate上に
あり、cluster primary security groupの内側にあります:

```bash
CLUSTER_PRIMARY_SG=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo "cluster primary sg (CoreDNS on Fargate): $CLUSTER_PRIMARY_SG"
```

cluster primary SGに、ソースをPodのSGとするinbound `53`のTCPとUDPを追加します。このルー
ル1つだけで十分です。security groupはstatefulなので、許可された入力(ingress)リクエストへ
の応答は個別のルールなしで戻っていきます。

```bash
aws ec2 authorize-security-group-ingress --group-id "$CLUSTER_PRIMARY_SG" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]"
```

名前解決を再度確認します:

```bash
sleep 5
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_after.txt 2>&1
cat /var/work/tests/artifacts/6/dns_after.txt
```

続いて2段目の作業を、最小権限の原則に従って行います。PodのSGのデフォルトのallow-all
egressは「Podは外部へすべて許可されている」ことを意味します - 独自のsecurity groupを持つ
Podにとって、これはまさに避けたかった状態です。egressを`53`だけに絞り、DNSが動き続けるこ
とを確認します:

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

アーティファクトを作成します:

```bash
cat > /var/work/tests/artifacts/6/dns_fix.txt <<EOF
修正前(dns_before.txt): kubernetes.defaultへのnslookupは
";; connection timed out; no servers could be reached"で失敗していた。

原因はegressではない: 新規作成したsecurity group ${SG_ID}にはデフォルトのallow-all
egressルールがあり、リクエストはPodから出ていく。パケットは受け側の入り口(inbound)で
破棄されている - Fargate上のCoreDNSが動作するcluster primary security group
${CLUSTER_PRIMARY_SG}に、我々のSGに対するinboundルールがないためだ。ルールが必要なのは
まさにそこであり、それ一つで十分: security groupはstatefulなので、許可された入力
(ingress)リクエストへの応答は自動的に戻っていく。

修正: ${CLUSTER_PRIMARY_SG}にsource-groupを${SG_ID}としたinbound 53のTCPとUDPを追加。
これによりnslookupはkubernetes.default.svc.cluster.localを解決できるようになった
(dns_after.txt)。

2段目: PodのSGからデフォルトのallow-all egressを外し、代わりに${CLUSTER_PRIMARY_SG}への
明示的なegress 53のTCPとUDPを残した。DNSは動き続ける - これはegress(送信側)とinbound
(受信側)が2つの独立したルールであり、DNSのためにPodにすべての送信トラフィックを許可する
必要はないことを示している。
EOF
cat /var/work/tests/artifacts/6/dns_fix.txt
```

## 課題7. トラップ: 同一ノード、異なるsecurity group

実験をします: 同一ノード上に、異なるsecurity groupを持つ2つのPodを置きます。ラベル
`app: other`用に2つ目のSGと2つ目の`SecurityGroupPolicy`を作成します:

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

Deploymentの実際のPod(診断用のPodではありません - それらも`app: secured`ラベルを持って
います)を特定し、隣に別のSGを持つPodを起動します:

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

結果は`wget: download timed out`です: それぞれのPodが自分のSGを持ち、両者の間には許可が
ありません。ルールを追加して再試行します:

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

今度はリクエストが通ります(`RC=0`)。つまり`strict`モードではPodのSGのルールは同一ノード
内でも機能しており、両方のPodはそれぞれのbranch ENI上にあり、決めるのはまさにルールで
す。アーティファクトを作成します:

```bash
{
  echo "=== SecurityGroupPolicy secured-sgpを持つDeploymentのPod(branch ENI) ==="
  kubectl get pod "$APP_POD" -n eks-126 -o wide
  echo
  echo "=== 異なるsecurity group(other-sgp)を持つPod、同じノード ==="
  kubectl get pod othersg -n eks-126 -o wide
  echo
  echo "=== ルール追加前 ==="
  cat /var/work/tests/artifacts/7/before.txt
  echo "=== 2つ目のSGからのinbound 8080ルール追加後 ==="
  cat /var/work/tests/artifacts/7/after.txt
  echo
  echo "=== CoreDNSの場所 ==="
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
  cat <<'TXT'

実験の結論。我々の`POD_SECURITY_GROUP_ENFORCING_MODE`は`strict`であり、このモードではPod
のsecurity groupのルールは同一ノード内のトラフィックにも適用される: 異なるSGを持つ2つの
Podは最初は接続できなかった(download timed out)が、inboundルールを追加した後は接続でき
た。つまりここでの診断は通常どおりで、トポロジーではなくルールを見ればよい。

知っておくべき対比(AWSドキュメント、standardモード): standardモードでは、Podのsecurity
groupのルールは同一ノード上のPodとサービス間のトラフィック(kubeletやnodeLocalDNSを含む)
には適用されず、異なるsecurity groupを持つPod同士は同一ノード上でも全く通信できない。そ
れは異なるサブネットにいて、ルーティングが無効化されているためだ。そこでは同じ状況をルー
ルでは修正できず、Podをノード間で分散させることでしか解決できない。そしてまさにそのため
に、standardでは課題4と5の症状は再現しない: kubeletのプローブはSGのルールを迂回し、
inboundルールが1つもないsecurity groupでもreadinessは通ってしまう。
TXT
} > /var/work/tests/artifacts/7/same_node_trap.txt
cat /var/work/tests/artifacts/7/same_node_trap.txt
```

## クイックチェック

```bash
check_result
```
