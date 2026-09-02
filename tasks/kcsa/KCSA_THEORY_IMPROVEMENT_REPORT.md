# KCSA Theory Improvement Report

**Дата регенерации:** 2026-09-02  
**Граница курса:** KCSA associate-level, conceptual MCQ preparation. Материал объясняет выбор security control, enforcement boundary, ограничения и evidence; он не заменяет практические CKS labs, authoring сложных policy или эксплуатацию уязвимостей.

## 1. Curriculum и version contours

Курс сохраняет LIVE KCSA domains и веса `14/22/22/16/16/10`. Учебные примеры зафиксированы на Kubernetes `v1.36`; это самостоятельная baseline-версия и не является утверждением о версии CKS. На дату проверки Linux Foundation указывает CKS exam environment на Kubernetes `v1.35`.

## 2. Currentness и technical precision

- Глава 09 использует запускаемый non-root HTTP baseline на `nginxinc/nginx-unprivileged:1.27-alpine`: образ подготовлен для непривилегированного запуска и слушает `8080`; `containerPort` описывает, но не меняет порт процесса.
- `MutatingAdmissionPolicy` + CEL добавлена в главы 11 и 17 вместе с `ValidatingAdmissionPolicy` + CEL. В Kubernetes `v1.36` mutating API stable и enabled by default; mutation и validation остаются разными задачами.
- KMS v2 отражён как рекомендуемый stable API для external envelope encryption; KMS v1 deprecated and disabled by default for supported modern configurations.
- Runtime isolation, signature/trust-policy, FIM evidence, NetworkPolicy default-deny и `hostNetwork` plugin-dependent behavior сохраняют точные границы применимости.
- RoleBinding описан как additive namespaced permission grant, а Pod — как workload boundary, но не VM/kernel boundary для untrusted tenancy.

## 3. Question-bank independence

### Domain matrix accuracy

Официальная текущая матрица KCSA относит `Audit Logging` к **Kubernetes Security Fundamentals**, а threat-modelling frameworks (STRIDE, attack tree, kill-chain) — к **Compliance and Security Frameworks**. Домен **Kubernetes Threat Model** ограничен Trust Boundaries and Data Flow, Persistence, Denial of Service, Malicious Code Execution and Compromised Applications in Containers, Attacker on the Network, Access to Sensitive Data и Privilege Escalation. Mock02 Q33 (audit correlation via `auditID`) перемещён в Security Fundamentals; Q38/Q40/Q41/Q43/Q44 переписаны как genuine Threat Model scenarios (DoS через resource exhaustion, CronJob+credential persistence, compromised host root, post-RCE runtime risk, etcd backup as a sensitive-data asset), заменив generic ResourceQuota arithmetic и misplaced framework questions (STRIDE, attack tree, kill-chain).

### Root bank — удалён

По явному указанию пользователя корневой question bank `README.MD` (94 вопроса, distribution A24/B23/C23/D24) удалён из курса и больше не используется. Ни один файл не содержал кликабельной Markdown-ссылки на него. Практика KCSA теперь состоит из Mock01, Mock02 и chapter self-checks; итоговое количество вопросов курса — 213 (Mock01 60 + Mock02 60 + chapter self-checks 93).

### Mock01 и Mock02

- Mock02 Q1/Q2 test distinct Overview competencies: Q1 covers declarative reconciliation and correcting the source workload template; Q2 covers cloud/infrastructure perimeter restriction of a managed Kubernetes API endpoint before Kubernetes credentials are evaluated.
- Mock02 Q43 tests Kubernetes privilege escalation after application compromise: a compromised workload identity with permission to create privileged `ClusterRoleBinding` objects can turn an application-level RCE into cluster-level privilege escalation.
- The final independent audit must classify every question against the current Linux Foundation KCSA domain matrix and must review semantic independence rather than relying on exact-stem equality.

## 4. Standalone course delivery

Самостоятельный KCSA package содержит кликабельные ссылки только на файлы внутри KCSA или на stable absolute URLs. Все previously clickable sibling `cka` / `cks` relative links удалены; cross-course reading guidance сохранена обычным текстом в `course/README_RU.md` и chapter «Куда дальше» blocks.

## 5. Validation boundary

Regression включает structure, keys, local links, standalone link policy, Markdown balance, answer distributions, exact normalized stems и targeted markers для каждого подтверждённого fix. Exact string equality не заменяет semantic review: release decisions также требуют review Mock01↔Mock01, Mock02↔Mock02, cross-mock definition/application overlaps, domain placement относительно live KCSA matrix, answer-shape cues и explanation↔option consistency, и version-sensitive facts.

**Status: HOLD — pending independent full audit.**
