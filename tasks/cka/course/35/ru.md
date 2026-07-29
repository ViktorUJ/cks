# Глава 35. Установка кластера с помощью kubeadm

> 🟦 **Глава для CKA** (домен Cluster Architecture, Installation & Configuration, 25%).
> Для CKAD не требуется, но полезна для понимания.
>
> **Что дальше.** Начинаем администраторскую часть. Мы много работали в готовом кластере;
> теперь соберём его сами с помощью **kubeadm** - официального инструмента установки. Это
> прямое задание CKA («установи кластер», «добавь ноду») и фундамент для обновлений (глава
> 36), бэкапа etcd (глава 37) и troubleshooting control plane (глава 45). Всё, что мы
> разбирали в главе 2 про компоненты, здесь оживает руками.

## 35.1. Что делает kubeadm (и чего не делает)

**kubeadm** - инструмент, который поднимает control plane и присоединяет ноды по «best
practices». Важно понимать границы его ответственности.

```mermaid
flowchart TB
    does["kubeadm делает"] --> d1["поднимает control plane<br>(static pods:<br>apiserver, etcd,<br>scheduler,<br>controller-manager)"]
    d1 --> d2["генерирует сертификаты<br>и kubeconfig"]
    d2 --> d3["настраивает<br>bootstrap-токены<br>для join нод"]
    d3 --> d4["ставит kube-proxy<br>и CoreDNS"]
    notdoes["kubeadm НЕ делает"] --> n1["не ставит<br>container runtime<br>(containerd — заранее)"]
    n1 --> n2["не ставит CNI<br>(Calico/Cilium — вручную)"]
    n2 --> n3["не настраивает ОС<br>(swap, модули, sysctl)"]
    d4 ~~~ notdoes
    style does fill:#0f9d58,color:#fff
    style notdoes fill:#db4437,color:#fff
    style d1 fill:#3cb371,color:#fff
    style d2 fill:#3cb371,color:#fff
    style d3 fill:#3cb371,color:#fff
    style d4 fill:#3cb371,color:#fff
    style n1 fill:#e57373,color:#000
    style n2 fill:#e57373,color:#000
    style n3 fill:#e57373,color:#000
```

Запомните три вещи, которые kubeadm **не** делает - их готовят отдельно: container runtime,
CNI и настройку ОС. Забыть про CNI - причина, по которой после `kubeadm init` ноды остаются
`NotReady` (глава 30).

## 35.2. Подготовка нод (до kubeadm)

Прежде чем звать kubeadm, каждую ноду готовят:

```mermaid
flowchart TB
    s1["1 · Отключить swap<br>(swapoff -a)"] --> s2["2 · Модули ядра + sysctl<br>(br_netfilter, ip_forward)"]
    s2 --> s3["3 · Установить<br>container runtime<br>(containerd)"]
    s3 --> s4["4 · Установить kubeadm,<br>kubelet, kubectl"]
    style s1 fill:#f4b400,color:#000
    style s2 fill:#326ce5,color:#fff
    style s3 fill:#0f9d58,color:#fff
    style s4 fill:#673ab7,color:#fff
```

```bash
# 1. Отключить swap (Kubernetes требует)
sudo swapoff -a
# и убрать из /etc/fstab, чтобы не вернулся после перезагрузки

# 2. Модули и параметры сети
sudo modprobe br_netfilter
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system

# 3. container runtime — containerd (установка через пакеты)
# 4. репозиторий Kubernetes и пакеты
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl    # зафиксировать версии
```

> **Про swap.** Kubernetes исторически требует отключённого swap (kubelet по умолчанию не
> стартует при включённом swap). Это первый пункт подготовки и частая причина, почему
> `kubeadm init` падает.

