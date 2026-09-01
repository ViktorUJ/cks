# KCSA Release QA Report — kcsa13

Regenerated from scratch, not edited from the kcsa12 report, per the standing instruction that a report shown to misdescribe the live archive must be fully regenerated rather than patched.

## Note on file integrity before this round started
Before this round's fixes, `tasks/kcsa/README.MD` (the root bank, 94 questions) was found **missing** from the working tree, even though it was present inside the previously packaged `kcsa12.zip`. It was restored from that archive before any further work, and its content was verified to match what `kcsa12.zip` contained (74755 bytes). This was a filesystem-state issue between sessions, not an intentional edit, and is noted here for transparency.

## Archive
```
File: kcsa13.zip
```
Size, SHA-256, and the `unzip -t` integrity result are emitted with the release output below.

## Structure (recalculated from the live files immediately before writing this report)
```
Chapters: 20
Chapter self-check MCQs: 93
Root bank MCQs: 94
Mock 01: 60
Mock 02: 60
Total MCQs: 307
```

## Answer distribution (recalculated from the live files)
```
Root:        A24 / B23 / C23 / D24   (shifted from a prior A24/B24/C23/D23 because Root Q80's technically-required fix moved its correct answer from B to D — technical correctness took priority over distribution, per the stated release rule)
Mock 01:     A15 / B15 / C15 / D15
Mock 02:     A15 / B15 / C15 / D15
Self-checks: A24 / B23 / C23 / D23
ALL (307):   A78 / B76 / C76 / D77  (25.4% / 24.8% / 24.8% / 25.1% — within the 15–35% band)
```

---

## This round's independent audit findings — each verified by direct quotation from the live file before any fix

### P1 — Root Q80: threat model / mechanism mismatch (CONFIRMED, fixed)
The stem explicitly named a threat model of "a compromised, non-hardened node," but the correct answer was an ordinary node-affinity label — which a compromised kubelet can spoof or self-apply on registration. Verified against official Kubernetes sources: a GitHub KEP for this exact concern states *"an intruder can easily register a compromised node with label foo/dedicated=customer-info-app. The scheduler will then bind customer-info-app to the compromised node"* — confirming the audit's technical point. Kubernetes reserves the `node-restriction.kubernetes.io/` label prefix specifically so the NodeRestriction admission plugin blocks a kubelet from setting or modifying such labels on its own Node object. The question was rewritten so the correct answer is the composite control: required node affinity on a label under the protected `node-restriction.kubernetes.io/` prefix, combined with that label only being present on genuinely hardened nodes. The old plain-label option is now an explicit, clearly-insufficient distractor (option B) that a compromised kubelet could still spoof.

### P1 — Chapter 08 self-check Q1: ambiguous/incomplete key (CONFIRMED, fixed)
The stem asked broadly which setting "устраняет неаутентифицированный доступ к его API" (eliminates unauthenticated access to its API), while option D (`--read-only-port=10255`, left enabled) is itself an unauthenticated-access vector, and the explanation already conceded this ("Read-only port следует отключать"). The stem was narrowed to explicitly ask about the kubelet's main (HTTPS) API specifically, and the explanation was rewritten to state clearly that `--read-only-port` is a separate, independently-unauthenticated legacy endpoint requiring its own fix (`--read-only-port=0`), rather than something `--anonymous-auth=false` alone resolves.

### P1 — Chapter 11 + Mock 02 Q26 (+ synchronization check on Root Q55 / Mock 01 Q26): PSA "no policy at all" model was imprecise (CONFIRMED, fixed)
Verified against an official source describing the built-in PSA admission-controller default: *"The default pod security configuration globally enforces the privileged Kubernetes pod security profile ... and generates warnings and audit events based on the policies set by the restricted profile."* This means that even with no namespace labels and no explicit cluster-wide defaults, PSA still applies an implicit, permissive `enforce: privileged` default — not "no PSS check at all." Chapter 11's model was corrected to state this as a third, always-present layer beneath namespace labels and explicit cluster-wide defaults. Mock 02 Q26's correct option was rewritten to state this precisely: *"The admission controller's own built-in default applies, which is an effectively permissive `privileged` profile in `enforce` mode — this rarely blocks a Pod, but it is still a real applied policy, not 'no PSS check at all'."* Root Q55 and Mock 01 Q26 were checked for the same imprecision and found **not** to make the false "no policy" claim — both already correctly state PSA applies via namespace labels or cluster-wide defaults, which remains true regardless of this additional built-in-default nuance; no change was needed there.

