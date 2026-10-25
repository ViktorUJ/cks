# KCSA course version and weight policy

Last verified: **2026-09-02**.

KCSA's version tracks are independent and must not be auto-aligned with each other:

| Track | Current value | Source of truth |
|---|---|---|
| Course examples | Kubernetes `v1.36` | Fixed training baseline version; its correctness is verified separately from the CKS exam version |
| KCSA exam | Conceptual, version-light | LF "Domains & Competencies" |
| KCSA curriculum (LIVE) | 6 domains, weights `14/22/22/16/16/10` | LF "Domains & Competencies" |

> **Version maintenance.** The latest verified upstream Kubernetes minor version is `v1.37`. Course examples currently remain on `v1.36` as the fixed training baseline. Do not automatically call this baseline "the CKS version": the CKS version is a separate track and must be checked against the current Linux Foundation page at every course release. As of the 2026-09-02 verification, LF lists CKS on Kubernetes `v1.35`.

KCSA tests cloud native and Kubernetes security concepts, so the Kubernetes version affects the correctness of illustrative examples but does not set a separate exam-environment version. Before releasing the course, re-check the current LF page separately and record the verification date.

## Official curriculum PDF provenance

The 2026-09-01 verification used the official `KCSA Curriculum.pdf` file: size `227288` bytes, SHA-256 `2855eb7db729ab9ad0136b87d002560f82297e66e811026159df946227d5114a`.

At every subsequent review, re-download this exact curriculum PDF from the official LF source, record the verification date, file name, size, and SHA-256, then cross-check its domains and weights against the LF LIVE page. Change the weights `14/22/22/16/16/10` only if the LF LIVE page has confirmedly changed.

## Current exam curriculum

| Domain | Weight |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

The weights `14/22/22/16/16/10` must not be changed without a corresponding change on the LF page. Version drift or secondary sources alone are not grounds for changing the course structure.

## Drift with `cncf/curriculum`

The `cncf/curriculum` master branch records a different six-domain edition:

| CNCF revision domain | Weight |
|---|---:|
| Cloud Native Fundamentals | 16% |
| Kubernetes Security Fundamentals | 20% |
| Container Security Fundamentals | 20% |
| Secure Software Supply Chain | 16% |
| Monitoring, Logging, and Runtime Security | 12% |
| General Security Knowledge | 16% |

The course structure and weights use the LF LIVE curriculum. Content is designed as a superset of the LF LIVE curriculum and the `cncf/curriculum` revision, so the course stays useful if the curriculum transitions. At the next review, compare both tracks, update the verification date, and change the structure only after a confirmed LF change.

## References

- [Linux Foundation KCSA - Domains & Competencies](https://training.linuxfoundation.org/certification/kubernetes-and-cloud-native-security-associate-kcsa/)
- [CNCF curriculum repository](https://github.com/cncf/curriculum)
