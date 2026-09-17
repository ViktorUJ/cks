# Adversarial acceptance standard для CKS labs

Этот документ - чек-лист для авторов и ревьюеров лабораторных работ курса CKS
(`tasks/cks/labs/101` и далее). Он не заменяет существующие `README_RU.MD`/`tests.bats`
конкретных лаб, а формализует минимальный стандарт доказательности для **CKS Core
security-control labs** - тех, где студент настраивает или проверяет security control
(NetworkPolicy, RBAC, AppArmor/seccomp, encryption at rest, admission policy, supply chain
verification, audit/runtime detection и т.п.).

Не все лабы курса обязаны реализовывать весь стандарт буквально (например, лабы
исключительно на logistics/CLI без security control могут не иметь Negative control), но
каждая **CKS Core security-control lab** должна по возможности покрывать все шесть пунктов.

## 1. Positive control

То, что должно продолжать работать после применения control, действительно работает.

```text
frontend -> backend = allow
```

Без этого пункта студент может «защитить» систему, просто сломав легитимный доступ -
что не отличимо от настоящей security-меры без явной проверки, что нужный путь остался
открытым.

## 2. Negative/abuse control

То, что control должен блокировать, действительно блокируется.

```text
foreign Pod -> backend = deny
```

Тест не должен считать успехом любую ошибку (timeout, DNS failure, quota) - см. пункт 5
"No fake success" ниже.

## 3. Effective-state evidence

Доказательство состоит не только из чтения manifest/YAML, а из наблюдения фактического
runtime-состояния. Примеры того, что считается effective-state evidence:

- effective AppArmor profile (`aa-status`, не только `securityContext.appArmorProfile` в
  манифесте);
- effective seccomp mode процесса;
- фактический ciphertext в etcd (не факт наличия `EncryptionConfiguration`);
- фактический digest образа (`RepoDigests` из registry manifest, не `ImageID`/`DiffID`);
- фактическое audit-событие с нужными verb/stage;
- фактический CNI/Hubble flow (allowed/dropped), а не только текст `NetworkPolicy`.

## 4. Retest

После исправления (`Phase C`/hardening) повторяется **тот же самый** abuse-probe, который
использовался в unsafe-baseline. Если тест на "после" отличается от теста "до" по scope
или методу проверки, ревьюер должен явно спросить, действительно ли доказано устранение
именно этого abuse path.

## 5. No fake success

Тест не должен принимать любую ошибку как доказательство срабатывания конкретного control.

Примеры **неправильной** проверки:

```text
curl вернул код ошибки  -> считаем, что NetworkPolicy сработала
kubectl apply завершился с ненулевым exit code -> считаем, что именно эта VAP/policy отклонила запрос
```

Правильная проверка отличает:

- transport/API failure (сеть недоступна, DNS не резолвится, API server timeout);
- отказ другого механизма (RBAC, quota, другой admission webhook/policy);
- фактический deny **именно** проверяемого control (конкретный error message, policy/binding
  name, audit reason, HTTP status code).

Для этого тест должен захватывать stderr/response body и искать уникальный маркер
(имя policy/binding, validation message, конкретный HTTP-код), а не только exit code.

## 6. Safe fixtures only

Все identity, tokens, endpoints и данные, используемые в controlled abuse, должны быть:

- synthetic (fake secrets/markers, не реальные credentials);
- lab-owned (ServiceAccount/namespace/registry, созданные именно для лабы, не production);
- изолированы от внешних систем (локальный registry, а не публичный; fake metadata
  endpoint, а не реальный cloud IMDS);
- безопасны для повторного запуска и для параллельных студентов на общем кластере, если
  инфраструктура лабы это допускает.

Не использовать: реальные CVE exploit chains, kernel/container escape PoC, реальные cloud
credentials, реальные внешние цели.

Исключение: labs/101 намеренно использует реальный EC2 IMDS вместо синтетического
эндпоинта, потому что цель лабы - проверить фактическое поведение AWS IMDSv1/v2 (hop
limit, token flow), а не общий факт сетевой достижимости произвольного IP; риски описаны
в README лабы.

Исключение: labs/102 намеренно использует публичные DNS-имена `example.com` и
`www.google.com` для проверки Cilium `toFQDNs`. Механизм `toFQDNs` формирует
FQDN-to-IP mapping на основании DNS-ответов, наблюдаемых Cilium DNS proxy, поэтому для
этой лабораторной работы требуется реальный DNS/FQDN flow. `example.com` - зарезервированный
IANA домен для документационных примеров; его HTTP-сервис предоставляется best-effort и не
рассматривается как надёжный testing endpoint. `www.google.com` используется только как
безопасный внешний negative comparator. Перед применением FQDN policy лаба выполняет
baseline/preflight: если внешний endpoint уже недоступен до применения policy, такой
результат считается `inconclusive`, а не ошибкой policy, и не приводит сам по себе к
`FAIL`. Лаба не передаёт credentials, не выполняет state-changing requests и не использует
внешний сервис как объект controlled abuse - проверяется только DNS/FQDN reachability и
ограничение egress policy.

