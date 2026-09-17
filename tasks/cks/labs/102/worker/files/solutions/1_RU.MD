[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 102 - эталонное решение: CiliumNetworkPolicy L3/L4/L7 и Hubble

Все команды выполняются на worker. Перед началом убедитесь, что выбран правильный контекст:

```bash
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
cilium status --wait
```

## Задание 1. Namespace и учебные приложения

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: cks-102
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: cks-102
  labels:
    app: backend
spec:
  containers:
    - name: nginx
      image: nginx:1.27-alpine
      ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: cks-102
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: cks-102
  labels:
    role: frontend
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.10.1
      command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: cks-102
  labels:
    role: untrusted
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.10.1
      command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/backend pod/frontend pod/client -n cks-102 --timeout=180s
```

## Задание 2. CiliumNetworkPolicy L3/L4

Сначала baseline: пока никакой `CiliumNetworkPolicy` не выбирает backend, оба Pod должны
реально его достигать. Без этого шага таймаут `client` после policy нельзя было бы отличить
от посторонней сетевой проблемы.

```bash
mkdir -p /var/work/tests/artifacts/2
{
  printf 'baseline frontend: '
  frontend_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/)
  frontend_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$frontend_rc" "$frontend_code"
  printf 'baseline client: '
  client_code=$(kubectl exec -n cks-102 client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/)
  client_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$client_rc" "$client_code"
} > /var/work/tests/artifacts/2/l3-l4.txt
cat /var/work/tests/artifacts/2/l3-l4.txt

# Реально проверяем baseline, а не только печатаем результат.
if [[ "$frontend_rc" -eq 0 && "$frontend_code" =~ ^[1-5][0-9][0-9]$ ]]; then
  echo "OK: baseline frontend reaches backend (exit=$frontend_rc http=$frontend_code)"
else
  echo "FAIL: baseline frontend did NOT reach backend (exit=$frontend_rc http=$frontend_code) - fix connectivity before applying any policy" >&2
fi
if [[ "$client_rc" -eq 0 && "$client_code" =~ ^[1-5][0-9][0-9]$ ]]; then
  echo "OK: baseline client reaches backend (exit=$client_rc http=$client_code)"
else
  echo "FAIL: baseline client did NOT reach backend (exit=$client_rc http=$client_code) - fix connectivity before applying any policy" >&2
fi
```

Оба должны показать `CURL_EXIT=0` и реальный HTTP status (`1xx-5xx`) - это доказывает, что
backend в принципе достижим для обоих identity до применения policy. Если один из baseline
провалился, применять policy пока не имеет смысла - after-policy deny нельзя будет отличить
от уже существующей сетевой проблемы.

Теперь применяем policy. Она выбирает backend, поэтому для него включается ingress
enforcement. Разрешён только source с `role=frontend` и TCP/80; `client` под это правило не
подходит.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
EOF

{
  printf 'after-policy frontend: '
  frontend_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/)
  frontend_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$frontend_rc" "$frontend_code"
  printf 'after-policy client: '
  client_code=$(kubectl exec -n cks-102 client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/ 2>&1)
  client_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$client_rc" "$client_code"
} >> /var/work/tests/artifacts/2/l3-l4.txt
cat /var/work/tests/artifacts/2/l3-l4.txt

# Строго проверяем ожидаемый результат, а не просто печатаем числа.
if [[ "$frontend_rc" -eq 0 && "$frontend_code" == "200" ]]; then
  echo "OK: frontend allowed with real 200 (exit=$frontend_rc http=$frontend_code)"
else
  echo "FAIL: frontend expected exit=0 http=200, got exit=$frontend_rc http=$frontend_code - check fromEndpoints selector" >&2
fi
if [[ "$client_code" == "000" && "$client_rc" =~ ^(7|28)$ ]]; then
  echo "OK: client denied at transport level (exit=$client_rc http=$client_code)"
else
  echo "FAIL: client expected http=000 with exit 7/28 (transport deny), got exit=$client_rc http=$client_code - a real HTTP response means L3/L4 deny did not work" >&2
fi
```

`frontend` должен дать `CURL_EXIT=0 HTTPCODE=200`. `client` должен дать именно
transport-level deny: `HTTPCODE=000` и `CURL_EXIT` `7`/`28` - не «любой код кроме 200», а
конкретно отсутствие HTTP-ответа. Реальный `403`/`404` здесь означал бы, что L3/L4 deny не
сработал, а до backend всё равно есть сетевой путь.

## Задание 3. Ограничение HTTP L7

Baseline при ещё действующей L4-only policy из задания 2: и GET, и POST должны реально
достигать backend, чтобы после включения L7 можно было доказать, что именно L7-фильтр
отклоняет POST, а не какая-то другая причина.

