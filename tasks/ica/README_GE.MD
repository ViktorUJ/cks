[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Istio Certified Associate (ICA) - სასწავლო მასალები

<img src="../../docs/images/ICA.png" alt="Istio Certified Associate" width="200">

სრული მომზადება სერტიფიკაციისთვის **Istio Certified Associate (ICA)**: თვითსწავლების
კურსი, პრაქტიკული ლაბორატორიები და სრულფასოვანი საცდელი გამოცდები - ყველაფერი ერთ
ადგილას.

## რა არის შიგნით

| ნაწილი | გზა | რა არის ეს |
|-------|------|-----------|
| **კურსი** | [`course/`](course/README_GE.md) | 32-თავიანი თვითსწავლების კურსი: service mesh-ის იდეიდან პროდაქშენ-ექსპლუატაციამდე |
| **ლაბები** | [`labs/`](labs/) | 35 პრაქტიკული ლაბორატორია რეალურ AWS კლასტერებზე, თითოეული დაკავშირებულია კურსის თავთან |
| **საცდელი გამოცდები** | [`mock/`](mock/) | 2 სრულფასოვანი საცდელი გამოცდა, რომლებიც ნამდვილ ICA-ს იმიტირებს |

რეკომენდებული მარშრუტი: შეისწავლეთ კურსის თავი, განიმტკიცეთ იგი შესაბამისი ლაბით, შემდეგ კი
დროზე გაატარეთ საცდელი გამოცდები.

## კურსი

კურსი ([`course/README_GE.md`](course/README_GE.md)) შედგება 32 თავისგან და განკუთვნილია
ინჟინრებისთვის, რომლებმაც უკვე იციან Kubernetes (CKA დონე):

- **ნაწილი 1 (თავები 1-24)** - საფუძვლები და ICA გამოცდის დომენების სრული დაფარვა
  (ტრაფიკის მართვა, უსაფრთხოება, observability, გაფართოებული სცენარები, troubleshooting,
  ინსტალაცია).
- **ნაწილი 2 (თავები 25-31)** - რეალური სამუშაოს best practices: პროგრესული მიწოდება,
  მიგრაცია downtime-ის გარეშე, Istio EKS-ზე, მულტიკლასტერი, VM-workload-ები, control
  plane-ის წარმადობა, გამკვრივება.
- **გამოცდისთვის მომზადება (თავი 32)** - ICA-ს ფორმატი, რჩევები და ბმულები საცდელ
  გამოცდებზე.

თითოეული თავი მთავრდება ბლოკით **„პრაქტიკა“**, რომელიც მიუთითებს შესაბამის ლაბზე.

## ლაბები

35 პრაქტიკული ლაბორატორია (`labs/01` .. `labs/35`), თითოეული სრულად ლოკალიზებულია 8 ენაზე:
ინგლისური (`README.MD`), რუსული (`README_RU.MD`), ესპანური (`README_ES.MD`), ფრანგული
(`README_FR.MD`), გერმანული (`README_DE.MD`), ქართული (`README_GE.MD`), ტრადიციული
ჩინური (`README_TW.MD`) და იაპონური (`README_JP.MD`). ისინი Terragrunt-ის მეშვეობით
შლიან რეალურ კლასტერებს AWS-ში:

```bash
TASK=01 make run_ica_task      # გაშალეთ ლაბი 01
TASK=01 make delete_ica_task   # წაშალეთ
```

ლაბების თემები (და კურსის თავი, სადაც თეორიაა):

| ლაბი | თემა | თავი |
|------|------|------|
| 01 | Istio-ს ინსტალაცია, Bookinfo, sidecar injection | 2 |
| 02 | Dark launch, header-routing, canary | 5, 6 |
| 03 | Fault injection და retries | 8 |
| 04 | mTLS (PeerAuthentication) + AuthorizationPolicy | 13, 14 |
| 05 | Egress: ServiceEntry, egress gateway, REGISTRY_ONLY | 12 |
| 06 | დატვირთვის დაბალანსება + ტრაფიკის mirroring | 6, 7 |
| 07 | ინსტალაცია Helm-ით + canary-განახლება (რევიზიები) | 3 |
| 08 | Observability: Prometheus/Jaeger/Kiali | 17 |
| 09 | Ambient mode (sidecar-ის გარეშე) | 22 |
| 10 | მდგრადობა: timeout + circuit breaker | 8 |
| 11 | საბოლოო მომხმარებლის ავთენტიფიკაცია: RequestAuthentication + JWT | 15 |
| 12 | Troubleshooting istioctl-ით | 24 |
| 13 | Edge TLS (SIMPLE) | 9 |
| 14 | Locality-aware failover | 7 |
| 15 | ინსტალაცია და კონფიგურაცია (IstioOperator + MeshConfig) | 2 |
| 16 | Kubernetes Gateway API (Gateway + HTTPRoute) | 11 |
| 17 | ლოკალური rate limiting (EnvoyFilter) | 20 |
| 18 | Telemetry API: access logs + tracing | 18 |
| 19 | საკუთარი CA istiod-ში | 16 |
| 20 | mTLS მიგრაცია PERMISSIVE → STRICT | 13 |
| 21 | Sidecar scoping | 19 |
| 22 | TLS origination | 12 |
| 23 | WasmPlugin (WebAssembly) | 21 |
| 24 | Ambient: waypoint proxy + L7 ავტორიზაცია | 22 |
| 25 | პროგრესული მიწოდება Flagger-ით | 25 |
| 26 | დინამიური CA: cert-manager + istio-csr | 16 |
| 27 | EnvoyFilter + Lua | 21 |
| 28 | TCP-მარშრუტიზაცია | 10 |
| 29 | Ingress TLS: MUTUAL და PASSTHROUGH | 9 |
| 30 | StatefulSet და headless-სერვისები | 23 |
| 31 | მიგრაცია downtime-ის გარეშე: ingress-nginx → Istio | 26 |
| 32 | gRPC: per-request დაბალანსება, პორტების დასახელება, retries | 10 |
| 33 | Control plane: წარმადობა და ექსპლუატაცია | 30 |
| 34 | გამკვრივება და საფრთხის მოდელი | 31 |
| 35 | მულტიკლასტერული mesh (multi-primary, multi-network) | 28 |

## საცდელი გამოცდები (mock)

ორი სრულფასოვანი საცდელი გამოცდა ICA-ს ფორმატში:

- **Mock 01** ([`mock/01`](mock/01/README.MD)) - 17 დავალება Istio-ს ბაზისურ კონცეფციებზე.
- **Mock 02** ([`mock/02`](mock/02/README.MD)) - 16 დავალება mesh-ის გაფართოებულ პატერნებზე.

გაატარეთ ისინი დროზე, მინიშნებების გარეშე, და მიაღწიეთ **70%+**.

## მორგებული ტერმინალის გარემო

![Terminal Interface](../../docs/images/cockpit.png)

ინფრასტრუქტურა გაძლევთ წინასწარ კონფიგურირებულ ტერმინალს ინსტრუმენტებითა და
დამხმარეებით, რომლებიც ICA-სთვის მომზადებისთვისაა.

### ხელმისაწვდომი ბრძანებები
- **`time_left`** - რამდენი დრო დარჩა
- **`check_result`** - დავალების შესრულების შემოწმება (`check_result <task>` კონკრეტულისთვის)
- **`hosts`** - ingress gateway-ის ინფორმაცია (NodePort და IP)

### წინასწარ კონფიგურირებული ინსტრუმენტები (bash completion-ით)
- **`kubectl | k`**, **`istioctl`**, **`helm`**, **`yq`**, **`curl`/`wget`**,
  **`podman`**, **`aws`**

### SSH-წვდომა
```bash
ssh <kubernetes_nodename>
```

## სწრაფი დაწყება

```bash
# შედეგის შემოწმება (ყველა დავალება ან კონკრეტული)
check_result
check_result <task_number>

# კლასტერის/ingress-ის ინფორმაცია გარე წვდომის ტესტირებისთვის
hosts

# რამდენი დრო დარჩა დროზე გაშვებისას
time_left
```

## რა არის ნებადართული გამოცდაზე

შეგიძლიათ ისარგებლოთ Istio-ს ოფიციალური დოკუმენტაციით:
**https://istio.io/latest/docs/** და ყველა მისი subdomain-ით. mock-ებში ეს
რეპროდუცირებულია.

## რჩევები

1. **წაიკითხეთ დავალება სიტყვასიტყვით** - ზუსტი სახელები, namespace-ები და specs
   მნიშვნელოვანია.
2. **შეამოწმეთ კონტექსტი** `kubectl config current-context`-ით.
3. **შეამოწმეთ შედეგი** - `curl` sleep-pod-იდან მარშრუტიზაციისა და პოლიტიკების
   შესამოწმებლად.
4. **გამოიყენეთ `istioctl analyze`, `proxy-status`, `proxy-config`** შეცდომების
   მოსაძებნად.
5. **გაარჩიეთ ეტალონური გადაწყვეტები** მცდელობების შემდეგ.

## ხშირი შეცდომები

- **hosts VirtualService-ში**: namespace-ებს შორის ტრაფიკისთვის მიუთითეთ მოკლე სახელი
  და FQDN.
- **Gateway-ის სელექტორები**: უნდა ემთხვეოდეს ingress gateway-ის labels-ს.
- **Sidecar injection**: pod-ებმა უნდა აჩვენონ `2/2` კონტეინერი.
- **კონტექსტის გადართვა**: შეამოწმეთ კლასტერი რესურსების გამოყენებამდე.

---

**წარმატებები ICA სერტიფიკაციაში!** პრაქტიკა წყვეტს - გაიარეთ კურსი, ლაბები და ორივე
mock, სანამ დამაჯერებლად არ ჩაეტევით ტაიმინგში.
