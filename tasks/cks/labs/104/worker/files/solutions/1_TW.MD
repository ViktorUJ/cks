[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 104 - 參考解答：RBAC、ServiceAccount token 與 anonymous API

> 除非步驟中另有說明，否則請在工作機上執行指令。Namespace
> `security-104` 已經存在。
>
> 在考試中，`k`(`alias k=kubectl`)與它的 bash-completion 已經在 SSH 主機上設定好 -
> 不要花時間去設定它們，直接使用 `k` 即可(參見第 33.6 章)。

## 1. `auditor` 對 Pod 的最小存取

在考試中，手寫典型 RBAC 物件的完整 YAML 是浪費時間：
`kubectl create` 只需各一條指令就能分別產生 ServiceAccount/Role/RoleBinding:

```bash
k create sa auditor -n security-104
k create role pod-observer -n security-104 --resource=pods --verb=get,list,watch
k create rolebinding auditor-pod-observer -n security-104 \
  --role=pod-observer --serviceaccount=security-104:auditor

k auth can-i list pods -n security-104 \
  --as=system:serviceaccount:security-104:auditor
k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:auditor # 必須是 no
```

## 2. ServiceAccount 的 projected token

TokenRequest volume 會簽發短效的 token；一般的自動掛載已停用。
我們不固定 `audience: kubernetes.default.svc`：對 kubeadm 來說，這不一定是
API server 會接受的值。如果省略 `audience`,kubelet 會使用 API server
預設的 identifier。只有在檢查過 control-plane 上的
`--api-audiences`(或 `--service-account-issuer` 的預設值)之後，才可以指定單獨的 audience。
`expirationSeconds` 必須在 `600`-`3600` 的範圍內(含邊界)- Kubernetes API
會把 `serviceAccountToken` projected source 中小於 `600` 秒的任何值視為 invalid 而拒絕，
不論 manifest 中怎麼寫。

在考試中不需要憑記憶回想 `projected.sources[].serviceAccountToken` 的精確語法 -
它在 `kubernetes.io/docs` 的 Concepts → Storage →
[Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/) 一節中，位於
標題 **"serviceAccountToken projected volumes"** 之下(那裡有帶有這個
volume 的現成 Pod 範例 - 請從那裡取用結構，而不是從零開始寫)。`kubectl run` 無法透過旗標加入
這樣的 volume - 所以我們透過 `--dry-run=client -o yaml` 產生 Pod 的骨架，並在
`vim` 中只補上從文件範例複製來的必要欄位：

```bash
k create sa api-client -n security-104
k run token-client -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > token-client.yaml
vim token-client.yaml
```

```yaml
# 在 Pod 的 spec 中加入(containers/image/command 已由 kubectl run 產生):
spec:
  serviceAccountName: api-client              # 加入
  automountServiceAccountToken: false         # 加入
  containers:
  - name: token-client
    volumeMounts:                             # 加入
    - name: api-token                         # 加入
      mountPath: /var/run/secrets/tokens       # 加入
      readOnly: true                          # 加入
    ...
  volumes:                                    # 加入
  - name: api-token                           # 加入
    projected:                                # 加入
      sources:                                # 加入
      - serviceAccountToken:                  # 加入
          path: api-token                     # 加入
          expirationSeconds: 3600             # 加入
```

```bash
k apply -f token-client.yaml
k wait -n security-104 --for=condition=Ready po/token-client --timeout=120s
k exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token
# 檔案存在 - 如果 manifest 與文件中的範例一致,就是 kubelet 簽發的

k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:api-client
# no
```

我們檢查的不只是檔案是否存在，還要確認所掛載的 projected token
確實會以預期的 ServiceAccount 通過驗證，方法是把它送進 `TokenReview`:

```bash
TOKEN=$(k exec -n security-104 token-client -- cat /var/run/secrets/tokens/api-token)

k create -o jsonpath='{.status.authenticated}{" "}{.status.user.username}{"\n"}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: $TOKEN
EOF
# true system:serviceaccount:security-104:api-client
```

對於本實驗，這項檢查是必須的：檔案存在本身並不能證明
projected token 有效，並以預期的 ServiceAccount 通過驗證。`TokenReview`
必須回傳 `authenticated: true` 以及 username
`system:serviceaccount:security-104:api-client`。

在考試中，除非題目要求，否則不需要另外執行 `TokenReview`:
那裡只需要快速建立正確的 projected token volume，並以具體任務所需的
方式檢查結果。這裡的 `TokenReview` 是學習用的 verification 檢查，
同時也符合本實驗的驗收標準。

## 3. 沒有 API token 的 Pod

在 ServiceAccount 與 Pod 上都停用自動掛載：這樣即使之後
範本或 ServiceAccount 被修改，保護依然有效。

`kubectl create serviceaccount` 沒有 `automountServiceAccountToken` 的旗標 - 先建立，
再立刻 patch:

```bash
k create sa no-token-sa -n security-104
k patch sa no-token-sa -n security-104 -p '{"automountServiceAccountToken":false}'
k run no-token -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > no-token.yaml
vim no-token.yaml
```

```yaml
# 在 Pod 的 spec 中加入:
spec:
  serviceAccountName: no-token-sa       # 加入
  automountServiceAccountToken: false   # 加入
  containers:
  - name: no-token
    ...
```

```bash
k apply -f no-token.yaml
k wait -n security-104 --for=condition=Ready po/no-token --timeout=60s
k get po no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'

# 在 runtime 層級確認,而不只是在 YAML 規格層級:容器中
# 確實沒有 token 檔案。
k exec -n security-104 no-token -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - 檔案不存在,exec 本身執行成功
```

也不要另外掛載 `type: kubernetes.io/service-account-token` 的 legacy `Secret` -
即使停用了 automount，這樣的 Secret 仍然可以透過
`volumes[].secret` 手動掛載，這時 Pod 在 automount 欄位上形式上是「沒有 token」，但實際上
容器內仍然有有效的 API token。

## 4. 移除 wildcard 權限

我們同時刪除 binding(主體不再取得存取權)與 ClusterRole 本身(不讓危險的
範本留下來被重複使用):

```bash
k delete clusterrolebinding legacy-operator-admin
k delete clusterrole legacy-operator-admin
k auth can-i get secrets -n security-104 \
  --as=system:serviceaccount:security-104:legacy-operator # 必須是 no
```

## 5. 停用 anonymous-auth

單純的 `--anonymous-auth=false` 在這裡不適用：kubeadm `release-1.36` 產生的
kube-apiserver static Pod，在 `/livez` 與
`/readyz` 上使用 HTTPS liveness/readiness/startup probes，而 kubelet 的 HTTP probes 不會傳遞 client credentials - 完全停用
anonymous access 時，這些請求會得到 `401`,kubelet 就會開始認為 kube-apiserver
不健康(這又會連帶破壞依賴 API
server 穩定運作的任務 9)。因此我們改用帶有 `anonymous.conditions` 的 `AuthenticationConfiguration`,
把 anonymous access 只限制在三個 health 路徑。在考試中，不要在
每個指令前加 `sudo` - 一次切換成 root(`sudo -i`)，這樣更快：

```bash
ssh control-plane
sudo -i
cat > /etc/kubernetes/authentication-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

修改 static manifest：完全移除 `--anonymous-auth=true`(不能與
`--authentication-config` 並存 - 如果兩者都設定，kube-apiserver 會拒絕啟動),
加入 `--authentication-config`，並為新的
設定檔加入 `hostPath` volume/volumeMount - kube-apiserver 從節點的檔案
系統讀取 `authentication-config.yaml`，所以這個檔案必須透過 volumeMount 在 container 內可見，而不是
只存在於主機上：

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# 在 command 陣列中:
# - 刪除 "- --anonymous-auth=true" 這一行
# - 加入一行,縮排與其他參數相同:
#   - --authentication-config=/etc/kubernetes/authentication-config.yaml
# 在容器的 volumeMounts 中(縮排與相鄰的元素相同):
#   - mountPath: /etc/kubernetes/authentication-config.yaml
#     name: authentication-config
#     readOnly: true
# 在 Pod 的 volumes 中(縮排與相鄰的元素相同):
#   - hostPath:
#       path: /etc/kubernetes/authentication-config.yaml
#       type: File
#     name: authentication-config
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` 會強制立即重建 static Pod - 在考試中
比等待 kubelet 自己注意到檔案變更更快(通常是幾秒鐘，但不
保證是立刻):

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS 必須變成 Running - 如果還沒有,請等幾秒鐘再重試
```

檢查這三種行為：`/version` 拒絕匿名請求，而 `/livez`/`/readyz` -
接受：

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401 - anonymous access 已關閉
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/livez"   # 200 - health probe 正常運作
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/readyz"  # 200 - health probe 正常運作
```

對 `/readyz` 的已驗證請求(透過已經設定好的 kubectl context)
繼續以完全相同的方式運作 - `AuthenticationConfiguration.anonymous.conditions`
只是「擴大」anonymous 請求對特定路徑的存取，而不會縮小
已驗證用戶端的存取：

```bash
k get --raw=/readyz # ok
```

沒有限制性授權的 authentication 毫無意義 - 請確認
static Pod 上的 `--authorization-mode` 仍然是 `Node,RBAC`，且不包含 `AlwaysAllow`
(kubeadm 預設就是如此，但仍應確認沒有任何東西更動了這個旗標):

```bash
k get po -n kube-system -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep authorization-mode
# --authorization-mode=Node,RBAC
```

另外稽核 subjects 指向匿名使用者
或群組的 ClusterRoleBinding - 叢集中刻意留下了一個這樣的 lab-owned 綁定：

```bash
k get clusterrolebinding -o json | jq -r \
  '.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name == "system:unauthenticated")] | length > 0) | .metadata.name'
# system:public-info-viewer
# lab104-unintended-anonymous-access
```

`system:public-info-viewer` 是標準的 kubeadm 綁定：它同樣指向
`system:unauthenticated`，但它的 ClusterRole 只允許對
non-resource URL `/livez`、`/readyz`、`/healthz`、`/version`、`/version/` 的 read-only `GET`，而不是一般的
Kubernetes 資源 - 這是 default Kubernetes RBAC，是 bootstrap 必要的一部分，不要動
它。這與本任務中的 `anonymous.conditions` 不同：那個清單
限制的是在哪些路徑上，請求在 authentication 階段才會取得 anonymous identity
(那裡只有 `/livez`/`/readyz`/`/healthz`)- `/version` 匿名存取會回傳
`401`，正是因為那裡不會指派 anonymous identity，而不是因為
`system:public-info-viewer` 在那裡權限不足。`lab104-unintended-anonymous-access` -
是刻意設置的 lab-owned 發現：它的 ClusterRole `lab104-anonymous-debug-access` 提供
完整的 RBAC `get`/`list`，針對整個叢集的 `pods`/`secrets`/`configmaps`，也就是「任何」
匿名請求都能讀取它們。我們把兩個物件都刪除，就像任務 4/7 那樣：

```bash
k delete clusterrolebinding lab104-unintended-anonymous-access
k delete clusterrole lab104-anonymous-debug-access
```

我們以「恰好是未經驗證的 identity」的身分做 negative control，來確認已撤銷
(`system:anonymous` + 群組 `system:unauthenticated`，再沒有別的)，方法是
`SubjectAccessReview` - 它由 admin context 建立，因此不必
人為擴大群組清單：

```bash
for R in pods secrets configmaps; do
  for NS in $(k get ns -o jsonpath='{.items[*].metadata.name}'); do
    ALLOWED=$(k create -o jsonpath='{.status.allowed}' -f - <<EOF
apiVersion: authorization.k8s.io/v1
kind: SubjectAccessReview
spec:
  user: system:anonymous
  groups: ["system:unauthenticated"]
  resourceAttributes:
    namespace: $NS
    resource: $R
    verb: get
EOF
    )
    printf '%-12s %-24s %s\n' "$R" "$NS" "$ALLOWED"
  done
done
# 每一行都預期為 false
```

不要在 `can-i --as=system:anonymous` 中加入 `--as-group=system:authenticated`：真實的
未經驗證請求不屬於這個群組，加了之後檢查就不再反映
真正的 anonymous identity。我們逐一檢查每個 namespace，因為
RoleBinding 只在它自己的 namespace 中有效：沒有 cluster-wide 綁定，並不
證明沒有本地綁定，而驗收標準禁止在任何 namespace 中存取。

最後執行 `check_result`。

## 6. 透過 env 在 `/proc/1/environ` 洩漏 Secret：改用 volume

`app-vulnerable` 透過 `envFrom` 取得 `db-creds`，因此這個值會進入
容器 PID 1 行程的 environment。任何有權限對這個 Pod 執行 `kubectl exec` 的人，
都可以直接從 `/proc` 讀取這個 secret，不需要存取 Kubernetes API，也不需要
`get secrets` 的 RBAC:

```bash
mkdir -p /var/work/tests/artifacts/6
k exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | grep DB_PASSWORD | tee /var/work/tests/artifacts/6/env-leak-before.txt
```

我們儲存的正是行程環境中的 `DB_PASSWORD=<真實的值>` 這一行，而不是
沒有值的單純文字 `DB_PASSWORD` - checker 會自己把它與 Secret `db-creds` 的
實際值比對，不需要自己另外計算並比較這個值。

以相同的名稱重新建立 Pod：移除 `envFrom`，把同一個 Secret 掛載為 volume
`db-creds-vol` 到 `/etc/secrets`,read-only，並帶有 `defaultMode: 0400`(十進位 `256`,
就像 `kubectl get pod -o json` 顯示的那樣)。`0400` 是只有容器內檔案擁有者
可以讀取；應用程式行程本身仍然必須以這個 UID 執行，否則
它無法讀取檔案。

這個欄位是不可變的；必須刪除 Pod 並以相同的名稱重新建立。同樣地，用 `--dry-run` 產生骨架，再在 `vim` 中補上 volume,
比寫完整的 YAML 更省事：

```bash
k run app-vulnerable -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > app-vulnerable-fixed.yaml
vim app-vulnerable-fixed.yaml
```

```yaml
# 在 Pod 的 spec 中加入:
spec:
  automountServiceAccountToken: false     # 加入
  containers:
  - name: app-vulnerable
    volumeMounts:                         # 加入
    - name: db-creds-vol                  # 加入
      mountPath: /etc/secrets             # 加入
      readOnly: true                      # 加入
    ...
  volumes:                                # 加入
  - name: db-creds-vol                    # 加入
    secret:                               # 加入
      secretName: db-creds                # 加入
      defaultMode: 0400                   # 加入
```

```bash
k delete pod app-vulnerable -n security-104
k apply -f app-vulnerable-fixed.yaml
k wait -n security-104 --for=condition=Ready po/app-vulnerable --timeout=120s
```

我們確認三項最終的屬性，而不只是「environment 中沒有 secret」：檔案
權限恰好是 `400`(而不是只要在某處包含子字串 `400`)，而且更重要的是，應用程式
仍然確實能讀取 secret 的值 - 否則 hardening 可能會悄悄地
破壞應用程式本身的功能：

```bash
k exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# 沒有找到任何東西 - 這是預期的

k exec -n security-104 app-vulnerable -- stat -L -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400 - 正是這個值,而不是某處包含 "400" 的任意文字。旗標 -L
# 是必須的:secret volume 是透過符號連結鏈("..data")掛載的,沒有 -L 時
# stat 會顯示符號連結本身的 mode(在 Linux 中永遠是 777),而不是實際檔案的。

# Positive control:應用程式行程必須確實能夠讀取 secret 的值。
k exec -n security-104 app-vulnerable -- cat /etc/secrets/DB_PASSWORD
# 必須與修正之前 env-leak-before.txt 中的值相符
```

`defaultMode: 0400` 防止同一個 Pod 上的其他 UID 讀取(例如沒有所需 UID 的
相鄰 sidecar-container)，但它不能取代 etcd 的 encryption at rest，也不會妨礙
以預期 UID 執行的行程讀取檔案本身 - mount 允許的正是這件事。
另外請確認 `db-creds` 沒有同時透過某種「第二種」方式掛載
(例如還透過 `projected` volume)- 必須恰好只剩一個
掛載這個 Secret 的 volume。

最後執行 `check_result`。

## 7. 稽核並撤銷隱藏的 RBAC privilege escalation 路徑

`build-agent-hidden-privesc` 不含 wildcard `*`，但 `impersonate`/`bind`/`escalate`/
CSR-approval 是另一類危險的 verbs：它們不會擴大可見的
資源清單，而是讓人能夠**以他人的名義行動**或**替自己授予
額外的權限**。在這個版本的 fixture 中，ClusterRole 還包含針對 `clusterroles`/`clusterrolebindings` 的基本
`create`/`update` - 沒有它們，`bind`/`escalate`
就是不完整的 escalation primitives(RBAC 要求「要麼」已經擁有該角色中的權限，「要麼」
在實際嘗試建立/更新 Role/Binding 的前提下，明確擁有 `escalate`/`bind`)。
找出所有 ClusterRole 允許任何一個危險 verbs 的 ClusterRoleBinding。我們不從
ClusterRole 出發(叢集中有幾十個，包括標準的 `system:*`)，而是從
ClusterRoleBinding 出發 - `kubectl get clusterrolebinding` 預設就會顯示
`ROLE` 欄位(格式為 `ClusterRole/<名稱>`)，而 `-o wide` 還會加上 `USERS`/`GROUPS`/
`SERVICEACCOUNTS` - 不需要 custom-columns，也不需要 YAML:

```bash
mkdir -p /var/work/tests/artifacts/7
k get clusterrolebinding -o wide | grep -v system:
# build-agent-hidden-privesc   ClusterRole/build-agent-hidden-privesc   ...   security-104/build-agent
```

對每個候選者，以人類可讀的方式查看它的 ClusterRole，不用 `jq`/`grep` 去搜尋 YAML -
`kubectl describe` 會自己用表格印出 verbs，馬上就能看到 `impersonate`/`bind`/
`escalate`，以及針對 `certificatesigningrequests/approval` 的獨立規則：

```bash
k describe clusterrole build-agent-hidden-privesc
# PolicyRule 表格中的 Verbs 會顯示 impersonate / bind / escalate / update
# (針對 certificatesigningrequests/approval)- 肉眼就能看出這個角色很危險
```

把 ClusterRoleBinding 的名稱(不是 ClusterRole - 它們可能不相同，在這個實驗中
只是剛好相同)儲存到 artifact:

```bash
echo build-agent-hidden-privesc > /var/work/tests/artifacts/7/dangerous-bindings-before.txt
cat /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` 必須出現在最終的檔案中(作為 ClusterRoleBinding 的名稱，
而不是 ClusterRole)。我們刪除的正是這個 ClusterRoleBinding(以及 ClusterRole，不讓範本
留下來被重複使用)，不動 `system:*` bindings，它們給
Kubernetes 核心元件提供必要的 `impersonate`/CSR 存取：

```bash
k delete clusterrolebinding build-agent-hidden-privesc
k delete clusterrole build-agent-hidden-privesc
```

確認「所有」宣稱的危險權限都已撤銷，而不只是其中一部分。有兩個細節：
fixture 一次對三種資源類型授予 `impersonate`(`users`/`groups`/`serviceaccounts`)-
只檢查 `users` 並不能證明另外兩個已被撤銷；而且 `kubectl auth
can-i` 中的 `TYPE/NAME` 是 resourceName,而不是 subresource(`kubectl auth can-i --help` 明確顯示
範例 "jobs.batch/bar" - 檢查字面上名為 `bar` 的物件)，因此對於
`certificatesigningrequests/approval`，需要單獨的旗標 `--subresource=approval`，而不是
斜線：

```bash
k auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate groups --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate serviceaccounts -n security-104 --as=system:serviceaccount:security-104:build-agent
k auth can-i bind clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i update certificatesigningrequests --subresource=approval --as=system:serviceaccount:security-104:build-agent
k auth can-i approve signers/kubernetes.io/kube-apiserver-client --as=system:serviceaccount:security-104:build-agent
# no / no / no / no / no / no / no
```

最後執行 `check_result`。

## 8. Namespace 層級的 baseline：不帶 automount 的 `default` SA

任務 3 是針對性地停用 automount，在具體的 Pod 及其自己的 SA 上。這裡
需要系統性的 baseline：在 namespace 中建立任何 Pod「之前」，先修改 namespace 的 `default` SA,
讓任何新的 workload 預設都不會取得 token，即使開發者
忘了在 manifest 中寫明確的欄位也一樣。

ServiceAccount `default` 是由獨立的 controller 在 Namespace 出現之後非同步建立的 -
`kubectl wait` 能夠等待物件的出現(`--for=create`)，不只是
它的 condition，因此不需要手動重試，也不需要自製的迴圈：

```bash
k create namespace security-104-baseline
k wait -n security-104-baseline --for=create sa/default --timeout=30s

k -n security-104-baseline patch sa default \
  -p '{"automountServiceAccountToken":false}'
k -n security-104-baseline get sa default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

建立一個「既不」指定 `serviceAccountName`，「也不」指定 `automountServiceAccountToken` 的 Pod -
這是現實中最常見的情況，也就是開發者根本沒有想到 SA。欄位
`automountServiceAccountToken` 必須在 Pod 的 spec 中「不存在」- 明確指定 `false`
只能證明 Pod 本身的針對性設定(就像任務 3 那樣)，而不能證明
namespace 層級的 baseline 確實有效。

這裡甚至不需要 `--dry-run` - 因為不會對 Pod 加入任何關於 SA/automount 的欄位，
不帶旗標的 `kubectl run` 就會直接建立出恰好需要的東西：

```bash
k run implicit-default-sa -n security-104-baseline --image=busybox:1.36 --command -- sh -c "sleep 3600"
k wait -n security-104-baseline --for=condition=Ready po/implicit-default-sa --timeout=60s
k get po implicit-default-sa -n security-104-baseline -o jsonpath='{.spec.serviceAccountName}{"\n"}'
# default

k get po implicit-default-sa -n security-104-baseline \
  -o jsonpath='{.spec.automountServiceAccountToken}{"\n"}'
# 輸出為空 - 欄位在 spec 中不存在,而不是被設為 false

k exec -n security-104-baseline implicit-default-sa -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - 檔案不存在,而且 exec 本身執行成功(不同於對不存在的檔案
# 單純執行 "cat",cat 的 exit code 也不是零,但原因不同 - test ! -e 做的
# 正是需要的那項檢查,而且必須單獨要求它本身的成功,
# 而不是只看「任何錯誤 = 檔案不存在」)
```

SA 的值只有在 Pod 自己沒有覆寫它時才有效。如果同一個 namespace
需要帶有 API 存取的 Pod，請在確認確實需要存取之後，在
具體的 manifest 中明確加入 `automountServiceAccountToken: true` - 不要把整個 namespace 的
`default` SA baseline 改回 `true`。也不要透過 `volumes[].secret` 手動掛載舊的
(legacy)`type: kubernetes.io/service-account-token` 的 `Secret` -
無論 automount 怎麼設定，這都會讓 Pod 取得有效的 API token。

最後執行 `check_result`。

## 9. 整合任務：偵測危險的 RBAC 變更 → audit log → containment

任務 1-8 收斂了 `build-agent` 自己可用的具體 privilege escalation 路徑
(wildcard、impersonate/bind/escalate、automount)。這裡需要的是另一層防護 -
偵測**由管理員授予的危險 RBAC grant**(錯誤、由於
被入侵的自動化，或惡意造成)，而不只是 RBAC 目前的快照。
連線到 control-plane，並準備最小的 audit backend:

```bash
ssh control-plane
sudo -i
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings"]
- level: Metadata
EOF
```

RBAC 規則放在第一位 - 較具體的規則必須在通用的
catch-all 之前，否則 `Metadata` 會先攔截事件。整個 policy 層級的 `omitStages: [RequestReceived]`
會去掉請求處理之前多餘的記錄 - 它沒有
`requestObject`/`responseStatus`，checker 反正也會丟棄這類記錄(`stage ==
"ResponseComplete"`)，而且由於對叢集所有其他請求都有 catch-all `Metadata` 規則，
這個階段會讓 audit.log 的體積加倍，卻沒有任何好處。

修改 static manifest：加入 `--audit-policy-file`/`--audit-log-path`，以及用於 policy 與 log 目錄的 hostPath
volume/volumeMount - 做法與任務 5 中處理
`authentication-config.yaml` 時相同：

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/9-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# 在 command 陣列中加入幾行,縮排與其他參數相同:
#   - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
#   - --audit-log-path=/var/log/kubernetes/audit/audit.log
# 在容器的 volumeMounts 中(縮排與相鄰的元素相同):
#   - mountPath: /etc/kubernetes/audit
#     name: audit-policy
#     readOnly: true
#   - mountPath: /var/log/kubernetes/audit
#     name: audit-log
# 在 Pod 的 volumes 中(縮排與相鄰的元素相同):
#   - hostPath:
#       path: /etc/kubernetes/audit
#       type: Directory
#     name: audit-policy
#   - hostPath:
#       path: /var/log/kubernetes/audit
#       type: DirectoryOrCreate
#     name: audit-log
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` 會強制立即重建 static Pod - 如同
任務 5，這比等待 kubelet 自己發現檔案變更更快：

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS 必須變成 Running - 如果還沒有,請等幾秒鐘再重試
```

回到工作機(以管理員 `cluster1-admin` 的身分)，並建立
危險的綁定 - 這**不是** `build-agent` 的 escalation 嘗試(在任務 7 之後，它已經沒有
通往這裡的真實路徑)，而是模擬的管理員動作，
audit log 必須把它捕捉為可重現的 evidence，說明究竟是誰
做的，以及權限究竟被授予了誰：

```bash
k create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

首先，只是用肉眼確認 audit 規則確實有運作，且事件進入了
log - 在考試中通常需要的是這項檢查，而不是現成的 artifact:

```bash
ssh control-plane
sudo cat /var/log/kubernetes/audit/audit.log | jq . | grep -A 30 incident-simulated-escalation
exit
```

`jq .` 會以人類可讀的方式印出每筆 log 記錄(每行一個欄位),`grep -A 30`
會顯示找到的那一行(含名稱)以及它「之後」的 30 行 - 這足以用肉眼看到
`stage`、`user.username`(真正的發起者)、`requestObject.roleRef`、
`requestObject.subjects`，不需要特殊的 jq 語法。

對真實的考試來說，這樣就夠了，但本實驗另外要求一個包含該事件的 artifact 檔案 -
不是因為 checker 光知道規則有在運作還不夠(它會自己、獨立地
透過 SSH 讀取 control-plane 上的 `audit.log`)，而是為了檢查另一項技能：
擷取並保存「真實的」記錄作為 forensic evidence，而不是用
自己的話轉述它(checker 會把你檔案的 `auditID` 與 log 中真實記錄的 `auditID` 比對)。
`/var/work/tests/artifacts/9/` 是「工作機」上的路徑，而不是 control-plane 上的，因此
要從工作機透過 `ssh control-plane "..."` 儲存，使用同樣的
對一般子字串做 grep 的組合(事件名稱 + `ResponseComplete`，以免撞上
同一個 request 的中間 `ResponseStarted` 記錄):

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | grep incident-simulated-escalation | grep ResponseComplete \
  | tail -n1 > /var/work/tests/artifacts/9/audit-escalation-event.json
```

我們儲存「整個」事件，就像它實際存在於 audit log 中的樣子(包括 `auditID`)- 不要
改寫，也不要手動拼湊 JSON，否則 artifact 在驗證時不會與 log 中的
真實記錄相符。

Containment：刪除綁定，並確認存取確實已被撤銷，而不只是
物件變得無法讀取。不帶 `-n`/`-A` 的 `can-i` 只檢查
kubeconfig context 目前的 namespace，而不是整個叢集 - 對於 `security-104` 中的 namespaced RoleBinding
(不同於已經刪除的 cluster-wide ClusterRoleBinding)，這會改變結果，
因此我們明確指定 namespace:

```bash
k delete clusterrolebinding incident-simulated-escalation
k auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent \
  | tee /var/work/tests/artifacts/9/containment-result.txt
# no
```

與任務 7 的差別：在那裡，我們是透過對 RBAC 物件的靜態分析，找出並撤銷
屬於 workload 自己(`build-agent`)的「已存在的」隱藏路徑。在這裡，
source of truth 是**時間上的事件**(audit log)，它證明究竟是誰
(欄位 `user.username` - 請求的真正發起者，這裡是管理員，而不是
`build-agent`)授予了危險的權限，以及授予給了誰 - 這正是真實
資安事件所需要的，因為物件本身在使用之後可能已經被刪除，而 `build-agent` 在
事件中只是作為權限的接收者出現，而不是請求的發起者。

最後執行 `check_result`。

## 10. 解碼、建立並掛載 Secret

`legacy-config` 已經存在。透過 API 讀取兩個值，而不是猜測：

```bash
mkdir -p /var/work/tests/artifacts/10
SERVICE_USER=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_USER}' | base64 -d)
SERVICE_TOKEN=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_TOKEN}' | base64 -d)
printf 'SERVICE_USER=%s\nSERVICE_TOKEN=%s\n' "$SERVICE_USER" "$SERVICE_TOKEN" \
  | tee /var/work/tests/artifacts/10/decoded-values.txt
