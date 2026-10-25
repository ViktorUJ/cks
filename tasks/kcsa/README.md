[Русская версия](README_RU.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: Kubernetes and Cloud Native Security Associate - Training Materials

Complete preparation for the **Kubernetes and Cloud Native Security Associate (KCSA)** certification: a self-study course and full mock exams - all in one place.

KCSA is an associate-level, pre-professional, conceptual CNCF and Linux Foundation certification in cloud native and Kubernetes security. It fits into the KCNA (optional) → KCSA → CKA → CKS learning path: KCSA explains fundamentals and threat models, CKA provides the hands-on foundation required for CKS, and CKS develops practical security skills. There are no formal prerequisites; a basic understanding of what a `Pod`, `Deployment`, `Service`, and `kubectl` are is enough.

## What's inside

| Part | Path | What it is |
|------|------|-----------|
| **Course** | [`course/`](course/README.md) | 20-chapter self-study course covering all 6 official KCSA domains |
| **Mock exams** | [`mock/`](mock/README.md) | 2 full 60-question mock exams in MCQ format |

KCSA practice consists of multiple-choice questions and mock exams, not hands-on labs. Recommended path: read the course chapters in order, then take both mock exams under exam-like time pressure.

## The course

The course ([`course/README.md`](course/README.md)) has 20 chapters, each published in 8 languages: English (`README.md`), Russian (`ru.md`, canonical source), Spanish (`es.md`), French (`fr.md`), German (`de.md`), Georgian (`ge.md`), Traditional Chinese (`tw.md`), and Japanese (`jp.md`). Chapters are grouped by the official KCSA domains:

| Domain | Weight |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

Terms are collected in the [glossary](course/GLOSSARY.md). Chapters 1-2 introduce the exam and cloud native security; chapter 20 covers final exam strategy, time management, and a checklist.

## Mock exams

Two full mock exams ([`mock/`](mock/README.md)) simulate the real KCSA experience:

- **Mock 01** ([`mock/01`](mock/01/README.md)) - 60 questions distributed across the domains.
- **Mock 02** ([`mock/02`](mock/02/README.md)) - an independent set of 60 questions, same distribution.

Take each mock in a closed-book, 90-minute session: no documentation, search, notes, tools, or external websites. As of the last verification, the LF Multiple Choice FAQ lists a passing score of 75% or above; confirm current KCSA registration requirements with the Linux Foundation before you register.

## Exam format and course version

KCSA is a multiple-choice exam: 60 questions, 90 minutes, 75% to pass, no hands-on tasks (verify current parameters with the Linux Foundation before registering, as they may change). Course examples target Kubernetes `v1.36`. Current weights, sources, and curriculum drift are recorded in the [version policy](VERSION_POLICY.md).

## Further reading

- [Official Kubernetes documentation: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- The CKS course is the next step for deeper practical hardening and investigation.
