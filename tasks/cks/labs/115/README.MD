[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 115 - Cilium bootstrap, kube-proxy replacement, and Mutual Authentication

> **Advanced / production track. Not part of the formal CKS Core exam requirements.**
> This lab goes beyond the CKS exam and is useful as a production skill: installing
> Cilium from scratch as a full replacement for kube-proxy, and Cilium Mutual Authentication
> based on SPIRE. If you are preparing only for the exam, the priority is labs 101-114.

## Description

The control-plane of this lab is brought up with `kubeadm init --skip-phases=addon/kube-proxy` - without
the `kube-proxy` DaemonSet and **without an installed CNI**. The node stays `NotReady` until you
install Cilium yourself. This is deliberate: the whole lab is about manually installing Cilium as a
full replacement for kube-proxy (`kubeProxyReplacement`), the incremental enabling of WireGuard
transparent encryption, and Cilium Mutual Authentication based on SPIRE - each step is
installed and verified separately, and not handed to you ready-made.

The `cilium`/`hubble` CLI are already installed on the worker and point to the real cluster
(`~/.kube/config`), but the installation of Cilium into the cluster itself is done by you.

## Deployment

```bash
TASK=115 make run_cks_task
```

After the deployment connect over SSH with the command from the Terraform output (`worker_pc_ssh`).
The node will be `NotReady` right after login - this is the expected baseline, and not an error.

## Goal

Install Cilium as a full replacement for kube-proxy on an already prepared kube-proxy-free
kubeadm cluster, enable WireGuard encryption, enable Cilium Mutual Authentication
(SPIRE), and write a `CiliumNetworkPolicy` that requires successful mutual authentication between
two namespaces.

## Infrastructure

| Component | Purpose |
| --- | --- |
| control-plane EC2 | a kubeadm cluster without kube-proxy and without a CNI at the moment the lab is handed out |
| `ingress-115` | the namespace of the client that must pass mutual authentication |
| `app-115` | the namespace of the backend protected by a CiliumNetworkPolicy with `authentication.mode: required` |
| worker EC2 | the `cilium`/`hubble` CLI, a configured kubeconfig |

## Tasks

---

| **1** | **Baseline: kube-proxy-free, without a CNI** |
| :---: | :--- |
| What to do | • Confirm the current state of the cluster before installing anything |
| Acceptance criteria | • The `kube-proxy` DaemonSet is absent<br/>• The initial `NotReady` is observed before the Cilium installation<br/>• After all the tasks are done, the checker confirms the absence of kube-proxy and the availability of the API, and not the historical `NotReady` |
| Verification | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`. `kubectl get nodes` -> `NotReady` (no CNI). |

---

| **2** | **Installing Cilium as a kube-proxy replacement** |
| :---: | :--- |
| What to do | • Install the Cilium agent/chart version `1.20.1` via the `cilium` CLI version `v0.19.7` installed on the worker, with `kubeProxyReplacement=true` and explicitly set `k8sServiceHost`/`k8sServicePort` that point to the real API server (not the Service ClusterIP - without kube-proxy the cluster cannot resolve `kubernetes.default` until Cilium itself comes up) |
| Acceptance criteria | • `KubeProxyReplacement: True/Strict` (in the `cilium-dbg status` of the agent)<br/>• The node becomes `Ready`<br/>• A ClusterIP Service is reachable without kube-proxy |
| Verification | `cilium status --wait`, `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep KubeProxyReplacement`, then `kubectl get nodes` -> `Ready`. From a test Pod: `curl https://kubernetes.default.svc.cluster.local/` must get an HTTP response (not a connection error). |

---

| **3** | **WireGuard transparent encryption** |
| :---: | :--- |
| What to do | • Enable `encryption.enabled=true`, `encryption.type=wireguard` on top of the already installed Cilium (`cilium upgrade`, not a reinstall from scratch) |
| Acceptance criteria | • `Encryption: Wireguard` in `cilium-dbg status` and `enable-wireguard: "true"` in the Cilium ConfigMap<br/>• The path from task 2 did not regress<br/>• The single-node environment confirms the enabled WireGuard configuration, but does not prove encrypted inter-node traffic (Peers: 0) |
| Verification | `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep Encryption`. Repeat the curl from task 2 - it must get an HTTP response again. |

---

| **4** | **Cilium Mutual Authentication (SPIRE)** |
| :---: | :--- |
| What to do | • Enable the built-in SPIRE installation via the Cilium helm chart itself: `authentication.mutual.spire.enabled=true`, `authentication.mutual.spire.install.enabled=true` |
| Acceptance criteria | • The `spire-server` StatefulSet and the `spire-agent` DaemonSet have all the requested Ready replicas in the namespace `cilium-spire` |
| Verification | `kubectl get pods -A \| grep spire` - both types of Pods are `Running` and Ready. |

> **Lab environment specifics.** The cluster has no StorageClass, so the SPIRE server needs ephemeral
> storage (`authentication.mutual.spire.install.server.dataStorage.enabled=false`). The
> `spire-server` image runs as uid 1000 and cannot create a socket in the hostPath directory `root:755` -
> run it as root (`authentication.mutual.spire.install.server.securityContext.runAsUser=0`).
> The chart also requires `authentication.enabled=true`. The details are in the reference solution.

---

| **5** | **A CiliumNetworkPolicy with mandatory mutual authentication** |
| :---: | :--- |
| What to do | • Create `ingress-115` (client) and `app-115` (backend, label `app=backend`, Service `backend`)<br/>• Create a `CiliumNetworkPolicy backend-auth-required` in `app-115`: an `endpointSelector` for `app=backend`, ingress only from the namespace `ingress-115`, and `authentication.mode: required` on this ingress rule |
| Acceptance criteria | • The policy selects exactly the backend, contains one ingress rule from `ingress-115` on TCP/80 with `authentication.mode: required`<br/>• There are no additional ingress rules and no bypass paths<br/>• In the isolated Lab 115 environment there are no other namespaced/global network policies that affect the backend<br/>• The Service `backend` points to the Ready Pod `backend` |
| Verification | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml` - check `authentication.mode: required` inside `ingress[0]`. |

---

| **6** | **Positive/negative control: an authenticated identity is allowed, a foreign one is not** |
| :---: | :--- |
| What to do | • Check the effect of the policy with live traffic: the client from `ingress-115` must reach `backend` (after a successful SPIRE-based mutual auth handshake)<br/>• A separate Pod from the "wrong" namespace (`app-115`, not `ingress-115`; Cilium always lets the backend's traffic to itself through) must be blocked |
| Acceptance criteria | • In the isolated mirrored backend the baseline allows both clients, and after applying a copy of the policy only `ingress-115` is allowed<br/>• The live backend answers the allowed client, and rejects the clients from `app-115` and from a new independent namespace<br/>• The Cilium BPF auth map contains `spire` for the exact client/backend identity pair |
| Verification | `curl` from the client Pod in `ingress-115` to `http://backend.app-115.svc.cluster.local/` -> an HTTP response. The same curl from a Pod in `app-115` without the client label -> a connection error. |

## Verification

```bash
check_result
```

The checker **never removes the live** `app-115/backend-auth-required`. To check the baseline it creates a temporary mirrored backend and Service in a one-off namespace `cks-115-*`, first checks the allowed traffic without the policy, then applies a copy of the verified CiliumNetworkPolicy only to the mirrored backend. Separately it checks the real backend, the EndpointSlice, the exact pairs of SPIRE identities in the BPF auth map, and the denial of clients from foreign namespaces. All the created Pods, Services, policies, and the temporary namespace are deleted with a cleanup check.

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD).

## Deletion

```bash
TASK=115 make delete_cks_task
```