```

建立新的 generic Secret，使用相同的鍵名與相同的值 -
`--from-literal` 會自己把值編碼為 base64，不需要手動做這件事：

```bash
k create secret generic rehydrated-config -n security-104 \
  --from-literal=SERVICE_USER="$SERVICE_USER" \
  --from-literal=SERVICE_TOKEN="$SERVICE_TOKEN"
```

把它以 read-only volume 掛載到 Pod - 同樣是 dry-run + 在 `vim` 中針對性修改：

```bash
k run secret-workflow -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > secret-workflow.yaml
vim secret-workflow.yaml
```

```yaml
# 在 Pod 的 spec 中加入:
spec:
  automountServiceAccountToken: false      # 加入
  containers:
  - name: secret-workflow
    volumeMounts:                          # 加入
    - name: rehydrated-config-vol          # 加入
      mountPath: /etc/rehydrated           # 加入
      readOnly: true                       # 加入
    ...
  volumes:                                 # 加入
  - name: rehydrated-config-vol            # 加入
    secret:                                # 加入
      secretName: rehydrated-config        # 加入
```

```bash
k apply -f secret-workflow.yaml
k wait -n security-104 --for=condition=Ready po/secret-workflow --timeout=60s
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_USER
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_TOKEN
# 必須與上面的 $SERVICE_USER / $SERVICE_TOKEN 相符
```

最後執行 `check_result`。

## 11. 修復既有的 Role，並把它綁定到另一個 namespace 的 SA

`rbac-a` 中既有的 Role `pod-role` 允許 `get`、`list`、`delete` - 我們移除
多餘的 `delete`，加入需要的 `watch`:

```bash
k patch role pod-role -n rbac-a --type=json -p \
  '[{"op":"replace","path":"/rules/0/verbs","value":["get","list","watch"]}]'
