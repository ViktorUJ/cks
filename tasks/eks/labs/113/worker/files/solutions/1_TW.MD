[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 113 - 參考解答(集群升級與回滾)

所有命令都在工作機上透過 SSH 執行。kubectl 和 aws cli 已經配置好指向實驗的集群。首先,
把集群名稱保存到一個變數裡 - 幾乎每個命令都會用到它:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## 任務 1。Namespace 與集群的起始版本

```bash
kubectl create namespace eks-113

aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

預期輸出 - `"1.35"`。這個實驗的集群刻意起始於比目前 GA 版本 `1.36` 低一個小版本的地
方,這樣你之後才能走過真正的升級與回滾。

額外內容(不會被檢查,但在升級前很有用):看看 API server 目前提供的是哪些
`apiVersion`,以便之後與升級後的版本做對比:

```bash
kubectl get --raw /apis | grep -o '"groupVersion":"[^"]*"'
```

## 任務 2。檢查升級就緒狀態

Upgrade insights 是 EKS 內建的檢查,用來找出可能阻擋升級的東西:目標版本中將被移除的
API 的使用情況,以及集群整體的健康狀況。不加 `--filter` 的集群 insights 列表包含所有
類別,包括升級就緒狀態:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks list-insights --cluster-name "$CLUSTER" \
  > /var/work/tests/artifacts/2/upgrade_insights.json
cat /var/work/tests/artifacts/2/upgrade_insights.json
```

確認 insights 中沒有 `ERROR` 狀態(它會阻擋升級,直到問題被修復):

```bash
grep '"status"' /var/work/tests/artifacts/2/upgrade_insights.json
```

如果某個 insight 的狀態是 `WARNING` - 這不會阻擋升級,但值得透過
`aws eks describe-insight --cluster-name "$CLUSTER" --id <insight-id>` 閱讀它的建議。
如果出現了 `ERROR`,先修復問題根源(通常是清單中已棄用的 `apiVersion`),然後再次執行
`aws eks list-insights` - EKS 每 24 小時刷新一次 insights,你也可以透過
`aws eks start-insights-refresh --cluster-name "$CLUSTER"` 強制刷新。

## 任務 3。將 control plane 升級到 1.36

升級一次只能往上移動一個小版本:`1.35 -> 1.36`。啟動升級並保存更新的 `id`:

```bash
UPDATE_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.36 \
  --query 'update.id' --output text)
echo "$UPDATE_ID"
```

control plane 的更新在背景中運行,可能需要 20-40 分鐘。等待 `Successful` 狀態:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$UPDATE_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

確認新版本:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

預期輸出 - `"1.36"`。此時節點和附加元件的版本還沒有變化 - 這是下一步要做的事。

## 任務 4。將核心附加元件升級到適用於 1.36 的版本

control plane 已經更新完成,但 `kube-proxy` 和 `coredns` 不會自動跟著更新 - 它們要分開
更新,更新到與新的小版本相容的版本。如果手邊沒有課程表格,可以這樣查詢確切的相容版本:

```bash
aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
```

更新這兩個附加元件(版本與集群直接起始於 `1.36` 的實驗 101 相同):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.36.0-eksbuild.14
aws eks update-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --addon-version v1.14.3-eksbuild.3
```

等待它們各自變為 `ACTIVE`:

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

檢查結果版本:

```bash
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --query 'addon.addonVersion'
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --query 'addon.addonVersion'
```

`vpc-cni` 和 `eks-pod-identity-agent` 不像 `kube-proxy` 和 `coredns` 那樣與 Kubernetes
的小版本緊密綁定,所以在這個實驗中可以先不管它們 - 但在實際運維中,仍然值得透過
`describe-addon-versions` 檢查它們的版本。

## 任務 5。檢查回滾就緒狀態

Rollback readiness insights 只會在升級之後出現,並且只存在整整 7 天 - 也就是回滾視
窗。用類別過濾器來查看它們:

```bash
mkdir -p /var/work/tests/artifacts/5
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  > /var/work/tests/artifacts/5/rollback_readiness.json
cat /var/work/tests/artifacts/5/rollback_readiness.json
```

檢查狀態 - `ERROR` 和 `UNKNOWN` 會阻擋回滾:

```bash
grep '"status"' /var/work/tests/artifacts/5/rollback_readiness.json
```

如果你剛修復了其中一個阻擋因素,又不想等每天的刷新:

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
```

## 任務 6。將 control plane 回滾到 1.35

在任務 4 中,我們把 `kube-proxy` 升級到了與 `1.36` 相容的版本。如果現在就嘗試回滾
control plane,EKS 會在呼叫 `update-cluster-version` 的那一刻重新計算 rollback
readiness insights,並在 `kube-proxy version rollback compatibility` 檢查上發現一個
`ERROR`:`kube-proxy` 的版本是 `1.36`,而 control plane 回滾到 `1.35` 之後,`kube-proxy`
就會比 control plane 更新,這違反了 version skew 政策。這正是第 39 章所說的「如果附加
元件的版本領先於目標版本,就要先回滾節點/附加元件,再回滾 control plane」的原因 - 升
級後馬上執行的 `aws eks list-insights` 還不會顯示這個問題(rollback insights 是根據集
群目前的狀態重新計算的),但在附加元件更新之後再次請求時就會出現。

正確的順序是先把 `kube-proxy` 帶回與 `1.35` 相容的版本,然後才回滾 control plane:

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

確認 kube-proxy 的 insight 變成了 `PASSING`(如果不想等一整天,可以強制重新計算):

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
sleep 30
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  --query 'insights[].{name:name,status:insightStatus.status}'
```

現在可以不加 `--force` 回滾 control plane 了 - 標準方式,和升級一樣,只是版本換成前一
個:

```bash
ROLLBACK_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.35 \
  --query 'update.id' --output text)
echo "$ROLLBACK_ID"

aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type'
```

回應中的更新類型是 `VersionRollback`,不是常規的 `VersionUpdate`。把它保存為產物:

```bash
mkdir -p /var/work/tests/artifacts/6
aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type' --output text > /var/work/tests/artifacts/6/rollback_update.txt
cat /var/work/tests/artifacts/6/rollback_update.txt
```

回滾同樣在背景中運行,可能需要 20-40 分鐘。等待 `Successful`:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

確認 control plane 已經回到 `1.35`:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

預期輸出 - `"1.35"`。回滾過程中不會動到 etcd 資料、工作負載和持久化磁碟區 - 只有
control plane 的版本會回滾,這不能取代備份。

## 快速檢查

```bash
check_result
```
