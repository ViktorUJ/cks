[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 33 - საცნობარო გადაწყვეტა

Istio `1.29.1` (ნაგულისხმევი პროფილი, კლასტერის მასშტაბის აღმოჩენა, Sidecar-ის მოქმედების არეალის გარეშე) და OPA
Gatekeeper წინასწარ არის დაინსტალირებული. არსებობს სამი namespace:

- `app` (ინექცია ჩართულია, `mesh=enabled`) - `frontend`;
- `shop` (ინექცია ჩართულია, `mesh=enabled`) - `catalog` + Sidecar-ის გარეშე `probe`;
- `legacy` (ინექცია არ არის ჩართული, `mesh` label არ აქვს) - `legacy-app`.

`istioctl` ხელმისაწვდომია worker PC-ზე.

## მიზანი

1. ჩართეთ **discovery selectors**, რათა istiod თვალს ადევნებდეს მხოლოდ `mesh=enabled` namespace-ებს
   (`legacy` გამოირიცხება).
2. დაამატეთ **Sidecar** egress-ის მოქმედების არეალი `app`-ში, რათა მისმა proxy-ებმა იცოდნენ მხოლოდ `app` + `istio-system`
   (`shop` გამოირიცხება).
3. დააკვირდით istiod-ის **golden signals**-ს.
4. დანერგვის policy აღასრულეთ **OPA Gatekeeper**-ის მეშვეობით.

## ნაბიჯი 1. Discovery selectors

ხელახლა გამოიყენეთ ინსტალაცია `meshConfig.discoverySelectors`-ით, რომელიც ემთხვევა `mesh=enabled`-ს
(`istio-system`, `app`, `shop` ატარებს მას, `legacy` კი არა):

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    discoverySelectors:
      - matchLabels:
          mesh: enabled
EOF
istioctl install -f /tmp/iop.yaml -y
```

შეამოწმეთ, რომ `legacy` გაქრა mesh-იდან (proxy-დან, რომელსაც ჯერ Sidecar-ის მოქმედების არეალი არ აქვს):

```bash
istioctl proxy-config clusters deploy/catalog.shop | grep legacy-app || echo "legacy dropped"
```

## ნაბიჯი 2. Sidecar egress-ის მოქმედების არეალი app-ში

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

`./*` = proxy-ის საკუთარი namespace (`app`), დამატებული `istio-system/*` control-plane-ისა და
gateway-ებისთვის. ყველაფერი დანარჩენი (მათ შორის `shop`) ამოღებულია `app` proxy-ებიდან:

```bash
istioctl proxy-config clusters deploy/frontend.app | grep catalog.shop || echo "shop dropped from app"
```

## ნაბიჯი 3. istiod-ის golden signals

```bash
# convergence time + push count (the key control-plane signals)
kubectl exec -n shop deploy/probe -c probe -- \
  curl -s http://istiod.istio-system:15014/metrics \
  | grep -E 'pilot_proxy_convergence_time|pilot_xds_pushes'

# how many proxies are connected / config sync state
istioctl proxy-status
```

`pilot_proxy_convergence_time` მთავარი signal-ია: რამდენი დრო სჭირდება ცვლილებას proxy-ებამდე მისაღწევად.
`pilot_xds_pushes` ითვლის push-ებს. convergence time-ის ზრდა ან push-ის შეცდომები ნიშნავს, რომ
control plane დატვირთვის ქვეშაა. ნაბიჯებში 1-2 გამოყენებული მოქმედების არეალის ბერკეტები სწორედ ამ დატვირთვას ამცირებს.

## ნაბიჯი 4. OPA Gatekeeper-ის დანერგვის policy

მოითხოვეთ, რომ ყველა namespace-მა მიუთითოს ინექციის label (თავში განხილული დანერგვის ჰიგიენის კლასიკური policy).
შექმენით template და constraint:

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("namespace is missing required labels: %v", [missing])
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-injection
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["istio-injection"]
EOF
```

შეამოწმეთ, რომ policy აღსრულებულია (უნდა იყოს **denied**):

```bash
kubectl create ns test-no-label
# Error ... admission webhook "validation.gatekeeper.sh" denied the request:
# namespace is missing required labels: {"istio-injection"}
```

## რატომ მუშაობს ეს

- **Discovery selectors** ზღუდავს, თუ რომელ namespace-ებს აკვირდება istiod საერთოდ. selector label-ის გარეშე
  namespace-ები უხილავია control plane-ისთვის. მათი service-ები არასდროს გარდაიქმნება
  cluster-ებად/endpoint-ებად არცერთ proxy-ზე, რაც ამცირებს config-ის ზომასა და push-ის სამუშაოს. ყველაზე დიდი სარგებელი მიიღება, როცა
  კლასტერის ნაწილი mesh-ში არ არის.
- **Sidecar egress scope** თითოეული namespace-ისთვის ზღუდავს, თუ რომელი service-ების შესახებ მიეწოდება ინფორმაცია proxy-ს.
  `./*` + `istio-system/*`-ის გამოყენებისას `app` proxy აღარ შეიცავს `shop`-ის (ან
  mesh-ის დანარჩენი ნაწილის) config-ს. ეს ამცირებს თითოეული proxy-ის config-სა და istiod-იდან push fan-out-ს.
- **Golden signals** (`pilot_proxy_convergence_time`, `pilot_xds_pushes`, დაკავშირებული proxy-ები,
  istiod CPU/mem) აჩვენებს, ახერხებს თუ არა control plane დატვირთვასთან გამკლავებას; მოქმედების არეალის ბერკეტები არის
  convergence time-ის შემცირების მთავარი საშუალებები.
- **OPA Gatekeeper** საუკეთესო პრაქტიკებს admission rule-ებად გარდაქმნის: შეუსაბამო resource-ები
  შექმნისას უარყოფილია და არა უბრალოდ არასასურველად მიჩნეული.
