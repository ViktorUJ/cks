<!-- Standalone RU release: ссылки на переводы удалены, потому что соответствующие файлы не входят в архив. -->

# Глава 08. Secure Ingress с TLS

> **Что дальше.** В главе 07 мы проверяли и усиливали конфигурацию компонентов кластера.
> Теперь защитим публичную точку входа приложений. **Ingress с TLS** шифрует HTTP-трафик
> между клиентом и ingress controller, подтверждает имя сервера и не даёт перехватчику
> незаметно прочитать или подменить запрос. Это домен Cluster Setup (10%) CKS.

> **Что нужно из CKA.** Базовый синтаксис Ingress, Service и маршрутизация по host/path
> разобраны в [главе 32 CKA](../../../cka/course/32/ru.md). Устройство TLS, сертификат,
> закрытый ключ и проверка цепочки - в [главе 00-3 CKA](../../../cka/course/00-3-tls/ru.md).
> Здесь рассматриваем безопасное применение этих механизмов на публичном входе, а не
> повторяем их основы.

## 08.1. Модель угроз: почему HTTP на Ingress недостаточен

Ingress controller обычно принимает трафик из внешней сети и направляет его к Service,
а затем к Pod. Если клиент подключается по HTTP, логин, cookie, bearer token и содержимое
формы идут по сети открытым текстом. Пользователь в той же недоверенной сети, вредоносная
точка Wi-Fi или промежуточный прокси могут прочитать запрос либо подменить ответ.

TLS защищает канал от клиента до точки **TLS termination** - ingress controller. Контроллер
предъявляет сертификат для имени хоста, выполняет TLS handshake, расшифровывает запрос и
маршрутизирует обычный HTTP-трафик к backend. Поэтому TLS на внешнем входе не означает,
что путь controller -> Service -> Pod автоматически зашифрован. Для чувствительного
внутрикластерного трафика нужны отдельные меры: TLS у приложения, service mesh или Cilium
transparent encryption, которая рассматривается в главе 23.

```mermaid
flowchart LR
    client["Клиент"] -->|"HTTP: пароль и cookie<br>видны в сети"| bad["Перехватчик"]
    client -->|"HTTPS: TLS handshake<br>и шифрование"| ingress["NGINX Ingress Controller<br>TLS termination"]
    ingress -->|"HTTP или TLS<br>внутри кластера"| service["Service"]
    service --> pod["Pod приложения"]
    style client fill:#326ce5,color:#fff
    style bad fill:#db4437,color:#fff
    style ingress fill:#0f9d58,color:#fff
    style service fill:#673ab7,color:#fff
    style pod fill:#f4b400,color:#000
```

Нужны одновременно три свойства:

- конфиденциальность - трафик между клиентом и controller нельзя прочитать;
- целостность - нельзя незаметно изменить запрос или ответ;
- аутентичность - клиент проверяет, что сертификат выдан именно для запрошенного host.

Шифрование не исправляет небезопасный backend, избыточный RBAC или открытый endpoint.
Это один слой defense in depth. Также нельзя путать TLS certificate с Kubernetes Secret:
Secret хранит ключ и сертификат, но сам по себе не включает TLS, пока на него не сошлётся
Ingress.

## 08.2. Сертификат и ключ: тестовый self-signed и production-подход

Для лаборатории можно создать self-signed certificate. Клиент не доверяет ему по умолчанию,
поэтому при проверке будет нужен `curl -k`. Это нормально только для теста: флаг `-k`
отключает проверку сертификата и в production скрывает ошибки доверия и подмены.

Имя из URL должно присутствовать в **Subject Alternative Name** (SAN). Современные клиенты
проверяют SAN, а не только устаревшее поле Common Name (CN). Ниже сертификат рассчитан на
`app.example.test`; для другого имени измените и `HOST`, и `subjectAltName`.

```bash
export HOST=app.example.test

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout tls.key \
  -out tls.crt \
  -days 30 \
  -subj "/CN=${HOST}" \
  -addext "subjectAltName=DNS:${HOST}"

# До загрузки в кластер проверить subject и SAN
openssl x509 -in tls.crt -noout -subject -ext subjectAltName

# Публичный ключ certificate обязан совпадать с публичным ключом private key.
# Хеши двух команд должны быть одинаковыми.
openssl x509 -in tls.crt -pubkey -noout \
  | openssl pkey -pubin -outform DER | sha256sum
openssl pkey -in tls.key -pubout -outform DER \
  | sha256sum

# Для CA certificate проверить цепочку: leaf -> intermediate -> trusted root.
# `tls.crt` для controller обычно содержит leaf, затем intermediate; root в него не кладут.
openssl verify -show_chain -CAfile root-ca.crt \
  -untrusted intermediate-ca.crt leaf.crt
```

