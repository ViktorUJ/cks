[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 128 - 參考解決方案(AWS 上的 Gateway API:ALB Gateway API 與 VPC Lattice)

所有命令都透過 SSH 在工作機上執行。kubectl 已經在集群上配置好了。Terraform 已經為兩個
控制器創建了 IAM 角色(組件 `eks_lbc_irsa`、`eks_vpclattice_irsa`) - 它們的 ARN 位於
`~/lab128_hints.txt` 中。

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

## 任務 1. Gateway API CRD 與實驗的 namespace

```bash
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl create namespace eks-128
kubectl create namespace eks-128-backend
```

## 任務 2. AWS Load Balancer Controller 與 ALB 類別的 Gateway(L7)

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

`region` 和 `vpcId` 在這裡是必須的,這不是可有可無的裝飾。控制器的 pod 落在
`kube-system` 中,而這個 namespace 被 Fargate 配置檔覆蓋,那裡完全沒有 IMDS。沒有這
些參數,控制器會陷入 `CrashLoopBackOff`,出現 `failed to get VPC ID ... ec2imds:
GetMetadata ... context deadline exceeded`(已在測試環境中驗證)。同樣的陷阱等待著
你在 Fargate 上的 `kube-system` 中安裝的任何控制器(第 15 章和第 26 章)。

創建 ALB 的 `GatewayClass` 和 `Gateway` 本身:

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

`gateway.k8s.aws/alb` 就是實驗 108/109 中那個同樣的 AWS Load Balancer Controller,
只是入口是用 Gateway API 的資源來描述,而不是 Ingress:L7 路由 `HTTPRoute` 和
`GRPCRoute` 會轉化為 ALB 的 listener 和規則(第 28 章,28.4 節)。

## 任務 3. ALB 上的 HTTPRoute:應用層路由

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

只有一個路由還不夠:必須告訴控制器要註冊什麼類型的目標。類型預設會被推斷為
`instance`,而 `instance` 需要 `NodePort` 或 `LoadBalancer` 類型的 Service。用
`ClusterIP` 的話,負載平衡器會處於未完全配置的狀態:`Gateway` 會進入 `Accepted:
False`,`reason: Invalid`,控制器日誌中會反覆出現 `TargetGroup port is empty. When
using Instance targets, your service must be of type 'NodePort' or 'LoadBalancer'`
(已在測試環境中重現)。在 Ingress 的世界裡,這是靠 `alb.ingress.kubernetes.io/target-type: ip` 這個註解解決的,在 Gateway API 中,取代註解的是一個獨立的類型化對象,它必須位於其 Service 所在的 namespace 中:

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

等待地址出現,並透過 AWS CLI 確認這確實是 ALB:

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

輸出中的 `Type` 應該是 `application` - 類別為 `aws-alb` 的 `Gateway` 創建 ALB 的方
式,和實驗 109 中 `ingressClassName: alb` 的 `Ingress` 一樣,只是透過類型化資源而不
是註解來完成。

接下來等待 `Programmed: True`,並確認流量確實通過了。負載平衡器是內部的
(`internal-...`),所以請求要從 worker 發出 - 它在同一個 VPC 中:

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

`http=200` 的回應會在 `Programmed: True` 後的一兩分鐘內出現:首先 ALB 變為啟用狀
態,然後目標會通過 health check(目標的狀態可以在 `aws elbv2 describe-target-health` 中看到)。

## 任務 4. AWS Gateway API Controller 與 VPC Lattice 類別的 Gateway

首先在節點的 SG 中開放 VPC Lattice 的流量 - 沒有這條規則,pod 就不會收到來自
Service Network 的流量(第 28 章,控制器部署文件的 28.4 節):

```bash
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists \
  --query "PrefixLists[?PrefixListName=='com.amazonaws.eu-central-1.vpc-lattice'].PrefixListId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id "$NODE_SG" \
  --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID}}],IpProtocol=-1"
```

安裝控制器:namespace、帶有角色的 ServiceAccount、帶有 `defaultServiceNetwork` 參
數的 Helm chart - 控制器會自己創建 Service Network `eks-task128-mesh`,並將它與集
群的 VPC 關聯起來。Chart 和映像位於公開的 ECR 中,可以匿名拉取,不需要 `helm
registry login`(worker 的角色沒有 `ecr-public:GetAuthorizationToken`,這是正確
的 - 公開倉庫不需要 token 就能讀取):

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

最後這四個參數是必須的,原因和 LBC 的 `region`、`vpcId` 一樣,但症狀不同,值得記住。
這個控制器的 pod 位於普通的 EC2 節點上,也就是說原則上是有 IMDS 的,但是 IMDSv2 的
hop limit 是 1,來自 pod 網路 namespace 的請求會被丟棄。沒有這些參數,控制器會立刻
崩潰,出現 `init config failed: vpcId is not specified: EC2MetadataError ...
status code: 401`(已在測試環境中驗證)。正是這個 hop limit 在第 10 章和第 19 章中
有詳細討論:它保護節點角色的憑證不被 pod 獲取,同時也會破壞任何依賴元資料的控制器。

創建 VPC Lattice 的 `GatewayClass` 和 `Gateway` 本身:

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

這裡 `Gateway` 的名稱不是隨意的,這正是這個任務的主要陷阱。VPC Lattice 的控制器是
按 `Gateway` 對象的名稱去尋找 Service Network 的,而不是按 `defaultServiceNetwork`
的值。如果把 `Gateway` 命名為 `mesh`,它就會永遠停留在 `Programmed: False`,並顯示
`VPC Lattice Service Network not found`,因為帳戶中的網路名稱是
`eks-task128-mesh`(已在測試環境中驗證:兩個 `Gateway` 並排放置,名稱一致的那個是
`Programmed: True`,訊息中有網路的 ARN,不一致的那個是 `not found`)。由此得出規
則:`Gateway` 的名稱 = Service Network 的名稱。

類別為 `amazon-vpc-lattice` 的 `Gateway` 會映射到 VPC Lattice 的 Service Network:
這是集群內服務之間的 east-west 連接,而不是像 `aws-alb` 那樣的外部入口(第 28
章,28.5 節)。

## 任務 5. 症狀:沒有 ReferenceGrant 的 HTTPRoute

在相鄰的 namespace 中啟動 backend:

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

`TargetGroupConfiguration` 是必須的,原因和任務 3 中一樣,同時它也展示了所有權的劃
分:這個對象位於它所屬 Service 的擁有者的 namespace 中,而不是放在路由旁邊。

路由 `rates` 位於 `eks-128` 中,卻引用了 `eks-128-backend` 中的 Service。它的父級
是類別為 `aws-alb` 的 `Gateway` `web`:

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

同樣的路由,但這次是在類別為 `amazon-vpc-lattice` 的 `Gateway` 上 - 這是一個對照
實驗,是這個任務得出結論所必需的:

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

我們不用 `kubectl -o yaml | grep -A...`:對於 CRD 對象(unstructured),
condition 的欄位是按字母順序序列化的(`reason`、`status` 排在 `type` 之前),所以
更可靠的做法是透過 `jsonpath` 直接取出需要的 condition。

帶有 `namespace` 欄位的 `backendRefs` 引用了另一個 namespace 中的 Service - 這種
引用預設是被禁止的,目的是防止 `eks-128` 中的開發者未經對方擁有者的許可就把流量導向
別人的服務(第 28 章,28.2 節)。路由 `rates` 的 `ResolvedRefs` 條件會是 `status:
"False"`,`reason: RefNotPermitted`,訊息為 `No explicit ReferenceGrant exists to
allow the reference.`

而這正是這個對照實驗要展示的結果:`rates-lattice` 的條件立即就是 `ResolvedRefs:
True`,儘管 `eks-128-backend` 中還完全沒有任何 `ReferenceGrant`(已在測試環境中驗
證)。`ReferenceGrant` 這個規則是 Gateway API 規範的一部分,但遵守它的是實現,而不
是 API 伺服器:AWS Load Balancer Controller 會檢查它,而 v1.1.0 版的 VPC Lattice
控制器不會。由此得出實際的結論:同樣的 YAML 在兩種 Gateway API 實現中,團隊之間的
信任邊界是不同的,只有在你確認過控制器行為的地方,才能把 `ReferenceGrant` 當作一種
保護來依賴。

## 任務 6. 修復:ReferenceGrant 允許跨 namespace 引用

`ReferenceGrant` 由**目標** backend 的擁有者創建 - namespace `eks-128-backend`,
而不是引用它的那一方:

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

我們用產物的第二行檢查的不是狀態,而是流量本身:來自 `backend` pod 的 `http=200`
表示整條鏈路都連接起來了 - 路由被授權解析,`ip` 類型的 target group 已創建,目標通
過了 health check。如果 `ResolvedRefs` 已經是 `True`,但 `curl` 卻回傳
`503`,等一分鐘:目標的註冊發生在 target group 出現之後。

`ReferenceGrant` 出現之後,`rates` 的 `ResolvedRefs` 條件在幾秒鐘內就變為 `True` -
控制器在下一次調諧時會重新評估被允許的引用,路由開始能解析相鄰 namespace 中的
`backend`。請注意,授予許可的是目標的擁有者 namespace:刪除 `ReferenceGrant`,路由
就會回到 `RefNotPermitted`,儘管路由本身沒有任何改動。

## 快速檢查

```bash
check_result
```
