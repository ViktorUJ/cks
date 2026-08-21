[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 108 - 參考解答(AWS Load Balancer Controller:為 Service 建立 NLB)

所有指令都在工作機上透過 SSH 執行。kubectl 已經配置好指向該集群。Terraform 已經為
控制器創建了 IAM 角色(組件 `eks_lbc_irsa`,模組 `eks_v2_lbc_irsa`) - 剩下的只是取得
它的 ARN,並安裝控制器本身。

## 任務 1. Namespace `eks-108`

```bash
kubectl create namespace eks-108
```

## 任務 2. ServiceAccount 與安裝 AWS Load Balancer Controller

尋找 terraform 創建的角色的 ARN(角色名稱 `<cluster-name>-lbc-irsa`):

```bash
ROLE_ARN=$(aws iam list-roles \
  --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text)
echo "$ROLE_ARN"
```

在 `kube-system` 中創建 ServiceAccount,並附上指向該角色的註解。LBC 透過 Helm 安裝
時使用 `serviceAccount.create=false`,因此 ServiceAccount 必須事先存在:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF
```

從官方 chart 安裝控制器本身:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's/.*\///')
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "$VPC_ID"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

控制器運行在 Fargate 上(namespace `kube-system` 位於 Fargate profile 之下),而
Fargate 上物理上根本不存在 EC2 instance metadata service(IMDS) - 若沒有明確的
`vpcId`/`region`,控制器會嘗試透過 IMDS 取得 VPC ID,並陷入 `CrashLoopBackOff`,
錯誤類似 `failed to fetch VPC ID from instance metadata: ... context deadline
exceeded`。在受管理的 EC2 節點上不需要這些旗標(那裡有 IMDS 可用),但在 Fargate 上
必須始終明確傳遞它們。

確認控制器已啟動並看到該角色:

```bash
kubectl get deploy aws-load-balancer-controller -n kube-system
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml | grep role-arn
```

## 任務 3. Deployment `web`(viktoruj/ping_pong,2 個副本)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-108
kubectl rollout status deployment/web -n eks-108
```

## 任務 4. LoadBalancer 類型的 Service `web`:NLB 而非 CLB

預設情況下,in-tree cloud provider 會為 LoadBalancer 類型的 Service 創建過時的
Classic Load Balancer。註解 `aws-load-balancer-type: external` 將協調工作(
reconciliation)交給 AWS Load Balancer Controller,由它創建現代化的 Network Load
Balancer:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: eks-108
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
EOF
```

等待外部位址:

```bash
kubectl get svc web -n eks-108 -w
```

透過 AWS CLI 確認建立的確實是 NLB(類型 `network`),而不是 CLB,且 scheme 為
`internet-facing`:

```bash
HOSTNAME=$(kubectl get svc web -n eks-108 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/4/nlb.txt
cat /var/work/tests/artifacts/4/nlb.txt
```

輸出中 `Type` 應為 `network`(NLB),`Scheme` 應為 `internet-facing`。如果沒有
`aws-load-balancer-type` 這個註解,in-tree provider 會創建 `Type: classic` - 這正是
第 26 章中「要求 LoadBalancer,卻得到 CLB」的症狀。

## 任務 5. 檢查 target:Pod 的 IP,而非節點的 instance ID

`target-type: ip` 會在 target group 中註冊由 VPC CNI 分配的 Pod 位址,而不是以
`InstanceId` 表示的節點。透過 `describe-target-groups` 與
`describe-target-health` 來驗證:

```bash
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/5
{
  aws elbv2 describe-target-groups --target-group-arns "$TG_ARN"
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
} > /var/work/tests/artifacts/5/targets.txt

cat /var/work/tests/artifacts/5/targets.txt
```

檔案中 `TargetType` 應為 `ip`,且每個 target 的 `Target.Id` 應是來自
`10.10.0.0/16`(這個實驗的 VPC 子網)的位址,而不是 `i-...`(instance ID)。這正是
`target-type: ip` 的 NLB target group 該有的樣子:控制器直接註冊 Pod 的 IP,繞過
NodePort,省去了經過 kube-proxy 的額外跳轉。

## 任務 6. 診斷:成功的協調對比 AccessDenied

查看控制器日誌,觀察正常 Service 協調的樣子 - 其中應該包含所建立負載平衡器的 ARN:

```bash
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
  | grep -i 'successfully reconciled\|loadBalancerARN\|arn:aws:elasticloadbalancing' \
  | tail -n 10
```

如果 ServiceAccount 沒有附加角色(或該角色缺少必要權限),控制器將無法呼叫 ELBv2
API,日誌會出現類似 `AccessDenied: User: ... is not authorized to perform:
elasticloadbalancing:CreateLoadBalancer` 的訊息,而 Service 會停留在 `<pending>`
狀態,沒有外部位址 - 因為協調在第一次 API 呼叫時就失敗了,NLB 根本還沒被創建。

將兩個觀察結果保存到同一個產物檔案中:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== 成功的協調(真實的控制器日誌) ==="
  kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
    | grep -i 'successfully reconciled\|arn:aws:elasticloadbalancing'
  echo
  echo "=== 缺少 IAM 權限時預期的症狀(在目前這個有效角色上無法重現) ==="
  echo "AccessDenied: User: arn:aws:sts::<account>:assumed-role/<cluster>-lbc-irsa/... " \
       "is not authorized to perform: elasticloadbalancing:CreateLoadBalancer " \
       "on resource: arn:aws:elasticloadbalancing:<region>:<account>:loadbalancer/*"
  echo "出現這個錯誤時,web Service 會停留在 <pending>:EXTERNAL-IP 永遠不會出現," \
       "因為控制器無法透過 ELBv2 API 創建 NLB。"
} > /var/work/tests/artifacts/6/reconcile.txt

cat /var/work/tests/artifacts/6/reconcile.txt
```

## 快速檢查

```bash
check_result
```
