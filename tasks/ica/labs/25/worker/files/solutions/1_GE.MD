[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 25 - ეტალონური გადაწყვეტა

Istio `1.29.1` და Prometheus დაყენებულია. **Flagger** მუშაობს `istio-system`-ში. სახელთა სივრცე
`test` (istio-injection) შეიცავს სადემონსტრაციო აპლიკაციას **podinfo** (`6.0.0`),
**flagger-loadtester**-ს (ანალიზის დროს ტრაფიკს წარმოქმნის), ხოლო `public-gateway` არსებობს
`istio-system`-ში.

## მიზანი

შექმენით `Canary` რესურსი, რომლის მეშვეობითაც Flagger მართავს **პროგრესულ მიწოდებას**: ყოველი
ახალი image-ის დროს თანდათან გადაიტანოს ტრაფიკი canary-ზე, შეამოწმოს მეტრიკები და ავტომატურად
შეასრულოს promotion (ან წარუმატებლობის შემთხვევაში ავტომატური rollback).

## ნაბიჯი 1. შექმენით Canary

```bash
kubectl apply -f - <<'EOF'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 300
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: podinfo
  service:
    port: 9898
    targetPort: 9898
    gateways:
    - istio-system/public-gateway
    hosts:
    - app.example.com
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 20
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 2m -q 10 -c 2 http://podinfo-canary.test:9898/"
EOF
```

## ნაბიჯი 2. დაელოდეთ Flagger-ის ინიციალიზაციას

```bash
kubectl -n test get canary podinfo -w   # wait until STATUS = Initialized
kubectl -n test get deploy
# Flagger created: podinfo-primary, services podinfo/podinfo-canary/podinfo-primary,
# destinationrules and a virtualservice.
```

## ნაბიჯი 3. გაუშვით canary release

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.1
```

Flagger აღმოაჩენს ახალ revision-ს და იწყებს ანალიზს: ის ტრაფიკის 20% → 40% → 50%-ს
canary-ზე გადაიტანს და ყოველ interval-ზე ამოწმებს `request-success-rate`-სა და
`request-duration`-ს. loadtester აგრძელებს ტრაფიკის გაგზავნას, რათა მეტრიკები არსებობდეს.

## ნაბიჯი 4. დააკვირდით promotion-ს

```bash
kubectl -n test describe canary/podinfo
# ... Advance podinfo.test canary weight 20/40/50
# ... Copying podinfo.test template spec to podinfo-primary.test
# ... Promotion completed!

kubectl -n test get canary podinfo         # STATUS = Succeeded
kubectl -n test get deploy podinfo-primary -o jsonpath='{.spec.template.spec.containers[*].image}'
# -> ghcr.io/stefanprodan/podinfo:6.0.1
```

ზემოთ მოცემული პარამეტრებით promotion-ს დაახლოებით 2–3 წუთი სჭირდება. გაუშვით `check_result`
მას შემდეგ, რაც `podinfo-primary` განახლდება `6.0.1` ვერსიამდე.

## ავტომატური rollback (არასავალდებულო)

გაუშვით კიდევ ერთი release და ანალიზის დროს წარუმატებლობები შეიტანეთ:

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.2
POD=$(kubectl -n test get pod -l app=flagger-loadtester -o jsonpath='{.items[0].metadata.name}')
kubectl -n test exec -it "$POD" -- hey -z 1m -c 5 -q 10 http://podinfo-canary.test:9898/status/500
```

როდესაც წარუმატებელი metric check-ების რაოდენობა threshold-ს მიაღწევს, Flagger პროცესს აჩერებს
და rollback-ს ასრულებს: ტრაფიკი primary-ზე ბრუნდება, canary ნულამდე მასშტაბირდება, ხოლო STATUS
ხდება `Failed`.

## როგორ მუშაობს

- Flagger აკვირდება სამიზნე `Deployment`-ს. spec-ის ცვლილებისას ის ქმნის ან განაახლებს
  **canary** deployment-ს და ტრაფიკს ეტაპობრივად გადააქვს Istio-ს
  `VirtualService`/`DestinationRule` weight-ების მეშვეობით.
- ყოველ ნაბიჯზე ის **Prometheus**-ში აგზავნის მოთხოვნებს კონფიგურირებული მეტრიკებისთვის; თუ ისინი
  threshold-ების ფარგლებში რჩება, პროცესი წინ მიიწევს, წინააღმდეგ შემთხვევაში `threshold`
  წარუმატებლობის შემდეგ rollback სრულდება.
- `podinfo-primary` ყოველთვის შეიცავს „ცნობილ კარგ“ ვერსიას; სამუშაო ტრაფიკს primary ემსახურება,
  სანამ canary ყველა შემოწმებას სრულად არ გაივლის და promotion არ შესრულდება.
- ეს სარისკო ხელით მართულ canary-ს (ლაბორატორია 06-ში ტრაფიკის გადატანას) ავტომატიზებულ,
  მეტრიკებით კონტროლირებად release-ად გარდაქმნის, ჩაშენებული rollback-ით, რაც პროგრესული
  მიწოდების არსია.
