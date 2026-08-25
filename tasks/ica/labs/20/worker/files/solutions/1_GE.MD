[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 20 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაყენებულია. განთავსებულია სამი სამუშაო დატვირთვა:
- `ping-pong` სახელთა სივრცეში `app` (sidecar ინექციით, ემსახურება აპლიკაციას);
- `mesh-client` სახელთა სივრცეში `app` (sidecar ინექციით, ურთიერთობს mTLS-ით);
- `legacy-client` სახელთა სივრცეში `legacy` (**არ აქვს** sidecar, მხოლოდ ღია ტექსტი).

როდესაც `PeerAuthentication` არ არის, mTLS ნაგულისხმევად **PERMISSIVE** რეჟიმშია: როგორც mesh კლიენტს
(mTLS), ისე მოძველებულ კლიენტს (ღია ტექსტი) შეუძლია აპლიკაციასთან დაკავშირება.

## მიზანი

გადაიყვანეთ `app` სახელთა სივრცე **STRICT** mTLS-ზე, რათა მხოლოდ mTLS ტრაფიკი იქნეს მიღებული,
mesh-ის შიგნით არსებული კლიენტის მუშაობის დარღვევის გარეშე.

## ნაბიჯი 1. დააკვირდით PERMISSIVE-ის საწყის მდგომარეობას

```bash
# in-mesh client -> app : works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : ALSO works under PERMISSIVE
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200
```

## ნაბიჯი 2. (რეკომენდებულია) მკაფიოდ მიუთითეთ განზრახვა PERMISSIVE-ის გამოყენებით

უსაფრთხო მიგრაციისას ჯერ მკაფიოდ ფიქსირდება PERMISSIVE, შემდეგ კი ის იცვლება STRICT-ით, როდესაც
(მეტრიკების საშუალებით) დაადასტურებთ, რომ ღია ტექსტის ტრაფიკი აღარ დარჩა:

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

## ნაბიჯი 3. გადაიყვანეთ სახელთა სივრცე STRICT რეჟიმში

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

## ნაბიჯი 4. შეამოწმეთ

```bash
# in-mesh client -> app : still works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : now rejected (connection reset)
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 http://ping-pong.app.svc.cluster.local:8080/
# -> 000 (curl exit 56: reset by peer)
```

## როგორ მუშაობს

- **PeerAuthentication** განსაზღვრავს, როგორ იღებს *სერვერის მხარეს* არსებული sidecar შემომავალ
  კავშირებს:
  - `PERMISSIVE` (mesh-ის ნაგულისხმევი რეჟიმი) - იღებს როგორც mTLS-ს, ისე ღია ტექსტს. სწორედ ეს ხდის
    შესაძლებელს მიგრაციას შეფერხების გარეშე: შეგიძლიათ სამუშაო დატვირთვები mesh-ში ეტაპობრივად
    ჩართოთ, სანამ მოძველებული ღია ტექსტის კლიენტები მუშაობას განაგრძობენ.
  - `STRICT` - იღებს მხოლოდ mTLS-ს; ღია ტექსტის კავშირები წყდება.
- მოქმედების არეალის იერარქია: `PeerAuthentication` `istio-system`-ში (root) ვრცელდება მთელ mesh-ზე;
  სახელთა სივრცეში არსებული ანაცვლებს მას იქ; `selector`-ის მქონე კი კონკრეტული სამუშაო დატვირთვისთვის ანაცვლებს.
- **უსაფრთხო მიგრაციის სქემა**: დატოვეთ PERMISSIVE, აკონტროლეთ
  `istio_requests_total{connection_security_policy="none"}` მეტრიკა, სანამ ის ნულამდე
  არ შემცირდება (ღია ტექსტი აღარ დარჩება), შემდეგ კი გადადით STRICT-ზე.

## დაკავშირებული მასალა

ლაბორატორია 04 მოიცავს STRICT-ის საბოლოო მდგომარეობას `AuthorizationPolicy`-სთან ერთად (ვის შეუძლია ვისთან
დაკავშირება). ეს ლაბორატორია ყურადღებას ამახვილებს თავად გადასვლასა და PERMISSIVE-ის როლზე.
