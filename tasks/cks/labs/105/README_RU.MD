# Лаба 105 - System Hardening ОС и безопасность Docker daemon

## Цель

В этой CKS-лабе вы уменьшите поверхность атаки двух Linux-хостов. На Kubernetes
control-plane нужно отключить лишние сервисы, закрыть открытый порт, настроить firewall,
защитить kubeconfig и запретить прямой root login по SSH. На отдельном `docker-host`
нужно устранить три опасные настройки Docker daemon: TCP API без TLS, доступ к
`docker.sock` через группу `docker` и доступ пользователя `developer` к этому сокету.

Это учебное окружение намеренно создано небезопасным. Не переносите исходные настройки
в production: Docker API на TCP/2375 без TLS даёт удалённый root-доступ любому, кто может
подключиться к порту.

## Проверьте себя перед стартом

<details>
<summary>1. Чем `systemctl disable` отличается от `systemctl stop`, и почему для задания 1 нужны оба?</summary>

`stop` останавливает уже запущенный процесс прямо сейчас, но не влияет на автозапуск при следующей загрузке системы. `disable` убирает сервис из автозапуска (unit-файл больше не привязан к target), но не останавливает уже работающий процесс. Для полного закрытия поверхности атаки нужно и то, и другое - иначе сервис либо продолжит работать сейчас, либо снова запустится после reboot.
</details>

<details>
<summary>2. Почему TCP Docker API без TLS (`-H tcp://0.0.0.0:2375`) эквивалентен удалённому root-доступу?</summary>

Docker daemon работает с правами root, а его API не имеет built-in authentication без TLS client certificates. Любой, кто может подключиться к этому порту сетевым способом, может запустить произвольный container с `--privileged` и смонтированной host filesystem - и получить полный контроль над хостом, минуя SSH и любые другие механизмы контроля доступа.
</details>

<details>
<summary>3. Почему `chmod 600` для kubeconfig важен, даже если файл и так доступен только root через файловую систему?</summary>

`/etc/kubernetes/admin.conf` содержит client certificate с правами `cluster-admin` - если режим файла слишком широк (например, `644`, читаем всеми), ЛЮБОЙ пользователь на этой ноде, даже без sudo, может прочитать credential и получить полный административный доступ к кластеру удалённо, без необходимости эскалации привилегий на самой ноде.
</details>

<details>
<summary>4. Почему core dump процесса может утечь секрет, даже если сам секрет никогда не записывался на диск?</summary>

Core dump — это образ памяти процесса на момент crash, который **может** включать расшифрованные значения переменных, приватные ключи и токены, удерживаемые в открытом виде. Это не гарантированно вся память процесса: набор отображений зависит от `/proc/<pid>/coredump_filter`, а отдельные области могут быть исключены, например через `MADV_DONTDUMP`. Поэтому даже если приложение никогда явно не пишет секрет в файл, crash dump может сохранить присутствовавшие в включённых отображениях секреты на диск в доступном для чтения файле.
</details>

## Связь с курсом

- [Глава 14. Минимизация footprint хостовой ОС и безопасность runtime-демона](../../course/14/ru.md)
- [Глава 15. Least-privilege на хосте и минимизация внешнего доступа](../../course/15/ru.md)
- [CKA: systemd, сервисы и Linux](../../../cka/course/00-5-linux/ru.md)
- [CKA: контейнеры и runtime](../../../cka/course/00-4-containers/ru.md)

## Инфраструктура

Окружение разворачивается через Terragrunt в AWS `eu-central-1`:

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.10.0.0/16` с двумя публичными подсетями |
| `ssh-keys` | SSH-ключ для внутренних соединений |
| `k8s-1` | одноузловой kubeadm-кластер Kubernetes `1.36.0`, containerd, Calico; это целевой control-plane |
| `docker-host` | отдельный Ubuntu 22.04 с Docker и намеренно небезопасной конфигурацией |
| `worker` | рабочая машина с `kubectl`, SSH-конфигурацией и `check_result` |

`worker` имеет SSH-доступ к control-plane по его Kubernetes node name и к отдельному
хосту по имени `docker-host`. Docker не является runtime Kubernetes-кластера: его
конфигурация из задания 6 изолирована на `docker-host`.

## Развёртывание

```bash
TASK=105 make run_cks_task
```

Подключитесь к `worker`, затем получите имя control-plane:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CTX=cluster1-admin@cluster1
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
  --context "$CTX" -o jsonpath='{.items[0].metadata.name}')
ssh "$CP"
ssh docker-host
```

