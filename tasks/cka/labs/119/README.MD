[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 119 — Speed Drills and JSONPath

## Description

A speed trainer for CKA/CKAD: short, repetitive tasks on imperative creation of objects
(Pod, Deployment, Service, ConfigMap, Secret) plus a separate block on `-o jsonpath` —
extracting data from cluster objects into files.

The tasks are written in exam style with automatic validation via the `check_result`
command. The point of the drill is not a theory walkthrough but speed and muscle memory:
building fluency with imperative commands and keeping up with the exam pace (~6-8 minutes
per task). The answer files for the JSONPath tasks are saved to `/home/ubuntu/answers/`.

## Goal

Reinforce the material from the course chapters:

- [Chapter 3. Working with kubectl: imperative and declarative approaches](../../course/03/README.md) — fast imperative commands, `--dry-run=client -o yaml`, object generators
- [Chapter 47. CKAD exam: JSONPath and kubectl productivity](../../course/47/README.md) — extracting data with `-o jsonpath`, custom-columns, `--sort-by`
- [Chapter 48. CKA exam: time management and strategy](../../course/48/README.md) — allocating time and choosing the order of tasks

## What We Do and Why

| Block | Tasks | Skill |
|-------|-------|-------|
| **Drills** | namespace, Deployment, Service, ConfigMap, Secret | speed of imperative commands, `--dry-run` (chapter 3) |
| **JSONPath** | node versions, Pod images, Service ClusterIP → into files | `-o jsonpath`, extracting data against the clock (chapter 47) |

## Infrastructure

The environment is deployed in AWS (`eu-central-1`) via Terragrunt and consists of:

| Component  | Description                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` with public subnets                               |
| `ssh-keys` | SSH keys for node access                                             |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico CNI, metrics-server, single-node |
| `worker`   | Work machine with `kubectl` and `check_result`                       |

Instances: `t4g.medium` (master), Ubuntu `22.04`. The cluster is single-node — the master is
untainted (the `control-plane` taint is removed), so Pods are scheduled directly on it.

## Deployment

```bash
TASK=119 make run_cka_task
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
|        **1**        | **Namespace**                                                |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create the namespace `drill` — the objects of the remaining tasks will live in it (`kubectl create namespace drill`). |
| Acceptance criteria | - namespace `drill` exists. |
---
|        **2**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | In namespace `drill` create a Deployment `api` with image `viktoruj/ping_pong:latest` and 3 replicas (`kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3`). |
| Acceptance criteria | - Deployment `api` in `drill`: 3 ready replicas. |
---
|        **3**        | **Service**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Expose Deployment `api` as a Service of type ClusterIP named `api-svc` on port 80 (`kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080`). |
| Acceptance criteria | - Service `api-svc` (ns `drill`): Endpoints are not empty. |
---
|        **4**        | **ConfigMap and Secret**                                    |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | In namespace `drill` create a ConfigMap `cfg` with the key `APP_COLOR=blue` and a Secret `sec` with the key `PASSWORD` (any value). Use `--from-literal`. |
| Acceptance criteria | - `cfg.data.APP_COLOR=blue`;<br/>- Secret `sec` has the key `PASSWORD`. |
---
|        **5**        | **JSONPath: node versions**                                 |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Extract the `kubeletVersion` of all nodes with `-o jsonpath` and save the result to the file `/home/ubuntu/answers/versions.txt` (path `{.items[*].status.nodeInfo.kubeletVersion}`). |
| Acceptance criteria | - the contents of `versions.txt` match the `jsonpath` output for the nodes. |
---
|        **6**        | **JSONPath: Pod images**                                    |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Extract the container images of all Pods in namespace `drill` with `-o jsonpath` and save them to `/home/ubuntu/answers/images.txt` (path `{.items[*].spec.containers[*].image}`). |
| Acceptance criteria | - the set of images in `images.txt` matches the `jsonpath` output for the Pods in `drill`. |
---
|        **7**        | **JSONPath: Service ClusterIP**                             |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Extract the ClusterIP of Service `api-svc` with `-o jsonpath` and save it to `/home/ubuntu/answers/api-ip.txt` (path `{.spec.clusterIP}`). |
| Acceptance criteria | - the value in `api-ip.txt` matches `.spec.clusterIP` of Service `api-svc`. |
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

Basic speed and JSONPath skills, in demand across all CKA and CKAD mock exams.

## Deleting the Cluster and Resources

```bash
TASK=119 make delete_cka_task
```
