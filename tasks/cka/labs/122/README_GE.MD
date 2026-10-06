[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 122 — დრილები: pod-ების დაგეგმვა

## აღწერა

სიჩქარის ტრენაჟორი დომენ Workloads & Scheduling-ისთვის: მოკლე დამოუკიდებელი დავალებები
nodeSelector-ზე, nodeAffinity-ზე, requests/limits-ზე, PriorityClass-სა და
taints/tolerations-ზე. კლასტერი ერთკვანძიანია — label-ები (ლეიბლები) და taint-ები ერთადერთ
node-ზე ეკიდება.

დავალებები გამოცდის სტილშია გაფორმებული და მათი შემოწმება ავტომატურად ხდება ბრძანებით
`check_result`. დრილის მიზანი თეორიის განხილვა არაა, არამედ სიჩქარე და კუნთოვანი მეხსიერება:
„ხელის მომარჯვება“ Pod-ების დაგეგმვის მართვაში და გამოცდის ტემპში ჩაჯდომა.

> **მნიშვნელოვანი:** დავალება 6 (taint) შეასრულეთ ბოლოს — taint `NoSchedule` ხელს უშლის
> toleration-ის გარეშე Pod-ების დაგეგმვას.

## მიზანი

განამტკიცოთ კურსის თავების მასალა:

- [თავი 12. Pod-ების დაგეგმვა: nodeName, nodeSelector, affinity](../../course/12/ge.md) — Pod-ების მიბმა node-ებზე nodeSelector-ითა და nodeAffinity-ით
- [თავი 13. Taint-ები და toleration-ები](../../course/13/ge.md) — Pod-ების მოგერიება taint-ებით და მათი დაშვება toleration-ებით
- [თავი 14. რესურსები: requests, limits, LimitRange, ResourceQuota](../../course/14/ge.md) — CPU/მეხსიერების requests და limits კონტეინერზე
- [თავი 15. Static Pods, PriorityClass, რამდენიმე დამგეგმავი](../../course/15/ge.md) — Pod-ების პრიორიტეტი PriorityClass-ის მეშვეობით

## რას ვაკეთებთ და რისთვის

| ბლოკი | დავალებები | უნარი |
|-------|------------|-------|
| **მიბმა node-ზე** | label `disk=ssd`, Pod `sel` (nodeSelector), Pod `aff` (nodeAffinity) | Pod-ების მიმართვა საჭირო node-ებზე (თავი 12) |
| **რესურსები და პრიორიტეტი** | Pod `res` (requests/limits), PriorityClass `high-prio` + Pod `prio` | requests/limits და დაგეგმვის პრიორიტეტი (თავები 14, 15) |
| **Taint-ები და toleration-ები** | taint `dedicated=special:NoSchedule` + Pod `tol` | node-ის იზოლაცია taint-ით და დაშვება toleration-ის მეშვეობით (თავი 13) |

## ინფრასტრუქტურა

გარემო იშლება AWS-ში (`eu-central-1`) Terragrunt-ის მეშვეობით და შედგება:

| კომპონენტი | აღწერა                                                                          |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` საჯარო ქვექსელებით                                           |
| `ssh-keys` | SSH-გასაღებები node-ებზე წვდომისთვის                                             |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ერთკვანძიანი; namespace `sched` წინასწარ შექმნილია |
| `worker`   | სამუშაო მანქანა `kubectl`-ითა და `check_result`-ით                              |

ინსტანსები: `t4g.medium` (master), Ubuntu `22.04`. კლასტერი ერთკვანძიანია — master-ს
მოშორებულია taint `control-plane`, ამიტომ pod-ები პირდაპირ მასზე იგეგმება.

## განთავსება

```bash
TASK=122 make run_cka_task
```

შექმნის შემდეგ დაუკავშირდით სამუშაო მანქანას (worker) SSH-ით და დავალებები შეასრულეთ
იქიდან. `kubectl` უკვე კონფიგურირებულია კონტექსტზე `cluster1-admin@cluster1`.

სასარგებლო ბრძანებები სამუშაო მანქანაზე:

```bash
time_left       # რამდენი დრო დარჩა
check_result    # ამოხსნის შემოწმება
```

## დავალებები

ერთადერთი node-ის სახელი მოსახერხებელია ცვლადში ჩაწეროთ:
`NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')`.

---
|        **1**        | **ლეიბლი node-ზე**                                          |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | node-ზე მიამაგრეთ label (ლეიბლი) `disk=ssd` (`kubectl label node $NODE disk=ssd`). |
| მიღების კრიტერიუმები | - node-ს აქვს label `disk=ssd`. |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით Pod `sel` (ns `sched`, image `viktoruj/ping_pong:latest`) `nodeSelector: disk=ssd`-ით — Pod იგეგმება მხოლოდ ამ label-ის მქონე node-ზე. |
| მიღების კრიტერიუმები | - Pod `sel` მდგომარეობაშია `Running`, `nodeSelector` `disk=ssd`. |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით Pod `aff` (ns `sched`, image `viktoruj/ping_pong:latest`) required nodeAffinity-ით: გასაღები `disk`, ოპერატორი `In`, მნიშვნელობები `[ssd]` (`requiredDuringSchedulingIgnoredDuringExecution`). |
| მიღების კრიტერიუმები | - Pod `aff` მდგომარეობაშია `Running`, nodeAffinity მითითებულია. |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით Pod `res` (ns `sched`, image `viktoruj/ping_pong:latest`) კონტეინერზე requests `cpu=100m`, `memory=64Mi` და limits `cpu=200m`, `memory=128Mi`. |
| მიღების კრიტერიუმები | - Pod `res` მდგომარეობაშია `Running`, limits `cpu` და `memory` მითითებულია. |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით PriorityClass `high-prio` მნიშვნელობით `value: 1000` (`kubectl create priorityclass high-prio --value=1000`), შემდეგ Pod `prio` (ns `sched`, image `viktoruj/ping_pong:latest`) `priorityClassName: high-prio`-ით. |
| მიღების კრიტერიუმები | - PriorityClass `high-prio` `value=1000`;<br/>- Pod `prio` მდგომარეობაშია `Running` `priorityClassName: high-prio`-ით. |
---
|        **6**        | **Taint + toleration** (ბოლოს)                              |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | node-ზე მიამაგრეთ taint `dedicated=special:NoSchedule` (`kubectl taint node $NODE dedicated=special:NoSchedule`), შემდეგ შექმენით Pod `tol` (ns `sched`, image `viktoruj/ping_pong:latest`) შესაბამისი toleration-ით (`key=dedicated`, `operator=Equal`, `value=special`, `effect=NoSchedule`). **ეს დავალება შეასრულეთ ბოლოს** — taint ხელს შეუშლის დანარჩენი Pod-ების დაგეგმვას. |
| მიღების კრიტერიუმები | - node-ს აქვს taint `dedicated=special:NoSchedule`;<br/>- Pod `tol` მდგომარეობაშია `Running`. |
---

## შედეგის შემოწმება

სამუშაო მანქანაზე გაუშვით ავტომატური შემოწმება:

```bash
check_result
```

სკრიპტი გაატარებს ტესტებს და აჩვენებს, რამდენი დავალებაა შესრულებული.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD)

## Mock-გამოცდების დაფარვა

დომენი Workloads & Scheduling (15% CKA) — nodeSelector/affinity-ის, რესურსების,
PriorityClass-ის, taints/tolerations-ის გამეორებები.

## კლასტერისა და რესურსების წაშლა

```bash
TASK=122 make delete_cka_task
```