k auth can-i delete pods -n rbac-a --as=system:serviceaccount:rbac-a:dev # no
k auth can-i watch pods -n rbac-a --as=system:serviceaccount:rbac-a:dev  # yes
```

`shared-config` 已經存在於 `rbac-b`。我們正是在
`rbac-b` 中建立「新的」Role+RoleBinding - RoleBinding 支援來自另一個 namespace 的 subject，但權限本身
只在 RoleBinding 自己的 namespace 中有效：

```bash
k create role configmap-reader -n rbac-b --resource=configmaps --verb=get,list
k create rolebinding configmap-reader-binding -n rbac-b \
  --role=configmap-reader --serviceaccount=rbac-a:dev

k auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev    # yes
k auth can-i delete configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev # no
k auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev       # no
```

在 `rbac-a` 中建立確實使用 `dev` 的 Pod:

```bash
k run rbac-a-workload -n rbac-a --image=busybox:1.36 \
  --overrides='{"spec":{"serviceAccountName":"dev"}}' -- sh -c "sleep 3600"
```

最後執行 `check_result`。

## 12. 透過 CSR + namespaced RBAC 建立用戶端憑證使用者

產生 private key 與帶有 `CN=john` 的 CSR - 以憑證為基礎的使用者，其 RBAC
是透過 `kind: User` 綁定的，而不是 `ServiceAccount`，而且 `User` 沒有自己的 API
物件：它的 identity 完全取決於用戶端憑證中的 CN
與 binding 中的 `name` 相符。

```bash
mkdir -p /var/work/tests/artifacts/12
openssl genrsa -out /var/work/tests/artifacts/12/john.key 2048
openssl req -new -key /var/work/tests/artifacts/12/john.key \
  -out /tmp/john.csr -subj "/CN=john"
