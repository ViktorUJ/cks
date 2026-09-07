# Лаба 113 - Upgrade кластера Kubernetes через kubeadm (minor upgrade)

## Цель

В этой CKS-лабе вы выполните реальный minor-upgrade самостоятельно управляемого
кластера через `kubeadm`: сначала control-plane, затем worker-узел, в правильном
порядке и без незапланированного downtime уже работающей нагрузки. Кластер стартует
на Kubernetes `1.35.x`; ваша задача - перевести оба узла на `1.36.x`, соблюдая
официальную процедуру `kubeadm upgrade` и переключение пакетного репозитория
`pkgs.k8s.io` на новый minor.

## Проверьте себя перед стартом

<details>
<summary>1. Почему `kubeadm upgrade` требует upgrade control-plane СТРОГО перед worker-узлами, а не в любом порядке?</summary>

`kubeadm upgrade apply` на control-plane обновляет версию API server и other control-plane компонентов, а также version skew policy кластера. Worker-нода со слишком новым kubelet относительно API server может нарушить поддерживаемый skew (kubelet не должен быть новее kube-apiserver). Обновление control-plane первым гарантирует, что API server уже на целевой версии, когда worker переходит на неё же - это не произвольная рекомендация, а требование version skew policy Kubernetes.
</details>

<details>
<summary>2. Почему переключение apt-репозитория `pkgs.k8s.io` обязательно при переходе на новый minor, хотя patch-обновления работают без этого?</summary>

Начиная с миграции с `packages.cloud.google.com`/`apt.kubernetes.io`, `pkgs.k8s.io` организован как **отдельный репозиторий на каждую minor-версию** (`core:/stable:/v1.35`, `core:/stable:/v1.36` и т.д.), а не единый репозиторий со всеми версиями. Внутри уже подключённого repo `v1.35` доступны только `1.35.x` patch-релизы. Чтобы `apt install kubeadm=1.36.x-*` увидел версии `1.36`, нужно сначала подключить (`sources.list.d/kubernetes.list`) и подписать (`Release.key`) repo именно `core:/stable:/v1.36`.
</details>

<details>
<summary>3. Почему `kubectl drain` перед upgrade кластера - не просто "хорошая практика", а конкретная защита от чего?</summary>

`kubeadm upgrade` на control-plane пересоздаёт static Pod-манифесты компонентов (kube-apiserver, controller-manager, scheduler), а на любом узле upgrade kubelet требует его restart - в этот момент узел временно теряет способность корректно репортить статус Pod'ов и принимать новые. `drain` заранее переселяет обычные workload-Pod'ы на другие узлы (или помечает их evicted), чтобы этот временный провал узла не превратился в downtime приложения. Без `drain` Pod'ы на обновляемом узле могут оказаться недоступны на время restart без компенсирующего переезда на другой узел.
</details>

## Связь с курсом

- [Глава 13. Обновление Kubernetes для устранения уязвимостей](../../course/13/ru.md)

## Инфраструктура

Terragrunt создаёт self-managed Kubernetes `1.35.4` в `eu-central-1`, containerd,
Calico CNI:

| Компонент | Назначение |
|---|---|
| `k8s-1` control-plane | обычная control-plane нода, допускающая обычные Pod (single control-plane, без выделенного второго control-plane узла) |
| `k8s-1` worker `worker1` | обычный worker-узел на той же стартовой версии |
| `worker` | рабочая машина с `kubectl`, `check_result` и SSH-доступом к обоим узлам кластера |

Целевая версия upgrade - `1.36.x` (последний доступный patch на момент лабы), то есть
после выполнения заданий кластер окажется на той же training baseline версии, что и
остальные core labs 101-112. Skip minor-версий (например прямой переход `1.35` → `1.37`)
kubeadm не поддерживает - в этой лабе такой переход и не требуется.

Для доступа к узлам используйте алиасы `k8s113_controlPlane_1` и `k8s113_node_worker1`.

Namespace `upgrade-113` с Deployment `canary` (2 реплики) уже развёрнут - это ваш
индикатор отсутствия downtime: обе реплики должны остаться `Available` на протяжении
всего upgrade.

## Развёртывание

```bash
TASK=113 make run_cks_task
```

Подключитесь к рабочей машине и выберите готовый контекст:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Создайте каталог доказательств до начала работы:

