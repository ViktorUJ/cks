[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 119 — სიჩქარის დრილები და JSONPath

## აღწერა

სიჩქარის ტრენაჟორი CKA/CKAD-სთვის: მოკლე, ერთგვაროვანი დავალებები ობიექტების იმპერატიულ
შექმნაზე (Pod, Deployment, Service, ConfigMap, Secret) და ცალკე ბლოკი `-o jsonpath`-ზე —
კლასტერის ობიექტებიდან მონაცემების ამოღება ფაილებში.

დავალებები გამოცდის სტილშია გაფორმებული და მათი შემოწმება ავტომატურად ხდება ბრძანებით
`check_result`. დრილის მიზანი თეორიის განხილვა არ არის, არამედ სიჩქარე და კუნთოვანი მეხსიერება:
„ხელის მომარჯვება“ იმპერატიულ ბრძანებებზე და გამოცდის ტემპში ჩაჯდომა (~6-8 წუთი დავალებაზე).
JSONPath-დავალებების პასუხების ფაილები ინახება `/home/ubuntu/answers/`-ში.

## მიზანი

განამტკიცოთ კურსის თავების მასალა:

- [თავი 3. მუშაობა kubectl-თან: იმპერატიული და დეკლარაციული მიდგომები](../../course/03/ge.md) — სწრაფი იმპერატიული ბრძანებები, `--dry-run=client -o yaml`, ობიექტების გენერატორები
- [თავი 47. CKAD გამოცდა: JSONPath და kubectl-ის პროდუქტიულობა](../../course/47/ge.md) — მონაცემების ამოღება `-o jsonpath`-ით, custom-columns, `--sort-by`
- [თავი 48. CKA გამოცდა: დროის მენეჯმენტი და სტრატეგია](../../course/48/ge.md) — დროის განაწილება და დავალებების ამოხსნის რიგი

## რას ვაკეთებთ და რისთვის

| ბლოკი | დავალებები | უნარი |
|-------|------------|-------|
| **დრილები** | namespace, Deployment, Service, ConfigMap, Secret | იმპერატიული ბრძანებების სიჩქარე, `--dry-run` (თავი 3) |
| **JSONPath** | node-ების ვერსიები, Pod-ების image-ები, Service-ის ClusterIP → ფაილებში | `-o jsonpath`, მონაცემების ამოღება ტაიმერის ქვეშ (თავი 47) |

## ინფრასტრუქტურა

გარემო იშლება AWS-ში (`eu-central-1`) Terragrunt-ის მეშვეობით და შედგება:

| კომპონენტი | აღწერა                                                              |
|------------|---------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` საჯარო ქვექსელებით                               |
| `ssh-keys` | SSH-გასაღებები node-ებზე წვდომისთვის                                 |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ერთკვანძიანი |
| `worker`   | სამუშაო მანქანა `kubectl`-ით და `check_result`-ით                     |

ინსტანსები: `t4g.medium` (master), Ubuntu `22.04`. კლასტერი ერთკვანძიანია — master-ს
მოშორებულია taint `control-plane`, ამიტომ pod-ები პირდაპირ მასზე იგეგმება.

## განთავსება

```bash
TASK=119 make run_cka_task
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
|        **1**        | **Namespace**                                                |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით namespace (სახელების სივრცე) `drill` — მასში იცხოვრებს დანარჩენი დავალებების ობიექტები (`kubectl create namespace drill`). |
| მიღების კრიტერიუმები | - namespace `drill` არსებობს. |
---
|        **2**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | namespace `drill`-ში შექმენით Deployment `api` image-ით `viktoruj/ping_pong:latest` და 3 რეპლიკით (`kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3`). |
| მიღების კრიტერიუმები | - Deployment `api` `drill`-ში: 3 მზა რეპლიკა. |
---
|        **3**        | **Service**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | გამოაქვეყნეთ Deployment `api` როგორც ClusterIP ტიპის Service (სერვისი) სახელით `api-svc` პორტზე 80 (`kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080`). |
| მიღების კრიტერიუმები | - Service `api-svc` (ns `drill`): Endpoints არ არის ცარიელი. |
---
|        **4**        | **ConfigMap და Secret**                                     |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | namespace `drill`-ში შექმენით ConfigMap `cfg` გასაღებით `APP_COLOR=blue` და Secret `sec` გასაღებით `PASSWORD` (მნიშვნელობა ნებისმიერი). გამოიყენეთ `--from-literal`. |
| მიღების კრიტერიუმები | - `cfg.data.APP_COLOR=blue`;<br/>- Secret `sec`-ს აქვს გასაღები `PASSWORD`. |
---
|        **5**        | **JSONPath: node-ების ვერსიები**                            |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | ამოიღეთ ყველა node-ის `kubeletVersion` `-o jsonpath`-ით და შედეგი შეინახეთ ფაილში `/home/ubuntu/answers/versions.txt` (გზა `{.items[*].status.nodeInfo.kubeletVersion}`). |
| მიღების კრიტერიუმები | - `versions.txt`-ის შიგთავსი ემთხვევა node-ებზე `jsonpath`-ის გამოტანას. |
---
|        **6**        | **JSONPath: Pod-ების image-ები**                            |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | ამოიღეთ namespace `drill`-ის ყველა Pod-ის კონტეინერების image-ები `-o jsonpath`-ით და შეინახეთ `/home/ubuntu/answers/images.txt`-ში (გზა `{.items[*].spec.containers[*].image}`). |
| მიღების კრიტერიუმები | - `images.txt`-ში image-ების ნაკრები ემთხვევა `drill`-ის Pod-ებზე `jsonpath`-ის გამოტანას. |
---
|        **7**        | **JSONPath: Service-ის ClusterIP**                          |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | ამოიღეთ Service `api-svc`-ის ClusterIP `-o jsonpath`-ით და შეინახეთ `/home/ubuntu/answers/api-ip.txt`-ში (გზა `{.spec.clusterIP}`). |
| მიღების კრიტერიუმები | - `api-ip.txt`-ში მნიშვნელობა ემთხვევა Service `api-svc`-ის `.spec.clusterIP`-ს. |
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

სიჩქარისა და JSONPath-ის ბაზისური უნარები, რომლებიც მოთხოვნადია CKA-სა და CKAD-ის ყველა
mock-გამოცდაში.

## კლასტერისა და რესურსების წაშლა

```bash
TASK=119 make delete_cka_task
```