До создания Secret совпадение публичных ключей исключает пару certificate/key от разных
выпусков. В выводе `openssl verify -show_chain` leaf должен быть проверен через
intermediate до доверенного root; ошибка на любом звене означает, что такой certificate
нельзя загружать.

Параметр `-nodes` оставляет закрытый ключ без passphrase. Это необходимо, потому что
controller должен прочитать ключ без интерактивного ввода. Защита в этом случае строится на
строгом RBAC для Secret, ограничении доступа к etcd и encryption at rest - не на passphrase
в файле ключа.

В production не создавайте долгоживущие self-signed certificate вручную. Обычно
`cert-manager` получает сертификат у доверенного CA, например Let's Encrypt, кладёт его в
Secret и обновляет до истечения срока. Команда платформы должна также определить владельца
сертификата, оповещение об истечении и процедуру ротации. Если TLS завершается перед
кластером на cloud load balancer, проверьте, что соединение до NGINX также соответствует
требованиям организации: TLS может понадобиться и на этом участке.

## 08.3. TLS Secret: формат и область видимости

Ingress ищет certificate и key в Secret типа `kubernetes.io/tls`. Наиболее надёжный способ
создать его из уже проверенных файлов - `kubectl create secret tls`: команда сама положит
сертификат в ключ `tls.crt`, а закрытый ключ в `tls.key`.

```bash
kubectl -n web create secret tls app-example-tls \
  --cert=tls.crt \
  --key=tls.key

kubectl -n web get secret app-example-tls \
  -o jsonpath='{.type}{"\n"}{.data.tls\.crt}{"\n"}{.data.tls\.key}{"\n"}'
# kubernetes.io/tls
# base64-значения tls.crt и tls.key
```

Тот же объект в виде манифеста выглядит так. Здесь `data` намеренно не заполнен: ключ и
сертификат нельзя хранить в Git в открытом виде. `stringData` удобнее для коротких
тестовых значений, но не делает секретным содержимое репозитория.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-example-tls
  namespace: web
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-certificate>
  tls.key: <base64-encoded-private-key>
