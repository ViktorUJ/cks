[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 33 - Эталонное решение

Istio `1.29.1` (профиль по умолчанию, обнаружение на уровне всего кластера, без области Sidecar) и OPA
Gatekeeper предустановлены. Существуют три пространства имён:

- `app` (инъекция включена, `mesh=enabled`) - `frontend`;
- `shop` (инъекция включена, `mesh=enabled`) - `catalog` + `probe` без sidecar;
- `legacy` (инъекция НЕ включена, без метки `mesh`) - `legacy-app`.

`istioctl` доступен на рабочем ПК.

## Цель

1. Включить **селекторы обнаружения**, чтобы istiod отслеживал только пространства имён с `mesh=enabled`
   (исключает `legacy`).
2. Добавить область исходящего трафика **Sidecar** в `app`, чтобы его прокси знали только `app` + `istio-system`
   (исключает `shop`).
3. Наблюдать **ключевые сигналы** istiod.
4. Принудительно применить политику развёртывания с помощью **OPA Gatekeeper**.

## Шаг 1. Селекторы обнаружения

Повторно примените установку с `meshConfig.discoverySelectors`, соответствующим `mesh=enabled`
(`istio-system`, `app`, `shop` имеют эту метку; `legacy` не имеет):

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

Убедитесь, что `legacy` исчез из mesh (из прокси, у которого ещё нет области Sidecar):

```bash
istioctl proxy-config clusters deploy/catalog.shop | grep legacy-app || echo "legacy dropped"
```

## Шаг 2. Область исходящего трафика Sidecar в app

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

`./*` = собственное пространство имён прокси (`app`), плюс `istio-system/*` для control-plane и
шлюзов. Всё остальное (включая `shop`) удаляется из прокси `app`:

```bash
istioctl proxy-config clusters deploy/frontend.app | grep catalog.shop || echo "shop dropped from app"
```

## Шаг 3. Ключевые сигналы istiod

```bash
# convergence time + push count (the key control-plane signals)
kubectl exec -n shop deploy/probe -c probe -- \
  curl -s http://istiod.istio-system:15014/metrics \
  | grep -E 'pilot_proxy_convergence_time|pilot_xds_pushes'

# how many proxies are connected / config sync state
istioctl proxy-status
```

`pilot_proxy_convergence_time` является главным сигналом: как долго изменение доходит до
прокси. `pilot_xds_pushes` подсчитывает отправки. Рост времени конвергенции или ошибки отправки означают,
что control plane испытывает нагрузку - механизмы области действия в шагах 1-2 уменьшают её.

## Шаг 4. Политика развёртывания OPA Gatekeeper

Требуйте, чтобы каждое пространство имён объявляло метку инъекции (классическая политика гигиены
развёртывания из главы). Создайте шаблон и ограничение:

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

Убедитесь, что политика применяется (должно быть **отклонено**):

```bash
kubectl create ns test-no-label
# Error ... admission webhook "validation.gatekeeper.sh" denied the request:
# namespace is missing required labels: {"istio-injection"}
```

## Почему это работает

- **Селекторы обнаружения** ограничивают, какие пространства имён istiod вообще отслеживает. Пространства имён без
  метки селектора невидимы для control plane - их сервисы никогда не становятся
  clusters/endpoints ни на одном прокси, что сокращает размер конфигурации и работу по отправке. Наибольшая выгода, когда
  часть кластера не находится в mesh.
- **Область исходящего трафика Sidecar** ограничивает для каждого пространства имён, о каких сервисах сообщается прокси.
  С `./*` + `istio-system/*` прокси `app` больше не содержит конфигурацию для `shop` (или
  остальной части mesh). Это сокращает конфигурацию каждого прокси и fan-out отправки от istiod.
- **Ключевые сигналы** (`pilot_proxy_convergence_time`, `pilot_xds_pushes`, подключённые прокси,
  istiod CPU/mem) показывают, успевает ли control plane; механизмы области действия являются
  основными инструментами для уменьшения времени конвергенции.
- **OPA Gatekeeper** превращает лучшие практики в правила admission: несоответствующие ресурсы
  отклоняются при создании, а не просто не рекомендуются.
