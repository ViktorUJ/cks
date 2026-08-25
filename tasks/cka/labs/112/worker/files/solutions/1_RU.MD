[Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Лаба 112 — эталонное решение (etcd: снапшоты и восстановление)

Все действия с etcd — на control plane ноде (`ssh k8s1_controlPlane_1`, `sudo -i`).
`etcdctl` уже установлен; сертификаты — в `/etc/kubernetes/pki/etcd/`.

Удобно один раз задать общие параметры подключения к etcd:

```bash
# на control plane, под root
export ETCDCTL_API=3
export EP="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"
```

## Задание 1. Снять снапшот S1 (базовое состояние) и скопировать на worker

```bash
# на control plane
etcdctl $EP snapshot save /root/etcd-snapshot-1.db
etcdctl snapshot status /root/etcd-snapshot-1.db --write-out=table
```

Скопировать снапшот на рабочую машину (для проверки):

```bash
# с worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-1.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-1.db
```

(если `scp` не берёт файл из `/root`, на control plane скопируйте его в `/tmp` и
дайте права: `cp /root/etcd-snapshot-1.db /tmp/ && chmod 644 /tmp/etcd-snapshot-1.db`,
затем `scp` из `/tmp`.)

## Задание 2. Внести изменения в кластер

Создаём «маркер-ресурсы» — по ним потом увидим разницу между снапшотами. Команды
запускаются на рабочей машине (там настроен `kubectl`).

```bash
# на worker PC
kubectl create namespace snapshot-demo
kubectl -n snapshot-demo create configmap demo-config --from-literal=app=v1
kubectl -n snapshot-demo create deployment demo-web \
  --image=viktoruj/ping_pong --replicas=2

kubectl get ns snapshot-demo
kubectl -n snapshot-demo get cm,deploy
```

## Задание 3. Снять снапшот S2 (после изменений)

```bash
# на control plane
etcdctl $EP snapshot save /root/etcd-snapshot-2.db
etcdctl snapshot status /root/etcd-snapshot-2.db --write-out=table
```

```bash
# с worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-2.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-2.db
```

Разница: `etcd-snapshot-1.db` снят **до** создания `snapshot-demo`, а `etcd-snapshot-2.db`
— **после**. То есть S2 содержит namespace `snapshot-demo` и его ресурсы, а S1 — нет.

## Задание 4. Восстановить S1 и убедиться, что лишних ресурсов нет

Восстанавливаем самый первый снапшот — кластер должен вернуться в состояние **до**
создания `snapshot-demo`.

Порядок восстановления (метод «остановить статик-поды → восстановить в `/var/lib/etcd`
→ поднять статик-поды»):

```bash
# на control plane, под root
# 1. посмотреть имя ноды и адреса из текущего манифеста etcd — понадобятся при restore
grep -E -- '--name=|--initial-cluster=|--initial-advertise-peer-urls=' \
  /etc/kubernetes/manifests/etcd.yaml
# пример вывода:
#   - --name=ip-10-10-1-17
#   - --initial-advertise-peer-urls=https://10.10.1.17:2380
#   - --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380

# 2. остановить все статик-поды control plane (kubelet погасит их контейнеры)
mkdir -p /etc/kubernetes/manifests-stopped
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
# дождаться, пока контейнеры etcd/apiserver исчезнут
crictl ps

# 3. убрать текущие данные и восстановить снапшот S1 в /var/lib/etcd
mv /var/lib/etcd /var/lib/etcd.bak
etcdctl snapshot restore /root/etcd-snapshot-1.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

# 4. вернуть манифесты — kubelet поднимет control plane на восстановленных данных
mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

> **Важно про `--name` (etcd 3.6+).** При restore нужно указывать `--name`,
> `--initial-cluster` и `--initial-advertise-peer-urls` **ровно теми же**, что в манифесте
> etcd. Иначе восстановленный member не совпадёт с тем, с которым стартует статик-под, и
> etcd упадёт с паникой `member unknown`. Значения берём из шага 1.

Проверяем, что кластер поднялся и `snapshot-demo` **пропал**:

```bash
# с worker PC (подождать ~1 минуту, пока поднимется API)
kubectl get --raw='/healthz'          # ok
kubectl get ns snapshot-demo          # NotFound — лишних ресурсов нет
kubectl get pods -n kube-system
```

## Задание 5. Восстановить кластер из S2

Теперь восстанавливаем второй снапшот — `snapshot-demo` и его ресурсы должны вернуться.
Процедура та же, снапшот — `/root/etcd-snapshot-2.db`.

```bash
# на control plane, под root
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
crictl ps                                    # дождаться остановки контейнеров

rm -rf /var/lib/etcd
etcdctl snapshot restore /root/etcd-snapshot-2.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

Проверяем, что кластер здоров и `snapshot-demo` **вернулся**:

```bash
# с worker PC
kubectl get --raw='/healthz'                 # ok
kubectl get ns snapshot-demo                 # Active
kubectl -n snapshot-demo get cm,deploy       # demo-config и demo-web на месте
kubectl get pods -n kube-system
```

Итог: снапшот — это полный слепок состояния кластера на момент снятия. Восстановление
из S1 откатывает кластер к «пустому» состоянию, из S2 — возвращает созданные ресурсы.