Полезные команды:

```bash
time_left
check_result
```

Артефакты проверки сохраняйте в `/var/work/tests/artifacts/<номер>/`. Создавать
манифесты Kubernetes для этой лабы не требуется.

## Задания

---
| **1** | **Отключить лишний сервис** |
| :---: | :--- |
| Что делаем | На control-plane отключите и остановите `cks-lab105-unused.service`. Сервис не нужен для работы Kubernetes и не должен стартовать после reboot. |
| Критерии приёмки | `systemctl is-enabled cks-lab105-unused.service` возвращает `disabled`, `systemctl is-active` - `inactive`; в `/var/work/tests/artifacts/1/service.txt` находится строка `disabled inactive`. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

Порядок команд: `sudo systemctl stop cks-lab105-unused.service && sudo systemctl disable cks-lab105-unused.service` - оба шага нужны, ни один не заменяет другой (см. вопрос 1 в разделе самопроверки выше). Артефакт должен содержать именно строку "disabled inactive" (в этом порядке, через пробел) - проверьте формат перед сохранением.
</details>

---
| **2** | **Закрыть ненужный открытый порт** |
| :---: | :--- |
| Что делаем | На control-plane устраните listener TCP/8080, созданный `cks-lab105-port.service`. Отключите и остановите сервис (оба действия обязательны — см. вопрос 1 в разделе самопроверки); он не нужен ни control-plane, ни kubelet. |
| Критерии приёмки | `ss -ltn` не показывает TCP/8080; `systemctl is-enabled cks-lab105-port.service` возвращает `disabled`, `systemctl is-active` - `inactive`; `/var/work/tests/artifacts/2/service.txt` содержит строку `disabled inactive`; `/var/work/tests/artifacts/2/port-8080.txt` содержит `tcp/8080: closed`. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Сначала найдите, какой процесс держит порт (`sudo ss -ltnp | grep 8080`), чтобы убедиться, что это действительно `cks-lab105-port.service`, а не что-то другое. Закрывать порт через firewall (задание 3) недостаточно для этого задания - тест проверяет, что listener САМ отсутствует, не просто заблокирован снаружи.
</details>

