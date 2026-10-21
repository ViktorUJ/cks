[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 105 - 參考解答：System Hardening 作業系統與 Docker

> 工作方式：只用一次 `ssh` 登入節點，然後直接在節點上執行指令(在
> `sudo -i` 之下，這樣就不必在每個指令前加 `sudo`)- 這比把
> 每個指令都單獨用 `ssh` 送出更快，在考試中也應該這樣操作。
> control-plane 節點的名稱透過 `kubectl get no` 查看：
>
> ```bash
> kubectl get no
> ssh <輸出中的節點名稱>
> sudo -i
> ```
>
> 檢查與 artifacts:checker 從**工作機**(`worker`)上的
> `/var/work/tests/artifacts/<編號>/` 讀取 artifacts，因此在節點上修改之後，先離開(`exit`、`exit`),
> 再從 `worker` 用簡短的指令儲存 artifact。為此請先設定一次節點名稱：
>
> ```bash
> CP=<輸出中的節點名稱>
> mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,9,10}
> ```
>
> Artifacts 只用於檢查實驗：考試中沒有它們，那裡只需要在
> 節點上執行指令並快速檢查結果。這些指令把輸出儲存到檔案(`>`)，內容再單獨
> 透過 `cat <檔案>` 查看 - 預期的結果寫在區塊下方的 `# ...` 註解中。
>
> 對於 Docker 主機，以相同的方式登入：`ssh docker-host`，然後 `sudo -i`。

## 1. 停用不需要的 systemd 服務

服務 `cks-lab105-unused.service` 對 Kubernetes 來說不是必需的，而且會擴大攻擊面。
我們停止它，並禁止自動啟動。

在 control-plane 上：

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-unused.service
systemctl is-enabled cks-lab105-unused.service   # disabled
systemctl is-active cks-lab105-unused.service    # inactive
exit
exit
```

Artifact(在 `worker` 上):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-unused.service; systemctl is-active cks-lab105-unused.service' \
  | xargs > /var/work/tests/artifacts/1/service.txt
# disabled inactive
```

## 2. 關閉不需要的 TCP/8080

埠 8080 是被服務 `cks-lab105-port.service` 刻意開啟的；control-plane 與
kubelet 都不需要它。停止並停用這個服務 - 兩個動作都是必須的，
否則即使現在埠是關閉的，listener 在 reboot 之後也會回來。

在 control-plane 上：

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-port.service
ss -ltn | grep 8080     # 輸出為空 - 埠已關閉
exit
exit
```

Artifacts(在 `worker` 上):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-port.service; systemctl is-active cks-lab105-port.service' \
  | xargs > /var/work/tests/artifacts/2/service.txt
# disabled inactive
# 埠已在節點上檢查過(`ss -ltn | grep 8080` - 為空),記錄結果:
echo 'tcp/8080: closed' > /var/work/tests/artifacts/2/port-8080.txt
```

## 3. 用 UFW 限制入站流量

首先確定拓撲與需要的 source。這是單節點 control-plane,
它同時也執行 workload。Worker 必須有 SSH 與 API 存取；Pod CIDR 與節點本身則需要
API 存取。這裡沒有節點間的 kubelet/CNI flows。我們不對
`Anywhere` 開放 `22`/`6443`。

在 `worker` 上用肉眼查看需要的值：

```bash
kubectl get no -o wide                                      # 節點的 INTERNAL-IP
kubectl get no "$CP" -o jsonpath='{.spec.podCIDR}{"\n"}'    # Pod CIDR
hostname -I                                                 # worker 的 IP
```

把它們寫入 preflight(代入你自己的值；`role=` 這一行是必須的):

```bash
WORKER_IP=<ip-worker>; NODE_IP=<節點的-internal-ip>; POD_CIDR=<pod-cidr>
printf 'role=control-plane,workload\nworker_ip=%s\nnode_ip=%s\npod_cidr=%s\n' \
  "$WORKER_IP" "$NODE_IP" "$POD_CIDR" > /var/work/tests/artifacts/3/preflight.txt
```

UFW「之前」的 Baseline：確認 TCP/10250(kubelet HTTPS)現在確實可達 - 沒有
這一步，UFW 之後的「被阻擋」什麼也證明不了，該埠可能因為其他原因就已無法存取
(security group、routing)。Checker 另外會與它自己的 baseline 比對，但你自己的
記錄也是必需的：

```bash
curl -ks -o /dev/null -w '%{http_code}\n' --max-time 3 "https://$NODE_IP:10250/healthz"
# 401 - 埠可達(任何 1xx-5xx,包括 401/403,都可以)
echo 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=401' >> /var/work/tests/artifacts/3/preflight.txt
```

如果 baseline 無法到達(curl 回傳 `000`)- 請先修復連通性，否則 UFW 之後的
結果不具說服力。

UFW 規則在節點上設定。先允許 recovery 與需要的 source，然後才
更改 default。`WORKER_IP`/`NODE_IP`/`POD_CIDR` 的值取自 `preflight.txt`
(代入你自己的):

```bash
ssh "$CP"
sudo -i
WORKER_IP=<worker_ip>; NODE_IP=<node_ip>; POD_CIDR=<pod_cidr>
ufw allow from "$WORKER_IP" to any port 22 proto tcp comment 'CKS105 worker SSH recovery'
ufw allow from "$WORKER_IP" to any port 6443 proto tcp comment 'CKS105 worker API'
ufw allow from "$NODE_IP" to any port 6443 proto tcp comment 'CKS105 node API'
ufw allow from "$POD_CIDR" to any port 6443 proto tcp comment 'CKS105 Pod API'
ufw allow in on lo comment 'CKS105 loopback'
ufw default allow outgoing
ufw default deny incoming
ufw --force enable
ufw status verbose
exit
exit
```

Artifacts(在 `worker` 上)。`ufw show added` - 你實際加入的規則的
正規化表示(「不保證」是原本指令的形式/順序 - UFW 在
顯示時會將它們正規化)。檢查會把這份清單與預期的 allowlist 比對 -
請把它也儲存下來，這是 exact allow-set 最可靠的 evidence。只透過 `ufw` 管理 firewall -
「不要」手動編輯 `/etc/ufw/before*.rules` 或 `/etc/ufw/after*.rules`，這些是
帶有通用 default 規則的 framework 檔案，不是放置限定 source 的規則的地方；checker
會把它們的雜湊值與 checker-owned bootstrap-baseline 比對，並會發現直接編輯。

```bash
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  > /var/work/tests/artifacts/3/ufw.txt
ssh "$CP" 'sudo ufw show added' \
  >> /var/work/tests/artifacts/3/ufw.txt

cat > /var/work/tests/artifacts/3/recovery.txt <<'EOF'
# 在無法存取 API 時,從仍然開啟的 SSH/console session 執行:
sudo ufw disable
sudo ufw status verbose
# 修正限定範圍的 allow rules,檢查 source IP/CIDR
sudo ufw --force enable
# 如果規則完全損壞,只能透過 console/recovery channel:
sudo ufw --force reset
EOF
```

確認叢集健康(從 `worker`):

```bash
kubectl get --raw=/readyz
kubectl get nodes
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=60s
# 叢集內的 workload 必須仍然能解析 DNS 並到達 API server
# (UFW 不得破壞 Pod -> CoreDNS 與 Pod -> API 的流量):
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default   # 必須回傳 kubernetes service 的 Address
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz   # 除 000 以外的任何狀態碼

# 不應有的 worker -> kubelet flow 不得得到 HTTP response。
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000 - transport deny
```

在 `ufw reload`「之後」必須進行完整的 E2E retest - 證明 ruleset 能撐過
reload，而不只是在 `ufw enable` 之後立刻在記憶體中運作。沒有這一步，可能會
在 enable 之後立刻意外得到錯誤的 PASS:

```bash
ssh "$CP" 'sudo ufw reload'
sleep 2
kubectl get --raw=/readyz
kubectl get nodes
kubectl get pods -n kube-system -l k8s-app=calico-node
# 在 reload 之後重複同樣的兩項 workload 檢查:
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz
# 與 reload 之前相同的約定:worker 仍然無法到達 kubelet。
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000
```

declared vs effective 的檢查：`ufw show added` 是宣告式的清單，它是根據
ufw 在透過 CLI 加入規則時自己寫入 `user.rules` 的 `### tuple ###` metadata
重建出來的。而 `ufw reload` 之後核心的真實狀態，則是 `ufw show user-rules`
顯示的內容。不要只比較行的「數量」，還要比較它們的「內容」
(source/port/proto):`ufw-user-input` 必須顯示 loopback(all、lo)以及四條帶有精確 source 位址的 tcp
dpt:22/6443 規則，而 `ufw6-user-input` 則必須「恰好」只有一行，即
針對 v6 的同一個 loopback ACCEPT(`ufw allow in on lo` 是針對 interface、沒有明確 IP 的規則，
因此 ufw 總是同時建立 v4 與 v6 版本)。那裡任何「其他的」/額外的行，
都是不該存在的 bypass:

```bash
ssh "$CP" 'sudo ufw show user-rules'
```

輸出中必須有 `Status: active`、`Default: deny (incoming)` 以及限定 source 的規則 -
無論是在 `ufw status verbose` 中，還是在宣告式清單 `ufw show added` 中。在 `/readyz`、nodes、calico-node、workload(包括 reload 之前與
之後的 Pod DNS)以及兩項針對 `10250` 的負向檢查(`ufw reload` 之前與之後，使用相同的
CURL_EXIT/HTTPCODE 約定)都得到預期結果之前，不要關閉
最初的 SSH session。

## 4. 保護管理員的 kubeconfig

`/etc/kubernetes/admin.conf` 包含 cluster-admin credential。它只能由
root 讀取。

在 control-plane 上：

```bash
ssh "$CP"
sudo -i
chown root:root /etc/kubernetes/admin.conf && chmod 600 /etc/kubernetes/admin.conf
stat -c '%U %G %a' /etc/kubernetes/admin.conf   # root root 600
exit
exit
```

Artifact(在 `worker` 上):

```bash
ssh "$CP" "stat -c '%U %G %a' /etc/kubernetes/admin.conf" \
  > /var/work/tests/artifacts/4/admin-conf.txt
# root root 600
```

## 5. 禁止透過 SSH 直接以 root 登入

修改設定，在 reload 之前檢查語法，並在不中斷目前
工作階段的情況下套用。

在 control-plane 上：

```bash
ssh "$CP"
sudo -i
sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
sshd -t && systemctl reload ssh
```

`reload ssh` 時，目前的工作階段不會中斷。但在 sshd 重新啟動期間，對 control-plane 的新
連線可能會有 1-2 秒收到 `Connection refused` - 這是
正常的，並不表示設定壞了(`sshd -t` 已經檢查過)，只要
重試指令即可。

不帶 connection context 的 `sshd -T` 完全不套用 `Match` 區塊 - `sshd(8)` 的 man page
明確指出，test mode 中的 `Match` 只有在傳入 `-C` 時才會套用。因此
我們透過 `-C` 檢查，模擬來自 worker 的真實 root 連線(位址取自
任務 3 的 `preflight.txt`):

```bash
sshd -T -C 'user=root,addr=<worker_ip>,laddr=<node_ip>,lport=22' | grep -i permitrootlogin
# permitrootlogin no
exit
exit
```

Artifact(在 `worker` 上，等待幾秒鐘之後):

```bash
# WORKER_IP 與 NODE_IP - 與任務 3 中相同的值
ssh "$CP" "sudo sshd -T -C 'user=root,addr=${WORKER_IP},laddr=${NODE_IP},lport=22' | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
  > /var/work/tests/artifacts/5/sshd.txt
# PermitRootLogin no
```

## 6. 關閉 `docker-host` 上對 Docker daemon 的不安全存取

TCP/2375 沒有 TLS 與 authentication：對它的存取實際上等同於對主機的 root
存取。我們移除帶有 TCP listener 的學習用 systemd override，透過 socket override
設定 unix-socket 的擁有者，並把 `developer` 從 `docker` 群組中移除。

透過完整的 `daemon-reload` + 對**兩個** unit 的 restart 來套用變更 - 這是
必須的步驟，而不只是「重新讀取設定」：沒有真正的 restart，可能會意外
「通過」檢查，只因為 Docker 單純停止回應(此時 TCP/2375 是關閉的，不是因為
移除了 `-H tcp://`，而是因為 daemon 根本沒有在運作)。

在 `docker-host` 上：

```bash
ssh docker-host
sudo -i
rm -f /etc/systemd/system/docker.service.d/10-cks-lab105-tcp.conf
install -d -m 0755 /etc/systemd/system/docker.socket.d
printf '[Socket]\nSocketGroup=root\nSocketMode=0660\n' > /etc/systemd/system/docker.socket.d/10-cks-lab105-socket.conf
gpasswd -d developer docker || true
systemctl daemon-reload
systemctl restart docker.socket
systemctl restart docker.service
chown root:root /var/run/docker.sock && chmod 660 /var/run/docker.sock
```

Positive control:restart 之後 Docker 確實在「運作」(不只是沒有監聽 2375 - 它
必須透過 unix-socket 完整地正常運作):

```bash
systemctl is-active docker.service docker.socket   # active / active
docker version && docker info >/dev/null
```

持久設定檢查 - effective unit 不包含 `-H tcp://`，而 socket override 確實
設定了需要的值(而不只是暫時與它們相符):

```bash
systemctl cat docker.service | grep -c "H tcp://"   # 0
systemctl cat docker.socket                          # ... SocketGroup=root ... SocketMode=0660 ...
```

任務的約定比埠 2375 更廣：Docker API 不得在任何埠上監聽 TCP，而
`docker.socket` 不得包含 TCP `ListenStream`:

```bash
ss -ltnp | grep dockerd                        # 輸出為空(docker.socket 產生的 systemd TCP socket 由下一行捕捉)
systemctl cat docker.socket | grep ListenStream # 只有 /run/docker.sock(以及空的重設)
stat -c '%U %G %a' /var/run/docker.sock         # root root 660
sudo -u developer docker ps                     # permission denied
exit
exit
```

Artifacts(在 `worker` 上):

```bash
# 埠 2375 已在 docker-host 上檢查過(`ss -ltnp | grep dockerd` - 為空),記錄結果:
echo 'tcp/2375: closed' > /var/work/tests/artifacts/6/docker-tcp.txt
ssh docker-host "sudo stat -c '%U %G %a' /var/run/docker.sock" \
  > /var/work/tests/artifacts/6/docker-socket.txt
ssh docker-host 'if sudo -u developer docker ps >/dev/null 2>&1; then echo "developer docker ps: allowed"; else echo "developer docker ps: denied"; fi' \
  > /var/work/tests/artifacts/6/developer-access.txt
# tcp/2375: closed
# root root 660
# developer docker ps: denied
```

完成所有步驟之後，執行 `check_result`。

## 7. 禁止載入模組 `sctp`

`sctp` 已載入，但在這個節點上 kubeadm、containerd、Calico 都不需要它。我們嘗試
卸載已經載入的模組，然後無論如何都透過 `blacklist` 與 `install` override
阻止重新載入。這兩個指令都作用在
`modprobe` 層級(alias resolution 與明確的 `modprobe sctp`)，消除一般的載入路徑；
它們不能取代 kernel-level 的強制執行(`insmod` 直接透過 syscall 插入模組，
不讀取 `modprobe.d`，而 `modprobe --ignore-install` 在同等的
root 存取權下可以繞過 `install`)- 對這個實驗來說，重要的是消除預期的自動載入路徑，而不是
模擬防範已經在節點上擁有 root 的使用者。

**`modprobe -r sctp` 在已經在運作的叢集上可能無法成功** - 這是預期的，
不是學員的錯誤。協定的核心模組(包括 `sctp`)會對載入模組當時已存在的每個 netns
取得持久的
per-network-namespace 引用(pernet 初始化中的 `try_module_get`)- 這個節點上已經有 Pod 在運作
(calico、coredns、kube-system)，因此 `sctp` 可能保持 `in use` 狀態，
refcount 不為零，且 `/sys/module/sctp/holders` 為「空」(也就是說，不是別的模組在持有它 -
沒有可以遞迴卸載的東西)。不停止所有這些 Pod 就無法修正這一點，而這
不在任務範圍內。重要且被檢查的，正是在學員控制範圍內的事情：
模組不能被「重新」載入。

在 control-plane 上：

```bash
ssh "$CP"
sudo -i
modprobe -r sctp || true
printf 'blacklist sctp\ninstall sctp /bin/true\n' > /etc/modprobe.d/60-cks-sctp.conf
lsmod | grep sctp                       # 可能是空的,也可能不是空的 - 兩種情況都可以
modprobe --show-config | grep sctp      # install sctp /bin/true 與 blacklist sctp
exit
exit
```

Artifact(在 `worker` 上)：目前的狀態(`absent` 或 `present`)以及 effective
modprobe config 中的 override:

```bash
ssh "$CP" '
{
  if lsmod | grep -q sctp; then echo "lsmod: present"; else echo "lsmod: absent"; fi
  modprobe --show-config | grep sctp
}' > /var/work/tests/artifacts/7/sctp.txt
# lsmod: absent   (或 lsmod: present - 兩種情況都可以,見上文)
# install sctp /bin/true
```

## 8. `protectKernelDefaults` 與安全的 sysctl

先修正 sysctl - 如果目前的核心值與 kubelet 的預期不符，
`protectKernelDefaults: true` 會讓 kubelet **在啟動時失敗**，因此 sysctl
必須在重新啟動 kubelet 之前套用。

在 control-plane 上：

```bash
ssh "$CP"
sudo -i
printf 'kernel.unprivileged_bpf_disabled = 1\nvm.overcommit_memory = 1\n' > /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl kernel.unprivileged_bpf_disabled vm.overcommit_memory
```

現在在 kubelet 的設定中啟用 `protectKernelDefaults`，並重新啟動服務：

```bash
grep -q '^protectKernelDefaults:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^protectKernelDefaults:.*/protectKernelDefaults: true/' /var/lib/kubelet/config.yaml \
  || echo 'protectKernelDefaults: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

節點必須保持 `Ready`(從 `worker`):

```bash
kubectl get no
```

如果 kubelet 在這一步之後無法啟動 - 請檢查順序：在 kubelet 啟動時檢查 sysctl 之前，
它們必須已經被套用(`sysctl --system`)，而不只是寫入檔案。

## 9. 找出多餘的 SUID 二進位檔並使其無害

`find` 會同時顯示系統的 SUID 二進位檔(`sudo`、`passwd`、`mount` - 我們不動它們)，以及
學習用的 `/usr/local/bin/cks-lab105-suid-tool`，這個節點上的 Kubernetes 元件都不
需要它。

`/var/lib/containerd` 被排除在輸出之外：它的 overlayfs snapshot 路徑是 container image
層的內容，而不是安裝在主機上的二進位檔，而且在實驗期間任何一次
pull/extract 映像時它們都會改變，與學員的動作無關。

Artifact `suid-before.txt` 必須在修正「之前」儲存(在 `worker` 上):

```bash
ssh "$CP" "sudo find / -xdev -perm -4000 -type f 2>/dev/null | grep -v '^/var/lib/containerd/'" \
  > /var/work/tests/artifacts/9/suid-before.txt
grep cks-lab105-suid-tool /var/work/tests/artifacts/9/suid-before.txt
```

只移除學習用檔案的 SUID bit(在 control-plane 上)，並確認系統的
SUID 二進位檔沒有被動到 - `sudo`/`passwd` 必須保持 SUID bit，否則作業系統的基本
功能會損壞：

```bash
ssh "$CP"
sudo -i
chmod u-s /usr/local/bin/cks-lab105-suid-tool
stat -c '%a' /usr/local/bin/cks-lab105-suid-tool   # 755
stat -c '%a %n' /usr/bin/sudo /usr/bin/passwd      # 4755 ...
exit
exit
```

Artifact `suid-after.txt`(在 `worker` 上):

```bash
ssh "$CP" "stat -c '%a' /usr/local/bin/cks-lab105-suid-tool" \
  > /var/work/tests/artifacts/9/suid-after.txt
# 755
```

完成所有步驟之後，執行 `check_result`。

## 10. 停用 core dumps 並保護 SUID 行程

Core dump 可能包含 crash 當下行程記憶體中的 secret 與金鑰 - 必須同時對
一般行程與 SUID 行程禁止它。我們把 `fs.suid_dumpable` 加入與任務 8 中已經建立的
同一個檔案 `/etc/sysctl.d/99-kubernetes.conf` - 不要建立另一個
衝突的設定。

在 Ubuntu 上，`ulimit -c 0` 與 `fs.suid_dumpable=0` **不保證**沒有 core dump:
`man 5 core` 明確記載，如果
`kernel.core_pattern` 透過 pipe(`|program`)把 dump 導向 userspace handler，核心會忽略 `RLIMIT_CORE`。
Ubuntu 預設正是這樣設定的 - crash 會被 Apport 攔截，並儲存到
`/var/lib/apport/coredump/`，「不管」行程的 `ulimit -c` 為何。唯一可靠的
方法是把 `kernel.core_pattern` 本身覆寫成必然無法運作的 handler。

我們同時在行程限制層級限制 core dump 的大小 - 這是與
`suid_dumpable`/`core_pattern` 不同的機制(針對一般 crash 在經典的
基於檔案的寫入下的 soft limit，如果這種寫入日後被恢復的話)。

在 control-plane 上：

```bash
ssh "$CP"
sudo -i
printf 'fs.suid_dumpable = 0\nkernel.core_pattern = |/bin/false\n' >> /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern   # 0 / |/bin/false
printf '* hard core 0\n* soft core 0\n' >> /etc/security/limits.conf
```

`limits.conf` 透過 PAM 套用到新的 login 工作階段，而不是已經開啟的 shell -
我們專門在新的工作階段中檢查：

```bash
su - ubuntu -c 'ulimit -c'      # 0
exit
exit
```

Artifact `coredump.txt`(在 `worker` 上)。包含 controlled crash probe：確認
在真正的 `SIGSEGV` 之後，Apport 的目錄(`/var/lib/apport/coredump`、`/var/crash`)
中不會出現「新的」保留的 core dump:

```bash
ssh "$CP" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; sudo su - ubuntu -c 'ulimit -c'" \
  > /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" "cat /etc/sysctl.d/99-kubernetes.conf; cat /etc/security/limits.conf" \
  >> /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" '
before_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
sh -c "kill -SEGV \$\$" || true
sleep 2
after_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
if [ "$after_count" -le "$before_count" ]; then
  echo "crash-probe: no new retained core dump"
else
  echo "crash-probe: NEW core dump appeared after SIGSEGV"
fi
' >> /var/work/tests/artifacts/10/coredump.txt
# crash-probe: no new retained core dump
```

完成所有步驟之後，執行 `check_result`。
