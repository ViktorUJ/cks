[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 15 - Эталонное решение

Используемая версия Istio: `1.29.1` (`istioctl` предустановлен на рабочем ПК).

## Цель

Установить Istio с **настраиваемой** конфигурацией с помощью манифеста `IstioOperator`:
- начать с профиля `default`;
- задать две опции `meshConfig`:
  - `accessLogFile: /dev/stdout` (логи доступа Envoy в stdout),
  - `outboundTrafficPolicy.mode: REGISTRY_ONLY` (блокировать исходящий трафик к неизвестным хостам);
- добавить **второй** компонент ingress gateway `ingressgateway-internal` наряду с
  стандартным `istio-ingressgateway`.

## Шаг 1. Создайте манифест IstioOperator

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

## Шаг 2. Установите Istio с пользовательским манифестом

```bash
istioctl install -f custom-istio.yaml -y
```

## Шаг 3. Проверьте установку

```bash
# control plane
kubectl get pods -n istio-system

# both ingress gateways
kubectl get deploy -n istio-system | grep -E 'ingressgateway'

# meshConfig landed in the istio configmap
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy|REGISTRY_ONLY'
```

Ожидаемый результат:
- `istiod` имеет статус `Running`;
- развёртывания `istio-ingressgateway` и `ingressgateway-internal` оба готовы;
- configmap `istio` содержит `accessLogFile: /dev/stdout` и
  `outboundTrafficPolicy.mode: REGISTRY_ONLY`.

## (необязательно) Шаг 4. Посмотрите REGISTRY_ONLY в действии

```bash
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
kubectl -n demo run curl --image=curlimages/curl -it --rm --restart=Never -- \
  sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://httpbin.org/get'
# -> 502 : egress is blocked because the host is not in the mesh registry
```

При `outboundTrafficPolicy: REGISTRY_ONLY` вызовы к внешним хостам, которые не
объявлены через `ServiceEntry`, отклоняются. Чтобы разрешить такой трафик, добавьте
`ServiceEntry` (см. лабораторную работу 05).