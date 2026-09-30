# CKS Course Maintainers

This document describes the maintainership responsibilities and technical review principles for the CKS course.

## Lead Maintainer

### Viktar Mikalayeu

- CNCF Kubestronaut
- course architecture and long-term development;
- alignment with the current CKS competencies;
- Kubernetes and security-tool currentness;
- technical review of theory content;
- technical review of labs and mock exams;
- release quality and consistency.

Official CNCF Kubestronaut program and public list:

https://www.cncf.io/training/kubestronaut/

CNCF Kubestronaut list: [Viktar Mikalayeu](https://www.cncf.io/training/kubestronaut/?_sft_lf-country=ge&p=viktar-mikalayeu&_sf_s=viktar+mikalayeu).

## Contributors

The course is developed with contributions from the community.

Contributions may include:

- technical corrections;
- review of Kubernetes, Linux, and security mechanisms;
- validation of commands, YAML, and shell examples;
- labs and automated acceptance checks;
- Kubernetes and security-tool currentness updates;
- mock exams;
- editorial improvements;
- translations;
- feedback from learners preparing for or taking the CKS exam.

Contribution history is preserved in the project's Git history, commits, and Pull Requests.

## Technical Review Principles

For security-sensitive and version-sensitive claims, primary sources are preferred whenever possible.

Primary references include:

- Kubernetes documentation;
- Kubernetes release notes and enhancement documentation;
- Linux Foundation / CNCF materials related to CKS;
- official Falco documentation;
- official Cilium documentation;
- official Istio documentation;
- official Kyverno documentation;
- official Gatekeeper documentation;
- upstream release notes;
- upstream security advisories;
- upstream source code when documentation is insufficient.

The course follows the principle:

**configuration != enforcement**

Where practical, validation goes beyond desired configuration and checks:

```text
desired state
-> effective state
-> positive test
-> negative test
-> observable evidence
```

## Currentness

The CKS exam version, the course training baseline, and the current upstream Kubernetes release are tracked independently.

The machine-readable CKS snapshot is maintained in:

```text
metadata/cks-exam-snapshot.yaml
```

Security-tool versions and compatibility are tracked in:

```text
metadata/tool-compatibility.yaml
```

The version update policy is documented in:

```text
VERSION_POLICY.md
```

## Independence

This CKS course is an independent, community-maintained open-source project.

The **CNCF Kubestronaut** status refers to the professional qualifications of the lead maintainer, **Viktar Mikalayeu**.

It does **not** mean that:

- CNCF officially endorses this course;
- the Linux Foundation officially endorses this course;
- this course is an official CNCF training product;
- this course is an official Linux Foundation training product;
- CNCF or the Linux Foundation reviews, certifies, or guarantees the course content.
