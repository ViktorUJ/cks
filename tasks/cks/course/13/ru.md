<!-- Standalone RU release: ссылки на переводы удалены, потому что соответствующие файлы не входят в архив. -->

# Глава 13. Обновление Kubernetes для устранения уязвимостей

> **Проблема.** Опубликованный CVE в kubelet, API server, container runtime или ядре
> остаётся рабочим путём от скомпрометированного Pod либо сети к ноде и кластеру, пока
> уязвимая версия не заменена. EOL-ветка может вообще не получить исправление, а неверный
> порядок обновления добавляет простой или несовместимость вместо безопасного remediation.

> **Что дальше.** В главе 12 мы сократили доступ к Kubernetes API. Но правильно настроенный
> API не спасает от известной уязвимости в `kube-apiserver`, kubelet или container runtime.
> Обновление - это security-контроль: оно сокращает время, в течение которого атакующий
> может использовать опубликованный CVE. Это домен **Cluster Hardening** CKS (15%): нужно
> уметь оценить срочность advisory, соблюсти version skew и обновить кластер без новой
> поверхности атаки и без простоя.

> **Что нужно знать из CKA.** Полная процедура `kubeadm upgrade`, различие `apply` и
> `node`, `cordon`/`drain`/`uncordon`, PodDisruptionBudget и обновление ОС — отдельный
> lifecycle-навык. Здесь фиксируем необходимую security-последовательность: CVE, EOL,
> advisories, version skew, evidence и зависимости ноды.

> 🧠 Patch сокращает окно эксплуатации; приоритет учитывает достижимость, prerequisites и экспозицию кластера, не только CVSS.

## 13.1. Почему патч - это security-контроль

CVE в Kubernetes-компоненте, container runtime или ядре ноды может дать атакующему путь от
Pod к данным, Kubernetes API или самой ноде. Типичная цепочка: опубликован exploit для
установленной версии -> атакующий получает вход в workload либо сеть к control plane ->
использует уязвимый компонент до того, как команда поставит исправление. Firewall, RBAC и
NetworkPolicy уменьшают экспозицию, но не исправляют дефект в коде.

```mermaid
flowchart TB
    cve["Опубликован CVE<br/>в kubelet /<br/>runtime / ОС"] --> inv["Инвентаризация:<br/>какая версия<br/>установлена?"]
    inv --> risk["Оценка экспозиции:<br/>достижим ли<br/>компонент,<br/>нужны ли права?"]
    risk --> fix["Патч или обновление<br/>в проверенном окне"]
    fix --> verify["Проверка версий,<br/>health и workload"]
    style cve fill:#db4437,color:#fff
    style inv fill:#f4b400,color:#000
    style risk fill:#673ab7,color:#fff
    style fix fill:#326ce5,color:#fff
    style verify fill:#0f9d58,color:#fff
```

**Модель угрозы.** Не следует считать, что CVE опасен только при публичном endpoint. Например,
ошибка в `kubelet` может быть доступна с уже скомпрометированного Pod или соседней ноды,
а дефект `runc` - из контейнера, который уже запущен в кластере. Поэтому ответ зависит не
только от CVSS: важны prerequisites, доступность уязвимой функции, наличие публичного
exploit, компенсирующие controls и ценность затронутых нод.

**EOL (End of Life)** - отдельный риск. Для ветки, которую больше не поддерживает upstream
или дистрибутив, новые исправления CVE могут вообще не появиться. Компенсирующий control
не превращает EOL-версию в поддерживаемую: нужен план перехода на поддерживаемую минорную
ветку или поддержка от поставщика с явно определённым сроком.

Практическая реакция на advisory:

1. Зафиксируйте затронутые компоненты и точные версии, включая managed control plane,
   worker pools, `containerd`, `runc`, ОС и CNI.
2. Сопоставьте условия эксплуатации CVE со своей конфигурацией, сетевой доступностью и
   правами атакующего. Не игнорируйте CVE только из-за отсутствия внешнего доступа.
3. Выберите исправленную версию из advisory, проверьте support policy и совместимость,
   протестируйте в stage, затем выполните rollout с проверкой и откатом.
4. Если немедленный патч невозможен, временно сузьте экспозицию по рекомендациям advisory,
   назначьте владельца и дедлайн. Временная mitigation не должна остаться постоянной.

> 🏭 Release cadence и support window задают lifecycle: поддерживаемый кластер проще патчить, чем срочно мигрировать из EOL.

## 13.2. Release cadence, support window и version skew

Kubernetes выпускает минорные версии регулярно, обычно три раза в год, а patch-релизы
выходят по мере готовности исправлений. Точную дату и список исправлений надо брать из
release notes конкретной ветки, а не из старого runbook. Upstream обычно поддерживает три
последние минорные ветки: текущую `N`, `N-1` и `N-2`. Следовательно, `N-3` обычно уже EOL;
у managed-сервиса или enterprise-дистрибутива окно может отличаться, и его нужно проверять
отдельно.

В этой лаборатории Kubernetes `v1.36` обозначает **целевую (target) версию примера**, а не
«текущую stable» версию Kubernetes и не обещание её актуального support window. Перед
реальным change window сверяйте фактическую поддерживаемую target-ветку и fixed patch из
advisory. Переход делают последовательно, по одной minor-версии, например `v1.34` ->
`v1.35` -> `v1.36`; patch внутри ветки можно обновлять напрямую до исправленной версии.
Такой ритм оставляет время на тесты и не превращает срочный CVE в многоверсионный
migration-проект.

```mermaid
flowchart TB
    n["N: текущая<br/>минорная ветка"] --> n1["N-1: поддерживается"] --> n2["N-2: последняя<br/>upstream-<br/>поддерживаемая"] --> n3["N-3: обычно EOL<br/>нет новых<br/>upstream-патчей"]
    cp["kube-apiserver<br/>обновляется первым"] --> worker["kubelet: не новее<br/>apiserver<br/>и не более 3<br/>minor старше"]
    style n fill:#0f9d58,color:#fff
    style n1 fill:#0f9d58,color:#fff
    style n2 fill:#f4b400,color:#000
    style n3 fill:#db4437,color:#fff
    style cp fill:#326ce5,color:#fff
    style worker fill:#673ab7,color:#fff
```

> 🎯 Сначала обновляйте control plane; kubelet не новее `kube-apiserver` и не более чем на три minor-версии старше него.

**Version skew** ограничивает порядок обновления. Для каждого kubelet проверяйте две
границы относительно его `kube-apiserver`:

1. kubelet **не новее** API server;
2. kubelet **не более чем на три minor-версии старее** API server.

