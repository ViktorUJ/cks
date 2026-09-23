# KCSA Theory Improvement Report

**Дата регенерации:** 2026-09-02  
**Граница курса:** KCSA associate-level, conceptual MCQ preparation. Материал объясняет выбор security control, enforcement boundary, ограничения и evidence; он не заменяет практические CKS labs, authoring сложных policy или эксплуатацию уязвимостей.

## 1. Curriculum и version contours

Курс сохраняет LIVE KCSA domains и веса `14/22/22/16/16/10`. Учебные примеры зафиксированы на Kubernetes `v1.36`; это самостоятельная baseline-версия и не является утверждением о версии CKS. На дату проверки Linux Foundation указывает CKS exam environment на Kubernetes `v1.35`.

## 2. Currentness и technical precision

- Учебные NGINX-примеры в главах 09–11 используют исправленную stable-ветку NGINX `1.30.4`: `course/09` и `course/11` используют `nginxinc/nginx-unprivileged:1.30.4-alpine-slim`, а `course/10` — `nginx:1.30.4`. Образ `nginx-unprivileged` подготовлен для непривилегированного запуска и по умолчанию слушает `8080`; `containerPort` описывает, но не меняет порт процесса. При каждом release-аудите NGINX version pins нужно повторно сверять с upstream security advisories.
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
- Mock02 Q43 tests Kubernetes privilege escalation after application compromise: a compromised workload identity that can create a `ClusterRoleBinding` and is also authorized to bind a privileged `ClusterRole` (for example through explicit `bind` permission on `cluster-admin`) can turn an application-level RCE into cluster-level privilege escalation. Mere `create` permission on `ClusterRoleBinding` alone is not sufficient to bypass Kubernetes RBAC privilege-escalation protections.
- The final independent audit must classify every question against the current Linux Foundation KCSA domain matrix and must review semantic independence rather than relying on exact-stem equality.

## 4. Standalone course delivery

Самостоятельный KCSA package содержит кликабельные ссылки только на файлы внутри KCSA или на stable absolute URLs. Все previously clickable sibling `cka` / `cks` relative links удалены; cross-course reading guidance сохранена обычным текстом в `course/README_RU.md` и chapter «Куда дальше» blocks.

## 5. Validation boundary

Regression включает structure, keys, local links, standalone link policy, Markdown balance, answer distributions, exact normalized stems и targeted markers для каждого подтверждённого fix. Exact string equality не заменяет semantic review: release decisions также требуют review Mock01↔Mock01, Mock02↔Mock02, cross-mock definition/application overlaps, domain placement относительно live KCSA matrix, answer-shape cues и explanation↔option consistency, и version-sensitive facts.

## 6. Дополнение по инициативе пользователя

`course/02/ru.md` §02.1 содержит компактный блок про текущий CNCF **TAG Security and Compliance** — действующую группу CNCF в области security/compliance после архивирования прежнего **TAG-Security** — и про исторический **Cloud Native Security Whitepaper**, созданный прежним TAG-Security, с его lifecycle Develop → Distribute → Deploy → Runtime. Там же кратко разобраны CNCF project maturity levels (Sandbox → Incubating → Graduated) с явным упором на безопасность и экосистему security-инструментов, а не на историю фонда. Приведены только independently verified Graduated-примеры (Falco — runtime, OPA/Kyverno — admission, Cilium — network), поскольку maturity level конкретных проектов может меняться; для самостоятельной проверки сохранена ссылка на актуальную страницу CNCF projects.

## 7. Currentness update (2026-09-01 verification)

Независимо верифицировано на `docs.linuxfoundation.org/tc-docs/certification/faq-mc` и `important-instructions-mc`: стандартный Linux Foundation Multiple Choice экзамен (в том числе KCSA) содержит **60 вопросов**, длится **90 минут** и требует **75% или выше** для прохождения; KCSA доступен только на английском языке (LF Language matrix). `course/01/ru.md`, `course/20/ru.md` и `course/README_RU.md` обновлены так, чтобы называть эти числа проверенными фактами на дату снимка 2026-09-01, а не приблизительными ориентирами, при сохранении явного предупреждения, что условия могут измениться после этой даты и должны быть перепроверены перед регистрацией.

Также исправлена неточность в `course/06/ru.md` §06.2: DNS-настройки `Pod` в Kubernetes предоставляет kubelet через `/etc/resolv.conf`, а не файл, который нужно вручную включать в минимальный `scratch`-образ; пример скорректирован, чтобы не ставить DNS в один ряд с runtime-зависимостями (CA bundle, timezone data), которые действительно нужно добавлять в образ вручную.

## 8. Toolchain currentness update (2026-09-03 verification)

Независимо верифицировано на `go.dev/doc/devel/release`: релиз Go 1.27.0 состоялся 2026-08-19, минорная ревизия 1.27.1 - 2026-09-01; официальная Go Release Policy гласит "each major Go release is supported until there are two newer major releases" - на дату проверки 2026-09-03 Go 1.25 уже вне окна поддержки (Go 1.26 и Go 1.27 - две последние ветки). Пример multi-stage build в `course/06/ru.md` §06.2 обновлён с `FROM golang:1.25 AS build` на `FROM golang:1.27.1 AS build`, чтобы глава о безопасности артефактов и supply chain не иллюстрировала build toolchain, вышедший из окна получения security fixes.

**Status: HOLD — pending independent full audit.**