```bash
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## Задания

---
| **1** | **Upgrade control-plane до целевого minor** |
| :---: | :--- |
| Что делаем | На `k8s113_controlPlane_1` переключите apt-репозиторий `pkgs.k8s.io` с `core:/stable:/v1.35` на `core:/stable:/v1.36` (новый keyring и `sources.list.d/kubernetes.list`). Обновите пакет `kubeadm` до `1.36.x`, выполните `kubeadm upgrade plan`, затем `kubeadm upgrade apply v1.36.x`. Только после успешного `apply` выполните `kubectl drain` этого узла, обновите пакеты `kubelet`/`kubectl` до `1.36.x`, перезапустите `kubelet`, затем `kubectl uncordon`. |
| Критерии приёмки | `kubeadm version`, `kubelet --version` и версия API server (`kubectl version`) на control-plane сообщают `v1.36.x`. Узел `k8s113_controlPlane_1` в статусе `Ready`. Полный вывод команды `kubeadm upgrade apply` (со строкой `SUCCESS` и целевой версией) сохранён буквально в `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt`. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

Порядок принципиален: сначала `apt-mark unhold kubeadm` → обновить пакет → `apt-mark hold kubeadm` → `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z`, и только ПОСЛЕ успешного `apply` - `drain` и обновление `kubelet`/`kubectl`. Обновлять `kubelet` до вызова `kubeadm upgrade apply` не нужно и не рекомендуется официальной процедурой. Сохраните вывод `kubeadm upgrade apply` через `tee`, а не восстанавливайте его по памяти после - тест ищет буквальный текст со словом `SUCCESS`.
</details>

---
| **2** | **Upgrade worker-узла до целевого minor** |
| :---: | :--- |
| Что делаем | На `k8s113_node_worker1` аналогично переключите `pkgs.k8s.io` на `core:/stable:/v1.36`, обновите `kubeadm`, выполните `kubeadm upgrade node` (не `apply` - это команда только для control-plane). Затем `kubectl drain` этого узла (с рабочей машины, не с самого узла), обновите `kubelet`/`kubectl`, перезапустите `kubelet`, `kubectl uncordon`. |
| Критерии приёмки | `kubeadm version` и `kubelet --version` на worker-узле сообщают `v1.36.x`; `kubectl get node k8s113_node_worker1` показывает `v1.36.x` в `kubeletVersion` и статус `Ready`. Вывод `kubeadm upgrade node` сохранён в `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt`. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

`kubeadm upgrade node` - именно та команда для worker-узлов (и для дополнительных control-plane узлов), `kubeadm upgrade apply` предназначена только для ПЕРВОГО/единственного control-plane узла. Начинайте это задание только после того, как задание 1 полностью завершено и control-plane уже `Ready` на `1.36.x` - иначе вы нарушите version skew policy.
</details>

---
| **3** | **Соблюсти правильный порядок upgrade** |
| :---: | :--- |
| Что делаем | Убедитесь, что вы выполнили upgrade control-plane (задание 1) полностью, включая uncordon, ДО того как начали upgrade worker-узла (задание 2). Никакого отдельного действия в кластере это задание не требует - оно проверяется по фактическому времени создания evidence-файлов из заданий 1 и 2. |
| Критерии приёмки | Файл `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt` создан не позже, чем `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt` (по времени модификации). |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Если вы уже начали (или тем более закончили) upgrade worker-узла до control-plane - остановитесь, откатите worker обратно на скачивание пакетов `1.35.x` невозможно простым способом, но правильный путь - завершить upgrade control-plane, затем продолжить/повторить upgrade worker-узла. Главное - следующий upgrade worker-узла (когда бы он ни был начат) должен произойти позже полностью завершённого upgrade control-plane.
</details>

---
| **4** | **Доказать отсутствие downtime у существующей нагрузки** |
| :---: | :--- |
| Что делаем | Пока выполняете задания 1-2, параллельно (в отдельной сессии на рабочей машине) запустите цикл, опрашивающий доступность Deployment `canary` в namespace `upgrade-113` каждые несколько секунд, и допишите каждую строку опроса в `/var/work/tests/artifacts/4/canary-availability.log` в формате, содержащем `available=N` (например `available=2`). Продолжайте опрос на протяжении всего upgrade обоих узлов. |
| Критерии приёмки | Deployment `canary` в конце имеет `2/2` доступных реплик. Файл `/var/work/tests/artifacts/4/canary-availability.log` не пуст и содержит минимум одну строку `available=N`, где минимальное встретившееся значение `N` за весь лог - не меньше `1` (то есть Deployment никогда не терял все реплики одновременно). |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Пример цикла опроса, который можно оставить работать в отдельном терминале/`screen`/`tmux` на всё время выполнения заданий 1-2: `while true; do echo "$(date +%s) available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}')" >> /var/work/tests/artifacts/4/canary-availability.log; sleep 5; done`. Если Deployment на короткое время терял все реплики - скорее всего оба Pod'а оказались на одном и том же узле без anti-affinity, и `drain` этого узла разом убрал оба; проверьте распределение `kubectl get pods -n upgrade-113 -o wide` и, если нужно, перераспределите реплики перед повторной попыткой.
</details>

## Проверка

```bash
check_result
```

Проверка содержит `0 Init` и пять обязательных тестов. Тесты 1-2 проверяют версии
`kubeadm`/`kubelet`/`kubectl` и статус `Ready` на control-plane и worker-узле
соответственно, а также буквальный evidence-файл с выводом `kubeadm upgrade`. Тест 3
проверяет порядок upgrade по времени модификации evidence-файлов. Тест 4 проверяет,
что нагрузка `canary` не имела простоя. Тест 5 - финальная проверка, что оба узла
действительно на целевой версии и не оставлены в состоянии `cordon`.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=113 make delete_cks_task
```
