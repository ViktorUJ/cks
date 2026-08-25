[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 22 - Эталонное решение

Установлен Istio `1.29.1`. В пространстве имён `external` развёрнут «внешний»,
**только HTTPS** backend (без sidecar): nginx завершает TLS на порту `8443`, а Service
`httpsvc` предоставляет его на незашифрованном порту `80` (`targetPort: 8443`).
Внутримешевый клиент `app-client` работает в пространстве имён `app`.

## Цель

Настройте mesh для **инициации TLS** к внешнему сервису: приложение использует
незашифрованный HTTP для `httpsvc.external:80`, а его sidecar повышает уровень
соединения до TLS перед подключением к backend.

## Шаг 1. Наблюдение сбоя без инициации

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> 400 : plaintext hit the TLS-only port
```

## Шаг 2. Настройка инициации TLS с помощью DestinationRule

Backend использует самоподписанный сертификат, поэтому мы пропускаем проверку upstream с
помощью `insecureSkipVerify: true`. В production вместо этого следует указать для
`caCertificates` центр сертификации, подписавший upstream.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpsvc-tls-origination
  namespace: app
spec:
  host: httpsvc.external.svc.cluster.local
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 80
      tls:
        mode: SIMPLE
        insecureSkipVerify: true
EOF
```

## Шаг 3. Проверка

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -w "\nHTTP %{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> secure-ok
#    HTTP 200
```

## Как это работает

- Клиент отправляет незашифрованный **HTTP** на `httpsvc.external:80`. Никаких изменений
  в коде приложения и никаких сертификатов для управления в приложении.
- `DestinationRule` с `tls.mode: SIMPLE` на порту 80 указывает Envoy на стороне клиента
  **инициировать TLS** к upstream endpoints (к `targetPort: 8443` backend).
- Backend получает корректное TLS-соединение и возвращает `200`.
- В Istio `SIMPLE` по умолчанию **проверяет** сертификат upstream. Наш backend использует
  самоподписанный сертификат, поэтому мы устанавливаем `insecureSkipVerify: true`. В production
  вместо этого следует установить `caCertificates` (и при необходимости `subjectAltNames`) для
  проверки upstream либо использовать `MUTUAL` для аутентификации по сертификату клиента.

## Зачем инициировать TLS в mesh

- Приложения могут оставаться простыми (незашифрованный HTTP), пока весь TLS к внешним/legacy
  сервисам единообразно обрабатывается mesh.
- В сочетании с **egress gateway** (Лабораторная работа 05) инициацию можно централизовать на
  выделенном узле, чтобы весь исходящий TLS покидал cluster через один проверяемый и управляемый
  политиками hop.
