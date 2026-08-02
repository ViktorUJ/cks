[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 120 — Drills: Services and Networking

## Description

A speed trainer for the Services & Networking domain. Short independent tasks on creating
Services (ClusterIP, NodePort, headless), Ingress and NetworkPolicy, plus a block on
JSONPath.

The tasks are written in exam style with automatic validation via the `check_result`
command. The goal of a drill is not theory but speed and muscle memory: get your hands
trained and keep up with the exam pace. Answer files for the JSONPath tasks are saved in
`/home/ubuntu/answers/`.

## Goal

Reinforce the material from the course chapters:

- [Chapter 7. Services: ClusterIP, NodePort, LoadBalancer, Endpoints](../../course/07/README.md) — Service types, publishing via `expose`, Endpoints
- [Chapter 31. Service internals, DNS and CoreDNS](../../course/31/README.md) — headless Service (`clusterIP: None`), DNS names
- [Chapter 32. Ingress and Ingress controllers](../../course/32/README.md) — routing by host and path to a backend Service
- [Chapter 34. NetworkPolicy](../../course/34/README.md) — default-deny, podSelector, policyTypes

## What We Do and Why

| Block | Tasks | Skill |
|-------|-------|-------|
| **Services** | Deployment `web`, ClusterIP, NodePort, headless | quickly publish a workload with different Service types (chapters 7, 31) |
| **Routing and isolation** | Ingress `web-ing`, NetworkPolicy `deny-all` | Ingress rules by host and default-deny traffic (chapters 32, 34) |
| **JSONPath** | nodePort of Service `web-np` → into a file | extracting data via `-o jsonpath` against the clock (chapter 47) |

## Infrastructure

The environment is deployed in AWS (`eu-central-1`) via Terragrunt and consists of:

| Component  | Description                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` with public subnets                               |
| `ssh-keys` | SSH keys for node access                                             |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico CNI, metrics-server, single-node |
| `worker`   | Work machine with `kubectl` and `check_result`                       |

Instances: `t3.medium` (master), Ubuntu `22.04`. The cluster is single-node — the master is
untainted (the `control-plane` taint is removed), so Pods are scheduled directly on it.

## Deployment

```bash
TASK=120 make run_cka_task
```

Once it is created, connect to the work machine (worker) over SSH and do the tasks from
there. `kubectl` is already pointed at the `cluster1-admin@cluster1` context.

Handy commands on the work machine:

```bash
time_left       # how much time is left
check_result    # check your solution
```

## Tasks

---
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create the namespace `net`, then inside it a Deployment `web` with image `viktoruj/ping_pong:latest` and 2 replicas (`kubectl create ns net`, `kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2`). |
| Acceptance criteria | - Deployment `web` (ns `net`): 2 ready replicas. |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Publish Deployment `web` as a Service of type ClusterIP named `web-svc` on port 80 (`kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080`). |
| Acceptance criteria | - Service `web-svc` (ns `net`): Endpoints are not empty. |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create a Service `web-np` of type NodePort for `web` with the fixed `nodePort: 30080` (`kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080`). |
| Acceptance criteria | - Service `web-np`: type `NodePort`, `nodePort` 30080. |
---
|        **4**        | **Headless Service**                                        |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create a headless Service `web-h` with `clusterIP: None` for the `web` Pods (selector `app=web`). A headless Service hands out DNS records straight to the Pods, bypassing the virtual IP. |
| Acceptance criteria | - Service `web-h`: `clusterIP` = `None`. |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create an Ingress `web-ing` in namespace `net`: host `web.local`, path `/` routes to the backend Service `web-svc` on port 80 (`kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"`). |
| Acceptance criteria | - Host rule `web.local` → backend Service `web-svc`, port 80. |
---
|        **6**        | **NetworkPolicy (default-deny)**                            |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create a NetworkPolicy `deny-all` in namespace `net` with an empty `podSelector: {}` (applies to all Pods) and `policyTypes: [Ingress]` — the policy denies all incoming traffic. |
| Acceptance criteria | - NetworkPolicy `deny-all`: `policyTypes` contains `Ingress`, `podSelector` is empty. |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Extract the `nodePort` of Service `web-np` via `-o jsonpath` and save it to `/home/ubuntu/answers/nodeport.txt` (path `{.spec.ports[0].nodePort}`). |
| Acceptance criteria | - The value in `nodeport.txt` matches `.spec.ports[0].nodePort` of Service `web-np`. |
---

## Checking the Result

On the work machine run the automatic validation:

```bash
check_result
```

The script runs the tests and shows how many tasks are complete.

## Solution

Reference solution: [worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Mock Exam Coverage

The Services & Networking domain (20% CKA / 20% CKAD) — basic repetitions of Services,
Ingress, NetworkPolicy.

## Deleting the Cluster and Resources

```bash
TASK=120 make delete_cka_task
```
