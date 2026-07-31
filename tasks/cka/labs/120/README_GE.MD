[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 120 — Drill-ები: სერვისები და ქსელი

## აღწერა

სიჩქარის ტრენაჟორი დომენზე Services & Networking. მოკლე დამოუკიდებელი დავალებები
Service-ების შექმნაზე (ClusterIP, NodePort, headless), Ingress-სა და NetworkPolicy-ზე,
პლუს ბლოკი JSONPath-ზე.

დავალებები გამოცდის სტილშია გაფორმებული და მათი შემოწმება ავტომატურად ხდება ბრძანებით
`check_result`. drill-ის მიზანი თეორიის განხილვა არ არის, არამედ სიჩქარე და კუნთოვანი
მეხსიერება: „ხელის მოკიდება“ და გამოცდის ტემპში ჩაჯდომა. JSONPath-დავალებების პასუხების
ფაილები ინახება `/home/ubuntu/answers/`-ში.

## მიზანი

განამტკიცოთ კურსის თავების მასალა:

- [თავი 7. Services: ClusterIP, NodePort, LoadBalancer, Endpoints](../../course/07/ge.md) — Service-ების ტიპები, გამოქვეყნება `expose`-ით, Endpoints
- [თავი 31. Service შიგნიდან, DNS და CoreDNS](../../course/31/ge.md) — headless-Service (`clusterIP: None`), DNS-სახელები
- [თავი 32. Ingress და Ingress-კონტროლერები](../../course/32/ge.md) — მარშრუტიზაცია ჰოსტისა და გზის მიხედვით backend-Service-ზე
- [თავი 34. NetworkPolicy](../../course/34/ge.md) — default-deny, podSelector, policyTypes

## რას ვაკეთებთ და რისთვის

| ბლოკი | ამოცანები | უნარი |
|-------|-----------|-------|
| **Service-ები** | Deployment `web`, ClusterIP, NodePort, headless | დატვირთვის სწრაფად გამოქვეყნება Service-ის სხვადასხვა ტიპით (თავები 7, 31) |
| **მარშრუტიზაცია და იზოლაცია** | Ingress `web-ing`, NetworkPolicy `deny-all` | Ingress-ის წესები ჰოსტის მიხედვით და ტრაფიკის default-deny (თავები 32, 34) |
| **JSONPath** | Service `web-np`-ის nodePort → ფაილში | მონაცემების ამოღება `-o jsonpath`-ით ტაიმერის ქვეშ (თავი 47) |

## ინფრასტრუქტურა

გარემო იშლება AWS-ში (`eu-central-1`) Terragrunt-ის მეშვეობით და შედგება:

| კომპონენტი | აღწერა                                                            |
|------------|-------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` საჯარო ქვექსელებით                             |
| `ssh-keys` | SSH-გასაღებები node-ებზე წვდომისთვის                               |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ერთკვანძიანი |
| `worker`   | სამუშაო მანქანა `kubectl`-ით და `check_result`-ით                  |

ინსტანსები: `t3.medium` (master), Ubuntu `22.04`. კლასტერი ერთკვანძიანია — master-ს
მოშორებულია taint `control-plane`, ამიტომ pod-ები პირდაპირ მასზე იგეგმება.

## განთავსება

```bash
TASK=120 make run_cka_task
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
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით namespace (სახელების სივრცე) `net`, შემდეგ მასში Deployment `web` image-ით `viktoruj/ping_pong:latest` და 2 რეპლიკით (`kubectl create ns net`, `kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2`). |
| მიღების კრიტერიუმები | - Deployment `web` (ns `net`): 2 მზა რეპლიკა. |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | გამოაქვეყნეთ Deployment `web` როგორც ClusterIP ტიპის Service (სერვისი) სახელით `web-svc` პორტზე 80 (`kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080`). |
| მიღების კრიტერიუმები | - Service `web-svc` (ns `net`): Endpoints არ არის ცარიელი. |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით NodePort ტიპის Service `web-np` `web`-სთვის ფიქსირებული `nodePort: 30080`-ით (`kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080`). |
| მიღების კრიტერიუმები | - Service `web-np`: ტიპი `NodePort`, `nodePort` 30080. |
---
|        **4**        | **Headless-Service**                                        |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით headless-Service `web-h` `clusterIP: None`-ით `web`-ის Pod-ებისთვის (სელექტორი `app=web`). Headless-Service DNS-ჩანაწერებს პირდაპირ Pod-ებზე გასცემს, ვირტუალურ IP-ს გვერდის ავლით. |
| მიღების კრიტერიუმები | - Service `web-h`: `clusterIP` = `None`. |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით Ingress `web-ing` namespace `net`-ში: ჰოსტი `web.local`, გზა `/` მიმართავს backend-Service `web-svc`-ზე პორტ 80-ზე (`kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"`). |
| მიღების კრიტერიუმები | - ჰოსტის წესი `web.local` → backend Service `web-svc`, პორტი 80. |
---
|        **6**        | **NetworkPolicy (default-deny)**                            |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით NetworkPolicy `deny-all` namespace `net`-ში ცარიელი `podSelector: {}`-ით (ვრცელდება ყველა Pod-ზე) და `policyTypes: [Ingress]`-ით — პოლიტიკა კრძალავს ყველა შემომავალ ტრაფიკს. |
| მიღების კრიტერიუმები | - NetworkPolicy `deny-all`: `policyTypes` შეიცავს `Ingress`-ს, `podSelector` ცარიელია. |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | ამოიღეთ Service `web-np`-ის `nodePort` `-o jsonpath`-ით და შეინახეთ `/home/ubuntu/answers/nodeport.txt`-ში (გზა `{.spec.ports[0].nodePort}`). |
| მიღების კრიტერიუმები | - მნიშვნელობა `nodeport.txt`-ში ემთხვევა Service `web-np`-ის `.spec.ports[0].nodePort`-ს. |
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

დომენი Services & Networking (20% CKA / 20% CKAD) — Service-ების, Ingress-ისა და
NetworkPolicy-ის ბაზისური გამეორებები.

## კლასტერისა და რესურსების წაშლა

```bash
TASK=120 make delete_cka_task
```
