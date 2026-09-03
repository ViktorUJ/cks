# KCSA Release QA Report

**Scope:** current standalone KCSA release.

**Question-bank scope:** 93 chapter self-checks + Mock01 60 + Mock02 60. The separate Root bank is intentionally outside the current release scope by explicit user decision; its absence is not a defect.

**Release decision:** HOLD until the independent semantic, technical, domain-placement, answer-shape, currentness, link, and Markdown checks against the live files are complete. This embedded report is a regression changelog, not release evidence.

## Confirmed fixes (most recent independent fixes-only audit round)

### P1 — Threat Modelling Frameworks domain mapping

- **`course/15/ru.md`**: added an explicit KCSA domain-mapping note after the §15.3 heading stating that Linux Foundation places Threat Modelling Frameworks (STRIDE, MITRE ATT&CK for Containers, kill chain) under **Compliance and Security Frameworks**, not Kubernetes Threat Model; the frameworks are used here only as cross-domain analytical context. Updated the §15.8 Exam Essentials bullet to match. Added `#### Cross-domain повторение: Compliance and Security Frameworks` immediately before self-check Q3 and `#### Возврат к Kubernetes Threat Model` immediately before Q5, so the STRIDE/ATT&CK self-check questions are explicitly marked as cross-domain rather than implied Threat Model competencies. Q3–Q5 content and keys unchanged.
- **`course/20/ru.md`**: corrected the §20.4 domain-review table. The `Kubernetes Threat Model - 16%` row no longer lists "STRIDE-вопросы"; it now lists only genuine Threat Model competencies (trust boundaries/data flows, persistence, DoS, malicious code/compromised applications, attacker on the network, access to sensitive data, privilege escalation). The `Compliance and Security Frameworks - 10%` row now explicitly names threat-modelling frameworks (e.g., STRIDE) as part of that domain instead of only listing compliance-standard names.

### P2 — answer-shape leakage

- **`course/07/ru.md` self-check Q5** replaced: the correct option no longer bundles a complete, uniquely detailed security rule against three short categorical distractors; all four options are now comparable length/structure. Key position c preserved.
- **Mock02 Q13** replaced: the correct option no longer stands out as the only long, heavily qualified statement; distractors were rewritten to comparable length and specificity. Key position D preserved.
- **Mock02 Q22** replaced: the correct option no longer spells out the complete `bind` semantics at much greater length than the distractors; option lengths rebalanced. Key position B preserved.

### Prior rounds

- Theory traceability/currentness fixes for etcd PKI trust separation and RBAC `bind`/`escalate`/`impersonate`/`ConstrainedImpersonation` semantics (`course/07`, `course/10`).
- Mock01↔Mock02 semantic-duplicate removals across signature verification, etcd exposure, NetworkPolicy DNS/selector composition, and service-mesh mTLS competencies.
- Domain-placement corrections for Mock01/Mock02 CNI, Code-layer, Client Security, and admission-webhook competencies.
- Root question bank removed from release scope by explicit user decision; this is documented, not treated as an open defect.

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
