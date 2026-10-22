[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 106 - AppArmor 與 seccomp:node-local policy 與可驗證的拒絕

## 目標

在這個 CKS 實驗中，你要套用兩個獨立的機制，在 Linux 核心層級保護容器行程。
首先，把事先放好的 **AppArmor** profile 從 `complain` 切換到 `enforce`，透過現代的欄位
`securityContext.appArmorProfile` 指派給 Pod，並證明寫入被拒絕。接著指派安全的
baseline `RuntimeDefault`，以及會封鎖系統呼叫 `unshare(2)` 的自訂 **seccomp Localhost** profile。

這是 CKA 實驗 106 中基本 `SecurityContext` 的延續：這裡光寫
YAML 是不夠的。Localhost profile 存在於 Kubernetes 節點上，因此需要檢查節點、
Pod 的 placement，以及行程的實際行為。

## Threat model

假設容器中發生了 RCE。compromise 之後的問題不是「攻擊者能否取得 shell」，而是「這個 shell 接下來能做什麼」，以及它的 blast radius 有多大。

任務 1-3 中的 AppArmor 限制物件與操作：profile 被切換到 enforce，接著證明寫入被拒絕。這樣已經被入侵的行程，不會僅僅因為它在容器中執行，就取得不受限制的動作。

任務 4-6 中的 seccomp 限制可用的系統呼叫：先套用 baseline，然後套用自訂 profile，再檢查 `unshare(2)` 實際被拒絕。任務 6 已經透過 Pod `sysadmin-control` 包含了 negative control：在相同的 capability 下，沒有 seccomp filter 時呼叫會成功，因此比較顯示的正是 compromise 之後的邊界。

## 開始前先自我檢查

<details>
<summary>1. AppArmor 中的 `complain` 與 `enforce` 有什麼不同，為什麼不能把 `complain` 當作防護的證明？</summary>

在 `complain` 模式下，AppArmor 只記錄違反 profile 的行為，但「不會」阻擋 - 本來應該被禁止的操作仍然會執行，只是在 log 中多了一筆記錄。在 `enforce` 中，操作會真正被阻擋。任務 2 明確要求把 profile 切換到 `enforce`，因為在 `complain` 下展示「看，log 裡有違規記錄」並不能證明防護 - 行程仍然能夠執行該動作。
</details>

<details>
<summary>2. 為什麼 `allowPrivilegeEscalation: false` 不會移除已經授予的 capability `SYS_ADMIN`？</summary>

`allowPrivilegeEscalation: false` 會啟用 kernel 旗標 `no_new_privs`，它禁止行程透過 `execve` 取得「新的」權限(例如透過 setuid 二進位檔或 file capabilities)。這不影響行程「已經」在其 effective/bounding set 中擁有的權限 - 如果容器在 manifest 中明確地以 capability `SYS_ADMIN` 啟動，這個 capability 就會保持可用，與 `allowPrivilegeEscalation` 的值無關。
</details>

<details>
<summary>3. 為什麼 Pod manifest 中的 `localhostProfile` 要指定為相對路徑，而不是絕對路徑？</summary>

Kubelet 會自己以相對於其 seccomp root(預設為 `/var/lib/kubelet/seccomp/`)的方式解析相對路徑。如果指定絕對路徑，kubelet 會在 seccomp root 內「依這個絕對路徑」尋找檔案，這幾乎總是與檔案的實際位置不符 - Pod 會得到 `CreateContainerError`。
</details>

## 與課程的關聯

- [第 16 章 AppArmor](../../course/16/tw.md)
- [第 17 章 seccomp](../../course/17/tw.md)
- [第 03 章 Container Runtime Security](../../course/03/tw.md)

## 基礎架構

環境透過 Terragrunt 部署在 AWS `eu-central-1`。

| 元件 | 用途 |
|---|---|
| `vpc` | VPC `10.10.0.0/16`，含公有子網路 |
| `ssh-keys` | 用於存取節點的金鑰 |
| `k8s-1` | 單節點 kubeadm 叢集 Kubernetes `1.36.0`、containerd 與 **Calico** |
| `worker` | 具備 `kubectl`、`check_result`，並以 `control-plane` 身分 SSH 存取節點的工作機 |

為了節省資源，control-plane 是唯一的 workload 節點：它的
`NoSchedule` taint 已移除。它被標上 label
`security.cks.io/localhost-profiles-106=true`。這個實驗的所有 Pod 都必須選擇這個
節點 - Localhost-profile 只存在於這個節點上，排程器(scheduler)不會把它搬到其他節點。

Bootstrap「只」準備了：

- 節點 label `security.cks.io/localhost-profiles-106=true`，用於安全的 placement;
- 在工作機(worker)上的 `/opt/lab106-fixtures/`:`k8s-106-deny-write`
  (AppArmor profile)與 `cks-106-deny-unshare.json`(自訂 seccomp profile)的原始檔。

AppArmor profile 與 seccomp profile **都沒有**預先安裝在 workload 節點上，也沒有
載入到其核心中 - 它們各自的搬移與首次載入，是任務 1 與 5 的一部分。
不要更改 seccomp profile 的路徑，也不要在一般的 Pod 內建立 profile：把
檔案搬到節點上，是你以節點管理員的身分透過 SSH 完成的，而不是從 workload 內部。

## 部署

```bash
TASK=106 make run_cks_task
```

透過 SSH 連線到工作機。context 已經設定好：

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

在開始之前，先檢查對節點的存取以及 worker 端的 fixtures:

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ls -la /opt/lab106-fixtures/
```

## 任務

---
| **1** | **搬移並載入 AppArmor profile** |
| :---: | :--- |
| 要做什麼 | profile `k8s-106-deny-write` 的原始檔只存在於工作機上的 `/opt/lab106-fixtures/k8s-106-deny-write`。把它複製到節點 `control-plane` 的 `/etc/apparmor.d/k8s-106-deny-write`(例如透過 `scp`)，並用 `sudo apparmor_parser -r` 載入核心。Profile 已經包含旗標 `complain` - 不需要再次啟用它，那是任務 2 的內容。 |
| 驗收標準 | `/etc/apparmor.d/k8s-106-deny-write` 存在於節點上；`/sys/kernel/security/apparmor/profiles` 包含名稱為 `k8s-106-deny-write` 的行(任何模式 - `complain` 或 `enforce` 皆可)，也就是說 profile 確實已載入核心，而不只是複製到磁碟上。 |

<details>
<summary>💡 任務 1 的提示</summary>

`scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/` 會把檔案複製到節點的
暫存目錄；請從那裡用 `sudo` 把它移動到 `/etc/apparmor.d/`(一般
使用者沒有直接寫入那裡的權限)。然後 `sudo apparmor_parser -r
/etc/apparmor.d/k8s-106-deny-write` 會編譯並把 profile 載入核心 - 沒有這
一步，磁碟上的檔案完全不提供任何防護，也不會出現在
`/sys/kernel/security/apparmor/profiles` 中。
</details>

---
| **2** | **把 AppArmor profile 切換到 enforce** |
| :---: | :--- |
| 要做什麼 | 在節點 `control-plane` 上，把任務 1 中載入的 profile `k8s-106-deny-write` 切換到 `enforce` 模式。原本的 `complain` 模式會記錄違規，但不是防護。不要刪除 profile，也不要更改它的名稱。 |
| 驗收標準 | 帶有 label `security.cks.io/localhost-profiles-106=true` 的節點存在；`/etc/apparmor.d/k8s-106-deny-write` 可用；`/sys/kernel/security/apparmor/profiles` 包含行 `k8s-106-deny-write (enforce)`。Checker-owned bootstrap-baseline(在發放實驗「之前」，對同一個 profile 的過渡副本在它還處於 `complain` 時記錄)確認，符合這個 profile 的 `/work/**` 模式的寫入，當時確實是成功的 - 沒有這一點，就無法證明後來的拒絕正是由切換到 `enforce` 引起的。 |

<details>
<summary>💡 任務 2 的提示</summary>

指令 `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` 會重新載入已存在的 profile - 如果它原本是 `complain`，而磁碟上的檔案已經描述為 `enforce`，這個指令就足夠了。請透過 `sudo cat /sys/kernel/security/apparmor/profiles | grep k8s-106-deny-write` 自行檢查 - 輸出必須明確顯示 `(enforce)`。不要透過 `aa-status` 來檢查：這個指令會把 profile 分組在各區段標題下(`N profiles are in enforce mode.`)，並且在其下只印出單純的 profile 名稱，每一行「沒有」`(enforce)`/`(complain)` 後綴 - 這樣的後綴只出現在 `/proc/<pid>/attr/current` 以及核心檔案 `/sys/kernel/security/apparmor/profiles` 中，而不在 `aa-status` 的 profile 清單中。

在完成任務 9 之前，不要對這個 profile 使用 `aa-enforce`/`aa-complain`:
來自 `apparmor-utils` 的這些 Python 工具，在做主要工作之前會先解析
(parse)`/etc/apparmor.d/` 中的**所有**檔案，包括任務 9 中仍然損壞的 `k8s-106-broken-profile`,
並在其他無關的檔案上因 parser 錯誤而失敗。請直接編輯 profile 檔案中的 `complain` 旗標(`sed`),
並透過 `apparmor_parser -r` 重新載入「這個」檔案 -
與 `aa-enforce` 不同，這個二進位檔只解析傳給它的檔案。
</details>

---
| **3** | **Localhost AppArmor Pod 與寫入阻擋** |
| :---: | :--- |
| 要做什麼 | 建立 namespace `security-106` 與 Pod `apparmor-writer`。Pod 必須選擇基礎架構中的節點 label，停用 ServiceAccount token 的 automount，並在 Pod 層級設定 `appArmorProfile.type: Localhost`、`localhostProfile: k8s-106-deny-write`。使用 `busybox:1.36`、容器 `app`、休眠指令 `sleep 3600`，以及掛載到 `/work` 的 `emptyDir`。啟動之後，用指令 `cat /proc/1/attr/current` 確認生效的 profile(如果該介面可用)，執行被允許的讀取操作，例如 `cat /etc/hostname >/dev/null`，然後嘗試在 `/work` 中寫入檔案；該操作必須以拒絕結束。在節點上，從 `journalctl -k \| grep -i apparmor` 或 `dmesg \| grep -i apparmor` 中記錄針對該 profile/process 的 AppArmor denial。 |
| 驗收標準 | Pod 正在執行，使用的正是 Localhost profile 與正確的 nodeSelector；行程生效的 profile 顯示 `k8s-106-deny-write` 處於 enforce mode(當 `/proc/.../attr/current` 可用時)；被允許的讀取操作(例如 `cat /etc/hostname` 或 `ls /work`)成功，而 checker 會獨立地在 `/work` 中寫入它自己唯一的(per-run)檔案，並得到 AppArmor 拒絕。在 kernel journal/audit log 中有針對「這次」嘗試(依唯一的檔名)、帶有這個 profile 的事件 `apparmor="DENIED"` - 這排除了來自 log 中過期 denial 事件的 false pass。 |

<details>
<summary>💡 任務 3 的提示</summary>

類型為 `Localhost` 的 profile,`appArmorProfile` 透過兩個獨立的欄位指定：`type: Localhost` 與 `localhostProfile: k8s-106-deny-write`(profile 名稱，「不帶」路徑 `/etc/apparmor.d/`)- 這是任務 1 中載入 profile 時使用的同一個名稱。如果 Pod 無法啟動(CreateContainerError)，請檢查 profile 確實已載入到 nodeSelector 所選的「正確」節點上 - AppArmor profile 是 node-local 的，不會自動搬移。
</details>

---
| **4** | **安全的 baseline seccomp RuntimeDefault** |
| :---: | :--- |
| 要做什麼 | 在 `security-106` 中建立 Pod `runtime-default`，使用 `busybox:1.36` 與 `sleep 3600`。在 Pod 層級明確指定 `securityContext.seccompProfile.type: RuntimeDefault`;Pod 同樣必須選擇準備好的節點。在容器中檢查 `/proc/1/status`：預期為 `Seccomp: 2`。 |
| 驗收標準 | Pod 為 `Running`，在其 Pod-level securityContext 中選擇了 `RuntimeDefault`，且行程處於 seccomp filter mode。 |

<details>
<summary>💡 任務 4 的提示</summary>

`/proc/1/status` 中的 `Seccomp: 2` 表示「filter mode 已啟用」(SECCOMP_MODE_FILTER)- 這是你應該看到的。`Seccomp: 0` 則表示完全沒有 seccomp filter(`Unconfined`)。這是三個 seccomp 任務(4-6)中最簡單的 - 如果它沒有通過，問題很可能出在 nodeSelector，而不是 seccompProfile 本身。
</details>

---
| **5** | **搬移並使用自訂的 Localhost seccomp profile** |
| :---: | :--- |
| 要做什麼 | 原始檔 `cks-106-deny-unshare.json` 只存在於工作機上的 `/opt/lab106-fixtures/cks-106-deny-unshare.json`。找出帶有 label `security.cks.io/localhost-profiles-106=true` 的節點，在其上建立目錄 `/var/lib/kubelet/seccomp/profiles/`(如果還沒有)，並把 JSON 以相同的名稱複製到那裡。然後在這個節點上於 `security-106` 中建立 Pod `localhost-seccomp`。在 Pod 層級指定 `seccompProfile.type: Localhost` 與相對路徑 `profiles/cks-106-deny-unshare.json` - 不帶 `/var/lib/kubelet/seccomp/`。容器 `app` 必須使用 `busybox:1.36`，取得 capability `SYS_ADMIN`，並在檢查之後保持執行。**不要把這個組合當成 hardened baseline:**`SYS_ADMIN` 仍然是最危險的 capabilities 之一，而 `allowPrivilegeEscalation: false` 不會收回已經授予的權限。這是一個以 capability 為重點的實驗，其中的安全性由具體的 seccomp deny 來展現。 |
| 驗收標準 | JSON profile 已搬移，並存在於節點上的正確路徑；帶有正確 nodeSelector 的 Pod 使用 profile `Localhost:profiles/cks-106-deny-unshare.json`;JSON profile 包含針對 `unshare` 的 `SCMP_ACT_ERRNO`/`errnoRet: 1`；容器中只加入了實驗所需的 `SYS_ADMIN`。 |

<details>
<summary>💡 任務 5 的提示</summary>

路徑 `profiles/cks-106-deny-unshare.json` 是相對於 kubelet seccomp root `/var/lib/kubelet/seccomp/` 的，也就是說，節點上的實際檔案必須位於 `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json` - 正是要把它從工作機複製到那裡(例如 `scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/`，然後在節點上 `sudo mkdir -p` 與 `sudo mv`)。不要在 manifest 中寫完整的絕對路徑 - kubelet 會自己加上 root。`SYS_ADMIN` 在這裡「正是」為了實驗而給的(需要一個原則上能夠呼叫 `unshare` 的 capability)，而不是作為建議的做法 - 不要把學習情境與 production baseline 混為一談。
</details>

---
| **6** | **證明系統呼叫 `unshare(2)` 被拒絕** |
| :---: | :--- |
| 要做什麼 | 在容器 `localhost-seccomp` 的指令中執行 `unshare -n true`，把預期拒絕的成功確認以字串 `unshare denied by seccomp` 儲存到 `/tmp/unshare-result`，然後用 `sleep 3600` 保持容器運作。再次執行 `kubectl exec ... -- unshare -n true` 必須回傳非零代碼。作為 attack-minded 的 negative control，在同一個節點上建立 Pod `sysadmin-control`，使用 `seccompProfile.type: Unconfined` 與相同、唯一的 capability `SYS_ADMIN`；它的 `unshare -n true` 必須成功結束。檢查之後刪除 control Pod。 |
| 驗收標準 | Localhost Pod 正在執行；`Seccomp: 2`;`unshare` 被自訂 profile 阻擋。在 control Pod 中，相同的系統呼叫、相同的 capability 且沒有 seccomp filter 時會成功。這證明了核心的行為，而不只是 YAML 的存在。 |

<details>
<summary>💡 任務 6 的提示</summary>

請使用 `unshare -n true`(unshare network namespace,`CLONE_NEWNET`)，而「不要」
用 `unshare -m true`。`-m`(mount namespace)和 `-n` 一樣需要 `CAP_SYS_ADMIN`，但
BusyBox 的 `unshare -m` 在成功執行 `unshare(2)` 之後，還會額外執行「第二個」、
獨立的 `mount(2)` 系統呼叫(`mount("none", "/", NULL, MS_REC|MS_PRIVATE, NULL)`,
用來強制設定 private propagation - 這是 unshare 預設啟用的行為，
除非明確傳入 `--propagation unchanged`，而即使如此 `mount()` 仍然會
被呼叫，只是旗標為零)。containerd 預設的 AppArmor profile(`RuntimeDefault`,
沒有明確 `securityContext.appArmorProfile` 的 Pod 會取得它)包含 `deny mount,`,
沒有任何針對旗標的條件 - 這項禁止的生效與 capabilities 以及 seccomp 無關。
因此 `unshare -m true` 可能因為 AppArmor 而以 `EPERM` 失敗，「即使」
seccomp 根本沒有限制 `unshare`，這使得這樣的探測不能可靠地證明
是 seccomp 造成的拒絕。`unshare -n`(`CLONE_NEWNET`)「只」呼叫
系統呼叫 `unshare(2)` 本身，之後沒有任何 `mount()` - 而 `localhost-seccomp` 與
`sysadmin-control` 使用相同的 `SYS_ADMIN`，因此結果的差異
明確地只能由 seccomp filter 來解釋，而不是 AppArmor 的副作用。

指令的順序對於證明力很重要：先執行 `unshare -n true`，並確認它以錯誤失敗(非零 exit code)，「之後」才把字串 `unshare denied by seccomp` 寫入 `/tmp/unshare-result` - 不要預先寫入這個字串，「假設」結果。Negative control(`sysadmin-control`)必須使用「相同的」capability `SYS_ADMIN`，但 `seccompProfile.type: Unconfined` - 如果忘了明確指定 `Unconfined`,Pod 預設可能會取得 `RuntimeDefault`(如果啟用了任務 8 中的 `seccompDefault`)，那麼測試就看不出差別。
</details>

Linux capabilities 與 privilege escalation 是不同的軸。`allowPrivilegeEscalation: false`
會啟用 `no_new_privs`，並禁止透過 `execve` 取得**新的**權限(setuid/setgid 與
file capabilities)，但不會移除已經加入 bounding/effective set 的 `SYS_ADMIN`。
對於一般的工作負載，請使用 `capabilities.drop: ["ALL"]`，並單獨使用
`allowPrivilegeEscalation: false`；上面的實驗刻意不是這樣的 baseline。

---
| **7** | **User namespaces:`hostUsers: false` 與透過 `uid_map` 的 UID 轉換** |
| :---: | :--- |
| 要做什麼 | User namespaces 在 Kubernetes v1.36 中為 GA(參見 [第 03 章](../../course/03/tw.md)、[第 18 章](../../course/18/tw.md) 以及 Security Delta v1.36)。理論說明 `hostUsers: false` 會把容器的 root 轉換為非特權的 host UID；這裡需要在執行中的行程上證明這一點。在 `security-106` 中，於準備好的節點上建立 Pod `userns-probe`，帶有 `spec.hostUsers: false`、映像 `busybox:1.36`、指令 `sleep 3600`；不要設定 Pod-level `runAsUser`，讓行程在容器「內部」以 UID 0 啟動。確認容器內的 `id`(`uid=0`)。透過 `crictl inspect`(比照實驗 112 的做法)或透過 `kubectl get pod -o jsonpath` + `crictl ps` 找出容器行程的 host PID，然後在節點上讀取 `/proc/<host PID>/uid_map`。把兩個輸出(容器內的 `id` 與 `uid_map` 的內容)儲存到 `/var/work/tests/artifacts/6/userns.txt`。 |
| 驗收標準 | Pod 為 `Running`,`spec.hostUsers == false`，並選擇準備好的節點；容器內的 `id` 顯示 `uid=0(root)`；節點上的 `/proc/<host PID>/uid_map` 包含形如 `0 <host-uid> <length>` 的行，其中 `<host-uid>` **不等於 0**(容器的 root 被轉換為非特權的 host UID)，且 `<length>` 至少等於 `65536`(標準的 per-Pod UID 範圍);artifact 包含 evidence 的兩部分。 |

<details>
<summary>💡 任務 7 的提示</summary>

容器「內部」的 `id` 無論 `hostUsers` 為何，都會顯示 `uid=0(root)` - 這是預期的，容器看到的是它「自己的」namespace，在那個 namespace 中它的 root 確實是 UID 0。真正的防護只有從「外部」才看得到：在節點本身上，於 `/proc/<host PID>/uid_map` 中，容器內的 UID 0 被轉換為主機上某個很大的非特權 UID。要找到 host PID，請使用 `crictl inspect <container-id>` - 正是從那裡，而不是 `kubectl get pod`，因為後者只知道 Kubernetes 物件，不知道行程在 host 層級的 PID。
</details>

---
| **8** | **kubelet 層級的 `seccompDefault: true`：沒有明確 profile 的 baseline** |
| :---: | :--- |
| 要做什麼 | 任務 4-6 中的所有 Pod 都在 manifest 中明確指定了 `seccompProfile`。現實中，開發者可能會忘記這個欄位 - 這時如果沒有 node-level baseline,Pod 會得到 `Unconfined`。在節點上，於 `/var/lib/kubelet/config.yaml` 中啟用 `seccompDefault: true`，並重新啟動 kubelet(`systemctl restart kubelet`)。在 `security-106` 中，於準備好的節點上以 `busybox:1.36`(`sleep 3600`)建立 Pod `no-seccomp-field`,**完全不指定 securityContext.seccompProfile**，無論是 Pod 層級還是容器層級。透過容器內的 `/proc/1/status` 確認 kubelet 自動套用了 `RuntimeDefault`(`Seccomp: 2`)，而不是留下 `Unconfined`(`Seccomp: 0`)。 |
| 驗收標準 | kubelet 生效(已套用)的設定 - 透過 `/api/v1/nodes/<node>/proxy/configz`，欄位 `.kubeletconfig.seccompDefault` - 等於 `true`;`systemctl is-active kubelet` 回傳 `active`，節點保持 `Ready`;Pod `no-seccomp-field` 在其規格的任何層級都沒有 `seccompProfile`；容器內的 `/proc/1/status` 顯示 `Seccomp: 2`。 |

<details>
<summary>💡 任務 8 的提示</summary>

關鍵要求是 Pod「確實」完全不能提到 `seccompProfile`，無論是 Pod 層級還是容器層級。如果你複製了任務 4-6 的 manifest，卻忘了刪除這個欄位 - 測試就無法證明它應該證明的事：也就是說，讓 `Seccomp: 2` 生效的，是 node-level 的 `seccompDefault`(而不是 manifest 中的明確指定)。

檢查以 kubelet「實際套用」的設定為準，而不是磁碟上檔案的文字：
`curl`/`kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq .kubeletconfig.seccompDefault`。
單純對 `/var/lib/kubelet/config.yaml` 做 grep，並不能證明執行中的 kubelet 使用的正是這個檔案 -
命令列旗標或 drop-in 可能在不改動檔案本身的情況下覆寫該值。
修改檔案之後，務必重新啟動 kubelet - 設定不會即時被載入。
</details>

---
| **9** | **除錯並重建損壞的 AppArmor profile(`apparmor_parser -r -v`)** |
| :---: | :--- |
| 要做什麼 | 磁碟上已經有 `/etc/apparmor.d/k8s-106-broken-profile` - 一個有語法錯誤、**從未被載入**核心的 profile。請自己透過 `sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile`(`-Q`/`--skip-kernel-load`：完整地執行 profile 的檢查/編譯，但不載入核心)或 `sudo apparmor_parser -d /etc/apparmor.d/k8s-106-broken-profile`(`-d`/`--debug`，只指定一次 - 只檢查語法是否正確)找出錯誤，修正檔案，並透過 `sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile` 把 profile 載入核心。透過 `aa-status \| grep k8s-106-broken-profile` 確認已載入。把修正「之前」的錯誤輸出，以及「之後」的載入確認，儲存到 `/var/work/tests/artifacts/8/apparmor-debug.txt`。 |
| 驗收標準 | `apparmor-debug.txt` 包含**修正之前**那次嘗試的 parser 錯誤文字(例如 `syntax error`);checker-owned bootstrap-baseline(在發放實驗「之前」記錄，與你的 artifact 無關)獨立地確認原始 profile 確實包含 syntax error；磁碟上的 `/etc/apparmor.d/k8s-106-broken-profile` 不再包含原本的語法錯誤；`aa-status` 顯示 `k8s-106-broken-profile` 在已載入的 profile 之中(任何模式 - `enforce` 或 `complain`)；對修正後的檔案再次執行 `apparmor_parser -Q` 沒有錯誤地結束。 |

<details>
<summary>💡 任務 9 的提示</summary>

`apparmor_parser -p`(`--preprocess`)「不是」安全的 dry-run/語法檢查模式 - 它
只是 preprocessing：展開 `#include` 指令並把得到的
profile 印到 stdout，本身不保證沒有副作用，也不是
專門用來檢查語法的。請使用 `-Q`/`--skip-kernel-load`
(執行完整的編譯/檢查，但不載入核心)或 `-d`/`--debug`
(一次 - 只檢查語法是否正確)，以「安全地」找出
語法錯誤而沒有副作用。只有在修正檔案之後，才使用
`-r`(reload/load)真正載入核心。AppArmor 的語法要求以逗號
作為區塊內規則的分隔符號 - 請研究 parser 的輸出，找出缺少了哪個字元，
以及確切在哪裡。

請透過 `sudo` 執行 `apparmor_parser`，即使是 `-Q`/`-d`：在實驗節點(apparmor 3.0.4,
Ubuntu)上，沒有權限時 parser 每次啟動都會嘗試設定 `/var/cache/apparmor` 中的 policy cache,
並在檢查語法「之前」就以 "Failed setting up policy cache: Permission denied" 失敗 -
你會得到關於權限的誤導性錯誤，而不是 profile 真正的語法錯誤。這已在節點本身上驗證過(包括在確定損壞的 profile 上)。
如果需要不帶 `sudo` 執行，請加上 `-K`(`--skip-cache`：不做任何快取)-
不帶權限的 `apparmor_parser -Q -K` 能夠進行到解析 profile，並顯示真正的
錯誤。載入與 reload(`-r`)無論如何都需要權限。
</details>

## 檢查

在工作機上執行：

```bash
check_result
```

檢查包含 Init 與九個獨立的測試。它透過 API 讀取 Pod 的 state，透過 SSH 檢查節點上的
profile，並執行受控的負向情境。如果 Localhost
Pod 無法建立，請先查看 `kubectl describe pod`：常見的原因是使用了絕對
路徑而不是相對路徑，或是把 Pod 指派到沒有 profile 的節點上。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=106 make delete_cks_task
```
