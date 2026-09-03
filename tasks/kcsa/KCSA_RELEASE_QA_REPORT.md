# KCSA Release QA Report

**Scope:** current standalone KCSA release.

**Question-bank scope:** 93 chapter self-checks + Mock01 60 + Mock02 60. The separate Root bank is intentionally outside the current release scope by explicit user decision; its absence is not a defect.

**Release decision:** HOLD until the independent semantic, technical, domain-placement, answer-shape, currentness, link, and Markdown checks against the live files are complete. This embedded report is a regression changelog, not release evidence.

## Confirmed fixes (most recent independent fixes-only audit round)

### P2 — PSS vs. Pod Security Admission terminology precision

- **`course/05/ru.md`** §05.6: corrected "PSS или policy engine сначала включают в `audit` или `warn`" — Pod Security Standards (PSS) define the `privileged`/`baseline`/`restricted` levels; the `enforce`/`audit`/`warn` modes belong to Pod Security Admission (PSA), which applies a chosen PSS level. The revised wording attributes the modes to PSA applying a PSS profile, and separately notes third-party policy engines use their own non-blocking mode where supported. Matches the already-correct PSS/PSA distinction in `course/05/ru.md` §05.x and elsewhere in the course.

### P2 — SOC 2 Type I vs. Type II differentiation

- **`course/19/ru.md`** §19.1 frameworks table: the SOC 2 row stated unconditionally that controls must be shown to be "designed and operating over the stated period" — this is the Type II characteristic. SOC 2 Type I assesses only the suitability of control design as of a point in time; Type II additionally assesses operating effectiveness over a period. The row now distinguishes both report types explicitly.

### Prior rounds

- Cloud role vs. credential lifetime precision: `course/03/ru.md` §03.2 corrected to attribute short lifetime/rotation to issued credentials/tokens/role sessions rather than the durable cloud role itself, matching `course/04/ru.md`.
- Attack-tree preventive-control accuracy: `course/15/ru.md` §15.4 "Shell searches for credentials" row replaced `PSS`/`seccomp`/capabilities with the actually preventive controls (no unnecessary `Secret` mounts, `automountServiceAccountToken: false`, least-privilege workload identity/RBAC).
- RBAC privilege-escalation-prevention technical accuracy: Mock02 Q43 corrected so mere `create` on `ClusterRoleBinding` is not treated as sufficient for privilege escalation without `bind`/`escalate` or already-held permissions; `KCSA_THEORY_IMPROVEMENT_REPORT.md` §3 synchronized.

- CNCF TAG-Security naming currentness: `course/02/ru.md` §02.1 replaced present-tense claim naming `TAG-Security` as the active CNCF security working group with `TAG Security and Compliance` (current active group; `TAG-Security` archived in CNCF TOC structure).
- NGINX version-pin currentness: `course/09/ru.md`/`course/11/ru.md` (`nginxinc/nginx-unprivileged:1.30.4-alpine-slim`) and `course/10/ru.md` (`nginx:1.30.4`) replaced `1.27.x`, which fell inside the vulnerable range of multiple upstream NGINX security advisories.
- `NetworkPolicy` two-sided enforcement precision: `course/13/ru.md` §13.1 additive-rules explanation now scopes additivity to one Pod/direction and states the two-sided source-egress/destination-ingress check explicitly.
- Answer-shape leakage rebalancing (`course/13` Вопрос 1, `course/14` Q1, `course/16` Q2, Mock02 Q9) — qualitative leakage confirmed by inspection even though strict double quantitative threshold was not simultaneously met on independent re-verification.
- Mock01 Q31 internal semantic-duplicate replacement (two-sided connection rule).
- CNCF Graduated overclaim removed from `course/02/ru.md` (Falco/OPA/Kyverno/Cilium retained as verified Graduated examples).
- Prior answer-shape rebalancing: `course/01,02,06,07,14,20` self-checks; Mock01 Q2,Q3,Q5,Q7,Q10,Q15,Q22,Q34,Q51; Mock02 Q6,Q14,Q35,Q38,Q42,Q55.
- Mock02 Q25 domain-placement correction (Admission Control → Authorization within Security Fundamentals).
- `course/16`/`course/19` self-check answer-shape rebalancing.
- Threat Modelling Frameworks domain-mapping corrections in `course/15` and `course/20`.
- Theory traceability/currentness fixes for etcd PKI trust separation and RBAC `bind`/`escalate`/`impersonate`/`ConstrainedImpersonation` semantics (`course/07`, `course/10`).
- Mock01↔Mock02 semantic-duplicate removals across signature verification, etcd exposure, NetworkPolicy DNS/selector composition, and service-mesh mTLS competencies.
- Domain-placement corrections for Mock01/Mock02 CNI, Code-layer, Client Security, and admission-webhook competencies.
- Root question bank removed from release scope by explicit user decision; this is documented, not treated as an open defect.
- LF exam-format currentness (60 questions / 90 minutes / 75% passing score, English-only KCSA language) verified first-party against `docs.linuxfoundation.org` and applied to `course/01`, `course/20`, `course/README_RU.md`.
- `course/06/ru.md` `scratch` example: removed DNS from the list of things to add manually to the image (kubelet configures Pod DNS via `/etc/resolv.conf`, not an application runtime dependency).
- `course/06/ru.md` multi-stage build example: `golang:1.25` replaced with `golang:1.27.1` (Go 1.25 fell outside the two-newest-major-release support window per the official Go release policy).

### Mock01 и Mock02

## Required regression and packaging evidence

Before release, verify all of the following against the actual standalone archive and live tree:

- Mock01/Mock02 each have exactly A/B/C/D choices and one valid key per question;
- counts (Mock01 60, Mock02 60, chapter self-checks 93, total 213) and key distributions (each mock A15/B15/C15/D15) remain structurally valid;
- both mocks contain all six domain headings in the correct order with no gaps;
- self-check option lines use the uniform `   - a.`/`b.`/`c.`/`d.` format;
- no file references a Root question bank as part of the current release scope;
- all clickable Markdown links inside the standalone package resolve inside that package or use stable absolute URLs; no relative sibling CKA/CKS links exist;
- Markdown fences and `<details>` blocks are balanced;
- semantic duplicate review is performed for Mock01↔Mock01, Mock02↔Mock02 and Mock01↔Mock02; exact normalized-stem equality is supplemental only;
- every mock question is classified against the current LIVE Linux Foundation KCSA domain matrix;
- package helpers are absent, `unzip -t` passes, SHA-256 is recorded externally, and archive/live file lists are identical.

## Release decision

The next package may be produced only after the stated regression and packaging checks pass. This fixes-only round does not close the ongoing independent audit.

**HOLD — pending independent full audit.**
