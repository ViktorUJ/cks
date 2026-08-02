[Русская версия](GLOSSARY_RU.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glossary of the CKA + CKAD course

[← Course contents](README.md) · [CKA](CKA.md) · [CKAD](CKAD.md)

A single alphabetical reference of the terms of the course. A term is in English (as in
Kubernetes), a description is in English, in the "Chapters" column - where the term is
covered (with the links to the chapters). A search on the page - Ctrl+F.

| Term | Description | Chapters |
|--------|----------|-------|
| **A record / AAAA record** | a DNS record name → IPv4 / name → IPv6. | [0.2](00-2-dns/README.md) |
| **accessModes** | the access modes: RWO, ROX, RWX, RWOP. | [25](25/README.md) |
| **activeDeadlineSeconds** | the maximum running time of a task. | [10](10/README.md) |
| **Adapter** | a container that converts the output of an application into a required format. | [22](22/README.md) |
| **admin.conf** | the kubeconfig of an administrator after init. | [35](35/README.md) |
| **Admission control** | a check/modification of a request after authn+authz. | [21](21/README.md) |
| **aggregation layer** | an extension of the API through your own extension-apiserver (e.g. metrics-server). | [41](41/README.md) |
| **APIService** | an object that registers an aggregated API (`metrics.k8s.io` and others). | [41](41/README.md) |
| **allow logic** | the policies only allow; there is no deny as a separate rule. | [34](34/README.md) |
| **allowPrivilegeEscalation** | an allowance/prohibition of a privilege escalation. | [20](20/README.md) |
| **allowVolumeExpansion** | whether a volume may be expanded. | [25](25/README.md), [26](26/README.md) |
| **Ambassador** | a proxy container for the outgoing connections of an application. | [22](22/README.md) |
| **Annotation** | a key-value pair for additional data, not for a selection. | [06](06/README.md) |
| **API deprecation** | a declaration of an API version as obsolete with a removal afterwards. | [29](29/README.md) |
| **apiVersion** | the version of the API group of an object (alpha/beta/stable). | [29](29/README.md) |
| **Application container** | the main container of a pod with the payload. | [04](04/README.md) |
| **apply** | to create or to update an object from a manifest (idempotent, a 3-way merge). | [03](03/README.md) |
| **args** | overrides the CMD of an image (the arguments). | [17](17/README.md) |
| **Authn** | an establishment of who the sender of a request is. | [21](21/README.md) |
| **Authz** | a check that the sender is allowed (RBAC). | [21](21/README.md) |
| **automountServiceAccountToken** | whether to mount the token of an SA into a pod. | [21](21/README.md) |
| **averageUtilization** | a target average percentage of a resource usage. | [16](16/README.md) |
| **backendRefs** | the target services (with the weights for a canary). | [33](33/README.md) |
| **backoffLimit** | a number of the retries on a failure. | [10](10/README.md) |
| **Bare pod** | a pod created directly, without a controller; it is not recreated. | [04](04/README.md) |
| **base** | the common source manifests. | [43](43/README.md) |
| **Base image** | a base image (`FROM`) a build starts from. | [23](23/README.md) |
| **base64** | the encoding of the values of a Secret; NOT an encryption. | [19](19/README.md) |
| **behavior** | a fine tuning of the speed of a scale up/down. | [16](16/README.md) |
| **Binding** | a binding of a matching PV to a PVC (one to one). | [25](25/README.md) |
| **Blue** | the current working version; **Green** - the new one, being prepared for a switch. | [09](09/README.md) |
| **Blue/Green** | two full environments (the current and the new one) with an instant switch of the traffic. | [09](09/README.md) |
| **bootstrap token** | a temporary token for a join of the nodes (it lives ~24 hours). | [35](35/README.md) |
| **bridge (cni0)** | a software switch of a node that connects the pods on it. | [0.7](00-7-netns/README.md), [30](30/README.md) |
| **CA** | a certificate authority; a root of trust, it signs the certificates. | [0.3](00-3-tls/README.md), [39](39/README.md) |
| **Calico / Cilium / Flannel** | the popular CNI plugins. | [30](30/README.md), [40](40/README.md) |
| **Canary** | a release of a new version for a small share of the traffic with a gradual increase. | [09](09/README.md) |
| **CIDR** | a notation `address/N`, where `N` is a number of the bits for the network; a bigger N - a smaller network. | [0.1](00-1-net/README.md), [30](30/README.md) |
| **CNAME** | a DNS record: an alias that points to another name. | [0.2](00-2-dns/README.md) |
| **capabilities** | the separate rights out of the "omnipotence of root" (drop/add). | [20](20/README.md) |
| **cgroups** | the kernel controllers that limit the resources of a container (cpu, memory, pids, io); a basis of requests/limits. | [0.4](00-4-containers/README.md), [14](14/README.md) |
| **cgroup v1 / v2** | the old (a hierarchy per controller) / the modern (a single hierarchy) versions of cgroups; v2 by default since Fedora 31, Ubuntu 22.04, Debian 11, RHEL 9 (K8s cgroup v2 is GA since 1.25). | [0.4](00-4-containers/README.md) |
| **cgroup driver** | who configures cgroups (`systemd` or `cgroupfs`); the kubelet and the runtime must match (`SystemdCgroup=true`). | [0.4](00-4-containers/README.md), [35](35/README.md) |
| **cert-manager** | an operator of an automatic issuance and renewal of the certificates. | [32](32/README.md) |
| **cert-manager / Prometheus Operator** | the popular operators. | [41](41/README.md) |
| **change-cause** | an annotation with a reason of a change for the history. | [08](08/README.md) |
| **Chart** | a package: the templates of the manifests + values + the metadata. | [42](42/README.md) |
| **CKA** | Certified Kubernetes Administrator, an exam on an administration of a cluster. | [01](01/README.md) |
| **CKAD** | Certified Kubernetes Application Developer, an exam on a running of the applications. | [01](01/README.md) |
| **Client certificate** | an identity of a user; CN → a name, O → a group. | [39](39/README.md) |
| **Cluster Autoscaler** | changes the number of the nodes in a cluster. | [16](16/README.md) |
| **Karpenter** | selects and launches the nodes of a needed type for the Pending pods (more flexible than Cluster Autoscaler). | [16](16/README.md) |
| **Cluster API** | a declarative management of the life cycle of the clusters. | [35](35/README.md), [35B](35-3-design/README.md) |
| **managed / self-managed** | the control plane is served by a provider (EKS/GKE/AKS) / by you. | [35B](35-3-design/README.md) |
| **node pool** | a group of the nodes of the same kind (a profile, a zone, spot/on-demand). | [35B](35-3-design/README.md) |
| **IaC** | an infrastructure as code (Terraform/OpenTofu, Ansible). | [35B](35-3-design/README.md) |
| **GitOps** | git as a source of truth for the state of a cluster (Argo CD/Flux). | [35B](35-3-design/README.md) |
| **cluster-admin / admin / edit / view** | the built-in ClusterRole. | [38](38/README.md) |
| **Cluster-scoped object** | on the level of a cluster (Node, PV, StorageClass, ClusterRole). | [06](06/README.md) |
| **ClusterIP** | the default type: an internal virtual IP, available only inside a cluster. | [07](07/README.md) |
| **ClusterRole** | the permissions for a cluster / the cluster-scoped resources / for a reuse. | [38](38/README.md) |
| **ClusterRoleBinding** | a binding of a role to a subject for the whole cluster. | [38](38/README.md) |
| **CNCF** | Cloud Native Computing Foundation, the organization behind Kubernetes and these certifications. | [01](01/README.md) |
| **CNI** | the interface and a plugin of the network of the pods (Calico, Cilium and others). | [02](02/README.md), [30](30/README.md), [40](40/README.md) |
| **command** | overrides the ENTRYPOINT of an image (what to run). | [17](17/README.md) |
| **completions** | how many successful completions are needed. | [10](10/README.md) |
| **componentstatuses** | an overview status of the components (is being deprecated). | [45](45/README.md) |
| **concurrencyPolicy** | a policy for the overlapping runs of a CronJob (Allow/Forbid/Replace). | [10](10/README.md) |
| **Conditions** | the states of a node (Ready, MemoryPressure, DiskPressure, PIDPressure). | [45](45/README.md) |
| **ConfigMap** | an object with a non-secret configuration (the key-values or the files). | [18](18/README.md) |
| **configMapGenerator / secretGenerator** | a generation of a ConfigMap/Secret (with a hash in a name). | [43](43/README.md) |
| **configMapKeyRef** | to take a single key of a ConfigMap into an environment variable. | [18](18/README.md) |
| **container runtime** | an environment of an execution of the containers (containerd), it talks over CRI. | [02](02/README.md) |
| **containerd / CRI-O** | the implementations of CRI (the runtimes). | [40](40/README.md) |
| **context** | a bundle of cluster + user + namespace. | [39](39/README.md) |
| **Context (kubeconfig)** | a bundle of a cluster + a user + a namespace; it is switched by `use-context`. | [03](03/README.md) |
| **Control plane** | the management layer of a cluster (the brain): apiserver, etcd, scheduler, controller-manager. | [02](02/README.md) |
| **Controller** | a program with a reconciliation loop (it brings the reality to the spec). | [41](41/README.md) |
| **cordon** | to mark a node unschedulable (the new pods do not go here). | [36](36/README.md) |
| **cordon / drain** | to mark a node unschedulable / to evict the pods from it (chapter 36). | [13](13/README.md), [36](36/README.md) |
| **CoreDNS** | the DNS server of a cluster (a Deployment in kube-system behind the Service kube-dns). | [31](31/README.md) |
| **Corefile** | the configuration of CoreDNS (in the ConfigMap `coredns`). | [31](31/README.md) |
| **CrashLoopBackOff** | a container falls and restarts in a loop. | [04](04/README.md), [44](44/README.md) |
| **containerd / CRI-O** | the high-level container runtimes the kubelet works with. | [0.4](00-4-containers/README.md), [40](40/README.md) |
| **CRD** | a definition of a new type of the objects in the API. | [41](41/README.md) |
| **CreateContainerConfigError** | there is no ConfigMap/Secret a pod refers to. | [44](44/README.md) |
| **CRI** | the interface kubelet ↔ an execution environment. | [0.4](00-4-containers/README.md), [40](40/README.md) |
| **crictl** | a CLI for a work with the containers through CRI on a node. | [40](40/README.md), [45](45/README.md) |
| **CronJob** | creates the Jobs by a cron schedule. | [10](10/README.md) |
| **CSI** | the standard of a connection of the storages to Kubernetes. | [26](26/README.md), [40](40/README.md) |
| **CSI driver** | an implementation of CSI (a provisioner in a StorageClass). | [40](40/README.md) |
| **CSR** | a request for a signing of a certificate through the API of a cluster. | [39](39/README.md) |
| **certSANs** | the additional names/addresses in the certificate of the apiserver (e.g. the DNS of a load balancer for HA). | [35](35/README.md) |
| **certificatesDir** | the PKI directory of a cluster (by default `/etc/kubernetes/pki`). | [35](35/README.md) |
| **Custom Resource** | an instance of a type defined by a CRD. | [41](41/README.md) |
| **custom-columns** | your own table of an output. | [47](47/README.md) |
| **DaemonSet** | a controller that keeps one pod on every (suitable) node. | [11](11/README.md) |
| **data / binaryData** | the text / the binary data of a ConfigMap. | [18](18/README.md) |
| **Declarative approach** | a management through the manifests (`kubectl apply -f`). | [01](01/README.md), [03](03/README.md) |
| **default / kube-system / kube-public / kube-node-lease** | the system namespaces. | [06](06/README.md) |
| **default deny** | a policy that blocks everything in a direction (there are no allowing rules). | [34](34/README.md) |
| **default SA** | the default ServiceAccount in every namespace. | [21](21/README.md) |
| **Default StorageClass** | the default class for a PVC without an explicit class. | [26](26/README.md) |
| **default-deny + DNS** | a trap: an egress policy cuts off the resolving (chapter 34). | [34](34/README.md), [46](46/README.md) |
| **Deployment** | a controller over a ReplicaSet: the replicas + the updates + the rollbacks + the history. | [05](05/README.md) |
| **Desired state** | what you have described in a manifest. | [01](01/README.md) |
| **Destructive operations** | an etcd restore, a drain: to check them especially carefully. | [48](48/README.md) |
| **distroless / scratch** | the minimal base images without anything excessive / an empty one. | [23](23/README.md) |
| **dnsConfig** | a fine tuning of the DNS of a pod (including `options ndots`), it works with any dnsPolicy. | [31](31/README.md) |
| **dnsPolicy** | how a pod gets its DNS (ClusterFirst and others). | [31](31/README.md) |
| **Dockerfile** | the instructions of a build of an image. | [0.4](00-4-containers/README.md), [23](23/README.md) |
| **Downward API** | an access of a pod to the information about itself (`fieldRef`, `resourceFieldRef`). | [17](17/README.md) |
| **drain** | to evict the pods from a node (gracefully), to move them to the others. | [36](36/README.md) |
| **Dynamic provisioning** | an automatic creation of a PV for a request of a PVC. | [26](26/README.md) |
| **eBPF** | a technology in the Linux kernel that Cilium is built on. | [30](30/README.md) |
| **EmptyDir** | a volume of a pod for an exchange of the files between the containers. | [22](22/README.md), [24](24/README.md) |
| **encryption at rest** | an encryption of the Secrets in etcd. | [19](19/README.md) |
| **External CA mode** | in `pki/` there is only `ca.crt` without a key: kubeadm makes a CSR, a signing and a renewal are up to you. | [35](35/README.md) |
| **endpoint 2379** | the client port of etcd. | [37](37/README.md) |
| **Endpoints** | a list of the addresses of the pods behind a service; an empty one = it is not bound (chapter 7). | [07](07/README.md), [46](46/README.md) |
| **Endpoints / EndpointSlice** | a list of the IPs of the ready pods behind a service. | [07](07/README.md) |
| **ENTRYPOINT/CMD** | what to run and with which arguments, defined in an image. | [17](17/README.md) |
| **env** | the environment variables of a container. | [17](17/README.md) |
| **envFrom + configMapRef** | all the keys of a ConfigMap as the environment variables. | [18](18/README.md) |
| **Ephemeral volume** | it lives as long as a pod does (it survives a restart of a container, but not a deletion of the pod). | [24](24/README.md) |
| **ephemeral container** | a temporary container for a debugging of a live pod (`kubectl debug`). | [04](04/README.md), [29](29/README.md) |
| **etcd** | a distributed key-value store of the whole state of a cluster. | [02](02/README.md), [37](37/README.md) |
| **etcdctl** | a CLI for a work with etcd; `ETCDCTL_API=3` is needed for the snapshots. | [37](37/README.md) |
| **Events** | a chronology of the actions with an object in the output of `describe`/`get events`. | [29](29/README.md), [44](44/README.md) |
| **eviction** | an eviction of the pods by the kubelet on a shortage of the resources of a node. | [14](14/README.md) |
| **exec** | to run a command/a shell inside a container. | [29](29/README.md) |
| **exec form** | a command as a list, without a shell (the right one for the signals). | [17](17/README.md) |
| **expandtab** | a setting of vim (the spaces instead of the tabs) for YAML. | [0.8](00-8-vim/README.md), [47](47/README.md) |
| **External Secrets / Vault / SOPS / Sealed Secrets** | the tools of a real protection of the secrets. | [19](19/README.md) |
| **ExternalName** | a DNS alias (CNAME) to an external domain. | [07](07/README.md) |
| **FailedScheduling** | an event of the scheduler on a Pending. | [44](44/README.md) |
| **failureThreshold / successThreshold** | a number of the failures/the successes for a change of a state. | [27](27/README.md) |
| **filters** | the transformations (rewrite, redirect, the headers). | [33](33/README.md) |
| **Flat network** | any pod sees any other one by an IP directly, without NAT. | [30](30/README.md) |
| **Fluent Bit/Fluentd** | the agents of a collection of the logs (usually a DaemonSet). | [28](28/README.md) |
| **FQDN of a service** | `<service>.<namespace>.svc.cluster.local`. | [31](31/README.md) |
| **fsGroup** | the owner group of the mounted volumes (the level of a pod). | [20](20/README.md) |
| **Gateway** | an entry point: the listeners (the ports, the protocols, TLS); an operator of a cluster owns it. | [33](33/README.md) |
| **Gateway API** | the modern standard of a routing of the traffic in Kubernetes. | [33](33/README.md) |
| **FQDN** | a full domain name with all the levels (e.g. `backend.default.svc.cluster.local`). | [0.2](00-2-dns/README.md), [31](31/README.md) |
| **GatewayClass** | an implementation (a controller) of Gateway API, an analog of a StorageClass. | [33](33/README.md) |
| **globalDefault** | a PriorityClass applied to the pods without an explicit priority. | [15](15/README.md) |
| **HA (high availability)** | a fault tolerance of the control plane: several nodes, a failure of one does not bring the management down. | [35A](35-2-ha/README.md) |
| **--control-plane-endpoint** | a stable address of the control plane (a load balancer) for HA; it is set at `kubeadm init`. | [35A](35-2-ha/README.md), [35](35/README.md) |
| **stacked / external etcd** | etcd on the control-plane nodes themselves (by default) / on the separate nodes. | [35A](35-2-ha/README.md) |
| **quorum (etcd)** | a majority of the etcd members for a write (raft); hence an odd number (3/5). | [35A](35-2-ha/README.md), [37](37/README.md) |
| **leader election** | a choice of an active instance of the scheduler/the controller-manager in HA (the rest are on a standby). | [35A](35-2-ha/README.md) |
| **SPOF** | a single point of failure; HA removes it. | [35A](35-2-ha/README.md) |
| **--upload-certs / certificate-key** | a transfer of the certificates of the control plane at a join of the HA nodes. | [35A](35-2-ha/README.md) |
| **Handshake (TLS)** | a procedure of an establishment of a TLS connection (a check of a certificate, an agreement on a key). | [0.3](00-3-tls/README.md) |
| **Headless service** | `clusterIP: None`, the DNS returns the IPs of the pods directly. | [07](07/README.md), [11](11/README.md) |
| **Helm** | a package manager for Kubernetes. | [42](42/README.md) |
| **helm install/upgrade/rollback/uninstall** | the life cycle of a release. | [42](42/README.md) |
| **helm template** | a local render of a chart into the manifests (for a check). | [42](42/README.md) |
| **hostPath** | a mount of a directory of a node into a pod (risky, for the system tasks). | [24](24/README.md) |
| **HPA** | changes the number of the replicas by the metrics. | [16](16/README.md) |
| **httpGet / tcpSocket / exec / grpc** | the ways of a check. | [27](27/README.md) |
| **HTTPRoute** | the rules of an HTTP routing to the services; a developer owns it. | [33](33/README.md) |
| **IgnoredDuringExecution** | a rule is checked at a scheduling, but it does not evict an already running pod. | [12](12/README.md) |
| **Image** | a packed FS of an application + the dependencies + the metadata of a start. | [23](23/README.md) |
| **ImagePullBackOff/ErrImagePull** | an image cannot be pulled. | [44](44/README.md) |
| **imagePullPolicy** | when to pull an image (IfNotPresent/Always/Never). | [23](23/README.md) |
| **imagePullSecrets** | a secret for an access to a private registry of the images. | [19](19/README.md) |
| **immutable** | an immutable ConfigMap (only a recreation). | [18](18/README.md) |
| **Imperative approach** | a management of the objects by the commands (`kubectl run`, `create`). | [01](01/README.md), [03](03/README.md) |
| **Ingress controller** | an application that executes the Ingress rules (nginx, Traefik, ALB). | [32](32/README.md) |
| **Ingress resource** | a declaration of the rules of an L7 routing (the hosts, the paths, TLS). | [32](32/README.md) |
| **ingress2gateway** | a utility of an automatic conversion of an Ingress into the resources of Gateway API (it gives a draft, a review is required). | [33](33/README.md) |
| **IngressClass** | which controller serves this Ingress (`ingressClassName`). | [32](32/README.md) |
| **Init container** | a container that runs before the main ones and is obliged to complete. | [22](22/README.md) |
| **initialDelaySeconds** | a delay before the first check. | [27](27/README.md) |
| **IP address** | a numeric address of a device in a network (IPv4 - 32 bits, four octets). | [0.1](00-1-net/README.md) |
| **ipBlock** | an allowance by a range of the IPs (an external traffic). | [34](34/README.md) |
| **iptables / IPVS modes** | the ways of an implementation of the services; IPVS scales better. | [31](31/README.md) |
| **Job** | a controller of a one-time task; it watches for a successful completion of the pods. | [10](10/README.md) |
| **journalctl -u kubelet** | the logs of the kubelet, the main source of the reasons of a NotReady. | [45](45/README.md) |
| **JSONPath** | a language of a selection of the fields from a response of the API (`-o jsonpath=...`). | [03](03/README.md), [47](47/README.md) |
| **KEDA** | an event-driven autoscaling by the external events (including down to zero). | [16](16/README.md) |
| **kube-apiserver** | the single entry point all the requests go through; the only one that writes into etcd. | [02](02/README.md) |
| **list-watch** | a tracking of the changes: a LIST + a WATCH stream (without a polling of the API). | [02](02/README.md) |
| **informer** | a local cache of the objects of a controller, synchronized through a watch. | [02](02/README.md) |
| **resourceVersion** | a version of an object; a continuation of a watch and a basis of an optimistic locking. | [02](02/README.md) |
| **optimistic locking** | a write with an outdated version is rejected (409 Conflict) → a retry. | [02](02/README.md) |
| **kube-controller-manager** | a set of the controllers (the reconciliation loops). | [02](02/README.md) |
| **kube-proxy** | implements the services through iptables/IPVS on a node. | [02](02/README.md), [07](07/README.md), [31](31/README.md) |
| **kube-scheduler** | assigns the pods to the nodes. | [02](02/README.md), [12](12/README.md) |
| **kubeadm** | the official tool of an installation of a cluster (init/join/upgrade). | [35](35/README.md) |
| **kubeadm certs renew** | to renew the certificates of a cluster. | [39](39/README.md) |
| **kubeadm init** | an initialization of the control plane. | [35](35/README.md) |
| **kubeadm join** | a joining of a node to a cluster. | [35](35/README.md) |
| **kubeadm reset** | a cleanup of the state of kubeadm on a node. | [36](36/README.md) |
| **kubeadm upgrade plan / apply / node** | a plan / an application (the first CP) / an upgrade of a node. | [36](36/README.md) |
| **kubeconfig** | a file (`~/.kube/config`) with the clusters, the users and the contexts. | [03](03/README.md), [39](39/README.md) |
| **kubectl** | the main command line utility for a work with a cluster. | [01](01/README.md), [03](03/README.md) |
| **kubectl apply -k** | to apply a Kustomize directory. | [43](43/README.md) |
| **kubectl certificate approve** | to approve a CSR (to sign it by the CA). | [39](39/README.md) |
| **kubectl debug** | to inject a debug container / to copy a pod / to debug a node. | [29](29/README.md) |
| **kubectl explain** | the built-in documentation on the fields of the objects. | [03](03/README.md) |
| **kubectl kustomize / kustomize build** | a render without an application. | [43](43/README.md) |
| **kubectl logs** | a view of the logs of a pod/a container. | [28](28/README.md) |
| **kubectl top** | to show a consumption of the resources (metrics-server is needed). | [28](28/README.md) |
| **kubelet** | an agent of a node, it starts and controls the pods; a system service. | [02](02/README.md) |
| **Kubernetes** | a system of an orchestration of the containers: it brings the real state of a cluster to the desired one. | [01](01/README.md) |
| **kustomization.yaml** | a file that describes the resources and the transformations. | [43](43/README.md) |
| **Kustomize** | a tool of an adaptation of the manifests by an overlay of the patches, without the templates. | [43](43/README.md) |
| **Label** | a key-value pair for a selection and a binding of the objects. | [06](06/README.md) |
| **Labels** | the key-value pairs on the objects, the selectors work by them. | [05](05/README.md) |
| **Layer** | a set of the changes of the FS; the layers are cached and reused. | [23](23/README.md) |
| **Layered troubleshooting** | an analysis of a network from the bottom up: CNI → DNS → Endpoints → a policy → an entry. | [46](46/README.md) |
| **LimitRange** | the defaults and the boundaries of the resources for a single object in a namespace. | [14](14/README.md) |
| **limits** | a ceiling of a consumption; it is checked during a work. | [14](14/README.md) |
| **liveness** | whether a container is alive; a failure → a restart. | [27](27/README.md) |
| **LoadBalancer** | an external cloud load balancer in front of a service. | [07](07/README.md) |
| **localhost** | the common network of a pod through which the containers see each other. | [22](22/README.md) |
| **Manifest** | a YAML file with a description of an object of Kubernetes. | [01](01/README.md) |
| **matchLabels / matchExpressions** | the two forms of a selector. | [06](06/README.md) |
| **maxSurge** | how many pods may be created above the desired number during a rollout. | [08](08/README.md) |
| **maxUnavailable** | how many pods may be temporarily lost during a rollout. | [08](08/README.md) |
| **medium: Memory** | a placement of an emptyDir in the RAM (tmpfs). | [24](24/README.md) |
| **metrics-server** | collects the CPU/the memory of the pods; it is needed for an HPA and `kubectl top`. | [16](16/README.md), [28](28/README.md) |
| **Mi/Gi vs M/G** | the binary (1024) against the decimal (1000) units of the memory. | [14](14/README.md) |
| **Microsegmentation** | a fine separation of the traffic between the pods/the services. | [34](34/README.md) |
| **milli-CPU** | a thousandth of a core (`500m` = a half of a core). | [14](14/README.md) |
| **minReplicas/maxReplicas** | the lower and the upper boundaries of the number of the replicas. | [16](16/README.md) |
| **Mirror Pod** | a reflection of a static pod in the API; it is visible, but it is not deleted through kubectl. | [15](15/README.md) |
| **Mock exam** | a rehearsal under a timer with an automatic check. | [48](48/README.md) |
| **mTLS** | a mutual TLS: both sides present the certificates. | [0.3](00-3-tls/README.md), [39](39/README.md) |
| **Multi-stage build** | a build in one image, the final one - only the result. | [23](23/README.md) |
| **Mutating / Validating admission** | the modifying / the checking controllers. | [21](21/README.md) |
| **Namespace** | a section of a cluster; the names of the objects are unique inside it. | [06](06/README.md) |
| **Namespaced object** | it lives in a namespace (Pod, Deployment, Service, ...). | [06](06/README.md) |
| **namespaceSelector** | a choice of the pods by the labels of a namespace. | [34](34/README.md) |
| **NAT** | a substitution of the addresses on a gateway so that a private traffic goes outside. | [0.1](00-1-net/README.md) |
| **netshoot** | an image with the network tools for a debugging. | [46](46/README.md) |
| **NetworkPolicy** | the rules of which pod may talk with which one (a firewall of the level of the pods). | [34](34/README.md) |
| **Node** | a machine (a VM or a physical one) as a part of a cluster. | [02](02/README.md) |
| **Node-level work** | SSH + systemctl/journalctl/crictl/etcdctl (a specificity of CKA). | [48](48/README.md) |
| **nodeAffinity** | a flexible selection of the nodes; `required` (strictly) and `preferred` (softly). | [12](12/README.md) |
| **NodeLocal DNSCache** | a local DNS cache on every node. | [31](31/README.md) |
| **nodeName** | a hard assignment of a node bypassing the scheduler. | [12](12/README.md) |
| **NodePort** | opens a port (30000-32767) on all the nodes for an external access. | [07](07/README.md) |
| **nodeSelector** | a simple hard selection of a node by its labels. | [12](12/README.md) |
| **NoExecute** | not to schedule and to evict the already running pods without a toleration. | [13](13/README.md) |
| **NoSchedule** | not to schedule the new pods without a toleration (the old ones stay). | [13](13/README.md) |
| **NotReady** | a status of a node when the kubelet does not report a readiness. | [45](45/README.md) |
| **ndots** | a threshold of the dots in a name: below it a name is first tried with the search suffixes (the default `ndots:5` → the excessive queries for the external names). | [31](31/README.md) |
| **namespaces (Linux)** | an isolation of what a process sees: PID, NET, MNT, UTS, IPC, USER (not to be confused with a namespace of Kubernetes). | [0.4](00-4-containers/README.md) |
| **network namespace** | an isolated network stack of a process/a container (its own interfaces, IPs, routes). | [0.7](00-7-netns/README.md), [40](40/README.md) |
| **nslookup/dig** | a check of a DNS resolving from inside a pod. | [46](46/README.md) |
| **OCI** | the open standard of the format of the images and the containers (a compatibility Docker ↔ containerd). | [0.4](00-4-containers/README.md) |
| **OLM** | Operator Lifecycle Manager, a mechanism of an installation/an update of the operators. | [41](41/README.md) |
| **OOMKilled** | a container is killed for an excess of the memory limit. | [04](04/README.md), [14](14/README.md), [44](44/README.md) |
| **Operator** | a controller + the domain knowledge about a management of an application. | [41](41/README.md) |
| **operator Equal/Exists** | a match by a value / only by a key. | [13](13/README.md) |
| **Orchestration** | an automatic management of the life cycle of the containers (a start, a restart, a scaling, a placement). | [01](01/README.md) |
| **overlay** | a set of the changes on top of a base for a specific environment. | [43](43/README.md) |
| **Overlay network** | a network with an encapsulation of the packets between the nodes (VXLAN). | [30](30/README.md) |
| **parallelism** | how many pods a Job runs simultaneously. | [10](10/README.md) |
| **parentRefs** | a binding of a Route to a Gateway. | [33](33/README.md) |
| **Partial credit** | a partially done work is counted. | [47](47/README.md) |
| **patches** | the pinpoint changes of the fields (strategic merge / JSON6902). | [43](43/README.md) |
| **pathType** | a way of a matching of a path: Prefix / Exact / ImplementationSpecific. | [32](32/README.md) |
| **pause container** | a service container that holds the network namespace of a pod. | [40](40/README.md) |
| **Pending** | a pod is not scheduled (the resources/the taints/the affinity/a PVC). | [44](44/README.md) |
| **periodSeconds** | an interval of the checks. | [27](27/README.md) |
| **PersistentVolume** | an object - "a piece of a storage" in a cluster. | [25](25/README.md) |
| **PersistentVolumeClaim** | a request of an application for a storage (a size, a mode). | [25](25/README.md) |
| **Phase** | a large stage of a life of a pod: Pending, Running, Succeeded, Failed, Unknown. | [04](04/README.md) |
| **PKI of a cluster** | a set of the CAs and the certificates in `/etc/kubernetes/pki/`, it is created at `kubeadm init`. | [35](35/README.md), [39](39/README.md) |
| **front-proxy-ca** | the CA for the aggregation layer (the extensions of the API server). | [35](35/README.md) |
| **sa.key / sa.pub** | a pair of the keys for a signing of the tokens of a ServiceAccount. | [35](35/README.md), [21](21/README.md) |
| **pluto / kubent** | the tools of a search of the deprecated APIs in the manifests/a cluster. | [29](29/README.md), [36](36/README.md) |
| **kubepug (kubectl deprecations)** | a check of the API against a target version of K8s (a cluster and the files). | [29](29/README.md) |
| **kubeconform** | a validator of the manifests by the schemas of a target version of K8s (CI). | [29](29/README.md) |
| **Popeye** | a sanitizer of a cluster; it finds the deprecated APIs among other things. | [29](29/README.md) |
| **Pod** | the minimal unit of a run: a wrapper around one/several containers with a common network and the volumes. | [04](04/README.md) |
| **Pod CIDR / Service CIDR** | the ranges of the addresses of the pods / of the virtual IPs of the services; they must not overlap. | [0.1](00-1-net/README.md), [30](30/README.md) |
| **Pod connectivity** | whether the pods can talk by an IP (the level of CNI, chapter 30). | [30](30/README.md), [46](46/README.md) |
| **Pod Security Admission** | the built-in policy of the levels privileged/baseline/restricted. | [20](20/README.md) |
| **podAffinity** | to place a pod next to the pods by the labels. | [12](12/README.md) |
| **podAntiAffinity** | to place a pod away from the pods by the labels. | [12](12/README.md) |
| **PodDisruptionBudget** | a minimum of the available pods at a voluntary eviction. | [36](36/README.md) |
| **podSelector** | to which pods a policy is applied / whom to allow. | [34](34/README.md) |
| **policyTypes** | the directions: Ingress (an incoming one) and/or Egress (an outgoing one). | [34](34/README.md) |
| **port / targetPort / nodePort** | a port of a service / a port on the pods / a port on the nodes. | [07](07/README.md) |
| **port-forward** | a forwarding of a port of a pod/a service to a local machine. | [29](29/README.md), [46](46/README.md) |
| **Preemption** | a deletion of the less priority pods for the sake of a placement of a more priority one. | [15](15/README.md) |
| **PreferNoSchedule** | to avoid a scheduling here softly. | [13](13/README.md) |
| **pressure-taints** | the automatic taints on a shortage of the resources of a node (chapter 13). | [13](13/README.md), [45](45/README.md) |
| **PriorityClass** | an object with a numeric priority of the pods. | [15](15/README.md) |
| **privileged** | a privileged container (≈ root on a node); it is dangerous. | [20](20/README.md) |
| **Probe** | a check of a health of a container, performed by the kubelet. | [27](27/README.md) |
| **Progressive delivery** | the automated canary/blue-green by the metrics (Argo Rollouts, Flagger). | [09](09/README.md) |
| **projected** | a volume that combines several sources (secret/configMap/downwardAPI). | [24](24/README.md) |
| **Prometheus / Grafana** | a collection/a storage of the metrics and a visualization (a real monitoring). | [28](28/README.md) |
| **provisioner** | a CSI driver that creates the real volumes. | [26](26/README.md) |
| **PTR** | a reverse DNS record: an IP → a name. | [0.2](00-2-dns/README.md) |
| **QoS class** | Guaranteed / Burstable / BestEffort; an order of an eviction on a shortage of the memory. | [14](14/README.md) |
| **Quorum** | a majority of the etcd members, needed for a work (HA). | [37](37/README.md) |
| **raft** | the protocol of a consensus the etcd members agree by. | [02](02/README.md) |
| **RBAC** | a role-based access control (chapter 38). | [21](21/README.md), [38](38/README.md) |
| **readiness** | whether it is ready for the traffic; a failure → a removal from the Endpoints (without a restart). | [27](27/README.md) |
| **readOnlyRootFilesystem** | a root FS is read-only. | [20](20/README.md) |
| **ReadWriteMany** | a read-write from many nodes (a network FS is needed). | [25](25/README.md) |
| **ReadWriteOnce** | a read-write from one node (not from one pod!). | [25](25/README.md) |
| **reclaimPolicy** | a fate of a PV after a deletion of a PVC: Retain / Delete. | [25](25/README.md) |
| **Reconciliation loop** | a continuous cycle in which the controllers remove a difference between the desired and the real state. | [01](01/README.md) |
| **Recreate** | a strategy "to kill everything, then to create"; with a downtime. | [08](08/README.md) |
| **Registry** | a store of the images (Docker Hub by default); a private one requires an imagePullSecret. | [0.4](00-4-containers/README.md), [23](23/README.md) |
| **Release** | an installed instance of a chart (with a history of the revisions). | [42](42/README.md) |
| **replicas** | a desired number of the pods. | [05](05/README.md) |
| **ReplicaSet** | a controller that maintains a given number of the pods by a selector. | [05](05/README.md) |
| **ReplicationController** | a deprecated predecessor of a ReplicaSet. | [05](05/README.md) |
| **Repository** | a store of the charts. | [42](42/README.md) |
| **requests** | a guaranteed minimum of the resources; it is used at a scheduling. | [14](14/README.md) |
| **required vs preferred** | a strict (a mandatory) against a soft (if possible) rule of a placement of an affinity. | [12](12/README.md) |
| **ResourceQuota** | a total limit of the resources and of the number of the objects per namespace. | [14](14/README.md) |
| **restartPolicy** | a policy of a restart of the containers: Always, OnFailure, Never. | [04](04/README.md) |
| **Return to context** | after a work on a node to continue on the original machine. | [48](48/README.md) |
| **Revision** | a fixed version of the template of a Deployment in the history. | [08](08/README.md) |
| **revisionHistoryLimit** | how many old ReplicaSets to keep for a rollback. | [08](08/README.md) |
| **Role** | the permissions in a single namespace. | [38](38/README.md) |
| **RoleBinding** | a binding of a role to a subject in a namespace. | [38](38/README.md) |
| **roleRef** | which role a binding refers to. | [38](38/README.md) |
| **rollback** | a rollback to a previous revision (`rollout undo`). | [08](08/README.md) |
| **RollingUpdate** | a strategy of a gradual replacement of the pods without a downtime (by default). | [08](08/README.md) |
| **rollout** | a process of a rollout of a new version of a Deployment. | [08](08/README.md) |
| **Routed network** | a network that knows the routes to the pods directly (BGP). | [30](30/README.md) |
| **rules** | what is allowed and over what. | [38](38/README.md) |
| **runAsNonRoot** | a prohibition of a run as root. | [20](20/README.md) |
| **runAsUser / runAsGroup** | the UID/the GID of the process of a container. | [20](20/README.md) |
| **runc** | a low-level tool of a start of the containers through the kernel. | [0.4](00-4-containers/README.md), [40](40/README.md) |
| **Scheduler Profiles** | several configurations within a single scheduler. | [15](15/README.md) |
| **schedulerName** | which scheduler places a pod. | [15](15/README.md) |
| **scope** | a scope of a CRD: in a namespace or for the whole cluster. | [41](41/README.md) |
| **search domains** | the suffixes in resolv.conf that complete the short names. | [0.2](00-2-dns/README.md), [31](31/README.md) |
| **Secret** | an object for the sensitive data (the passwords, the tokens, the keys, the certificates). | [19](19/README.md) |
| **secretKeyRef / secretRef** | a connection of a key/of a whole Secret into env. | [19](19/README.md) |
| **SecurityContext** | the security settings on the level of a pod/a container. | [20](20/README.md) |
| **selector** | how a controller finds "its own" pods (by the labels). | [05](05/README.md), [06](06/README.md) |
| **Selector switch** | a change of the `selector` of a service for an instant move of the traffic to another version (a basis of a blue/green). | [09](09/README.md) |
| **SSH** | a secure login to a node over a network; `exit` - to go back. | [0.5](00-5-linux/README.md) |
| **sudo** | to run a command as root; `sudo -i` - to become root for a session. | [0.5](00-5-linux/README.md) |
| **systemd / systemctl** | a system of a management of the services (the kubelet, containerd) and the command to it. | [0.5](00-5-linux/README.md), [45](45/README.md) |
| **Service** | a stable address and a balancing in front of a group of the pods selected by a selector. | [07](07/README.md) |
| **ServiceAccount** | an identity of a pod/a process for an access to the API. | [21](21/README.md) |
| **shell form** | a command through `sh -c` (it is needed for the variables, the pipes). | [17](17/README.md) |
| **Sidecar** | an auxiliary container in the same pod (chapter 22). | [04](04/README.md), [22](22/README.md) |
| **snapshot restore** | a deployment of a snapshot into a new data directory. | [37](37/README.md) |
| **snapshot save** | a creation of a backup of etcd into a file. | [37](37/README.md) |
| **stabilization window** | a window of a wait before a reduction of the replicas. | [16](16/README.md) |
| **Stable identity** | the predictable names of the pods (`db-0`, `db-1`) that survive a recreation. | [11](11/README.md) |
| **startup** | whether a start is finished; it blocks the other probes until it passes. | [27](27/README.md) |
| **Stateful** | an application with a state; an identity and its own storage are needed. | [05](05/README.md) |
| **StatefulSet** | a controller for the applications with a state: the stable names, an order, its own storage per pod. | [11](11/README.md) |
| **Stateless** | an application without a unique state; the pods are interchangeable. | [05](05/README.md) |
| **Static Pod** | a pod raised by the kubelet directly from a manifest in `/etc/kubernetes/manifests/`, without a participation of the scheduler. | [02](02/README.md), [15](15/README.md), [45](45/README.md) |
| **staticPodPath** | a folder the kubelet watches (usually `/etc/kubernetes/manifests/`). | [15](15/README.md) |
| **stdout/stderr** | the standard output of a container, where Kubernetes takes the logs from. | [28](28/README.md) |
| **StorageClass** | a template of a creation of the volumes: a provisioner, the parameters, a reclaim policy. | [26](26/README.md) |
| **stringData** | a field for the values in a plain text (they are encoded automatically). | [19](19/README.md) |
| **subjects** | to whom the rights are given: User, Group, ServiceAccount. | [38](38/README.md) |
| **suspend** | a temporary suspension of a CronJob. | [10](10/README.md) |
| **swapoff** | a disabling of the swap (a requirement of Kubernetes). | [35](35/README.md) |
| **Taint** | a restriction mark on a node (`key=value:effect`) that repels the pods. | [13](13/README.md) |
| **Task weight** | a share of the points, a hint of a priority. | [47](47/README.md) |
| **TCPRoute / gRPCRoute / TLSRoute** | a routing for the other protocols. | [33](33/README.md) |
| **template** | a template of a pod the replicas are created by. | [05](05/README.md) |
| **Three pillars of observability** | the logs, the metrics, the traces. | [28](28/README.md) |
| **Three-pass strategy** | a strategy of the time: the easy ones → the hard ones → a check. | [47](47/README.md), [48](48/README.md) |
| **throttling** | a slowing down of a container on an excess of the CPU limit. | [14](14/README.md) |
| **TLS** | the protocol of an encryption and an authentication of the traffic (the letter "S" in HTTPS). | [0.3](00-3-tls/README.md) |
| **TLS termination** | a decryption of HTTPS on an Ingress; a certificate from a Secret of the type tls. | [0.3](00-3-tls/README.md), [32](32/README.md) |
| **Toleration** | a "pass" of a pod that allows it to be on a node with a taint. | [13](13/README.md) |
| **tolerationSeconds** | how long a pod stays on a node with NoExecute before an eviction. | [13](13/README.md) |
| **topologyKey** | a label of a node that defines a "zone of a neighborhood" (hostname, zone). | [12](12/README.md) |
| **topologySpreadConstraints** | an even distribution of the pods over a topology (`maxSkew`). | [12](12/README.md) |
| **troubleshooting domain** | 30% of CKA, the most weighty one; to fix the applications/a cluster/a network. | [48](48/README.md) |
| **TTL** | a time of a life of a DNS record in a cache (in the seconds). | [0.2](00-2-dns/README.md) |
| **ttlSecondsAfterFinished** | an automatic deletion of a finished Job after a given time. | [10](10/README.md) |
| **type** | a purpose of a Secret (Opaque, tls, dockerconfigjson and others). | [19](19/README.md) |
| **uncordon** | to return a node into the pool of a scheduling. | [36](36/README.md) |
| **updateStrategy** | a strategy of an update of a DaemonSet/a StatefulSet (rolling). | [11](11/README.md) |
| **valueFrom** | a filling of a variable from a source (a field of a pod, the resources, a CM/a Secret). | [17](17/README.md) |
| **Values** | the parameters for a substitution into the templates. | [42](42/README.md) |
| **VAR** | a reference to a previously declared variable inside a manifest. | [17](17/README.md) |
| **veth pair** | two connected virtual interfaces - a "cable" between the network namespace of a pod and of a node. | [0.7](00-7-netns/README.md), [30](30/README.md) |
| **Version skew** | an allowed difference of the versions of the components; the kubelet is not newer than the apiserver. | [36](36/README.md) |
| **Volume** | a storage declared on the level of a pod and mounted into the containers. | [24](24/README.md) |
| **Volume mount** | the keys of a ConfigMap become the files in a directory. | [18](18/README.md) |
| **volumeBindingMode** | when to create/to bind a volume (Immediate / WaitForFirstConsumer). | [26](26/README.md) |
| **volumeClaimTemplates** | a template of a StatefulSet that creates a PVC for every pod. | [11](11/README.md), [26](26/README.md) |
| **volumes / volumeMounts** | a declaration of a volume / its mount into a container. | [24](24/README.md) |
| **VPA** | changes the requests/limits of the pods. | [16](16/README.md) |
| **webhook** | an external check/modification of the objects (Kyverno, OPA, a mesh). | [21](21/README.md) |
| **YAML** | a human-readable format of the manifests; a nesting is set by the indents (only the spaces). | [0.6](00-6-yaml/README.md), [03](03/README.md) |
| **whenUnsatisfiable** | a mode of a topologySpread: `DoNotSchedule` (strictly, → Pending) or `ScheduleAnyway` (softly, with a tolerance of a skew). | [12](12/README.md) |
| **Worker node** | a working node the pods of the applications are run on. | [02](02/README.md) |
| **Ingress annotations** | the settings specific to a controller (rewrite, timeout and others). | [32](32/README.md) |
| **Asymmetric cryptography** | a pair of the connected keys: a private one (a secret) and a public one (an open one). | [0.3](00-3-tls/README.md) |
| **Subnet mask** | which part of an address belongs to a network, and which one - to a host. | [0.1](00-1-net/README.md) |
| **Octet** | one of the four numbers of an IPv4 address (8 bits, 0-255). | [0.1](00-1-net/README.md) |
| **Port** | a number 0-65535 that points to an application on a device; a pair "an IP + a port" = a service. | [0.1](00-1-net/README.md) |
| **Private / public key** | a secret key of an owner (it is not transferred) / a public key (it is given to everyone). | [0.3](00-3-tls/README.md) |
| **Resolver** | a component that performs the DNS queries for an application (in a cluster - CoreDNS). | [0.2](00-2-dns/README.md), [31](31/README.md) |
| **Certificate** | a public key + the data of an owner + a signature of a CA. | [0.3](00-3-tls/README.md), [39](39/README.md) |
| **Migration Ingress → Gateway API** | a split of a single Ingress into a Gateway (an entry) + an HTTPRoute (the rules). | [33](33/README.md) |
| **Native sidecar** | an init container with `restartPolicy: Always`. | [22](22/README.md) |
| **etcd certificates** | the CA/cert/key in `/etc/kubernetes/pki/etcd/`. | [37](37/README.md) |
| **Network model of Kubernetes** | the requirements to a network: an own IP for a pod, a connection without NAT, a flat network. | [30](30/README.md) |
| **Statuses of PV/PVC** | Available, Bound, Pending, Released. | [25](25/README.md) |
| **Tag / digest** | a version of an image / an immutable hash of the content. | [23](23/README.md) |

## Parameters, flags and codes

The flags of the commands, the helper aliases and the codes of the responses - they are
moved separately from the main alphabetical list of the terms.

| Parameter / code | Description | Chapters |
|----------------|----------|-------|
| **$do / $now** | the helpers `--dry-run=client -o yaml` / a fast deletion. | [47](47/README.md) |
| **--control-plane-endpoint** | a common address of the control plane (for HA). | [35](35/README.md) |
| **--data-dir** | the data directory of etcd (at a restore - a new one). | [37](37/README.md) |
| **--from-file / --from-env-file** | a whole file into a single key / line by line into the keys. | [18](18/README.md) |
| **--ignore-daemonsets** | at a drain not to touch the pods of a DaemonSet (they are tied to a node). | [36](36/README.md) |
| **--pod-network-cidr** | the range of the addresses of the pods (it is agreed with a CNI). | [35](35/README.md) |
| **--previous** | the logs of a previous (a crashed) container. | [28](28/README.md) |
| **--set / -f** | an override of the values in the CLI / by a file. | [42](42/README.md) |
| **401 vs 403** | not authenticated (a certificate) vs no rights (RBAC). | [39](39/README.md) |
| **`--dry-run=client -o yaml`** | to generate a YAML, creating nothing. | [03](03/README.md) |
