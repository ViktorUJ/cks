[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 125 - 参考解答（EKS Auto Mode と自前スタックの比較）

すべてのコマンドは worker マシン上で SSH を通じて実行します。kubectl はすでにこの
クラスターに設定済みです。このクラスターは Auto Mode を有効にし、内蔵 NodePool
`general-purpose` を一つだけ持つ状態で作成されています - この lab には Fargate
profile、managed addon、Karpenter はありません。

クラスター名は kubeconfig から取得します：`list-clusters[0]` はアカウントの最初の
クラスターを返しますが、それは必ずしも自分のクラスターではありません。

```bash
export CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
echo "$CLUSTER"
```

## タスク 1. モードの確認：Auto Mode が有効になっている

```bash
mkdir -p /var/work/tests/artifacts/1
{
  echo "=== aws eks describe-cluster computeConfig ==="
  aws eks describe-cluster --name "$CLUSTER" --query 'cluster.computeConfig'
  echo
  echo "=== kubectl get nodepools ==="
  kubectl get nodepools
} > /var/work/tests/artifacts/1/automode.txt
cat /var/work/tests/artifacts/1/automode.txt
```

`computeConfig.enabled` は `true` であるべきで、`nodePools` には `general-purpose`
が含まれるべきです。`kubectl get nodepools` は同じ NodePool を通常の Kubernetes
リソースとして表示します - Auto Mode は Kubernetes API を通じて有効化された内蔵 pool
を実体化します（第 9 章）。

## タスク 2. 二つ目の内蔵 NodePool が無効になっている

```bash
kubectl get nodepools
```

一覧に `system` はありません - 内蔵 NodePool は、その名前が
`computeConfig.nodePools` に存在するときにのみクラスターリソースとして現れます。この
lab ではそこには `general-purpose` だけが記載されています。

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/twopools.txt <<'EOF'
EKS Auto Mode には general-purpose と system という二つの内蔵 NodePool があります。
system NodePool は CriticalAddonsOnly taint を持ち、クラスターにとって重要なコンポーネ
ント（例えば CoreDNS）がそれを許容します - これはそれらを通常のワークロードから分離し、
アプリケーションとリソースを競合しないようにし、general-purpose ノードの集約時に排除
されないようにする方法です。

この lab では node_pools に general-purpose だけが含まれているため、system はクラスター
リソースとして作成されません：kubectl get nodepools はそれを表示しません。これを有効化
するとは、control plane 上で computeConfig.nodePools を編集することを意味し、kubectl
でオブジェクトを作成することではありません。
EOF
cat /var/work/tests/artifacts/2/twopools.txt
```

## タスク 3. general-purpose 上のワークロードと、内蔵 NodePool を直そうとする試み

```bash
kubectl create namespace eks-125
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-125
kubectl rollout status deployment/web -n eks-125

kubectl get pods -n eks-125 -o wide
```

両方のレプリカは、Auto Mode が `general-purpose` の下で自ら立ち上げたノード上で
`Running` になります - lab 101 のベースで必要となる Fargate profile も外部 Karpenter
もありません。

内蔵 NodePool の編集を試みます。AWS は内蔵 NodePool を「enabled or disabled but not
modified」と文書化していますが、これは自分の手で確認する必要があります - admission
レベルの禁止はありません：

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "=== 内蔵 pool への kubectl patch ==="
  kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":{"cpu":"100"}}}'
  echo "編集後の limits: $(kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}')"
  echo
  echo "=== このオブジェクトの所有者は誰か ==="
  kubectl get nodepool general-purpose -o jsonpath='labels={.metadata.labels}{"\n"}'
  kubectl get nodepool general-purpose \
    -o jsonpath='managedFields managers={range .metadata.managedFields[*]}{.manager}{","}{end}{"\n"}'
  echo
  echo "=== 結論 ==="
  echo "編集は受け入れられました：コマンドは patched を返し、値はオブジェクトに残り"
  echo "ました。しかしこのオブジェクトはサービスに属しています：ラベル"
  echo "app.kubernetes.io/managed-by=eks、フィールドの所有者は eks-auto-mode です。"
  echo "サポートされている管理方法は一つだけです - computeConfig.nodePools で pool 名"
  echo "を有効化・無効化することです。この一覧を変更すると、リソースはノードとともに"
  echo "削除され、私たちの編集なしで最初から再作成されます。"
} > /var/work/tests/artifacts/3/builtin.txt
cat /var/work/tests/artifacts/3/builtin.txt
```

pool を元の状態に戻します - 自分のものではないオブジェクトに余計な `limits` を残す
必要はありません：

```bash
kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":null}}'
kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}{"\n"}'
```

注意：`kubectl delete nodepool general-purpose` も実行できてしまいますが、EKS は
このオブジェクトを再作成**しません**。その一方で pool のノードは drain されます -
クラスターは計算リソースを失ったままになります。復旧は `computeConfig` を通じてのみ
可能です（README の「削除」セクションのレシピを参照）。

## タスク 4. ノードへのアクセスがない：SSH と SSM は設計上閉じている

Auto Mode ではノード名自体が instance ID なので、`providerID` を別途解析する必要は
ありません：

```bash
NODE=$(kubectl get pods -n eks-125 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node=$NODE"
```

3 つの証拠を集めます。まず一つ目 - このインスタンスには key pair がなく（`KeyName`）、
ポート 22 で何かがリスンしているかどうかに関わらず、鍵による SSH は不可能です：

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "=== key pair とノードの image ==="
  aws ec2 describe-instances --instance-ids "$NODE" \
    --query 'Reservations[0].Instances[0].[KeyName,ImageId,PlatformDetails]' --output text
  echo "KeyName は空です（None）- このノードには key pair がありません"
  echo
  echo "=== SSM：接続なし ==="
  aws ssm get-connection-status --target "$NODE" --output json
  echo "SSM のインベントリ（このノードはここにあってはならない）："
  aws ssm describe-instance-information \
    --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
} > /var/work/tests/artifacts/4/nossh.txt
```

ここでは `aws ssm start-session` を使わないでください：worker マシンには
`ssm:StartSession` 権限がないため、このコマンドは `AccessDeniedException` を返します -
これはノードについてではなく、worker のポリシーについての事実です。このタスクの問いに
答えるのは、`notconnected` ステータスを返す `get-connection-status` です。

3 つ目の証拠は逆方向のものです：ホストはクラスターから隔離されていません。`/` を
マウントする `hostPath` を持つ特権 pod がノードのファイルシステムを読み取ります：

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostprobe
  namespace: eks-125
spec:
  nodeName: $NODE
  restartPolicy: Never
  containers:
  - name: p
    image: busybox
    command: ["sh","-c","cat /host/etc/os-release; echo ---; ls /host/bin | head -5"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: h
      mountPath: /host
  volumes:
  - name: h
    hostPath:
      path: /
EOF

kubectl wait --for=condition=Ready pod/hostprobe -n eks-125 --timeout=90s 2>/dev/null
sleep 5
{
  echo
  echo "=== 特権 pod から見たホスト ==="
  kubectl logs hostprobe -n eks-125
  echo
  echo "=== 結論 ==="
  echo "SSH は不可能です（KeyName の key pair がない）、SSM は接続されていません"
  echo "（notconnected）- operator にはノードへのアクセスがありません。しかし"
  echo "Bottlerocket の image は特権 pod から読み取れます：Auto Mode は operator の"
  echo "門を閉じますが、cluster-admin の門は閉じません。後者は Pod Security Admission"
  echo "と admission ポリシーが担います（第 19 章と 22 章）。"
} >> /var/work/tests/artifacts/4/nossh.txt

kubectl delete pod hostprobe -n eks-125
cat /var/work/tests/artifacts/4/nossh.txt
```

Auto Mode のノードは read-only root と enforcing モードの SELinux を持つ
Bottlerocket で、シェルもパッケージマネージャーもなく、ノードの最大寿命は 21 日で
自動的に置き換えられます（第 9 章）。おなじみの SSH や SSM のツールでデバッグすることは
原理的に不可能です - それが最小限の運用の代償です。

## タスク 5. 明示的な limits を持つ独自の NodePool

内蔵 pool には `limits` がありません - 需要が無制限に増加すると、上限なく成長して
しまいます（第 9 章、第 9.7 節）。あなた自身の NodePool は内蔵の `NodeClass`
`default` を参照し、自分で制限を設定します：

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: custom-limited
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: ["c", "m", "r"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
  limits:
    cpu: "10"
    memory: 10Gi
EOF

kubectl get nodepool custom-limited
```

独自の NodePool は内蔵 pool の制限（C/M/R のみ、on-demand のみ、generation 5+）を
継承しません - `limits` を含めて自分の手で設定する必要があります。そうしないと pool
は上限なく成長してしまいます（第 9 章、第 9.7 節）。

## クイックチェック

```bash
check_result
```