Исключение: labs/103 намеренно устанавливает `ingress-nginx controller-v1.15.1` на
Kubernetes `1.36.0`, хотя официальная support table этого релиза контроллера
перечисляет только `1.35-1.31` (Kubernetes `1.36` в неё не входит). Причина: лаба
целиком построена как forward-looking сценарий на версии Kubernetes новее текущей
экзаменационной (`1.35` на дату написания, см. README лабы), а `ingress-nginx` retired
с марта 2026 и не получит новых релизов, которые формально покрывали бы `1.36` - таким
образом любая версия контроллера для этой лабы гарантированно будет вне support table
для достаточно новой версии Kubernetes. Официальная support table прямо описывает
перечисленные версии как E2E-tested combinations ("Supported versions ... mean that we
have completed E2E tests, and they are passing for the versions listed"); для Kubernetes
`1.36` такой проверки и, соответственно, формальной гарантии совместимости нет - проект
не даёт и обратной гарантии, что версия заведомо не будет работать, просто это
не покрыто их E2E-матрицей. Чтобы это несоответствие не было тихим и непроверяемым
риском, bootstrap (`k8s-1/scripts/master.sh`) не считает установку успешной по факту
применения манифеста: он дожидается `condition=Available` у Deployment, затем проверяет
устойчивые postconditions admission webhook bootstrap-а - `Secret ingress-nginx-admission`,
непустой `caBundle` в `ValidatingWebhookConfiguration ingress-nginx-admission`, наличие
endpoint у `Service ingress-nginx-controller-admission`, и завершает проверку успешным
server-side dry-run (`kubectl apply --dry-run=server`) тестового `Ingress` с
`ingressClassName: nginx` - что подтверждает, что admission webhook path реально
принимает запросы, а не просто что связанные объекты существуют. Затем явно проверяет
наличие реального Pod IP в `Endpoints` основного `Service ingress-nginx-controller` -
то есть end-to-end preflight именно на этой версии Kubernetes, включая admission webhook
path, а не только readiness
самого Deployment. Если контроллер или его admission webhook не поднимаются на `1.36`
практически, bootstrap завершается `FATAL` и лаба не выдаётся студенту в
неработоспособном виде.

Исключение: labs/105 намеренно включает `ufw` (UFW) как host-level firewall на
одноузловом Kubernetes control-plane, использующем Calico как CNI. Официальная
документация Calico по требованиям (docs.tigera.io/calico/latest/getting-started/
kubernetes/requirements) прямо указывает: "If your Linux distribution comes with
installed Firewalld or another iptables manager it should be disabled. These may
interfere with rules added by Calico and result in unexpected behavior." UFW - это
iptables/nftables manager, поэтому совмещение UFW с Calico node - неоговорённая upstream
конфигурация, а не рекомендуемый общий способ ограничить host-level трафик на
Calico-ноде (для этого Calico предлагает `HostEndpoint`/`GlobalNetworkPolicy`). Лаба
сохраняет именно UFW - не потому что это production best practice, а потому что задание
7 CKS exam curriculum (`Minimize host OS footprint`, домен System Hardening) явно
включает host firewall configuration как отдельный практический навык, независимый от
CNI-специфичных механизмов, которые уже покрыты в лабе 102 (`CiliumNetworkPolicy`). README
лабы явно формулирует это как lab-specific exception, а не как общую рекомендацию совмещать
Calico с UFW на реальном кластере. Чтобы конфликт не был тихим и непроверяемым риском,
задание 3 реализует deterministic E2E contract вокруг UFW enable/reload:

- **Checker-owned bootstrap baseline** (`worker.sh`, до выдачи лабы студенту и до
  какого-либо изменения UFW): прямая проба TCP/10250 (kubelet HTTPS) с worker station,
  сохранённая в `/var/work/tests/bootstrap-baseline-3.txt`. Это независимо от
  student-owned `artifacts/3/preflight.txt`, которую студент технически мог бы
  сфабриковать или записать после hardening - checker сверяет post-hardening результат
  с ЭТИМ файлом, а не только со student-artifact.
- **Exact allow-set** через `sudo ufw show added` (декларативный список реально
  выполненных `ufw allow`/`ufw limit` команд в исходной форме, а не через regex по
  iptables-производному `ufw status`, который допускает множество синтаксических форм
  того же results - short form, app profile, interface-scoped, IPv6). Тест требует
  ровно 5 строк: loopback + 4 source-scoped правила (`worker_ip`→`22/tcp`,
  `worker_ip`→`6443/tcp`, `node_ip`→`6443/tcp`, `pod_cidr`→`6443/tcp`) - любая лишняя
  строка любой формы (в т.ч. короткая `ufw allow 8080/tcp` без `from`) увеличивает
  счётчик и проваливает тест.
- **Post-enable retest**: сразу после `ufw --force enable` проверяются `calico-node`
  Ready, Node Ready, `/readyz`, Pod DNS (`getent hosts kubernetes.default.svc...`), Pod →
  Kubernetes Service, и негативный worker → kubelet:10250 (транспортный deny).
- **Post-reload retest**: тест сам выполняет `sudo ufw reload` и повторяет ВСЕ те же
  проверки (readyz/node/calico-node/DNS/Pod→API/worker→kubelet:10250 deny) - правило,
  работающее только в памяти сразу после `enable`, но не переживающее `reload`, не
  считается корректным решением и явно проваливает тест с отдельным hint.

Любой сбой в этой цепочке проверок явно фиксируется как infrastructure/control error (с
конкретным hint, указывающим, какой шаг цепочки не прошёл), а не маскируется как случайный
transient failure.

## Как это соотносится с существующими лабами

Пункты выше не требуют переписывания existing labs с нуля. Большинство лаб 101-112 уже
покрывают часть стандарта (например, лаба 106 уже строит AppArmor/seccomp через
positive+negative control). Цель документа - дать ревьюеру единый список вопросов при
доработке или создании новой лабы, а не разово исполненный чеклист.

См. также [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml) для покрытия
компетенций theory/lab/mock и [`metadata/offensive-map.yaml`](../metadata/offensive-map.yaml)
для карты ATT&CK-техник, уже связанных с главами курса.
