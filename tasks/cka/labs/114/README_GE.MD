[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 — Troubleshooting: ვასწორებთ გატეხილ რესურსებს

## აღწერა

პრაქტიკული სამუშაო Troubleshooting-ის დომენზე (CKA-ს 30%). კლასტერში წინასწარ განთავსებულია
**გატეხილი** ობიექტები — თქვენი ამოცანაა მიზეზების მოძებნა და აღმოფხვრა სისტემური გამართვის
მარშრუტის გამოყენებით: `get` → `describe` (Events) → `logs` → შესწორება. დავალებები
ტიპურ ინციდენტებს იმიტირებს: ImagePullBackOff, ცარიელი Endpoints არასწორი სელექტორის გამო და
CreateContainerConfigError არარსებული ConfigMap-ის გამო.

ყველა დავალება გამოცდის სტილშია გაფორმებული (როგორც რეალური CKA/CKAD კითხვები) და მათი
შემოწმება ავტომატურად ხდება ბრძანებით `check_result`.

## მიზანი

განამტკიცოთ კურსის თავების მასალა:

- [თავი 44. აპლიკაციების ხარვეზების გამართვა](../../course/44/ge.md) — მარშრუტი `get` → `describe` → `logs`, Pod-ების სტატუსების გარჩევა
- [თავი 45. control plane-ისა და worker-node-ების გამართვა](../../course/45/ge.md) — კვანძებისა და სისტემური კომპონენტების დიაგნოსტიკა
- [თავი 46. სერვისებისა და ქსელის გამართვა](../../course/46/ge.md) — კავშირი Service ↔ Endpoints ↔ ლეიბლები

## რას ვასწორებთ და რისთვის

ამ ლაბორატორიაში ვასწორებთ სამ დამოუკიდებელ ინციდენტს: გაუმართავი image, გაწყვეტილი კავშირი
Service-სა და pod-ებს შორის, და აკლია კონფიგურაცია. თითოეული ხარვეზი გამართვის მარშრუტის
საკუთარ მონაკვეთს ამუშავებს:

| ხარვეზი | სიმპტომი | მიზეზი | რას ასწავლის |
|---------|----------|--------|--------------|
| **ReplicaSet `rs-app2223`** (namespace `rsapp`) | ImagePullBackOff | image-ის არასწორი ტეგი | image-ის პრობლემების გარჩევა და RS-ის Pod-ების ხელახლა შექმნა (თავი 44) |
| **Service `svc-broken`** (namespace `tsvc`) | ცარიელი Endpoints | selector არ დაემთხვა Pod-ების label-ს | კავშირი Service ↔ Endpoints ↔ ლეიბლები (თავი 46) |
| **Deployment `capp`** (namespace `cfgapp`) | CreateContainerConfigError | არ არის საჭირო ConfigMap | კონფიგურაციის დამოკიდებულებები (თავი 44) |

საბოლოო სურათი იმისა, რაც განთავსდება:

```mermaid
flowchart LR
    a["rs-app2223<br>ImagePullBackOff"] -->|"fix image"| a2["2 ready"]
    b["svc-broken<br>Endpoints ცარიელია"] -->|"fix selector"| b2["Endpoints არსებობს"]
    c["capp<br>CreateContainerConfigError"] -->|"create ConfigMap"| c2["Ready"]
    a2 ~~~ b
    b2 ~~~ c
    style a fill:#db4437,color:#fff
    style b fill:#db4437,color:#fff
    style c fill:#db4437,color:#fff
    style a2 fill:#0f9d58,color:#fff
    style b2 fill:#0f9d58,color:#fff
    style c2 fill:#0f9d58,color:#fff
```

## ინფრასტრუქტურა

გარემო იშლება AWS-ში (`eu-central-1`) Terragrunt-ის მეშვეობით და შედგება:

| კომპონენტი | აღწერა                                                            |
|------------|-------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` საჯარო ქვექსელებით                              |
| `ssh-keys` | SSH-გასაღებები node-ებზე წვდომისთვის                                |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ერთკვანძიანი; გაშვებისას განათავსებს გატეხილ ობიექტებს |
| `worker`   | სამუშაო მანქანა `kubectl`-ით და `check_result`-ით                    |

ინსტანსები: `t4g.medium` (master), Ubuntu `22.04`. კლასტერი ერთკვანძიანია — master-ს
მოშორებულია taint `control-plane`, ამიტომ pod-ები პირდაპირ მასზე იგეგმება.

## განთავსება

```bash
TASK=114 make run_cka_task
```

შექმნის შემდეგ დაუკავშირდით სამუშაო მანქანას (worker) SSH-ით და დავალებები შეასრულეთ
იქიდან. `kubectl` უკვე კონფიგურირებულია კონტექსტზე `cluster1-admin@cluster1`.

სასარგებლო ბრძანებები სამუშაო მანქანაზე:

```bash
time_left       # რამდენი დრო დარჩა
check_result    # ამოხსნის შემოწმება
```

## დავალებები

---
|        **1**        | **ReplicaSet-ის შესწორება**                                  |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | namespace `rsapp`-ში ReplicaSet `rs-app2223`-ის Pod-ები ჩარჩენილია `ImagePullBackOff`-ში. გაიარეთ მარშრუტი: `kubectl get po -n rsapp` (ვხედავთ სტატუსს), `kubectl describe po -n rsapp <pod>` (Events-ში — image `viktoruj/ping_pong:doesnotexist123` არ ჩამოიწევა). შეასწორეთ image RS-ის შაბლონში მუშა ვერსიაზე (`viktoruj/ping_pong:latest`) ბრძანებით `kubectl edit rs rs-app2223 -n rsapp`. RS შაბლონის შეცვლისას Pod-ებს ხელახლა არ ქმნის — წაშალეთ ძველი Pod-ები (`kubectl delete po -n rsapp -l <label>`), რომ RS-მა ახლები ასწიოს. მიაღწიეთ `2` მზა რეპლიკას. |
| მიღების კრიტერიუმები | - ReplicaSet `rs-app2223` (namespace `rsapp`): `2` Ready რეპლიკა. |
---
|        **2**        | **Service-ის შესწორება (ცარიელი Endpoints)**                  |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | Service `svc-broken` namespace `tsvc`-ში ტრაფიკს არ გადასცემს — მას ცარიელი Endpoints აქვს. დიაგნოსტიკა: `kubectl get endpoints svc-broken -n tsvc` (ცარიელია), `kubectl describe svc svc-broken -n tsvc` (selector, მაგალითად `app=WRONG`), `kubectl get pods -n tsvc --show-labels` (Pod-ებს აქვთ ლეიბლი `app=web`). მოიყვანეთ Service-ის selector Pod-ების რეალურ label-ებთან შესაბამისობაში (`kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'`) და დარწმუნდით, რომ Endpoints შეივსო. |
| მიღების კრიტერიუმები | - Service `svc-broken` (namespace `tsvc`): Endpoints არ არის ცარიელი (≥ 1 მისამართი). |
---
|        **3**        | **Deployment-ის შესწორება (არ არის ConfigMap)**               |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | Deployment `capp` namespace `cfgapp`-ში ვარდება `CreateContainerConfigError`-ში. მარშრუტი: `kubectl get po -n cfgapp` (ვხედავთ სტატუსს), `kubectl describe po -n cfgapp <pod>` (Events-ში — ვერ მოიძებნა ConfigMap `missing-config`). შექმენით არარსებული ConfigMap (`kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value`) და დაელოდეთ, სანამ deployment მზად გახდება (`kubectl rollout status deploy capp -n cfgapp`). |
| მიღების კრიტერიუმები | - Deployment `capp` (namespace `cfgapp`): ≥ 1 Ready რეპლიკა. |
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

ლაბორატორია ფარავს mock-ების troubleshooting-ის დავალებებს: CKAD mock 01 (№4 — fix
ReplicaSet); troubleshooting-ის ზოგადი უნარი CKA mock 01/02-იდან (სტატუსების, Endpoints-ის,
კონფიგურაციის გარჩევა) და CKAD mock 02 (№7/№8 — fix ingress/netpol).

## კლასტერისა და რესურსების წაშლა

```bash
TASK=114 make delete_cka_task
```