### P1 — Mock 01 Q11 ↔ Mock 02 Q12: real overlap, correctly identified against the actual pairing (CONFIRMED, fixed)
The audit correctly noted that a prior round's embedded report described fixing "M1Q12 ↔ M2Q12" when the actual overlapping pair was M1Q11 (exposed, unauthenticated kubelet API) ↔ M2Q12 (unauthenticated `--read-only-port`) — a specific instance of the same general concept M1Q11 already tests. Verified directly: M1Q11's correct answer is *"An exposed, unauthenticated kubelet API"*; M2Q12 (before this fix) asked about `--read-only-port=10255` being left enabled — the same underlying concept. M2Q12 was replaced with an etcd-TLS-trust-independence scenario (dedicated CA for etcd's own client/peer certificates) that shares no competency with M1Q11.

### P2 — Mock 02 Q13: `AlwaysAllow` described as "the insecure default" without qualification (CONFIRMED, fixed)
Current tooling such as `kubeadm` configures `authorization.mode: Webhook` by default; `AlwaysAllow` is the historical/legacy value, still reachable via a deprecated CLI flag or older/custom configuration, not literally "the" current default in all current setups. The explanation was rewritten to state this distinction explicitly (legacy/historical value vs. current tooling defaults) while preserving the correct answer and the real risk when `AlwaysAllow` is present in a given cluster.

### P2 — Root Q88: endpoint readiness model oversimplified relative to current `EndpointSlice` (CONFIRMED, fixed)
The explanation described Service endpoints as populated only from "ready" Pods in a binary sense. Current `EndpointSlice` tracks `ready`, `serving`, and `terminating` conditions for more precise backend selection, particularly during Pod termination. The explanation was updated to name this current model while keeping the KCSA-level conclusion (no ready Pods → no usable endpoint under default behavior) unchanged and correct.

### P2 — Root Q83: `ResourceQuota` incorrectly implied relevant to stale-data confidentiality (CONFIRMED, fixed)
The explanation grouped "reclaim policy and namespace-level RBAC/quota controls" together as addressing this exposure. `ResourceQuota` is a capacity-governance control and has no bearing on data confidentiality or reuse. The explanation was rewritten to separate reclaim-policy/sanitization (which governs whether retained data is actually removed) from RBAC (which governs who may create a PVC against a given storage class), and to state explicitly that `ResourceQuota` does not address this gap at all.

### P2 — Mock 02 Q15: weak theory traceability for file-integrity/configuration monitoring (CONFIRMED, fixed via Option A — improve theory)
Verified that Chapter 08 did not mention file-integrity or configuration-monitoring practices before this fix (`grep` for "integrity monit|file integrity|configuration monit" returned no matches). Added a short paragraph to Chapter 08, §08.1, stating this practice explicitly as evidence that a kubelet's hardened configuration was not altered after the fact, framed generally (not tied to one specific tool) to avoid CKS-level implementation depth.

### Reviewed, not changed
- **Root Q68 / Q70**: audit again noted these feel closer to generic Kubernetes knowledge with an added security frame than to pure security reasoning. Re-read both; no technical inaccuracy found, and both were already given explicit security framing in a prior pass. This is a subjective framing judgment, not a verified defect. No change made.
- **Root Q55 / Mock 01 Q26**: confirmed correct as-is (see the Chapter 11/Mock02 Q26 finding above — the "no policy at all" imprecision does not appear in either of these two questions).

## Mock01 ↔ Mock02 independence — status after this round's fix
The specific pair flagged this round (M1Q11 ↔ M2Q12) has been resolved by replacing M2Q12's competency. The overlaps resolved in the previous round (M1Q7↔M2Q8, M1Q16↔M2Q15, M1Q36↔M2Q37, M1Q6↔M2Q47, M1Q34↔M2Q33, M1Q44↔M2Q15-old) were independently re-confirmed still resolved by this round's audit and were not re-touched in this pass.

## Full regression after all fixes (recalculated from the live files)
```
Root: 94 questions, 4 options + 1 valid key each. Distribution A24/B23/C23/D24.
Mock 01: 60 questions, 4 options + 1 valid key each. Distribution a15/b15/c15/d15.
Mock 02: 60 questions, 4 options + 1 valid key each. Distribution a15/b15/c15/d15.
Chapters: 93 questions across 20 files, 4 options + 1 valid key each. Distribution A24/B23/C23/D23.
Combined: 307 questions, A78/B76/C76/D77 (25.4%/24.8%/24.8%/25.1%).
Broken local links: 0.
Unclosed Markdown fences: 0 in any edited file (README.MD, both mocks, Chapter 08, Chapter 11 all checked individually).
```

## Fixes made this round
```
P1: Root Q80 (threat-model/mechanism mismatch — now a composite protected-label + affinity answer); Chapter 08 self-check Q1 (stem narrowed, read-only-port risk explained as separate); Chapter 11 + Mock 02 Q26 (PSA "no policy at all" replaced with correct implicit-permissive-default model); Mock 02 Q12 (replaced — no longer overlaps Mock 01 Q11).
P2: Mock 02 Q13 (AlwaysAllow legacy-vs-current-default distinction), Root Q88 (EndpointSlice conditions model), Root Q83 (ResourceQuota removed from confidentiality-relevant controls, reclaim/RBAC distinguished), Mock 02 Q15 (Chapter 08 theory added for file-integrity/configuration monitoring).
```

## Remaining findings
```
P0: none found this round.
P1: none found this round after the fixes above.
P2: none newly identified beyond items already reviewed.
P3: Root Q68/Q70 subjective "still feels generic" framing judgment noted by the audit but not confirmed as a technical defect; no change made.
```

## Final status
```
HOLD — pending independent re-audit of all 307/307 questions.
```

This report does not self-certify READY or CONDITIONAL READY. Across multiple rounds, independent audits have repeatedly found real defects — including, this round, a missing file in the working tree that this agent had not noticed, and in earlier rounds a factually false claim in this agent's own prior report. This report documents what was verified and changed in this round, with direct quotations and, where applicable, official-source verification, as evidence — and explicitly defers the release-readiness determination to the next independent audit rather than asserting one here.
