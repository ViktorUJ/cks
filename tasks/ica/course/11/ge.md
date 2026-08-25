[Русская версия](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# თავი 11. Kubernetes Gateway API

> **შემდეგ რა არის.** 5-10 თავებში ტრაფიკს Istio-ს რესურსების - Gateway-ისა და
> VirtualService-ის - საშუალებით ვმართავდით. თუმცა Kubernetes-ში იმავე მიზნისთვის საერთო
> სტანდარტი - Kubernetes Gateway API - გამოჩნდა. Istio მას სრულად უჭერს მხარს და ingress-ის
> მომავალად მიიჩნევს. ამ თავში გავარჩევთ, რა არის ის, შევადარებთ Istio-ს რესურსებს და, რაც
> მთავარია, გავიგებთ, როდის რომელი სჯობს გამოვიყენოთ.

## 11.1. რატომ გახდა საჭირო ცალკე სტანდარტი

`networking.istio.io`-ს რესურსები `Gateway` და `VirtualService` შესანიშნავად მუშაობს,
მაგრამ ერთი ნაკლი აქვს: ეს **Istio-სთვის სპეციფიკური** API-ა. თუ ხვალ mesh-ის ან
ingress-კონტროლერის შეცვლას გადაწყვეტთ, ყველა მანიფესტის სხვა პროდუქტისთვის გადაწერა
მოგიწევთ. თითოეულ გადაწყვეტას (Istio, nginx, Traefik, ღრუბლოვან კარიბჭეებს) რესურსების
საკუთარი ნაკრები ჰქონდა.

Kubernetes-ის საზოგადოებამ ეს პრობლემა ერთიანი სტანდარტით - **Kubernetes Gateway API**-ით
(`gateway.networking.k8s.io`) - გადაჭრა. ეს შემომავალი ტრაფიკის მართვის ვენდორ-ნეიტრალური
API-ა, რომელსაც მრავალი პროდუქტი, მათ შორის Istio, ახორციელებს. სტანდარტის მიხედვით ერთხელ
წერთ და ის ნებისმიერ თავსებად რეალიზაციაზე მუშაობს.

თავიდანვე უნდა გაგაფრთხილოთ სახელებში შესაძლო აღრევის შესახებ. არსებობს ორი განსხვავებული
რესურსი სიტყვით `Gateway`:

- `networking.istio.io`-ს `Gateway` - Istio-ს რესურსია (მას მე-5 თავიდან ვიყენებდით).
- `gateway.networking.k8s.io`-ს `Gateway` - Kubernetes Gateway API სტანდარტის რესურსია.

ეს სხვადასხვა სტრუქტურის მქონე განსხვავებული API-ებია. შემდგომში „Gateway API“-ში სწორედ
მეორე, სტანდარტულ API-ს ვიგულისხმებთ.

## 11.2. Gateway API-ს როლები და რესურსები

Gateway API-ში პასუხისმგებლობა რამდენიმე რესურსს შორისაა განაწილებული, თითოეული თავისი
როლისთვის:

| რესურსი | რაზე აგებს პასუხს | ანალოგი Istio-ში |
|--------|-------------|----------------|
| `GatewayClass` | რეალიზაციის ტიპი (ვინ ამუშავებს ტრაფიკს) | განისაზღვრება ინსტალაციისას |
| `Gateway` | რას მოუსმინოს: პორტებს, პროტოკოლებს, TLS-ს | Istio `Gateway` |
| `HTTPRoute` | HTTP მარშრუტიზაციის წესები | Istio `VirtualService` |

`HTTPRoute`-ის გარდა, სხვადასხვა პროტოკოლისთვის სხვა მარშრუტებიც არსებობს: `TCPRoute`,
`TLSRoute`, `GRPCRoute`. იდეა იგივეა, რაც Istio-ში: ცალკეა „რას ვუსმენთ“ (Gateway) და
ცალკე - „სად ვაგზავნით“ (Route).

## 11.3. Gateway API-ს CRD-ების ინსტალაცია

მნიშვნელოვანი პრაქტიკული მომენტი, რომელიც ხშირად დაბრკოლებად იქცევა: Gateway API-ს
რესურსები არის **CRD-ები, რომლებიც კლასტერში ნაგულისხმევად შეიძლება არ იყოს**. Istio
სტანდარტს ახორციელებს, მაგრამ თავად განსაზღვრებები (`GatewayClass`, `Gateway`,
`HTTPRoute`…) საზოგადოებამ ან Istio-მ უნდა დააყენოს. თუ CRD-ები დაყენებული არ არის,
თქვენი მანიფესტები უბრალოდ არ გამოყენდება.

არსებობის შემოწმება:

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

თუ CRD არ არის, დააყენეთ ისინი სტანდარტის ოფიციალური რელიზიდან (არხი `standard`
სტაბილურ რესურსებს შეიცავს, `experimental` კი დამატებით `TCPRoute`/`TLSRoute`-სა და
სხვებსაც):

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Istio ინსტალაციისას ავტომატურად აყენებს `GatewayClass`-ს სახელით `istio` (istiod CRD-ებს
აკვირდება და კლასს ქმნის). შეამოწმეთ, რომ კლასი ადგილზეა:

```bash
kubectl get gatewayclass istio
```

## 11.4. Gateway-ისა და HTTPRoute-ის მაგალითი

ავამუშაოთ კარიბჭე 80-ე პორტზე და მთელი ტრაფიკი `reviews` სერვისისკენ მივმართოთ.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio    # ამ იმპლემენტაციას უზრუნველყოფს Istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-route
spec:
  parentRefs:
  - name: my-gateway         # რომელ Gateway-ს არის მიბმული მარშრუტი
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: reviews          # პირდაპირ Kubernetes Service-ის სახელი
      port: 8080
```

```mermaid
flowchart LR
    C["კლიენტი"] --> GW["Gateway<br>class: istio"]
    GW --> HR["HTTPRoute<br>მარშრუტების წესები"]
    HR --> S["Service reviews"]
    style C fill:#673ab7,color:#fff
    style GW fill:#326ce5,color:#fff
    style HR fill:#326ce5,color:#fff
    style S fill:#0f9d58,color:#fff
```

ძირითადი ველები:

- **`gatewayClassName: istio`** - მიუთითებს, რომ ამ Gateway-ს Istio ახორციელებს. ეს იმის
  ანალოგია, თუ როგორ ვუკავშირებდით Istio Gateway-ს ingress gateway-ს `selector`-ის
  საშუალებით.
- HTTPRoute-ში **`parentRefs`** მარშრუტს კონკრეტულ Gateway-ს უკავშირებს. Istio-ში ამ როლს
  VirtualService-ის ველი `gateways` ასრულებდა.
- **`backendRefs`** პირდაპირ მიუთითებს Kubernetes Service-სა და პორტზე. საბაზისო Gateway
  API-ში subsets და DestinationRule არ არსებობს - ვერსიები და პოლიტიკები სხვაგვარად
  აღიწერება.

კიდევ ერთი მოსახერხებელი შესაძლებლობა: როდესაც ქმნით `Gateway`-ს
`gatewayClassName: istio`-თი, Istio-ს შეუძლია ამ კარიბჭისთვის ცალკე Envoy deployment
ავტომატურად გაშალოს. ingress gateway-ს წინასწარ დაყენება საჭირო არ არის - ის კონკრეტული
Gateway-სთვის ჩნდება.

## 11.5. TLS: HTTPS Gateway API-ზე

მე-9 თავის Edge TLS Gateway API-ში საკუთარი ველებით აღიწერება. HTTPS-listener ცხადდება
`protocol: HTTPS`-ითა და `tls` ბლოკით, სადაც მოცემულია რეჟიმი და სერტიფიკატის შემცველ
Secret-ზე მითითება:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: myapp.example.com
    tls:
      mode: Terminate                # gateway ამთავრებს TLS-ს (Istio-ს SIMPLE-ის ანალოგი)
      certificateRefs:
      - kind: Secret
        name: myapp-cert             # იგივე tls-Secret, რაც მე-9 თავში
    allowedRoutes:
      namespaces:
        from: All                    # რომელ namespace-ებს შეუძლიათ მარშრუტების მიბმა (იხ. 11.7)
```

მე-9 თავის რეჟიმებთან შესაბამისობა:

- **`mode: Terminate`** - კარიბჭე TLS-ს გაშიფრავს (როგორც `SIMPLE`/`MUTUAL` Istio-ში).
  კლიენტის სერტიფიკატი (`MUTUAL`-ის ანალოგი) კონფიგურირდება
  `frontendValidation`/`BackendTLSPolicy`-ის საშუალებით და სტანდარტის ვერსიაზეა
  დამოკიდებული.
- **`mode: Passthrough`** - კარიბჭე ტრაფიკს არ გაშიფრავს და ის SNI-ის მიხედვით გამჭოლად
  გადის (როგორც `PASSTHROUGH`); მისთვის `HTTPRoute`-ის ნაცვლად `TLSRoute` გამოიყენება.

სერტიფიკატი ინახება ჩვეულებრივ Kubernetes `Secret`-ში, რომლის ტიპია `tls` - მისი გაცემა
ასევე შეიძლება cert-manager-ით (თავი 9), უბრალოდ ახლა მარშრუტი მას `certificateRefs`-ის
და არა `credentialName`-ის საშუალებით უთითებს.

## 11.6. Canary და ფილტრები HTTPRoute-ში

ტრაფიკის წონითი განაწილება (canary მე-6 თავიდან) Gateway API-ში **სტანდარტული**
შესაძლებლობაა და არა გაფართოება: `backendRefs`-ს აქვს ველი `weight`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-canary
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - backendRefs:
    - name: reviews-v1       # ტრაფიკის 90% v1-ზე
      port: 8080
      weight: 90
    - name: reviews-v2       # 10% v2-ზე
      port: 8080
      weight: 10
```

გაითვალისწინეთ: Gateway API-ში subsets/DestinationRule არ არის, ამიტომ სხვადასხვა ვერსია
არის **სხვადასხვა Kubernetes Service** (`reviews-v1`, `reviews-v2`) და არა ერთი სერვისის
subset.

HTTPRoute-ს მოთხოვნების შეცვლა **ფილტრებით** (`filters`) შეუძლია - ეს VirtualService-ის
შესაძლებლობების ნაწილის ანალოგია:

```yaml
  rules:
  - filters:
    - type: RequestHeaderModifier      # სათაურების დამატება/მოცილება
      requestHeaderModifier:
        add:
        - name: x-env
          value: prod
    - type: RequestMirror              # ტრაფიკის დამირვა (თავი 6)
      requestMirror:
        backendRef:
          name: reviews-shadow
          port: 8080
    backendRefs:
    - name: reviews
      port: 8080
```

ფილტრების სასარგებლო ტიპებია: `RequestHeaderModifier`/`ResponseHeaderModifier`
(სათაურები), `RequestRedirect` (გადამისამართებები, მათ შორის HTTP→HTTPS), `URLRewrite`
(ბილიკის/ჰოსტის გადაწერა), `RequestMirror` (სარკისებური ასლის შექმნა). თუმცა სტანდარტში
**fault injection** არ არის - ის Istio API-ს ექსკლუზიურ შესაძლებლობად რჩება (თავი 8).

## 11.7. მარშრუტები namespace-ებს შორის: allowedRoutes და ReferenceGrant

Gateway API-ს ძლიერი მხარე namespace-ებს შორის უფლებების მკაფიო და უსაფრთხო გამიჯვნაა.
აქ ორი მექანიზმი მოქმედებს.

**`allowedRoutes` listener-ზე** - Gateway თავად წყვეტს, რომელი namespace-ებიდან შეიძლება
მასზე მარშრუტების მიბმა (`from: Same` - მხოლოდ საკუთარი, `All` - ნებისმიერი, `Selector` -
namespace-ის ჭდეების მიხედვით):

```yaml
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            team: frontend      # მხოლოდ მარშრუტები ამ ჭდის მქონე namespace-იდან
```

**`ReferenceGrant`** - როდესაც ერთი namespace-ის რესურსი **სხვა** namespace-ის რესურსზე
მიუთითებს (მაგალითად, `apps`-ში არსებული HTTPRoute-ს სურს ტრაფიკის `data`-ში არსებულ
Service-ზე გაგზავნა), ეს ნაგულისხმევად აკრძალულია. ნებართვას **სამიზნე** namespace-ში
არსებული `ReferenceGrant` გასცემს:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-apps-to-data
  namespace: data              # namespace, სადაც დევს სამიზნე Service
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: apps            # ვინ მიუთითებს
  to:
  - group: ""
    kind: Service              # რაზე ვრთავთ მითითების უფლებას
```

ეს იცავს თქვენს namespace-ში არსებულ სერვისს უცხო მარშრუტის მიერ ტრაფიკის თქვენი
თანხმობის გარეშე „გადაყვანისგან“ - Istio API-ში ასეთი ჩაშენებული მექანიზმი არ არის.

## 11.8. შედარება Istio API-სთან

| | Istio API | Kubernetes Gateway API |
|---|-----------|------------------------|
| შესასვლელი რესურსები | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| მარშრუტის მიბმა | ველი `gateways` VirtualService-ში | `parentRefs` Route-ში |
| რეალიზაციის არჩევა | `selector` ingress gateway-ზე | `gatewayClassName` |
| ვერსიები/subsets | `DestinationRule` (subsets) | სხვადასხვა Service + `weight` `backendRefs`-ში |
| წონითი Canary | `VirtualService` weight | `backendRefs.weight` (სტანდარტულად) |
| სარკისებური ასლის შექმნა | `VirtualService` mirror | ფილტრი `RequestMirror` (სტანდარტულად) |
| Fault injection | არის | არ არის (მხოლოდ Istio) |
| ბექენდის პოლიტიკები | `DestinationRule` (LB, circuit breaking) | არ არის (მხოლოდ Istio) |
| უფლებების გამიჯვნა namespace-ების მიხედვით | ჩაშენებული არ არის | `allowedRoutes` + `ReferenceGrant` |
| სტანდარტი | Istio-სთვის სპეციფიკური | საერთო, ვენდორ-ნეიტრალური |
| პორტირებადობა | მხოლოდ Istio | ნებისმიერი თავსებადი ingress/mesh |

ცხრილის მთავარი დასკვნა: Gateway API უპირატესია სტანდარტულობით, პორტირებადობითა და გუნდებს
შორის უფლებების გამიჯვნით, Istio API კი - მიმღებ მხარეს შესაძლებლობების სისრულით
(`DestinationRule`: დაბალანსება, circuit breaking, subsets) და fault injection-ით.
სარკისებური ასლის შექმნა და წონითი canary ორივე API-ში არის.

## 11.9. რა და როდის გამოვიყენოთ (best practices)

პრაქტიკული რეკომენდაციები რეალურ პროექტებში არჩევანის გასაკეთებლად.

**აირჩიეთ Kubernetes Gateway API, როდესაც:**

- ახალ პროექტს იწყებთ და აქტუალური სტანდარტის გამოყენება გსურთ;
- პორტირებადობა მნიშვნელოვანია: არ გსურთ მანიფესტების დონეზე Istio-ზე დამოკიდებულება;
- გუნდებს შორის პასუხისმგებლობის მკაფიო გაყოფა გჭირდებათ (პლატფორმის გუნდი ფლობს
  `Gateway`-ს, პროდუქტის გუნდები კი - საკუთარ `HTTPRoute`-ებს);
- მარშრუტიზაციის სტანდარტული შესაძლებლობები (ბილიკის, სათაურების, წონების მიხედვით)
  საკმარისია;
- მუშაობთ **ambient mode**-თან: waypoint-proxy-ების (თავი 22) კონფიგურაცია სწორედ Gateway
  API-ით ხდება.

**დარჩით Istio API-ზე (VirtualService/DestinationRule), როდესაც:**

- გჭირდებათ ფუნქციები, რომლებიც სტანდარტში არ არის: **fault injection** (თავი 8),
  `DestinationRule`-ის პოლიტიკები (დეტალური დაბალანსება, circuit breaking, outlier
  detection, subsets), მარშრუტების დელეგირება;
- უკვე გაქვთ Istio API-ზე აგებული ბევრი მოქმედი მანიფესტი და მათი გადაწერის მიზეზი არ
  არსებობს.

(სარკისებური ასლის შექმნა და წონითი canary ორივე API-ში არის, ამიტომ მხოლოდ მათ გამო
გადასვლა ან დარჩენა საჭირო არ არის.)

### კლასიკური Kubernetes Ingress რესურსი (legacy)

შესვლის მესამე ვარიანტიც არსებობს - ჩვეულებრივი Kubernetes `Ingress`
(`networking.k8s.io/v1`), იგივე, რომელსაც nginx-ingress-თან, Traefik-სა და ღრუბლოვან
კონტროლერებთან იყენებდნენ. Istio-ს შეუძლია მისთვის ingress-კონტროლერის როლი შეასრულოს:
istio ingress gateway კითხულობს `Ingress` რესურსებს, თუ მათ კლასი `istio` აქვთ
მითითებული.

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: istio
spec:
  controller: istio.io/ingress-controller
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reviews-ingress
  namespace: app
spec:
  ingressClassName: istio          # ემსახურება istio ingress gateway
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /reviews
        pathType: Prefix
        backend:
          service:
            name: reviews
            port:
              number: 8080
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-cert          # tls-Secret, როგორც მე-9 თავში
```

რატომ არის ეს **legacy** და რატომ არ ღირს მისი არჩევა ახალი ტრაფიკისთვის:

- თავად `Ingress` სტანდარტს შესაძლებლობების ძალიან მწირი ნაკრები აქვს: ჰოსტი, ბილიკი,
  TLS - და ეს ყველაფერია. არავითარი წონები, სარკისებური ასლის შექმნა, გადამისამართებები ან
  სათაურების მიხედვით split.
- ყველა დამატებითი შესაძლებლობა კონტროლერის **არასტანდარტული ანოტაციებით** ხორციელდება
  (როგორც nginx-ში, თავი 26). ანოტაციები კონტროლერებს შორის შეუთავსებელია, ხოლო Istio მათ
  მხოლოდ მცირე ქვესიმრავლეს უჭერს მხარს - ჩვეული `nginx.ingress.kubernetes.io/*`-ის
  უმეტესობა არ მუშაობს.
- ინდუსტრიისა და თავად Istio-ს განვითარება Gateway API-სკენ მიდის, რომელიც სწორედ
  „შემდეგი თაობის `Ingress`“-ად შეიქმნა.

პრაქტიკული დასკვნა: კლასიკურ `Ingress`-ს Istio-ში მხოლოდ მიგრაციისას ძველ მანიფესტებთან
თავსებადობისთვის ინარჩუნებენ (თავი 26). ახალი ingress-ისთვის აირჩიეთ Kubernetes Gateway
API ან, თუ Istio-ს ფუნქციები გჭირდებათ, - Istio `Gateway` + `VirtualService`.

**ზოგადი წესები:**

- ერთი და იგივე მარშრუტი ერთდროულად VirtualService-ითაც და HTTPRoute-ითაც არ აღწეროთ - ეს
  გაუგებრობასა და კონფლიქტებს იწვევს. ერთი სერვისისთვის რომელიმე ერთი აირჩიეთ.
- Istio API არსად ქრება და სრულად არის მხარდაჭერილი, ამიტომ მიგრაცია შეიძლება თანდათანობით
  განხორციელდეს: ახალი სერვისები Gateway API-ზე, ძველები კი უცვლელად რჩება.
- ინდუსტრიის მოძრაობის მიმართულება Gateway API-სკენაა, ამიტომ მისი ცოდნა და ათვისება
  ღირს, მაშინაც კი, თუ დღეს თქვენი ძირითადი ტრაფიკი Istio API-ზეა.

## 11.10. თავის შეჯამება

- Kubernetes Gateway API (`gateway.networking.k8s.io`) შემომავალი ტრაფიკის მართვის
  ვენდორ-ნეიტრალური სტანდარტია; Istio მას ახორციელებს.
- ერთმანეთში არ აგერიოთ Istio `Gateway` და Gateway API-ს `Gateway` - ისინი სხვადასხვა
  რესურსებია.
- როლები Gateway API-ში: `GatewayClass` (რეალიზაცია), `Gateway` (რას მოუსმინოს),
  `HTTPRoute` და სხვა Route-ები (სად მიმართოს).
- მარშრუტის კარიბჭეზე მიბმა ხდება `parentRefs`-ით, რეალიზაციის არჩევა კი -
  `gatewayClassName: istio`-თი.
- Gateway API-ს CRD-ები ნაგულისხმევად შეიძლება არ იყოს - ისინი ცალკე ყენდება (არხი
  `standard`), ხოლო `GatewayClass istio`-ს Istio თავად ქმნის.
- TLS: HTTPS-listener `tls.mode: Terminate`/`Passthrough`-ით და Secret-ზე
  `certificateRefs`-ით მითითებით (`credentialName`-ის ანალოგი); სერტიფიკატებს ასევე გასცემს
  cert-manager.
- წონითი Canary (`backendRefs.weight`, თუმცა ვერსიები სხვადასხვა Service-ებია) და
  სარკისებური ასლის შექმნა (ფილტრი `RequestMirror`) სტანდარტულად არის ხელმისაწვდომი; fault
  injection და `DestinationRule`-ის პოლიტიკები - მხოლოდ Istio API-ში.
- უფლებების გამიჯვნა namespace-ებს შორის: `allowedRoutes` listener-ზე და `ReferenceGrant`
  cross-namespace მითითებებისთვის - Istio API-ში ჩაშენებული ანალოგი არ არის.
- Best practice: Gateway API ახალი ingress-ისთვის, სტანდარტული სცენარებისა და
  ambient-ისთვის; Istio API - როდესაც fault injection ან DestinationRule-ის პოლიტიკებია
  საჭირო; ერთი მარშრუტისთვის ორივე არ აურიოთ.
- კლასიკურ Kubernetes `Ingress`-საც (`ingressClassName: istio`) ემსახურება Istio, თუმცა ეს
  legacy-ა: შესაძლებლობები მწირია, გაფართოებული ფუნქციები კი არასტანდარტული ანოტაციებითაა
  (მცირე ქვესიმრავლე). მას მიგრაციისას თავსებადობისთვის ინარჩუნებენ და ახალი ტრაფიკისთვის
  არ ირჩევენ.

## 11.11. თვითშემოწმების კითხვები

1. რა პრობლემას წყვეტს Kubernetes Gateway API Istio API-სთან შედარებით?
2. რით განსხვავდება ერთმანეთისგან ორი რესურსი სახელით `Gateway`?
3. Gateway API-ს რომელი რესურსები შეესაბამება Istio Gateway-სა და VirtualService-ს?
4. რაზე აგებს პასუხს `gatewayClassName` და `parentRefs`?
5. რა შემთხვევებში სჯობს Istio VirtualService/DestinationRule-ზე დარჩენა? რომელი ფუნქციები
   არ არის Gateway API-ში?
6. რატომ არ ღირს ერთი მარშრუტის ერთდროულად ორივე API-ში აღწერა?
7. როგორ უნდა გამართოთ Gateway API-ში HTTPS და წონითი canary? რით განსხვავდება canary
   Istio-სგან (რა ხდება subsets-თან)?
8. რისთვის არის საჭირო `allowedRoutes` და `ReferenceGrant`? უსაფრთხოების რომელ პრობლემას
   წყვეტს ისინი?
9. რა უნდა შეამოწმოთ, თუ Gateway API-ს მანიფესტები კლასტერში არ გამოიყენება?
10. შეუძლია თუ არა Istio-ს კლასიკური Kubernetes `Ingress`-ის მომსახურება და რატომ მიიჩნევა
    ის legacy-დ? როდის იყენებენ მას მაინც?

## პრაქტიკა

გამართეთ ingress Kubernetes Gateway API-ს საშუალებით (Gateway + HTTPRoute):

🧪 ლაბორატორია 16: [tasks/ica/labs/16](../../labs/16/README_GE.MD)

---
[სარჩევი](../README_GE.md) · [თავი 10](../10/ge.md) · [თავი 12](../12/ge.md)