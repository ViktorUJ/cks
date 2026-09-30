[Русская версия](README_RU.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: A Practical Self-Study Guide to Cloud Native and Kubernetes Security

KCSA (Kubernetes and Cloud Native Security Associate) is an associate-level, pre-professional, conceptual CNCF and Linux Foundation certification in cloud native and Kubernetes security. The course fits into the KCNA (optional) → KCSA → CKA → CKS learning path: KCSA explains fundamentals and threat models, CKA provides the hands-on foundation required for CKS, and CKS develops practical security skills. There are no formal prerequisites; a basic understanding of what a `Pod`, `Deployment`, `Service`, and `kubectl` are is enough.

> **About links to CKA and CKS.** The standalone KCSA archive does not include the CKA and CKS directories. Therefore, in a standalone distribution, links within KCSA itself remain clickable, while cross-course references to CKA/CKS are published as plain text without relative URLs. In a monorepo build, they can be generated as working links to adjacent courses or as stable absolute URLs.

> **Exam format and example version.** KCSA is a multiple choice exam. Under Linux Foundation rules verified on September 1, 2026, the standard MCQ (multiple choice question) exam contains 60 questions, lasts 90 minutes, and requires 75% to pass; there are no hands-on tasks. Be sure to check the current LF requirements again before registering, as these parameters may change. Course examples target Kubernetes `v1.36`. Current weights, sources, and curriculum drift are recorded in the [version policy](../VERSION_POLICY.md).

## How the course is organized

Each topic is a numbered directory with the canonical Russian source file `ru.md`. Translations are also published for each chapter: English `README.md`, Español `es.md`, Français `fr.md`, Deutsch `de.md`, ქართული `ge.md`, 繁體中文 `tw.md`, and 日本語 `jp.md`. Chapters are grouped by KCSA domains and color-coded:

- 🟦 Overview of Cloud Native Security - 14%
- 🟥 Kubernetes Cluster Component Security - 22%
- 🟩 Kubernetes Security Fundamentals - 22%
- 🟪 Kubernetes Threat Model - 16%
- 🟨 Platform Security - 16%
- 🟫 Compliance and Security Frameworks - 10%
- ⬜ introduction, fundamentals, and exam preparation

KCSA practice consists of multiple-choice questions and mock exams, not labs. This file provides a unified preparation path and exam navigation. Terms are collected in the [glossary](GLOSSARY.md).

## Official exam curriculum

| Domain | Weight |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

## Contents

### Part 0. Introduction and fundamentals ⬜

1. [Introduction: the KCSA exam, format, place in the certification ladder, versions](01/README.md)
2. [Cloud native and why security matters](02/README.md)

### Part 1. Overview of Cloud Native Security - 14% 🟦

3. [The 4Cs of cloud security: Cloud, Cluster, Container, Code](03/README.md)
4. [Cloud provider and infrastructure security](04/README.md)
5. [Security controls, frameworks, and isolation techniques](05/README.md)
6. [Artifact, image, and code security](06/README.md)

### Part 2. Kubernetes Cluster Component Security - 22% 🟥

7. [Control plane security: API Server, Controller Manager, Scheduler, Etcd](07/README.md)
8. [Node security: Kubelet, Container Runtime, KubeProxy](08/README.md)
9. [Pod, container networking, storage, and client security](09/README.md)

### Part 3. Kubernetes Security Fundamentals - 22% 🟩

10. [Authentication and authorization](10/README.md)
11. [Pod Security Standards and Pod Security Admission](11/README.md)
12. [Secrets](12/README.md)
13. [Network Policy, isolation, and segmentation](13/README.md)
14. [Audit Logging](14/README.md)

### Part 4. Kubernetes Threat Model - 16% 🟪

15. [Trust boundaries, data flows, and threat modeling](15/README.md)
16. [Kubernetes threat categories](16/README.md)

### Part 5. Platform Security - 16% 🟨

17. [Supply chain, image registries, and admission control](17/README.md)
18. [Observability, PKI, connectivity, and service mesh](18/README.md)

### Part 6. Compliance and Security Frameworks - 10% 🟫

19. [Compliance and security frameworks](19/README.md)

### Part 7. Exam preparation ⬜

20. [The KCSA exam: strategy, time management, checklist](20/README.md)

## Practice

- 📝 [KCSA mock exams](../mock) - English Mock 01 and Mock 02 are available in MCQ format for independent practice. Questions are distributed according to domain weights; terragrunt/bats labs are not created for KCSA.

Start with chapters 01-02, then work through the domains in order. The final strategy and checklist are collected in [chapter 20](20/README.md).

## Further reading

- [Official Kubernetes documentation: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- The CKS course is the next step for deeper practical hardening and investigation.