```bash
mkdir -p /var/work/tests/artifacts/3
{
  printf 'baseline GET /: '
  get_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/)
  get_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$get_rc" "$get_code"
  printf 'baseline POST /: '
  post_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -X POST -o /dev/null -w '%{http_code}' http://backend/)
  post_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$post_rc" "$post_code"
} > /var/work/tests/artifacts/3/l7-http.txt
cat /var/work/tests/artifacts/3/l7-http.txt

if [[ "$get_rc" -eq 0 && "$get_code" =~ ^[1-5][0-9][0-9]$ ]]; then
  echo "OK: baseline GET reaches backend (exit=$get_rc http=$get_code)"
else
  echo "FAIL: baseline GET did NOT reach backend (exit=$get_rc http=$get_code) - fix L4-only policy first" >&2
fi
if [[ "$post_rc" -eq 0 && "$post_code" =~ ^[1-5][0-9][0-9]$ ]]; then
  echo "OK: baseline POST reaches backend (exit=$post_rc http=$post_code)"
else
  echo "FAIL: baseline POST did NOT reach backend (exit=$post_rc http=$post_code) - fix L4-only policy first" >&2
fi
```

Оба запроса должны реально достигать backend (`CURL_EXIT=0`, любой реальный HTTP status) -
L4-only policy не смотрит внутрь HTTP, поэтому и GET, и POST на этом этапе проходят. Если
baseline не подтверждён, after-policy `403` для POST ничего не доказывает - он мог отсутствовать
уже до L7-правила по посторонней причине.

Заменяем L3/L4-правило, а не добавляем вторую широкую allow-политику: широкое правило на
TCP/80 сделало бы L7-ограничение неэффективным.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/"
EOF

{
  printf 'after-policy GET /: '
  get_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/)
  get_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$get_rc" "$get_code"
  printf 'after-policy POST /: '
  post_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -X POST -o /dev/null -w '%{http_code}' http://backend/)
  post_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$post_rc" "$post_code"
} >> /var/work/tests/artifacts/3/l7-http.txt
cat /var/work/tests/artifacts/3/l7-http.txt

if [[ "$get_rc" -eq 0 && "$get_code" == "200" ]]; then
  echo "OK: GET allowed by L7 rule (exit=$get_rc http=$get_code)"
else
  echo "FAIL: GET expected exit=0 http=200, got exit=$get_rc http=$get_code - check rules.http method/path" >&2
fi
if [[ "$post_rc" -eq 0 && "$post_code" == "403" ]]; then
  echo "OK: POST denied by L7 with 403 (exit=$post_rc http=$post_code)"
else
  echo "FAIL: POST expected exit=0 http=403 (L7 deny), got exit=$post_rc http=$post_code - check for a leftover broad L4-only rule on the same port" >&2
