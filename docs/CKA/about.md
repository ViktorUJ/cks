---
id: about_cka
title: About
description: About CKA section
slug: /CKA/about
sidebar_position: 2
custom_edit_url: null
---

This section contains labs and mock exams to train your CKA certifications.

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

- [01 - Fix a problem with kube-api](./Labs/01.md)
- [02 - Create HPA based on the CPU load](./Labs/02.md)
- [03 - Operations with Nginx ingress. Routing by header](./Labs/03.md)
- [04 - Nginx ingress. Canary deployment](./Labs/04.md)
- [05 - PriorityClass](./Labs/05.md)

Exams:

- [01](./Mock%20exams/01.md)
- [02](./Mock%20exams/02.md)

