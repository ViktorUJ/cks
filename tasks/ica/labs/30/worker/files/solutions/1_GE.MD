[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 30 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაყენებულია. Namespace `app` (istio-injection) შეიცავს mesh-ში ჩართულ კლიენტს
`app-client`. `istioctl` ხელმისაწვდომია worker PC-ზე.

## მიზანი

mesh-ში **headless Service**-ის უკან გაუშვით **StatefulSet**, ჩართეთ **STRICT** mTLS
და mTLS-ის საშუალებით დაუკავშირდით თითოეულ replica-ს მისი **სტაბილური per-pod identity**-ის (`web-0`, `web-1`) გამოყენებით.

## ნაბიჯი 1. Headless Service + StatefulSet

Service-ს უნდა ჰქონდეს `clusterIP: None` (headless) და **სახელიანი** port (Istio protocol-ის
აღმოსაჩენად port-ის სახელის prefix-ს იყენებს). StatefulSet-ის `serviceName` უნდა ემთხვეოდეს
headless Service-ს, რათა pod-ებმა მიიღონ სტაბილური DNS სახელები `<pod>.<svc>.<ns>.svc.cluster.local`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: app
  labels:
    app: web
spec:
  clusterIP: None          # headless
  selector:
    app: web
  ports:
    - name: http           # named port - required for Istio protocol detection
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
  namespace: app
spec:
  serviceName: web         # ties the pods to the headless Service
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: viktoruj/ping_pong:latest
          env:
            - name: ENABLE_DEFAULT_HOSTNAME   # report the real pod name (web-0/web-1)
              value: "false"
          ports:
            - name: http
              containerPort: 8080
EOF

kubectl rollout status statefulset/web -n app
```

## ნაბიჯი 2. STRICT mTLS-ის სავალდებულოდ გამოყენება

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: STRICT
EOF
```

## ნაბიჯი 3. თითოეულ replica-სთან დაკავშირება მისი სტაბილური identity-ით (mTLS-ის საშუალებით)

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-0.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-0

kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-1.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-1
```

თითოეული სტაბილური DNS სახელი კონკრეტულ pod-ზე resolve-დება, ხოლო traffic sidecar-ების მიერ
mTLS-ით იშიფრება, მიუხედავად იმისა, რომ Service headless-ია.

## რატომ იყო headless + mesh-ის გამოყენება ადრე რთული

- **headless** Service-ს აქვს `clusterIP: None`, ამიტომ virtual IP არ არსებობს - DNS პირდაპირ
  ცალკეული pod-ების IP-ებს აბრუნებს. StatefulSet აპლიკაციები ხშირად load-balanced VIP-ის ნაცვლად
  მის სტაბილურ სახელზე დაყრდნობით უკავშირდებიან **კონკრეტულ** peer-ს (მაგალითად, Kafka broker-ს ან database replica-ს).
- წარსულში Envoy ქმნიდა listener-ებს `0.0.0.0:<port>`-ზე, რაც კონფლიქტში მოდიოდა აპლიკაციებთან,
  რომლებიც მხოლოდ pod IP-ზე ასრულებდნენ binding-ს, ხოლო headless services-ზე mTLS პრობლემური იყო. **Istio
  1.10+** headless services-ს native რეჟიმში ამუშავებს: per-pod listener-ები და automatic mTLS მუშაობს.
- **Port-ის სახელის მინიჭება კვლავ მნიშვნელოვანია**: port-ს დაარქვით `http`/`tcp`/`grpc`/`mongo-*` და ა.შ.
  უსახელო port-ის შემთხვევაში Istio მას opaque TCP-ად აღიქვამს და L7 ფუნქციებს კარგავთ.

## გარე headless services (დამატებით)

კლასტერის **გარეთ** არსებული headless service-ისთვის (მაგალითად, external Kafka) დაამატეთ
`ServiceEntry` პარამეტრით `resolution: DNS`, რათა mesh-მა შეძლოს მისი resolve და მასთან route-ის შექმნა:

```yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: kafka-ext
  namespace: app
spec:
  hosts: ["kafka.example.com"]
  location: MESH_INTERNAL
  ports:
    - name: tcp-kafka
      number: 9092
      protocol: TCP
  resolution: DNS
```
