# CKS Course Version and Weight Policy

Last checked: **2026-09-10**.

Three versions are independent and must not be automatically aligned:

| Track | Current value | Source of truth |
|---|---:|---|
| Training labs (core, `labs/101-113`) | Kubernetes `v1.36` (lab `113` is an exception: starts on `v1.35.x`, upgrades to `v1.36.x` - that upgrade is the task's own topic) | `env.hcl` of the core labs, verified tool compatibility |
| CKS exam environment | Kubernetes `v1.35` | LF CKS product page + LF "Important Instructions: CKS" (checked 2026-09-10); LF FAQ confirms the CKA prerequisite but does not publish the environment version |
| CKS curriculum | `CKS Curriculum v1.34` | root-level CKS curriculum PDF in `cncf/curriculum` |

The single training baseline is `labs/101-113`, complemented by the full-exam simulations
in `mock/01-04`. There is no separate lab track.

A version mismatch is not by itself a defect. Before releasing the course, separately:

1. verify the training version across all labs and the compatibility matrix for Cilium,
   Istio, Kyverno, Falco, and kube-bench;
2. verify the exam version against the main CKS page and "Important Instructions: CKS";
   use the LF FAQ for prerequisites and registration conditions, not as a version source.
   If version-publishing official sources disagree, record all values and do not declare
   one of them the agreed source of truth; cross-check the ExamUI immediately before the
   attempt as well;
3. find the current root-level CKS curriculum PDF in `cncf/curriculum`, record its
   filename, size, and SHA-256, then extract the weights from it;
4. verify the LF `Resources Allowed` independently of the curriculum and record the date;
5. update the prose only from primary sources.

## Upstream-to-exam transition window

Upstream latest stable показывает production-current состояние, а версия экзамена меняется
независимо. Когда upstream minor новее minor, указанного на LF CKS product page, exam
snapshot перепроверяют чаще: default threshold для `cks-exam-snapshot.yaml` — 7 дней вместо
обычных 30. Это не основание автоматически обновлять labs: для нового Kubernetes minor
создают отдельный Security Delta, а 🎯 CKS Core меняют только после подтверждения
exam/curriculum relevance. Явный `--max-age-days` сохраняет приоритет над этой policy.

### Domain weight policy

Exam weights are not automatically tied to the Kubernetes version and are not considered
agreed just because they have not changed in a while.

For a release snapshot, two independent signals are recorded separately:

1. weights published on the LF CKS product page;
2. weights from the current root-level CKS curriculum PDF in `cncf/curriculum`.

If the values match, the snapshot is considered consistent, and the current weights
**15 / 15 / 10 / 20 / 20 / 20** remain in effect.

If the values disagree:

- both sets are stored in `metadata/cks-exam-snapshot.yaml` as separate observations;
- the disagreement blocks declaring the weights "consistent" in the course prose, but does
  not block using the course itself;
- the maintainer manually checks the LF product page, the current curriculum PDF, and,
  where possible, the Candidate Handbook/ExamUI before changing the weights in chapter
  text;
- the prose does not declare either set "the truth" until the disagreement is resolved
  through a primary source.

This differs from the previous rule of "only change weights after a PDF newer than v1.34
appears": the CNCF curriculum filename can lag behind the LF product page or vice versa,
so relying on a single channel (the PDF only) could miss a real weight change on the
product page. Both channels are checked and recorded independently.

Links:

- [LF Important Instructions: CKS](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks)
- [LF Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)
- [CNCF curriculum repository](https://github.com/cncf/curriculum)
