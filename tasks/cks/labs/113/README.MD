[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 113 - Upgrading a Kubernetes Cluster with kubeadm (minor upgrade)

## Goal

In this CKS lab you perform a real minor upgrade of a self-managed
cluster with `kubeadm`: first the control-plane, then the worker node, in the correct
order and without unplanned downtime of the already running workload. The cluster starts
on Kubernetes `1.35.x`; your task is to move both nodes to `1.36.x`, following the
official `kubeadm upgrade` procedure and switching the `pkgs.k8s.io` package repository
to the new minor.

## Self-check before you start

<details>
<summary>1. Why does `kubeadm upgrade` require upgrading the control-plane STRICTLY before the worker nodes, and not in any order?</summary>

`kubeadm upgrade apply` on the control-plane updates the version of the API server and of the other control-plane components; this version is the reference point for the cluster's version skew policy. A worker node with a kubelet that is too new relative to the API server may violate the supported skew (the kubelet must not be newer than the kube-apiserver). Upgrading the control-plane first guarantees that the API server is already at the target version when the worker moves to it as well - this is not an arbitrary recommendation, but a requirement of the Kubernetes version skew policy.
</details>

<details>
<summary>2. Why is switching the `pkgs.k8s.io` apt repository mandatory when moving to a new minor, although patch updates work without it?</summary>

Since the migration from `packages.cloud.google.com`/`apt.kubernetes.io`, `pkgs.k8s.io` is organized as a **separate repository for every minor version** (`core:/stable:/v1.35`, `core:/stable:/v1.36`, and so on), and not a single repository with all the versions. Inside the already connected `v1.35` repo only `1.35.x` patch releases are available. For `apt install kubeadm=1.36.x-*` to see the `1.36` versions, you first need to add the `core:/stable:/v1.36` repo specifically in `sources.list.d/kubernetes.list` (only the version in the URL changes; the keyring with the signing key `Release.key` stays the same).
</details>

<details>
<summary>3. Why is `kubectl drain` before a cluster upgrade not just "good practice" - what exactly does it protect against?</summary>

`kubeadm upgrade` on the control-plane recreates the static Pod manifests of the components (kube-apiserver, controller-manager, scheduler), and on any node upgrading the kubelet requires restarting it - at this moment the node temporarily loses the ability to correctly report the status of Pods and to accept new ones. `drain` relocates the ordinary workload Pods to other nodes in advance (or marks them as evicted), so that this temporary outage of the node does not turn into application downtime. Without `drain`, the Pods on the node being upgraded may become unavailable for the duration of the restart without a compensating move to another node.
</details>

## Related Course Chapters

- [Chapter 13. Updating Kubernetes to Fix Vulnerabilities](../../course/13/README.md)

## Infrastructure

Terragrunt creates a self-managed Kubernetes `1.35.4` in `eu-central-1`, containerd,
Calico CNI:

| Component | Purpose |
|---|---|
| `k8s-1` control-plane | an ordinary control-plane node that allows ordinary Pods (a single control-plane, without a dedicated second control-plane node) |
| `k8s-1` worker `worker1` | an ordinary worker node on the same starting version |
| `worker` | a work machine with `kubectl`, `check_result`, and SSH access to both cluster nodes |

The target version of the upgrade is `1.36.x` (the latest available patch at the time of the lab), that is,
after completing the tasks the cluster will be on the same training baseline version as
the rest of the core labs 101-112. Skipping minor versions (for example a direct move `1.35` → `1.37`)
is not supported by kubeadm - this lab does not require such a move.

To access the nodes use the aliases `k8s113_controlPlane_1` and `k8s113_node_worker1`.

The namespace `upgrade-113` with the Deployment `canary` (2 replicas) is already deployed - this is your
indicator of the absence of downtime. Throughout the whole upgrade at least one replica must
remain `Available`; after the `uncordon` of each node and at the end the Deployment must
recover to `2/2`. The bootstrap distributes both replicas across different
nodes in advance (required `podAntiAffinity`) and creates a `PodDisruptionBudget` with `minAvailable: 1`.

## Deployment

```bash
TASK=113 make run_cks_task
```

Connect to the work machine and select the ready-made context:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Create the evidence directory before starting work:

```bash
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## Tasks

---
| **1** | **Upgrade the control-plane to the target minor** |
| :---: | :--- |
| What to do | • Log in to `k8s113_controlPlane_1` (`ssh`, then `sudo -i`).<br/>• Switch the apt repository `pkgs.k8s.io` from `core:/stable:/v1.35` to `core:/stable:/v1.36`: in `/etc/apt/sources.list.d/kubernetes.list` only the version in the URL changes (as described in the Kubernetes documentation, the keyring stays the same).<br/>• Upgrade the `kubeadm` package to `1.36.x`, run `kubeadm upgrade plan`, then `kubeadm upgrade apply v1.36.x`.<br/>• Only after a successful `apply` run `kubectl drain` for this node.<br/>• Upgrade the `kubelet`/`kubectl` packages to `1.36.x`, restart the `kubelet`, then run `kubectl uncordon`. |
| Acceptance criteria | • `kubeadm version`, `kubelet --version`, the local `kubectl version --client`, and the API server version (`kubectl version`) on the control-plane report `v1.36.x`.<br/>• The control-plane node (`<cp-name>` from `kubectl get no`) is in the `Ready` status.<br/>• The full output of the `kubeadm upgrade apply` command (with the `SUCCESS` line and the target version) is saved verbatim in `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt` on the work machine (the command is run on the node, the output is written to a file on the node, then copied with `scp`). |

<details>
<summary>💡 Hint for task 1</summary>

The order is essential: first `apt-mark unhold kubeadm` → upgrade the package → `apt-mark hold kubeadm` → `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z`, and only AFTER a successful `apply` - `drain` and the upgrade of `kubelet`/`kubectl`. Upgrading the `kubelet` before calling `kubeadm upgrade apply` is not needed and is not recommended by the official procedure. Save the output of `kubeadm upgrade apply` to a file on the node (`> /tmp/kubeadm-upgrade-apply.txt 2>&1`), and do not reconstruct it from memory afterwards - the test looks for the literal text with the word `SUCCESS`.
</details>

---
| **2** | **Upgrade the worker node to the target minor** |
| :---: | :--- |
| What to do | • On `k8s113_node_worker1` (`ssh`, `sudo -i`) switch `pkgs.k8s.io` to `core:/stable:/v1.36` in the same way and upgrade `kubeadm`.<br/>• Run `kubeadm upgrade node` (not `apply` - that is a command for the control-plane only).<br/>• Run `kubectl drain` for this node (from the work machine, not from the node itself).<br/>• Upgrade `kubelet`/`kubectl`, restart the `kubelet`, run `kubectl uncordon`. |
| Acceptance criteria | • `kubeadm version`, `kubelet --version`, and the local `kubectl version --client` on the worker node report `v1.36.x`.<br/>• `kubectl get nodes` shows for the worker node `v1.36.x` in `kubeletVersion` and the `Ready` status.<br/>• The output of `kubeadm upgrade node` is saved to a file on the node and copied with `scp` to `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt` on the work machine. |

<details>
<summary>💡 Hint for task 2</summary>

`kubeadm upgrade node` is exactly the command for worker nodes (and for additional control-plane nodes), while `kubeadm upgrade apply` is intended only for the FIRST/only control-plane node. Start this task only after task 1 is fully completed and the control-plane is already `Ready` on `1.36.x` - otherwise you will violate the version skew policy.
</details>

---
| **3** | **Observe the correct upgrade order** |
| :---: | :--- |
| What to do | • Complete the control-plane upgrade (task 1) fully, including the uncordon, BEFORE you start the worker node upgrade (task 2).<br/>• This task does not require a separate action in the cluster: the order is checked automatically by the checker-owned monitor of the cluster state and versions. |
| Acceptance criteria | • The checker-owned monitor records the initial `1.35.x` baseline.<br/>• Then it records the complete transition of the control-plane to `1.36.x` (including `Ready` and schedulable) with the worker on `1.35.x`, and only after that the start of the worker node upgrade.<br/>• The state survives a restart of the monitor; a missing baseline or a gap in observation of more than 60 seconds is not counted. |

<details>
<summary>💡 Hint for task 3</summary>

If you have already started (let alone finished) the worker node upgrade before the control-plane - stop; rolling the worker back to the `1.35.x` packages is not possible in a simple way, but the right path is to complete the control-plane upgrade, then continue/repeat the worker node upgrade. The main point is that the next worker node upgrade (whenever it is started) must happen after the fully completed control-plane upgrade. Do not start task 2 until `kubectl get node <cp-name>` shows `v1.36.x` and `Ready`.
</details>

---
| **4** | **Prove the absence of downtime for the existing workload** |
| :---: | :--- |
| What to do | • While you are performing tasks 1-2, open a separate session on the work machine and start a loop that polls the availability of the Deployment `canary` in the namespace `upgrade-113` every few seconds.<br/>• Append each polling line to `/var/work/tests/artifacts/4/canary-availability.log` in a format containing `available=N` (for example `available=2`).<br/>• Keep polling throughout the upgrade of both nodes. |
| Acceptance criteria | • The Deployment `canary` has `2/2` available replicas at the end, the original Deployment/PDB and the required Pod anti-affinity are preserved.<br/>• The absence of downtime is checked by the checker-owned monitor via Pod Ready and the CRI containers of exactly `upgrade-113`; API/SSH/CRI errors are counted as UNKNOWN, and not as zero.<br/>• The student file `/var/work/tests/artifacts/4/canary-availability.log` contains at least two lines of the format `<unix_timestamp> available=N` or `<unix_timestamp> available=api-unreachable`, with observations from before the control-plane upgrade and after the start of the worker upgrade. |

<details>
<summary>💡 Hint for task 4</summary>

An example of a polling loop that you can leave running in a separate terminal/`screen`/`tmux` for the whole time you do tasks 1-2: `while true; do if available=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then echo "$(date +%s) available=${available:-0}"; else echo "$(date +%s) available=api-unreachable"; fi >> /var/work/tests/artifacts/4/canary-availability.log; sleep 5; done`. If the Deployment lost all replicas for a short time - check `kubectl get pods -n upgrade-113 -o wide` and that the successive drains respect the PDB and the required anti-affinity.
</details>

## Verification

```bash
check_result
```

The check contains `0 Init` and five mandatory tests. Tests 1-2 check the versions of
`kubeadm`/`kubelet`/the local `kubectl` and the `Ready` status on the control-plane and the worker node
respectively, as well as the literal evidence file with the output of `kubeadm upgrade`. Test 3
checks the upgrade order by the checker-owned cluster state monitor, and not by the
modification time of the files. Test 4 checks that the `canary` workload had no downtime,
using the same checker-owned monitor as the source of truth. Test 5 is the final
check that both nodes are really on the target version and are not left in the
`cordon` state.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD).

## Deletion

```bash
TASK=113 make delete_cks_task
```