Из них следует порядок: сначала обновляют control plane, затем рабочие узлы. Допустимый
skew — временное состояние для короткого rolling upgrade, а не нормальный режим жизни
старых нод месяцами. Диапазон для других компонентов зависит от версии и роли; перед
изменением сверяйтесь с официальной
[policy version skew](https://kubernetes.io/releases/version-skew-policy/).

**HA control plane.** Экземпляры `kube-apiserver` могут отличаться максимум на одну
minor-версию. Пока в кластере остаётся старый API server, именно он сужает верхнюю границу
kubelet: kubelet не может быть новее **ни одного** API server. Например, при API servers
`1.37` и `1.36` допустимы kubelet `1.36`, `1.35` и `1.34`; kubelet `1.37` недопустим из-за
API server `1.36`.

**Control-plane managers.** `kube-controller-manager`, `kube-scheduler` и
`cloud-controller-manager` не должны быть новее `kube-apiserver`. Обычно их держат на той
же minor-версии; в допустимом skew они могут быть не более чем на одну minor-версию старее
соответствующего API server.

Перед целевым минорным обновлением также проверьте удаляемые API у приложений, Helm-чартов,
операторов и аддонов. Устранение CVE не должно сломать следующий deploy из-за удалённого
`apiVersion`; сохраните inventory до change window и устраните найденные зависимости до upgrade.

> 🏭 Advisory и точный inventory фиксируют affected versions, владельца remediation, SLA, evidence исправления и временную mitigation.

## 13.3. Advisories, CVE feed и инвентаризация версий

Источник решения - первичный advisory, а не только агрегатор CVE. У Kubernetes это
[security advisories](https://kubernetes.io/docs/reference/issues-security/security/) и
release notes; для ОС, облачного поставщика, CNI и runtime - advisory их производителя.
NVD, GitHub Advisory Database и корпоративные CVE feeds полезны для уведомлений и поиска,
но могут отставать, содержать неполные диапазоны версий или не описывать конфигурационные
условия.

| Что проверять | Где искать | Зачем |
|---|---|---|
| Kubernetes CVE и fixed version | Kubernetes security advisory, release notes | Понять затронутый диапазон, prerequisites и версию с исправлением |
| Поддержку ветки | upstream release/support policy или policy поставщика | Не выбрать EOL-ветку без последующих патчей |
| Версию client/server | `kubectl version --output=yaml` | Сопоставить server с advisory; client не доказывает версию ноды |
| Версию каждой ноды | `kubectl get nodes -o wide`, `kubectl describe node` | Найти отстающие kubelet и смешанный rollout |
| Пакеты runtime и ОС | пакетный менеджер, SBOM/asset inventory, vendor advisory | Kubernetes-патч не исправляет `containerd`, `runc`, kernel или OpenSSL |

```bash
# Версии kubectl и API server. Не выводите credentials из kubeconfig в тикет или чат.
kubectl version --output=yaml

# Версии kubelet на всех нодах и их состояние.
kubectl get nodes -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,OS:.status.nodeInfo.osImage

# На конкретной ноде: версия и происхождение пакетов зависят от дистрибутива.
kubeadm version -o short
containerd --version
runc --version
uname -r
```

`kubectl version` видит API server, но не заменяет инвентаризацию control-plane пакетов и
рабочего узла. В managed Kubernetes control plane может обновлять провайдер: всё равно нужно
сверить версию control plane, support calendar, node image/AMI и deadline, после которого
поставщик прекращает поддержку ветки.

Полезная привычка - вести patch SLA: критический CVE с reachable exploit получает короткое
окно реакции, остальные - ближайшее плановое окно. Severity сама по себе не приоритет:
CVE с меньшим CVSS, но без authentication в доступном извне компоненте, может быть важнее
локального CVE с трудными prerequisites.

> 🎯 Последовательность: preflight → первый control plane через `kubeadm upgrade apply` → health → каждый worker через `kubeadm upgrade node`, `cordon`/`drain`, kubelet, проверку и `uncordon`.

## 13.4. Безопасный `kubeadm` upgrade: control plane, затем ноды

Ниже — security-последовательность, которая не пропускает ни исправление CVE, ни
проверку его результата. `v1.36.x` здесь является **lab target**: замените его на точный поддерживаемый
patch из проверенного advisory и своего репозитория пакетов; это не утверждение, что
`v1.36` является текущей stable-версией.

### До изменения

- Прочитайте advisory и release notes, проверьте support window, version skew, удалённые API,
  совместимость CNI/CSI/CoreDNS и container runtime.
- Проверьте health control plane, свободную ёмкость для evicted Pod, PDB и готовность
  monitoring/alerting. Устраните уже существующие `NotReady` и `CrashLoopBackOff` до начала.
- Проверьте backup и процедуру восстановления etcd; backup должен быть проверяемым, а не
  только «успешно созданным файлом». Подготовьте tested rollback для пакетов и node image.
- Воспроизведите процедуру в stage с теми же critical add-ons и workload. Не добавляйте
  `--ignore-preflight-errors`, чтобы «пройти дальше», пока причина не понята и не одобрена.

```mermaid
flowchart TB
    plan["Advisory,<br/>fixed version,<br/>совместимость<br/>и backup"] --> cp["Control plane:<br/>kubeadm -><br/>plan/apply -><br/>cordon + drain -><br/>kubelet"]
    cp --> health["Проверка API, nodes,<br/>system Pods и alerts"]
    health --> node["Один рабочий узел:<br/>upgrade kubeadm -><br/>upgrade node"]
    node --> drain["cordon + drain"]
    drain --> workerKubelet["upgrade kubelet/<br/>kubectl -> restart"]
    workerKubelet --> verify["Ready, версия<br/>workload"]
    verify --> uncordon["uncordon и<br/>следующая нода"]
    style plan fill:#673ab7,color:#fff
    style cp fill:#326ce5,color:#fff
    style health fill:#f4b400,color:#000
    style drain fill:#db4437,color:#fff
    style node fill:#326ce5,color:#fff
    style verify fill:#0f9d58,color:#fff
    style uncordon fill:#0f9d58,color:#fff
```

### Control plane

На первом control-plane обновите пакет `kubeadm` до target-версии, выполните только
предварительный расчёт, затем примените обновление. Канонический порядок для minor-upgrade:
`kubeadm upgrade apply` → обновление CNI, если его compatibility matrix этого требует →
`cordon` и `drain` перед заменой `kubelet` → target-пакеты kubelet/kubectl → restart и
проверка → `uncordon`. Drain нельзя пропускать перед обновлением kubelet control-plane:
он даёт PDB и capacity возможность остановить небезопасный rollout. Проверяйте, что в
кластере есть ёмкость для выселенных workload.

Не используйте `--force` только для того, чтобы «продавить» непонятную ошибку drain.
Если drain обнаружил Pod без controller или с отсутствующим managing resource, сначала
идентифицируйте workload и подтвердите способ его восстановления. Только после явного
принятия риска допустимо использовать `--force`. Не путайте это с `--disable-eviction`:
этот флаг заставляет drain обходить Eviction API и проверки PodDisruptionBudget и не
должен использоваться как обычный способ ускорить upgrade. Static Pods control plane не
выселяются через `drain`.

После `apply` и нужной проверки CNI установите target `kubelet` и `kubectl`, перезапустите
kubelet, убедитесь в `Ready` и только тогда сделайте `uncordon`. В HA-кластере остальные control-plane ноды
обновляют по одной через `kubeadm upgrade node`, с проверкой quorum и API между нодами. Не
обновляйте все control-plane ноды одновременно.

```bash
# Пример Debian/Ubuntu. Сначала переключите фактически активный source на target minor,
# затем обновите индекс и выберите точный patch из этого репозитория. `1.36.<PATCH>` и
# `1.36.x-*` не являются copy-paste значениями.
export TARGET_K8S_VERSION='v1.36.<PATCH>'
export TARGET_K8S_MINOR='v1.36'
KEYRING=/etc/apt/keyrings/kubernetes-apt-keyring.gpg
K8S_SOURCE_FILES=$(sudo grep -RIlE --include='*.list' --include='*.sources' \
  'https://(pkgs\.k8s\.io|pkgs\.kubernetes\.io|packages\.kubernetes\.io)/core:/stable:/v1\.[0-9]+/deb/' \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | sort -u || true)

# Один signing key используется для всех minor-веток. Создайте keyring лишь при первом
# подключении репозитория; --yes исключает интерактивный вопрос о перезаписи.
if ! sudo test -s "$KEYRING"; then
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${TARGET_K8S_MINOR}/deb/Release.key" \
    | sudo gpg --dearmor --yes -o "$KEYRING"
  sudo chmod 0644 "$KEYRING"
fi

# Меняем minor в реально активном source, а не всегда создаём kubernetes.list.
if [ -n "$K8S_SOURCE_FILES" ]; then
  printf '%s\n' "$K8S_SOURCE_FILES"
  while IFS= read -r source_file; do
    sudo sed -Ei "s#https://(pkgs\.k8s\.io|pkgs\.kubernetes\.io|packages\.kubernetes\.io)/core:/stable:/v1\.[0-9]+/deb/#https://pkgs.k8s.io/core:/stable:/${TARGET_K8S_MINOR}/deb/#g" "$source_file"
  done <<< "$K8S_SOURCE_FILES"
else
  echo "deb [signed-by=$KEYRING] https://pkgs.k8s.io/core:/stable:/${TARGET_K8S_MINOR}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
fi
sudo apt-get update
apt-cache madison kubeadm
export TARGET_K8S_PACKAGE_VERSION='<точная-версия-из-целевого-репозитория>'

# На control-plane-1: kubeadm можно обновить до apply, kubelet -- только после drain.
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm="$TARGET_K8S_PACKAGE_VERSION"
sudo apt-mark hold kubeadm
sudo kubeadm upgrade plan

# На control-plane-1: сначала обновляется control plane.
sudo kubeadm upgrade apply "$TARGET_K8S_VERSION" --yes
# Если матрица CNI требует обновления, выполните его здесь и подтвердите сеть.

# С административной машины: только перед minor-обновлением kubelet.
kubectl cordon control-plane-1
kubectl drain control-plane-1 --ignore-daemonsets

# На control-plane-1.
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet="$TARGET_K8S_PACKAGE_VERSION" kubectl="$TARGET_K8S_PACKAGE_VERSION"
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# С административной машины: только после Ready и проверки версии.
kubectl get node control-plane-1 -o wide
kubectl uncordon control-plane-1
```

### Worker-ноды

К рабочим узлам переходят только после healthy control plane. Канонический порядок для
каждой worker-ноды: обновить `kubeadm` → выполнить `kubeadm upgrade node` (**не** `apply`) →
вывести ноду из планирования и освободить её → обновить `kubelet` и `kubectl` →
перезапустить kubelet → проверить `Ready` и версию → `uncordon`. Повторяют по одной ноде,
соблюдая PDB и требуемую capacity.

```bash
# На worker-1, пример Debian/Ubuntu. Репозиторий pkgs.k8s.io привязан к minor-ветке:
# поменяйте minor в фактически активном source, затем обновите индекс и выбирайте patch.
export TARGET_K8S_VERSION='v1.36.<PATCH>'
export TARGET_K8S_MINOR='v1.36'
KEYRING=/etc/apt/keyrings/kubernetes-apt-keyring.gpg
K8S_SOURCE_FILES=$(sudo grep -RIlE --include='*.list' --include='*.sources' \
  'https://(pkgs\.k8s\.io|pkgs\.kubernetes\.io|packages\.kubernetes\.io)/core:/stable:/v1\.[0-9]+/deb/' \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | sort -u || true)

# Обычная minor-смена переиспользует signing key. Импортируйте и сделайте keyring читаемым
# для apt только при первом подключении; --yes исключает интерактивную перезапись.
if ! sudo test -s "$KEYRING"; then
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${TARGET_K8S_MINOR}/deb/Release.key" \
    | sudo gpg --dearmor --yes -o "$KEYRING"
  sudo chmod 0644 "$KEYRING"
fi

if [ -n "$K8S_SOURCE_FILES" ]; then
  printf '%s\n' "$K8S_SOURCE_FILES"
  while IFS= read -r source_file; do
    sudo sed -Ei "s#https://(pkgs\.k8s\.io|pkgs\.kubernetes\.io|packages\.kubernetes\.io)/core:/stable:/v1\.[0-9]+/deb/#https://pkgs.k8s.io/core:/stable:/${TARGET_K8S_MINOR}/deb/#g" "$source_file"
  done <<< "$K8S_SOURCE_FILES"
else
  echo "deb [signed-by=$KEYRING] https://pkgs.k8s.io/core:/stable:/${TARGET_K8S_MINOR}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
fi
sudo apt-get update
apt-cache madison kubeadm
export TARGET_K8S_PACKAGE_VERSION='<точная-версия-из-целевого-репозитория>'

# Сначала обновите kubeadm и примените его node-конфигурацию.
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm="$TARGET_K8S_PACKAGE_VERSION"
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node

# С административной машины: --delete-emptydir-data добавляйте только после принятия
# потери local emptyDir. --force нужен только для явно разобранных unmanaged Pod /
# missing controller. Не используйте --disable-eviction для обхода PDB в обычном rollout.
kubectl cordon worker-1
kubectl drain worker-1 --ignore-daemonsets

# На worker-1: kubelet и kubectl обновляют вместе только после drain.
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet="$TARGET_K8S_PACKAGE_VERSION" kubectl="$TARGET_K8S_PACKAGE_VERSION"
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# С административной машины: только после Ready, версии и workload smoke test.
kubectl get node worker-1 -o wide
kubectl uncordon worker-1
```

Для RPM-дистрибутива сначала проверьте и при необходимости переключите vendor-репозиторий
на целевую minor-ветку, затем выберите **явную точную** версию. Используйте эквиваленты
`kubeadm-<TARGET_K8S_PACKAGE_VERSION>`, `kubelet-<TARGET_K8S_PACKAGE_VERSION>` и
`kubectl-<TARGET_K8S_PACKAGE_VERSION>` в том же порядке: `kubeadm upgrade node` → drain →
обновление kubelet/kubectl → restart kubelet → проверка → `uncordon`. Не оставляйте worker
на старом kubelet из-за того, что `kubeadm upgrade node` завершился успешно: эта команда не
устанавливает пакеты.

### Проверка результата и диагностика

```bash
kubectl get nodes -o wide
kubectl get --raw='/readyz?verbose'

# Gate завершается с ненулевым кодом для Failed/Pending/Unknown Pod или Running Pod без Ready=True.
# Успешно завершённые Pods Job имеют phase=Succeeded и намеренно не считаются ошибкой.
kubectl get pods -A -o json | jq -e '
  [ .items[]
    | select(
        .status.phase == "Failed" or
        .status.phase == "Pending" or
        .status.phase == "Unknown" or
        (.status.phase == "Running" and
          (any(.status.conditions[]?; .type == "Ready" and .status == "True") | not))
      )
  ] | length == 0
'
kubectl get events -A --sort-by=.lastTimestamp
kubectl version --output=yaml
```

Проверьте отдельно: API server готов, все ноды `Ready`, версии соответствуют плану, `kube-system`
и критичные DaemonSet/Deployment восстановились, workload проходит smoke test, а alerts не
сигнализируют об ошибках runtime, CNI, DNS или storage. Ошибка `NotReady` после обновления
чаще требует смотреть `journalctl -u kubelet`, статус `containerd`, cgroup driver, CRI socket
и логи CNI - не повторять `kubeadm` вслепую.

> 🔬 Runtime, kernel, ОС и cgroup v2 образуют совместимый node-image contract; проверяйте его в stage.

## 13.5. Runtime и ОС: Kubernetes не единственный источник CVE

Патч `kube-apiserver` не обновляет `containerd`, `runc`, kernel, OpenSSL, `systemd` и
пакеты ОС. Для атаки из контейнера именно runtime и kernel часто являются границей между
workload и нодой. Поэтому inventory и patch policy должны охватывать весь node image.

| Зависимость | Риск при отставании | Что проверить перед rollout |
|---|---|---|
| `containerd` и CRI | CVE, несовместимый CRI, изменение конфигурации/сокета | Поддержку целевой Kubernetes-версии, `SystemdCgroup`, health сервиса и образ ноды |
| `runc` | escape из контейнера при уязвимости runtime | Fixed version из advisory и пакетную зависимость containerd |
| kernel и ОС-пакеты | privilege escalation, network/filesystem CVE | Поддержку ОС, vendor security update, необходимость reboot и node image |
| cgroups/systemd | kubelet/runtime не запускаются либо получают разные cgroup | Единый cgroup driver и поддержку cgroup v2 в ОС и runtime |
| CNI, CSI, CoreDNS | сеть, storage или DNS не восстановятся после change | Compatibility matrix и smoke test на stage |

### Cgroup v2 baseline для Kubernetes v1.35+

До планирования перехода на Kubernetes v1.35+ выполните preflight **на каждой ноде**:
kubelet и runtime должны работать с cgroup v2 и согласованным `systemd` cgroup driver.
`failCgroupV1` — поле `KubeletConfiguration`, а не feature gate; его default равен `true`
с v1.35. Не отключайте его через `failCgroupV1: false`, чтобы продлить жизнь cgroup v1:
временный override возможен лишь как краткая, документированная мера миграции. Если
проверка не проходит, сначала мигрируйте ОС/runtime в stage и проверьте node image, а не
обходите preflight в production.

В Kubernetes v1.36 `KubeletCgroupDriverFromCRI` уже GA. Если CRI runtime поддерживает
вызов `RuntimeConfig`, kubelet получает driver от runtime и игнорирует собственный
`cgroupDriver`; если runtime его не поддерживает, kubelet использует `cgroupDriver` из
своей конфигурации. Поэтому не фиксируйте пути `/var/lib/kubelet/config.yaml` и
`/etc/containerd/config.toml`: сначала определите активные `--config`/`--config-dir` kubelet
и unit, процесс и документированный config source установленного CRI runtime.

```yaml
# В активном KubeletConfiguration, найденном из startup configuration.
failCgroupV1: true
# cgroupDriver: systemd  # fallback только для runtime без RuntimeConfig
```

```bash
# На каждой ноде; ненулевой exit code означает, что cgroup v2 baseline пока не выполнен.
set -euo pipefail
test "$(stat -fc %T /sys/fs/cgroup)" = 'cgroup2fs'
sudo systemctl cat kubelet containerd crio 2>/dev/null || true
KUBELET_PID=$(pgrep -xo kubelet) || { echo 'kubelet process not found' >&2; exit 2; }
sudo tr '\0' '\n' < "/proc/$KUBELET_PID/cmdline" \
  | grep -E -- '^--config(=|$)|^--config-dir(=|$)' || true
sudo journalctl -u kubelet -b --no-pager | grep -Ei 'cgroup|RuntimeConfig' || true
```

Для CRI-O, containerd с нестандартной установкой или другого runtime проверьте его
эффективный driver в документированной runtime-конфигурации и в логах; не копируйте путь
containerd или поле `SystemdCgroup` вслепую.

Безопасная стратегия - разделить риск: сначала проверить совместимую связку Kubernetes +
runtime + ОС в stage, затем раскатывать по нодам. Если urgent runtime/OS CVE требует
немедленной remediation, используйте тот же lifecycle: `cordon` -> `drain` -> patch/reboot
или replacement -> health check -> `uncordon`. Для immutable node pool часто безопаснее
создать новый patched pool, перенести workload rolling-заменой и удалить старые ноды, чем
менять множество пакетов на месте.

При обновлении package repository проверяйте источник и подпись репозитория. Не смешивайте
случайные версии из разных репозиториев и не делайте одновременно большой Kubernetes,
runtime и ОС migration без выделенного теста: так трудно отличить CVE remediation от
regression и безопасно откатиться.

> 🎯 Не нарушайте version skew, не обновляйте все ноды одновременно, не обходите PDB или preflight без причины и подтверждайте итог версиями и health.

## 13.6. Типичные ошибки при security-обновлении

- **«У нас нет публичного API, CVE не касается нас».** Уязвимый kubelet или runtime может
  быть доступен внутреннему атакующему после компрометации Pod или ноды.
- **Патчится только control plane.** Worker kubelet, `containerd`, `runc` и ОС остаются
  уязвимыми, хотя `kubectl version` уже выглядит хорошо.
- **EOL принимают за низкий риск.** Отсутствие нового advisory означает отсутствие patch,
  а не отсутствие уязвимостей.
- **Перепрыгивают минорные версии или обновляют kubelet раньше API server.** Это нарушает
  version skew и создаёт трудно диагностируемое состояние.
- **Обновляют все ноды сразу либо обходят PDB.** Срочный CVE не оправдывает потерю всех
  реплик; сначала оценивают экспозицию и capacity, затем выполняют rolling rollout.
- **Доверяют только успешному `kubeadm`.** Команда не доказывает, что runtime, CNI, DNS,
  storage и приложения действительно работают на исправленных версиях.

> 🏭 Security upgrade: advisories, inventory, support policy, stage, progressive rollout, evidence и stop conditions при health failure.

## 13.7. Как это применяют в продакшене

- **Patch management как процесс.** Команда подписывается на upstream и vendor advisories,
  связывает CVE с inventory, назначает severity-based SLA, владельца, окно rollout и
  подтверждение закрытия. Это лучше разовых «дней обновления» раз в год.
- **Короткий lag от релиза.** Регулярный переход в пределах поддерживаемого окна N/N-1/N-2
  уменьшает размер каждого изменения и оставляет возможность спокойно тестировать critical
  CVE, а не проводить multi-hop upgrade ночью.
- **Stage и progressive rollout.** Сначала тестируют node image и аддоны, затем обновляют
  небольшой pool/ноду, смотрят метрики и только после этого продолжают. Для managed
  Kubernetes контролируют отдельно control plane и node pool deadlines.
- **Автоматизированная, но наблюдаемая замена нод.** Infrastructure as Code, golden image,
  maintenance windows, PDB и autoscaling делают обновление воспроизводимым. Автоматизация
  обязана останавливаться на health failure, а не продолжать заменять весь парк.
- **Единый SBOM/asset inventory.** Он связывает advisory не только с Kubernetes, но и с
  `containerd`, `runc`, CNI, ОС и kernel, поэтому команда не упускает вторую половину
  атаки на ноду.

## 13.8. Мини-глоссарий

- **CVE** - идентификатор публично известной уязвимости.
- **security advisory** - первичное уведомление производителя с затронутыми версиями,
  условиями эксплуатации, mitigation и fixed version.
- **EOL** - окончание поддержки версии; новые upstream security patches обычно не выходят.
- **release cadence** - регулярность выхода минорных и patch-релизов.
- **support window** - диапазон поддерживаемых веток; upstream Kubernetes обычно держит
  `N`, `N-1` и `N-2`.
- **version skew** - допустимая разница версий компонентов; kubelet не новее API server и не более чем на три minor-версии старше него.
- **`kubeadm upgrade plan` / `apply` / `node`** - план обновления / применение на первом
  control plane / обновление конфигурации конкретной ноды.
- **rolling upgrade** - обновление по одной ноде с проверкой между шагами.
- **`cordon` / `drain` / `uncordon`** - запретить планирование / выселить workload /
  вернуть ноду в планирование.
- **node image** - согласованный образ ОС, runtime и пакетов для ноды.

## 13.9. Итоги главы

- Обновление - security-контроль: оно устраняет известные CVE в Kubernetes, но не заменяет
  RBAC, network controls и hardening.
- EOL-ветка опасна тем, что для новых CVE может не быть upstream patch; обычно поддерживаются
  только `N`, `N-1` и `N-2`, а `N-3` уже EOL.
- Advisory и release notes - первичный источник fixed version и условий CVE; CVE feed
  помогает уведомлять, но не заменяет чтение advisory и инвентаризацию нод.
- Соблюдайте version skew: control plane обновляется первым, kubelet не новее API server
  и не более чем на три minor-версии старше него; minor-версии проходят последовательно.
- Безопасный `kubeadm` rollout: preflight и backup -> control plane -> health check ->
  на одном worker `kubeadm` -> `kubeadm upgrade node` -> `cordon`/`drain` -> kubelet/kubectl ->
  restart и проверка -> `uncordon`.
- Kubernetes-патч не исправляет CVE в `containerd`, `runc`, kernel и ОС; runtime и node image
  требуют отдельной compatibility-проверки и patch policy.

## 13.10. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** Задание может попросить безопасно обновить кластер или объяснить порядок
версий. Сначала определите текущую и целевую версии, не нарушайте version skew, обновите
control plane до рабочего узла, используйте `drain` перед обновлением kubelet и верните узел
через `uncordon`. Помните разницу: на первом узле control plane применяется `kubeadm upgrade
apply`, на worker - `kubeadm upgrade node`.

**В реальной работе.** Ценность навыка не в механическом запуске `kubeadm`, а в сокращении
экспозиции CVE без потери доступности. Инженер читает advisory, подтверждает затронутые
версии, проверяет EOL и зависимости, тестирует node image, идёт rolling-волной и доказывает
после неё и исправленную версию, и работоспособность сервисов.

> 🏭 Gate сохраняет before/after evidence версий, readiness, PSS, admission/RBAC и security-флагов API server; он не заменяет tested rollback.

## 13.11. Самостоятельная практика: security upgrade gate

Это self-contained контролируемая simulation для kubeadm-кластера. Она не заменяет
реальное обновление пакетов: цель - пройти все security gates и получить артефакты до/после,
не меняя версию учебного кластера. Выполняйте её только в одноразовом стенде; пути
сертификатов etcd сначала сверяйте с manifest вашего control plane.

Создайте каталог evidence и зафиксируйте исходное состояние:

```bash
export UPGRADE_EVIDENCE=/tmp/cks-upgrade-security
mkdir -p "$UPGRADE_EVIDENCE"/{before,after}

kubectl version -o yaml > "$UPGRADE_EVIDENCE/before/version.yaml"
kubectl get nodes -o wide > "$UPGRADE_EVIDENCE/before/nodes.txt"
kubectl get --raw='/readyz?verbose' > "$UPGRADE_EVIDENCE/before/readyz.txt"
kubectl get ns -o json > "$UPGRADE_EVIDENCE/before/namespaces.json"
kubectl get clusterrole,clusterrolebinding -o yaml > "$UPGRADE_EVIDENCE/before/rbac.yaml"
# MutatingAdmissionPolicy may be not served (for example, the v1.35 beta feature was off
# by default). Preserve an explicit marker instead of failing the whole pre-upgrade snapshot.
snapshot_admission_resources() {
  local phase=$1 resource served
  served=$(kubectl api-resources --api-group=admissionregistration.k8s.io -o name)
  {
    for resource in validatingadmissionpolicies validatingadmissionpolicybindings \
      validatingwebhookconfigurations mutatingwebhookconfigurations; do
      printf '# resource: %s\n' "$resource"
      kubectl get "$resource" -o yaml
      printf '%s\n' '---'
    done
    for resource in mutatingadmissionpolicies mutatingadmissionpolicybindings; do
      printf '# resource: %s\n' "$resource"
      if grep -Fxq "${resource}.admissionregistration.k8s.io" <<< "$served"; then
        kubectl get "$resource" -o yaml
      else
        printf '# NOT_SERVED\n'
      fi
      printf '%s\n' '---'
    done
  } > "$UPGRADE_EVIDENCE/$phase/admission.yaml"
}
snapshot_admission_resources before
```

### Gate 1: kubelet version skew и план

Это ограниченный gate: он сравнивает каждый kubelet только с одним API server, который
вернул `kubectl` (в HA это может быть один backend load balancer), и останавливается, если
kubelet нарушает любую границу: новее этого API server **либо** более чем на три
minor-версии старше. Он не доказывает skew всех HA API servers и не проверяет
`kube-controller-manager`, `kube-scheduler`, `cloud-controller-manager`, `kube-proxy` или
`kubectl`; их inventory и policy сверяют отдельно перед production rollout. Затем `kubeadm
upgrade plan` проверяет доступные цели, preflight и порядок обновления. Для реального
перехода выберите ровно следующую minor-ветку.

```bash
set -euo pipefail
SERVER_MINOR=$(kubectl version -o json | jq -r '.serverVersion.minor | sub("[^0-9].*$"; "") | tonumber')
kubectl get nodes -o json | jq -e --argjson server "$SERVER_MINOR" \
  '[.items[] | (.status.nodeInfo.kubeletVersion | capture("v1\\.(?<m>[0-9]+)").m | tonumber)] |
   all(. >= ($server - 3) and . <= $server)' \
  | tee "$UPGRADE_EVIDENCE/before/skew-check.txt"
sudo kubeadm upgrade plan | tee "$UPGRADE_EVIDENCE/before/kubeadm-upgrade-plan.txt"
```

### Gate 2: backup и проверяемое восстановление

Наличие `etcdctl`/`etcdutl` не следует выводить из самого факта установки kubeadm.
Перед gate проверьте binaries и их совместимость с версией etcd. Если инструментов нет,
установите заранее проверенную и закреплённую совместимую версию из доверенного
источника либо используйте утверждённый operational image/toolbox. Не скачивайте
`latest` непосредственно во время change window.

```bash
command -v etcdctl >/dev/null 2>&1 || {
  echo 'ERROR: etcdctl is not installed on this control-plane node' >&2
  exit 1
}
command -v etcdutl >/dev/null 2>&1 || {
  echo 'ERROR: etcdutl is not installed on this control-plane node' >&2
  exit 1
}
etcdctl version
etcdutl version
```

На узле control plane создайте snapshot с TLS-параметрами из
`/etc/kubernetes/manifests/etcd.yaml`, затем проверьте его через `etcdutl snapshot status`.
Не запускайте restore поверх работающего etcd: запишите точную restore-команду в runbook и
репетируйте её в отдельном кластере.

```bash
sudo ETCDCTL_API=3 etcdctl snapshot save /var/backups/etcd-pre-upgrade.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
sudo etcdutl snapshot status /var/backups/etcd-pre-upgrade.db -w json \
  | tee "$UPGRADE_EVIDENCE/before/etcd-snapshot-status.json"
sudo sha256sum /var/backups/etcd-pre-upgrade.db \
  | tee "$UPGRADE_EVIDENCE/before/etcd-snapshot.sha256"
```

### Gate 3: deprecated API и security configuration

Проверьте не только manifests в Git, но и фактическое использование deprecated APIs по
метрике API server. Прямой `kubectl get --raw /metrics` ниже получает метрики только одного
выбранного API server backend и потому в HA является лишь локальным evidence, а не полным
inventory. Для production HA агрегируйте scrape **всех** API servers в monitoring (например,
PromQL `max by (group, version, resource, subresource, removed_release)
(apiserver_requested_deprecated_apis) > 0`) либо сверяйте audit events каждого API server.
Любая строка со значением больше нуля получает владельца и remediation до upgrade. Зафиксируйте
PSS, admission и критические RBAC-разрешения. Namespace labels — только часть effective PSS:
cluster-wide defaults и exemptions могут задаваться через `PodSecurityConfiguration` в файле,
переданном API server флагом `--admission-control-config-file`; этот файл сохраняется в Gate 4.

```bash
# Это evidence только выбранного API server backend; в HA используйте описанную выше агрегацию.
kubectl get --raw /metrics \
  | awk '/^apiserver_requested_deprecated_apis/ && $NF > 0' \
  | tee "$UPGRADE_EVIDENCE/before/deprecated-apis.txt"

kubectl auth can-i --list --as=system:serviceaccount:default:default \
  > "$UPGRADE_EVIDENCE/before/default-sa-can-i.txt"
# Effective PSS map (labels + defaults + version + exemptions) is built in Gate 4 after
# the active kube-apiserver configuration has been resolved from its actual volume mounts.
kubectl api-resources --api-group=admissionregistration.k8s.io \
  > "$UPGRADE_EVIDENCE/before/admission-resources.txt"
```

### Gate 4: security-флаги static Pod manifests не должны исчезнуть

Главная экзаменационная ловушка `kubeadm upgrade`: команда переписывает static Pod
manifests control plane из своей собственной конфигурации (`ClusterConfiguration` в
`kubeadm-config` ConfigMap), а не просто патчит существующий файл. Кастомные флаги
`--audit-policy-file`, `--audit-log-path`, `--encryption-provider-config` (KMS/at-rest
encryption) и `--profiling=false`, добавленные вручную в manifest **после** первоначальной
установки кластера, но не отражённые в `kubeadm-config`, могут быть потеряны при следующем
`kubeadm upgrade apply` - кластер останется API-совместим и `Ready`, но de facto потеряет
audit trail, шифрование Secret at rest или debug-профилирование останется включённым.
Зафиксируйте полный список аргументов **до** upgrade. В HA-кластере `.items[0]` может
выбрать разную control-plane ноду до и после upgrade, поэтому явно закрепите проверяемую
ноду через `--field-selector`:

```bash
export CONTROL_PLANE_NODE='control-plane-1'

# Baseline допустим только от ровно одного Ready kube-apiserver на целевой ноде.
# Без этой проверки .items[0] для пустого списка даёт пустой файл с jq exit code 0.
BEFORE_APISERVER_JSON="$(
  kubectl -n kube-system get pods -l component=kube-apiserver \
    --field-selector "spec.nodeName=${CONTROL_PLANE_NODE}" \
    -o json
)"
printf '%s\n' "$BEFORE_APISERVER_JSON" | jq -e '
  (.items | length) == 1 and
  any(.items[0].status.conditions[]?;
      .type == "Ready" and .status == "True")
' > "$UPGRADE_EVIDENCE/before/apiserver-node-gate.txt"
printf '%s\n' "$BEFORE_APISERVER_JSON" \
  | jq -r '.items[0].spec.containers[0].command[]?' \
  | sort > "$UPGRADE_EVIDENCE/before/apiserver-flags.txt"
grep -E '^--(audit-policy-file|audit-log-path|encryption-provider-config|profiling)' \
  "$UPGRADE_EVIDENCE/before/apiserver-flags.txt" \
  > "$UPGRADE_EVIDENCE/before/apiserver-security-flags.txt" || true

# Effective PSS включает labels namespace и PodSecurityConfiguration с defaults/exemptions.
# Выполняйте этот блок на CONTROL_PLANE_NODE. Если путь из container argv не совпадает с
# hostPath static Pod manifest, сначала сопоставьте его с hostPath: иначе sudo test остановит gate.
# PyYAML is used only as a parser for the documented AdmissionConfiguration schema. A
# missing parser or an ambiguous mount/path must stop the gate; it must never yield PASS.
python3 -c 'import yaml' || {
  echo 'ERROR: Python PyYAML is required to inspect effective PodSecurity configuration' >&2
  exit 2
}

resolve_apiserver_host_path() {
  local container_path=$1 apiserver_json=$2 mapping host_path sub_path relative_path
  mapping=$(printf '%s\n' "$apiserver_json" | jq -ce --arg path "$container_path" '
    def relative_to_mount($path; $mount):
      if $path == $mount then "" else ($path | ltrimstr($mount + "/")) end;
    .items[0] as $pod |
    [ $pod.spec.containers[0].volumeMounts[]? as $mount
      | ($mount.mountPath) as $mount_path
      | select($path == $mount_path or ($path | startswith($mount_path + "/")))
      | ($pod.spec.volumes[]? | select(.name == $mount.name and .hostPath.path? != null)) as $volume
      | {mountPath: $mount_path, hostPath: $volume.hostPath.path,
         subPath: ($mount.subPath // ""),
         relativePath: relative_to_mount($path; $mount_path)}
    ] | sort_by(.mountPath | length) | reverse as $candidates |
    ($candidates[0].mountPath) as $longest |
    [$candidates[] | select(.mountPath == $longest)] |
    if length == 1 then .[0] else error("no unique hostPath mapping") end
  ') || {
    echo "ERROR: cannot map kube-apiserver container path to one hostPath: $container_path" >&2
    return 2
  }
  IFS=$'\t' read -r host_path sub_path relative_path < <(
    jq -r '[.hostPath, .subPath, .relativePath] | @tsv' <<< "$mapping"
  )
  for component in "$sub_path" "$relative_path"; do
    case "/$component/" in
      *'/../'*|*/..|../*)
        echo 'ERROR: unsafe relative path in kube-apiserver volume mapping' >&2
        return 2
        ;;
    esac
  done
  printf '%s%s%s\n' "$host_path" \
    "${sub_path:+/$sub_path}" "${relative_path:+/$relative_path}"
}

capture_admission_control_config() {
  local phase=$1 apiserver_json=$2 config_container_path='' config_host_path='' i disabled='false'
  local plugin_kind plugin_path='' plugin_container_path='' plugin_host_path=''
  local -a argv=()
  mapfile -t argv < <(printf '%s\n' "$apiserver_json" \
    | jq -r '.items[0].spec.containers[0].command[]?')
  printf '%s\n' "${argv[@]}" \
    | grep -E '^--(admission-control-config-file|disable-admission-plugins)(=|$)' \
    > "$UPGRADE_EVIDENCE/$phase/pss-admission-flags.txt" || true

  for ((i = 0; i < ${#argv[@]}; i++)); do
    case "${argv[i]}" in
      --admission-control-config-file=*)
        [[ -z "$config_container_path" ]] || { echo 'duplicate admission-control config flag' >&2; return 2; }
        config_container_path=${argv[i]#--admission-control-config-file=}
        ;;
      --admission-control-config-file)
        (( i + 1 < ${#argv[@]} )) || { echo 'missing admission-control config path' >&2; return 2; }
        [[ -z "$config_container_path" ]] || { echo 'duplicate admission-control config flag' >&2; return 2; }
        i=$((i + 1))
        config_container_path=${argv[i]}
        ;;
      --disable-admission-plugins=*)
        [[ ",${argv[i]#--disable-admission-plugins=}," == *,PodSecurity,* ]] && disabled='true'
        ;;
      --disable-admission-plugins)
        (( i + 1 < ${#argv[@]} )) || { echo 'missing disabled admission plugin list' >&2; return 2; }
        i=$((i + 1))
        [[ ",${argv[i]}," == *,PodSecurity,* ]] && disabled='true'
        ;;
    esac
  done
  if [[ "$disabled" == true ]]; then
    printf 'PodSecurity=DISABLED\n' > "$UPGRADE_EVIDENCE/$phase/pss-admission-status.txt"
    echo 'ERROR: PodSecurity is disabled through --disable-admission-plugins' >&2
    return 1
  fi
  printf 'PodSecurity=ENABLED\n' > "$UPGRADE_EVIDENCE/$phase/pss-admission-status.txt"

  if [[ -z "$config_container_path" ]]; then
    printf 'not-set\n' > "$UPGRADE_EVIDENCE/$phase/admission-control-config-path.txt"
    printf 'admission-control-config-file: not-set\n' \
      > "$UPGRADE_EVIDENCE/$phase/admission-control-config.yaml"
    python3 - "$UPGRADE_EVIDENCE/$phase/pss-effective-config.json" <<'PYTHON'
import json, sys
json.dump({"source": "apiserver-defaults", "defaults": {
    "enforce": "privileged", "enforce-version": "latest",
    "audit": "privileged", "audit-version": "latest",
    "warn": "privileged", "warn-version": "latest",
}, "exemptions": {"usernames": [], "runtimeClasses": [], "namespaces": []}},
    open(sys.argv[1], "w"), sort_keys=True)
PYTHON
  else
    [[ "$config_container_path" == /* ]] || { echo 'admission-control config path is not absolute' >&2; return 2; }
    config_host_path=$(resolve_apiserver_host_path "$config_container_path" "$apiserver_json")
    printf '%s\n' "$config_container_path -> $config_host_path" \
      > "$UPGRADE_EVIDENCE/$phase/admission-control-config-path.txt"
    sudo cat -- "$config_host_path" \
      > "$UPGRADE_EVIDENCE/$phase/admission-control-config.yaml"
    python3 - "$UPGRADE_EVIDENCE/$phase/admission-control-config.yaml" \
      "$UPGRADE_EVIDENCE/$phase/pss-plugin-reference.json" <<'PYTHON'
import json, sys, yaml
config = yaml.safe_load(open(sys.argv[1])) or {}
plugins = [p for p in config.get("plugins", []) if p.get("name") == "PodSecurity"]
if len(plugins) > 1:
    raise SystemExit("multiple PodSecurity plugin configurations")
if not plugins:
    result = {"kind": "default"}
else:
    plugin = plugins[0]
    if plugin.get("configuration") is not None:
        result = {"kind": "embedded", "configuration": plugin["configuration"]}
    elif plugin.get("path"):
        result = {"kind": "path", "path": plugin["path"]}
    else:
        result = {"kind": "default"}
json.dump(result, open(sys.argv[2], "w"), sort_keys=True)
PYTHON
    plugin_kind=$(jq -r '.kind' "$UPGRADE_EVIDENCE/$phase/pss-plugin-reference.json")
    if [[ "$plugin_kind" == path ]]; then
      plugin_path=$(jq -r '.path' "$UPGRADE_EVIDENCE/$phase/pss-plugin-reference.json")
      # Kubernetes resolves a relative plugin path against the directory of the primary
      # --admission-control-config-file. Normalize first, then map the resulting absolute
      # container path through the static Pod hostPath mounts.
      plugin_container_path=$(python3 - "$config_container_path" "$plugin_path" <<'PYTHON'
import posixpath, sys
config_path, plugin_path = sys.argv[1:]
base_dir = posixpath.dirname(config_path)
print(posixpath.normpath(plugin_path if plugin_path.startswith("/") else
                         posixpath.join(base_dir, plugin_path)))
PYTHON
)
      [[ "$plugin_container_path" == /* ]] || { echo 'resolved PodSecurity plugin path is not absolute' >&2; return 2; }
      plugin_host_path=$(resolve_apiserver_host_path "$plugin_container_path" "$apiserver_json")
      printf '%s\n' "$plugin_path -> $plugin_container_path -> $plugin_host_path" \
        > "$UPGRADE_EVIDENCE/$phase/podsecurity-config-path.txt"
      sudo cat -- "$plugin_host_path" \
        > "$UPGRADE_EVIDENCE/$phase/podsecurity-config.yaml"
    else
      printf '%s\n' "$plugin_kind" > "$UPGRADE_EVIDENCE/$phase/podsecurity-config-path.txt"
    fi
    python3 - "$UPGRADE_EVIDENCE/$phase/pss-plugin-reference.json" \
      "$UPGRADE_EVIDENCE/$phase/podsecurity-config.yaml" \
      "$UPGRADE_EVIDENCE/$phase/pss-effective-config.json" <<'PYTHON'
import json, os, sys, yaml
reference_path, nested_path, output_path = sys.argv[1:]
reference = json.load(open(reference_path))
kind = reference["kind"]
if kind == "embedded":
    config = reference["configuration"] or {}
elif kind == "path":
    config = yaml.safe_load(open(nested_path)) or {}
elif kind == "default":
    config = {}
else:
    raise SystemExit(f"unknown PodSecurity config source: {kind}")
defaults = config.get("defaults", {}) or {}
exemptions = config.get("exemptions", {}) or {}
if not isinstance(defaults, dict) or not isinstance(exemptions, dict):
    raise SystemExit("PodSecurity defaults/exemptions must be mappings")
def normalized_exemption(name):
    values = exemptions.get(name, []) or []
    if not isinstance(values, list) or not all(isinstance(value, str) for value in values):
        raise SystemExit(f"PodSecurity exemptions.{name} must be a list of strings")
    return sorted(values)
effective = {
    "source": kind,
    "defaults": {
        "enforce": defaults.get("enforce", "privileged"),
        "enforce-version": defaults.get("enforce-version", "latest"),
        "audit": defaults.get("audit", "privileged"),
        "audit-version": defaults.get("audit-version", "latest"),
        "warn": defaults.get("warn", "privileged"),
        "warn-version": defaults.get("warn-version", "latest"),
    },
    "exemptions": {
        "usernames": normalized_exemption("usernames"),
        "runtimeClasses": normalized_exemption("runtimeClasses"),
        "namespaces": normalized_exemption("namespaces"),
    },
}
json.dump(effective, open(output_path, "w"), sort_keys=True)
PYTHON
  fi
  sha256sum "$UPGRADE_EVIDENCE/$phase/admission-control-config.yaml" \
    > "$UPGRADE_EVIDENCE/$phase/admission-control-config.sha256"
  [[ -f "$UPGRADE_EVIDENCE/$phase/podsecurity-config.yaml" ]] && \
    sha256sum "$UPGRADE_EVIDENCE/$phase/podsecurity-config.yaml" \
      > "$UPGRADE_EVIDENCE/$phase/podsecurity-config.sha256" || true
  python3 - "$UPGRADE_EVIDENCE/$phase/namespaces.json" \
    "$UPGRADE_EVIDENCE/$phase/pss-effective-config.json" \
    "$UPGRADE_EVIDENCE/$phase/pss-effective.json" <<'PYTHON'
import json, sys
namespaces = json.load(open(sys.argv[1]))
config = json.load(open(sys.argv[2]))
defaults = config["defaults"]
items = []
for item in namespaces.get("items", []):
    labels = item.get("metadata", {}).get("labels", {})
    level = labels.get("pod-security.kubernetes.io/enforce") or defaults["enforce"]
    version = labels.get("pod-security.kubernetes.io/enforce-version")
    if not version:
        version = "latest" if labels.get("pod-security.kubernetes.io/enforce") else defaults["enforce-version"]
    items.append({"namespace": item["metadata"]["name"], "enforce": level,
                  "enforceVersion": version,
                  "source": "namespace-label" if labels.get("pod-security.kubernetes.io/enforce") else "cluster-default"})
json.dump(sorted(items, key=lambda entry: entry["namespace"]), open(sys.argv[3], "w"), sort_keys=True)
PYTHON
}
capture_admission_control_config before "$BEFORE_APISERVER_JSON"
```

`grep` завершается кодом `1`, если ни одна строка не совпала; под `set -e` это без `|| true`
останавливает скрипт раньше собственной проверки. `|| true` сохраняет корректное поведение
для обоих исходов: список флагов может быть пустым (это отдельная находка) или непустым.

Если этот список пуст в вашем кластере - это отдельная находка: значит, audit/KMS/profiling
hardening ещё не применены, и сравнение после upgrade окажется тривиальным. В таком случае
сначала настройте нужные флаги (главы 07, 09, 32) и только после этого выполняйте upgrade
gate осмысленно.

### Контролируемая simulation и post-upgrade validation

Отметьте simulation, ещё раз выполните те же probes как если бы control plane и один
рабочий узел уже прошли rolling upgrade. Сравнение должно показать неизменившийся security
posture; health обязан быть успешным. Node gate ниже возвращает ненулевой код, если у любой
ноды condition `Ready=False` (а также если condition `Ready=True` отсутствует). При реальном
upgrade между блоками выполняются
`kubeadm upgrade apply` для первого control plane и `kubeadm upgrade node` для остальных
узлов в порядке из 13.4.

```bash
set -euo pipefail
printf 'mode=controlled-simulation\nserver_minor=%s\ntarget_minor=%s\n' \
  "$SERVER_MINOR" "$((SERVER_MINOR + 1))" > "$UPGRADE_EVIDENCE/simulation.txt"

kubectl get --raw='/readyz?verbose' > "$UPGRADE_EVIDENCE/after/readyz.txt"
kubectl get nodes -o wide > "$UPGRADE_EVIDENCE/after/nodes.txt"
kubectl get ns -o json > "$UPGRADE_EVIDENCE/after/namespaces.json"
kubectl get clusterrole,clusterrolebinding -o yaml > "$UPGRADE_EVIDENCE/after/rbac.yaml"
snapshot_admission_resources after
kubectl auth can-i --list --as=system:serviceaccount:default:default \
  > "$UPGRADE_EVIDENCE/after/default-sa-can-i.txt"

# Та же control-plane нода, что и в блоке before. Сначала требуем ровно один Ready
# kube-apiserver; только затем извлекаем argv, чтобы пустой список не стал false-PASS.
AFTER_APISERVER_JSON="$(
  kubectl -n kube-system get pods -l component=kube-apiserver \
    --field-selector "spec.nodeName=${CONTROL_PLANE_NODE}" \
    -o json
)"
printf '%s\n' "$AFTER_APISERVER_JSON" | jq -e '
  (.items | length) == 1 and
  any(.items[0].status.conditions[]?;
      .type == "Ready" and .status == "True")
' > "$UPGRADE_EVIDENCE/after/apiserver-node-gate.txt"
printf '%s\n' "$AFTER_APISERVER_JSON" \
  | jq -r '.items[0].spec.containers[0].command[]?' \
  | sort > "$UPGRADE_EVIDENCE/after/apiserver-flags.txt"
grep -E '^--(audit-policy-file|audit-log-path|encryption-provider-config|profiling)' \
  "$UPGRADE_EVIDENCE/after/apiserver-flags.txt" \
  > "$UPGRADE_EVIDENCE/after/apiserver-security-flags.txt" || true
capture_admission_control_config after "$AFTER_APISERVER_JSON"

grep -q 'readyz check passed' "$UPGRADE_EVIDENCE/after/readyz.txt"
# Любое Ready=False (или отсутствие Ready=True) даёт jq exit code 1 и останавливает gate.
kubectl get nodes -o json | jq -e '
  [ .items[]
    | {name: .metadata.name,
       ready: [.status.conditions[]? | select(.type == "Ready") | .status]}
    | select((.ready | index("False")) != null or
             (.ready | index("True")) == null)
  ] | length == 0
' > "$UPGRADE_EVIDENCE/after/nodes-ready-gate.txt"

# Глобальные snapshots — evidence для обязательного review, а не автоматическое
# доказательство неизменной security posture. Kubernetes auto-reconciles только default
# ClusterRole/ClusterRoleBinding с label kubernetes.io/bootstrapping=rbac-defaults;
# это правило не переносится на произвольные admission objects. Новый minor-релиз может
# легитимно изменить default RBAC, а обычный YAML diff не умеет универсально определить,
# стало ли custom RBAC/admission слабее. Переход marker `NOT_SERVED` -> served
# MutatingAdmissionPolicy/Binding — ожидаемое platform change, но objects после перехода
# всё равно входят в admission.diff и требуют обычного review.
diff -u "$UPGRADE_EVIDENCE/before/rbac.yaml" \
  "$UPGRADE_EVIDENCE/after/rbac.yaml" \
  > "$UPGRADE_EVIDENCE/after/rbac.diff" || true
diff -u "$UPGRADE_EVIDENCE/before/admission.yaml" \
  "$UPGRADE_EVIDENCE/after/admission.yaml" \
  > "$UPGRADE_EVIDENCE/after/admission.diff" || true
diff -u "$UPGRADE_EVIDENCE/before/default-sa-can-i.txt" \
  "$UPGRADE_EVIDENCE/after/default-sa-can-i.txt" \
  > "$UPGRADE_EVIDENCE/after/default-sa-can-i.diff" || true

# Если вашей policy нужен exact diff по custom RBAC, сначала исключите
# auto-reconciled bootstrap-defaults и runtime-metadata, а не сравнивайте весь
# global snapshot целиком:
#
# kubectl get clusterrole,clusterrolebinding -o json | jq -S '
#   { items: [ .items[]
#       | select((.metadata.labels["kubernetes.io/bootstrapping"] // "") != "rbac-defaults")
#       | del(.metadata.creationTimestamp, .metadata.generation,
#             .metadata.managedFields, .metadata.resourceVersion,
#             .metadata.uid, .status) ] }
# ' > "$UPGRADE_EVIDENCE/before/custom-rbac.json"
#
# и сравнивать такой же after/custom-rbac.json согласно policy проекта.
#
# До принятия gate обязательно просмотрите rbac.diff, admission.diff и targeted
# authorization evidence; подтвердите сохранность security-critical custom
# Roles/Bindings, отсутствие новых запрещённых permissions у выбранных identities и
# требуемые validating/mutating webhooks, admission policies, selectors, rules и failure
# behavior. Зафиксируйте результат review в change record. Если нужен fully automatic
# gate, замените общий diff явными project-specific invariants для этих объектов.

# Gate: любой security-флаг, присутствовавший до upgrade, обязан остаться после него.
# Пустой diff -u не обязателен (после upgrade список может стать шире), но exit code
# comm -23 (строки только в before) обязан быть нулевой длины.
missing_flags=$(comm -23 "$UPGRADE_EVIDENCE/before/apiserver-security-flags.txt" \
  "$UPGRADE_EVIDENCE/after/apiserver-security-flags.txt")
if [[ -n "$missing_flags" ]]; then
  echo "ERROR: security flags disappeared after upgrade:" >&2
  printf '%s\n' "$missing_flags" >&2
  exit 1
fi

# Raw AdmissionConfiguration remains review evidence, but effective PodSecurity defaults
# and normalized exemptions are the authoritative security gate. A change must never PASS.
diff -u "$UPGRADE_EVIDENCE/before/admission-control-config.yaml" \
  "$UPGRADE_EVIDENCE/after/admission-control-config.yaml" \
  > "$UPGRADE_EVIDENCE/after/admission-control-config.diff" || true
diff -u "$UPGRADE_EVIDENCE/before/pss-effective-config.json" \
  "$UPGRADE_EVIDENCE/after/pss-effective-config.json" \
  > "$UPGRADE_EVIDENCE/after/pss-effective-config.diff" || true
if ! cmp -s "$UPGRADE_EVIDENCE/before/pss-effective-config.json" \
  "$UPGRADE_EVIDENCE/after/pss-effective-config.json"; then
  echo 'ERROR: effective PodSecurity configuration changed; review defaults/exemptions' >&2
  exit 1
fi

# Effective PSS combines namespace labels with PodSecurityConfiguration defaults. A missing
# namespace *-version means latest; latest after a minor upgrade is always REVIEW_REQUIRED.
# The enforcement level is monotonic (privileged < baseline < restricted), but version is not
# an ordinal measure of strictness.
jq -e --slurpfile before "$UPGRADE_EVIDENCE/before/pss-effective.json" '
  def enforce_level:
    if . == "restricted" then 2 elif . == "baseline" then 1 else 0 end;
  $before[0] as $previous |
  [ $previous[] as $before_ns
    | ([.[] | select(.namespace == $before_ns.namespace)] | .[0]) as $after_ns
    | select($after_ns != null)
    | select(($after_ns.enforce | enforce_level) < ($before_ns.enforce | enforce_level))
    | {namespace: $before_ns.namespace, before: $before_ns, after: $after_ns}
  ] as $weaker |
  [ $previous[] as $before_ns
    | ([.[] | select(.namespace == $before_ns.namespace)] | .[0]) as $after_ns
    | select($after_ns != null)
    | select($before_ns.enforceVersion != $after_ns.enforceVersion or
             $before_ns.enforceVersion == "latest" or $after_ns.enforceVersion == "latest")
    | {namespace: $before_ns.namespace, before: $before_ns, after: $after_ns,
       action: "review effective PSS controls for source and target Kubernetes versions"}
  ] as $version_review |
  if ($weaker | length) > 0 then
    error("PSS enforce level was weakened: " + ($weaker | tojson))
  else
    {status: (if ($version_review | length) == 0 then "OK" else "REVIEW_REQUIRED" end),
     version_review: $version_review}
  end
' "$UPGRADE_EVIDENCE/after/pss-effective.json"   | tee "$UPGRADE_EVIDENCE/after/pss-gate.txt"

# Succeeded Pods завершённых Job не являются health failure; Running Pod обязан иметь Ready=True.
kubectl get pods -A -o json | jq -e '
  [ .items[]
    | select(
        .status.phase == "Failed" or
        .status.phase == "Pending" or
        .status.phase == "Unknown" or
        (.status.phase == "Running" and
          (any(.status.conditions[]?; .type == "Ready" and .status == "True") | not))
      )
  ] | length == 0
'
```

Simulation считается принятой, если skew check успешен, `kubeadm upgrade plan` сохранён,
snapshot валиден, deprecated API inventory разобран, `/readyz` успешен, все узлы `Ready`,
cluster-wide PSS configuration (включая defaults/exemptions) не изменилась, PSS `enforce`
не ослаблен, а каждое изменение effective PSS version (включая `latest`) прошло отдельный
review. RBAC/admission считаются проверенными только после обязательного
review сохранённых diff и targeted policy evidence либо после успешного project-specific
automated gate; сам факт создания `*.diff` этого не доказывает. Ни один security-флаг
apiserver (audit, encryption provider, profiling) не должен исчезнуть из static Pod manifest
после upgrade. Для реального upgrade дополнительно приложите точные версии до/после и smoke
test критической рабочей нагрузки.

## 13.12. Вопросы для самопроверки

<details>
<summary>1. Почему CVE в kubelet или `runc` может быть критичным, даже если API server не доступен
   из интернета?</summary>

Kubelet может быть достижим атакующему уже из скомпрометированного Pod или соседней ноды, а уязвимость `runc` может эксплуатироваться из уже запущенного контейнера. Поэтому отсутствие публичного API не устраняет внутренние prerequisite атаки. Приоритет определяют по доступности уязвимой функции, требуемым правам, exploit и ценности ноды, а не только по внешней экспозиции.
</details>

<details>
<summary>2. Чем EOL-ветка отличается от поддерживаемой ветки с точки зрения следующего CVE?</summary>

Для поддерживаемой ветки upstream или поставщик выпускает исправленный patch в рамках support policy. Для EOL-ветки следующая уязвимость может остаться без нового security patch вообще. Компенсирующие controls не делают EOL-версию поддерживаемой, поэтому нужен переход на поддерживаемую minor-ветку или явно ограниченная поддержка поставщика.
</details>

<details>
<summary>3. Какие ветки обычно входят в upstream support window `N`/`N-1`/`N-2`, и что означает
   `N-3`?</summary>

Upstream Kubernetes обычно поддерживает текущую minor-ветку `N` и две предыдущие: `N-1` и `N-2`. `N-3` обычно уже EOL и не получает новых upstream security patches. Реальное окно managed-сервиса или enterprise-дистрибутива может отличаться, поэтому его сверяют отдельно.
</details>

<details>
<summary>4. Почему CVSS и CVE feed недостаточны для решения о срочности обновления?</summary>

CVSS не описывает конкретную экспозицию кластера: нужны prerequisites, достижимость функции, доступ атакующего, public exploit и компенсирующие controls. CVE feed полезен для уведомления, но может отставать или не содержать точных диапазонов и условий. Решение опирается на первичный vendor/upstream advisory, fixed version, inventory и support policy.
</details>

<details>
<summary>5. Почему control plane обновляют раньше рабочих узлов, почему kubelet не должен быть новее
   API server и не может отставать от него более чем на три minor-версии?</summary>

Version skew требует, чтобы kubelet был не новее kube-apiserver и не более чем на три minor-версии старше него, поэтому сначала поднимают control plane. В HA старый API server также ограничивает допустимую верхнюю версию kubelet, пока он остаётся в кластере. Такой skew допустим только на время rolling upgrade, а не как постоянное состояние.
</details>

<details>
<summary>6. Назовите безопасную последовательность обновления рабочего узла через `kubeadm`.</summary>

После healthy control plane на worker обновляют `kubeadm`, выполняют `kubeadm upgrade node`, затем с административной машины делают `cordon` и `drain` с учётом PDB и capacity. После этого устанавливают target `kubelet` и `kubectl`, перезапускают kubelet, проверяют Ready, версию и workload smoke test. Только затем выполняют `uncordon` и переходят к следующей ноде.
</details>

<details>
<summary>7. Какие проверки нужны после успешного `kubeadm upgrade`, чтобы доказать и security patch,
   и работоспособность кластера?</summary>

Проверяют фактические версии control plane и kubelet через `kubectl version --output=yaml` и `kubectl get nodes -o wide`, а не только exit code `kubeadm`. Health подтверждают `/readyz?verbose`, состоянием всех Node `Ready`, `kube-system`, критичных DaemonSet/Deployment, событий и smoke test workload. Дополнительно проверяют alerts и отсутствие проблем runtime, CNI, DNS и storage.
</details>

<details>
<summary>8. Почему обновление Kubernetes не закрывает автоматически CVE в `containerd`, `runc` или
   kernel, и как их обновлять безопасно?</summary>

Пакеты Kubernetes не обновляют независимые runtime, kernel и пакеты ОС, хотя именно они часто являются границей между контейнером и нодой. Их версии и compatibility с Kubernetes сверяют по vendor advisory, inventory и node image. Rollout выполняют тем же контролируемым lifecycle: stage, затем node-by-node `cordon`/`drain`, patch или reboot/replacement, health check и `uncordon`.
</details>

<details>
<summary>9. **Flashback (глава 26).** Version skew (эта глава) и image digest pinning (глава 26) -
   оба механизма про то, что "какая именно версия сейчас работает" должно быть проверяемым
   фактом, а не предположением. В чём разница между "версия compatible" (version skew) и
   "версия identical" (digest), и почему для kubelet/API server достаточно первого, а для
   container image в production - обязательно второе?</summary>

Version skew задаёт допустимое отношение minor-версий взаимодействующих компонентов: kubelet и API server могут быть разными, но совместимыми в указанном диапазоне. Digest, напротив, идентифицирует конкретные неизменные байты образа; tag не даёт такой гарантии. Для rolling lifecycle Kubernetes нужна ограниченная совместимость версий, а production image должен быть воспроизводимо закреплён за точным содержимым.
</details>

## Дополнительная практика

Упражнение 13.11 полностью покрывает CKS-oriented security gates без внешнего материала.
В главе 14 перейдём к минимизации поверхности узла и безопасности runtime-демона.

🧪 Лаба 113 (upgrade control-plane и worker через `kubeadm`, evidence отсутствия downtime): [tasks/cks/labs/113](../../labs/113/README_RU.MD)

🎮 Killercoda (в браузере, без установки): [Upgrading Kubernetes](https://killercoda.com/chadmcrowell/course/cka/upgrade-k8s) · [Upgrade Kubelet](https://killercoda.com/chadmcrowell/course/cka/upgrade-kubelet)

## Смешанный чек-поинт: Cluster Hardening завершён

Прежде чем перейти к System Hardening, проверьте 15-20 минут без подсказок, что домен
Cluster Hardening (главы 10-13) закрепился:

1. Создайте узкую Role/RoleBinding для тестового subject и покажите двумя `can-i`
   проверками, что разрешён `get pods`, но запрещён `delete pods` (глава 10).
2. Отключите `automount` у `default` ServiceAccount в тестовом namespace и докажите, что
   новый Pod без явного SA не получает token-файл (глава 11).
3. Проверьте, включён ли anonymous access на API server, и объясните разницу между `401`
   и `403` в ответе (глава 12).
4. **Смешанное задание.** Возьмите NetworkPolicy default-deny (глава 04, домен Cluster
   Setup) и RBAC default-deny (глава 10, этот домен): объясните, почему отсутствие явного
   правила в обоих случаях означает запрет, а не разрешение, и в чём разница между тем, кто
   принимает это решение (API server RBAC authorizer vs CNI plugin).
5. Назовите безопасную последовательность обновления control plane через `kubeadm` и
   объясните, почему kubelet не должен быть новее API server (глава 13).

Если задание 4 вызвало затруднение - вернитесь к главам 04 и 10 вместе.

---
[Оглавление](../README_RU.md) · [Глава 12](../12/ru.md) · [Глава 14](../14/ru.md)