```

作為 Kubernetes `CertificateSigningRequest` 送出，使用與任務 7 中已經
用於核准 CSR 的同一個 signer(`kubernetes.io/kube-apiserver-client` -
正是適用於 client-auth 憑證的正確 signer，這個憑證將用來驗證
對 API server 的請求):

```bash
cat > john-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: $(base64 -w0 /tmp/john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF
k apply -f john-csr.yaml
k certificate approve john-csr
k get csr john-csr -o jsonpath='{.status.certificate}' \
  | base64 -d > /var/work/tests/artifacts/12/john.crt
```

確認憑證確實是由這個叢集簽發的，而不只是欄位
`status.certificate` 不是空的：

```bash
openssl verify -CAfile <(ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt) \
  /var/work/tests/artifacts/12/john.crt
# /var/work/tests/artifacts/12/john.crt: OK
openssl x509 -in /var/work/tests/artifacts/12/john.crt -noout -subject
# subject=CN = john
```

RBAC:`development` 中的 Role，以及針對 `kind: User, name: john` 的 RoleBinding - `kubectl create rolebinding` 中的 `--user=john`
會自己填入 `kind: User`，不需要寫 YAML:

```bash
k create role john-pod-access -n development --resource=pods --verb=create,list,get
k create rolebinding john-pod-access-binding -n development \
  --role=john-pod-access --user=john

k auth can-i create pods -n development --as=john  # yes
k auth can-i list pods -n development --as=john    # yes
k auth can-i get pods -n development --as=john     # yes
k auth can-i delete pods -n development --as=john  # no
k auth can-i create pods -n security-104 --as=john # no
```

`--as=john` 只能證明 RBAC 邏輯(impersonation，任何 admin 都可以使用，
無論是否簽發了真實的憑證)。另外我們要證明，「簽發出來的」
憑證確實會透過真正的 TLS client-auth 請求被 API server 接受：

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt > /tmp/cluster-ca.crt
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/development/pods"     # 200
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/security-104/pods"     # 403
```

同樣的證明，但是透過慣用的 `kubectl`，而不是 `curl` - 我們用已經簽發的憑證為 John 組合出單獨的
kubeconfig(`set-credentials` 搭配 `--client-certificate`/
`--client-key`，而不是 `--token`，因為這裡的 identity 正是 client-cert，而不是
ServiceAccount token):

```bash
k config set-cluster cluster1 --server="$SERVER" \
  --certificate-authority=/tmp/cluster-ca.crt --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-credentials john \
  --client-certificate=/var/work/tests/artifacts/12/john.crt \
  --client-key=/var/work/tests/artifacts/12/john.key --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-context john@cluster1 --cluster=cluster1 --user=john \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config use-context john@cluster1 \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development
# 可以運作 - RBAC 放行

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n security-104
# Error from server (Forbidden) - 與上面 curl 檢查中相同的 403

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig auth whoami
# Username: john - 確認這個 kubeconfig 確實是以 john 的身分通過驗證的,
# 而不只是碰巧給出了需要的回應碼
```

最後執行 `check_result`。
