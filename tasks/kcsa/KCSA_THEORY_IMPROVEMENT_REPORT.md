# KCSA Theory Improvement Report

**Дата аудита:** 2026-09-01
**Граница курса:** KCSA associate-level, conceptual MCQ preparation. Изменения усиливают выбор security control, его enforcement point, evidence и ограничения; они не добавляют labs, profile authoring или эксплуатацию уязвимостей уровня CKS.

## 1. Итог аудита curriculum

Live-страница Linux Foundation подтверждает шесть доменов KCSA и веса `14/22/22/16/16/10`: Overview, Cluster Component Security, Security Fundamentals, Threat Model, Platform Security и Compliance. Все домены и компетенции уже отображены в `course/README_RU.md` и таблице «компетенция → глава» в `course/KCSA_RU.md`; изменение весов не потребовалось.

Существующие сильные разделы не переписывались: distinctions `digest`/signature/SBOM/provenance, SLSA v1.2 Build/Source tracks, `ValidatingAdmissionPolicy`/CEL, STRIDE/ATT&CK, `audit` versus runtime detection и цепочка `requirement → control → evidence` сохранены. Новые блоки присоединены только там, где они добавляют причинно-следственную модель или устраняют распространённый distractor.

## 2. Изменённые файлы

| Файл | Изменение |
|---|---|
| `course/01/ru.md` - `course/20/ru.md` | Существующие финальные блоки явно названы `Exam vocabulary`, `Exam Essentials` и `Не путать и как это встречается на экзамене`; содержание не расширялось механически. |
| `course/05/ru.md` | Linux-process isolation model, SELinux/AppArmor MAC context, resource-isolation table and decision scenarios. |
| `course/09/ru.md` | Pod/process mental model, точные различия namespaces, cgroups, capabilities, seccomp, MAC и sandbox runtimes; уточнена shared Pod network namespace boundary. |
| `course/10/ru.md` | Authentication map расширена authentication webhook и bootstrap tokens; добавлено различие Node authorizer и `NodeRestriction`. |
| `course/11/ru.md` | Added built-in admission map: `NodeRestriction`, `LimitRanger`, `ResourceQuota`, `ServiceAccount`, `AlwaysPullImages`, webhooks и CEL policy; clarified Gatekeeper/Kyverno boundary. |
| `course/13/ru.md` | Added `NetworkPolicy` capability/limitation block and scenario → best control → evidence table. |
| `course/15/ru.md` | Added attack tree «получить production secrets» and attack path → preventive/detective/evidence mapping. |
| `course/17/ru.md` | Added source-to-runtime supply-chain flow with threat → control → evidence per stage. |
| `course/18/ru.md` | Added compact PKI/service-mesh map and explicit TLS/RBAC/Ingress termination limitations. |
| `course/19/ru.md` | Added explicit framework/control/evidence distinctions for ATT&CK, STRIDE, CIS and PCI DSS. |

## 3. Добавленные и расширенные темы

- **Isolation:** container как Linux process; namespaces отвечают за видимость, cgroups - за resources, capabilities - за отдельные privileged actions, seccomp - за syscalls, AppArmor/SELinux - за MAC policy, gVisor/Kata - за дополнительную isolation boundary.
- **Resource isolation:** `requests`, CPU/memory limits, `LimitRange`, `ResourceQuota`, HPA и `NetworkPolicy` показаны как разные механизмы с тремя security scenarios.
- **Identity/API flow:** authentication methods, workload identity `ServiceAccount`, RBAC, Node authorizer и `NodeRestriction` расположены на правильных стадиях решения API Server.
- **Admission:** built-in plugins, mutating/validating webhooks, `ValidatingAdmissionPolicy` + CEL и external policy engines отделены от authentication/authorization.
- **Threat reasoning:** attack tree связывает атакующий путь с preventive control, detective control и evidence.
- **Platform:** end-to-end supply chain и PKI/service-mesh models теперь формулируют не только control, но и ограничение/evidence.
- **Compliance:** purpose table существовал; к нему добавлено явное различение methodology, knowledge base, benchmark, requirement и enforcement control.

## 4. Исправленные или явно предотвращённые неточности

В материале не обнаружено major current Kubernetes fact, который требовал бы переписывания. Уточнены потенциально ошибочные упрощения:

- capability не эквивалентна full root, cgroup не является sandbox, namespace не является policy;
- `Node` authorizer относится к authorization, `NodeRestriction` - к validating admission;
- `ServiceAccount` является workload identity, а не permission; permissions выдаёт authorizer, обычно RBAC;
- `NetworkPolicy` не добавляет TLS, identity, application authorization, image scanning или resource limits;
- certificate/TLS не выдаёт RBAC permission, а Ingress TLS termination не гарантирует end-to-end encryption;
- historical `PodSecurityPolicy` остаётся только с явной маркировкой удаления с Kubernetes `v1.25`.

## 5. Добавленные exam traps и attack scenarios

**Exam traps:** `requests != limits`; `ResourceQuota != LimitRange`; HPA не quota/security boundary; `NetworkPolicy != seccomp`; `AppArmor/SELinux != seccomp`; `Node authorizer != NodeRestriction`; Gatekeeper/Kyverno не authorizer и не authentication; TLS/certificate/mTLS не RBAC; digest/signature/SBOM/provenance не взаимозаменяемы.

**Scenarios:** unbounded tenant resource consumption; oversized Pod resource request; forbidden Pod-to-database path; stolen ServiceAccount token; shell in container; malicious CI artifact; exposure of etcd backup; Pod boundary and localhost sharing. Для каждого добавленного decision table указан control и evidence.

## 6. Comparison and decision tables