fi
```

Ожидаемые статусы после L7 - `200` для GET и `403` для POST, который отклоняет Envoy proxy
Cilium. Сравнение baseline/after-policy в одном файле доказывает переход именно L4→L7, а не
случайную сетевую проблему.

## Задание 4. DNS-aware egress через toFQDNs

Preflight до применения `frontend-fqdn`: подтверждаем, что DNS и все три контрольных
endpoint реально доступны, пока egress policy для frontend ещё не существует.

```bash
mkdir -p /var/work/tests/artifacts/4
{
  printf 'preflight dns: '
  kubectl exec -n cks-102 frontend -- getent hosts example.com >/dev/null 2>&1 && echo OK || echo FAIL
  printf 'preflight example.com HTTPS: '
  pre_https_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 10 -o /dev/null -w '%{http_code}' https://example.com/)
  pre_https_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$pre_https_rc" "$pre_https_code"
  printf 'preflight example.com HTTP: '
  pre_http_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://example.com:80/)
  pre_http_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$pre_http_rc" "$pre_http_code"
  printf 'preflight www.google.com HTTPS: '
  pre_google_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' https://www.google.com/)
  pre_google_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$pre_google_rc" "$pre_google_code"
} > /var/work/tests/artifacts/4/fqdn.txt
cat /var/work/tests/artifacts/4/fqdn.txt
```

DNS разрешается отдельным L7 DNS proxy rule: `toFQDNs` разрешает соединение с IP,
полученными для FQDN, но именно `toPorts.rules.dns` позволяет Cilium надёжно наблюдать DNS и
формировать FQDN-to-IP mapping. Для FQDN отдельно ограничиваем разрешённый транспорт HTTPS
(TCP/443), чтобы resolved IP не был доступен на произвольных портах.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-fqdn
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      role: frontend
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s:k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: ANY
          rules:
            dns:
              - matchPattern: "*"
    - toEndpoints:
        - matchLabels:
            app: backend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
    - toFQDNs:
        - matchName: example.com
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
EOF

{
  printf 'after-policy example.com HTTPS: '
  post_https_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 10 -o /dev/null -w '%{http_code}' https://example.com/)
  post_https_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$post_https_rc" "$post_https_code"
  printf 'after-policy example.com HTTP: '
  post_http_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://example.com:80/)
  post_http_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$post_http_rc" "$post_http_code"
  printf 'after-policy www.google.com HTTPS: '
  post_google_code=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' https://www.google.com/)
  post_google_rc=$?
  printf 'CURL_EXIT=%s HTTPCODE=%s\n' "$post_google_rc" "$post_google_code"
} >> /var/work/tests/artifacts/4/fqdn.txt
cat /var/work/tests/artifacts/4/fqdn.txt

# Интерпретация - только относительно собственного preflight. Если endpoint был
# недоступен уже на preflight, after-policy результат для него остаётся inconclusive
# и не считается доказательством allow/deny. Для доказательства сетевой достижимости
# любой реально полученный HTTP status (1xx-5xx) с CURL_EXIT=0 считается валидным -
# 401/403/404/429/5xx всё равно доказывают, что TCP/TLS/HTTP путь существует.
pre_https_ok=false
[[ "$pre_https_rc" -eq 0 && "$pre_https_code" =~ ^[1-5][0-9][0-9]$ ]] && pre_https_ok=true
pre_http_ok=false
[[ "$pre_http_rc" -eq 0 && "$pre_http_code" =~ ^[1-5][0-9][0-9]$ ]] && pre_http_ok=true
pre_google_ok=false
[[ "$pre_google_rc" -eq 0 && "$pre_google_code" =~ ^[1-5][0-9][0-9]$ ]] && pre_google_ok=true

if [[ "$pre_https_ok" == true ]]; then
  if [[ "$post_https_rc" -eq 0 && "$post_https_code" =~ ^[1-5][0-9][0-9]$ ]]; then
    echo "OK: example.com:443 remained network-reachable after policy"
  else
    echo "WARNING: example.com:443 was reachable on preflight but not after policy (exit=$post_https_rc http=$post_https_code) - check toFQDNs matchName/toPorts 443"
  fi
else
  echo "INCONCLUSIVE: example.com:443 was already unreachable on preflight (exit=$pre_https_rc http=$pre_https_code) - after-policy result for it cannot prove allow or deny"
fi

if [[ "$pre_http_ok" == true ]]; then
  if [[ "$post_http_code" == "000" && "$post_http_rc" =~ ^(7|28)$ ]]; then
    echo "OK: example.com:80 denied after policy, as expected (only TCP/443 is allowed)"
  else
    echo "WARNING: example.com:80 expected to be denied (http=000, exit 7/28) after policy, got exit=$post_http_rc http=$post_http_code - toPorts for the FQDN rule may be too broad"
  fi
else
  echo "INCONCLUSIVE: example.com:80 was already unreachable on preflight - after-policy result for it cannot prove allow or deny"
fi

if [[ "$pre_google_ok" == true ]]; then
  if [[ "$post_google_code" == "000" && "$post_google_rc" =~ ^(7|28)$ ]]; then
    echo "OK: www.google.com denied after policy, as expected (only example.com is in toFQDNs)"
  else
    echo "WARNING: www.google.com expected to be denied (http=000, exit 7/28) after policy, got exit=$post_google_rc http=$post_google_code - toFQDNs may be too broad (e.g. matchPattern instead of exact matchName)"
  fi
else
  echo "INCONCLUSIVE: www.google.com was already unreachable on preflight - after-policy result for it cannot prove allow or deny"
fi
```

Сетевые проверки к `example.com`/`www.google.com` записываются в артефакт как diagnostic
evidence, но не являются обязательным условием PASS для этого задания: IANA прямо
указывает, что HTTP-сервис example-доменов предоставляется best-effort и не
предназначен как testing endpoint для software, поэтому его временная недоступность
не должна засчитываться как ошибка policy. Graded критерий - структура
`CiliumNetworkPolicy` (`toFQDNs.matchName`, TCP `443`, отдельное правило `rules.dns`
для `kube-dns`) плюс сам факт наличия preflight/after-policy evidence.

Обязательный regression-check: `frontend-fqdn` включает egress default-deny для
`frontend`, поэтому без явного правила к `backend` уже разрешённый в заданиях 2-3 поток
`frontend -> backend:80` был бы заблокирован. Подтверждаем, что этого не произошло:

```bash
# GET должен остаться разрешён через backend L7 policy.
get_after_fqdn=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/)
get_after_fqdn_rc=$?
echo "frontend -> backend GET /: exit=$get_after_fqdn_rc http=$get_after_fqdn"

# POST должен по-прежнему дойти до L7 proxy и получить 403 от Envoy,
# а не transport-level timeout от egress policy.
post_after_fqdn=$(kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -X POST -o /dev/null -w '%{http_code}' http://backend/)
post_after_fqdn_rc=$?
echo "frontend -> backend POST /: exit=$post_after_fqdn_rc http=$post_after_fqdn"

if [[ "$get_after_fqdn_rc" -eq 0 && "$get_after_fqdn" == "200" ]]; then
  echo "OK: internal frontend -> backend GET still allowed after frontend-fqdn"
else
  echo "FAIL: frontend -> backend GET regressed (exit=$get_after_fqdn_rc http=$get_after_fqdn) - frontend-fqdn is missing the internal backend:80 egress rule" >&2
fi
if [[ "$post_after_fqdn_rc" -eq 0 && "$post_after_fqdn" == "403" ]]; then
  echo "OK: internal frontend -> backend POST still reaches L7 and gets 403 (not a transport deny)"
else
  echo "FAIL: frontend -> backend POST regressed to a transport-level deny (exit=$post_after_fqdn_rc http=$post_after_fqdn) instead of L7 403 - frontend-fqdn is missing the internal backend:80 egress rule" >&2
fi
```

## Задание 5. Evidence из Hubble

На worker relay включён стартовым скриптом. Откройте локальный port-forward, запустите
наблюдение, сгенерируйте GET и запрещённый POST, затем завершите оба фоновых процесса.

```bash
cilium hubble port-forward > /tmp/cilium-hubble-port-forward.log 2>&1 &
PF_PID=$!
sleep 3

mkdir -p /var/work/tests/artifacts/5
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf 'start=%s source=cks-102/frontend destination=cks-102/backend\nallowed=GET / denied=POST /\n' \
  "$START" > /var/work/tests/artifacts/5/test-window.txt

hubble observe --from-pod cks-102/frontend --to-pod cks-102/backend \
  --protocol http --since "$START" --output json --follow \
  > /var/work/tests/artifacts/5/hubble-observe.json &
OBSERVE_PID=$!
sleep 2

kubectl exec -n cks-102 frontend -- curl -sS http://backend/ -o /dev/null
kubectl exec -n cks-102 frontend -- curl -sS -X POST http://backend/ -o /dev/null || true
sleep 5
kill "$OBSERVE_PID" "$PF_PID" 2>/dev/null || true
```

Не ограничиваемся просмотром первых строк файла - самостоятельно валидируем, что нужные
test case реально попали в artifact, прежде чем считать задание выполненным:

```bash
allowed=$(jq -s '[.[] | (.flow // .) as $f | select(
  $f.source.namespace == "cks-102" and $f.source.pod_name == "frontend" and
  $f.destination.namespace == "cks-102" and $f.destination.pod_name == "backend" and
  $f.l7.http.method == "GET" and ($f.l7.http.url | endswith("/")) and
  $f.verdict == "FORWARDED"
)] | length' /var/work/tests/artifacts/5/hubble-observe.json)

denied=$(jq -s '[.[] | (.flow // .) as $f | select(
  $f.source.namespace == "cks-102" and $f.source.pod_name == "frontend" and
  $f.destination.namespace == "cks-102" and $f.destination.pod_name == "backend" and
  $f.l7.http.method == "POST" and ($f.l7.http.url | endswith("/")) and
  $f.verdict == "DROPPED"
)] | length' /var/work/tests/artifacts/5/hubble-observe.json)

echo "GET / FORWARDED flows: $allowed"
echo "POST / DROPPED flows: $denied"

if [[ "$allowed" -ge 1 && "$denied" -ge 1 ]]; then
  echo "OK: hubble-observe.json содержит оба ожидаемых test case."
else
  echo "FAIL: artifact не содержит нужные flow - повторите capture во время (не после) GET/POST." >&2
fi
```

Если `allowed` или `denied` равны `0` - artifact не годится, даже если файл непустой:
значит нужные flow не попали в capture window, и нужно повторить сбор evidence.


Здесь `--follow` выбран как удобный способ непрерывно собирать controlled test; это не единственный допустимый способ evidence. В пределах retention window можно выполнить обычный `hubble observe` после теста с точным `--since` и сохранить его вывод. В любом варианте verdict сам по себе недостаточен: evidence связывает временное окно, source/destination,
HTTP method/path и ожидаемый результат policy. Поток другого Pod не подтверждает этот test case.

Проверка всех заданий:

```bash
check_result
```
