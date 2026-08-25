[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 34 - эталонное решение

Istio `1.29.1` (профиль по умолчанию, PERMISSIVE mTLS, `ALLOW_ANY` egress, без authz) и OPA
Gatekeeper предварительно установлены. Пространство имен `app` (с инъекцией) содержит `frontend`, а также два curl
клиента `good` (SA `good`) и `bad` (SA `bad`) и SA `mesh-editor`; пространство имен
`legacy` (без инъекции) содержит curl-клиент `legacy` без sidecar. `istioctl` доступен на
рабочем ПК.

## Цель (многоуровневая защита)

1. **STRICT mTLS** во всей mesh.
2. **Запрет по умолчанию** авторизации + целевое разрешение для `good`.
3. **Контроль egress**: `REGISTRY_ONLY`.
4. **RBAC для Istio CRD**: разрешить конфигурацию Istio, но запретить `EnvoyFilter`.
5. **OPA Gatekeeper**: отклонять `PeerAuthentication` с `mode: DISABLE`.
6. **Устойчивость к обходу sidecar**: NetworkPolicy как независимый уровень L3/L4.

## Шаг 1. STRICT mTLS (во всей mesh)

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system      # root namespace -> mesh-wide
spec:
  mtls:
    mode: STRICT
EOF
```

Теперь curl-клиент `legacy` без sidecar (plaintext) больше не может обратиться к `frontend`:

```bash
kubectl exec -n legacy deploy/legacy -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://frontend.app.svc.cluster.local:8080/
# connection reset / 000
```

## Шаг 2. Запрет по умолчанию + целевое разрешение

```bash
# default-deny for the whole app namespace (empty spec)
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: app
spec: {}
EOF

# allow only the "good" identity to call frontend
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-good
  namespace: app
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/app/sa/good"]
EOF
```

```bash
kubectl exec -n app deploy/good -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 200
kubectl exec -n app deploy/bad  -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 403
```

## Шаг 3. Контроль egress: REGISTRY_ONLY

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
EOF
istioctl install -f /tmp/iop.yaml -y

# external host that is not in the registry is now blocked
kubectl exec -n app deploy/good -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://www.example.com/   # 502 (blocked)
```

(Чтобы разрешить конкретный внешний хост, следует добавить `ServiceEntry`, см. lab 05.)

## Шаг 4. RBAC для Istio CRD (запретить EnvoyFilter)

`EnvoyFilter` является наиболее опасным Istio CRD: он внедряет необработанную конфигурацию Envoy. Предоставьте
управление конфигурацией Istio для `mesh-editor`, но **исключите** `envoyfilters`:

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mesh-editor
  namespace: app
rules:
  - apiGroups: ["networking.istio.io"]
    resources: ["virtualservices","destinationrules","gateways","serviceentries","sidecars","workloadentries"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["security.istio.io"]
    resources: ["authorizationpolicies","requestauthentications"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  # envoyfilters intentionally NOT granted
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mesh-editor
  namespace: app
roleRef:
  kind: Role
  name: mesh-editor
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: mesh-editor
    namespace: app
EOF
```

```bash
kubectl auth can-i create virtualservices.networking.istio.io --as=system:serviceaccount:app:mesh-editor -n app   # yes
kubectl auth can-i create envoyfilters.networking.istio.io     --as=system:serviceaccount:app:mesh-editor -n app   # no
```

## Шаг 5. OPA Gatekeeper: запрет отключения mTLS

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdenymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: K8sDenyMtlsDisable
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenymtlsdisable
        violation[{"msg": msg}] {
          input.review.object.spec.mtls.mode == "DISABLE"
          msg := "PeerAuthentication with mode: DISABLE is not allowed"
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
      - apiGroups: ["security.istio.io"]
        kinds: ["PeerAuthentication"]
EOF
```

```bash
# should be DENIED
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: try-disable
  namespace: app
spec:
  mtls:
    mode: DISABLE
EOF
```

## Шаг 6. NetworkPolicy (устойчивость к обходу sidecar)

mTLS/authz работают в sidecar; при обходе sidecar трафиком они не применяются.
NetworkPolicy обеспечивается в ядре CNI (Calico), это независимый уровень L3/L4:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-allow-app
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
  ingress:
    # app port 8080 only from pods in the app namespace
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: app
      ports:
        - port: 8080
          protocol: TCP
    # istio sidecar health (15021) / metrics (15090) from anywhere (kubelet, prometheus)
    - ports:
        - port: 15021
          protocol: TCP
        - port: 15090
          protocol: TCP
EOF
```

Только pod в `app` могут обращаться к `frontend` по порту `8080`; трафик `legacy` отбрасывается еще до того, как
достигает sidecar. Порт `15021` остается открытым, чтобы проверка готовности kubelet для Istio
sidecar продолжала проходить (иначе pod станет NotReady).

## Почему это работает (модель угроз)

- **STRICT mTLS** - принимается только взаимно аутентифицированный mesh-трафик; plaintext и
  клиенты вне mesh отклоняются. Шифрование + идентификация сервиса.
- **Авторизация с запретом по умолчанию** - минимальные привилегии: ничего не разрешено, пока явный ALLOW
  не совпадет, что ограничивает радиус поражения скомпрометированной рабочей нагрузки.
- **REGISTRY_ONLY egress** - скомпрометированный pod не может передавать данные на произвольные внешние
  хосты; доступны только объявленные назначения.
- **RBAC для CRD** - ограничение `EnvoyFilter` (и конфигурации Istio в целом) не позволяет
  чрезмерно привилегированному пользователю перепрограммировать плоскость данных.
- **OPA Gatekeeper** - превращает правило "никогда не отключать mTLS" в строгое правило admission, а не в соглашение.
- **NetworkPolicy** - независимый контроль на уровне ядра, который сохраняется даже при обходе sidecar
  - многоуровневая защита.