Добавлены таблицы: Linux mechanisms → question/limitation; resource mechanism → scenario/control/evidence; admission scenario → best mechanism/distractor; `NetworkPolicy` scenario → control/evidence; supply-chain stage → threat/control/evidence; attack path → preventive/detective/evidence. Существующие comparison tables PKI, frameworks, audit levels и supply-chain artifacts сохранены.

## 7. Переработанные вопросы

Вопросы для самопроверки уже были scenario-oriented и использовали скрытые ответы с разбором. Они сохранены в диапазоне 3-5 вопросов на главу по текущей спецификации: новые модели не увеличивают банк ради количества. Добавленные theory decision tables используют те же реалистичные distractor pairs (`LimitRange`/`ResourceQuota`, HPA, `NetworkPolicy`, RBAC, seccomp), поэтому преподаватель или последующее обновление мока могут безопасно опираться на них без добавления trivia.

## 8. Официальные источники

- [Linux Foundation - KCSA Domains & Competencies](https://training.linuxfoundation.org/certification/kubernetes-and-cloud-native-security-associate-kcsa/) - live domains, weights, beginner/pre-professional scope, MCQ and 90-minute exam format.
- [Kubernetes - Linux kernel security constraints for Pods and containers](https://kubernetes.io/docs/concepts/security/linux-kernel-security-constraints/) - seccomp, AppArmor, SELinux, privileged-container limitations.
- [Kubernetes - Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) - scheduling requests, CPU throttling, memory OOM behaviour and cgroups.
- [Kubernetes - Using Node Authorization](https://kubernetes.io/docs/reference/access-authn-authz/node/) - purpose/scope of Node authorizer and relationship to `NodeRestriction`.
- [Kubernetes - Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) - admission after authentication/authorization, mutation/validation, built-in plugin semantics and `ValidatingAdmissionPolicy`.
- [Kubernetes - Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) - policy boundary and CNI enforcement.
- [SLSA v1.2 specification](https://slsa.dev/spec/v1.2/) - retained as source for existing cautious Build/Source-track discussion; no new claim was added after the direct `levels` endpoint returned 404 during this audit.

## 9. Сознательно не реализовано

| Recommendation | Status | Rationale |
|---|---|---|
| SELinux/AppArmor profiles, complex seccomp, Rego/Kyverno authoring | NOT APPLICABLE | Это практическая CKS-level настройка; KCSA требует conceptual recognition. |
| Container escape/CVE exploitation, eBPF/Cilium internals, OpenSSL and Istio labs | NOT APPLICABLE | Не помогает MCQ-level mechanism selection и нарушает KCSA boundary. |
| Полная переработка supply-chain, audit/runtime, STRIDE/MITRE, SLSA | NOT APPLICABLE | Разделы уже точны и сильны; сохранены distinctions вместо дублирования. |
| New Mock 02 | NOT IMPLEMENTED | Второй mock optional/reserved по текущей спецификации и не является теоретическим gap этого ТЗ. |
| Removing language toggles | NOT APPLICABLE | Переключатели требуются текущей спецификацией R-FMT-2; переводной backfill вне этого изменения. |
| Structured YAML question source or automatic MCQ grader | NOT APPLICABLE | Не входит в обязательный scope текущей KCSA specification. |

## 10. Regression matrix

| Improvement | Previous state | New state | Status | Evidence |
|---|---|---|---|---|
| Live curriculum alignment | Six domains/weights already mapped | Re-audited, unchanged `14/22/22/16/16/10` | FIXED | LF page and `README_RU.md`/`KCSA_RU.md` |
| Linux isolation mental model | Separate mentions of `securityContext`, sandbox | Unified Linux-process layer and explicit non-equivalences | FIXED | `course/05/ru.md`, `course/09/ru.md` |
| SELinux conceptual coverage | AppArmor mentioned; SELinux not in compact mental map | MAC explanation alongside AppArmor | FIXED | `course/05/ru.md` |
| Resource isolation | Quota mentioned in tenancy context | Requests/limits/LimitRange/ResourceQuota/HPA/NetworkPolicy comparison + MCQ | FIXED | `course/05/ru.md` |
| Authentication methods | Certificates, tokens, SA and OIDC | Added authentication webhook and bootstrap token context | FIXED | `course/10/ru.md` |
| Authorization mechanisms | RBAC/Node/Webhook/ABAC listed | Node authorizer versus `NodeRestriction` explicitly mapped | FIXED | `course/10/ru.md` |
| Admission map | PSA, policy engines and CEL existed in separate places | Built-in/webhook/CEL map and policy-engine boundary | FIXED | `course/11/ru.md` |
| Attack tree and evidence | STRIDE/ATT&CK and scenarios existed | Production-secrets tree plus preventive/detective/evidence mapping | FIXED | `course/15/ru.md` |
| NetworkPolicy limitations | L3/L4 and CNI enforcement existed | Explicit does/does-not and decision table | FIXED | `course/13/ru.md` |
| Supply-chain reasoning | Strong distinctions and chain existed | Per-stage threat/control/evidence flow | FIXED | `course/17/ru.md` |
| PKI/service-mesh distinctions | PKI/mTLS described | Explicit CA→cert→TLS→mTLS→rotation map and limitations | FIXED | `course/18/ru.md` |
| Compliance framework purpose | Framework table and requirement/control/evidence existed | Explicit `!=` traps for ATT&CK/STRIDE/CIS/PCI | FIXED | `course/19/ru.md` |
| Exam vocabulary / essentials / traps | Equivalent blocks named differently | All 20 chapters expose consistent named headings | FIXED | `course/*/ru.md` |
| Version drift / removed APIs | PSP already historical; examples pinned to v1.36 | Re-audited; no new stale API claim introduced | FIXED | `course/11/ru.md`, `VERSION_POLICY.md` |
