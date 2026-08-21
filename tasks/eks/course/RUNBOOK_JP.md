[Русская версия](RUNBOOK_RU.md) · [Eng version](RUNBOOK.md) · [Versión en español](RUNBOOK_ES.md) · [Version française](RUNBOOK_FR.md) · [Deutsche Version](RUNBOOK_DE.md) · [ქართული ვერსია](RUNBOOK_GE.md) · [繁體中文版](RUNBOOK_TW.md)

# EKS 診断リファレンス: 症状、原因、確認方法

[コース目次](README_JP.md) · [用語集](GLOSSARY_JP.md)

## 使い方

これは、第 45、46、47 章の「診断手順とツール」セクションを当番対応用に 1 つのファイルへまとめたものです。インシデント発生時に 3 つの章を行き来するのは不便です。
次のように使います。まず「症状からのクイックスタート」表で症状の**クラス**を特定し、該当するレイヤーを上から下へ進みます。分類はツールより重要です。`ContainerCreating` の Pod とロードバランサーからの 503 は、異なるコマンドで対処します。
ここには確認順序、チェックリスト、コマンドだけを載せています。原因の分析、仕組み、説明は第 45-47 章にあり、ナビゲーターの各行からリンクされています。

## 症状からのクイックスタート

| 見えている症状 | クラス | 確認先 |
|---|---|---|
| `kubectl get nodes` が空で、ノードがない | ノードが参加していない | [ノード](#ノードがクラスターに参加できない), [第 45 章](45/jp.md) |
| `NodeCreationFailure`, `Instances failed to join the kubernetes cluster` | ノードが参加していない | [ノード](#ノードがクラスターに参加できない), [第 45 章](45/jp.md) |
| node group が `CREATE_FAILED` または `DEGRADED` | ノードが参加していない | [ノード](#ノードがクラスターに参加できない), [第 45 章](45/jp.md) |
| kubelet ログに `node "" not found` | ノード: DNS と private DNS name | [ノード](#ノードがクラスターに参加できない), [第 45 章](45/jp.md) |
| ノードは見えるが `NotReady` | CNI の準備未完了、別レイヤー | [ノード](#ノードがクラスターに参加できない), [第 45 章](45/jp.md), 第 8 章 |
| Pod が `ContainerCreating`、`failed to assign an IP address to container` | ネットワーク: IP と ENI | [ネットワーク](#稼働中クラスターのネットワーク障害), [第 46 章](46/jp.md) |
| Pod 間または Pod-RDS で `connection timed out`、DNS は解決できる | ネットワーク: security group | [ネットワーク](#稼働中クラスターのネットワーク障害), [第 46 章](46/jp.md) |
| リクエストは送信されるが接続がハングする | ネットワーク: NACL と ephemeral ports | [ネットワーク](#稼働中クラスターのネットワーク障害), [第 46 章](46/jp.md) |
| Pod が名前解決できず readiness も通らない | ネットワーク: Pod 固有の SG | [ネットワーク](#稼働中クラスターのネットワーク障害), [第 46 章](46/jp.md) |
| DNS が断続的に動作し、タイムアウトが不規則に発生する | ネットワーク: DNS | [ネットワーク](#稼働中クラスターのネットワーク障害), [第 46 章](46/jp.md) |
| 外部名への不要な DNS 負荷 | ネットワーク: `ndots:5` の影響 | [ネットワーク](#稼働中クラスターのネットワーク障害), [第 46 章](46/jp.md) |
| target group のターゲットが `unhealthy`、502 `Bad gateway` | ネットワーク: ロードバランサー | [ネットワーク](#稼働中クラスターのネットワーク障害), [第 46 章](46/jp.md) |
| LB 配下のサービスから 503 `Service unavailable` | ネットワーク: 正常なターゲットがない | [ネットワーク](#稼働中クラスターのネットワーク障害), [第 46 章](46/jp.md) |
| `You must be logged in to the server (Unauthorized)` | アクセス: 認証 | [アクセス](#アクセス拒否-人と-pod), [第 47 章](47/jp.md) |
| `couldn't get current server API group list: Unauthorized` | アクセス: kubeconfig またはリージョン | [アクセス](#アクセス拒否-人と-pod), [第 47 章](47/jp.md) |
| `Forbidden: cannot <verb> resource` | アクセス: RBAC | [アクセス](#アクセス拒否-人と-pod), [第 47 章](47/jp.md) |
| Pod が AWS 呼び出しで `AccessDenied` を出して停止する | Pod のアクセス: STS とロール | [アクセス](#アクセス拒否-人と-pod), [第 47 章](47/jp.md) |
| Pod が `WebIdentityErr: failed to retrieve credentials` を出して停止する | Pod のアクセス: IRSA | [アクセス](#アクセス拒否-人と-pod), [第 47 章](47/jp.md) |

## ノードがクラスターに参加できない

第 45 章。症状は空の `kubectl get nodes` と `NodeCreationFailure` という 1 つですが、原因は異なるレイヤーにあります。上から下への確認順序は次のとおりです。

1. IAM レイヤー: node instance role の権限と、クラスターにおけるロールの認可（45.2 節）。
2. ネットワークレイヤー: 443 で API サーバー endpoint へ到達する経路、endpoint の種類、DNS（45.3 節）。
3. user data と bootstrap レイヤー: AL2 の `bootstrap.sh`、AL2023 の `nodeadm`/`NodeConfig`（45.4 節）。
4. kubelet レイヤー: デーモンが起動しているか、kubeconfig と証明書が正常か、登録が完了したか（45.5 節）。

考え方は、まず `describe-nodegroup` で EKS 自身に確認し、次にロール認可を確認することです。これは低コストであり、最もよく原因になります。その後に endpoint へのネットワークを確認し、最後にノード上で cloud-init と kubelet のログを確認します。「ノードがない」と `NotReady` を区別してください。kubelet が動作している状態で後者となるのは、ほとんどの場合 CNI です。これは第 8 章で扱います。

| 症状 | 考えられる原因 | 確認内容 |
|---|---|---|
| `NodeCreationFailure`、ノードがない | ノードロールが認可されていない | `aws eks list-access-entries`, `aws-auth` |
| ノードがなく、IAM は正常 | 443 で API への経路がない | SG、NAT/IGW ルート、endpoint の種類 |
| ノードがなく、private cluster | endpoint を名前解決できない | DNS、VPC の DHCP options set |
| ノードがなく、カスタム AMI | bootstrap が実行されていない | `/var/log/cloud-init-output.log` |
| ノードがなく、kubelet が停止する | kubeconfig/証明書の破損 | `journalctl -u kubelet` |
| ノードはあるが `NotReady` | CNI の準備未完了で、Pod に IP がない | `aws-node` Pod、ノードイベント（第 8 章） |
| ログに `node "" not found` | private DNS name がない | DHCP options、VPC の DNS |

```bash
# 1. node group について EKS 自身が示す内容
aws eks describe-nodegroup --cluster-name prod --nodegroup-name ng-1 \
  --query 'nodegroup.health.issues'
# 2. クラスターがノードを認識しているか
kubectl get nodes
# 3. ノードロールが認可されているか
aws eks list-access-entries --cluster-name prod
# レガシー経路: aws-auth のマッピング
kubectl -n kube-system get configmap aws-auth -o yaml
# 4. SSM Session Manager 経由でノード上の bootstrap/cloud-init ログを確認
sudo cat /var/log/cloud-init-output.log
# 5. ノード上の kubelet の状態とログ
systemctl status kubelet
journalctl -u kubelet -n 200 --no-pager
```

SSH を使わずにノードへアクセスするには SSM Session Manager を使用します。SSM agent と権限が必要です。SSM を使用できない場合は、インスタンスのコンソール出力（system log）と `/var/log` を利用できます。

## 稼働中クラスターのネットワーク障害

第 46 章。クラスターは動作し、ノードも `Ready` ですが、ネットワークにはさまざまな問題が起こり得ます。最初に症状を分類します。IP がない、接続性が切れる、DNS、ロードバランサーからの 5xx です。クラスがレイヤーとコマンドを決めます。
`describe pod` と `get pods -o wide` は低コストで、最初に IP 問題を切り分けられます。`describe-target-health` はロードバランサーの障害を即座に局所化します。VPC Flow Logs は、IP でも health check でも説明できない接続断に対する最後の手段です。レイヤーの違いを覚えておいてください。security group は stateful で ENI レベルで機能し、NACL は stateless でサブネットレベルで機能するため、NACL では ephemeral ports の戻りトラフィックを手動で許可します。

| 症状 | 考えられる原因 | 確認内容 |
|---|---|---|
| `failed to assign an IP address` | ノードまたはサブネットに空き IP がない | `describe pod`, `AvailableIpAddressCount` |
| Pod 間または Pod-RDS の timeout | SG がトラフィックを許可していない | `describe-network-interfaces` の Groups、RDS の SG |
| 接続が切れるがリクエストは送信される | NACL が ephemeral ports を遮断している | NACL の in/out ルール、VPC Flow Logs |
| DNS のタイムアウトが断続的に発生する | CoreDNS、conntrack、per-ENI throttling | CoreDNS メトリクス（第 33 章）、conntrack、PPS |
| 外部名への不要な DNS 負荷 | `ndots:5` の影響 | search domains、末尾にドットを付けた FQDN |
| LB 配下のサービスから 502 または 503 | ターゲットが `unhealthy` | `describe-target-health`、health check、SG |
| ターゲットは `unhealthy` だが Pod は稼働中 | health check のパス/ポートまたは SG | チェックのパスとポート、ロードバランサーの SG |
| Pod に DNS も readiness もない | ノードの SG ではなく Pod 固有の SG | Pod の `SecurityGroupPolicy`、53 TCP/UDP、ノード SG からの ingress |

```bash
# 1. Pod イベント: ContainerCreating と IP 割り当ての原因
kubectl describe pod <pod>
# 2. Pod の場所と配置先ノード
kubectl get pods -o wide
# 3. 特定アドレスの ENI、IP、SG
aws ec2 describe-network-interfaces \
  --filters "Name=private-ip-address,Values=<ip>" --query 'NetworkInterfaces[0]'
# 4. サブネットの空きアドレス
aws ec2 describe-subnets --subnet-ids <subnet> \
  --query 'Subnets[0].AvailableIpAddressCount'
# 5. ロードバランサーのターゲットの正常性
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
# サービスの背後に Ready な endpoint があるか
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
# 6. Pod から名前解決をテスト
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup <name>
# Pod 固有の SG: 適用モードと SG ID のエラーを確認
kubectl describe daemonset aws-node -n kube-system | grep -iE 'SECURITY_GROUP|DEMUX'
kubectl describe pod <pod> | grep -i InvalidSecurityGroupID
# 7. ノード上で VPC CNI のネットワークダンプを収集（ipamd/plugin ログ、ENI、eni-configs）
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids <instance-id> \
  --parameters 'commands=["/opt/cni/bin/aws-cni-support.sh"]'
```

ipamd の状態はローカル endpoint から直接確認することもできます。`/v1/enis` は割り当て済みの ENI と IP を、`/v1/pods` はアドレスと Pod の関連付けを表示します。

## アクセス拒否: 人と Pod

第 47 章。アクセス障害は独立した 2 軸に分かれます。当番担当者が最初に問うべきことは、どちらが壊れているかです。人または CI がクラスターに入れないのか、それとも Pod が AWS 呼び出しで `AccessDenied` を受けるのかです。
次に、拒否コードが分類を完了させます。`Unauthorized`（401）は認証の失敗です。トークンがない、期限切れ、または identity がマッピングされていません。kubeconfig、credentials、マッピング（access entry または aws-auth）で修正します。`Forbidden`（403）は認可の失敗です。identity はすでに認識されていますが、RBAC に権限がありません。Role、ClusterRole、binding で修正します。Pod からの `AccessDenied` は IRSA または Pod Identity へ進みます。「クラスターか自分か」を素早く分けるには、`aws sts get-caller-identity` が期待とは異なる identity を示す場合、問題はローカル側、つまり profile、リージョン、または credentials にあります。

| 症状 | 考えられる原因 | 確認内容 |
|---|---|---|
| `Unauthorized`、`must be logged in` | identity が誤っているかマッピングされていない | `sts get-caller-identity`, `list-access-entries` |
| `edit aws-auth` の直後に `Unauthorized` | 自身のマッピングを削除した | `get cm aws-auth`、access entry で復旧 |
| `Forbidden: cannot <verb>` | RBAC が権限を与えていない | `kubectl auth can-i`、Role と binding |
| `couldn't get server API group` | kubeconfig またはリージョンの不備 | `update-kubeconfig`, `current-context`, profile |
| IRSA の Pod で `AccessDenied` | trust policy、OIDC、SA annotation | OIDC provider、`sub`/`aud`、`role-arn` annotation |
| Pod で `WebIdentityErr` | トークンがマウントされていない、ロールが誤っている | Pod を再作成、trust policy を確認 |
| Pod Identity の Pod で `AccessDenied` | association、agent、またはトークンがない | `list-pod-identity-associations`、agent、Pod 内のトークン |

```bash
# AWS から見た実際の自分の identity
aws sts get-caller-identity
# クラスターの認証モードと accessConfig
aws eks describe-cluster --name <cluster> --query 'cluster.accessConfig'
# access entries でマッピングされている identity
aws eks list-access-entries --cluster-name <cluster>
# aws-auth の内容（モードがまだこれを使用している場合）
kubectl -n kube-system get cm aws-auth -o yaml
# authz: 自分に何が許可されているか
kubectl auth can-i --list
kubectl auth can-i get pods -n <ns>
# kubeconfig を再生成し、context を確認
aws eks update-kubeconfig --name <cluster> --region <region> --profile <profile>
kubectl config current-context
# Pod の軸: ServiceAccount のロール annotation（IRSA）
kubectl get sa <sa> -n <ns> -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# Pod Identity associations
aws eks list-pod-identity-associations --cluster-name <cluster>
# Pod Identity agent が起動しているか
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-pod-identity-agent
# Pod 内に Pod Identity token がマウントされているか（ファイルがなければ agent/association は動作していない）
kubectl exec <pod> -n <ns> -- ls /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/
```

ロックアウトされたクラスターは EKS API で復旧します。`authenticationMode=API_AND_CONFIG_MAP` を指定して `update-cluster-config` を実行し、その後 `AmazonEKSClusterAdminPolicy` を指定して `create-access-entry` と `associate-access-policy` を実行します（47.4 節）。`CONFIG_MAP` への逆戻りはできません。

## 何も一致しないときに確認するもの

- **VPC Flow Logs** は、ENI またはサブネットレベルでパケットが `ACCEPT` と `REJECT` のどちらを受けたかを記録します。`REJECT` は SG または NACL を示し、リクエスト送信後に応答パケットがない場合は stateless NACL と ephemeral ports を示します。
- **control plane logs**（api、audit、authenticator）は事後ではなく事前に有効化します。authenticator logs は到達した identity がマッピングされているかを示します（第 21 章および第 34 章）。
- **SSM 経由の `aws-cni-support.sh`** は、ipamd と plugin のログを ENI/IP の状態および設定とともに、SSH なしでノード上の `/var/log/eks_<instance-id>_<...>.tar.gz` アーカイブへ収集します。
- **`/var/log/aws-routed-eni` logs**（`ipamd.log`、`plugin.log`）は、Pod が `failed to assign an IP address` で停止し、IP を使い果たしたのか ENI が起動していないのか不明なときに、ノード上で確認します。

## ここに含まれないもの

これは各章の代替ではありません。原因の説明、レイヤーの仕組み、なぜ症状がそのように見えるかの分析はここにはなく、第 45、46、47 章にあります。ここには確認順序とコマンドだけを載せています。
コースの troubleshooting ラボ（119、120、121、および security groups for pods を扱う 126）はこのファイルには重複していません。各自の課題に従って実施してください。