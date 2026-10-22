[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 106 - AppArmor and seccomp: node-local policy and verifiable denials

## Goal

In this CKS lab you apply two independent mechanisms for protecting a container process at the
level of the Linux kernel. First you switch a pre-delivered **AppArmor** profile from
`complain` to `enforce`, assign it to a Pod via the modern field
`securityContext.appArmorProfile`, and prove the write denial. Then you assign the safe
baseline `RuntimeDefault` and a custom **seccomp Localhost** profile that blocks the
system call `unshare(2)`.

This is a continuation of the basic `SecurityContext` from CKA lab 106: here it is not enough to write
YAML. Localhost profiles live on the Kubernetes node, so you need to check the node,
the Pod placement, and the actual behavior of the process.

## Threat model

Assume an RCE in a container. The question after the compromise is not "could the attacker get a shell", but "what can this shell do next" and how large its blast radius is.

AppArmor in tasks 1–3 restricts objects and operations: the profile is switched to enforce and then the write denial is proven. This way an already compromised process does not gain unrestricted freedom of action merely because it is running in a container.

seccomp in tasks 4–6 restricts the available system call: first the baseline is applied, then a custom profile, and then the real denial of `unshare(2)` is checked. Task 6 already contains a negative control through the Pod `sysadmin-control`: with the same capability but without a seccomp filter the call succeeds, so the comparison shows exactly the boundary after the compromise.

## Self-check before you start

<details>
<summary>1. How does `complain` differ from `enforce` in AppArmor, and why can `complain` not be shown as proof of protection?</summary>

In `complain` mode AppArmor only logs profile violations but does NOT block them - an operation that should be forbidden will still be executed, there will just be an entry in the log. In `enforce` the operation is actually blocked. Task 2 explicitly requires switching the profile to `enforce`, because a demonstration of "here is the violation in the log" under `complain` does not prove protection - the process was still able to perform the action.
</details>

<details>
<summary>2. Why does `allowPrivilegeEscalation: false` not remove the `SYS_ADMIN` capability that has already been granted?</summary>

`allowPrivilegeEscalation: false` enables the kernel flag `no_new_privs`, which forbids a process from gaining NEW privileges via `execve` (for example, through a setuid binary or file capabilities). It does not affect the privileges the process ALREADY has in its effective/bounding set - if the container is started with the `SYS_ADMIN` capability explicitly in the manifest, this capability remains available regardless of the value of `allowPrivilegeEscalation`.
</details>

<details>
<summary>3. Why is `localhostProfile` in a Pod manifest specified as a relative path and not an absolute one?</summary>

The kubelet itself resolves a relative path relative to its seccomp root (by default `/var/lib/kubelet/seccomp/`). If you specify an absolute path, the kubelet will look for the file BY THAT ABSOLUTE PATH inside the seccomp root, which will almost never match the real location of the file - the Pod will get `CreateContainerError`.
</details>

## Related Course Chapters

- [Chapter 16. AppArmor](../../course/16/README.md)
- [Chapter 17. seccomp](../../course/17/README.md)
- [Chapter 03. Container Runtime Security](../../course/03/README.md)

## Infrastructure

The environment is deployed via Terragrunt in AWS `eu-central-1`.

| Component | Purpose |
|---|---|
| `vpc` | VPC `10.10.0.0/16` with public subnets |
| `ssh-keys` | keys for access to the node |
| `k8s-1` | a single-node kubeadm Kubernetes `1.36.0` cluster, containerd, and **Calico** |
| `worker` | a work machine with `kubectl`, `check_result`, and SSH access to the node as `control-plane` |

To save resources the control-plane is the only workload node: its
`NoSchedule` taint has been removed. It is labeled
`security.cks.io/localhost-profiles-106=true`. All Pods of this lab must select exactly
this node - the Localhost profile exists only on it, and the scheduler does not move it to another node.

The bootstrap prepared **only**:

- the node label `security.cks.io/localhost-profiles-106=true` for safe placement;
- on the work machine (worker), in `/opt/lab106-fixtures/`: the sources `k8s-106-deny-write`
  (AppArmor profile) and `cks-106-deny-unshare.json` (custom seccomp profile).

Neither the AppArmor profile nor the seccomp profile is **preinstalled** on the workload node, and neither is
loaded into its kernel - transferring and initially loading each of them are part of tasks 1 and 5.
Do not change the path of the seccomp profile and do not create a profile inside a regular Pod: the transfer of
files to the node is done by you as the node administrator over SSH, and not from inside the workload.

## Deployment

```bash
TASK=106 make run_cks_task
```

Connect to the work machine over SSH. The context is already configured:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Check the node access and the worker-side fixtures before you start:

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ls -la /opt/lab106-fixtures/
```

## Tasks

---
| **1** | **Transfer and load the AppArmor profile** |
| :---: | :--- |
| What to do | The source of the profile `k8s-106-deny-write` lies only on the work machine, in `/opt/lab106-fixtures/k8s-106-deny-write`. Copy it to the node `control-plane` into `/etc/apparmor.d/k8s-106-deny-write` (for example, via `scp`) and load it into the kernel with `sudo apparmor_parser -r`. The profile already contains the `complain` flag - there is no need to enable it a second time, that is the job of task 2. |
| Acceptance criteria | `/etc/apparmor.d/k8s-106-deny-write` is present on the node; `/sys/kernel/security/apparmor/profiles` contains a line with the name `k8s-106-deny-write` (in any mode - `complain` or `enforce`), that is, the profile is really loaded into the kernel and not merely copied to disk. |

<details>
<summary>💡 Hint for task 1</summary>

`scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/` copies the file to the node
into a temporary directory; move it from there with `sudo` into `/etc/apparmor.d/` (a regular
user has no write permission there directly). Then `sudo apparmor_parser -r
/etc/apparmor.d/k8s-106-deny-write` compiles and loads the profile into the kernel - without this
step the file on disk gives no protection at all and will not appear in
`/sys/kernel/security/apparmor/profiles`.
</details>

---
| **2** | **Switch the AppArmor profile to enforce** |
| :---: | :--- |
| What to do | On the node `control-plane` switch the profile `k8s-106-deny-write` loaded in task 1 to `enforce` mode. The original `complain` mode records violations, but does not constitute protection. Do not delete the profile and do not change its name. |
| Acceptance criteria | A node with the label `security.cks.io/localhost-profiles-106=true` exists; `/etc/apparmor.d/k8s-106-deny-write` is available; `/sys/kernel/security/apparmor/profiles` contains the line `k8s-106-deny-write (enforce)`. The checker-owned bootstrap baseline (recorded BEFORE the lab was handed out, on a transient copy of this same profile while it was still in `complain`) confirms that a write matching the `/work/**` pattern of this profile really did pass back then - without this it cannot be proven that it was the switch to `enforce` that caused the later denial. |

<details>
<summary>💡 Hint for task 2</summary>

The command `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` reloads an already existing profile - if it was in `complain` and the file on disk already describes `enforce`, this command is enough. Check yourself via `sudo cat /sys/kernel/security/apparmor/profiles | grep k8s-106-deny-write` - the output must explicitly show `(enforce)`. Do not check it via `aa-status`: this command groups the profiles under section headings (`N profiles are in enforce mode.`) and prints under them only the bare profile names, WITHOUT the `(enforce)`/`(complain)` suffix on each line - such a suffix exists only in `/proc/<pid>/attr/current` and in the kernel file `/sys/kernel/security/apparmor/profiles`, and not in the `aa-status` list of profiles.

Do not use `aa-enforce`/`aa-complain` for this profile until task 9 is done:
before doing their main work, these Python tools from `apparmor-utils` parse
**all** the files in `/etc/apparmor.d/`, including the still broken `k8s-106-broken-profile`
from task 9, and fail with a parser error on an unrelated file. Edit the `complain` flag in the profile
file directly (`sed`) and reload exactly THIS file via `apparmor_parser -r` -
this binary, unlike `aa-enforce`, parses only the file passed to it.
</details>

---
| **3** | **A Localhost AppArmor Pod and write blocking** |
| :---: | :--- |
| What to do | Create the namespace `security-106` and the Pod `apparmor-writer`. The Pod must select the node label from the infrastructure, disable the automount of the ServiceAccount token, and at the Pod level set `appArmorProfile.type: Localhost`, `localhostProfile: k8s-106-deny-write`. Use `busybox:1.36`, the container `app`, the sleep command `sleep 3600`, and an `emptyDir` mounted at `/work`. After the start confirm the effective profile with the command `cat /proc/1/attr/current` (if the interface is available), perform an allowed read operation, for example `cat /etc/hostname >/dev/null`, and then try to write a file to `/work`; the operation must end with a denial. On the node record the AppArmor denial for the profile/process from `journalctl -k \| grep -i apparmor` or `dmesg \| grep -i apparmor`. |
| Acceptance criteria | The Pod is running, uses exactly the Localhost profile and the right nodeSelector; the effective profile of the process shows `k8s-106-deny-write` in enforce mode (when `/proc/.../attr/current` is available); the allowed read operation (for example, `cat /etc/hostname` or `ls /work`) passes, while the checker independently writes its own unique (per-run) file to `/work` and gets an AppArmor denial. In the kernel journal/audit log there is an `apparmor="DENIED"` event with this profile that relates specifically to THIS attempt (by the unique file name) - this rules out a false pass from a stale denial event in the journal. |

<details>
<summary>💡 Hint for task 3</summary>

`appArmorProfile` for a profile of type `Localhost` is specified through two separate fields: `type: Localhost` and `localhostProfile: k8s-106-deny-write` (the profile name WITHOUT the path `/etc/apparmor.d/`) - this is the same name under which the profile was loaded in task 1. If the Pod does not start (CreateContainerError), check that the profile is really already loaded on the RIGHT node via the nodeSelector - AppArmor profiles are node-local, they are not transferred automatically.
</details>

---
| **4** | **The safe baseline seccomp RuntimeDefault** |
| :---: | :--- |
| What to do | Create a Pod `runtime-default` in `security-106` with `busybox:1.36` and `sleep 3600`. At the Pod level explicitly specify `securityContext.seccompProfile.type: RuntimeDefault`; the Pod must also select the prepared node. Check `/proc/1/status` in the container: `Seccomp: 2` is expected. |
| Acceptance criteria | The Pod is `Running`, `RuntimeDefault` is selected in its Pod-level securityContext, and the process is in seccomp filter mode. |

<details>
<summary>💡 Hint for task 4</summary>

`Seccomp: 2` in `/proc/1/status` means "filter mode is active" (SECCOMP_MODE_FILTER) - this is what you should see. `Seccomp: 0` would mean no seccomp filter at all (`Unconfined`). This is the simplest of the three seccomp tasks (4-6) - if it does not pass, the problem is most likely in the nodeSelector and not in the seccompProfile itself.
</details>

---
| **5** | **Transfer and use a custom Localhost seccomp profile** |
| :---: | :--- |
| What to do | The source `cks-106-deny-unshare.json` lies only on the work machine, in `/opt/lab106-fixtures/cks-106-deny-unshare.json`. Determine the node with the label `security.cks.io/localhost-profiles-106=true`, create the directory `/var/lib/kubelet/seccomp/profiles/` on it (if it does not exist yet), and copy the JSON there under the same name. Then create the Pod `localhost-seccomp` in `security-106` on this node. At the Pod level specify `seccompProfile.type: Localhost` and the relative path `profiles/cks-106-deny-unshare.json` - without `/var/lib/kubelet/seccomp/`. The container `app` must use `busybox:1.36`, get the capability `SYS_ADMIN`, and stay running after the check. **Do not present this combination as a hardened baseline:** `SYS_ADMIN` remains one of the most dangerous capabilities, and `allowPrivilegeEscalation: false` does not take away the permissions already granted. This is a capability-focused experiment in which the security is demonstrated by a specific seccomp deny. |
| Acceptance criteria | The JSON profile has been transferred and exists on the node at the right path; the Pod with the right nodeSelector uses the profile `Localhost:profiles/cks-106-deny-unshare.json`; the JSON profile contains `SCMP_ACT_ERRNO`/`errnoRet: 1` for `unshare`; only the `SYS_ADMIN` required for the experiment is added to the container. |

<details>
<summary>💡 Hint for task 5</summary>

The path `profiles/cks-106-deny-unshare.json` is relative to the kubelet seccomp root `/var/lib/kubelet/seccomp/`, that is, the real file on the node must lie at `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json` - it is exactly there that it must be copied from the work machine (for example, `scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/`, then `sudo mkdir -p` and `sudo mv` on the node). Do not write the full absolute path in the manifest - the kubelet adds the root itself. `SYS_ADMIN` is given here PRECISELY for the experiment (a capability is needed that in principle allows calling `unshare`), and not as a recommended practice - do not confuse the training scenario with a production baseline.
</details>

---
| **6** | **Prove the denial of the syscall `unshare(2)`** |
| :---: | :--- |
| What to do | In the command of the container `localhost-seccomp` run `unshare -n true`, save the successful confirmation of the expected denial in `/tmp/unshare-result` as the line `unshare denied by seccomp`, then keep the container alive with `sleep 3600`. A repeated command `kubectl exec ... -- unshare -n true` must return a non-zero code. For an attack-minded negative control create a Pod `sysadmin-control` on the same node with `seccompProfile.type: Unconfined` and the same single capability `SYS_ADMIN`; its `unshare -n true` must succeed. Delete the control Pod after the check. |
| Acceptance criteria | The Localhost Pod is running; `Seccomp: 2`; `unshare` is blocked by the custom profile. In the control Pod the same syscall with the same capability and without a seccomp filter passes. This proves kernel behavior, and not just the presence of YAML. |

<details>
<summary>💡 Hint for task 6</summary>

Use exactly `unshare -n true` (unshare network namespace, `CLONE_NEWNET`), and NOT
`unshare -m true`. `-m` (mount namespace) requires `CAP_SYS_ADMIN` just like `-n`, but
BusyBox `unshare -m` after a successful `unshare(2)` additionally performs a SECOND,
independent `mount(2)` syscall (`mount("none", "/", NULL, MS_REC|MS_PRIVATE, NULL)`
to force private propagation - this is the behavior of unshare, active by default
unless `--propagation unchanged` is passed explicitly, and even then `mount()` is
still called, just with zero flags). The default AppArmor profile of containerd (`RuntimeDefault`,
which a Pod without an explicit `securityContext.appArmorProfile` gets) contains `deny mount,`
WITHOUT any conditions on flags - this prohibition acts independently of capabilities and of
seccomp. Therefore `unshare -m true` can fail with `EPERM` because of AppArmor EVEN when
seccomp does not restrict `unshare` at all, which makes such a probe an unreliable proof
of a seccomp denial specifically. `unshare -n` (`CLONE_NEWNET`) calls ONLY the `unshare(2)`
syscall itself without any subsequent `mount()` - both `localhost-seccomp` and
`sysadmin-control` use the same `SYS_ADMIN`, so the difference in the result is
unambiguously explained by exactly the seccomp filter, and not by a side effect of AppArmor.

The order of commands matters for the proof to be convincing: first run `unshare -n true` and make sure it fails with an error (non-zero exit code), ONLY THEN write the line `unshare denied by seccomp` to `/tmp/unshare-result` - do not write the line in advance, "assuming" the result. The negative control (`sysadmin-control`) must use THE SAME capability `SYS_ADMIN`, but `seccompProfile.type: Unconfined` - if you forget to specify `Unconfined` explicitly, the Pod may get `RuntimeDefault` by default (if the `seccompDefault` from task 8 is enabled) and the test will not show the difference.
</details>

Linux capabilities and privilege escalation are different axes. `allowPrivilegeEscalation: false`
enables `no_new_privs` and forbids gaining **new** privileges via `execve` (setuid/setgid and
file capabilities), but does not remove the `SYS_ADMIN` already added to the bounding/effective set.
For a regular workload use `capabilities.drop: ["ALL"]` and, separately,
`allowPrivilegeEscalation: false`; the experiment above is deliberately not such a baseline.

---
| **7** | **User namespaces: `hostUsers: false` and UID translation via `uid_map`** |
| :---: | :--- |
| What to do | User namespaces are GA in Kubernetes v1.36 (see [chapter 03](../../course/03/README.md), [chapter 18](../../course/18/README.md) and the Security Delta v1.36). The theory explains that `hostUsers: false` translates the root of the container into an unprivileged host UID; here you need to prove this on a live process. Create a Pod `userns-probe` in `security-106` on the prepared node with `spec.hostUsers: false`, the image `busybox:1.36`, and the command `sleep 3600`; do not set the Pod-level `runAsUser`, so that the process starts as UID 0 **inside** the container. Confirm `id` inside the container (`uid=0`). Determine the host PID of the container process via `crictl inspect` (by analogy with lab 112) or via `kubectl get pod -o jsonpath` + `crictl ps`, then on the node read `/proc/<host PID>/uid_map`. Save both outputs (`id` inside the container and the content of `uid_map`) in `/var/work/tests/artifacts/6/userns.txt`. |
| Acceptance criteria | The Pod is `Running`, `spec.hostUsers == false`, it selects the prepared node; `id` inside the container shows `uid=0(root)`; `/proc/<host PID>/uid_map` on the node contains a line of the form `0 <host-uid> <length>`, where `<host-uid>` is **not equal to 0** (the container root is translated into an unprivileged host UID) and `<length>` is at least `65536` (the standard per-Pod UID range); the artifact contains both parts of the evidence. |

<details>
<summary>💡 Hint for task 7</summary>

`id` INSIDE the container will show `uid=0(root)` regardless of `hostUsers` - this is expected, the container sees ITS OWN namespace, where its root really is UID 0 in that namespace. The real protection is visible only from OUTSIDE: on the node itself, in `/proc/<host PID>/uid_map`, where UID 0 inside the container is translated into some large unprivileged UID on the host. To find the host PID, use `crictl inspect <container-id>` - from there, and not from `kubectl get pod`, which knows only about the Kubernetes object and not about the host-level PID of the process.
</details>

---
| **8** | **`seccompDefault: true` at the kubelet level: a baseline without an explicit profile** |
| :---: | :--- |
| What to do | All the Pods in tasks 4–6 explicitly specify `seccompProfile` in the manifest. In reality a developer may forget this field - then, without a node-level baseline, the Pod gets `Unconfined`. On the node enable `seccompDefault: true` in `/var/lib/kubelet/config.yaml` and restart the kubelet (`systemctl restart kubelet`). Create a Pod `no-seccomp-field` in `security-106` on the prepared node from `busybox:1.36` (`sleep 3600`), **without specifying securityContext.seccompProfile at all**, either at the Pod level or at the container level. Via `/proc/1/status` inside the container confirm that the kubelet applied `RuntimeDefault` automatically (`Seccomp: 2`), and did not leave `Unconfined` (`Seccomp: 0`). |
| Acceptance criteria | The effective (applied) kubelet configuration - via `/api/v1/nodes/<node>/proxy/configz`, the field `.kubeletconfig.seccompDefault` - equals `true`; `systemctl is-active kubelet` returns `active`, the node stays `Ready`; the Pod `no-seccomp-field` has no `seccompProfile` at any level of its specification; `/proc/1/status` inside the container shows `Seccomp: 2`. |

<details>
<summary>💡 Hint for task 8</summary>

The key requirement is that the Pod REALLY must not mention `seccompProfile` at all, either at the Pod level or at the container level. If you copy the manifest from tasks 4–6 and simply forget to remove this field - the test will not prove what it should: that exactly the node-level `seccompDefault` (and not an explicit setting in the manifest) provided `Seccomp: 2`.

The check is based on the REALLY APPLIED kubelet configuration, and not on the text of the file on
disk: `curl`/`kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq .kubeletconfig.seccompDefault`.
A simple grep over `/var/lib/kubelet/config.yaml` does not prove that this is the very file
used by the running kubelet - a command-line flag or a drop-in could have overridden the
value without changing the file itself. Be sure to restart the kubelet after editing the
file - the configuration is not picked up on the fly.
</details>

---
| **9** | **Debugging and rebuilding a broken AppArmor profile (`apparmor_parser -r -v`)** |
| :---: | :--- |
| What to do | On disk there is already `/etc/apparmor.d/k8s-106-broken-profile` - a profile with a syntax error that was **never loaded** into the kernel. Find the error yourself via `sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile` (`-Q`/`--skip-kernel-load`: performs the full check/compilation of the profile but does not load it into the kernel) or `sudo apparmor_parser -d /etc/apparmor.d/k8s-106-broken-profile` (`-d`/`--debug`, once - only a syntax correctness check), fix the file, and load the profile into the kernel via `sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile`. Confirm the load via `aa-status \| grep k8s-106-broken-profile`. Save the error output **before** the fix and the load confirmation **after** in `/var/work/tests/artifacts/8/apparmor-debug.txt`. |
| Acceptance criteria | `apparmor-debug.txt` contains the text of the parser error (for example, `syntax error`) from the attempt **before** the fix; the checker-owned bootstrap baseline (recorded BEFORE the lab was handed out, independently of your artifact) independently confirms that the original profile really contained a syntax error; `/etc/apparmor.d/k8s-106-broken-profile` on disk no longer contains the original syntax error; `aa-status` shows `k8s-106-broken-profile` among the loaded profiles (in any mode - `enforce` or `complain`); a repeated `apparmor_parser -Q` on the fixed file completes without an error. |

<details>
<summary>💡 Hint for task 9</summary>

`apparmor_parser -p` (`--preprocess`) is NOT a safe dry-run/syntax-check mode - it is
just preprocessing: it expands the `#include` directives and prints the resulting
profile to stdout, which by itself does not guarantee the absence of side effects and is not
intended specifically for syntax checking. Use `-Q`/`--skip-kernel-load`
(performs the full compilation/check but does not load into the kernel) or `-d`/`--debug`
(once - only a syntax correctness check) to SAFELY find the
syntax error without side effects. Only after fixing the file use
`-r` (reload/load) for the real load into the kernel. AppArmor syntax requires a comma as
the rule separator inside a block - study the parser output to find which character is
missing and where exactly.

Run `apparmor_parser` via `sudo`, even with `-Q`/`-d`: on the lab node (apparmor 3.0.4,
Ubuntu) without privileges the parser tries on every run to set up the policy cache in
`/var/cache/apparmor` and fails with "Failed setting up policy cache: Permission denied" BEFORE
checking the syntax - you will get a misleading permissions error instead of the real syntax
error of the profile. This has been verified on the node itself (including on a deliberately broken profile).
If you need to run without `sudo`, add `-K` (`--skip-cache`: no caching) -
`apparmor_parser -Q -K` without privileges gets as far as parsing the profile and shows the real
error. Loading and reloading (`-r`) require privileges in any case.
</details>

## Verification

On the work machine run:

```bash
check_result
```

The check contains Init and nine independent tests. It reads the Pod state through the API, checks the
profile on the node over SSH, and performs controlled negative scenarios. If the Localhost
Pod is not created, first look at `kubectl describe pod`: the usual cause is an absolute
path instead of a relative one or the assignment of the Pod to a node without the profile.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD).

## Deletion

```bash
TASK=106 make delete_cks_task
```