---
| **3** | **Ограничить входящий трафик firewall** |
| :---: | :--- |
| Что делаем | До включения UFW зафиксируйте роль узла, worker source IP, node InternalIP и `spec.podCIDR`. **Обязательный baseline до firewall:** до включения UFW зафиксируйте baseline-пробу TCP/10250 (kubelet HTTPS endpoint) с worker - `curl` с реальным `CURL_EXIT`/`HTTPCODE`, доказывающим сетевую достижимость порта (любой `1xx-5xx`, включая `401`/`403`, считается достижимостью - kubelet API реально ответил). Без этого шага post-hardening "заблокировано" нельзя отличить от постороннего сбоя (security group, routing), который блокировал порт ещё до UFW - помимо вашей записи, checker независимо сверяет это со своим собственным bootstrap-baseline, зафиксированным ДО выдачи лабы в защищённом каталоге `/var/lib/cks-lab105-checker` (`0711 root:root`, отдельно от `/var/work/tests`, которая по умолчанию доступна для записи всем). Это одноузловой control-plane + workload node: нужны loopback, SSH recovery от worker, API `6443/tcp` от worker, самого узла и Pod CIDR; etcd/scheduler/controller-manager используют локальные flows, а межнодовых CNI/kubelet flows в этой топологии нет. Управляйте firewall **только через команду `ufw`** (`allow`/`deny`/`reject`/`limit`/`route`, затем `enable`/`reload`) - не редактируйте `/etc/ufw/before*.rules`, `after*.rules`, `user.rules` или `user6.rules` вручную: framework-файлы (`before`/`after`) сверяются по хэшу с bootstrap-baseline, а `user.rules`/`user6.rules` (куда `ufw` пишет ваши правила) проверяются через фактическое состояние ядра (`ufw show user-rules`), а не только через файл. Добавьте source-scoped allow rules **до** `ufw default deny incoming`; не используйте широкие `ALLOW Anywhere` и не добавляйте никаких иных правил сверх этих пяти (loopback + 4 source-scoped), включая `deny`/`reject`/`route`. Затем включите UFW, сохраните `ufw status` **и** `ufw show added` (нормализованное представление добавленных правил - не обязательно в исходном виде/порядке команд), preflight (включая baseline TCP/10250) и recovery-команды в `/var/work/tests/artifacts/3/`. **Обязательный retest после `ufw reload`:** выполните `sudo ufw reload` и повторите ВСЕ те же проверки (readyz, node Ready, `calico-node` Ready, Pod DNS, Pod→API, worker→kubelet:10250 deny, effective UFW rule count) - правило, работающее только в памяти сразу после `enable`, но не переживающее `reload`, не считается корректным решением. |
| Критерии приёмки | Checker-owned bootstrap-baseline (зафиксирован до выдачи лабы в `/var/lib/cks-lab105-checker`, каталог `0711 root:root` вне `/var/work/tests`, файл `0444 root:root`) подтверждает исходную достижимость TCP/10250; ваша собственная baseline-проба TCP/10250 до UFW сохранена и показывает реальную сетевую достижимость (`CURL_EXIT=0`, HTTP `1xx-5xx`) - если порт уже недоступен на baseline, результат задания - `inconclusive`, а не PASS; UFW active/default-deny; **точное множество** добавленных правил - `ufw show added` содержит РОВНО пять строк: loopback + `worker_ip`→`22/tcp` + `worker_ip`→`6443/tcp` + `node_ip`→`6443/tcp` + `pod_cidr`→`6443/tcp` - без единого лишнего правила ЛЮБОГО действия (`allow`/`deny`/`reject`/`limit`/`route`) и без отсутствующего из пяти; хэш `/etc/ufw/before*.rules`/`after*.rules` не отличается от checker-owned bootstrap-baseline (правила добавляются только через `ufw`, framework-файлы не редактируются вручную); **фактическое содержимое правил в ядре** (`sudo ufw show user-rules` на реальных `ufw-user-*` chains через `iptables -L`) семантически совпадает с ожидаемыми 5 правилами - не только их количество, но source/interface/protocol/port КАЖДОГО правила проверяются против реального `iptables`-вывода, и после `enable`, и после `reload`; `ufw6-user-input` остаётся РОВНО с одной строкой - v6-версией loopback ACCEPT (`ufw allow in on lo` создаёт и v4-, и v6-правило одновременно, так как это правило по интерфейсу без явного IP; не "полностью пусто") - это ловит и прямую правку `user.rules`/`user6.rules` без tuple metadata (не отражается ни в `ufw show added`, ни в хэше `before/after`), и расширение уже задекларированного правила (например, `node_ip`→`6443/tcp`, тайно заменённый на `node_ip`→`any`) без изменения количества строк; `/readyz=ok`; ожидаемая нода и все `calico-node` Pod остаются `Ready`; `health-probe` остаётся Ready, резолвит DNS и достигает Kubernetes Service; после UFW worker не достигает kubelet `10250` (`HTTPCODE=000`, транспортный deny) - именно как регресс относительно доказанного baseline; **все те же проверки повторно проходят после явного `sudo ufw reload`** (readyz/node/calico-node/DNS/Pod→API остаются здоровы, worker→kubelet:10250 остаётся заблокирован тем же контрактом deny, что и до reload, и фактическое количество правил в ядре снова совпадает с декларативным); артефакт содержит команды recovery (`ufw disable`, проверка, исправление и повторное включение). |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Самая опасная ошибка здесь - включить `ufw enable` (default-deny) ДО того, как вы добавили allow-правило для SSH с worker IP. Порядок должен быть: сначала все нужные `ufw allow from <IP> to any port <port>`, только потом `ufw --force enable`. Держите текущую SSH-сессию открытой на всё время работы с firewall - если вы потеряете доступ, вторая сессия для recovery не подключится (см. предупреждение ниже). Не забудьте baseline-пробу TCP/10250 ДО включения UFW - без неё post-hardening "заблокировано" ничего не доказывает: порт мог быть недостижим ещё раньше по совершенно другой причине (например, AWS security group), и тогда UFW тут вообще ни при чём; кроме того, у checker есть свой собственный baseline, зафиксированный ещё до выдачи лабы в отдельном защищённом каталоге, поэтому подделать эту запись задним числом не получится. Проверяйте allow-set строго через `sudo ufw show added` (не только `ufw status`) - там должно быть РОВНО пять строк, ни одной лишней (никаких широких `ALLOW Anywhere`, никаких дополнительных портов, и это касается ЛЮБОГО действия - `allow`, `deny`, `reject`, `limit`, `route`, не только новых allow) и ни одной недостающей. Управляйте firewall только через команду `ufw` - не редактируйте `/etc/ufw/before*.rules`/`after*.rules`/`user.rules`/`user6.rules` вручную: framework-файлы сверяются по хэшу, а фактическое состояние `user.rules`/`user6.rules` checker проверяет напрямую через реальные iptables-правила в `ufw-user-*` chains (`sudo ufw show user-rules`), поэтому даже правка `user.rules` без правильных `### tuple ###` комментариев будет обнаружена после `ufw reload`. И не забудьте выполнить `sudo ufw reload` в конце и повторить все проверки - правило, работающее только сразу после `enable`, но не переживающее `reload`, не засчитывается.
</details>

