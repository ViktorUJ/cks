[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 14 - ეტალონური გადაწყვეტა (ლოკაციაზე დაფუძნებული გადართვა)

კლასტერს აქვს ორი კვანძი სხვადასხვა ზონაში (`eu-central-1a`, `eu-central-1b`),
რომლებსაც საწყისი კონფიგურაციისას უკვე მიენიჭათ ჭდე `topology.kubernetes.io/zone`.

## ნაბიჯი 1. დაადასტურეთ ზონის ჭდეები

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

## ნაბიჯი 2. ჩართეთ sidecar-ის ინექცია და განათავსეთ აპლიკაცია

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/14/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods -n default -o wide     # ping-pong-a on zone a, ping-pong-b on zone b
```

## ნაბიჯი 3. DestinationRule - ლოკაციაზე დაფუძნებული დატვირთვის დაბალანსება და გაუმართავი ეგზემპლარების გამოვლენა

ლოკაციებს შორის გადართვისთვის საჭიროა `outlierDetection` (არაჯანსაღი საბოლოო წერტილების გამოსავლენად) და
`localityLbSetting` (ლოკაციაზე დაფუძნებული მარშრუტიზაციის ჩასართავად).

```yaml
# dr.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ping-pong-dr
  namespace: default
spec:
  host: ping-pong
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
      localityLbSetting:
        enabled: true
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 1m
      maxEjectionPercent: 100
```

```bash
kubectl apply -f dr.yaml
```

## ნაბიჯი 4. დააკვირდით ლოკალური ზონის უპირატესობას

კლიენტი A ზონაშია, ამიტომ მას Zone-A-ის backend ემსახურება:

```bash
for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-A   (x5)
```

## ნაბიჯი 5. გამოიწვიეთ გადართვა

გამორთეთ ლოკალური (Zone-A) backend - ტრაფიკი Zone-B-ზე გადაირთვება:

```bash
kubectl scale deployment ping-pong-a -n default --replicas=0
kubectl wait --for=delete pod -l app=ping-pong,zone=a -n default --timeout=60s

for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-B   (failover)

# restore
kubectl scale deployment ping-pong-a -n default --replicas=1
```
