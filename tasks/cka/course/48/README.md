[Русская версия](ru.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# Chapter 48. The exam CKA: a format, a time management and a strategy

> 🟦 **A chapter for the CKA.** The general receptions of a speed and of an organization are the same as for the CKAD (the
> chapter 47); here a focus is on a specificity of the CKA: a troubleshooting (30%), an administration of a cluster,
> a work at the nodes.
>
> **What comes next.** A final of the course. You have got all the knowledge (the chapters 1-46) and a tactics of a speed (the
> chapter 47). Now - how to pass exactly the CKA: this exam is shifted towards an operation and a
> troubleshooting, it requires a work through an SSH at the nodes and a confident analysis of the failures of a cluster.
> We will assemble a strategy and a map of a repetition.

## 48.1. How the CKA differs from the CKAD by a tactics

A format is the same (2 hours, ~15-20 tasks, 66%, a documentation is allowed, the partial points), but
the accents are different (the chapter 1):

```mermaid
flowchart TB
    ckad["CKAD (the chapter 47)"]
    ckad --> d1["the applications: the manifests,<br>the configs, the probes"]

    cka["CKA (this chapter)"]
    cka --> a1["a troubleshooting 30% -<br>to fix a cluster, the nodes,<br>a control plane"]
    a1 ~~~ a2["an installation/an upgrade<br>kubeadm, etcd backup"]
    a2 ~~~ a3["a work through an SSH at the nodes,<br>systemctl/journalctl/crictl"]
    style ckad fill:#673ab7,color:#fff
    style cka fill:#0f9d58,color:#fff
    style d1 fill:#9c27b0,color:#fff
    style a1 fill:#3cb371,color:#fff
    style a2 fill:#3cb371,color:#fff
    style a3 fill:#3cb371,color:#fff
```

A main difference: **at the CKA there is a lot of a work outside of a kubectl** - at the nodes themselves (an SSH, the system
services, the files). A troubleshooting (30%) and an installation/a maintenance of a cluster require to get into
`/etc/kubernetes/`, `systemctl`, `journalctl`, `crictl`, `etcdctl`.

## 48.2. The weights of the domains and a distribution of a time

Distribute a time by the weights (the chapter 1):

```mermaid
flowchart LR
    t["2 hours"]
    t --> ts["Troubleshooting 30%<br>→ ~36 min"]
    t --> ca["Cluster Arch/Install 25%<br>→ ~30 min"]
    t --> sn["Services & Networking 20%<br>→ ~24 min"]
    t --> ws["Workloads & Scheduling 15%<br>→ ~18 min"]
    t --> st["Storage 10% → ~12 min"]
    style t fill:#326ce5,color:#fff
    style ts fill:#e74c3c,color:#fff
    style ca fill:#4a90d9,color:#fff
    style sn fill:#2ecc71,color:#fff
    style ws fill:#7b68ee,color:#fff
    style st fill:#e8a838,color:#000
```

A troubleshooting and a Cluster Architecture together are more than a half of an exam. Exactly there it is worth
to invest a main preparation.

## 48.3. The first minutes: the same settings + an SSH

A setup of an environment is as at the CKAD (the chapter 47): an alias, `$do`/`$now`, an autocompletion, a vim with
an expandtab. Plus a specificity of the CKA:

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
source <(kubectl completion bash); complete -o default -F __start_kubectl k
echo 'set tabstop=2 shiftwidth=2 expandtab' >> ~/.vimrc; export KUBE_EDITOR=vim
```

```mermaid
flowchart TB
    env["a standard<br>setup (ch.47)"] --> ssh["a readiness to work<br>through an SSH:<br>ssh &lt;node&gt;, sudo -i"]
    ssh --> tools["at a node: systemctl,<br>journalctl, crictl,<br>etcdctl, a vim of the manifests"]
    style env fill:#326ce5,color:#fff
    style ssh fill:#0f9d58,color:#fff
    style tools fill:#f4b400,color:#000
```

> **It is important for the CKA.** A lot of the tasks are solved **at a node**, and not through a kubectl. Be ready to
> `ssh` to a control plane/a worker, to `sudo`, to edit the files in `/etc/kubernetes/`,
> to look at `journalctl -u kubelet`, `crictl ps`. Do not forget to return to "your own" machine
> after a work at a node.

## 48.4. The key tasks of the CKA and where to repeat

The typical high-scoring tasks and the chapters of the course:

| A task | The chapters |
|---------|-------|
| to install a cluster / to add a node (kubeadm) | 35 |
| to upgrade a cluster (upgrade, cordon/drain) | 36 |
| a backup/a restoration of etcd | 37 |
| RBAC: the roles and the bindings | 38 |
| to issue a certificate through a CSR / kubeconfig | 39 |
| to fix a control plane (static pods) | 15, 45 |
| a node NotReady (kubelet/runtime/CNI) | 45, 30 |
| a service/a DNS does not work (Endpoints, CoreDNS) | 7, 31, 46 |
| NetworkPolicy | 34 |
| Deployment, scheduling, the resources | 5, 8, 12-14 |
| PV/PVC, StorageClass | 25-26 |

```mermaid
flowchart LR
    core["A core of a preparation for the CKA"]
    core --> tshoot["a troubleshooting:<br>the applications (44),<br>a control plane/the nodes (45),<br>a network (46)"]
    core --> install["kubeadm (35),<br>upgrade (36),<br>etcd (37)"]
    core --> sec["RBAC (38),<br>the certificates (39)"]
    style core fill:#326ce5,color:#fff
    style tshoot fill:#e74c3c,color:#fff
    style install fill:#4a90d9,color:#fff
    style sec fill:#0f9d58,color:#fff
```

## 48.5. A strategy of a troubleshooting under a timer

Since a troubleshooting is 30%, train the algorithms up to an automatism (the chapters 44-46):

```mermaid
flowchart LR
    q["A task-troubleshooting"]
    q -->|"a pod does not work"| pod["get → describe →<br>logs --previous →<br>exec (ch.44)"]
    q -->|"a kubectl does not answer /<br>a component"| cp["at a node: crictl/journalctl,<br>the manifests<br>in /etc/kubernetes (ch.45)"]
    q -->|"a node NotReady"| node["ssh: systemctl/journalctl<br>kubelet, runtime,<br>CNI, swap (ch.45)"]
    q -->|"a network/a service"| net["layer by layer: IP → DNS →<br>Endpoints →<br>a policy (ch.46)"]
    style q fill:#f4b400,color:#000
    style pod fill:#0f9d58,color:#fff
    style cp fill:#326ce5,color:#fff
    style node fill:#673ab7,color:#fff
    style net fill:#db4437,color:#fff
```

Do not guess - apply the decision trees out of the chapters 44-46. A fast localization ("which layer /
component") is more important than a knowledge of the rare details.

## 48.6. A time management and the rules of an exam

A general strategy is as at the CKAD (the chapter 47): three passes, to look at a weight, not to get stuck,
to leave a time for a check. A specificity of the CKA:

- **The heavy tasks (an etcd restore, an upgrade, an installation) take a lot of a time** - estimate,
  whether you manage them, and do not sacrifice several easy ones for a sake of one complex one.
- **After a work at a node return into an initial context** - it is easy to forget and to do
  a next task "in a wrong place".
- **Check the destructive operations** (a restore of etcd, a drain) - they are expensive at an error.
- **A documentation of kubernetes.io is allowed** - keep at hand the pages about a kubeadm
  upgrade, an etcd backup, a CSR: the exact commands are convenient to copy.

```mermaid
flowchart LR
    p1["A pass 1: the fast victories<br>(RBAC, the pods, the services)"] --> p2["A pass 2: the heavy ones<br>(etcd, upgrade, install)"] --> p3["A pass 3: a check,<br>especially of the destructive ones"]
    style p1 fill:#0f9d58,color:#fff
    style p2 fill:#326ce5,color:#fff
    style p3 fill:#673ab7,color:#fff
```

## 48.7. A top of the errors at the CKA

```mermaid
flowchart TB
    e1["forgot to return from a node →<br>does a task<br>in a wrong context"]
    e2["a wrong namespace/context"]
    e3["got stuck at an etcd/an upgrade,<br>abandoned the easy ones"]
    e4["edits a wrong manifest /<br>did not check, that<br>a static pod has come up"]
    e5["a destructive thing without a check<br>(restore, drain)"]
    e6["searches the basics in the docs<br>instead of a knowledge by heart"]
    e1 ~~~ e2 ~~~ e3 ~~~ e4 ~~~ e5 ~~~ e6
    style e1 fill:#db4437,color:#fff
    style e2 fill:#db4437,color:#fff
    style e3 fill:#db4437,color:#fff
    style e4 fill:#db4437,color:#fff
    style e5 fill:#db4437,color:#fff
    style e6 fill:#db4437,color:#fff
```

## 48.8. A final check-list before the CKA

- [ ] I can do a kubeadm init/join and I know the steps of a preparation of a node (the chapter 35);
- [ ] I can do an upgrade of a cluster with a cordon/drain/uncordon (the chapter 36);
- [ ] I know by heart the commands of an etcd snapshot save/restore (the chapter 37);
- [ ] I confidently create an RBAC and check an `auth can-i --as` (the chapter 38);
- [ ] I can do a CSR approve and a setup of a kubeconfig (the chapter 39);
- [ ] I fix a control plane through the manifests + crictl/journalctl (the chapters 15, 45);
- [ ] I analyse a NotReady at a node through an SSH (the chapter 45);
- [ ] I debug a network layer by layer and I know about the Endpoints/DNS (the chapter 46);
- [ ] I have set up an alias/an autocompletion/a vim and I switch the contexts reflexively (the chapter 47);
- [ ] I have run the mock exams under a timer.

```mermaid
flowchart LR
    know["the knowledge (the chapters 1-46)"] --> tactics["a tactics (the chapters 47-48)"] --> mock["the mocks under a timer"] --> pass["a passing of the CKA"]
    style know fill:#326ce5,color:#fff
    style tactics fill:#0f9d58,color:#fff
    style mock fill:#f4b400,color:#000
    style pass fill:#673ab7,color:#fff
```

## 48.9. A mini glossary

- **a troubleshooting domain** - 30% of the CKA, the most weighty one; to fix the applications/a cluster/a network.
- **a work at a node** - an SSH + systemctl/journalctl/crictl/etcdctl (a specificity of the CKA).
- **three passes** - a strategy of a time (the light ones → the heavy ones → a check).
- **the destructive operations** - an etcd restore, a drain: to check especially.
- **to return into a context** - after a work at a node to continue at an initial machine.
- **a mock exam** - a rehearsal under a timer with an autocheck.

## 48.10. The conclusions of the chapter

- The CKA is formally as the CKAD (2 hours, ~17 tasks, 66%, the partial points), but it is shifted into
  a troubleshooting (30%) and an administration - there is a lot of a work outside of a kubectl, at the nodes through an SSH.
- A time is by the weights: a troubleshooting + a cluster architecture is >50% of an exam, there is a main
  focus.
- A setup of an environment is the same (the chapter 47) + a readiness for an SSH/systemctl/journalctl/crictl/
  etcdctl at the nodes; after a work at a node to return into an initial context.
- The key tasks: a kubeadm install/upgrade, an etcd backup/restore, RBAC, CSR, a fixing of a
  control plane and of the nodes, a network debugging - to repeat by the maps 48.4/48.5.
- A troubleshooting is to be solved by the decision trees (the chapters 44-46), and not by a guessing.
- A time management: three passes, not to get stuck at the heavy ones (etcd/upgrade), to check the
  destructive operations.

## 48.11. How this will come in handy: at an exam and in a real work

**At an exam (CKA).** This chapter is an assembly of everything into a strategy of a passing: a distribution of a time by
the weights, a readiness to work at the nodes, the trees of a troubleshooting and a check-list. Together with the chapter 47
(a general tactics) and the knowledge of the chapters 1-46 this is a thing which gives a passing score.

**In a real work.** The skills of the CKA are exactly an everyday work of an administrator/of an SRE:
to raise and to upgrade a cluster, to back up an etcd, to set up the accesses, to fix a fallen control
plane or a node, to analyse a network incident. An exam checks exactly that thing which they do in a prod -
therefore a preparation for the CKA directly raises your value as an engineer.

## 48.12. The questions for a self-check

1. How does a tactics of the CKA differ from the CKAD? Why is a readiness to work at the nodes important?
2. How to distribute 2 hours by the domains and where to invest a main preparation?
3. Which tools are needed at a node and why is it impossible to forget to return into an initial context?
4. List the key high-scoring tasks of the CKA and the chapters for their repetition.
5. How to fast localize a troubleshooting problem under a timer?
6. Why do the destructive operations (an etcd restore, a drain) require a special check?
7. What in your final check-list is not yet trained up to an automatism?

## A conclusion of the course

Congratulations - you have passed a whole joint course CKA + CKAD. You have analysed Kubernetes from
an architecture of a cluster and the workloads up to a network, a storage, a security,
an administration and a troubleshooting, and you know a tactics of both the exams. A main thing is left -
**the hands**: run the labs and the mock exams under a timer, until the commands do not
become a reflex. A knowledge + a trained speed = the passed CKA and CKAD.

For a targeted preparation for one exam use the guides:
[CKA](../CKA.md) · [CKAD](../CKAD.md).

🧪 A lab 119 (the drills on a speed and a JSONPath): [tasks/cka/labs/119](../../labs/119/README.MD)

🧪 The mock exams of the CKA: [tasks/cka/mock](../../mock)

---
[Contents](../README.md) · [Chapter 47](../47/README.md)