> **Recovery сначала.** Держите текущую SSH-сессию открытой до полной проверки. Если API
> пропал, из неё выполните `sudo ufw disable`, исправьте allow rules и только затем снова
> включите firewall. Если SSH уже потерян, используйте console/recovery channel провайдера;
> не пытайтесь «лечить» ситуацию широким `allow from any`.
>
> **Граница применимости.** Этот UFW allowlist рассчитан только на одноузловую fixture.
> Его нельзя буквально переносить в multi-node cluster: до default-deny нужно инвентаризовать
> kubelet и межнодовые потоки, CNI overlay, BGP/VXLAN/WireGuard, LoadBalancer/NodePort и
> provider firewall/security groups для конкретной топологии.
>
> **Lab-specific exception: UFW на Calico node.** Официальная документация Calico по
> требованиям прямо рекомендует отключать firewalld и другие iptables managers на
> Calico-нодах, потому что они могут конфликтовать с правилами, которые расставляет сам
> Calico. UFW - такой же iptables/nftables manager. Эта лаба намеренно сохраняет UFW на
> control-plane для практики host firewall hardening (отдельный навык в программе экзамена
> CKS), а не как рекомендуемый способ совместить Calico с host firewall в production - для
> этого Calico предлагает свой `HostEndpoint`/`GlobalNetworkPolicy`. Именно поэтому задание
> явно требует контролируемую последовательность baseline → `ufw enable` → retest с
> проверкой, что `calico-node` и вся связность Kubernetes остаются исправны (см.
> `ADVERSARIAL_ACCEPTANCE_STANDARD.md`).

