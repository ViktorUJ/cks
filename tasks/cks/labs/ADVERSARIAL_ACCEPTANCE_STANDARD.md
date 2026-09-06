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

## Как это соотносится с существующими лабами

Пункты выше не требуют переписывания existing labs с нуля. Большинство лаб 101-112 уже
покрывают часть стандарта (например, лаба 106 уже строит AppArmor/seccomp через
positive+negative control). Цель документа - дать ревьюеру единый список вопросов при
доработке или создании новой лабы, а не разово исполненный чеклист.

См. также [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml) для покрытия
компетенций theory/lab/mock и [`metadata/offensive-map.yaml`](../metadata/offensive-map.yaml)
для карты ATT&CK-техник, уже связанных с главами курса.
