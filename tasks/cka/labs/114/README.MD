[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD)

# Lab 114 — Troubleshooting: Fixing Broken Resources

## Description

A hands-on lab on the Troubleshooting domain (30% of CKA). The cluster already contains
**broken** objects — your job is to find and eliminate the causes by applying a systematic
debugging route: `get` → `describe` (Events) → `logs` → fix. The tasks simulate typical
incidents: ImagePullBackOff, empty Endpoints because of a wrong selector, and
CreateContainerConfigError because of a missing ConfigMap.

All tasks are written in exam style (like real CKA/CKAD questions) with automatic
validation via the `check_result` command.

## Goal

Reinforce the material from the course chapters:

- [Chapter 44. Debugging application failures](../../course/44/ru.md) — the `get` → `describe` → `logs` route, reading Pod statuses
- [Chapter 45. Debugging the control plane and worker nodes](../../course/45/ru.md) — diagnosing nodes and system components
- [Chapter 46. Debugging services and networking](../../course/46/ru.md) — the Service ↔ Endpoints ↔ labels chain

## What We Fix and Why

In this lab we fix three independent incidents: a broken image, a severed link between a
Service and its Pods, and a missing configuration. Each breakage exercises its own part of
the debugging route:

| Breakage | Symptom | Cause | What it teaches |
|----------|---------|-------|-----------------|
| **ReplicaSet `rs-app2223`** (namespace `rsapp`) | ImagePullBackOff | wrong image tag | analysing image problems and recreating the RS Pods (chapter 44) |
| **Service `svc-broken`** (namespace `tsvc`) | empty Endpoints | the selector does not match the Pod labels | the Service ↔ Endpoints ↔ labels chain (chapter 46) |
| **Deployment `capp`** (namespace `cfgapp`) | CreateContainerConfigError | the required ConfigMap is missing | configuration dependencies (chapter 44) |

The final picture of what will be deployed:

```mermaid
flowchart LR
    a["rs-app2223<br>ImagePullBackOff"] -->|"fix image"| a2["2 ready"]
    b["svc-broken<br>Endpoints empty"] -->|"fix selector"| b2["Endpoints present"]
    c["capp<br>CreateContainerConfigError"] -->|"create ConfigMap"| c2["Ready"]
    a2 ~~~ b
    b2 ~~~ c
    style a fill:#db4437,color:#fff
    style b fill:#db4437,color:#fff
    style c fill:#db4437,color:#fff
    style a2 fill:#0f9d58,color:#fff
    style b2 fill:#0f9d58,color:#fff
    style c2 fill:#0f9d58,color:#fff
```

## Infrastructure

The environment is deployed in AWS (`eu-central-1`) via Terragrunt and consists of:

| Component  | Description                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` with public subnets                               |
| `ssh-keys` | SSH keys for node access                                             |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico CNI, metrics-server, single-node; deploys the broken objects at startup |
| `worker`   | Work machine with `kubectl` and `check_result`                       |

Instances: `t3.medium` (master), Ubuntu `22.04`. The cluster is single-node — the master is
untainted (the `control-plane` taint is removed), so Pods are scheduled directly on it.

## Deployment

```bash
TASK=114 make run_cka_task
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
|        **1**        | **Fix the ReplicaSet**                                      |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | In namespace `rsapp` the Pods of ReplicaSet `rs-app2223` are stuck in `ImagePullBackOff`. Follow the route: `kubectl get po -n rsapp` (see the status), `kubectl describe po -n rsapp <pod>` (in Events — the image `viktoruj/ping_pong:doesnotexist123` cannot be pulled). Fix the image in the RS template to a working one (`viktoruj/ping_pong:latest`) with `kubectl edit rs rs-app2223 -n rsapp`. An RS does not recreate Pods when the template changes — delete the old Pods (`kubectl delete po -n rsapp -l <label>`) so the RS brings up new ones. Get to `2` ready replicas. |
| Acceptance criteria | - ReplicaSet `rs-app2223` (namespace `rsapp`): `2` Ready replicas. |
---
|        **2**        | **Fix the Service (empty Endpoints)**                       |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Service `svc-broken` in namespace `tsvc` does not serve traffic — its Endpoints are empty. Diagnostics: `kubectl get endpoints svc-broken -n tsvc` (empty), `kubectl describe svc svc-broken -n tsvc` (selector, for example `app=WRONG`), `kubectl get pods -n tsvc --show-labels` (the Pods carry the label `app=web`). Align the Service selector with the real Pod labels (`kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'`) and make sure the Endpoints are populated. |
| Acceptance criteria | - Service `svc-broken` (namespace `tsvc`): Endpoints are not empty (≥ 1 address). |
---
|        **3**        | **Fix the Deployment (missing ConfigMap)**                   |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Deployment `capp` in namespace `cfgapp` fails with `CreateContainerConfigError`. The route: `kubectl get po -n cfgapp` (see the status), `kubectl describe po -n cfgapp <pod>` (in Events — the ConfigMap `missing-config` is not found). Create the missing ConfigMap (`kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value`) and wait until the Deployment becomes ready (`kubectl rollout status deploy capp -n cfgapp`). |
| Acceptance criteria | - Deployment `capp` (namespace `cfgapp`): ≥ 1 Ready replica. |
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

The lab covers the troubleshooting tasks of the mocks: CKAD mock 01 (#4 — fix ReplicaSet);
the general troubleshooting skill from CKA mock 01/02 (reading statuses, Endpoints,
configuration) and CKAD mock 02 (#7/#8 — fix ingress/netpol).

## Deleting the Cluster and Resources

```bash
TASK=114 make delete_cka_task
```