---
| **4** | **Исправить права kubeconfig** |
| :---: | :--- |
| Что делаем | На control-plane защитите `/etc/kubernetes/admin.conf`, содержащий cluster-admin credential: владелец и группа должны быть `root:root`, режим - `600`. |
| Критерии приёмки | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` возвращает `root root 600`; то же значение сохранено в `/var/work/tests/artifacts/4/admin-conf.txt`. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Одна команда решает всё: `sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf`. Проверьте себя сразу после - если вы сами используете этот файл как `ubuntu` пользователь через `KUBECONFIG=/etc/kubernetes/admin.conf`, доступ на чтение исчезнет, и это ОЖИДАЕМО - используйте отдельный kubeconfig для повседневной работы.
</details>

---
| **5** | **Запретить root login по SSH** |
| :---: | :--- |
| Что делаем | На control-plane задайте `PermitRootLogin no` в `/etc/ssh/sshd_config`, проверьте синтаксис через `sshd -t` и безопасно перезагрузите SSH. Проверяйте эффективное значение именно для root-соединения командой `sshd -T -C "user=root,addr=<ваш IP>,laddr=<IP ноды>,lport=22"`, а не просто `sshd -T` без connection context. |
| Критерии приёмки | Эффективное значение `permitrootlogin` для root connection context равно `no`; `/var/work/tests/artifacts/5/sshd.txt` содержит `PermitRootLogin no`. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

`sshd -T` показывает ЭФФЕКТИВНУЮ конфигурацию, но БЕЗ connection context (`-C`) любые `Match`-блоки (`Match User`/`Match Address`/`Match Group` и подобные) не применяются вообще - man-страница `sshd(8)` явно говорит, что `Match`-правила применяются в test mode "only when the connection parameters are supplied via one or more `-C` options". Поэтому `sshd -T` без `-C` может показать `permitrootlogin no` из основного блока конфигурации, хотя более специфичный `Match`-блок (например, `Match Address <IP администратора>` или `Match User root`) разрешает root login именно для реального соединения. Проверяйте через `sshd -T -C "user=root,addr=<IP>,laddr=<IP ноды>,lport=22"` - это симулирует РЕАЛЬНОЕ входящее root-соединение и заставляет `sshd` применить все подходящие `Match`-блоки, прежде чем показать итоговое значение. ВСЕГДА держите текущую SSH-сессию открытой перед `systemctl reload sshd` и проверяйте с новой сессии - не с той, что уже была аутентифицирована до изменения.
</details>

---
| **6** | **Укрепить Docker daemon на `docker-host`** |
| :---: | :--- |
| Что делаем | На отдельном `docker-host` прекратите публикацию Docker API по TCP/2375: уберите `-H tcp://...` из учебного systemd override, но сохраните доступ только через unix-сокет. Настройте `/var/run/docker.sock` как `root:root` с режимом `660`; для устойчивости после restart задайте это через override `docker.socket`. Удалите `developer` из группы `docker`. После правок обязательно выполните `sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service` - это доказывает, что настройки переживают перезапуск демона, а не просто временно совпадают с ожидаемым состоянием. После restart подтвердите, что Docker реально работает (`sudo docker version`), а не просто остановлен. |
| Критерии приёмки | После `daemon-reload` + restart `docker.service` и `docker.socket` в состоянии `active`, а `sudo docker version`/`sudo docker info` завершаются успешно (positive control - Docker реально работает, не просто "выключен и поэтому 2375 закрыт"); на TCP/2375 нет listener; `stat -c '%U %G %a' /var/run/docker.sock` возвращает `root root 660`; persistent override `docker.service`/`docker.socket` (через `systemctl cat`) не содержит `-H tcp://` и задаёт `SocketGroup=root`/`SocketMode=0660`; `developer` не состоит в группе `docker`, а `sudo -u developer docker ps` завершается ошибкой доступа. Создайте `/var/work/tests/artifacts/6/docker-tcp.txt`, `/var/work/tests/artifacts/6/docker-socket.txt`, `/var/work/tests/artifacts/6/developer-access.txt` со строками `tcp/2375: closed`, `root root 660`, `developer docker ps: denied`. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

Членство в группе `docker` фактически эквивалентно root - любой процесс с доступом к `docker.sock` может смонтировать хостовую файловую систему через `--privileged` container. Убедиться, что `developer` удалён из группы, недостаточно проверить `groups developer` - изменения членства в группе применяются к НОВЫМ login-сессиям, проверяйте именно через `sudo -u developer docker ps` в свежей команде, не в уже открытой сессии `developer`. Не останавливайтесь на первом успешном запуске проверки - выполните `daemon-reload` и `restart` обоих unit-ов (`docker.socket`, `docker.service`) и повторите проверки СНОВА: без этого шага можно случайно пройти задание, просто временно остановив Docker (тогда 2375 закрыт не потому что убран `-H tcp://`, а потому что демон вообще не работает) - убедитесь также, что `sudo docker version` работает после restart, это доказывает, что Docker реально функционирует, а не просто "выключен".
</details>