```

Secret namespaced. Ingress в namespace `web` не может сослаться на Secret из `default` или
другого namespace. Не давайте приложению право `get`/`list` всех Secret только ради TLS:
обычно certificate обслуживает controller, а доступ к созданию и чтению таких Secret
ограничен отдельной ролью. Base64 в `data` - это кодирование, а не encryption.

## 08.4. Ingress: связать host, TLS Secret и backend

Переносимые поля Ingress API здесь - `spec.tls` (`hosts`, `secretName`) и `spec.rules`
(`host`, `path`, `pathType`, `backend`). Они описывают TLS certificate и маршрутизацию, но
**не** задают HTTP -> HTTPS redirect. `spec.ingressClassName` - тоже поле API, однако само
значение класса, например `nginx`, выбирает конкретную реализацию. Аннотации, включая
`nginx.ingress.kubernetes.io/*`, вообще не входят в Ingress API: их смысл определяет только
соответствующий controller.

Сопоставление host важно дважды: controller выбирает правильный certificate во время TLS
handshake, а клиент проверяет, что имя из URL есть в SAN. Перед применением убедитесь, что
нужный класс и Service существуют:

```bash
kubectl get ingressclass
kubectl -n web get service web
```

Ниже предполагается, что Service `web` в namespace `web` слушает порт 80. Манифест не
создаёт Service или Deployment: это CKA-база и они должны существовать отдельно.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-secure
  namespace: web
spec:
  # Поле API; имя `nginx` - выбор реализации, а не переносимое значение.
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.test
    secretName: app-example-tls
  rules:
  - host: app.example.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

Проверить связь объектов можно без внешнего DNS:

```bash
kubectl -n web describe ingress web-secure
kubectl -n web get ingress web-secure -o yaml
kubectl -n web get secret app-example-tls -o jsonpath='{.type}{"\n"}'
```

В выводе `describe` проверьте `Ingress Class`, правило для `app.example.test`, TLS host и
Secret. Событие об ошибке чтения Secret, пустое поле `ADDRESS` или backend без endpoints
означают, что запрос ещё не готов проверять TLS: сначала исправьте controller, Secret,
Service или готовность Pod.

## 08.5. ingress-nginx для экзамена: redirect и границы аннотаций

> **NGINX Ingress Controller retired.** Проект `ingress-nginx` объявлен retired (март 2026) и больше не получает релизов и security-фиксов ([анонс](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)). Экзамен CKS сохраняет компетенцию «Ingress с TLS» и может использовать NGINX Ingress как готовый fixture, поэтому его синтаксис (`ingressClassName: nginx`, аннотации) нужен для экзамена. Но для production не разворачивайте retired-controller на новых кластерах: выбирайте поддерживаемый Ingress Controller или мигрируйте на Gateway API. Навык `spec.tls` + TLS Secret универсален и от конкретного controller не зависит.

Даже корректный TLS Ingress оставляет риск, если HTTP остаётся доступным: пользователь может
перейти по старой ссылке, а cookie или форма уйдут до первого HTTPS-ответа. Для
**ingress-nginx** наличие блока `spec.tls` по умолчанию включает redirect HTTP -> HTTPS
(обычно `308`), если это не переопределено настройкой controller. Поэтому одновременно
задавать `ssl-redirect` и `force-ssl-redirect` не требуется и для обычного TLS Ingress
неверно как обязательный рецепт.

Это именно семантика ingress-nginx, а не Ingress API. Если нужно явно переопределить
настройку ingress-nginx для Ingress с `spec.tls`, применяют только его controller-specific
аннотацию `ssl-redirect`:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

`force-ssl-redirect` оставляют для другой топологии: TLS завершается **внешним** load
balancer/proxy, controller получает HTTP, и у Ingress нет блока `spec.tls`. При этом внешний
proxy должен корректно передавать информацию об исходной HTTPS-схеме, иначе возможен
redirect loop. Например, отдельный Ingress для такой external SSL offload-конфигурации:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-external-tls
  namespace: web
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

Не заменяйте redirect приложением, если его можно обеспечить на edge. Иначе каждый backend
должен повторять одинаковую настройку, а случайно добавленный Service может остаться
доступным по HTTP. HSTS дополняет redirect после первого успешного HTTPS-подключения, но не
заменяет TLS и требует отдельной осторожной политики для доменов и поддоменов.

### Gateway API: текущий production-путь

Для нового production-кластера используйте поддерживаемую реализацию Gateway API. В примере
ниже `platform-gateway` - **implementation-specific** имя `GatewayClass`: его предоставляет
выбранный Gateway controller, это не стандартное значение Kubernetes. `certificateRefs`
ссылается на тот же TLS Secret в namespace `web`; HTTPS listener выполняет TLS termination,
а `HTTPRoute` направляет запрос к Service.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: web
spec:
  gatewayClassName: platform-gateway # имя зависит от Gateway controller
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: app.example.test
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: app-example-tls
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-secure
  namespace: web
spec:
  parentRefs:
  - name: web-gateway
    sectionName: https
  hostnames:
  - app.example.test
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: web
      port: 80
```

Если Gateway также открывает порт 80, добавьте отдельный HTTP listener и `HTTPRoute` с
стандартным фильтром `RequestRedirect` на `https`; не смешивайте его с HTTPS-route к backend.
Проверьте поддерживаемые `GatewayClass` через `kubectl get gatewayclass` и статус Gateway
перед миграцией трафика.

## 08.6. Проверка: redirect, HTTPS, host и сертификат

Получите IP или hostname ingress controller. Для локального кластера может понадобиться
адрес NodePort или `kubectl port-forward`; для LoadBalancer дождитесь внешнего адреса.

```bash
kubectl -n ingress-nginx get service ingress-nginx-controller
kubectl -n web get ingress web-secure

export HOST=app.example.test
export INGRESS_IP=203.0.113.10  # замените на адрес ingress controller
```

Если тестовый host не опубликован в DNS, `--resolve` заставит `curl` использовать
`INGRESS_IP`, сохранив правильный Host header и SNI. Первая команда должна показать
`308` и `Location: https://app.example.test/...`; `-I` не следует за redirect.

```bash
# HTTP не обслуживает приложение: постоянный redirect на HTTPS
curl -kvI --resolve "${HOST}:80:${INGRESS_IP}" "http://${HOST}/"

# Следовать redirect. Оба --resolve нужны для портов 80 и 443.
curl -kvL \
  --resolve "${HOST}:80:${INGRESS_IP}" \
  --resolve "${HOST}:443:${INGRESS_IP}" \
  "http://${HOST}/"

# TLS-запрос приходит к backend и должен вернуть 200.
# -k допустим здесь только потому, что сертификат self-signed.
curl -kvsS -o /dev/null -w 'HTTP %{http_code}\n' \
  --resolve "${HOST}:443:${INGRESS_IP}" \
  "https://${HOST}/"
# HTTP 200
```

Проверяйте не только статус `200`, но и сертификат, который получил клиент. `-servername`
включает SNI: без него controller в кластере с несколькими host может отдать default
certificate.

```bash
openssl s_client -connect "${INGRESS_IP}:443" -servername "${HOST}" </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -ext subjectAltName
# subject=CN = app.example.test
# X509v3 Subject Alternative Name:
#     DNS:app.example.test
```

Для сертификата от доверенного CA уберите `-k`: обычный `curl` обязан успешно проверить
цепочку и имя. Если `curl` сообщает `SSL certificate problem`, не обходите проблему в
production. Проверьте срок действия, SAN, цепочку CA, `secretName`, namespace и то, что
controller действительно перечитал обновлённый Secret.

| Симптом | Что проверить | Вероятная причина |
|---|---|---|
| HTTP возвращает backend `200` | Аннотации и фактический controller | Нет `ssl-redirect`, controller не NGINX или его конфигурация переопределяет redirect |
| HTTPS показывает default certificate | `spec.tls.hosts`, SAN и SNI | Host не совпадает, Secret не найден или запрос без `--resolve`/SNI |
| `curl` получает `404` от NGINX | Host, `rules.host`, `ingressClassName` | Запрос попал в controller, но правило не выбрано |
| HTTPS возвращает `503` | Service, endpoints и readiness Pod | TLS работает, но backend недоступен |
| Secret есть, но TLS не включился | `type`, `tls.crt`, `tls.key`, namespace | Неверный тип, пустой/несовместимый ключ либо Secret в другом namespace |
| Браузер не доверяет сертификату | Issuer, цепочка и срок действия | Self-signed certificate или неполная цепочка CA |

## 08.7. Как это применяют в продакшене

- **Автоматическая выдача и ротация.** `cert-manager` и доверенный CA выпускают certificate,
  продлевают его до истечения и обновляют TLS Secret. Команда следит за метриками срока
  действия и получает alert заранее.
- **HTTPS по умолчанию.** Для ingress-nginx `spec.tls` по умолчанию даёт redirect;
  `ssl-redirect` - только явное controller-specific переопределение. `force-ssl-redirect`
  применяют лишь при external TLS offload без блока `spec.tls`. Внешний load balancer,
  controller и приложение согласованно обрабатывают proxy headers, чтобы не получить
  redirect loop.
- **План миграции API.** Для новых кластеров Gateway с HTTPS listener и `certificateRefs`
  вместе с `HTTPRoute` заменяет retired ingress-nginx; конкретный `GatewayClass` выбирает
  установленная реализация.
- **Минимальный доступ к ключам.** RBAC даёт права на TLS Secret только controller и
  автоматизации сертификатов. Secret encryption at rest и защищённый etcd уменьшают риск
  раскрытия private key.
- **Разделение границ.** Отдельные namespace, IngressClass и certificate для tenant либо
  критичных доменов уменьшают вероятность случайно отдать чужой certificate или маршрут.
- **Проверка после каждого изменения.** Pipeline делает HTTPS-запрос с правильным SNI,
  проверяет ожидаемый SAN, срок действия, 30x-redirect и доступность backend. Это ловит
  ошибку до того, как её увидит пользователь.

## 08.8. Мини-глоссарий

- **TLS termination** - завершение TLS handshake и расшифровка трафика на ingress controller.
- **Ingress** - API-объект с правилами внешней HTTP/HTTPS-маршрутизации к Service.
- **IngressClass** - выбор реализации Ingress, например NGINX Ingress Controller; имя
  класса зависит от установленного controller.
- **GatewayClass** - выбор реализации Gateway API; его имя также implementation-specific.
- **TLS Secret** - Secret типа `kubernetes.io/tls` с ключами `tls.crt` и `tls.key`.
- **SAN** - Subject Alternative Name, список DNS-имён/IP-адресов, для которых действителен
  certificate.
- **SNI** - Server Name Indication, имя host в TLS handshake для выбора certificate.
- **self-signed certificate** - certificate, подписанный собственным ключом, а не доверенным
  CA; подходит для теста, но не доверен клиентами по умолчанию.
- **HTTP -> HTTPS redirect** - постоянное перенаправление незашифрованного запроса на HTTPS.

## 08.9. Итоги главы

- TLS на Ingress защищает внешний HTTP-канал от перехвата и подмены до точки TLS termination.
- Для теста можно создать self-signed certificate через `openssl`, но SAN обязан содержать
  host, а `curl -k` нельзя оставлять в production.
- До создания Secret публичные ключи certificate и private key должны совпадать, а цепочка
  должна проверяться как leaf -> intermediate -> trusted root. `kubectl create secret tls`
  создаёт Secret типа `kubernetes.io/tls` с `tls.crt` и `tls.key`; Ingress и Secret должны
  быть в одном namespace.
- В `spec.tls` связывают переносимые API-поля `hosts` и `secretName`; `ingressClassName`
  выбирает реализацию, а имя `nginx` и её аннотации - не переносимы.
- В ingress-nginx `spec.tls` по умолчанию включает HTTP -> HTTPS redirect. `ssl-redirect`
  можно задать как явное переопределение только для ingress-nginx; `force-ssl-redirect`
  нужен для external TLS offload без блока `spec.tls`.
- Для новых production-кластеров используйте Gateway API: HTTPS listener с
  `certificateRefs` и `HTTPRoute`; `GatewayClass` выбирается реализацией.
- Проверка должна включать SNI и SAN сертификата, Service endpoints и события Ingress, а не
  только наличие YAML-объектов.

## 08.10. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** Нужно быстро сгенерировать certificate для заданного host, до создания
Secret сверить public key certificate/key и цепочку, сослаться на Secret в `spec.tls` Ingress
и подтвердить конфигурацию. Внимательно проверяйте namespace, `secretName`, `hosts` и
`ingressClassName`. Для ingress-nginx TLS Ingress по умолчанию перенаправляет HTTP на HTTPS;
в задаче с external TLS offload без `spec.tls` может понадобиться `force-ssl-redirect`.
Ожидайте 308 на HTTP и успешный HTTPS-вызов через `curl --resolve`.

**В реальной работе.** Secure Ingress - граница между недоверенным клиентом и приложением.
Надёжная конфигурация объединяет автоматическую ротацию certificate, минимальный доступ к
private key, строгую проверку SAN, обязательный HTTPS и непрерывные synthetic-проверки.
Одна неправильная аннотация или Secret в другом namespace способна оставить публичный
endpoint без ожидаемой защиты.

## 08.11. Вопросы для самопроверки

1. Где заканчивается защита TLS при TLS termination на Ingress и почему это не гарантирует
   шифрование между controller и Pod?
2. Почему одного CN недостаточно и какое поле certificate должен содержать DNS host?
3. Какой тип и какие ключи должен иметь TLS Secret для Ingress?
4. Почему Ingress и его TLS Secret должны находиться в одном namespace?
5. Почему ingress-nginx с `spec.tls` по умолчанию делает redirect и когда нужна
   controller-specific аннотация `force-ssl-redirect`?
6. Какие два результата ожидаются от `curl` для HTTP и HTTPS после настройки redirect?
7. Как до создания Secret подтвердить совпадение public key certificate/key и цепочку
   leaf -> intermediate -> root?
8. Почему `curl -k` приемлем для self-signed certificate в лаборатории, но опасен в
   production?
9. Почему `GatewayClass` нельзя считать переносимым именем и как HTTPS listener связывает
   Gateway с certificate через `certificateRefs`?

## Практика

🧪 Лаба 103 (CIS, Secure Ingress TLS, TLS hardening и проверка бинарников):
[tasks/cks/labs/103](../../labs/103/README_RU.MD)

🎮 Killercoda (в браузере, без установки): [Ingress Controller](https://killercoda.com/kubernetes-basics/course/kubernetes-fundamentals/ingress-controller) · [Create TLS Certificate](https://killercoda.com/kubernetes-basics/course/kubernetes-fundamentals/create-tls-certificate)

---
[Оглавление](../README_RU.md) · [Глава 07](../07/ru.md) · [Глава 09](../09/ru.md)