Полный и актуальный список требований и шагов подготовки ноды - в официальной документации:
[Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
(swap, модули ядра и sysctl, container runtime, репозиторий и пакеты kubeadm/kubelet/kubectl).

## 35.3. Инициализация control plane: kubeadm init

На будущей control plane ноде:

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \        # диапазон подов (согласовать с CNI!)
  --control-plane-endpoint=<адрес>          # стабильный адрес API (для HA)
```

> **Какой адрес в `--control-plane-endpoint`?** Это **стабильная точка входа к
> API-серверу**, общая для всех нод и попадающая в сертификаты. Указывать сюда IP
> конкретной ноды - плохая идея: если это единственный control plane, вы уже не сможете
> без пересоздания перейти на несколько control plane. Правильно указывать:
>
> - **DNS-имя** (например, `k8s-api.example.com`), которое вы контролируете, - самый
>   гибкий вариант: позже за ним можно поставить балансировщик, не трогая кластер;
> - **адрес балансировщика** (VIP/LB) перед control plane нодами - для настоящего HA
>   (несколько API-серверов за одним адресом).
>
> Можно добавить порт: `--control-plane-endpoint=k8s-api.example.com:6443`. Флаг
> **необязателен** для одноузлового control plane, но задать его (через DNS) сразу -
> хорошая практика: это оставляет путь к HA открытым. Без флага endpoint'ом становится
> адрес текущей ноды, и «вырасти» в HA потом не получится. Подробности -
> [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
> и [HA topology](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/).

```mermaid
sequenceDiagram
    participant A as Админ
    participant K as kubeadm init
    participant CP as Control plane
    A->>K: kubeadm init --pod-network-cidr=...
    K->>K: preflight-проверки (swap, порты, runtime)
    K->>CP: генерирует сертификаты
    K->>CP: поднимает static pods (etcd, apiserver, ...)
    K->>CP: ставит kube-proxy, CoreDNS
    K-->>A: kubeconfig + команда kubeadm join
```

После успешного init kubeadm печатает две важные вещи:

1. команды настроить `kubectl` (скопировать admin.conf):
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
2. команду `kubeadm join ...` с токеном - её выполняют на worker-нодах.

### Сертификаты кластера: сроки, продление, свой CA

`kubeadm init` сам генерирует всю PKI кластера в `/etc/kubernetes/pki`. Важно понимать
сроки жизни, иначе **на проде можно словить простой**: когда сертификаты apiserver и
компонентов истекают, control plane перестаёт работать, а `kubectl` начинает отвечать
ошибками TLS.

Сроки по умолчанию:

- **листовые сертификаты** (apiserver, apiserver-kubelet-client, клиентские в
  `admin.conf`/`controller-manager.conf`/`scheduler.conf` и т.д.) - **1 год**;
- **сертификаты CA** (`ca`, `etcd-ca`, `front-proxy-ca`) - **10 лет**;
- клиентский сертификат kubelet (`/var/lib/kubelet/pki`) **ротируется автоматически** -
  его в списке ниже нет.

Проверить сроки:

```bash
kubeadm certs check-expiration     # таблица EXPIRES / RESIDUAL TIME по всем сертификатам
```

Продление:

- **автоматически при апгрейде** control plane: `kubeadm upgrade apply/node` продлевает
  все сертификаты. Если обновлять кластер регулярно (чаще раза в год), об истечении можно
  не думать;
- **вручную** в любой момент: `kubeadm certs renew all` (выполнять на **каждой** control
  plane ноде, затем перезапустить static-поды control plane - например, временно убрать и
  вернуть их манифесты в `/etc/kubernetes/manifests/`). После продления `admin.conf`
  не забудьте обновить `~/.kube/config`.

Свои и внешние сертификаты (чтобы задать сроки и свой CA заранее):

- **свой CA**: положите `ca.crt` и `ca.key` в `/etc/kubernetes/pki` **до** `kubeadm init` -
  kubeadm не перезапишет их и подпишет остальное вашим CA;
- **кастомные сроки** через конфиг kubeadm (передать `kubeadm init --config`):

  ```yaml
  apiVersion: kubeadm.k8s.io/v1beta4
  kind: ClusterConfiguration
  certificateValidityPeriod: 8760h      # листовые: по умолчанию 1 год
  caCertificateValidityPeriod: 87600h   # CA: по умолчанию 10 лет
  ```

  (значения - в формате Go-длительностей, самая крупная единица - `h`);
- **внешний CA** (external CA mode): положите только `ca.crt` без `ca.key` - kubeadm
  распознает это и не будет держать ключ CA на диске, а выпуск/продление сертификатов вы
  берёте на себя (свой signer). При этом `kubeadm certs renew` такими сертификатами уже
  **не управляет**.

Подробности и сценарии - в документации:
[Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/).

> **Вывод для прода.** Либо регулярно апгрейдите кластер (сертификаты продлеваются сами),
> либо мониторьте `check-expiration` и продлевайте заранее. «Кластер всё сломался ровно
> через год после установки» - классика истёкших сертификатов kubeadm.

## 35.4. Установка CNI (обязательный шаг)

Сразу после init ноды `NotReady` - нет сети подов. Ставим CNI (глава 30):

```bash
# пример: Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/<версия>/manifests/calico.yaml
```

```mermaid
flowchart LR
    init["kubeadm init"] --> notready["ноды NotReady<br>(нет сети подов)"]
    notready --> cni["установить CNI"]
    cni --> ready["ноды Ready<br>CoreDNS запускается"]
    style init fill:#326ce5,color:#fff
    style notready fill:#db4437,color:#fff
    style cni fill:#f4b400,color:#000
    style ready fill:#0f9d58,color:#fff
```

Только после установки CNI ноды становятся `Ready`, а системные поды (CoreDNS)
запускаются. `--pod-network-cidr` в init должен совпадать с тем, что ожидает CNI - иначе
сеть не заработает.

## 35.5. Присоединение worker-нод: kubeadm join

На каждой worker-ноде (подготовленной по шагу 35.2) выполняют `kubeadm join`, который
вывел init:

```bash
sudo kubeadm join <control-plane>:6443 \
  --token <токен> \
  --discovery-token-ca-cert-hash sha256:<хеш>
```

```mermaid
flowchart TB
    cp["Control plane<br>(kubeadm init выполнен)"]
    w1["Worker 1: kubeadm join"] --> cp
    w2["Worker 2: kubeadm join"] --> cp
    cp -->|"kubectl get nodes"| list["все ноды Ready"]
    style cp fill:#326ce5,color:#fff
    style w1 fill:#0f9d58,color:#fff
    style w2 fill:#0f9d58,color:#fff
    style list fill:#f4b400,color:#000
```

Если токен потерян или истёк (живёт 24 часа), новый создают на control plane:

```bash
kubeadm token create --print-join-command    # выведет готовую команду join
```

Проверка результата:

```bash
kubectl get nodes                             # все ноды должны быть Ready
kubectl get pods -n kube-system               # компоненты и CoreDNS Running
```

## 35.6. Что где лежит после установки

kubeadm раскладывает файлы предсказуемо - это надо знать для troubleshooting (главы 37,
45):

| Путь | Что там |
|------|---------|
| `/etc/kubernetes/manifests/` | static pods control plane (apiserver, etcd, scheduler, cm) |
| `/etc/kubernetes/*.conf` | kubeconfig'и (admin, kubelet, controller-manager, scheduler) |
| `/etc/kubernetes/pki/` | сертификаты и ключи (в т.ч. CA, etcd) |
| `/var/lib/etcd/` | данные etcd |
| `/var/lib/kubelet/` | конфиг и данные kubelet |

```mermaid
flowchart TB
    root["/etc/kubernetes/"]
    root --> m["manifests/ →<br>static pods<br>control plane"]
    root --> c["*.conf →<br>kubeconfig'и"]
    root --> pki["pki/ →<br>сертификаты"]
    etcd["/var/lib/etcd/ →<br>данные etcd"]
    kubelet["/var/lib/kubelet/ →<br>kubelet"]
    pki ~~~ etcd ~~~ kubelet
    style root fill:#326ce5,color:#fff
    style m fill:#0f9d58,color:#fff
    style c fill:#0f9d58,color:#fff
    style pki fill:#0f9d58,color:#fff
    style etcd fill:#f4b400,color:#000
    style kubelet fill:#f4b400,color:#000
```

## 35.7. Какие сертификаты создаёт kubeadm init

При `kubeadm init` автоматически генерируется вся **PKI кластера** в
`/etc/kubernetes/pki/`. Это то, на чём стоит всё доверие (глава 0.3, 39). Полезно знать,
что именно создаётся.

```mermaid
flowchart TB
    ca["ca (CA кластера)<br>корень доверия"]
    ca --> apis["apiserver<br>(серверный<br>сертификат API)"]
    ca --> akc["apiserver-<br>kubelet-client<br>(apiserver →<br>kubelet)"]
    fca["front-proxy-ca"] --> fpc["front-proxy-client<br>(aggregation layer)"]
    eca["etcd/ca<br>(отдельный CA etcd)"] --> es["etcd/server,<br>etcd/peer"]
    eca --> ehc["etcd/healthcheck-client"]
    eca --> aec["apiserver-<br>etcd-client<br>(apiserver → etcd)"]
    sa["sa.key / sa.pub<br>(подпись токенов<br>ServiceAccount)"]
    ca ~~~ fca ~~~ eca ~~~ sa
    style ca fill:#f4b400,color:#000
    style fca fill:#f4b400,color:#000
    style eca fill:#f4b400,color:#000
    style apis fill:#326ce5,color:#fff
    style akc fill:#326ce5,color:#fff
    style fpc fill:#326ce5,color:#fff
    style es fill:#0f9d58,color:#fff
    style ehc fill:#0f9d58,color:#fff
    style aec fill:#0f9d58,color:#fff
    style sa fill:#673ab7,color:#fff
```

Ключевые файлы в `/etc/kubernetes/pki/`:

| Файл | Что это |
|------|---------|
| `ca.crt` / `ca.key` | **CA кластера** - подписывает apiserver и клиентские сертификаты |
| `apiserver.crt/.key` | серверный сертификат kube-apiserver (SAN: ClusterIP, имена, endpoint) |
| `apiserver-kubelet-client.*` | клиентский сертификат apiserver для обращения к kubelet |
| `front-proxy-ca.*` / `front-proxy-client.*` | CA и клиент для aggregation layer (расширения API) |
| `etcd/ca.*` | **отдельный CA для etcd** |
| `etcd/server.*`, `etcd/peer.*` | серверный и peer-сертификаты etcd |
| `etcd/healthcheck-client.*`, `apiserver-etcd-client.*` | клиенты к etcd (проверки, apiserver) |
| `sa.key` / `sa.pub` | пара ключей для **подписи токенов ServiceAccount** (не сертификат) |

Плюс kubeadm создаёт **kubeconfig'и**, подписанные CA (в `/etc/kubernetes/`):
`admin.conf`, `super-admin.conf`, `kubelet.conf`, `controller-manager.conf`,
`scheduler.conf`.

### Сроки действия

| Что | Срок по умолчанию |
|-----|-------------------|
| **CA** (кластера, etcd, front-proxy) | **10 лет** |
| Листовые сертификаты (apiserver, kubelet-client, etcd/* и т.д.) | **1 год** |
| Клиентские сертификаты в kubeconfig (admin и др.) | 1 год |

То есть корневые CA живут долго (10 лет), а всё, что ими подписано, - **1 год** и требует
продления. Проверка и продление - `kubeadm certs check-expiration` / `kubeadm certs renew`
(глава 39); апгрейд кластера (глава 36) продлевает сертификаты control plane автоматически.

### Best practices

- **Обновляйте кластер хотя бы раз в год** - апгрейд продлевает листовые сертификаты
  control plane автоматически, и они не успевают истечь.
- **Мониторьте сроки** (`kubeadm certs check-expiration`) с алертом за N дней - истёкший
  сертификат control plane роняет кластер (`x509: certificate has expired`).
- **Бэкапьте `/etc/kubernetes/pki`** (особенно ключи CA) вместе с etcd - без CA кластер не
  восстановить.
- **Берегите `ca.key`**: владелец ключа CA может выпустить любое удостоверение, включая
  admin. Доступ строго ограничен.
- **kubelet-сертификаты - на автоматическую ротацию** (`rotateCertificates: true`,
  `serverTLSBootstrap`), чтобы не продлевать вручную.

## 35.8. Свой PKI: подсунуть собственный CA или внешний signer

kubeadm можно заставить использовать **ваш** CA вместо генерации собственного - для
единого корня доверия в организации. Способы:

```mermaid
flowchart TB
    q["Что кладём в<br>/etc/kubernetes/pki<br>ДО init?"]
    q -->|"ca.crt + ca.key"| own["Свой CA:<br>kubeadm НЕ<br>генерирует свой,<br>подписывает всё<br>вашим CA"]
    q -->|"только ca.crt<br>(без ca.key)"| ext["External CA mode:<br>kubeadm делает CSR,<br>вы подписываете<br>сами"]
    style q fill:#f4b400,color:#000
    style own fill:#0f9d58,color:#fff
    style ext fill:#326ce5,color:#fff
```

- **Свой CA (ключ + сертификат).** Положите `ca.crt` **и** `ca.key` (при необходимости и
  `etcd/ca.*`, `front-proxy-ca.*`, `sa.key/sa.pub`) в `/etc/kubernetes/pki/` **до**
  `kubeadm init`. kubeadm увидит готовый CA и подпишет им остальные сертификаты, не
  создавая собственный. Так весь кластер строится на вашем корне доверия.
- **External CA mode (без приватного ключа CA на ноде).** Положите только **`ca.crt`**
  (публичный) без `ca.key`. kubeadm перейдёт в режим внешнего CA: сгенерирует **CSR** и
  будет ждать, что вы подпишете их своим внешним CA и положите готовые сертификаты. Плюс -
  приватный ключ CA не хранится на ноде; минус - **продлевать сертификаты kubeadm сам не
  сможет**, это ваша задача.
- **Тонкая настройка через kubeadm config.** В `ClusterConfiguration` задают:
  `certificatesDir` (свой каталог PKI), `apiServer.certSANs` (доп. имена/адреса в
  сертификате apiserver - например, DNS балансировщика для HA, глава 35A), а также
  `etcd.external` с путями к вашим сертификатам, если etcd внешний.

```bash
# пример: инициализация с кастомными SAN и своим CA (лежит в pki/ заранее)
sudo kubeadm init --config kubeadm-config.yaml
# в kubeadm-config.yaml:
#   apiServer:
#     certSANs: ["api.example.com", "10.0.0.100"]
```

> **На экзамене** свой PKI строят редко, но понимание, что CA можно подложить заранее и
> что бывает external-CA режим, - частый вопрос и реальная прод-задача (единый корпоративный
> корень доверия, хранение ключа CA в HSM/Vault, а не на ноде).

## 35.9. Как это применяют в продакшене

- **kubeadm - для self-managed кластеров.** В облаке чаще берут управляемые кластеры
  (EKS/GKE/AKS), где control plane ставит и обслуживает провайдер. kubeadm выбирают для
  on-prem, приватных и специфичных инсталляций, где нужен полный контроль.
- **Автоматизация поверх kubeadm.** Вручную kubeadm запускают редко - его оборачивают в
  Ansible/Terraform/образы, а для парка кластеров используют Cluster API (kubeadm внутри).
  Ручной init/join - в основном обучение, лаборатории и разбор проблем.
- **HA control plane.** В проде поднимают несколько control plane нод
  (`--control-plane-endpoint` + балансировщик) и нечётное число узлов etcd - один control
  plane допустим только в dev. Подробно - в главе 35A.
- **Версии и подготовка ОС автоматизированы.** Отключение swap, модули, sysctl, установка
  containerd и фиксация версий kube* делаются шаблоном образа/провижинингом, чтобы ноды
  были одинаковыми и воспроизводимыми.
- **Знание раскладки файлов - основа эксплуатации.** Пути `/etc/kubernetes/...`,
  `/var/lib/etcd` нужны для бэкапа etcd, обновления сертификатов и починки control plane -
  это ежедневная реальность CKA-навыков в self-managed кластерах.

## 35.10. Мини-глоссарий

- **kubeadm** - официальный инструмент установки кластера (init/join/upgrade).
- **kubeadm init** - инициализация control plane.
- **kubeadm join** - присоединение ноды к кластеру.
- **bootstrap-токен** - временный токен для join нод (живёт ~24 часа).
- **--pod-network-cidr** - диапазон адресов подов (согласуется с CNI).
- **--control-plane-endpoint** - общий адрес control plane (для HA).
- **swapoff** - отключение swap (требование Kubernetes).
- **admin.conf** - kubeconfig администратора после init.
- **PKI кластера** - набор CA и сертификатов в `/etc/kubernetes/pki/`, создаётся при init.
- **CA кластера / etcd CA / front-proxy CA** - три корня доверия (срок ~10 лет).
- **External CA mode** - только `ca.crt` без ключа: kubeadm делает CSR, подпись - за вами.
- **certSANs** - дополнительные имена/адреса в сертификате apiserver (напр. DNS балансировщика).
- **sa.key / sa.pub** - ключи подписи токенов ServiceAccount.

## 35.11. Итоги главы

- kubeadm поднимает control plane (static pods, сертификаты, токены, kube-proxy, CoreDNS),
  но не ставит container runtime, CNI и не настраивает ОС - это делают отдельно.
- Подготовка нод: отключить swap, включить модули/sysctl, поставить containerd и
  kubeadm/kubelet/kubectl (с фиксацией версий).
- `kubeadm init --pod-network-cidr=...` инициализирует control plane и печатает настройку
  kubectl и команду `kubeadm join`.
- Сразу после init нужно установить CNI - иначе ноды NotReady и CoreDNS не стартует.
- Worker-ноды присоединяют `kubeadm join` с токеном; истёкший токен пересоздают
  `kubeadm token create --print-join-command`.
- Файлы предсказуемы: static pods в `/etc/kubernetes/manifests/`, сертификаты в `pki/`,
  данные etcd в `/var/lib/etcd/` - это основа для бэкапа и troubleshooting.
- kubeadm init генерирует PKI кластера: CA (кластера, etcd, front-proxy) на ~10 лет и
  листовые сертификаты на 1 год; продление - апгрейд или `kubeadm certs renew` (глава 39).
- Можно использовать свой CA: положить `ca.crt`+`ca.key` в `pki/` до init (или только
  `ca.crt` для external-CA режима, где подпись CSR - за вами).

## 35.12. Как это пригодится: на экзамене и в реальной работе

**На экзамене (CKA).** «Установи кластер kubeadm», «добавь worker-ноду», «почему ноды
NotReady» - прямые задания домена Installation (25%). Нужно знать шаги подготовки (swap!),
последовательность init → kubectl → CNI → join и раскладку файлов. Это фундамент для глав
36-37 и 45.

**В реальной работе.** kubeadm - основа self-managed и on-prem кластеров. Даже когда его
оборачивают в автоматизацию (Ansible, Cluster API), понимание, что он делает и где лежат
файлы, необходимо для обновлений, бэкапов etcd, ротации сертификатов и починки control
plane.

## 35.13. Вопросы для самопроверки

1. Что kubeadm делает при установке и чего он НЕ делает?
2. Какие шаги подготовки ноды нужны до kubeadm? Почему важен swapoff?
3. Что происходит после `kubeadm init` и какие две вещи он печатает?
4. Почему сразу после init ноды NotReady и что это исправляет?
5. Как присоединить worker-ноду и что делать, если токен истёк?
6. Где лежат static pods control plane, сертификаты и данные etcd?
7. Почему `--pod-network-cidr` должен согласовываться с CNI?
8. Какие сертификаты создаёт `kubeadm init` и на какой срок (CA vs листовые)?
9. Как заставить kubeadm использовать ваш собственный CA? Чем отличается external-CA режим?

## Практика

Мы собрали кластер. В главе 35A разберём, как сделать control plane отказоустойчивым (HA),
в главе 36 - безопасно обновлять кластер (lifecycle), а в главе 37 - бэкапить и
восстанавливать etcd. Установка kubeadm-кластера - это то, что делают наши лабораторные
работы автоматически (можно зайти на ноды и всё увидеть).

🧪 Лаба 116 (kubeadm init + join с нуля): [tasks/cka/labs/116](../../labs/116/README_RU.MD)

---
[Оглавление](../README_RU.md) · [Глава 34](../34/ru.md) · [Глава 35A](../35-2-ha/ru.md)
