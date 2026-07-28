[Русская версия](README_RU.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD)

# Lab 121 — Drills: RBAC

## Description

A speed drill on RBAC: short independent tasks on ServiceAccount, Role/RoleBinding,
ClusterRole/ClusterRoleBinding and checking effective permissions with
`kubectl auth can-i`. The `rbac` namespace is created in advance.

The tasks are written in exam style with automatic validation via the `check_result`
command. The point of a drill is not theory but speed and muscle memory: get your hands
used to creating RBAC objects imperatively and keep up with the exam pace.

## Goal

Reinforce the material from the course chapters:

- [Chapter 21. ServiceAccount; authentication, authorization, admission](../../course/21/ru.md) — ServiceAccount, the authn/authz/admission chain
- [Chapter 38. RBAC: Role, ClusterRole and bindings](../../course/38/ru.md) — Role/ClusterRole, RoleBinding/ClusterRoleBinding, checking permissions with `auth can-i`

## What We Do and Why

| Block | Tasks | Skill |
|-------|-------|-------|
| **Namespaced RBAC** | ServiceAccount `app-sa`, Role `pod-reader`, RoleBinding `read-pods` | permissions within a namespace through Role + binding (chapter 38) |
| **Cluster-wide RBAC** | ClusterRole `cr-viewer`, ClusterRoleBinding `crb-viewer` | access to cluster-scoped resources (nodes) through ClusterRole (chapter 38) |
| **Permission check** | `kubectl auth can-i` for `app-sa` | quick validation of a ServiceAccount's effective permissions (chapter 21) |

## Infrastructure

The environment is deployed in AWS (`eu-central-1`) via Terragrunt and consists of:

| Component  | Description                                                                     |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` with public subnets                                          |
| `ssh-keys` | SSH keys for node access                                                         |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico CNI, metrics-server, single-node; the `rbac` namespace is created in advance |
| `worker`   | Work machine with `kubectl` and `check_result`                                  |

Instances: `t3.medium` (master), Ubuntu `22.04`. The cluster is single-node — the master is
untainted (the `control-plane` taint is removed), so Pods are scheduled directly on it.

## Deployment

```bash
TASK=121 make run_cka_task
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
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create the ServiceAccount `app-sa` in namespace `rbac` (`kubectl -n rbac create serviceaccount app-sa`). |
| Acceptance criteria | - ServiceAccount `app-sa` exists in namespace `rbac`. |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create the Role `pod-reader` in namespace `rbac` with the permissions `get,list,watch` on the resource `pods` (`kubectl -n rbac create role pod-reader --verb=get,list,watch --resource=pods`). |
| Acceptance criteria | - Role `pod-reader` grants `get`/`list`/`watch` on `pods`. |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create the RoleBinding `read-pods` in namespace `rbac`, binding the Role `pod-reader` to the subject ServiceAccount `app-sa` (`kubectl -n rbac create rolebinding read-pods --role=pod-reader --serviceaccount=rbac:app-sa`). |
| Acceptance criteria | - RoleBinding `read-pods` references the Role `pod-reader` and the subject `app-sa`. |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create the ClusterRole `cr-viewer` with the permissions `get,list` on the cluster-scoped resource `nodes` (`kubectl create clusterrole cr-viewer --verb=get,list --resource=nodes`). |
| Acceptance criteria | - ClusterRole `cr-viewer` grants `get`/`list` on `nodes`. |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Create the ClusterRoleBinding `crb-viewer`, binding the ClusterRole `cr-viewer` to the subject ServiceAccount `app-sa` from namespace `rbac` (`kubectl create clusterrolebinding crb-viewer --clusterrole=cr-viewer --serviceaccount=rbac:app-sa`). |
| Acceptance criteria | - ClusterRoleBinding `crb-viewer` references the ClusterRole `cr-viewer` and the subject `rbac/app-sa`. |
---
|        **6**        | **Permission check (auth can-i)**                           |
| :-----------------: | :----------------------------------------------------------- |
| What to do          | Check the effective permissions of `app-sa` with `kubectl auth can-i ... --as=system:serviceaccount:rbac:app-sa`: `get pods` in `rbac`, `get nodes` and `delete pods` in `rbac`. Make sure the bindings are granted correctly. |
| Acceptance criteria | - `get pods` in namespace `rbac` = `yes`;<br/>- `get nodes` = `yes`;<br/>- `delete pods` in namespace `rbac` = `no`. |
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

The Cluster Architecture domain (RBAC) for CKA and Application Security for CKAD — repeated
practice with Role/ClusterRole and bindings to a ServiceAccount.

## Deleting the Cluster and Resources

```bash
TASK=121 make delete_cka_task
```
