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
  какого-либо изменения UFW): прямая проба TCP/10250 (kubelet HTTPS) с worker station и
  hash `/etc/ufw/before*.rules`/`after*.rules`, сохранённые в отдельном каталоге
  `/var/lib/cks-lab105-checker` (`0711 root:root`), а НЕ в `/var/work/tests` - shared
  bootstrap-шаблон (`terraform/modules/work_pc_v2/template/worker.sh`) делает
  `/var/work/tests` world-writable (`chmod -R 777`), поэтому root-owned `0444` файл
  ВНУТРИ этого каталога не был бы реальной защитой: world-writable parent directory
  позволяет удалить и пересоздать файл независимо от его собственных owner/mode (Unix
  delete/create permission определяется правами директории, не файла). `tests.bats`
  проверяет owner/mode ОБОИХ - самого каталога `/var/lib/cks-lab105-checker` (`0711`) и
  каждого baseline-файла внутри (`0444`) - как условие для признания baseline
  действительно checker-owned. Захват baseline **fail-fast**: если SSH до control-plane
  не удаётся или получено не ровно 4 валидных 64-символьных SHA-256 хэша для
  `before.rules`/`before6.rules`/`after.rules`/`after6.rules`, bootstrap завершается
  `FATAL` и лаба не выдаётся студенту с неполным reference baseline.
  **Архитектурное ограничение (осознанно принятое, не случайный недосмотр):** штатный
  `check_result` этой лабы (из shared `work_pc_v2`) выполняет `bats
  /var/work/tests/tests.bats` **без `sudo`**, от имени `ubuntu` - поэтому сама проверка в
  `tests.bats` обязана читать baseline тоже без `sudo`, иначе штатный PASS ломается для
  любого студента. Каталог `0711` (не `0700`) даёт `ubuntu` traversal+read по точному
  известному имени файла, без листинга каталога; файл `0444` даёт read-only. Но `ubuntu`
  также имеет passwordless `NOPASSWD` sudo на этом же хосте (стандартный Ubuntu cloud
  image default, не переопределён ни в одном bootstrap-скрипте этой лабы) - студент,
  осознанно использующий `sudo`, технически всегда может переписать baseline и восстановить
  `root:root`/`0444` перед запуском `check_result`. Полностью tamper-proof, чисто
  локальный, self-hosted checker baseline на этой архитектуре недостижим. `0711`/`0444` -
  это defense-in-depth против случайной/попутной модификации (например, случайный `chmod
  -R` при работе с другими заданиями), а не заявка на hardened adversarial trust boundary
  против намеренной sudo-эскалации.
