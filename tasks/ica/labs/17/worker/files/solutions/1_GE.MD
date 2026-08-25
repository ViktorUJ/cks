[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 17 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაყენებულია (ingress gateway იყენებს NodePort `32080`-ს). აპლიკაცია `ping-pong`
განთავსებულია სახელთა სივრცეში `app` და ingress gateway-ის მეშვეობით ხელმისაწვდომია მისამართზე
`http://myapp.local:32080/`.

## მიზანი

ingress gateway-ზე `EnvoyFilter`-ის გამოყენებით დააყენეთ **ლოკალური მოთხოვნების სიხშირის ლიმიტი**:
დაუშვით მაქსიმუმ 5 მოთხოვნა წუთში, ხოლო დანარჩენები უარყავით HTTP `429` კოდით.

## ნაბიჯი 1. საწყისი მდგომარეობა

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## ნაბიჯი 2. ლოკალური მოთხოვნების სიხშირის ლიმიტის გამოყენება (EnvoyFilter)

```bash
cat > ratelimit.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingress-local-rate-limit
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            "@type": type.googleapis.com/udpa.type.v1.TypedStruct
            type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
            value:
              stat_prefix: http_local_rate_limiter
              token_bucket:
                max_tokens: 5
                tokens_per_fill: 5
                fill_interval: 60s
              filter_enabled:
                runtime_key: local_rate_limit_enabled
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              filter_enforced:
                runtime_key: local_rate_limit_enforced
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              response_headers_to_add:
                - append_action: OVERWRITE_IF_EXISTS_OR_ADD
                  header:
                    key: x-local-rate-limit
                    value: "true"
EOF

kubectl apply -f ratelimit.yaml
```

## ნაბიჯი 3. შემოწმება

```bash
for i in $(seq 10); do
  curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
done
# first ~5 -> 200, the rest -> 429
```

## მუშაობის პრინციპი

- **`token_bucket`** - `max_tokens: 5`, `tokens_per_fill: 5`, `fill_interval: 60s`:
  კალათაში თავსდება 5 ტოკენი და ყოველ 60 წამში ის კვლავ 5 ტოკენამდე ივსება. თითოეული მოთხოვნა
  ერთ ტოკენს ხარჯავს; როდესაც კალათა ცარიელია, მოთხოვნები უარყოფილია `429` კოდით.
- **`filter_enabled` / `filter_enforced`** - მოთხოვნების ის პროცენტული წილი, რომლისთვისაც ფილტრი
  აქტიურია და რეალურად ახორციელებს შეზღუდვას (აქ ორივე `100%`-ია).
- **context: GATEWAY** - ფილტრი ემატება ingress gateway-ის listener-ს,
  ამიტომ ლიმიტი ვრცელდება საზღვარზე შემომავალ მთელ ტრაფიკზე.

## ლოკალური და გლობალური მოთხოვნების სიხშირის შეზღუდვა

- **ლოკალური მოთხოვნების სიხშირის ლიმიტი** (ეს ლაბორატორია) - Envoy-ის თითოეული ეგზემპლარი საკუთარ token bucket-ს ინახავს.
  ეს მიდგომა მარტივია და დამატებით კომპონენტებს არ საჭიროებს, თუმცა ფაქტობრივი ლიმიტი
  gateway-ის რეპლიკების რაოდენობაზე მრავლდება.
- **გლობალური მოთხოვნების სიხშირის ლიმიტი** - Envoy მიმართავს გარე rate-limit სერვისს (რომელსაც Redis უჭერს მხარს),
  ამიტომ ლიმიტი ყველა რეპლიკას შორის საერთოა. მიდგომა იყენებს
  `envoy.filters.http.ratelimit` ფილტრს, ასევე `ConfigMap`-ს დესკრიპტორებით და
  განთავსებულ ratelimit სერვისს. გამოიყენეთ, როდესაც მთელი კლასტერისთვის ზუსტი კვოტა გჭირდებათ.
