# KCSA Release QA Report

**Scope:** current standalone KCSA release.

**Question-bank scope:** 93 chapter self-checks + Mock01 60 + Mock02 60. The separate Root bank is intentionally outside the current release scope by explicit user decision; its absence is not a defect.

**Release decision:** HOLD until the independent semantic, technical, domain-placement, answer-shape, currentness, link, and Markdown checks against the live files are complete. This embedded report is a regression changelog, not release evidence.

## Confirmed fixes (most recent independent fixes-only audit round)

### P1 — domain placement and semantic duplicates

- **Mock01 Q20** replaced: no longer duplicates a Kubernetes Security Fundamentals NetworkPolicy-application question inside the Cluster Component Security domain; now tests the CNI plugin's Pod-networking role, a genuine Cluster Component / Container Networking competency. Key position B preserved.
- **Mock02 Q8** replaced: no longer tests Secrets-handling (a Security Fundamentals competency) inside Overview of Cloud Native Security; now tests Workload and Application Code Security, a genuine Overview competency. Key position B preserved.
- **Mock02 Q19** replaced: no longer tests PKI/certificate-rotation evidence (a Platform Security competency) inside Cluster Component Security; now tests Client Security (`kubeconfig` contexts and credential blast radius). Key position D preserved.
- **Mock02 Q47/Q48** deduplicated: Q47 keeps the fail-closed `failurePolicy: Fail` webhook competency; Q48 no longer tests the inverse of the same fact and now tests Hubble/Cilium flow-visibility evidence. Key positions B and A preserved respectively.
- **Mock02 Q29** replaced: no longer restates Mock01 Q24's unnecessary-ServiceAccount-token competency; now tests the sensitivity of the `impersonate` RBAC verb. Key position B preserved.
- **Mock02 Q54** replaced: the prior "admission rejection record" answer was not a concrete taught evidence object and was tautological; now tests Istio `PeerAuthentication` `STRICT` mode as a mTLS boundary that does not by itself authorize callers. Key position C preserved.

### P2 — structure, typos, and answer-shape leakage

- Inserted the missing `## Kubernetes Security Fundamentals - questions 22-34` heading before Mock02 Q22.
- Corrected two typos: `course/01/ru.md` glossary ("ключевы" → "ключевые") and `course/17/ru.md` self-check Q2 stem ("организациионной" → "организационной").
- Rebalanced answer-shape leakage (correct option uniquely longer/more qualified than every distractor) in: `course/03` Q5, `course/06` Q4, `course/09` Q4, `course/10` Q5, `course/12` Q3, `course/13` Q5, `course/15` Q5, Mock01 Q14/Q24/Q26/Q33/Q42, Mock02 Q5/Q10/Q34/Q52/Q60 — all existing key positions preserved.
- Regenerated `KCSA_THEORY_IMPROVEMENT_REPORT.md` Mock01/Mock02 summary so it matches the corrected live questions instead of describing superseded content.
- This report's header was made release-number-neutral so it cannot become stale merely because the ZIP iteration number changes; prior round-specific changelog content has been superseded by this version.

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
