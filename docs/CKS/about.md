---
id: about_cks
title: About
description: About CKS section
slug: /CKS/about
sidebar_position: 1
custom_edit_url: null
---

This section contains labs and mock exams to train your CKS certifications.

- The platform uses **aws** to create following resources:  **vpc**, **subnets**, **security groups**, **ec2** (spot/on-demand), **s3**
- after you launch the scenarios the platform will create all the necessary resources and give access to k8s clusters.
- to create clusters the platform uses **kubeadm**
- you can easily add your own scenario using the already existing terraform module
- platform supports the following versions:

```text
k8s version  : [ 1.21 , 1.29 ]   https://kubernetes.io/releases/
Rintime :
    docker                   [1.21 , 1.23]
    cri-o                    [1.21 , 1.29]
    containerd               [1.21 , 1.30]
    containerd_gvizor        [1.21 , 1.30]
OS for nodes  :
   ubuntu  :  20.04 LTS  ,  22.04 LTS   # cks default  20.04 LTS
CNI :  calico
```

Labs:

- [01 - Kubectl contexts](./Labs/01.md)
- [02 - Falco, SysDig](./Labs/02.md)
- [03 - Access kube-api via nodePort](./Labs/03.md)
- [04 - Pod Security Standart](./Labs/04.md)
- [05 - CIS Benchmark](./Labs/05.md)
- [08 - Open Policy Agent](./Labs/08.md)
- [09 - AppArmor](./Labs/09.md)
- [10 - Container Runtime Sandbox gVisor](./Labs/10.md)
- [11 - Secrets in ETCD](./Labs/11.md)
- [17 - Enable audit log](./Labs/17.md)
- [19 - Fix Dockerfile](./Labs/19.md)
- [20 - Update Kubernetes cluster](./Labs/20.md)
- [21 - Image vulnerability scanning](./Labs/21.md)
- [22 - Network policy](./Labs/22.md)
- [23 - Set TLS version and allowed ciphers for etcd, kube-api](./Labs/23.md)
- [24 - Encrypt secrets in ETCD](./Labs/24.md)
- [25 - Image policy webhook](./Labs/25.md)

Exams:

- [01](./Mock%20exams/01.md)
