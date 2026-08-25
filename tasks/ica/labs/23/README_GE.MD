[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 23 - WasmPlugin: data plane-ის გაფართოება WebAssembly-ის მეშვეობით

> [საცნობარო გადაწყვეტა](worker/files/solutions/1_GE.MD)

## მიმოხილვა

ზოგჯერ Istio-ს ჩაშენებული CRD-ები (`AuthorizationPolicy`, `EnvoyFilter`) საკმარისი არ
არის - საჭიროა საკუთარი ლოგიკა უშუალოდ data plane-ში. ამისთვის არსებობს
**WebAssembly (Wasm)**: თქვენ წერთ (ან იყენებთ მზა) მოდულს, ხოლო Envoy მას დინამიკურად
ტვირთავს runtime-ში, proxy-ის ხელახლა აწყობის გარეშე.

ამ ლაბორატორიულ სამუშაოში ingress gateway-ზე ჩართავთ community-მოდულს
**`basic_auth`**, რათა მოთხოვნებს HTTP Basic-ავთენტიფიკაცია დასჭირდეთ.

> Istio `1.29` იყენებს `WasmPlugin` API-ს (`extensions.istio.io/v1alpha1`). `1.30+`-ში
> მას `TrafficExtension` API ჩაანაცვლებს.

Istio უკვე დაყენებულია (ingress gateway NodePort-ზე `32080`), აპლიკაცია `ping-pong`
gანთავსებულია namespace `app`-ში და გამოქვეყნებულია მისამართზე
`http://myapp.local:32080/`.

```mermaid
flowchart LR
    C["client"] --> GW["istio-ingressgateway<br>+ WasmPlugin basic_auth"]
    GW -->|"არ არის/არასწორი creds"| R["401 Unauthorized"]
    GW -->|"სწორი creds"| A["ping-pong<br>200 OK"]
    OCI["oci://ghcr.io/.../basic_auth:1.12.0"] -.pull.-> GW
```

## ინფრასტრუქტურა

| კომპონენტი | ტიპი | რაოდენობა | როლი |
|---|---|---|---|
| control-plane | `t3.medium` | 1 | master + istiod + ingress gateway |
| worker | `t3.small` | 1 | აპლიკაციისთვის საჭირო რესურსები |
| worker PC | `t3.small` | 1 | სამუშაო ადგილი: `kubectl`, `curl`, `check_result` |

რეგიონი: `eu-central-1` (AZ `eu-central-1a` / `eu-central-1b`).

## გაშლა

```bash
TASK=23 make run_ica_task
```

## რა არის WebAssembly (მათთვის, ვისაც ჯერ არ გამოუყენებია)

მოკლედ: **WebAssembly (Wasm)** არის მცირე, კომპილირებული პროგრამების ფორმატი,
რომლებიც უსაფრთხოდ შეიძლება გაეშვას სხვა პროგრამის შიგნით. თავდაპირველად Wasm
ბრაუზერებისთვის შეიქმნა (C++/Rust კოდის JavaScript-ის გვერდით გასაშვებად), თუმცა ახლა
მას ყველგან იყენებენ, მათ შორის ქსელური proxy-ების შიგნითაც.

ეტაპობრივად განვიხილოთ, რა ხდება აქ:

- **რა არის data plane და Envoy.** Istio-ში თითოეული pod-ის გვერდით მუშაობს proxy
  **Envoy** (იგივე „sidecar“). pod-ის მთელი შემავალი და გამავალი ქსელური ტრაფიკი მასზე
  გადის. ამ proxy-ების ერთობლიობას *data plane* ეწოდება. წესებს - mTLS-ს,
  მარშრუტიზაციას, ლიმიტებსა და ავტორიზაციას - რეალურად სწორედ Envoy იყენებს.
- **პრობლემა.** Envoy-ს ბევრი რამ შეუძლია „მზა სახით“, მაგრამ ყველაფრის წინასწარ
  გათვალისწინება შეუძლებელია. ადრე საკუთარი ლოგიკის დასამატებლად საჭირო იყო Envoy-ის
  C++-ზე ხელახლა აწყობა და proxy-ის image-ის ჩანაცვლება - ეს ხანგრძლივი და სარისკოა და
  განახლებებისას ფუჭდება.
- **Wasm-პლაგინის იდეა.** ხელახლა აწყობის ნაცვლად, სასურველ ენაზე (**Rust, C++,
  Go/TinyGo, AssemblyScript**) წერთ მცირე მოდულს, აკომპილირებთ `.wasm`-ში და Envoy-ს
  გადასცემთ. Envoy ამ მოდულს **მუშაობის პროცესში, გადატვირთვისა და ხელახლა აწყობის
  გარეშე** ტვირთავს და მოთხოვნების მასში გატარებას იწყებს.
- **იზოლირებული გარემო (sandbox).** Wasm-მოდული იზოლირებულ გარემოში სრულდება: მას არ
  აქვს პირდაპირი წვდომა Envoy-ის მეხსიერებაზე ან host-ზე და proxy-ს მხოლოდ მკაცრად
  განსაზღვრული ინტერფეისით უკავშირდება. მოდული რომც „გაითიშოს“, proxy-ს არ დააზიანებს.
  ეს proxy-ებში სხვისი ან საკუთარი კოდის გაშვებას შედარებით უსაფრთხოს ხდის.
- **proxy-wasm ABI.** „Envoy ↔ Wasm-მოდულის“ ურთიერთქმედება სტანდარტიზებულია
  **proxy-wasm** პროტოკოლით (hook-ფუნქციების ნაკრები: „მოთხოვნა მოვიდა“, „header
  მოვიდა“, „body მოვიდა“ და ა.შ.). საერთო სტანდარტის წყალობით ერთი და იგივე მოდული
  Envoy/Istio-ს სხვადასხვა ვერსიაზე და proxy-wasm-ის მხარდამჭერ სხვა proxy-ებშიც
  მუშაობს.
- **როგორ ხვდება მოდული proxy-ში.** მოდულს **OCI-image**-ში ფუთავენ (ჩვეულებრივი
  Docker-image-ის მსგავსად) და registry-ში ათავსებენ. `WasmPlugin`-ში უთითებთ
  `url: oci://...`-ს, ხოლო istio-agent მოდულს თავად ჩამოტვირთავს, node-ზე დააკეშირებს
  და Envoy-ს HTTP-filter-ის სახით დაუკავშირებს.

ანალოგიისთვის: ეს ჰგავს „ბრაუზერის პლაგინს/გაფართოებას“, ოღონდ აქ პლაგინი ბრაუზერში
კი არა, ქსელურ proxy-ში ყენდება და ვებგვერდების ნაცვლად სერვისებს შორის ქსელურ
მოთხოვნებს ამუშავებს. ამ ლაბორატორიულ სამუშაოში ასეთი „პლაგინი“ იქნება მზა მოდული
`basic_auth`, რომელიც mesh-ში შესვლისას მომხმარებლის სახელსა და პაროლს (HTTP Basic
auth) მოითხოვს.

## მზა მოდულები და საკუთარი მოდულის შექმნა

**მზა Wasm-მოდულები (კოდის დაწერა საჭირო არ არის).** ხშირად საჭირო ფუნქციონალი უკვე
დაწერილია - საკმარისია `WasmPlugin`-ში image-ის ბმული მიუთითოთ:

- **istio-ecosystem/wasm-extensions** - Istio-ს community-ის ოფიციალური მაგალითები
  (`basic_auth` და სხვ.), რომლებიც ქვეყნდება
  `ghcr.io/istio-ecosystem/wasm-extensions/...`-ში (ლაბორატორიულ სამუშაოში სწორედ მას
  ვიყენებთ).
- **პროდუქტების მზა მოდულები** მომწოდებლებისგან (მაგალითად, coraza-WAF როგორც Wasm,
  OPA, სხვადასხვა auth/rate-limit filter), რომლებიც OCI-image-ების სახით ვრცელდება.
- **WebAssembly Hub / OCI-registry-ები** - მოდულები ჩვეულებრივი OCI-image-ების მსგავსად
  იფუთება, ამიტომ მათი შენახვა ნებისმიერ registry-ში შეიძლება (ghcr, Docker Hub, ECR,
  კერძო Harbor).

წესი მარტივია: თუ მოდული OCI-image-ის სახით არსებობს, უბრალოდ წერთ
`url: oci://...`-ს და კოდის დაწერა არ გჭირდებათ.

**თუ საკუთარი მოდული გჭირდებათ - მოკლე გზა.** საკუთარი ლოგიკა იწერება ენაზე, რომელიც
Wasm-ში კომპილირდება, proxy-wasm SDK-ის გამოყენებით:

1. **აირჩიეთ ენა და SDK.** პოპულარული ვარიანტებია: **Rust**
   (`proxy-wasm/proxy-wasm-rust-sdk`), **Go/TinyGo** (`proxy-wasm-go-sdk`), C++ ან
   AssemblyScript. production-ისთვის ხშირად Rust-ს ირჩევენ (სწრაფი, კომპაქტური
   `.wasm`).
2. **დაწერეთ hook-ები.** SDK-ში ახორციელებთ მოთხოვნის სასიცოცხლო ციკლის callback-ებს,
   მაგალითად `on_http_request_headers` (მოთხოვნის header-ები მოვიდა),
   `on_http_response_headers` და ა.შ. შიგნით თქვენი ლოგიკაა: შეამოწმეთ header,
   დაამატეთ/შეცვალეთ იგი ან დააბრუნეთ შეცდომა.
3. **დააკომპილირეთ Wasm-ში.** მაგალითად, Rust-ისთვის:
   ```bash
   rustup target add wasm32-wasip1
   cargo build --release --target wasm32-wasip1
   # შედეგი: target/wasm32-wasip1/release/my_plugin.wasm
   ```
4. **შეფუთეთ OCI-image-ში და ატვირთეთ.** Istio Wasm-ს OCI-artifact-ის შიგნით ელის.
   მოსახერხებელია `buildah`/`docker` ან `func-e`/`wasme` ინსტრუმენტების გამოყენება;
   შემდეგ - `docker push <registry>/my-plugin:1.0`.
5. **დააკავშირეთ WasmPlugin-ით.** მიუთითეთ
   `url: oci://<registry>/my-plugin:1.0` და, საჭიროების შემთხვევაში, `pluginConfig`
   თქვენი პარამეტრებით - ზუსტად ისე, როგორც ამ ლაბორატორიულ სამუშაოში.

Rust-ზე ლოგიკის მინიმალური მაგალითი (response header-ის დამატება):

```rust
use proxy_wasm::traits::*;
use proxy_wasm::types::*;

proxy_wasm::main! {{
    proxy_wasm::set_http_context(|_, _| -> Box<dyn HttpContext> { Box::new(MyPlugin) });
}}

struct MyPlugin;
impl Context for MyPlugin {}
impl HttpContext for MyPlugin {
    fn on_http_response_headers(&mut self, _n: usize, _eos: bool) -> Action {
        self.set_http_response_header("x-my-plugin", Some("hello"));
        Action::Continue
    }
}
```

რეალური დამუშავებისთვის იხილეთ სახელმძღვანელოები
`istio-ecosystem/wasm-extensions` repository-ში (როგორ დაწეროთ, დატესტოთ და ააწყოთ
OCI-image-ები).

## დავალება

1. შეამოწმეთ, რომ პლაგინის გარეშე აპლიკაცია ხელმისაწვდომია (`200`).
2. გამოიყენეთ `WasmPlugin`, რომელიც ingress gateway-ზე
   (`selector: istio=ingressgateway`) OCI-registry-დან ტვირთავს `basic_auth` მოდულს და
   Basic-ავთენტიფიკაციას მოითხოვს.
3. შეამოწმეთ, რომ მოთხოვნა ავტორიზაციის მონაცემების გარეშე იღებს `401` პასუხს, ხოლო
   სწორი მონაცემებით - `200`-ს.

## ნაბიჯი 1. საბაზისო ქცევა (auth-ის გარეშე)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## ნაბიჯი 2. WasmPlugin-ის გამოყენება

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

ingress gateway-ზე istio-agent ჩამოტვირთავს Wasm-ის OCI-image-ს, ლოკალურად დააკეშირებს
და HTTP-filter-ის სახით ჩასვამს. დაელოდეთ რამდენიმე წამი.

## ნაბიჯი 3. შემოწმება

```bash
# ავტორიზაციის მონაცემების გარეშე -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# სწორი მონაცემებით -> 200  (base64 admin3:admin3-დან)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## როგორ მუშაობს

- **WebAssembly (Wasm)** Envoy-ში proxy-ის ხელახლა აწყობის გარეშე საკუთარი ლოგიკის
  დამატებისა და runtime-ში მისი დინამიკურად ჩატვირთვის საშუალებას იძლევა.
- **`url: oci://...`** - მოდული OCI-artifact-ის სახით მიეწოდება; istio-agent მას
  ჩამოტვირთავს და აკეშირებს. ასევე მხარდაჭერილია `file://` (image-ში ჩაშენებული) და
  `http(s)://`.
- **`phase: AUTHN`** filter-ს ჯაჭვის ადრეულ ეტაპზე ათავსებს
  (მარშრუტიზაციამდე/ავტორიზაციამდე).
- **`selector`** პლაგინს label-ების მიხედვით workload-ებით ზღუდავს (აქ - ingress
  gateway).
- **`pluginConfig`** მოდულს გადაეცემა; `basic_auth` კითხულობს `basic_auth_rules`-ს
  (გზის prefix, მეთოდები, დასაშვები ავტორიზაციის მონაცემები).

## როდის არის ეს სასარგებლო (რეალური სცენარები)

- **საკუთარი ავთენტიფიკაცია/ავტორიზაცია**: Basic auth, API-key-ის შემოწმება,
  მოთხოვნის HMAC-signature, არასტანდარტულ IdP-სთან ინტეგრაცია - ყველაფერი, რაც
  `RequestAuthentication`/`AuthorizationPolicy`-ით ვერ გამოისახება.
- **მოთხოვნებით/პასუხებით მანიპულირება**: გარე წყაროდან header-ების გამდიდრება,
  signature-ის გამოთვლა, body-ის რედაქტირება (PII-ის masking), გზების ნორმალიზება.
- **პროტოკოლური და ბიზნესლოგიკა საზღვარზე**: სპეციფიკური rate limiting საკუთარი
  key-ის მიხედვით, feature flag-ები, რთულ წესებზე დაფუძნებული A/B, proprietary
  პროტოკოლის დეკოდირება.
- **შესაბამისობა და უსაფრთხოება**: audit-logging სპეციალურ ფორმატში, WAF-ის მსგავსი
  შემოწმებები, საკუთარი signature-ებით დაბლოკვა.
- **ლოგიკის აპლიკაციიდან გატანა**: ერთი და იგივე cross-cutting ლოგიკა (auth, logging,
  header-ები) ერთხელ ხორციელდება mesh-ში და არა თითოეულ სერვისში, თითოეულ ენაზე.

## ალტერნატივებთან შედარებითი უპირატესობები

| მიდგომა | უპირატესობები | ნაკლოვანებები / როდის სჯობს Wasm |
|---|---|---|
| **ჩაშენებული CRD-ები** (`AuthorizationPolicy`, `RequestAuthentication`, `Telemetry`, `EnvoyFilter` local ratelimit) | მარტივი, დეკლარაციული, მხარდაჭერილია Istio-ს მიერ | წინასწარ განსაზღვრული შესაძლებლობებით შემოიფარგლება; ნებისმიერი ლოგიკის გამოხატვა შეუძლებელია |
| **`EnvoyFilter` + Lua** (იხ. lua-scripts) | ხელახლა აწყობის გარეშე, inline-script | მხოლოდ Lua; მძიმე ამოცანები უფრო ნელია; არ აქვს მკაცრი ტიპიზაცია/ტესტები; ლოგიკა YAML-შია „გაფანტული“ |
| **`EnvoyFilter` native C++ filter-ით** | მაქსიმალური სიჩქარე | საჭიროა Envoy-ის ხელახლა აწყობა და proxy-ის საკუთარი image; შეუთავსებელია upgrade-ებთან; რთული დასაწყებია |
| **ლოგიკა თვითონ აპლიკაციაში** | სრული კონტროლი | დუბლირდება თითოეულ სერვისში და თითოეულ ენაზე; ერთგვაროვნებისა და განახლების უზრუნველყოფა რთულია |
| **გარე სერვისი (ext_authz / callout)** | ნებისმიერი ენა, ცალკე deployment | დამატებითი ქსელური hop და დაყოვნება თითოეულ მოთხოვნაზე; ექსპლუატაციაში კიდევ ერთი კომპონენტი |
| **WasmPlugin (ეს ლაბორატორიული სამუშაო)** | საკუთარი კოდი ნებისმიერ ენაზე, რომელიც Wasm-ში კომპილირდება (C++, Rust, Go/TinyGo, AssemblyScript); **runtime-ში ჩატვირთვა Envoy-ის ხელახლა აწყობისა და restart-ის გარეშე**; სრულდება **in-process** (არ აქვს ქსელური hop, როგორც ext_authz-ს); Wasm sandbox - იზოლაცია და უსაფრთხოება; Envoy/Istio-ს ვერსიებს შორის პორტირებადობა სტაბილური proxy-wasm ABI-ის წყალობით; versioning და მიწოდება OCI-registry-ის მეშვეობით | API-ს Alpha-სტატუსი; runtime-ში ჩატვირთვისა და მოდულის caching-ის დამატებითი ხარჯი; საკუთარი კოდი საჭიროებს მხარდაჭერას, ტესტირებასა და versioning-ს; გამართვა დეკლარაციულ CRD-ებთან შედარებით უფრო რთულია |

**მოკლედ:** Wasm იმ შემთხვევაში იმარჯვებს, როდესაც data plane-ში *ნებისმიერი* ლოგიკაა
საჭირო, თუმცა ასევე მნიშვნელოვანია დაბალი დაყოვნება (in-process, ext_authz-ის მსგავსი
ზედმეტი hop-ის გარეშე), უსაფრთხოება (sandbox) და proxy-ის ხელახლა აწყობის გარეშე
filter-ის დინამიკურად გაშლის/განახლების შესაძლებლობა.

**არჩევის პრაქტიკული თანმიმდევრობა:** ჯერ ჩაშენებული CRD-ები → თუ არასაკმარისია,
`EnvoyFilter` (მათ შორის Lua მარტივი შემთხვევებისთვის) → გარე `ext_authz`, თუ ლოგიკის
ცალკე სერვისში შენახვა უფრო მარტივია და დაყოვნება კრიტიკული არ არის → **Wasm**, როდესაც
საკუთარი სწრაფი in-process კოდი უშუალოდ proxy-შია საჭირო. გაითვალისწინეთ Wasm-ის
საექსპლუატაციო ფასი: მოდულის მიწოდება, versioning და runtime-ში ჩატვირთვა
(`failStrategy` განსაზღვრავს ქცევას წარუმატებელი ჩატვირთვისას - fail-open ან
fail-close).

## შედეგის შემოწმება

worker PC-ზე გაუშვით:

```bash
check_result
```

## შეჯამება

თქვენ data plane OCI-registry-დან ჩატვირთული საკუთარი Wasm-მოდულით გააფართოეთ და
აპლიკაციის შეცვლის გარეშე mesh-ის საზღვარზე Basic-ავთენტიფიკაცია დაამატეთ.
`WasmPlugin`-თან მუშაობა senior-დონის უნარია იმ შემთხვევებისთვის, როდესაც Istio-ს
ჩაშენებული შესაძლებლობები საკმარისი არ არის.