---
| **7** | **Запретить загрузку неиспользуемого модуля ядра (`modprobe` blacklist)** |
| :---: | :--- |
| Что делаем | На control-plane модуль `sctp` загружен, но не требуется ни kubeadm, ни containerd, ни Calico в этой лабе. Попробуйте выгрузить его (`sudo modprobe -r sctp`) и запретите повторную загрузку через `/etc/modprobe.d/60-cks-sctp.conf` с директивами `blacklist sctp` и `install sctp /bin/true`. **Выгрузка может не сработать на уже живом кластере, и это не ошибка** - протокольные модули ядра получают persistent per-network-namespace ссылку для каждого netns, существовавшего на момент их загрузки, а на этой ноде уже работают Pod'ы (calico, coredns и т.д.); остановить их не входит в задание. Обе директивы действуют на уровне `modprobe` (alias resolution и dependency loading) - это не абсолютная защита ядра: `insmod` вставляет модуль напрямую через kernel syscall и не читает `modprobe.d`, а `modprobe --ignore-install` может обойти `install` override при должном host-level доступе. Для root-владельца ноды это ожидаемое ограничение модели угроз этой лабы: цель - устранить обычный, ожидаемый путь загрузки (`modprobe sctp`, автозагрузка по alias при обращении к protocol), а не защититься от пользователя, у которого уже есть root на ноде. Подтвердите, что `modprobe --show-config` показывает эффективный override и что прямой `modprobe sctp` не меняет состояние модуля. |
| Критерии приёмки | `/etc/modprobe.d/60-cks-sctp.conf` содержит обе строки `blacklist sctp` и `install sctp /bin/true`; `modprobe --show-config \| grep sctp` показывает `install sctp /bin/true`; прямой повторный `modprobe sctp` не меняет состояние модуля (было загружен - осталось загружен, было не загружен - осталось не загружен); `/var/work/tests/artifacts/7/sctp.txt` содержит строку `lsmod: absent` ИЛИ `lsmod: present` (любое из двух - реальное текущее состояние) и строку `install sctp /bin/true`. |

<details>
<summary>💡 Подсказка к заданию 7</summary>

