[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# Istio: პრაქტიკული თვითსწავლების კურსი

პრაქტიკული კურსი Istio service mesh-ის შესახებ, რომელიც დაკავშირებულია ლაბორატორიულ სამუშაოებთან
(`tasks/ica/labs`). განკუთვნილია ინჟინრებისთვის, რომლებმაც CKA გაიარეს. ნაწილი 1 მოიცავს ICA გამოცდას,
ნაწილი 2 კი - რეალურ გარემოში ექსპლუატაციის best practices-ს.

სტრუქტურა: თითოეული თემა დანომრილ საქაღალდეშია. მათში ლოკალიზებული ფაილებია განთავსებული.
ძირითადი ენა რუსულია (`ru.md`), თარგმანები კი მის საფუძველზე იქმნება.

ხელმისაწვდომი ლოკალიზაციები (კურსის თავები და ლაბორატორიული სამუშაოები სრულადაა თარგმნილი):

- 🇷🇺 რუსული - `ru.md` (ძირითადი, ჭეშმარიტების წყარო)
- 🇬🇧 ინგლისური - `en.md`
- 🇪🇸 ესპანური - `es.md`
- 🇫🇷 ფრანგული - `fr.md`
- 🇩🇪 გერმანული - `de.md`
- 🇬🇪 ქართული - `ge.md`
- 🇹🇼 ტრადიციული ჩინური - `tw.md`
- 🇯🇵 იაპონური - `jp.md`

ენებს შორის გადართვა შესაძლებელია თითოეული თავის პირველ სტრიქონში და ამ სარჩევის
სათაურში მოცემული ბმულებით. საცდელი გამოცდები (`tasks/ica/mock`) მხოლოდ ინგლისურადაა ხელმისაწვდომი.

## სარჩევი

### ნაწილი 1. საფუძვლები და ICA-სთვის მომზადება

1. [შესავალი service mesh-სა და Istio-ს არქიტექტურაში](01/ge.md)
2. [Istio-ს ინსტალაცია და კონფიგურაცია](02/ge.md)
3. [Istio-ს განახლება: Helm, რევიზიები, canary და in-place](03/ge.md)
4. [Data plane: Envoy და sidecar injection](04/ge.md)
5. [ტრაფიკის მართვა: Gateway, VirtualService, DestinationRule](05/ge.md)
6. [რელიზის სტრატეგიები: canary, header-routing, traffic mirroring](06/ge.md)
7. [დატვირთვის დაბალანსება და locality-aware failover](07/ge.md)
8. [მდგრადობა: fault injection, timeouts, retries, circuit breaking](08/ge.md)
9. [Edge TLS: ingress რეჟიმებში SIMPLE, MUTUAL, PASSTHROUGH](09/ge.md)
10. [TCP, gRPC და WebSocket მარშრუტიზაცია](10/ge.md)
11. [Kubernetes Gateway API](11/ge.md)
12. [Egress: ServiceEntry, egress gateway, TLS origination](12/ge.md)
13. [mTLS და PeerAuthentication: Zero Trust მოდელი](13/ge.md)
14. [AuthorizationPolicy: service-to-service ავტორიზაცია](14/ge.md)
15. [მომხმარებელთა ავთენტიკაცია: RequestAuthentication და JWT](15/ge.md)
16. [სერტიფიკატების მართვა: მორგებული CA, cert-manager და istio-csr](16/ge.md)
17. [Observability: Prometheus, Grafana, Jaeger, Kiali](17/ge.md)
18. [Telemetry API: access logs და განაწილებული tracing](18/ge.md)
19. [Sidecar scoping და proxy-ის კონფიგურაციის ოპტიმიზაცია](19/ge.md)
20. [Rate limiting: მოთხოვნების ლოკალური შეზღუდვა](20/ge.md)
21. [Data plane-ის გაფართოება: EnvoyFilter, Lua და WasmPlugin](21/ge.md)
22. [Ambient mode: ztunnel და waypoint proxy](22/ge.md)
23. [StatefulSet და headless სერვისები mesh-ში](23/ge.md)
24. [Istio-ს პრობლემების დიაგნოსტიკა](24/ge.md)

### ნაწილი 2. რეალურ გარემოში გამოყენების best practices

25. [პროგრესული მიწოდება Flagger-ით](25/ge.md)
26. [პროდაქშენის მიგრაცია შეფერხების გარეშე: ingress-nginx → Istio](26/ge.md)
27. [Istio EKS-ზე: პროდაქშენისთვის ინსტალაცია](27/ge.md)
28. [მულტიკლასტერული mesh](28/ge.md)
29. [არა-Kubernetes დატვირთვები: VM mesh-ში](29/ge.md)
30. [Control plane-ის წარმადობა და ექსპლუატაცია](30/ge.md)
31. [ჰარდენინგი და mesh-ის საფრთხეების მოდელი](31/ge.md)

### გამოცდისთვის მომზადება

32. [ICA გამოცდა: ფორმატი და მომზადება](32/ge.md)
