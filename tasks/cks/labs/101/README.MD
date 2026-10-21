[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 101 - NetworkPolicy: default-deny, isolation, and EC2 IMDS

## Description

`NetworkPolicy` works as an allow-list: after default-deny, the required flows are brought back only by explicit rules. Enforcement is provided by Calico. The worker of this lab is a Terraform-managed EC2 instance; its Instance Metadata Service (IMDS) is reachable at `http://169.254.169.254/`. Terraform explicitly enables the HTTP endpoint, leaves IMDSv1 GET allowed for a safe probe, and sets the response hop limit to `2`, so that before default-deny a regular Pod can confirm network reachability of IMDS.

The lab checks only the network reachability of the IMDS endpoint, without reading metadata or credentials. Any actually received HTTP status `1xx–5xx` means that a TCP/HTTP path to IMDS exists. `HTTPCODE:000` together with a transport error/timeout means there is no HTTP response. The specific HTTP status depends on the EC2 metadata options: if token usage is `required`, a GET without a valid IMDSv2 token receives `401`; if IMDSv1 is allowed, a tokenless GET is treated as an IMDSv1 request and may receive a regular HTTP response.

**Residual risk.** The worker EC2 instance has an IAM instance profile attached, and a tokenless IMDSv1 GET to `latest/meta-data/iam/security-credentials/<role>` actually returns temporary AWS credentials (AccessKeyId/SecretAccessKey/SessionToken) - this is not a hypothetical risk but the actual behavior of the current environment. The role itself is restricted to near-zero permissions (least privilege: it cannot even read its own IAM role via `iam:GetRole`), so the practical value of a leak to an attacker is minimal, but the student must clearly understand that in production with the same configuration (`HttpTokens=optional`, IMDSv1 allowed) the same command would return the real credentials of a working role with real permissions. The lab deliberately reproduces this anti-pattern from chapter 02.1 (IMDSv1 allowed, response hop limit `2`) for the purposes of probing and learning to find this vulnerability through NetworkPolicy; in production use `HttpTokens=required` (IMDSv2 only) and `HttpPutResponseHopLimit=1`.

## Deployment

On the management machine, start the environment:

```bash
TASK=101 make run_cks_task
```

After a successful deployment, Terraform prints the SSH command for connecting to the worker. It has the following format:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

For example:

```
18:53:06.019 STDOUT [worker] terraform: worker_pc_ssh = "ssh ubuntu@18.193.110.150 password= fq0J9RuZWN"
```

For the connection use only the address from the command:

```bash
ssh ubuntu@<IP>
```

When SSH asks for a password, enter the value Terraform showed after `password=`.

**For runtime checks** use a temporary diagnostic Pod with the same labels as the identity being checked. HTTP checks need an image with curl (`curlimages/curl:8.11.1`); DNS checks need an image with nslookup (`busybox`). After the check, delete the temporary Pods and temporary policies.

Work on the worker. Before you start, make sure the namespaces are clean (just in case):

```bash
kubectl delete namespace cks-101 cks-101-legacy imds-control --ignore-not-found --wait=true
printf 'EC2 IMDS target: %s\n' 'http://169.254.169.254/'
time_left
```

Check every stage yourself on your own resources; run `check_result` after completing the tasks, and open the reference solution only after your own attempt or when you are stuck.

## Goal

Configure a minimal ingress/egress allow-list, pin an image digest, prove the AND selector semantics and an exact `ipBlock.except` for IMDS, and then compare a regular Pod with a `hostNetwork` Pod without assuming a universal result in advance.

## Infrastructure

| Component | Purpose |
| ----- | ----- |
| `cks-101`        | namespace of the application and of your `NetworkPolicy` objects |
| `cks-101-legacy` | namespace for the legacy-client scenario |
| `imds-control`   | an independent namespace without policies for the baseline and the repeated control probe |
| worker EC2       | Terraform-managed EC2 instance with IMDS at `http://169.254.169.254/` |
| CNI                | Calico |

## Tasks

---

|           **1**           | **The application** |
| :-----: | :----- |
|       What to do       | Namespace `cks-101`; Deployments `frontend` and `backend` with `replicas: 1`, without `hostNetwork`, with the same `viktoruj/ping_pong@sha256:<64hex>`; Service `backend` TCP/8080.<br/><br/>**How to get the current digest:**<br/>1. Temporarily run a Pod from the image `viktoruj/ping_pong:latest`.<br/>2. Wait for the pull and Ready.<br/>3. Run `digest=$(kubectl get pod <pod_name> -o yaml \| grep imageID \| cut -d'@' -f2)` and obtain `sha256:<64hex>`.<br/>4. Delete the temporary Pod.<br/>5. Use the obtained digest for both Deployments: `viktoruj/ping_pong@sha256:<64hex>`. |
| Acceptance criteria | Both replicas are Ready, the image references are identical, the Service has an endpoint. |
|        Verification        | Run `kubectl -n cks-101 get deploy,svc,endpoints` and make sure that:<br/>1. Both Deployments are `1/1 Ready`.<br/>2. Service `backend` has an endpoint.<br/><br/>To verify the pinned image run:<br/>`kubectl -n cks-101 get deploy frontend backend -o yaml \| grep 'image:'`<br/>Both Deployments must use the same image of the form `viktoruj/ping_pong@sha256:<64hex>`. |

---

|           **2**           | **Baseline, default-deny, and repeated probe** |
| :-----: | :----- |
|       What to do       | Create the namespace `imds-control` and a temporary curl Pod. Create a frontend probe in `cks-101`. **Before `default-deny`** confirm two baselines: frontend → backend and frontend → IMDS are reachable; `imds-control` → IMDS is also reachable. Then create `default-deny`. **After `default-deny`** repeat the IMDS probes: frontend must get `HTTP 000` and curl `7`/`28`, while `imds-control` must keep getting a real HTTP `1xx–5xx` with exit `0`. The backend deny is checked in Task 3, after DNS is restored. |
| Acceptance criteria | Before the deny, backend and IMDS are actually reachable. After the deny, frontend → IMDS gives `HTTP 000` + curl `7`/`28`; the independent `imds-control` keeps HTTP `1xx–5xx` + exit `0`. |
|        Verification        | 1. Before `default-deny`: curl from the frontend probe to `http://backend:8080/` must get an HTTP response + exit `0`.<br/>2. Before `default-deny`: frontend and `imds-control` must get a real HTTP response from IMDS.<br/>3. Check `default-deny`: empty `podSelector`, `Ingress` + `Egress`, no allow-rules.<br/>4. After `default-deny`: frontend → IMDS must return `HTTP 000` + curl `7`/`28`; `imds-control` → IMDS must still get HTTP `1xx–5xx` + exit `0`.<br/>5. Do not check the backend deny until DNS is restored - it is checked in Task 3. |

---

|           **3**           | **DNS** |
| :-----: | :----- |
|       What to do       | After `default-deny`, as the first allow-rule, restore frontend access only to `kube-system/kube-dns` on exact UDP/53 and TCP/53, without `endPort`. For verification create a separate `dns-probe` on `busybox:1.36.1` with the label `app=frontend`. |
| Acceptance criteria | The DNS allow-set is exactly UDP/53 + TCP/53; `nslookup kubernetes.default.svc.cluster.local` works. At this point the backend must not yet be reachable on TCP/8080. |
|        Verification        | 1. Check `allow-frontend-dns` in the YAML: only UDP/53 and TCP/53, no `endPort` and no additional ports.<br/>2. Run `nslookup kubernetes.default.svc.cluster.local` from `dns-probe`.<br/>3. After DNS succeeds, run curl from the frontend probe to `http://backend:8080/`: until Task 4, `HTTP 000` + curl `7`/`28` is expected. |

---

|           **4**           | **NetworkPolicy for the application** |
| :-----: | :----- |
|       What to do       | Create `allow-frontend-egress-to-backend` and `allow-backend-ingress-from-frontend`. After that, frontend must get a real HTTP response from `http://backend:8080/`. |
| Acceptance criteria | frontend → backend:8080 is allowed; a foreign identity remains blocked. |
|        Verification        | Positive: frontend curl via the Service DNS name. Negative: a foreign Pod with a temporary egress policy to the backend must not pass the backend ingress. |

---

|           **5**           | **IMDS final verification** |
| :-----: | :----- |
|       What to do       | After adding the DNS and application allow policies, repeat the same IMDS probe from the frontend Pod and from the independent `imds-control`. The goal is to prove that the new allow policies did not open IMDS. There is no need to create auxiliary artifact files. |
| Acceptance criteria | `imds-control`: real HTTP `1xx–5xx` + exit `0`; frontend: `HTTP 000` + curl `7`/`28`. |
|        Verification        | Run the same bounded curl (`-m 5`) from both Pods and compare the actual result. Do not use `curl -f`: HTTP `401/403/404/...` still means network reachability. |

---

|           **6**           | **Legacy AND and IMDS except** |
| :-----: | :----- |
|       What to do       | Create the namespace `cks-101-legacy` with the Deployment `legacy-client`: replicas=1, no hostNetwork, image `curlimages/curl:8.11.1`, command `sleep 3600`. Create the NetworkPolicy `allow-backend-ingress-from-legacy` in the namespace `cks-101`: it selects backend, contains one ingress peer with an AND selector (namespaceSelector and podSelector in a single `from` element), TCP/8080. Create the NetworkPolicy `allow-legacy-egress` in the namespace `cks-101-legacy`: it selects app=legacy-client, contains ipBlock cidr=0.0.0.0/0 with the single except 169.254.169.254/32, and no additional allow-rules. Check: 1) IMDS from legacy-client is blocked; 2) legacy-client can reach backend; 3) a Pod with a different label in the same namespace cannot pass the ingress; 4) a Pod with label=legacy-client in the namespace cks-101 cannot pass the ingress. After the checks, delete the temporary Pods and temporary policies. |
| Acceptance criteria | IMDS is blocked, the actual legacy backend flow is allowed, a wrong label/namespace is blocked. |
|        Verification        | 1. Run `kubectl -n cks-101-legacy get networkpolicy allow-legacy-egress -o yaml` - make sure that `ipBlock.cidr=0.0.0.0/0` and the only `except` is `169.254.169.254/32`.<br/>2. Run `kubectl -n cks-101 get networkpolicy allow-backend-ingress-from-legacy -o yaml` - make sure that `namespaceSelector` and `podSelector` are in the same `from` element, and the port is TCP/8080.<br/>3. Curl from `legacy-client` to IMDS must return `HTTP 000` and exit `7` or `28`.<br/>4. Curl from `legacy-client` to the backend must get a real HTTP response.<br/>5. A Pod with a different label in `cks-101-legacy` with a temporary egress to the backend must not pass the backend ingress.<br/>6. A Pod with `app=legacy-client` in the namespace `cks-101` with a temporary egress to the backend must also not pass the backend ingress. |

---

|           **7**           | **hostNetwork observation** |
| :-----: | :----- |
|       What to do       | Create `hostnetwork-probe` with the image `curlimages/curl:8.11.1`, the label `app=frontend`, and `spec.hostNetwork=true`. Run from it the same IMDS curl that you used for the regular frontend Pod. Compare the actual observation with Task 5. There is no need to create auxiliary artifact files. |
| Acceptance criteria | The Pod is Ready, `hostNetwork=true`, a real IMDS probe has been performed. No universal expected result is assumed for hostNetwork: the behavior depends on the CNI and the node configuration. |
|        Verification        | Check `hostNetwork: true`, then run a bounded IMDS curl (`-m 5`) and `echo $?`. Compare the actual observation with the regular Pod from Task 5. |

## Verification

```bash
check_result
```

The checker creates and deletes its own `imds-control` namespace and probes: before and after the deny in `cks-101` it confirms that the real IMDS responds from an independent namespace without policies. It does not trust control resources left over from a previous attempt and does not replace your own baseline/runtime checks. Additional policies that widen the allowed flows cause an error.

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD).

## Deletion

```bash
TASK=101 make delete_cks_task
```
