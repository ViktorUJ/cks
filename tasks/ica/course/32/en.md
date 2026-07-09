[RU version](ru.md)

# Chapter 32. The ICA exam: format and preparation

> **The final chapter.** Throughout the course we prepared both the theory and the practice for the
> **Istio Certified Associate (ICA)** certification. Here we gather how the exam is structured, how
> to prepare for it, and where to get trial runs - our mock exams.

## 32.1. What the exam is

**ICA (Istio Certified Associate)** is a certification from the CNCF and the Linux Foundation
(originally developed by Tetrate) that confirms your ability to work with Istio. The exam is
**online, proctored**, and hybrid in format - **performance-based tasks plus multiple-choice
questions**. In the practical part you are given access to a cluster and asked to solve tasks by
hand - set up routing, enable mTLS, write a policy, find and fix a problem; in the theory part they
check your understanding of the principles and terminology. The duration is **2 hours**, and the
environment has been upgraded to **Istio v1.26**.

During the exam access to the official documentation is allowed (istio.io and its subdomains; as a
rule the Istio blog and the Kubernetes documentation too - check the current list of allowed
resources in the Candidate Handbook). This matters: no one forces you to remember all the YAML
fields by heart, but you need to **quickly** find and apply what you need.

> The exact details (duration, passing score, number of tasks, retake rules) change over time and
> depend on the program version. Always check the official page:
> [Istio Certified Associate (ICA)](https://training.linuxfoundation.org/certification/istio-certified-associate-ica).

## 32.2. The domains and what to focus on

The exam is built around weighted domains. The current breakdown (after the program update in August
2025):

| Domain | Weight | Course chapters |
|--------|--------|-----------------|
| Traffic Management | 35% | 5-12 |
| Securing Workloads | 25% | 9, 13-16 |
| Installation, Upgrade & Configuration | 20% | 2-4, 22 (ambient) |
| Troubleshooting | 20% | 24, 30 |

What is important to know about the new program:

- **There is no separate "Advanced Scenarios" domain anymore** - its topics were redistributed: the
  ambient installation moved into Installation, egress and connecting to external services - into
  Traffic Management.
- **Installation grew to 20%** and now explicitly includes installing **in sidecar and in ambient
  mode**, customization and upgrading (canary/in-place).
- **Traffic Management includes egress, ingress, resilience** (circuit breaking, failover, outlier
  detection, timeouts, retries) **and fault injection**.
- **Securing Workloads** - authorization, authentication (mTLS, JWT) and **securing edge traffic with
  TLS**.
- **Troubleshooting** - configuration, the control plane and the data plane.

The takeaway: **train traffic management the most** (Gateway, VirtualService, DestinationRule,
routing, resilience, egress, fault injection) - it is the biggest domain (35%). After that the
priorities go almost level: security (25%), installation/upgrade and troubleshooting (20% each) - do
not skip installation and debugging, their weight has grown noticeably.

## 32.3. Practical tips

CKA/CKS experience transfers directly:

- **Aliases and autocompletion.** Set up `alias k=kubectl`, enable completion for `kubectl` and
  `istioctl` - it saves time on every task.
- **Check the context.** Always verify which cluster and namespace you are working in
  (`kubectl config current-context`), especially if there are many tasks.
- **Read the task literally.** The exact resource names, namespace, ports, versions - an error in a
  subset name or a selector and the rule will not work (chapter 5).
- **Verify the result.** After configuring, run `curl` from a pod, look at the codes and headers -
  make sure the traffic really goes where it should.
- **`istioctl analyze` is your friend.** It quickly catches configuration errors (chapter 24). On a
  problem - `proxy-status` (SYNCED?) and `proxy-config`.
- **Time management.** Do not get stuck on one task. Skip a hard one, come back later - as on CKA.
- **Documentation at hand.** Know in advance where in istio.io the examples of Gateway,
  VirtualService, PeerAuthentication are - during the exam you will copy from there and edit.

## 32.4. Mock exams

The best preparation is to run realistic exams against the clock. This repository has **two mock
exams** that imitate the ICA format:

- **Mock 01** - 17 tasks on the basic topics: installation, Gateway/VirtualService,
  AuthorizationPolicy, injection management.
  [tasks/ica/mock/01](../../mock/01/README.MD)
- **Mock 02** - 16 tasks on advanced patterns: a canary upgrade with the operator, installation via
  Helm, an egress gateway, port-level balancing, fault injection, cross-namespace authorization.
  [tasks/ica/mock/02](../../mock/02/README.MD)

A general description of the environment, the commands (`check_result`, `time_left`, `hosts`) and
tips - in the infrastructure's root README: [tasks/ica/README.MD](../../README.MD).

How to use the mocks:

1. Go through the relevant chapters and labs on the topic.
2. Run the mock **against the clock**, like a real exam, without hints.
3. Check yourself with `check_result`, review the mistakes against the solutions.
4. Repeat until you comfortably fit within the timing with a **70%+** result.

The mocks train the **practical** part of the exam. But remember that the format is hybrid: there are
also multiple-choice questions on the understanding of the principles and terminology. So besides the
mocks, review the **theory** by chapter (what each resource does, how mTLS, xDS, locality balancing
work) - both "I can do it by hand" and "I understand why" are tested.

## 32.5. How to prepare with this course

The recommended route:

1. **Part 1 (chapters 1-24)** - the basics and all the exam domains. Reinforce each chapter with a
   lab (🧪).
2. **The mocks** (section 32.4) - run them after Part 1, against the clock.
3. **Part 2 (chapters 25-31)** - best practices for real work. Not mandatory for the exam itself, but
   they make you an engineer who understands Istio in production, not just one who passes a test.

## 32.6. Summary

- ICA is an online, proctored exam, hybrid in format: practical tasks in a cluster plus
  multiple-choice questions; access to the istio.io documentation is allowed, the duration is 2
  hours, the environment is v1.26.
- The current domains (as of August 2025): **Traffic Management 35%**, Securing Workloads 25%,
  Installation/Upgrade/Config 20%, Troubleshooting 20%; there is no "Advanced Scenarios" domain
  anymore.
- Train traffic management the most, but do not skip installation and troubleshooting - their weight
  has grown to 20%.
- Carry over CKA/CKS habits: aliases, autocompletion, checking the context, reading tasks literally,
  verifying the result, time management.
- Run **mock 01 and mock 02** against the clock for practice, and review the theory by chapter (for
  the multiple-choice part); aim for a steady 70%+.
- Check the exact logistics and rules (passing score, number of questions, allowed resources) on the
  official ICA page.

---

This concludes the course. You have gone from the idea of a service mesh to production operation of
Istio: traffic management, resilience, security, observability, advanced scenarios, troubleshooting,
real migrations, hardening - and exam preparation. Come back to the chapters, labs and mocks as
needed. Good luck with the ICA and with Istio in battle.

[Contents](../README.md) · [Chapter 31](../31/en.md)
