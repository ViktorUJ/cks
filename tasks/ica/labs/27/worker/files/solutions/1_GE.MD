[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 27 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაინსტალირებულია (Ingress Gateway განთავსებულია NodePort `32080`-ზე). აპლიკაცია `ping-pong`
განთავსებულია სახელთა სივრცეში `app` და ხელმისაწვდომია მისამართზე `http://myapp.local:32080/`.

## მიზანი

Ingress Gateway-ს დაურთეთ `EnvoyFilter` HTTP-ის **inline Lua** ფილტრით, რომელიც:
- პასუხს ამატებს სათაურს `x-lua-lab: hello-from-lua`;
- `403` კოდით უარყოფს ნებისმიერ მოთხოვნას, რომელიც შეიცავს `x-block: yes`-ს.

## ნაბიჯი 1. საწყისი მდგომარეობა

```bash
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab   # nothing yet
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/   # 200
```

## ნაბიჯი 2. Lua EnvoyFilter-ის გამოყენება

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: lua-edge
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
              subFilter:
                name: envoy.filters.http.router
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.lua
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
            inlineCode: |
              function envoy_on_request(request_handle)
                if request_handle:headers():get("x-block") == "yes" then
                  request_handle:respond(
                    {[":status"] = "403"},
                    "blocked by lua\n")
                end
              end
              function envoy_on_response(response_handle)
                response_handle:headers():add("x-lua-lab", "hello-from-lua")
              end
EOF
```

## ნაბიჯი 3. შემოწმება

```bash
# response header added by Lua
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab
# x-lua-lab: hello-from-lua

# request blocked by Lua
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/
# 403

# normal request still works
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# 200
```

## მუშაობის პრინციპი

- **`EnvoyFilter`** ცვლის Istio-ს მიერ გენერირებულ Envoy-ის დაბალი დონის კონფიგურაციას. აქ ის
  ჩაშენებულ HTTP-ის **Lua** ფილტრს (`envoy.filters.http.lua`) ამატებს Ingress Gateway-ის
  ფილტრების ჯაჭვში, უშუალოდ როუტერის წინ.
- Lua-ს სკრიპტი ახორციელებს სასიცოცხლო ციკლის ორ უკუგამოძახების ფუნქციას:
  - `envoy_on_request(request_handle)` - სრულდება თითოეული მოთხოვნისთვის; შეუძლია სათაურების წაკითხვა ან შეცვლა, სხეულის
    წაკითხვა ან მოთხოვნის დამუშავების ნაადრევად დასრულება `request_handle:respond(...)`-ით.
  - `envoy_on_response(response_handle)` - სრულდება თითოეული პასუხისთვის; აქ ის სათაურს ამატებს.
- `context: GATEWAY` ცვლილებას Ingress Gateway-ით ზღუდავს. სამუშაო დატვირთვის Sidecar-ებისთვის გამოიყენეთ `SIDECAR_INBOUND` /
  `SIDECAR_OUTBOUND`.

## Lua, Wasm და ჩაშენებული CRD-ები

- **Inline Lua** - მცირე მორგებული ლოგიკის დამატების უსწრაფესი გზა: არ სჭირდება იმიჯი და აგება, სკრიპტი
  YAML-ში რედაქტირდება. შესანიშნავია სათაურების შესაცვლელად, მოთხოვნების მარტივად გასაფილტრად და სწრაფი ექსპერიმენტებისთვის.
- **Wasm** (ლაბორატორია 23) - განკუთვნილია უფრო რთული ან მრავალჯერ გამოსაყენებელი ლოგიკისთვის რეალურ ენაზე (Rust/Go), ვერსიონირდება,
  OCI იმიჯის სახით ვრცელდება და იზოლირებულ გარემოში სრულდება.
- **ჩაშენებული CRD-ები** (`AuthorizationPolicy`, `Telemetry`, ...) - ყოველთვის პირველ რიგში ისინი გამოიყენეთ;
  Lua/Wasm მხოლოდ მაშინ გამოიყენეთ, როცა ისინი საჭირო ფუნქციონალს ვერ გამოხატავენ.

> `EnvoyFilter` დაბალი დონის, ვერსიაზე დამოკიდებული API-ია - Istio გვაფრთხილებს, რომ მისი კონფიგურაცია შეიძლება
> გამოშვებებს შორის შეიცვალოს. ასეთი ცვლილებები მინიმალური უნდა იყოს და განახლებების დროს უნდა შემოწმდეს.