`blacklist sctp` одна не блокирует всё - она мешает АВТОЗАГРУЗКЕ по alias resolution, но прямой `modprobe sctp` всё равно сработает без `install`-override. Нужны обе строки: `blacklist` для автозагрузки, `install sctp /bin/true` для явного вызова `modprobe sctp` (подменяет команду загрузки на no-op). Попробуйте `sudo modprobe -r sctp`, чтобы выгрузить уже загруженный модуль, но если получите `FATAL: Module sctp is in use` с пустым `/sys/module/sctp/holders` - это ожидаемо на живом кластере (per-netns pinning от уже запущенных Pod'ов) и не блокирует прохождение задания; конфиг всё равно предотвращает БУДУЩИЕ загрузки, что и проверяется.
</details>

---
| **8** | **`protectKernelDefaults` и безопасные sysctl для kubelet** |
| :---: | :--- |
| Что делаем | На control-plane сейчас `kernel.unprivileged_bpf_disabled = 0` — непривилегированные процессы могут загружать eBPF программы, что расширяет kernel attack surface. Исправьте это и добавьте `vm.overcommit_memory = 1` (типовая рекомендация для стабильности kubelet/containerd под memory pressure) через `/etc/sysctl.d/99-kubernetes.conf`, затем примените `sudo sysctl --system`. Включите `protectKernelDefaults: true` в `/var/lib/kubelet/config.yaml` и перезапустите kubelet: при `true` kubelet проверяет соответствие текущих kernel/cgroup parameters ожидаемым defaults при старте и **не запускается**, если они не совпадают — поэтому sysctl обязаны быть применены **до** перезапуска kubelet, а не после. |
| Критерии приёмки | `sysctl kernel.unprivileged_bpf_disabled` возвращает `1`; `sysctl vm.overcommit_memory` возвращает `1`; `/etc/sysctl.d/99-kubernetes.conf` содержит оба параметра; `/var/lib/kubelet/config.yaml` содержит `protectKernelDefaults: true`; `systemctl is-active kubelet` возвращает `active`, а нода остаётся `Ready` после перезапуска. |

<details>
<summary>💡 Подсказка к заданию 8</summary>

Порядок здесь критичен и намеренно подчёркнут в описании задания: сначала `sysctl --system` (применить значения), ТОЛЬКО ПОТОМ включать `protectKernelDefaults: true` и перезапускать kubelet. Если сделать в обратном порядке, kubelet при старте обнаружит несоответствие kernel parameters своим ожиданиям и откажется запускаться - нода останется NotReady, и вы не сможете понять причину без чтения kubelet логов (`journalctl -u kubelet`). Проверка ориентируется на РЕАЛЬНО ДЕЙСТВУЮЩУЮ конфигурацию kubelet через `kubectl get --raw="/api/v1/nodes/<node>/proxy/configz"`, а не на текст `config.yaml` - если строка в файле закомментирована или содержит опечатку, `grep` мог бы её всё равно найти, хотя kubelet продолжает работать со старым значением по умолчанию. После правки файла обязательно перезапустите kubelet и проверьте именно через `configz`.
</details>

---
| **9** | **Найти и обезвредить лишний SUID-бинарник** |
| :---: | :--- |
| Что делаем | На control-plane выполните `find / -xdev -perm -4000 -type f 2>/dev/null` и найдите среди результатов `/usr/local/bin/cks-lab105-suid-tool` — учебный бинарник, специально созданный с SUID-битом и не требующийся ни для одного компонента Kubernetes на этой ноде. Снимите с него SUID-бит (`chmod u-s`). Не трогайте системные SUID-бинарники (`passwd`, `sudo`, `mount` и подобные): их удаление ломает штатную работу ОС и не входит в рамки задания. Сохраните полный список найденных SUID-файлов **до** исправления в `/var/work/tests/artifacts/9/suid-before.txt` и режим `cks-lab105-suid-tool` **после** исправления в `/var/work/tests/artifacts/9/suid-after.txt`. |
| Критерии приёмки | `suid-before.txt` содержит путь `/usr/local/bin/cks-lab105-suid-tool` среди найденных SUID-файлов; `stat -c '%a' /usr/local/bin/cks-lab105-suid-tool` возвращает `755` (без SUID-бита `4`); `suid-after.txt` содержит `755`; штатные системные SUID-бинарники (например, `/usr/bin/sudo` или `/usr/bin/passwd`) остаются с SUID-битом нетронутыми. |

<details>
<summary>💡 Подсказка к заданию 9</summary>

`chmod u-s` убирает именно SUID-бит, не трогая остальные права (в отличие от `chmod 755`, который также перезапишет все остальные биты прав - в данном случае результат совпадает, но `u-s` безопаснее как общая привычка). Не запускайте `find / -perm -4000` без `-xdev` без крайней необходимости - без него команда будет сканировать смонтированные сетевые/виртуальные файловые системы и может выполняться очень долго или зависнуть. Проверка сравнивает текущий набор системных SUID-бинарников с baseline, зафиксированным ДО начала лабы - трогать любой другой системный SUID-бинарник (не только `sudo`/`passwd`) запрещено, и просто вернуть SUID на `sudo` не поможет, если вы случайно (или намеренно) сняли его с чего-то ещё. Пути внутри `/var/lib/containerd` (слои container image через overlayfs) не учитываются ни в baseline, ни в проверке - это не файлы хоста, и их набор естественно меняется при pull/extract образов независимо от вас.
</details>

---
| **10** | **Отключить core dumps и защитить SUID-процессы от снятия дампа памяти** |
| :---: | :--- |
| Что делаем | Core dump процесса может содержать расшифрованные секреты, приватные ключи и токены, находившиеся в памяти на момент crash. На control-plane ограничьте размер core dump через `/etc/security/limits.conf` (добавьте строки `* hard core 0` и `* soft core 0`) и запретите dump для SUID/privileged-процессов через `sysctl fs.suid_dumpable = 0` в `/etc/sysctl.d/99-kubernetes.conf` (тот же файл, что в задании 8 — не создавайте отдельный конфликтующий файл). **На Ubuntu этого недостаточно**: crash dump по умолчанию передаётся не напрямую в файл, а через `kernel.core_pattern`, который на Ubuntu указывает на userspace pipe handler (Apport) — Apport перехватывает crash в `/var/lib/apport/coredump/` независимо от `ulimit -c`, потому что `RLIMIT_CORE` игнорируется ядром именно для pipe-обработчиков (см. `man 5 core`: "RLIMIT_CORE will be ignored if the system is configured to pipe core dumps to a program"). Поэтому дополнительно задайте `kernel.core_pattern = |/bin/false` в том же `/etc/sysctl.d/99-kubernetes.conf` — это заменяет pipe-handler на заведомо неработающий, и ядро не создаёт dump ни в файл, ни через Apport. Примените `sudo sysctl --system`. Подтвердите все четыре свойства: `sysctl fs.suid_dumpable` возвращает `0`, `cat /proc/sys/kernel/core_pattern` возвращает `\|/bin/false`, новый login-shell (`bash -l` или `sudo su - ubuntu -c 'ulimit -c'` - именно с `sudo`, обычный `su` на самого себя всё равно требует пароль) показывает `ulimit -c` равным `0`, и после реального crash тестового процесса (`SIGSEGV`) не появляется новый core dump ни в `/var/lib/apport/coredump/`, ни где-либо ещё. |
| Критерии приёмки | `sysctl -n fs.suid_dumpable` возвращает `0`; `/etc/sysctl.d/99-kubernetes.conf` содержит `fs.suid_dumpable = 0` и `kernel.core_pattern = \|/bin/false`; `cat /proc/sys/kernel/core_pattern` возвращает `\|/bin/false`; `/etc/security/limits.conf` содержит обе строки `* hard core 0` и `* soft core 0`; новый login-shell показывает `ulimit -c` равным `0`; controlled crash тестового процесса не создаёт новый retained core dump; `/var/work/tests/artifacts/10/coredump.txt` содержит все подтверждения, включая результат controlled crash probe. |

<details>
<summary>💡 Подсказка к заданию 10</summary>

`ulimit -c` в ВАШЕЙ текущей SSH-сессии не изменится после редактирования `limits.conf` - PAM-лимиты применяются только при создании НОВОЙ сессии/login-shell. Проверяйте через `sudo su - ubuntu -c 'ulimit -c'` (новый login; `sudo` обязателен - `su` даже на самого себя всегда запрашивает пароль, если вызван не от root) или откройте новую SSH-сессию, а не проверяйте `ulimit -c` в той же shell, где вы редактировали файл. Оба значения нужны: `hard` - абсолютный потолок, `soft` - действующее значение по умолчанию; если задать только `soft`, процесс может сам поднять лимит до `hard`. Ключевая ловушка задания: `ulimit -c 0` и `fs.suid_dumpable=0` **не отключают** core dump на Ubuntu сами по себе - `man 5 core` прямо говорит, что `RLIMIT_CORE` игнорируется ядром, если `kernel.core_pattern` указывает на pipe-обработчик (`|program`), а Ubuntu по умолчанию направляет crash именно в такой обработчик (Apport), который перехватывает dump независимо от `ulimit`. Единственный надёжный способ - переопределить сам `kernel.core_pattern` (например, на `|/bin/false`), а не только лимиты процесса.
</details>

## Дополнительно: kernel и containerd/CRI hardening

Это короткая node-local практика сверх заданий 7–9, не входящая в автоматические критерии
fixture. Она показывает более широкий CRI-контекст, не ограниченный конкретным модулем ядра.

В этой лабе Kubernetes использует **containerd**, а не Docker. Поэтому те же принципы
надо применять к CRI: проверьте права `/run/containerd/containerd.sock` и
`/etc/containerd/config.toml`, не добавляйте обычных пользователей в группу, дающую доступ
к сокету, и разрешайте `ctr`/`crictl` с этим endpoint только привилегированным
администраторам. Не меняйте владельца или режим работающего CRI-сокета вслепую: ошибочная
настройка остановит kubelet и workload.

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# ожидается отказ доступа для непривилегированного пользователя
```

## Проверка

На `worker` выполните:

```bash
check_result
```

Проверка содержит `0 Init` и десять независимых тестов. Она проверяет состояние обоих
хостов по SSH и обязательные артефакты. После правки `sshd_config` или systemd unit
дождитесь завершения `systemctl reload/restart`, прежде чем запускать проверку повторно.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=105 make delete_cks_task
```
