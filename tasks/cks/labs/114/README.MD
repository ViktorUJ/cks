[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 - Kubeconfig contexts, client certificates, and API exposure

## Description

The kubeconfig issued to the student contains several contexts: the working `cluster1-admin@cluster1`
and two deliberately non-working ones (`staging-admin@staging`, `legacy-admin@legacy`) that point to non-existent
API servers. `current-context` is set right after login to the non-working `staging-admin@staging` - this
intentionally reproduces a real situation in the exam, when a candidate is given a kubeconfig with several
contexts and has to figure out on their own which of them works.

Separately, the same kubeconfig has a user `cluster9-admin` with a full-fledged, really generated
self-signed client certificate (`client-certificate-data`/`client-key-data`). This certificate gives
no rights in the cluster (its CA is not trusted by the apiserver) - the task teaches how to read and parse a
client certificate from a kubeconfig, and not to authenticate with it.

The lab also covers the classic scenario of reducing the attack surface of a Service: first you deliberately
create a `NodePort` Service (externally reachable on the IP of the control-plane node), then you reduce it to
`ClusterIP`, proving the effect live in both directions.

## Deployment

On the management machine start the environment:

```bash
TASK=114 make run_cks_task
```

After a successful deployment Terraform prints the SSH command for connecting to the worker:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Connect only to the address from the Terraform output:

```bash
ssh ubuntu@<IP>
```

Work on the worker. Check each stage yourself; run `check_result` after completing
the tasks, and open the reference solution only after your own attempt or when you get stuck.

## Goal

Learn to work safely with a kubeconfig that contains several contexts, to extract and inspect a
client certificate without using it for authentication, and to manage the exposure of a Service
consciously by switching `NodePort` -> `ClusterIP`.

## Infrastructure

| Component | Purpose |
| --- | --- |
| kubeconfig (`~/.kube/config`) | 4 contexts: 1 working (`cluster1-admin@cluster1`), 2 decoys (`staging-admin@staging`, `legacy-admin@legacy`), 1 with a real client certificate (`cluster9-admin@cluster1`) |
| `cks-114` | the namespace of your backend application and Service |
| control-plane EC2 | a single-node kubeadm cluster, Calico CNI |

## Tasks

---

| **1** | **Kubeconfig context inventory** |
| :---: | :--- |
| What to do | • Run `kubectl config get-contexts`, determine the current (non-working) `current-context`.<br/>• Find the really working context and switch to it: `kubectl config use-context <name>`. |
| Acceptance criteria | • `current-context` == `cluster1-admin@cluster1`.<br/>• A request to the API server really goes through from this context (it does not merely exist in the file). |
| Verification | `kubectl config current-context`, then `kubectl get nodes` - it must return a real list of nodes, and not a connection error. |

---

| **2** | **Client certificate extraction** |
| :---: | :--- |
| What to do | • Extract the `client-certificate-data` of the user `cluster9-admin` from the kubeconfig, decode the base64, and parse the certificate with `openssl x509`.<br/>• Save the result in `/var/work/tests/artifacts/task2-cert.txt` in the format `KEY=VALUE`, one value per line: `SHA256_FP`, `SUBJECT`, `ISSUER`, `NOTBEFORE`, `NOTAFTER`. |
| Acceptance criteria | • All five values in the artifact match what is extracted from the original bootstrap certificate `cluster9-admin`.<br/>• The checker compares the original fingerprint, the unchanged state of the certificate in the kubeconfig, and all five fields. |
| Verification | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` prints `sha256 Fingerprint=AA:BB:...` - write the hex without colons into the artifact (case does not matter). |

---

| **3** | **Baseline: NodePort exposure** |
| :---: | :--- |
| What to do | • Create the namespace `cks-114`.<br/>• Create a Deployment `backend` (for example `viktoruj/ping_pong:alpine` with `SRV_PORT=80`, label `app=backend`).<br/>• Create a Service `kubernetes-public` of type `NodePort` on port 80, with an explicit `nodePort: 30114`.<br/>• **Do not touch** the `default/kubernetes` Service. |
| Acceptance criteria | • The backend is really reachable both from the node itself at `<node-internal-ip>:30114`, and inside the cluster at `kubernetes-public.cks-114.svc.cluster.local`.<br/>• `default/kubernetes` remains `ClusterIP`.<br/>• Task 4 later turns this same Service into `ClusterIP`, so by the end of the lab the NodePort state is no longer observable: the historical NodePort phase is confirmed by two HTTP 200 probes (from the worker and via DNS from a Pod), by a check of the backend/EndpointSlice, and by a monitor that preserves the UID of the Service and the Deployment.<br/>• First complete task 3 fully and wait for the file `/var/lib/cks-lab114-checker/nodeport-phase-seen`, which the monitor creates after both successful live probes; only then do task 4. The file is the confirmation of the historical phase for the same Service/Deployment. |
| Verification | From the worker (outside the cluster): `curl http://<node-internal-ip>:30114/` -> HTTP 200.<br/>From inside the cluster (a temporary Pod with curl): `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200. The node IP: `kubectl get nodes -o wide`. |

---

| **4** | **Reduce exposure: NodePort -> ClusterIP** |
| :---: | :--- |
| What to do | • Change `kubernetes-public` to the type `ClusterIP`.<br/>• Remember: the API server will not let you keep a `nodePort` with the type `ClusterIP` - the field must be removed explicitly (`kubectl edit svc kubernetes-public` and delete the `nodePort` line, or `kubectl patch` with `$patch: replace` on the `ports` array). |
| Acceptance criteria | • The external path `<node-internal-ip>:30114` is now blocked at the transport level (connection refused/timeout).<br/>• The in-cluster path still works.<br/>• The backend Pod remains Ready. |
| Verification | From the worker: `curl -m5 http://<node-internal-ip>:30114/` -> a connection error (not an HTTP code).<br/>From inside the cluster: `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200 as before.<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`, none of the ports has a `nodePort`. |

## Verification

```bash
check_result
```

The checker verifies `current-context` and a live request to the API through it, independently extracts and parses
the `cluster9-admin` certificate, checks it against the original bootstrap fingerprint and compares it with your artifact, and also performs an external and an in-cluster HTTP 200 probe, checks the Deployment, the EndpointSlice, and that `default/kubernetes` is unchanged. The historical NodePort phase is confirmed by a root-owned monitor with two live probes before the Service is switched; in the ClusterIP state the checker verifies live DNS and the transport denial of the NodePort.

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD).

## Deletion

```bash
TASK=114 make delete_cks_task
```
