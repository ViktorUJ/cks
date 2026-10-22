[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 105 - System Hardening of the OS and Docker daemon security

## Goal

In this CKS lab you reduce the attack surface of two Linux hosts. On the Kubernetes
control-plane you need to disable unnecessary services, close an open port, configure the firewall,
protect the kubeconfig, and forbid direct root login over SSH. On the separate `docker-host`
you need to eliminate three dangerous Docker daemon settings: the TCP API without TLS, access to
`docker.sock` through the `docker` group, and the access of the user `developer` to this socket.

This training environment is deliberately made insecure. Do not carry the initial settings
over into production: the Docker API on TCP/2375 without TLS gives remote root access to anyone who can
connect to the port.

## Self-check before you start

<details>
<summary>1. How does `systemctl disable` differ from `systemctl stop`, and why are both needed for task 1?</summary>

`stop` stops an already running process right now, but does not affect autostart on the next boot of the system. `disable` removes the service from autostart (the unit file is no longer bound to the target), but does not stop an already running process. To fully close the attack surface you need both - otherwise the service either keeps running now, or starts again after a reboot.
</details>

<details>
<summary>2. Why is the TCP Docker API without TLS (`-H tcp://0.0.0.0:2375`) equivalent to remote root access?</summary>

The Docker daemon runs with root privileges, and its API has no built-in authentication without TLS client certificates. Anyone who can connect to this port over the network can run an arbitrary container with `--privileged` and the host filesystem mounted - and get full control over the host, bypassing SSH and any other access control mechanisms.
</details>

<details>
<summary>3. Why is `chmod 600` for the kubeconfig important, even if the file is already accessible only to root through the filesystem?</summary>

`/etc/kubernetes/admin.conf` contains a client certificate with `cluster-admin` rights - if the file mode is too broad (for example, `644`, readable by everyone), ANY user on this node, even without sudo, can read the credential and get full administrative access to the cluster remotely, without needing any privilege escalation on the node itself.
</details>

<details>
<summary>4. Why can a process core dump leak a secret even if the secret itself was never written to disk?</summary>

A core dump is a memory image of the process at the moment of the crash, which **may** include decrypted values of variables, private keys, and tokens held in plain form. It is not guaranteed to be the entire memory of the process: the set of mappings depends on `/proc/<pid>/coredump_filter`, and individual regions may be excluded, for example via `MADV_DONTDUMP`. Therefore even if the application never explicitly writes the secret to a file, a crash dump may save the secrets that were present in the included mappings to disk in a readable file.
</details>

## Related Course Chapters

- [Chapter 14. Minimizing the host OS footprint and runtime daemon security](../../course/14/README.md)
- [Chapter 15. Host least privilege and minimizing external access](../../course/15/README.md)
- [CKA: systemd, services, and Linux](../../../cka/course/00-5-linux/README.md)
- [CKA: containers and runtime](../../../cka/course/00-4-containers/README.md)

## Infrastructure

The environment is deployed via Terragrunt in AWS `eu-central-1`:

| Component | Purpose |
|---|---|
| `vpc` | VPC `10.10.0.0/16` with two public subnets |
| `ssh-keys` | an SSH key for internal connections |
| `k8s-1` | a single-node kubeadm Kubernetes `1.36.0` cluster, containerd, Calico; this is the target control-plane |
| `docker-host` | a separate Ubuntu 22.04 with Docker and a deliberately insecure configuration |
| `worker` | a work machine with `kubectl`, the SSH configuration, and `check_result` |

`worker` has SSH access to the control-plane by its Kubernetes node name and to the separate
host by the name `docker-host`. Docker is not the runtime of the Kubernetes cluster: its
configuration from task 6 is isolated on `docker-host`.

## Deployment

```bash
TASK=105 make run_cks_task
```

Connect to `worker` (the kubectl context is already configured), look up the name of the control-plane
node, and log in to the hosts:

```bash
kubectl get no
ssh <node-name-from-the-output>
ssh docker-host
```

Useful commands:

```bash
time_left
check_result
```

Save the verification artifacts in `/var/work/tests/artifacts/<number>/`. You do not need to create
Kubernetes manifests for this lab.

## Tasks

---
| **1** | **Disable an unnecessary service** |
| :---: | :--- |
| What to do | On the control-plane disable and stop `cks-lab105-unused.service`. The service is not needed for Kubernetes to work and must not start after a reboot. |
| Acceptance criteria | `systemctl is-enabled cks-lab105-unused.service` returns `disabled`, `systemctl is-active` - `inactive`; `/var/work/tests/artifacts/1/service.txt` contains the line `disabled inactive`. |

<details>
<summary>💡 Hint for task 1</summary>

The order of commands: `sudo systemctl stop cks-lab105-unused.service && sudo systemctl disable cks-lab105-unused.service` - both steps are needed, neither replaces the other (see question 1 in the self-check section above). The artifact must contain exactly the line "disabled inactive" (in this order, separated by a space) - check the format before saving.
</details>

---
| **2** | **Close an unnecessary open port** |
| :---: | :--- |
| What to do | On the control-plane eliminate the TCP/8080 listener created by `cks-lab105-port.service`. Disable and stop the service (both actions are mandatory - see question 1 in the self-check); it is needed neither by the control-plane nor by the kubelet. |
| Acceptance criteria | `ss -ltn` does not show TCP/8080; `systemctl is-enabled cks-lab105-port.service` returns `disabled`, `systemctl is-active` - `inactive`; `/var/work/tests/artifacts/2/service.txt` contains the line `disabled inactive`; `/var/work/tests/artifacts/2/port-8080.txt` contains `tcp/8080: closed`. |

<details>
<summary>💡 Hint for task 2</summary>

First find out which process holds the port (`sudo ss -ltnp | grep 8080`), to make sure that it really is `cks-lab105-port.service` and not something else. Closing the port through the firewall (task 3) is not enough for this task - the test checks that the listener ITSELF is absent, not merely blocked from outside.
</details>

---
| **3** | **Restrict incoming traffic with the firewall** |
| :---: | :--- |
| What to do | • Before enabling UFW, record the role of the node, the worker source IP, the node InternalIP, and `spec.podCIDR`.<br/>• **Mandatory baseline before the firewall:** record a baseline probe of TCP/10250 (the kubelet HTTPS endpoint) from the worker - a `curl` with a real `CURL_EXIT`/`HTTPCODE` proving the network reachability of the port (any 1xx-5xx, including 401/403, counts as reachability - the kubelet API really answered). Without this step the post-hardening "blocked" cannot be told apart from an unrelated failure (security group, routing) that blocked the port even before UFW. In addition to your record, the checker independently compares this with its own bootstrap baseline, recorded BEFORE the lab was handed out in the protected directory `/var/lib/cks-lab105-checker` (`0711 root:root`, separate from `/var/work/tests`, which is writable by everyone by default).<br/>• Topology: a single-node control-plane + workload node. Exactly five rules are needed: loopback, SSH recovery from the worker, the API `6443/tcp` from the worker, from the node itself, and from the Pod CIDR. etcd/scheduler/controller-manager use local flows, there are no inter-node CNI/kubelet flows in this topology.<br/>• Manage the firewall only with the `ufw` command (allow/deny/reject/limit/route, then enable/reload). Do not edit `/etc/ufw/before*.rules`, `after*.rules`, `user.rules`, `user6.rules` by hand: the framework files (before/after) are compared by hash with the bootstrap baseline, and `user.rules`/`user6.rules` (where ufw writes your rules) are checked through the actual kernel state (`ufw show user-rules`), and not only through the file.<br/>• Add the source-scoped allow rules before `ufw default deny incoming`. Do not use broad `ALLOW Anywhere` and do not add any rules beyond these five (loopback + 4 source-scoped), including deny/reject/route.<br/>• Enable UFW and save in `/var/work/tests/artifacts/3/`: `ufw status`, `ufw show added` (a normalized representation of the added rules - not necessarily in the original form/order of the commands), the preflight (including the TCP/10250 baseline), and the recovery commands.<br/>• **Mandatory retest after `ufw reload`:** run `sudo ufw reload` and repeat ALL the same checks (readyz, node Ready, calico-node Ready, Pod DNS, Pod→API, worker→kubelet:10250 deny, effective UFW rule count). A rule that works only in memory right after enable but does not survive a reload is not considered a correct solution. |
| Acceptance criteria | • **TCP/10250 baseline:** the checker-owned bootstrap baseline (recorded before the lab was handed out in `/var/lib/cks-lab105-checker`, a `0711 root:root` directory outside `/var/work/tests`, file `0444 root:root`) confirms the initial reachability of TCP/10250; your own baseline probe before UFW is saved and shows real network reachability (`CURL_EXIT=0`, HTTP `1xx-5xx`). If the port is already unreachable at baseline, the result of the task is `inconclusive`, not PASS.<br/>• **UFW and the exact set of rules:** UFW is active, default-deny; `ufw show added` contains EXACTLY five lines: loopback + `worker_ip`→`22/tcp` + `worker_ip`→`6443/tcp` + `node_ip`→`6443/tcp` + `pod_cidr`→`6443/tcp`, without a single extra rule of ANY action (`allow`/`deny`/`reject`/`limit`/`route`) and without any of the five missing.<br/>• **Framework files:** the hash of `/etc/ufw/before*.rules`/`after*.rules` does not differ from the checker-owned bootstrap baseline (rules are added only via `ufw`, the framework files are not edited by hand).<br/>• **Actual kernel state:** `sudo ufw show user-rules` (the real `ufw-user-*` chains via `iptables -L`) semantically matches the expected five rules - not only the count is checked, but the source/interface/protocol/port of EACH rule, both after `enable` and after `reload`. `ufw6-user-input` stays with EXACTLY one line - the v6 version of the loopback ACCEPT (`ufw allow in on lo` creates both a v4 and a v6 rule at once, since this is an interface rule without an explicit IP; it is not "completely empty"). This catches a direct edit of `user.rules`/`user6.rules` without tuple metadata (which is reflected neither in `ufw show added` nor in the `before/after` hash) and the widening of an already declared rule (for example, `node_ip`→`6443/tcp` secretly replaced by `node_ip`→`any`) without changing the number of lines.<br/>• **Cluster health:** `/readyz=ok`; the expected node and all `calico-node` Pods stay `Ready`; `health-probe` stays Ready, resolves DNS, and reaches the Kubernetes Service.<br/>• **kubelet blocking:** after UFW the worker does not reach the kubelet `10250` (`HTTPCODE=000`, a transport deny) - exactly as a regression relative to the proven baseline.<br/>• **Retest after reload:** **all the same checks pass again after an explicit `sudo ufw reload`**: readyz/node/calico-node/DNS/Pod→API stay healthy, worker→kubelet:10250 stays blocked with the same deny contract as before the reload, and the actual number of rules in the kernel again matches the declarative one.<br/>• **Artifacts:** the artifact contains the recovery commands (`ufw disable`, verification, correction, and re-enabling). |

<details>
<summary>💡 Hint for task 3</summary>

The most dangerous mistake here is to run `ufw enable` (default-deny) BEFORE you have added the allow rule for SSH from the worker IP. The order must be: first all the needed `ufw allow from <IP> to any port <port>`, only then `ufw --force enable`. Keep the current SSH session open the whole time you work with the firewall - if you lose access, a second session for recovery will not connect (see the warning below). Do not forget the baseline probe of TCP/10250 BEFORE enabling UFW - without it the post-hardening "blocked" proves nothing: the port could have been unreachable earlier for a completely different reason (for example, an AWS security group), and then UFW has nothing to do with it; besides, the checker has its own baseline, recorded before the lab was handed out in a separate protected directory, so this record cannot be forged after the fact. Check the allow-set strictly via `sudo ufw show added` (not only `ufw status`) - there must be EXACTLY five lines, not one extra (no broad `ALLOW Anywhere`, no additional ports, and this applies to ANY action - `allow`, `deny`, `reject`, `limit`, `route`, not only new allows) and not one missing. Manage the firewall only through the `ufw` command - do not edit `/etc/ufw/before*.rules`/`after*.rules`/`user.rules`/`user6.rules` by hand: the framework files are compared by hash, and the actual state of `user.rules`/`user6.rules` is checked by the checker directly through the real iptables rules in the `ufw-user-*` chains (`sudo ufw show user-rules`), so even an edit of `user.rules` without the correct `### tuple ###` comments will be detected after `ufw reload`. And do not forget to run `sudo ufw reload` at the end and repeat all the checks - a rule that works only right after `enable` but does not survive a `reload` does not count.
</details>

> **Recovery first.** Keep the current SSH session open until the full verification. If the API
> disappears, run `sudo ufw disable` from it, fix the allow rules, and only then enable the
> firewall again. If SSH has already been lost, use the provider's console/recovery channel;
> do not try to "cure" the situation with a broad `allow from any`.
>
> **Scope of applicability.** This UFW allowlist is designed only for the single-node fixture.
> It must not be carried literally to a multi-node cluster: before default-deny you need to inventory the
> kubelet and inter-node flows, the CNI overlay, BGP/VXLAN/WireGuard, LoadBalancer/NodePort, and the
> provider firewall/security groups for the specific topology.
>
> **Lab-specific exception: UFW on a Calico node.** The official Calico documentation on
> requirements explicitly recommends disabling firewalld and other iptables managers on
> Calico nodes, because they may conflict with the rules that Calico itself programs.
> UFW is the same kind of iptables/nftables manager. This lab deliberately keeps UFW on the
> control-plane to practice host firewall hardening (a separate skill in the CKS exam
> program), and not as a recommended way to combine Calico with a host firewall in production - for
> that Calico offers its own `HostEndpoint`/`GlobalNetworkPolicy`. This is exactly why the task
> explicitly requires a controlled sequence of baseline → `ufw enable` → retest with
> a check that `calico-node` and all Kubernetes connectivity stay healthy (see
> `ADVERSARIAL_ACCEPTANCE_STANDARD.md`).

---
| **4** | **Fix the kubeconfig permissions** |
| :---: | :--- |
| What to do | On the control-plane protect `/etc/kubernetes/admin.conf`, which contains the cluster-admin credential: the owner and group must be `root:root`, the mode - `600`. |
| Acceptance criteria | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` returns `root root 600`; the same value is saved in `/var/work/tests/artifacts/4/admin-conf.txt`. |

<details>
<summary>💡 Hint for task 4</summary>

One command solves everything: `sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf`. Check yourself right afterwards - if you yourself use this file as the `ubuntu` user via `KUBECONFIG=/etc/kubernetes/admin.conf`, the read access will disappear, and this is EXPECTED - use a separate kubeconfig for everyday work.
</details>

---
| **5** | **Forbid root login over SSH** |
| :---: | :--- |
| What to do | On the control-plane set `PermitRootLogin no` in `/etc/ssh/sshd_config`, check the syntax with `sshd -t`, and safely reload SSH. Check the effective value specifically for a root connection with the command `sshd -T -C "user=root,addr=<your IP>,laddr=<node IP>,lport=22"`, and not just `sshd -T` without a connection context. |
| Acceptance criteria | The effective value of `permitrootlogin` for the root connection context equals `no`; `/var/work/tests/artifacts/5/sshd.txt` contains `PermitRootLogin no`. |

<details>
<summary>💡 Hint for task 5</summary>

`sshd -T` shows the EFFECTIVE configuration, but WITHOUT a connection context (`-C`) any `Match` blocks (`Match User`/`Match Address`/`Match Group` and the like) are not applied at all - the `sshd(8)` man page explicitly says that `Match` rules are applied in test mode "only when the connection parameters are supplied via one or more `-C` options". Therefore `sshd -T` without `-C` may show `permitrootlogin no` from the main block of the configuration, even though a more specific `Match` block (for example, `Match Address <administrator IP>` or `Match User root`) allows root login for the real connection. Check via `sshd -T -C "user=root,addr=<IP>,laddr=<node IP>,lport=22"` - this simulates a REAL incoming root connection and makes `sshd` apply all the matching `Match` blocks before showing the final value. ALWAYS keep the current SSH session open before `systemctl reload sshd` and verify from a new session - not from the one that was already authenticated before the change.
</details>

---
| **6** | **Close insecure access to the Docker daemon on `docker-host`** |
| :---: | :--- |
| What to do | • On the separate `docker-host` stop publishing the Docker API on TCP/2375: remove `-H tcp://...` from the training systemd override, but keep access only through the unix socket.<br/>• Configure `/var/run/docker.sock` as `root:root` with mode `660`; for persistence after a restart set this through the `docker.socket` override.<br/>• Remove `developer` from the `docker` group.<br/>• After the changes be sure to run `sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service` - this proves that the settings survive a restart of the daemon, and do not merely match the expected state temporarily.<br/>• After the restart confirm that Docker is really working (`sudo docker version`), and not just stopped. |
| Acceptance criteria | • **Docker works after the restart:** after `daemon-reload` + restart, `docker.service` and `docker.socket` are in the `active` state, and `sudo docker version`/`sudo docker info` complete successfully (a positive control - Docker is really working, not just "switched off and therefore 2375 is closed").<br/>• **No TCP API:** there is no listener on TCP/2375. After the restart the Docker API has no TCP listener on any port: the effective `docker.service` contains no TCP `-H/--host`, and `docker.socket` contains no TCP `ListenStream`; the only API endpoint is the Unix socket `/var/run/docker.sock`.<br/>• **The socket:** `stat -c '%U %G %a' /var/run/docker.sock` returns `root root 660`; the persistent override of `docker.service`/`docker.socket` (via `systemctl cat`) contains no `-H tcp://` and sets `SocketGroup=root`/`SocketMode=0660`.<br/>• **The user `developer`:** is not a member of the `docker` group, and `sudo -u developer docker ps` ends with an access error.<br/>• **Artifacts:** create `/var/work/tests/artifacts/6/docker-tcp.txt`, `/var/work/tests/artifacts/6/docker-socket.txt`, `/var/work/tests/artifacts/6/developer-access.txt` with the lines `tcp/2375: closed`, `root root 660`, `developer docker ps: denied`. |

<details>
<summary>💡 Hint for task 6</summary>

Membership in the `docker` group is effectively equivalent to root - any process with access to `docker.sock` can mount the host filesystem through a `--privileged` container. To make sure that `developer` has been removed from the group, `groups developer` is not enough - changes to group membership apply to NEW login sessions, so check specifically via `sudo -u developer docker ps` in a fresh command, not in an already open `developer` session. Do not stop at the first successful run of the check - run `daemon-reload` and `restart` of both units (`docker.socket`, `docker.service`) and repeat the checks AGAIN: without this step you can accidentally pass the task by just temporarily stopping Docker (then 2375 is closed not because `-H tcp://` was removed, but because the daemon is not running at all) - also make sure that `sudo docker version` works after the restart, this proves that Docker is really functioning and not just "switched off".
</details>

---
| **7** | **Forbid loading an unused kernel module (`modprobe` blacklist)** |
| :---: | :--- |
| What to do | • On the control-plane the module `sctp` is loaded, but it is needed neither by kubeadm, nor by containerd, nor by Calico in this lab. Try to unload it (`sudo modprobe -r sctp`).<br/>• **The unloading may fail on an already live cluster, and this is not an error:** kernel protocol modules get a persistent per-network-namespace reference for every netns that existed at the time they were loaded, and Pods (calico, coredns, etc.) are already running on this node; stopping them is not part of the task.<br/>• Forbid reloading via `/etc/modprobe.d/60-cks-sctp.conf` with the directives `blacklist sctp` and `install sctp /bin/true`.<br/>• Threat model limitations: both directives act at the level of `modprobe` (alias resolution and dependency loading) - this is not an absolute kernel protection. `insmod` inserts a module directly through a kernel syscall and does not read `modprobe.d`, and `modprobe --ignore-install` can bypass the `install` override given host-level access. For the root owner of the node this is expected: the goal is to eliminate the usual loading path (`modprobe sctp`, autoloading by alias when a protocol is accessed), and not to defend against a user who already has root on the node.<br/>• Confirm that `modprobe --show-config` shows the effective override and that a direct `modprobe sctp` does not change the state of the module. |
| Acceptance criteria | • **The file:** `/etc/modprobe.d/60-cks-sctp.conf` contains both lines `blacklist sctp` and `install sctp /bin/true`.<br/>• **The effective config:** `modprobe --show-config \| grep sctp` shows `install sctp /bin/true`.<br/>• **The module state:** a direct repeated `modprobe sctp` does not change the state of the module (it was loaded - it stays loaded, it was not loaded - it stays not loaded).<br/>• **The artifact:** `/var/work/tests/artifacts/7/sctp.txt` contains the line `lsmod: absent` OR `lsmod: present` (either of the two - the real current state) and the line `install sctp /bin/true`. |

<details>
<summary>💡 Hint for task 7</summary>

`blacklist sctp` alone does not block everything - it prevents AUTOLOADING via alias resolution, but a direct `modprobe sctp` still works without the `install` override. Both lines are needed: `blacklist` for autoloading, `install sctp /bin/true` for an explicit `modprobe sctp` call (it replaces the load command with a no-op). Try `sudo modprobe -r sctp` to unload an already loaded module, but if you get `FATAL: Module sctp is in use` with an empty `/sys/module/sctp/holders` - this is expected on a live cluster (per-netns pinning by already running Pods) and does not prevent you from passing the task; the config still prevents FUTURE loads, which is what is checked.
</details>

---
| **8** | **`protectKernelDefaults` and safe sysctls for the kubelet** |
| :---: | :--- |
| What to do | • On the control-plane, `kernel.unprivileged_bpf_disabled = 0` is currently set - unprivileged processes can load eBPF programs, which widens the kernel attack surface. Fix this.<br/>• Add `vm.overcommit_memory = 1` (a typical recommendation for kubelet/containerd stability under memory pressure).<br/>• Set both parameters via `/etc/sysctl.d/99-kubernetes.conf`, then apply with `sudo sysctl --system`.<br/>• Enable `protectKernelDefaults: true` in `/var/lib/kubelet/config.yaml` and restart the kubelet.<br/>• **The order matters:** with `true` the kubelet checks at startup that the current kernel/cgroup parameters match the expected defaults and **does not start** if they do not - so the sysctls must be applied **before** the kubelet restart, and not after. |
| Acceptance criteria | • **Live values:** `sysctl kernel.unprivileged_bpf_disabled` returns `1`; `sysctl vm.overcommit_memory` returns `1`.<br/>• **Persistent configuration:** `/etc/sysctl.d/99-kubernetes.conf` contains both parameters as active lines (`kernel.unprivileged_bpf_disabled = 1`, `vm.overcommit_memory = 1`); a comment, `= 1 # comment`, or a temporary `sysctl -w` does not count.<br/>• **kubelet:** the effective kubelet configuration (`/api/v1/nodes/<node>/proxy/configz`) contains `protectKernelDefaults: true`.<br/>• **State after the restart:** `systemctl is-active kubelet` returns `active`, and the node stays `Ready`. |

<details>
<summary>💡 Hint for task 8</summary>

The order here is critical and is deliberately stressed in the task description: first `sysctl --system` (apply the values), ONLY THEN enable `protectKernelDefaults: true` and restart the kubelet. If you do it in the reverse order, the kubelet at startup will find a mismatch of the kernel parameters with its expectations and refuse to start - the node will stay NotReady, and you will not be able to understand the reason without reading the kubelet logs (`journalctl -u kubelet`). The check is based on the ACTUALLY effective kubelet configuration via `kubectl get --raw="/api/v1/nodes/<node>/proxy/configz"`, and not on the text of `config.yaml` - if the line in the file is commented out or contains a typo, `grep` could still find it, although the kubelet keeps working with the old default value. After editing the file, be sure to restart the kubelet and check specifically via `configz`.
</details>

---
| **9** | **Find and neutralize an extra SUID binary** |
| :---: | :--- |
| What to do | • On the control-plane run `find / -xdev -perm -4000 -type f 2>/dev/null` and find among the results `/usr/local/bin/cks-lab105-suid-tool` - a training binary deliberately created with the SUID bit and not needed by any Kubernetes component on this node.<br/>• Save the full list of the found SUID files **before** the fix in `/var/work/tests/artifacts/9/suid-before.txt`.<br/>• Remove the SUID bit from the binary (`chmod u-s`).<br/>• Save the mode of `cks-lab105-suid-tool` **after** the fix in `/var/work/tests/artifacts/9/suid-after.txt`.<br/>• Do not touch the system SUID binaries (`passwd`, `sudo`, `mount`, and the like): removing them breaks the normal operation of the OS and is outside the scope of the task. |
| Acceptance criteria | • **Before the fix:** `suid-before.txt` contains the path `/usr/local/bin/cks-lab105-suid-tool` among the found SUID files.<br/>• **After the fix:** `stat -c '%a' /usr/local/bin/cks-lab105-suid-tool` returns `755` (without the SUID bit `4`); `suid-after.txt` contains `755`.<br/>• **System binaries:** the standard SUID binaries (for example `/usr/bin/sudo` or `/usr/bin/passwd`) keep the SUID bit untouched. |

<details>
<summary>💡 Hint for task 9</summary>

`chmod u-s` removes specifically the SUID bit, without touching the other permissions (unlike `chmod 755`, which also overwrites all the other permission bits - in this case the result is the same, but `u-s` is safer as a general habit). Do not run `find / -perm -4000` without `-xdev` unless absolutely necessary - without it the command will scan mounted network/virtual filesystems and may run for a very long time or hang. The check compares the current set of system SUID binaries with a baseline recorded BEFORE the start of the lab - touching any other system SUID binary (not only `sudo`/`passwd`) is forbidden, and simply restoring SUID on `sudo` will not help if you accidentally (or deliberately) removed it from something else. Paths inside `/var/lib/containerd` (container image layers via overlayfs) are not counted either in the baseline or in the check - these are not host files, and their set naturally changes on image pull/extract regardless of your actions.
</details>

---
| **10** | **Disable core dumps and protect SUID processes from memory dumping** |
| :---: | :--- |
| What to do | • A process core dump may contain decrypted secrets, private keys, and tokens that were in memory at the moment of the crash.<br/>• On the control-plane add to `/etc/security/limits.conf` the lines `* hard core 0` and `* soft core 0` (a limit on the size of core dumps).<br/>• Forbid dumping for SUID/privileged processes: `fs.suid_dumpable = 0` in `/etc/sysctl.d/99-kubernetes.conf` (the same file as in task 8 - do not create a separate conflicting file).<br/>• **On Ubuntu this is not enough:** a crash dump is by default passed not directly to a file but through `kernel.core_pattern`, which points to a userspace pipe handler (Apport). Apport intercepts the crash in `/var/lib/apport/coredump/` regardless of `ulimit -c`, because `RLIMIT_CORE` is ignored by the kernel specifically for pipe handlers (see `man 5 core`: "RLIMIT_CORE will be ignored if the system is configured to pipe core dumps to a program").<br/>• Therefore additionally set `kernel.core_pattern = \|/bin/false` in the same `/etc/sysctl.d/99-kubernetes.conf` - this replaces the pipe handler with a deliberately non-working one, and the kernel creates the dump neither to a file nor via Apport. Apply with `sudo sysctl --system`.<br/>• Confirm: `sysctl fs.suid_dumpable` returns `0`, and `cat /proc/sys/kernel/core_pattern` returns `\|/bin/false`.<br/>• Confirm: a new login shell (`bash -l` or `sudo su - ubuntu -c 'ulimit -c'` - specifically with `sudo`, a regular `su` to yourself still asks for a password) shows `ulimit -c` equal to `0`.<br/>• Confirm: after a real crash of a test process (`SIGSEGV`) no new core dump appears in `/var/lib/apport/coredump/` or anywhere else. |
| Acceptance criteria | • **Live values:** `sysctl -n fs.suid_dumpable` returns `0`; `cat /proc/sys/kernel/core_pattern` returns `\|/bin/false`.<br/>• **Persistent sysctl:** `/etc/sysctl.d/99-kubernetes.conf` contains the active (not commented out) lines `fs.suid_dumpable = 0` and `kernel.core_pattern = \|/bin/false`.<br/>• **Limits:** `/etc/security/limits.conf` contains both lines `* hard core 0` and `* soft core 0`; a new login shell shows `ulimit -c` equal to `0`.<br/>• **Crash probe:** a controlled crash of a test process does not create a new retained core dump.<br/>• **The artifact:** `/var/work/tests/artifacts/10/coredump.txt` contains all the confirmations, including the result of the controlled crash probe. |

<details>
<summary>💡 Hint for task 10</summary>

`ulimit -c` in YOUR current SSH session will not change after editing `limits.conf` - PAM limits are applied only when a NEW session/login shell is created. Check via `sudo su - ubuntu -c 'ulimit -c'` (a new login; `sudo` is mandatory - `su` even to yourself always asks for a password if it is not run as root) or open a new SSH session, and do not check `ulimit -c` in the same shell where you edited the file. Both values are needed: `hard` is the absolute ceiling, `soft` is the effective default value; if you set only `soft`, the process can raise the limit to `hard` itself. The key trap of the task: `ulimit -c 0` and `fs.suid_dumpable=0` **do not disable** core dumps on Ubuntu by themselves - `man 5 core` explicitly says that `RLIMIT_CORE` is ignored by the kernel if `kernel.core_pattern` points to a pipe handler (`|program`), and Ubuntu by default directs the crash exactly to such a handler (Apport), which intercepts the dump regardless of `ulimit`. The only reliable way is to override `kernel.core_pattern` itself (for example, with `|/bin/false`), and not only the process limits.
</details>

## Additional: kernel and containerd/CRI hardening

This is a short node-local practice beyond tasks 7–9, not included in the automatic criteria of
the fixture. It shows a broader CRI context, not limited to a specific kernel module.

In this lab Kubernetes uses **containerd**, not Docker. Therefore the same principles
must be applied to the CRI: check the permissions of `/run/containerd/containerd.sock` and
`/etc/containerd/config.toml`, do not add regular users to the group that gives access
to the socket, and allow `ctr`/`crictl` against this endpoint only to privileged
administrators. Do not change the owner or mode of the running CRI socket blindly: a wrong
configuration will stop the kubelet and the workloads.

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# an access denial is expected for an unprivileged user
```

## Verification

On `worker` run:

```bash
check_result
```

The check contains `0 Init` and ten independent tests. It checks the state of both
hosts over SSH and the mandatory artifacts. After editing `sshd_config` or a systemd unit,
wait for `systemctl reload/restart` to finish before running the check again.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD).

## Deletion

```bash
TASK=105 make delete_cks_task
```
