[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 15 - ეტალონური გადაწყვეტა

გამოყენებული Istio-ს ვერსია: `1.29.1` (`istioctl` წინასწარ არის დაყენებული worker PC-ზე).

## მიზანი

დააყენეთ Istio **მორგებული** კონფიგურაციით, `IstioOperator` მანიფესტის გამოყენებით:
- დაიწყეთ `default` პროფილით;
- დააყენეთ `meshConfig`-ის ორი პარამეტრი:
  - `accessLogFile: /dev/stdout` (Envoy-ს წვდომის ჟურნალები stdout-ში),
  - `outboundTrafficPolicy.mode: REGISTRY_ONLY` (უცნობ ჰოსტებთან გამავალი ტრაფიკის დაბლოკვა);
- ნაგულისხმევ `istio-ingressgateway`-სთან ერთად დაამატეთ **მეორე** ingress gateway კომპონენტი `ingressgateway-internal`.

## ნაბიჯი 1. დაწერეთ IstioOperator მანიფესტი

```bash
cat > custom-istio.yaml <<'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: custom-istio
spec:
  profile: default
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
      - name: ingressgateway-internal
        enabled: true
        label:
          istio: ingressgateway-internal
        k8s:
          service:
            type: ClusterIP
EOF
```

## ნაბიჯი 2. დააყენეთ Istio მორგებული მანიფესტით

```bash
istioctl install -f custom-istio.yaml -y
```

## ნაბიჯი 3. შეამოწმეთ ინსტალაცია

```bash
# control plane
kubectl get pods -n istio-system

# both ingress gateways
kubectl get deploy -n istio-system | grep -E 'ingressgateway'

# meshConfig landed in the istio configmap
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy|REGISTRY_ONLY'
```

მოსალოდნელი შედეგი:
- `istiod` არის `Running` მდგომარეობაში;
- deployment-ები `istio-ingressgateway` და `ingressgateway-internal` ორივე მზადაა;
- `istio` configmap შეიცავს `accessLogFile: /dev/stdout`-სა და
  `outboundTrafficPolicy.mode: REGISTRY_ONLY`-ს.

## (არასავალდებულო) ნაბიჯი 4. იხილეთ REGISTRY_ONLY მოქმედებაში

```bash
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
kubectl -n demo run curl --image=curlimages/curl -it --rm --restart=Never -- \
  sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://httpbin.org/get'
# -> 502 : egress is blocked because the host is not in the mesh registry
```

`outboundTrafficPolicy: REGISTRY_ONLY`-ის გამოყენებისას გარე ჰოსტებთან გამოძახებები, რომლებიც
`ServiceEntry`-ის საშუალებით არ არის დეკლარირებული, უარყოფილია. ასეთი ტრაფიკის დასაშვებად უნდა დაამატოთ
`ServiceEntry` (იხილეთ ლაბორატორია 05).
