[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 122 — Drills: Pod Scheduling

## Description

A speed trainer for the Workloads & Scheduling domain: short independent tasks on
nodeSelector, nodeAffinity, requests/limits, PriorityClass and taints/tolerations.
The cluster is single-node — labels and taints are attached to the only node.

The tasks are written in exam style with automatic validation via the `check_result`
command. The goal of a drill is not theory but speed and muscle memory: get your hands
trained on Pod scheduling and keep up with the exam pace.

> **Important:** do task 6 (taint) last — the `NoSchedule` taint prevents scheduling
> Pods without a toleration.

## Goal

Reinforce the material from the course chapters:

- [Chapter 12. Pod scheduling: nodeName, nodeSelector, affinity](../../course/12/README.md) — binding Pods to nodes via nodeSelector and nodeAffinity
- [Chapter 13. Taints and tolerations](../../course/13/README.md) — repelling Pods with taints and admitting them with tolerations
- [Chapter 14. Resources: requests, limits, LimitRange, ResourceQuota](../../course/14/README.md) — CPU/memory requests and limits per container
- [Chapter 15. Static Pods, PriorityClass, multiple schedulers](../../course/15/README.md) — Pod priority via PriorityClass

## What We Do and Why

| Block | Tasks | Skill |
|-------|-------|-------|
| **Binding to a node** | label `disk=ssd`, Pod `sel` (nodeSelector), Pod `aff` (nodeAffinity) | steer Pods onto the right nodes (chapter 12) |
| **Resources and priority** | Pod `res` (requests/limits), PriorityClass `high-prio` + Pod `prio` | requests/limits and scheduling priority (chapters 14, 15) |
| **Taints and tolerations** | taint `dedicated=special:NoSchedule` + Pod `tol` | isolating a node with a taint and admitting Pods via toleration (chapter 13) |

## Infrastructure

The environment is deployed in AWS (`eu-central-1`) via Terragrunt and consists of:

| Component  | Description                                                                     |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` with public subnets                                          |
| `ssh-keys` | SSH keys for node access                                                         |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico CNI, metrics-server, single-node; namespace `sched` created in advance |
| `worker`   | Work machine with `kubectl` and `check_result`                                  |

Instances: `t3.medium` (master), Ubuntu `22.04`. The cluster is single-node — the master is
untainted (the `control-plane` taint is removed), so Pods are scheduled directly on it.

## Deployment

```bash
TASK=122 make run_cka_task
```

Once it is created, connect to the work machine (worker) over SSH and do the tasks from
there. `kubectl` is already pointed at the `cluster1-admin@cluster1` context.

Handy commands on the work machine:

```bash
time_left       # how much time is left
check_result    # check your solution
```

## Tasks

It is handy to put the name of the only node into a variable:
`NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')`.

---
|        **1**        | **A label on the node**                                     |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Attach the label `disk=ssd` to the node (`kubectl label node $NODE disk=ssd`). |
| Acceptance criteria | - the node has the label `disk=ssd`. |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create Pod `sel` (ns `sched`, image `viktoruj/ping_pong:latest`) with `nodeSelector: disk=ssd` — the Pod is scheduled only on a node carrying that label. |
| Acceptance criteria | - Pod `sel` is `Running`, `nodeSelector` `disk=ssd`. |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create Pod `aff` (ns `sched`, image `viktoruj/ping_pong:latest`) with required nodeAffinity: key `disk`, operator `In`, values `[ssd]` (`requiredDuringSchedulingIgnoredDuringExecution`). |
| Acceptance criteria | - Pod `aff` is `Running`, nodeAffinity is set. |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create Pod `res` (ns `sched`, image `viktoruj/ping_pong:latest`) with requests `cpu=100m`, `memory=64Mi` and limits `cpu=200m`, `memory=128Mi` on the container. |
| Acceptance criteria | - Pod `res` is `Running`, `cpu` and `memory` limits are set. |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create PriorityClass `high-prio` with `value: 1000` (`kubectl create priorityclass high-prio --value=1000`), then Pod `prio` (ns `sched`, image `viktoruj/ping_pong:latest`) with `priorityClassName: high-prio`. |
| Acceptance criteria | - PriorityClass `high-prio` `value=1000`;<br/>- Pod `prio` is `Running` with `priorityClassName: high-prio`. |
---
|        **6**        | **Taint + toleration** (do it last)                         |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Attach the taint `dedicated=special:NoSchedule` to the node (`kubectl taint node $NODE dedicated=special:NoSchedule`), then create Pod `tol` (ns `sched`, image `viktoruj/ping_pong:latest`) with a matching toleration (`key=dedicated`, `operator=Equal`, `value=special`, `effect=NoSchedule`). **Do this task last** — the taint will prevent scheduling the remaining Pods. |
| Acceptance criteria | - the node has the taint `dedicated=special:NoSchedule`;<br/>- Pod `tol` is `Running`. |
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

The Workloads & Scheduling domain (15% CKA) — repetitions of nodeSelector/affinity,
resources, PriorityClass, taints/tolerations.

## Deleting the Cluster and Resources

```bash
TASK=122 make delete_cka_task
```
