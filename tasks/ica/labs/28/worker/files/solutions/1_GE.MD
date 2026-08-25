[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 28 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაყენებულია ingress gateway-ზე ფიქსირებული TCP NodePort-ით `31400`. აპლიკაცია
`tcp-echo` განთავსებულია namespace-ში `app` ორი ვერსიით:
- **v1** პასუხობს პრეფიქსით `one`;
- **v2** პასუხობს პრეფიქსით `two`.

ორივე უსმენს ნედლ TCP პორტს `9000` (არა HTTP-ს).

## მიზანი

ნედლი **TCP** სერვისის მარშრუტიზაცია ingress gateway-ის გავლით, `TCP` listener-ის მქონე
`Gateway`-ისა და `tcp` route-ის მქონე `VirtualService`-ის გამოყენებით (v1-სა და v2-ს შორის წონებით განაწილებული).

## ნაბიჯი 1. Gateway TCP listener-ით

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: tcp-echo-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 31400
        name: tcp
        protocol: TCP
      hosts:
        - "*"
EOF
```

## ნაბიჯი 2. DestinationRule subsets-ით

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: tcp-echo
  namespace: app
spec:
  host: tcp-echo
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
EOF
```

## ნაბიჯი 3. VirtualService TCP route-ით

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tcp-echo
  namespace: app
spec:
  hosts:
    - "*"
  gateways:
    - tcp-echo-gateway
  tcp:
    - match:
        - port: 31400
      route:
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v1
          weight: 80
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v2
          weight: 20
EOF
```

## ნაბიჯი 4. შემოწმება

```bash
for i in $(seq 10); do
  echo "hello" | timeout 3 bash -c 'exec 3<>/dev/tcp/myapp.local/31400; cat >&3; head -n 1 <&3'
done
# ~80% "one hello", ~20% "two hello"
```

(თუ `nc` დაყენებულია: `echo hello | nc myapp.local 31400`.)

## მუშაობის პრინციპი

- **TCP მარშრუტიზაცია** მუშაობს მე-4 დონეზე: აქ არ არის HTTP ჰოსტი/ბილიკი/სათაური, ამიტომ მარშრუტიზაციის გასაღებად
  გამოიყენება **მსმენელი პორტი** (`match.port`). `Gateway` სერვერი `protocol: TCP` პარამეტრით
  Envoy-ს აიძულებს გახსნას ჩვეულებრივი TCP მსმენელი; `VirtualService.tcp` მარშრუტი კავშირს
  არჩეულ backend subset-ზე გადაამისამართებს.
- **პორტის სახელდებას მნიშვნელობა აქვს**: სერვისის/gateway-ის პორტის სახელი უნდა იყოს `tcp` (ან `tcp-*`). Istio
  პროტოკოლის ამოსაცნობად პორტის სახელის პრეფიქსს იყენებს; პრეფიქსის არმქონე ან `http-*` სახელი
  Istio-ს აიძულებდა, ის HTTP-ად აღექვა, რაც ნედლ პროტოკოლს დაარღვევდა.
- **წონებით განაწილებული TCP** *კავშირებს* (და არა მოთხოვნებს) subsets-ს შორის ანაწილებს - ყოველი ახალი TCP
  კავშირი წონის მიხედვით მარშრუტიზდება.
- L7 ფუნქციები (ხელახალი ცდები, სათაურის მიხედვით მარშრუტიზაცია, შეფერხების ხელოვნურად გამოწვევა) TCP მარშრუტებზე **არ** ვრცელდება -
  `DestinationRule`-ის მეშვეობით გამოიყენება მხოლოდ კავშირის დონის პოლიტიკები (კავშირების პული, დროის ლიმიტები).

## დაკავშირებული პროტოკოლები

- **MongoDB/MySQL/Redis** - პორტს დაარქვით `mongo-*` / `mysql-*` / `redis-*`, რათა Envoy-მ
  შესაბამისი პროტოკოლის ანალიზატორი გამოიყენოს; მარშრუტიზაცია კვლავ `tcp` მარშრუტებს იყენებს.
- **WebSocket** - მიუხედავად ხანგრძლივი არსებობისა, ის HTTP `Upgrade`-ზე მუშაობს, ამიტომ გამოიყენეთ ჩვეულებრივი
  `http` მარშრუტები და `http-*` პორტის სახელები და არა TCP.
