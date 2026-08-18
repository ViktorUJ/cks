[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 113 - 参考解答(クラスタのアップグレードとロールバック)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl と aws cli はすでに
このラボのクラスタ向けに設定されています。まずクラスタ名を変数に保存してください - ほぼ
すべてのコマンドで必要になります:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## タスク 1。Namespace とクラスタの開始バージョン

```bash
kubectl create namespace eks-113

aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

期待される出力 - `"1.35"`。このラボのクラスタは意図的に現行の GA バージョン `1.36` より
1 マイナー低いところから始まります。これにより後で実際のアップグレードとロールバックを
一通り経験できます。

補足(検証対象ではありませんが有用です。アップグレード前に):API server が現在提供して
いる `apiVersion` を見て、後でアップグレード後のバージョンと比較してください:

```bash
kubectl get --raw /apis | grep -o '"groupVersion":"[^"]*"'
```

## タスク 2。アップグレード準備状況の確認

upgrade insights は、アップグレードをブロックしうるものを探す EKS 組み込みのチェックで
す:対象バージョンで削除される API の使用状況や、クラスタ全体の健全性です。`--filter`
なしのクラスタ insights の一覧には、アップグレードを含むすべてのカテゴリが含まれます:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks list-insights --cluster-name "$CLUSTER" \
  > /var/work/tests/artifacts/2/upgrade_insights.json
cat /var/work/tests/artifacts/2/upgrade_insights.json
```

insights の中に `ERROR` ステータスがないことを確認します(修正されるまでアップグレード
をブロックします):

```bash
grep '"status"' /var/work/tests/artifacts/2/upgrade_insights.json
```

いずれかの insight が `WARNING` ステータスの場合 - これはブロッカーではありませんが、
`aws eks describe-insight --cluster-name "$CLUSTER" --id <insight-id>` で推奨事項を読ん
でおく価値があります。`ERROR` がある場合は原因(通常はマニフェスト内の非推奨
`apiVersion`)を修正し、`aws eks list-insights` を再実行してください - EKS は insights を
24 時間ごとに更新しますが、`aws eks start-insights-refresh --cluster-name "$CLUSTER"` で
強制的に更新することもできます。

## タスク 3。control plane を 1.36 にアップグレードする

アップグレードは一度に 1 マイナーしか進みません:`1.35` -> `1.36`。開始してアップデート
の `id` を保存します:

```bash
UPDATE_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.36 \
  --query 'update.id' --output text)
echo "$UPDATE_ID"
```

control plane の更新はバックグラウンドで進み、20-40 分かかることがあります。ステータス
`Successful` を待ちます:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$UPDATE_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

新しいバージョンを確認します:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

期待される出力 - `"1.36"`。この時点ではノードと add-on のバージョンはまだ変わっていま
せん - それが次のステップです。

## タスク 4。コア add-on を 1.36 用のバージョンにアップグレードする

control plane は更新されましたが、`kube-proxy` と `coredns` は自動的には追従しません -
これらは別途、新しいマイナーに互換なバージョンへ更新する必要があります。正確な互換バー
ジョンは次のように確認できます(コースの表が手元にない場合):

```bash
aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
```

両方の add-on を更新します(ラボ 101 と同じバージョン。そこではクラスタが最初から
`1.36` で始まります):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.36.0-eksbuild.14
aws eks update-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --addon-version v1.14.3-eksbuild.3
```

それぞれについて `ACTIVE` を待ちます:

```bash
for addon in kube-proxy coredns; do
  while true; do
    status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$addon" \
      --query 'addon.status' --output text)
    echo "$addon status=$status"
    [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
    sleep 10
  done
done
```

結果のバージョンを確認します:

```bash
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --query 'addon.addonVersion'
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --query 'addon.addonVersion'
```

`vpc-cni` と `eks-pod-identity-agent` は `kube-proxy` や `coredns` ほど厳密にはKubernetes
のマイナーバージョンに結びついていないため、このラボの範囲ではそのままにしておいて構いま
せん - ただし実際の運用ではやはり `describe-addon-versions` でバージョンを確認しておく
価値があります。

## タスク 5。ロールバック準備状況の確認

rollback readiness insights はアップグレードの後にだけ現れ、ロールバックの期限である
7 日間だけ存在します。カテゴリフィルタを付けて確認します:

```bash
mkdir -p /var/work/tests/artifacts/5
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  > /var/work/tests/artifacts/5/rollback_readiness.json
cat /var/work/tests/artifacts/5/rollback_readiness.json
```

ステータスを確認します - `ERROR` と `UNKNOWN` はロールバックをブロックします:

```bash
grep '"status"' /var/work/tests/artifacts/5/rollback_readiness.json
```

ブロッカーの一つを直前に修正していて、日次更新を待ちたくない場合:

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
```

## タスク 6。control plane を 1.35 にロールバックする

タスク 4 で `kube-proxy` を `1.36` 互換バージョンにアップグレードしました。今すぐ
control plane をロールバックしようとすると、EKS は `update-cluster-version` が呼ばれた
時点で rollback readiness insights を再計算し、`kube-proxy version rollback
compatibility` チェックで `ERROR` を検出します:`kube-proxy` のバージョン `1.36` は、
control plane が `1.35` にロールバックした後は control plane より新しくなってしまい、
version skew ポリシーに違反します。これがまさに第 39 章で「add-on のバージョンが対象
バージョンより先行している場合は、control plane より先にノード/add-on をロールバックす
る」と述べている理由です - アップグレード直後の `aws eks list-insights` ではまだこの問
題は見えません(rollback insights はクラスタの現在の状態に対して再計算されるため)が、
add-on 更新後に再度取得すると現れます。

正しい順序は、まず `kube-proxy` を `1.35` 互換バージョンに戻し、その後で control plane
をロールバックすることです:

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.35.3-eksbuild.13

while true; do
  status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
    --query 'addon.status' --output text)
  echo "kube-proxy status=$status"
  [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
  sleep 10
done
```

kube-proxy の insight が `PASSING` になったことを確認します(1 日待ちたくない場合は強制
的に再計算できます):

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
sleep 30
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  --query 'insights[].{name:name,status:insightStatus.status}'
```

これで `--force` なしで control plane をロールバックできます - アップグレードと同じ標
準的な方法ですが、対象は 1 つ前のバージョンです:

```bash
ROLLBACK_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.35 \
  --query 'update.id' --output text)
echo "$ROLLBACK_ID"

aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type'
```

レスポンス内のアップデートの種類は、通常の `VersionUpdate` ではなく `VersionRollback`
です。これをアーティファクトとして保存します:

```bash
mkdir -p /var/work/tests/artifacts/6
aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type' --output text > /var/work/tests/artifacts/6/rollback_update.txt
cat /var/work/tests/artifacts/6/rollback_update.txt
```

ロールバックもバックグラウンドで進み、20-40 分かかることがあります。`Successful` を待ち
ます:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

control plane が `1.35` に戻ったことを確認します:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

期待される出力 - `"1.35"`。ロールバック中も etcd のデータ、ワークロード、永続ボリューム
は変更されません - control plane のバージョンだけが戻るのであり、これはバックアップの
代わりにはなりません。

## クイックチェック

```bash
check_result
```