- **Exact allow-set** через `sudo ufw show added` (нормализованное представление реально
  выполненных `ufw allow`/`ufw deny`/`ufw reject`/`ufw limit`/`ufw route` команд - НЕ
  гарантированно literal/original command text или порядок, так как UFW нормализует
  правила при отображении; корректная формулировка - "нормализованное представление
  добавленных UFW rules", не "исходные команды"). Тест требует ровно 5 строк: loopback +
  4 source-scoped правила (`worker_ip`→`22/tcp`, `worker_ip`→`6443/tcp`,
  `node_ip`→`6443/tcp`, `pod_cidr`→`6443/tcp`) - любая лишняя строка ЛЮБОГО действия (в
  т.ч. `deny`, `reject`, `route`, не только новый `allow`, в т.ч. короткая форма без
  `from`) увеличивает счётчик и проваливает тест. Дополнительно checker сверяет хэш
  `/etc/ufw/before*.rules`/`after*.rules` с checker-owned bootstrap-хэшем этих же файлов -
  `ufw show added` отражает только правила, добавленные через CLI `ufw`, и не видит
  прямое редактирование framework rule files, которое могло бы открыть обходной ingress
  path.
- **Effective UFW-owned user chains** через `sudo ufw show user-rules` (реальный
  `iptables -L` на `ufw-user-input` chain специфично). `ufw show
  added` - декларативный вид, реконструированный из `### tuple ###` метаданных, которые
  `ufw` сам пишет в `user.rules`/`user6.rules` при добавлении правила через CLI; но UFW
  загружает `user.rules` через `iptables-restore` при `enable`/`reload` независимо от
  наличия этих метаданных. Поэтому правило, добавленное прямой правкой `user.rules` без
  соответствующих tuple-комментариев, может стать частью **эффективного** firewall после
  `ufw reload`, оставаясь невидимым и для `ufw show added`, и для хэша `before`/`after`
  (правка касается только `user.rules`, отдельного файла). Checker требует, чтобы
  количество правил именно в `ufw-user-input` chain (реальное ядро) точно совпадало с
  количеством из `ufw show added` (декларативное) - и после `ufw enable`, и повторно
  после `ufw reload` (момент, когда именно и происходит фактическая загрузка
  `user.rules`). **Важно про парсинг вывода:** `ufw show user-rules` - НЕ плоский
  список; согласно исходнику `ufw` (`get_running_raw()`, `rules_type == 'user'`), вывод
  содержит section header `IPV4 (user):`, затем блоки `ufw-user-input`/`-forward`/
  `-output`, затем ВСТРОЕННЫЕ chains `ufw-user-limit-accept`/`ufw-user-limit` (существуют
  всегда, с собственными rule rows, даже без единого добавленного `limit`-правила), и
  при включённом IPv6 на хосте (типичный default) - ПОЛНУЮ вторую секцию `IPV6:` с
  `ufw6-user-*` эквивалентами. Простой подсчёт всех непустых/non-header строк во всём
  выводе даёт грубый overcount (в синтетической проверке - 13 вместо ожидаемых 5) и
  ложный FAIL для абсолютно корректного решения; checker извлекает строки СТРОГО внутри
  блока `ufw-user-input` (между этим `Chain` и следующим `Chain`), игнорируя остальные
  chains и обе section-секции. **Count сам по себе недостаточен:** студент может
  сохранить корректные `### tuple ###` metadata для всех 5 задекларированных правил (так
  что `ufw show added` продолжает показывать ровно ожидаемые 5 команд), но вручную
  расширить одну из соответствующих `-A ufw-user-input ...` строк в `/etc/ufw/user.rules`
  - например, заменить документированное `node_ip -> 6443/tcp` на более широкое
  `node_ip -> any` - без изменения количества строк вообще. Checker поэтому сверяет
  СЕМАНТИКУ каждой из 5 строк (source/interface/protocol/destination port) против
  реального `iptables -n -v -x -L ufw-user-input`, а не только их число: пять
  эффективных правил, которые не являются пятью ПРАВИЛЬНЫМИ правилами, не засчитываются
  как совпадение. Дополнительно checker требует, чтобы `ufw6-user-input` был полностью
  пуст: все 5 задокументированных правил используют IPv4-адреса, поэтому у корректного
  решения `ufw6-user-input` не содержит ни одной строки - любая строка там (например,
  bypass-правило, добавленное прямо в `user6.rules`, которое `ufw show added` и хэш
  IPv4-framework-файлов не видят) сама по себе провал, независимо от IPv4 count.
- **Post-enable retest**: сразу после `ufw --force enable` проверяются `calico-node`
  Ready, Node Ready, `/readyz`, Pod DNS (`getent hosts kubernetes.default.svc...`), Pod →
  Kubernetes Service, effective UFW user chains rule count, и негативный worker →
  kubelet:10250 (транспортный deny).
- **Post-reload retest**: тест сам выполняет `sudo ufw reload` и повторяет ВСЕ те же
  проверки (readyz/node/calico-node/DNS/Pod→API/worker→kubelet:10250 deny с тем же
  контрактом transport-failure+пустой/`000` HTTP code, что и до reload, ПЛЮС повторную
  проверку effective UFW user chains rule count) - правило, работающее только в памяти
  сразу после `enable`, но не переживающее `reload`, не считается корректным решением и
  явно проваливает тест с отдельным hint.

Любой сбой в этой цепочке проверок явно фиксируется как infrastructure/control error (с
конкретным hint, указывающим, какой шаг цепочки не прошёл), а не маскируется как случайный
transient failure.

Исключение: labs/106 использует ту же архитектурную модель checker-owned bootstrap
baseline, что и labs/105 (см. выше), для двух независимых пар "before/after" -
(1) задание 1/2: baseline подтверждает, что write, соответствующий паттерну `/work/**`
профиля `k8s-106-deny-write`, успешно проходил, пока профиль был ещё в `complain` (до
того как студент перевёл его в `enforce`); (2) задание 8: baseline подтверждает, что
seed-профиль `k8s-106-broken-profile` действительно содержал syntax error на момент
bootstrap, до какого-либо взаимодействия студента с файлом. Оба baseline captured
`k8s-1/scripts/master.sh` при provisioning и хранятся в `/var/lib/cks-lab106-checker`
(`root:root 0700` для каталога, `0400` для каждого baseline-файла), читаются `tests.bats`
только через `ssh ... sudo` (в отличие от labs/105, где локальный `check_result` этой
лабы всегда выполняется без `sudo` от имени `ubuntu` - здесь `tests.bats` architecturally
всегда использует `sudo` для любого control-plane-side чтения, поэтому `0700`/`0400`
не противоречит штатному PASS path ни для одного студента).

**Архитектурное ограничение - НЕ эквивалент labs/105, статус: нерешённый вопрос, не
принятое исключение.** В отличие от labs/105 (где локальный `check_result` архитектурно
обязан читать baseline БЕЗ `sudo`, и `0711`/`0444` - это максимум защиты, достижимый без
поломки штатного PASS), у labs/106 `tests.bats` уже всегда читает control-plane state
через `ssh ... sudo` для ЛЮБОЙ проверки - то есть здесь НЕТ того же архитектурного
принуждения к non-privileged чтению, которое оправдывало bы приравнивание к прецеденту
labs/105. Более сильная защита baseline технически возможна для labs/106 и просто не
реализована, а не недостижима.

Текущий факт: control-plane этой лабы - единственная нода, на которой студент выполняет
все команды через `sudo`, и у студента на этой же ноде есть passwordless `NOPASSWD`
sudo (стандартный Ubuntu cloud image default, не переопределён ни одним
bootstrap-скриптом этой лабы) - причём то же самое верно и для рабочей станции
`worker`, откуда запускается `check_result` (тот же `work_pc_v2` bootstrap template,
тот же cloud image default для пользователя `ubuntu`). Поэтому в текущей
двухузловой архитектуре этой лабы (`worker` + `control-plane`, оба admin-accessible
студенту через один и тот же shared SSH-ключ) student session имеет root-equivalent
доступ на ОБЕИХ машинах - "off-host storage, к которому у student session нет
write/admin доступа", предложенное как решение, требует введения ТРЕТЬЕГО компонента
(внешний validation service либо storage вне обеих existing нод), которого сейчас не
существует в инфраструктуре этой лабы. Студент, осознанно использующий свой sudo,
технически всегда может прочитать, изменить и восстановить owner/mode обоих
baseline-файлов до запуска `check_result` - `root:root 0700/0400` защищает только от
случайной/попутной модификации (например, случайный `chmod -R` при работе с другими
заданиями), НЕ от намеренной sudo-эскалации того же студента, для которого сам baseline
должен служить независимым (adversarial) доказательством.

**Это признаётся здесь как невыполненное требование `no fake success`, а не как принятое
архитектурное исключение.** Написание объяснения в этом документе или в комментариях
`master.sh`/`tests.bats` само по себе не эквивалентно осознанному принятию этого
trade-off владельцем курса - предыдущая версия этой записи ошибочно формулировала
ограничение как "осознанно принятое", что было односторонней характеристикой автора
правок, а не подтверждённым внешним решением. До тех пор, пока (a) pre-change evidence
для task 1/task 8 не будет вынесено за пределы student-controlled privilege domain
(например, отдельный validation service или off-host storage, недостижимый ни через
`worker`, ни через `control-plane` sudo), либо (b) владелец курса explicitly не примет
текущую sudo-mutable схему как осознанный trade-off именно для labs/106 (не по аналогии
с labs/105, а отдельным решением, поскольку архитектурная необходимость здесь не та же),
- `master.sh`/`tests.bats`/`README_RU.MD` не должны характеризовать
`/var/lib/cks-lab106-checker` как adversarially independent evidence. Текущие комментарии
в коде ("checker-owned", "independently") корректно описывают только ORIGIN baseline
(создан bootstrap-ом до выдачи лабы, а не самим студентом) и defense-in-depth от
случайной модификации - не заявку на защиту от намеренной атаки того же студента, который
управляет baseline проверкой.

## Как это соотносится с существующими лабами

Пункты выше не требуют переписывания existing labs с нуля. Большинство лаб 101-112 уже
покрывают часть стандарта (например, лаба 106 уже строит AppArmor/seccomp через
positive+negative control). Цель документа - дать ревьюеру единый список вопросов при
доработке или создании новой лабы, а не разово исполненный чеклист.

См. также [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml) для покрытия
компетенций theory/lab/mock и [`metadata/offensive-map.yaml`](../metadata/offensive-map.yaml)
для карты ATT&CK-техник, уже связанных с главами курса.
