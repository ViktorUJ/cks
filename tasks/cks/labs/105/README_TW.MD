[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 105 - System Hardening 作業系統與 Docker daemon 安全

## 目標

在這個 CKS 實驗中,你要縮小兩台 Linux 主機的攻擊面。在 Kubernetes
control-plane 上,需要停用多餘的服務、關閉開放的埠、設定 firewall、
保護 kubeconfig,並禁止透過 SSH 直接以 root 登入。在單獨的 `docker-host` 上,
需要消除 Docker daemon 的三個危險設定:沒有 TLS 的 TCP API、透過 `docker` 群組存取
`docker.sock`,以及使用者 `developer` 對這個 socket 的存取。

這個學習環境是刻意建立成不安全的。不要把初始設定帶到
production:TCP/2375 上沒有 TLS 的 Docker API,會讓任何能連線到該埠的人
取得遠端 root 存取權。

## 開始前先自我檢查

<details>
<summary>1. `systemctl disable` 與 `systemctl stop` 有什麼不同,為什麼任務 1 兩者都需要?</summary>

`stop` 會立刻停止已經在執行的行程,但不影響下次系統開機時的自動啟動。`disable` 會把服務從自動啟動中移除(unit 檔案不再連結到 target),但不會停止已經在執行的行程。要完整關閉攻擊面,兩者都需要 - 否則服務要麼現在繼續執行,要麼在 reboot 之後再次啟動。
</details>

<details>
<summary>2. 為什麼沒有 TLS 的 TCP Docker API(`-H tcp://0.0.0.0:2375`)等同於遠端 root 存取?</summary>

Docker daemon 以 root 權限執行,而它的 API 在沒有 TLS client certificates 的情況下沒有內建的 authentication。任何能夠透過網路連線到這個埠的人,都可以啟動帶有 `--privileged` 並掛載 host filesystem 的任意 container - 從而完全控制主機,繞過 SSH 以及任何其他存取控制機制。
</details>

<details>
<summary>3. 為什麼即使檔案本來就只能透過檔案系統由 root 存取,對 kubeconfig 執行 `chmod 600` 仍然很重要?</summary>

`/etc/kubernetes/admin.conf` 包含具有 `cluster-admin` 權限的 client certificate - 如果檔案的 mode 太寬(例如 `644`,所有人都可讀),這個節點上的「任何」使用者,即使沒有 sudo,都可以讀取這份 credential,並遠端取得對叢集的完整管理存取權,不需要在節點本身上做權限提升。
</details>

<details>
<summary>4. 為什麼即使 secret 從未寫入磁碟,行程的 core dump 仍然可能洩漏 secret?</summary>

Core dump 是行程在 crash 當下的記憶體映像,它**可能**包含解密後的變數值、private key 與以明文保存的 token。這不保證是行程的全部記憶體:映射的集合取決於 `/proc/<pid>/coredump_filter`,而個別區域可能被排除,例如透過 `MADV_DONTDUMP`。因此,即使應用程式從不明確地把 secret 寫入檔案,crash dump 也可能把存在於已納入映射中的 secret 儲存到磁碟上可讀取的檔案裡。
</details>

## 與課程的關聯

- [第 14 章。縮減主機作業系統的 footprint 與 runtime-daemon 安全](../../course/14/tw.md)
- [第 15 章。主機上的 least-privilege 與縮減對外存取](../../course/15/tw.md)
- [CKA:systemd、服務與 Linux](../../../cka/course/00-5-linux/tw.md)
- [CKA:容器與 runtime](../../../cka/course/00-4-containers/tw.md)

## 基礎架構

環境透過 Terragrunt 部署在 AWS `eu-central-1`:

| 元件 | 用途 |
|---|---|
| `vpc` | VPC `10.10.0.0/16`,含兩個公有子網路 |
| `ssh-keys` | 用於內部連線的 SSH 金鑰 |
| `k8s-1` | 單節點 kubeadm 叢集 Kubernetes `1.36.0`、containerd、Calico;這是目標 control-plane |
| `docker-host` | 單獨的 Ubuntu 22.04,安裝了 Docker,並刻意設定為不安全 |
| `worker` | 具備 `kubectl`、SSH 設定與 `check_result` 的工作機 |

`worker` 可以透過 Kubernetes node name SSH 到 control-plane,也可以透過名稱 `docker-host` SSH 到單獨的
主機。Docker 不是 Kubernetes 叢集的 runtime:任務 6 中的
設定被隔離在 `docker-host` 上。

## 部署

```bash
TASK=105 make run_cks_task
```

連線到 `worker`(kubectl context 已經設定好),查看 control-plane
節點的名稱,然後登入各主機:

```bash
kubectl get no
ssh <輸出中的節點名稱>
ssh docker-host
```

實用指令:

```bash
time_left
check_result
```

請把檢查用的 artifacts 儲存在 `/var/work/tests/artifacts/<編號>/` 中。這個實驗不需要建立
Kubernetes manifests。

## 任務

---
| **1** | **停用多餘的服務** |
| :---: | :--- |
| 要做什麼 | 在 control-plane 上停用並停止 `cks-lab105-unused.service`。這個服務對 Kubernetes 的運作不是必需的,而且在 reboot 之後不應該啟動。 |
| 驗收標準 | `systemctl is-enabled cks-lab105-unused.service` 回傳 `disabled`,`systemctl is-active` 回傳 `inactive`;在 `/var/work/tests/artifacts/1/service.txt` 中有一行 `disabled inactive`。 |

<details>
<summary>💡 任務 1 的提示</summary>

指令順序:`sudo systemctl stop cks-lab105-unused.service && sudo systemctl disable cks-lab105-unused.service` - 兩個步驟都需要,兩者不能互相取代(參見上面自我檢查一節中的問題 1)。artifact 必須恰好包含 "disabled inactive" 這一行(依此順序,以空格分隔)- 儲存之前請先檢查格式。
</details>

---
| **2** | **關閉不需要的開放埠** |
| :---: | :--- |
| 要做什麼 | 在 control-plane 上消除由 `cks-lab105-port.service` 建立的 TCP/8080 listener。停用並停止這個服務(兩個動作都是必須的 - 參見自我檢查一節中的問題 1);control-plane 與 kubelet 都不需要它。 |
| 驗收標準 | `ss -ltn` 沒有顯示 TCP/8080;`systemctl is-enabled cks-lab105-port.service` 回傳 `disabled`,`systemctl is-active` 回傳 `inactive`;`/var/work/tests/artifacts/2/service.txt` 包含一行 `disabled inactive`;`/var/work/tests/artifacts/2/port-8080.txt` 包含 `tcp/8080: closed`。 |

<details>
<summary>💡 任務 2 的提示</summary>

首先找出是哪個行程佔用了這個埠(`sudo ss -ltnp | grep 8080`),確認它確實是 `cks-lab105-port.service`,而不是別的東西。透過 firewall(任務 3)關閉這個埠,對這個任務來說是不夠的 - 測試檢查的是 listener「本身」不存在,而不只是從外部被阻擋。
</details>

---
| **3** | **用 firewall 限制入站流量** |
| :---: | :--- |
| 要做什麼 | • 在啟用 UFW 之前,記錄節點的角色、worker source IP、node InternalIP 與 `spec.podCIDR`。<br/>• **firewall 之前必須有的 baseline:**記錄從 worker 對 TCP/10250(kubelet HTTPS endpoint)的 baseline 探測 - 帶有真實 `CURL_EXIT`/`HTTPCODE` 的 `curl`,證明該埠在網路上可達(任何 1xx-5xx,包括 401/403,都視為可達 - kubelet API 確實回應了)。沒有這一步,hardening 之後的「被阻擋」就無法與在 UFW 之前就已阻擋該埠的無關故障(security group、routing)區分開來。除了你的記錄之外,checker 還會獨立地把它與自己的 bootstrap-baseline 比對,該 baseline 是在發放實驗「之前」記錄在受保護的目錄 `/var/lib/cks-lab105-checker` 中的(`0711 root:root`,與預設對所有人可寫的 `/var/work/tests` 分開)。<br/>• 拓撲:單節點 control-plane + workload node。需要恰好五條規則:loopback、來自 worker 的 SSH recovery、來自 worker、來自節點本身以及來自 Pod CIDR 的 API `6443/tcp`。etcd/scheduler/controller-manager 使用本機的 flows,在這個拓撲中沒有節點間的 CNI/kubelet flows。<br/>• 只用 `ufw` 指令管理 firewall(allow/deny/reject/limit/route,然後 enable/reload)。不要手動編輯 `/etc/ufw/before*.rules`、`after*.rules`、`user.rules`、`user6.rules`:framework 檔案(before/after)會與 bootstrap-baseline 依雜湊值比對,而 `user.rules`/`user6.rules`(ufw 寫入你的規則的地方)是透過核心的實際狀態(`ufw show user-rules`)來檢查,而不只是檔案。<br/>• 在 `ufw default deny incoming` 之前,加入限定 source 的 allow rules。不要使用寬鬆的 `ALLOW Anywhere`,也不要在這五條(loopback + 4 條限定 source 的)之外再加入任何其他規則,包括 deny/reject/route。<br/>• 啟用 UFW,並在 `/var/work/tests/artifacts/3/` 中儲存:`ufw status`、`ufw show added`(已加入規則的正規化表示 - 不一定是原本指令的形式/順序)、preflight(包括 TCP/10250 的 baseline)與 recovery 指令。<br/>• **`ufw reload` 之後必須的 retest:**執行 `sudo ufw reload`,並重複「所有」相同的檢查(readyz、node Ready、calico-node Ready、Pod DNS、Pod→API、worker→kubelet:10250 deny、有效的 UFW 規則數量)。只在 enable 之後立刻在記憶體中運作、但無法撐過 reload 的規則,不算是正確的解答。 |
| 驗收標準 | • **TCP/10250 baseline:**checker-owned bootstrap-baseline(在發放實驗之前記錄於 `/var/lib/cks-lab105-checker`,目錄為 `0711 root:root`,位於 `/var/work/tests` 之外,檔案為 `0444 root:root`)確認了 TCP/10250 最初的可達性;你自己在 UFW 之前的 baseline 探測已儲存,並顯示真實的網路可達性(`CURL_EXIT=0`,HTTP `1xx-5xx`)。如果該埠在 baseline 時就已經無法存取,任務的結果是 `inconclusive`,而不是 PASS。<br/>• **UFW 與精確的規則集合:**UFW active,default-deny;`ufw show added` 恰好包含五行:loopback + `worker_ip`→`22/tcp` + `worker_ip`→`6443/tcp` + `node_ip`→`6443/tcp` + `pod_cidr`→`6443/tcp`,沒有任何「任何」動作(`allow`/`deny`/`reject`/`limit`/`route`)的多餘規則,也沒有缺少這五條中的任何一條。<br/>• **Framework 檔案:**`/etc/ufw/before*.rules`/`after*.rules` 的雜湊值與 checker-owned bootstrap-baseline 沒有差異(規則只透過 `ufw` 加入,不手動編輯 framework 檔案)。<br/>• **核心的實際狀態:**`sudo ufw show user-rules`(透過 `iptables -L` 的真實 `ufw-user-*` chains)在語意上與預期的五條規則相符 - 檢查的不只是數量,還有「每一條」規則的 source/interface/protocol/port,而且在 `enable` 之後與 `reload` 之後都要檢查。`ufw6-user-input` 保持「恰好」一行 - loopback ACCEPT 的 v6 版本(`ufw allow in on lo` 會同時建立 v4 與 v6 規則,因為這是針對 interface、沒有明確 IP 的規則;並不是「完全空的」)。這能抓到直接修改 `user.rules`/`user6.rules` 而沒有 tuple metadata(既不反映在 `ufw show added` 中,也不反映在 `before/after` 的雜湊值中),以及擴大已經宣告的規則(例如把 `node_ip`→`6443/tcp` 偷偷換成 `node_ip`→`any`)而不改變行數的情況。<br/>• **叢集健康:**`/readyz=ok`;預期的節點與所有 `calico-node` Pod 保持 `Ready`;`health-probe` 保持 Ready,能解析 DNS 並連到 Kubernetes Service。<br/>• **kubelet 阻擋:**UFW 之後,worker 無法連到 kubelet `10250`(`HTTPCODE=000`,transport deny)- 正是相對於已證明的 baseline 的退步。<br/>• **reload 之後的 retest:**「所有」相同的檢查在明確執行 `sudo ufw reload` 之後再次通過:readyz/node/calico-node/DNS/Pod→API 保持健康,worker→kubelet:10250 保持以與 reload 之前相同的 deny 約定被阻擋,而且核心中的實際規則數量再次與宣告式的相符。<br/>• **Artifacts:**artifact 包含 recovery 指令(`ufw disable`、檢查、修正與重新啟用)。 |

<details>
<summary>💡 任務 3 的提示</summary>

這裡最危險的錯誤,是在你加入來自 worker IP 的 SSH allow 規則「之前」就執行 `ufw enable`(default-deny)。順序必須是:先加入所有需要的 `ufw allow from <IP> to any port <port>`,然後才 `ufw --force enable`。在操作 firewall 的整個期間,請保持目前的 SSH 工作階段開啟 - 如果你失去存取權,用於 recovery 的第二個工作階段將無法連線(參見下面的警告)。別忘了在啟用 UFW「之前」做 TCP/10250 的 baseline 探測 - 沒有它,hardening 之後的「被阻擋」什麼也證明不了:該埠可能在更早之前就因為完全不同的原因而無法到達(例如 AWS security group),那麼這跟 UFW 完全無關;此外,checker 有它自己的 baseline,它在發放實驗之前就已記錄在單獨的受保護目錄中,因此無法事後偽造這筆記錄。請嚴格透過 `sudo ufw show added` 來檢查 allow 集合(而不只是 `ufw status`)- 其中必須恰好有五行,不能多一行(沒有寬鬆的 `ALLOW Anywhere`,沒有額外的埠,而且這適用於「任何」動作 - `allow`、`deny`、`reject`、`limit`、`route`,而不只是新的 allow),也不能少一行。請只透過 `ufw` 指令管理 firewall - 不要手動編輯 `/etc/ufw/before*.rules`/`after*.rules`/`user.rules`/`user6.rules`:framework 檔案會依雜湊值比對,而 `user.rules`/`user6.rules` 的實際狀態,checker 會直接透過 `ufw-user-*` chains 中真實的 iptables 規則來檢查(`sudo ufw show user-rules`),因此即使修改 `user.rules` 時沒有正確的 `### tuple ###` 註解,在 `ufw reload` 之後也會被發現。最後別忘了執行 `sudo ufw reload` 並重複所有檢查 - 只在 `enable` 之後立刻運作、但無法撐過 `reload` 的規則,不會被計分。
</details>

> **Recovery 優先。**在完整檢查完成之前,請保持目前的 SSH 工作階段開啟。如果 API
> 消失了,請在該工作階段中執行 `sudo ufw disable`,修正 allow rules,然後才重新
> 啟用 firewall。如果 SSH 已經遺失,請使用提供者的 console/recovery channel;
> 不要試圖用寬鬆的 `allow from any` 來「治療」這個情況。
>
> **適用範圍。**這個 UFW allowlist 只適用於單節點 fixture。
> 不能原封不動地搬到 multi-node 叢集:在 default-deny 之前,需要針對具體的拓撲盤點
> kubelet 與節點間的流量、CNI overlay、BGP/VXLAN/WireGuard、LoadBalancer/NodePort 以及
> 提供者的 firewall/security groups。
>
> **Lab-specific exception:Calico 節點上的 UFW。**Calico 關於
> 需求的官方文件明確建議在 Calico 節點上停用 firewalld 與其他 iptables manager,
> 因為它們可能與 Calico 自己設置的規則衝突。UFW 同樣是 iptables/nftables manager。這個實驗刻意在
> control-plane 上保留 UFW,用來練習 host firewall hardening(CKS 考試大綱中的
> 一項獨立技能),而不是作為在 production 中讓 Calico 與 host firewall 共存的建議做法 - 為此
> Calico 提供了自己的 `HostEndpoint`/`GlobalNetworkPolicy`。正因如此,任務
> 明確要求受控的順序:baseline → `ufw enable` → retest,並
> 檢查 `calico-node` 與整個 Kubernetes 的連通性仍然正常(參見
> `ADVERSARIAL_ACCEPTANCE_STANDARD.md`)。

---
| **4** | **修正 kubeconfig 的權限** |
| :---: | :--- |
| 要做什麼 | 在 control-plane 上保護包含 cluster-admin credential 的 `/etc/kubernetes/admin.conf`:擁有者與群組必須是 `root:root`,mode 為 `600`。 |
| 驗收標準 | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` 回傳 `root root 600`;同樣的值儲存在 `/var/work/tests/artifacts/4/admin-conf.txt` 中。 |

<details>
<summary>💡 任務 4 的提示</summary>

一條指令就解決一切:`sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf`。之後請立刻檢查 - 如果你自己以 `ubuntu` 使用者透過 `KUBECONFIG=/etc/kubernetes/admin.conf` 使用這個檔案,讀取權限會消失,這是預期的 - 請為日常工作使用單獨的 kubeconfig。
</details>

---
| **5** | **禁止透過 SSH 以 root 登入** |
| :---: | :--- |
| 要做什麼 | 在 control-plane 上於 `/etc/ssh/sshd_config` 中設定 `PermitRootLogin no`,用 `sshd -t` 檢查語法,並安全地重新載入 SSH。請用指令 `sshd -T -C "user=root,addr=<你的 IP>,laddr=<節點的 IP>,lport=22"` 專門針對 root 連線檢查生效的值,而不是不帶 connection context 的單純 `sshd -T`。 |
| 驗收標準 | root connection context 下生效的 `permitrootlogin` 值等於 `no`;`/var/work/tests/artifacts/5/sshd.txt` 包含 `PermitRootLogin no`。 |

<details>
<summary>💡 任務 5 的提示</summary>

`sshd -T` 顯示的是「生效的」設定,但「沒有」connection context(`-C`)時,任何 `Match` 區塊(`Match User`/`Match Address`/`Match Group` 等)都完全不會套用 - `sshd(8)` 的 man page 明確說明,`Match` 規則在 test mode 中 "only when the connection parameters are supplied via one or more `-C` options" 才會套用。因此,不帶 `-C` 的 `sshd -T` 可能會從設定的主區塊顯示 `permitrootlogin no`,而更具體的 `Match` 區塊(例如 `Match Address <管理員 IP>` 或 `Match User root`)卻正好對真實的連線允許 root 登入。請透過 `sshd -T -C "user=root,addr=<IP>,laddr=<節點的 IP>,lport=22"` 檢查 - 這會模擬「真實的」root 入站連線,並讓 `sshd` 在顯示最終值之前套用所有相符的 `Match` 區塊。在執行 `systemctl reload sshd` 之前,「一定」要保持目前的 SSH 工作階段開啟,並從新的工作階段檢查 - 而不是在修改之前就已經通過驗證的那個工作階段。
</details>

---
| **6** | **關閉 `docker-host` 上對 Docker daemon 的不安全存取** |
| :---: | :--- |
| 要做什麼 | • 在單獨的 `docker-host` 上,停止透過 TCP/2375 發布 Docker API:從學習用的 systemd override 中移除 `-H tcp://...`,但保留僅透過 unix-socket 的存取。<br/>• 把 `/var/run/docker.sock` 設定為 `root:root`,mode 為 `660`;為了在 restart 之後保持,請透過 `docker.socket` override 設定。<br/>• 把 `developer` 從 `docker` 群組中移除。<br/>• 修改之後,務必執行 `sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service` - 這證明設定能撐過 daemon 的重新啟動,而不只是暫時符合預期的狀態。<br/>• restart 之後,確認 Docker 確實在運作(`sudo docker version`),而不只是被停止了。 |
| 驗收標準 | • **restart 之後 Docker 在運作:**在 `daemon-reload` + restart 之後,`docker.service` 與 `docker.socket` 處於 `active` 狀態,而 `sudo docker version`/`sudo docker info` 成功結束(positive control - Docker 確實在運作,而不只是「被關閉了,所以 2375 是關閉的」)。<br/>• **沒有 TCP API:**TCP/2375 上沒有 listener。restart 之後,Docker API 在任何埠上都沒有任何 TCP listener:effective `docker.service` 不包含 TCP `-H/--host`,而 `docker.socket` 不包含 TCP `ListenStream`;唯一的 API endpoint 是 Unix socket `/var/run/docker.sock`。<br/>• **Socket:**`stat -c '%U %G %a' /var/run/docker.sock` 回傳 `root root 660`;持久的 `docker.service`/`docker.socket` override(透過 `systemctl cat`)不包含 `-H tcp://`,並設定 `SocketGroup=root`/`SocketMode=0660`。<br/>• **使用者 `developer`:**不屬於 `docker` 群組,而 `sudo -u developer docker ps` 以存取錯誤結束。<br/>• **Artifacts:**建立 `/var/work/tests/artifacts/6/docker-tcp.txt`、`/var/work/tests/artifacts/6/docker-socket.txt`、`/var/work/tests/artifacts/6/developer-access.txt`,分別包含 `tcp/2375: closed`、`root root 660`、`developer docker ps: denied` 這幾行。 |

<details>
<summary>💡 任務 6 的提示</summary>

`docker` 群組的成員資格實際上等同於 root - 任何能存取 `docker.sock` 的行程,都可以透過 `--privileged` container 掛載主機的檔案系統。要確認 `developer` 已被從群組移除,只檢查 `groups developer` 是不夠的 - 群組成員資格的變更只套用到「新的」login 工作階段,請透過全新指令中的 `sudo -u developer docker ps` 檢查,而不是在已經開啟的 `developer` 工作階段中。不要停在第一次成功執行檢查 - 請執行 `daemon-reload` 以及兩個 unit(`docker.socket`、`docker.service`)的 `restart`,然後「再次」重複檢查:沒有這一步,你可能只是暫時停止了 Docker 就碰巧通過任務(此時 2375 是關閉的,不是因為移除了 `-H tcp://`,而是因為 daemon 根本沒有在運作)- 另外請確認 restart 之後 `sudo docker version` 能運作,這證明 Docker 確實在正常運作,而不只是「被關閉」。
</details>

---
| **7** | **禁止載入未使用的核心模組(`modprobe` blacklist)** |
| :---: | :--- |
| 要做什麼 | • 在 control-plane 上,模組 `sctp` 已載入,但在這個實驗中 kubeadm、containerd、Calico 都不需要它。嘗試卸載它(`sudo modprobe -r sctp`)。<br/>• **在已經在運作的叢集上,卸載可能無法成功,這不是錯誤:**協定的核心模組,會對載入當時存在的每個 netns 取得持久的 per-network-namespace 引用,而這個節點上已經有 Pod 在運作(calico、coredns 等);停止它們不屬於任務範圍。<br/>• 透過 `/etc/modprobe.d/60-cks-sctp.conf` 禁止重新載入,內容為指令 `blacklist sctp` 與 `install sctp /bin/true`。<br/>• 威脅模型的限制:這兩個指令都作用在 `modprobe` 層級(alias resolution 與 dependency loading)- 這不是對核心的絕對防護。`insmod` 直接透過核心 syscall 插入模組,不讀取 `modprobe.d`,而 `modprobe --ignore-install` 在具備相應 host-level 存取權時,可以繞過 `install` override。對節點的 root 擁有者而言,這是預期的:目標是消除一般的載入路徑(`modprobe sctp`、在存取該協定時依 alias 自動載入),而不是防範已經在節點上擁有 root 的使用者。<br/>• 確認 `modprobe --show-config` 顯示了生效的 override,且直接執行 `modprobe sctp` 不會改變模組的狀態。 |
| 驗收標準 | • **檔案:**`/etc/modprobe.d/60-cks-sctp.conf` 包含 `blacklist sctp` 與 `install sctp /bin/true` 兩行。<br/>• **生效的設定:**`modprobe --show-config \| grep sctp` 顯示 `install sctp /bin/true`。<br/>• **模組狀態:**直接再次執行 `modprobe sctp` 不會改變模組的狀態(原本已載入 - 仍然已載入,原本未載入 - 仍然未載入)。<br/>• **Artifact:**`/var/work/tests/artifacts/7/sctp.txt` 包含一行 `lsmod: absent` 或 `lsmod: present`(兩者擇一 - 真實的目前狀態)以及一行 `install sctp /bin/true`。 |

<details>
<summary>💡 任務 7 的提示</summary>

單單 `blacklist sctp` 並不會阻擋一切 - 它只妨礙依 alias resolution 的「自動載入」,但沒有 `install`-override 時,直接的 `modprobe sctp` 仍然會成功。兩行都需要:`blacklist` 用於自動載入,`install sctp /bin/true` 用於明確呼叫 `modprobe sctp`(把載入指令替換成 no-op)。請嘗試 `sudo modprobe -r sctp` 來卸載已經載入的模組,但如果你得到 `FATAL: Module sctp is in use`,且 `/sys/module/sctp/holders` 為空 - 這在已經在運作的叢集上是預期的(來自已啟動 Pod 的 per-netns pinning),並不妨礙通過任務;設定仍然會阻止「未來的」載入,而這正是被檢查的。
</details>

---
| **8** | **`protectKernelDefaults` 與 kubelet 的安全 sysctl** |
| :---: | :--- |
| 要做什麼 | • control-plane 上目前 `kernel.unprivileged_bpf_disabled = 0` - 非特權行程可以載入 eBPF 程式,這擴大了核心的 attack surface。請修正這一點。<br/>• 加入 `vm.overcommit_memory = 1`(在 memory pressure 下確保 kubelet/containerd 穩定的常見建議)。<br/>• 兩個參數都透過 `/etc/sysctl.d/99-kubernetes.conf` 設定,然後用 `sudo sysctl --system` 套用。<br/>• 在 `/var/lib/kubelet/config.yaml` 中啟用 `protectKernelDefaults: true`,並重新啟動 kubelet。<br/>• **順序很重要:**設為 `true` 時,kubelet 在啟動時會檢查目前的 kernel/cgroup 參數是否符合預期的預設值,如果不符合就**不會啟動** - 因此 sysctl 必須在重新啟動 kubelet「之前」套用,而不是之後。 |
| 驗收標準 | • **即時的值:**`sysctl kernel.unprivileged_bpf_disabled` 回傳 `1`;`sysctl vm.overcommit_memory` 回傳 `1`。<br/>• **持久的設定:**`/etc/sysctl.d/99-kubernetes.conf` 以有效的行包含兩個參數(`kernel.unprivileged_bpf_disabled = 1`、`vm.overcommit_memory = 1`);註解、`= 1 # comment` 或暫時性的 `sysctl -w` 都不算。<br/>• **kubelet:**`/var/lib/kubelet/config.yaml` 包含 `protectKernelDefaults: true`。<br/>• **重新啟動之後的狀態:**`systemctl is-active kubelet` 回傳 `active`,且節點保持 `Ready`。 |

<details>
<summary>💡 任務 8 的提示</summary>

這裡的順序至關重要,並且刻意在任務說明中強調:先 `sysctl --system`(套用這些值),「之後才」啟用 `protectKernelDefaults: true` 並重新啟動 kubelet。如果順序相反,kubelet 在啟動時會發現 kernel 參數與它的預期不符,並拒絕啟動 - 節點會保持 NotReady,而且不閱讀 kubelet 的 logs(`journalctl -u kubelet`)你就無法了解原因。檢查以 kubelet「實際生效」的設定為準,透過 `kubectl get --raw="/api/v1/nodes/<node>/proxy/configz"`,而不是 `config.yaml` 的文字 - 如果檔案中的那一行被註解掉了或有錯字,`grep` 仍然可能找到它,而 kubelet 卻繼續使用舊的預設值運作。修改檔案之後,務必重新啟動 kubelet,並透過 `configz` 檢查。
</details>

---
| **9** | **找出並解除多餘的 SUID 二進位檔** |
| :---: | :--- |
| 要做什麼 | • 在 control-plane 上執行 `find / -xdev -perm -4000 -type f 2>/dev/null`,並在結果中找到 `/usr/local/bin/cks-lab105-suid-tool` - 這是專門建立、帶有 SUID bit 的學習用二進位檔,在這個節點上沒有任何 Kubernetes 元件需要它。<br/>• 把修正「之前」找到的所有 SUID 檔案的完整清單儲存到 `/var/work/tests/artifacts/9/suid-before.txt`。<br/>• 移除這個二進位檔的 SUID bit(`chmod u-s`)。<br/>• 把修正「之後」`cks-lab105-suid-tool` 的 mode 儲存到 `/var/work/tests/artifacts/9/suid-after.txt`。<br/>• 不要動系統的 SUID 二進位檔(`passwd`、`sudo`、`mount` 等):移除它們會破壞作業系統的正常運作,而且不在任務範圍內。 |
| 驗收標準 | • **修正之前:**`suid-before.txt` 在找到的 SUID 檔案中包含路徑 `/usr/local/bin/cks-lab105-suid-tool`。<br/>• **修正之後:**`stat -c '%a' /usr/local/bin/cks-lab105-suid-tool` 回傳 `755`(沒有 SUID bit `4`);`suid-after.txt` 包含 `755`。<br/>• **系統二進位檔:**標準的 SUID 二進位檔(例如 `/usr/bin/sudo` 或 `/usr/bin/passwd`)保持 SUID bit 不被動到。 |

<details>
<summary>💡 任務 9 的提示</summary>

`chmod u-s` 只移除 SUID bit,不動其他權限(不同於 `chmod 755`,它也會覆寫所有其他權限位元 - 在這裡結果相同,但 `u-s` 作為一般習慣更安全)。除非絕對必要,不要執行不帶 `-xdev` 的 `find / -perm -4000` - 沒有它,指令會掃描掛載的網路/虛擬檔案系統,可能執行很久或卡住。檢查會把目前系統 SUID 二進位檔的集合,與實驗開始「之前」記錄的 baseline 比較 - 禁止動任何其他系統 SUID 二進位檔(不只是 `sudo`/`passwd`),而且如果你不小心(或有意)從其他東西上移除了 SUID,只是把 `sudo` 的 SUID 還原也沒有幫助。`/var/lib/containerd` 內的路徑(透過 overlayfs 的 container image 層)不計入 baseline,也不計入檢查 - 它們不是主機的檔案,而且它們的集合在 pull/extract 映像時自然會變化,與你無關。
</details>

---
| **10** | **停用 core dumps,並保護 SUID 行程不被傾印記憶體** |
| :---: | :--- |
| 要做什麼 | • 行程的 core dump 可能包含在 crash 當下位於記憶體中的解密後 secret、private key 與 token。<br/>• 在 control-plane 上,把 `* hard core 0` 與 `* soft core 0` 這幾行加入 `/etc/security/limits.conf`(限制 core dump 的大小)。<br/>• 禁止 SUID/privileged 行程的 dump:在 `/etc/sysctl.d/99-kubernetes.conf` 中設定 `fs.suid_dumpable = 0`(與任務 8 相同的檔案 - 不要建立另一個衝突的檔案)。<br/>• **在 Ubuntu 上這樣還不夠:**crash dump 預設不是直接寫入檔案,而是透過 `kernel.core_pattern`,它指向一個 userspace pipe handler(Apport)。Apport 會把 crash 攔截到 `/var/lib/apport/coredump/`,不管 `ulimit -c` 為何,因為核心對 pipe handler 會忽略 `RLIMIT_CORE`(參見 `man 5 core`:"RLIMIT_CORE will be ignored if the system is configured to pipe core dumps to a program")。<br/>• 因此請另外在同一個 `/etc/sysctl.d/99-kubernetes.conf` 中設定 `kernel.core_pattern = \|/bin/false` - 這會把 pipe-handler 換成一個必然無法運作的,核心既不會建立檔案形式的 dump,也不會透過 Apport 建立。套用 `sudo sysctl --system`。<br/>• 確認:`sysctl fs.suid_dumpable` 回傳 `0`,而 `cat /proc/sys/kernel/core_pattern` 回傳 `\|/bin/false`。<br/>• 確認:新的 login-shell(`bash -l` 或 `sudo su - ubuntu -c 'ulimit -c'` - 要帶 `sudo`,不帶的話,一般的 `su` 切換成自己仍然需要密碼)顯示 `ulimit -c` 等於 `0`。<br/>• 確認:在測試行程真正 crash(`SIGSEGV`)之後,不論是在 `/var/lib/apport/coredump/` 還是別處,都沒有出現新的 core dump。 |
| 驗收標準 | • **即時的值:**`sysctl -n fs.suid_dumpable` 回傳 `0`;`cat /proc/sys/kernel/core_pattern` 回傳 `\|/bin/false`。<br/>• **持久的 sysctl:**`/etc/sysctl.d/99-kubernetes.conf` 包含有效的(未被註解的)行 `fs.suid_dumpable = 0` 與 `kernel.core_pattern = \|/bin/false`。<br/>• **限制:**`/etc/security/limits.conf` 包含 `* hard core 0` 與 `* soft core 0` 兩行;新的 login-shell 顯示 `ulimit -c` 等於 `0`。<br/>• **Crash probe:**對測試行程的 controlled crash 不會產生新的保留的 core dump。<br/>• **Artifact:**`/var/work/tests/artifacts/10/coredump.txt` 包含所有的確認,包括 controlled crash probe 的結果。 |

<details>
<summary>💡 任務 10 的提示</summary>

在編輯 `limits.conf` 之後,你「目前」SSH 工作階段中的 `ulimit -c` 不會改變 - PAM 的限制只在建立「新的」工作階段/login-shell 時才套用。請透過 `sudo su - ubuntu -c 'ulimit -c'` 檢查(新的 login;`sudo` 是必須的 - 如果不是從 root 呼叫,即使 `su` 切換成自己也總是會要求密碼),或開啟新的 SSH 工作階段,而不是在你編輯檔案的同一個 shell 中檢查 `ulimit -c`。兩個值都需要:`hard` 是絕對上限,`soft` 是預設生效的值;如果只設定 `soft`,行程可以自己把限制提高到 `hard`。這個任務的關鍵陷阱:`ulimit -c 0` 與 `fs.suid_dumpable=0` 在 Ubuntu 上自己「並不會」停用 core dump - `man 5 core` 明確指出,如果 `kernel.core_pattern` 指向 pipe handler(`|program`),核心會忽略 `RLIMIT_CORE`,而 Ubuntu 預設正是把 crash 導向這樣的 handler(Apport),它不管 `ulimit` 都會攔截 dump。唯一可靠的方法是覆寫 `kernel.core_pattern` 本身(例如改成 `|/bin/false`),而不只是行程的限制。
</details>

## 補充:kernel 與 containerd/CRI hardening

這是在任務 7–9 之外簡短的 node-local 練習,不屬於 fixture 的自動驗收標準。
它展示更廣泛的 CRI 情境,不侷限於某個具體的核心模組。

在這個實驗中,Kubernetes 使用的是 **containerd**,而不是 Docker。因此同樣的原則
必須套用到 CRI:檢查 `/run/containerd/containerd.sock` 與
`/etc/containerd/config.toml` 的權限,不要把一般使用者加入能存取
這個 socket 的群組,並且只允許具特權的
管理員使用 `ctr`/`crictl` 連到這個 endpoint。不要盲目更改正在運作的 CRI socket 的擁有者或 mode:錯誤的
設定會讓 kubelet 與 workload 停止。

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# 預期非特權使用者會被拒絕存取
```

## 檢查

在 `worker` 上執行:

```bash
check_result
```

檢查包含 `0 Init` 與十個獨立的測試。它會透過 SSH 檢查兩台
主機的狀態以及必要的 artifacts。修改 `sshd_config` 或 systemd unit 之後,
請等 `systemctl reload/restart` 完成,再重新執行檢查。

## 解答

參考解答:[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=105 make delete_cks_task
```
