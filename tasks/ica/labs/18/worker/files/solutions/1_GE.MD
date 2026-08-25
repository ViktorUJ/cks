[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 18 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაინსტალირებულია (შემომავალი ტრაფიკის კარიბჭე NodePort `32080`-ზე) და განაწილებული
ტრეისინგი დაკავშირებულია `zipkin` გაფართოების პროვაიდერთან (`zipkin.istio-system:9411`).
**Jaeger** დამატება გაშვებულია, როგორც ტრეისინგის ბეკენდი. აპლიკაცია `ping-pong` გაშვებულია
სახელთა სივრცეში `app` და ხელმისაწვდომია მისამართზე `http://myapp.local:32080/`. წვდომის ჟურნალების წარმოება
ნაგულისხმევად **გამორთულია** და `Telemetry` რესურსი ჯერ არ არსებობს.

## მიზანი

გამოიყენეთ **Telemetry API**, რათა:
- ჩართოთ Envoy-ის წვდომის ჟურნალების წარმოება `app` სახელთა სივრცისთვის (ჩაშენებული `envoy` პროვაიდერი);
- ჩართოთ ტრეისინგი `zipkin` პროვაიდერის მეშვეობით 100%-იანი სემპლინგით, რათა ტრეისები
  რეალურად შეგროვდეს Jaeger-ში.

## ნაბიჯი 1. დაადასტურეთ, რომ წვდომის ჟურნალები გამორთულია

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
curl -s -o /dev/null http://myapp.local:32080/
kubectl logs -n app "$POD" -c istio-proxy --tail=50   # no access log lines
```

## ნაბიჯი 2. დააკონფიგურირეთ ჟურნალები და ტრეისები Telemetry-ის მეშვეობით

```bash
cat > telemetry.yaml <<'EOF'
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: app-telemetry
  namespace: app
spec:
  accessLogging:
    - providers:
        - name: envoy
  tracing:
    - providers:
        - name: zipkin
      randomSamplingPercentage: 100.0
EOF

kubectl apply -f telemetry.yaml
```

## ნაბიჯი 3. შექმენით ტრაფიკი

```bash
for i in $(seq 30); do curl -s -o /dev/null http://myapp.local:32080/; done
```

## ნაბიჯი 4. შეამოწმეთ შეგროვება

წვდომის ჟურნალები (საიდქარის სტანდარტულ გამომავალში):

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n app "$POD" -c istio-proxy --tail=50 | grep 'GET / HTTP'
```

ტრეისები (Jaeger-ში, კლასტერის შიგნიდან მოთხოვნის გაგზავნით):

```bash
kubectl exec -n app deploy/curl-client -- \
  curl -s 'http://tracing.istio-system:80/jaeger/api/services' | tr ',' '\n' | grep ping-pong
```

ასევე შეგიძლიათ Jaeger UI-სთვის პორტის გადამისამართება:

```bash
kubectl -n istio-system port-forward svc/tracing 16686:80
# open http://localhost:16686/jaeger and pick the ping-pong service
```

## სად იგზავნება ჟურნალები და ტრეისები

| სიგნალი | პროვაიდერი | დანიშნულების ადგილი |
|---|---|---|
| წვდომის ჟურნალები | `envoy` (ჩაშენებული) | საიდქარის სტანდარტული გამომავალი → `kubectl logs -c istio-proxy` |
| ტრეისები | `zipkin` გაფართოების პროვაიდერი | Jaeger (`zipkin.istio-system:9411`) → Jaeger UI |

## როგორ მუშაობს

- **Telemetry API** (`telemetry.istio.io`) დეკლარაციულად აკონფიგურირებს ჟურნალებს, მეტრიკებსა
  და ტრეისებს და მხარს უჭერს მოქმედების არეალის იერარქიას: მთელი mesh (ძირეული სახელთა სივრცე) → სახელთა სივრცე →
  სამუშაო დატვირთვა (`selector`).
- **`accessLogging.providers.name: envoy`** წვდომის ჟურნალებს საიდქარის სტანდარტულ გამომავალში წერს.
- **`tracing.providers.name: zipkin`** სპანებს მიმართავს `zipkin` გაფართოების პროვაიდერისკენ,
  რომელიც გამოცხადებულია `meshConfig.extensionProviders`-ში და მათ Jaeger-ში აგზავნის.
  პროვაიდერზე მითითების გარეშე სემპლინგის პოლიტიკას სპანების გასაგზავნი ადგილი არ ექნებოდა.
- **`randomSamplingPercentage: 100`** ყველა მოთხოვნის ტრეისს ქმნის (სამუშაო გარემოში
  ზედნადები ხარჯების გასაკონტროლებლად გამოიყენეთ დაბალი მნიშვნელობა).
