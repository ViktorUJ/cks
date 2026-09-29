[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 103 - эталонное решение

> Команды выполняются на worker, если явно не указан `control-plane`. Перед правкой
> static Pod manifests сохраните копии. Kubelet сам заметит изменение файлов и пересоздаст
> соответствующие static Pods; не удаляйте их через Kubernetes API.
>
> На экзамене `k` (`alias k=kubectl`) и bash-completion для него уже настроены на SSH-хосте -
> не тратьте время на их настройку, просто используйте `k` (см. главу 33.6).

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
k config use-context "$CTX"
ssh control-plane hostname
```

## Задание 1. Отчёт kube-bench

`kube-bench` `0.16.0` уже установлен на `control-plane` (как и на реальном экзамене, где
CIS Benchmark tooling на нодах уже есть) - копировать его туда с worker не нужно. Kubernetes
`1.36` пока отсутствует в официальной support table kube-bench; встроенный version mapping
этой версии заканчивается записью `"1.34": "cis-1.12"` - более новых профилей (включая
какой-либо профиль под 1.35/1.36) в `0.16.0` нет вовсе, поэтому используем именно `cis-1.12`
как ближайший существующий. Поэтому мы запускаем его принудительно как approximate
hardening signal, а не как authoritative CIS compliance assessment.

```bash
mkdir -p /var/work/tests/artifacts/1
{
  printf 'kubernetes_version=%s\n' "$(k version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-1.12\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,node,controlplane,etcd,policies'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

grep '== Summary' /var/work/tests/artifacts/1/kube-bench.txt
# == Summary master ==
# == Summary node ==
# == Summary controlplane ==
# == Summary etcd ==
# == Summary policies ==
```

Глазами убедитесь, что все пять `== Summary <target> ==` присутствуют - без явного
`--targets` часть из них (`etcd`, `policies`) в отчёт не попадёт.

## Задание 2. Hardening kubelet

Не вспоминайте имена полей по памяти - на экзамене быстрее достать их прямо из уже снятого
отчёта kube-bench (задание 1). У каждого check там есть секция `== Remediations <target> ==`
с готовым текстом исправления - `grep -A1` по номеру check сразу даёт нужное поле:

```bash
grep -A1 '^4.2.1 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.1 If using a Kubelet config file, edit the file to set `authentication: anonymous: enabled` to
# `false`.

grep '^4.2.4 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.4 If using a Kubelet config file, edit the file to set `readOnlyPort` to 0.
```

На control-plane kubelet читает `/var/lib/kubelet/config.yaml`. В YAML должны быть именно
следующие поля (не добавляйте одноимённые ключи второй раз):

```yaml
readOnlyPort: 0
authentication:
  anonymous:
    enabled: false
```

На экзамене не префиксите каждую команду `sudo` - один раз станьте root (`sudo -i`), это
быстрее:

```bash
ssh control-plane
sudo -i
cp /var/lib/kubelet/config.yaml ~/2-kubelet-config.yaml
vim /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet
exit   # выйти из root-шелла
exit   # выйти с control-plane
```

Проверяем не статический текст файла, а действующую конфигурацию, которую kubelet
реально применил - через API `configz` (текстовый парсинг YAML легко обмануть похожими
полями вроде `webhook.enabled`, а `configz` отражает то, что kubelet сам считает своей
конфигурацией):

```bash
NODE=$(k get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}')

k get --raw="/api/v1/nodes/${NODE}/proxy/configz" \
  | jq -e '
      (.kubeletconfig.readOnlyPort // 0) == 0 and
      .kubeletconfig.authentication.anonymous.enabled == false
    '

k wait --for=condition=Ready "node/${NODE}" --timeout=120s
```

## Задание 3. Отключить profiling kube-apiserver

Тот же приём, что в задании 2 - используйте отчёт kube-bench из задания 1 как источник
истины, не вспоминайте флаг по памяти:

```bash
grep -A2 '^1.2.15 ' /var/work/tests/artifacts/1/kube-bench.txt
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
```

Добавьте параметр в список `command` контейнера `kube-apiserver`.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/3-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# В массив command добавьте строку с тем же отступом, что у остальных аргументов:
# - --profiling=false
exit
exit

ssh control-plane "sudo grep -n -- '--profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
k get po -n kube-system -l component=kube-apiserver
# STATUS должен стать Running - если ещё нет, подождите пару секунд и повторите
```

## Задание 4. TLS Secret и Ingress

Создайте минимальное приложение и Service, сгенерируйте самоподписанный сертификат для
точного DNS-имени, затем создайте TLS Secret и Ingress. Controller `ingress-nginx` уже
установлен и Ready в этой лабе (lab-owned fixture, версия закреплена в bootstrap) - убедимся
в этом перед тем, как создавать Ingress.

Короткие имена ресурсов (`ns` = namespace, `deploy` = deployment, `svc` = service,
`ing` = ingress, `po` = pod) экономят набор текста под давлением времени.

```bash
k get ingressclass
k -n ingress-nginx get deploy ingress-nginx-controller
k -n ingress-nginx get endpoints ingress-nginx-controller

k create ns cks-103
k -n cks-103 create deploy secure-app --image=viktoruj/ping_pong:alpine
k -n cks-103 set env deploy/secure-app SERVER_NAME=secure-app SRV_PORT=80
k -n cks-103 expose deploy secure-app --name=secure-app --port=80 --target-port=80
k -n cks-103 wait --for=condition=Available deploy/secure-app --timeout=60s

mkdir -p /tmp/cks-103-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/cks-103-tls/tls.key \
  -out /tmp/cks-103-tls/tls.crt \
  -subj '/CN=secure.cks.local' \
  -addext 'subjectAltName=DNS:secure.cks.local'

k -n cks-103 create secret tls secure-ingress-tls \
  --cert=/tmp/cks-103-tls/tls.crt --key=/tmp/cks-103-tls/tls.key

cat <<'EOF' | k apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: cks-103
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.cks.local
    secretName: secure-ingress-tls
  rules:
  - host: secure.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port:
              number: 80
EOF

k get secret,ing -n cks-103
k get ing secure-ingress -n cks-103 -o yaml
```

Не останавливаемся на `k get ... -o yaml` - подтверждаем, что TLS Ingress реально
работает через настоящий controller. `secure.cks.local` уже резолвится в реальный node IP
(bootstrap добавил запись в `/etc/hosts`), а `ingress-nginx-controller` - Service типа
`NodePort`, открытый на каждой ноде, поэтому curl выполняется прямо с этой машины, без SSH
на кластер:

```bash
HTTPS_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -k "https://secure.cks.local:${HTTPS_NODEPORT}/"
# HTTPCODE 200, тело содержит "Server Name: secure-app"

HTTP_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
curl -v "http://secure.cks.local:${HTTP_NODEPORT}/"
# < HTTP/1.1 308 Permanent Redirect
# < Location: https://secure.cks.local
```

Этот HTTP→HTTPS редирект - реальный экзаменационный вопрос, не искусственное требование
лабы (см. mock-экзамен `tasks/cks/mock/04`, задание 4).

## Задание 5. TLS hardening kube-apiserver и etcd

Не ищите точное имя флага в документации - быстрее спросить сам бинарник изнутри уже
запущенного Pod'а (`--help` есть у любого компонента control plane) и отгрепать нужное:

```bash
k exec -n kube-system $(k get po -n kube-system -l component=kube-apiserver -o name) -- kube-apiserver --help | grep -i tls
# --tls-min-version string   Minimum TLS version supported. Possible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13
# --tls-cipher-suites strings   Comma-separated list of cipher suites for the server. Preferred values: TLS_AES_128_GCM_SHA256, ...

k exec -n kube-system $(k get po -n kube-system -l component=etcd -o name) -- etcd --help | grep -i cipher
# --cipher-suites ''   Comma-separated list of supported TLS cipher suites between client/server and peers
```

В обоих static Pod manifests добавьте параметры в `command`. На kube-apiserver задание требует
ОБА флага, хотя реальную защиту при `VersionTLS13` даёт именно `--tls-min-version`
(Go выбирает TLS 1.3 cipher suites сам, `--tls-cipher-suites` на них не влияет - см. вопрос
2 в разделе "Проверьте себя"). `--tls-cipher-suites` всё равно нужен явно - это
defense-in-depth: если минимальную версию потом ослабят до 1.2, слабые наборы шифров не
включатся сами по себе. На etcd (там допускается TLS 1.2) `--cipher-suites` уже реально
ограничивает набор прямо сейчас, а не на будущее.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
cp /etc/kubernetes/manifests/etcd.yaml ~/5-etcd.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Добавьте в command:
# - --tls-min-version=VersionTLS13
# - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
vim /etc/kubernetes/manifests/etcd.yaml
# Добавьте в command:
# - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
exit
exit

k get po -n kube-system -l component=etcd
# STATUS должен стать Running - если ещё нет, подождите пару секунд и повторите
ssh control-plane "sudo grep -E -- '--tls-min-version=VersionTLS13|--tls-cipher-suites=' /etc/kubernetes/manifests/kube-apiserver.yaml"
ssh control-plane "sudo grep -- '--cipher-suites=' /etc/kubernetes/manifests/etcd.yaml"

mkdir -p /var/work/tests/artifacts/5
ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_3 -brief </dev/null' \
  > /var/work/tests/artifacts/5/tls13.txt 2>&1
# Protocol version: TLSv1.3 - соединение прошло

ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null' \
  >> /var/work/tests/artifacts/5/tls13.txt 2>&1
# ssl3_read_bytes:tlsv1 alert protocol version - handshake должен провалиться, это и нужно

echo 'TLS 1.2 correctly rejected (non-zero exit / handshake failure)' \
  >> /var/work/tests/artifacts/5/tls13.txt
cat /var/work/tests/artifacts/5/tls13.txt
```

Ожидается строка вида `Protocol version: TLSv1.3` или `Protocol : TLSv1.3`, а завершение
`openssl s_client -tls1_2` с ошибкой handshake/non-zero exit должно быть записано как
`TLS 1.2 correctly rejected`.

## Задание 6. Проверить SHA-256 kubelet и kubectl

Эталон не вычисляется из локальных файлов. Скачайте официальные опубликованные суммы
Kubernetes `v1.36.0`, сформируйте файлы в формате `sha256sum -c` и сохраните результаты.

```bash
mkdir -p /var/work/tests/artifacts/6 /tmp/cks-103-sha
cd /tmp/cks-103-sha
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl.sha256
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubelet.sha256

printf '%s  %s\n' "$(cat kubectl.sha256)" "$(command -v kubectl)" > kubectl.check
scp kubelet.sha256 control-plane:/tmp/kubelet.sha256
ssh control-plane 'printf "%s  %s\\n" "$(cat /tmp/kubelet.sha256)" "$(command -v kubelet)" > /tmp/kubelet.check && sha256sum -c /tmp/kubelet.check' \
  | tee /var/work/tests/artifacts/6/binaries.sha256.txt
sha256sum -c kubectl.check | tee -a /var/work/tests/artifacts/6/binaries.sha256.txt

cat /var/work/tests/artifacts/6/binaries.sha256.txt
```

Обе строки должны завершаться `: OK`. Если путь к бинарнику отличается от `/usr/bin`,
`command -v` всё равно формирует корректный вход для `sha256sum -c`.

## Задание 7. Remediation cycle: конкретный kube-bench FAIL до PASS

В отличие от задания 1 (снимок всего отчёта), здесь нужно связать один конкретный check
с его исправлением. `kube-bench` поддерживает точечный запуск через `--check`, поэтому
не нужно перечитывать весь отчёт вручную:

```bash
mkdir -p /var/work/tests/artifacts/7

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/before.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/before.txt
# [FAIL] 1.1.1 Ensure that the API server pod specification file permissions ...
```

Проверьте фактическое право доступа на ноде и исправьте его до `600` - это file-only
изменение, kubelet не пересоздаёт static Pod из-за смены прав, только из-за смены
содержимого манифеста:

```bash
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 644 /etc/kubernetes/manifests/kube-apiserver.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 600 /etc/kubernetes/manifests/kube-apiserver.yaml
```

Повторный точечный запуск того же check должен показать `PASS`:

```bash
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/after.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/after.txt
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions ...
```

Подтвердите, что kube-apiserver остался здоров: правка прав файла не меняет его
содержимое, поэтому kubelet не должен пересоздавать static Pod.

```bash
k get --raw='/readyz'
k -n kube-system get pods -l component=kube-apiserver
```

## Задание 8. Remediation cycle: kube-controller-manager

Тот же приём, что в задании 7, для другого компонента и другого check ID (`1.1.3` -
kube-controller-manager pod specification file permissions):

```bash
mkdir -p /var/work/tests/artifacts/8

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/before.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/before.txt
# [FAIL] 1.1.3 Ensure that the controller manager pod specification file permissions ...

ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 644 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-controller-manager.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 600 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/after.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/after.txt
# [PASS] 1.1.3 Ensure that the controller manager pod specification file permissions ...

k -n kube-system get pods -l component=kube-controller-manager
```

## Задание 9. Remediation cycle: profiling на kube-controller-manager и kube-scheduler

Тот же приём, что в заданиях 7-8 (найти конкретный `[FAIL]` через kube-bench, исправить,
подтвердить `[PASS]`), для checks `1.3.2` (kube-controller-manager profiling) и `1.4.1`
(kube-scheduler profiling). Оба, как и весь раздел `1.x`, относятся к target `master` в
`cis-1.12`, поэтому явный `--targets` не нужен - точно так же, как в заданиях 7-8. Задание 3
уже отключило profiling только на kube-apiserver; kubeadm по умолчанию НЕ добавляет
`--profiling=false` в манифесты kube-controller-manager/kube-scheduler вообще.

```bash
mkdir -p /var/work/tests/artifacts/9

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-before.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-before.txt
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-before.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-before.txt
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false ...
```

Исправляем оба static Pod manifests - тот же приём, что в задании 3, только для двух
других компонентов:

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-controller-manager.yaml ~/9-controller-manager.yaml
cp /etc/kubernetes/manifests/kube-scheduler.yaml ~/9-scheduler.yaml
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# В массив command добавьте строку с тем же отступом, что у остальных аргументов:
# - --profiling=false
vim /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
exit
exit

k -n kube-system get pods -l component=kube-controller-manager
k -n kube-system get pods -l component=kube-scheduler
```

Проверяем не текст файла, а реально запущенный Pod (kubelet пересоздаёт static Pod не
мгновенно после изменения манифеста), и повторный точечный запуск того же check должен
показать `PASS`:

```bash
k -n kube-system get pod -l component=kube-controller-manager -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

k -n kube-system get pod -l component=kube-scheduler -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-after.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-after.txt
# [PASS] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-after.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-after.txt
# [PASS] 1.4.1 Ensure that the --profiling argument is set to false ...
```

`jq -e` должен вывести `true` для обоих компонентов, а обе команды `k get pods`
выше - показать `Running`.

## Задание 10. Remediation cycle: protect-kernel-defaults на worker-узле

Тот же приём, что в заданиях 7-9, теперь на РЕАЛЬНОМ worker-узле (не control-plane), но для
ДРУГОГО профиля. Закреплённый `kube-bench 0.16.0`/`cis-1.12` (используемый во всех остальных
заданиях этой лабы) вообще не содержит check protect-kernel-defaults - CIS убрал/
переномеровал его начиная с этой версии профиля; собственный `4.2.6` в `cis-1.12` - это
ДРУГОЙ check (`--make-iptables-util-chains`, `PASS` по умолчанию, к protect-kernel-defaults
отношения не имеет). Нужный check с тем же ID `4.2.6` существует в более старом профиле
`cis-1.24` того же бинарника - используйте именно его, явным `--benchmark cis-1.24`, только
для этого одного задания.

В отличие от control-plane, на worker-узле `kube-bench` НЕ предустановлен - установите его
здесь сами (реальный install, не копия с control-plane или worker PC): скачайте тот же
закреплённый релиз с GitHub, распакуйте `binary` и `cfg` в default `--config-dir`
(`/etc/kube-bench/cfg`), чтобы не указывать этот флаг явно в каждой команде:

```bash
WORKER_NODE=$(k get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
KUBE_BENCH_VERSION=0.16.0
ssh "$WORKER_NODE" "
  arch=\$(dpkg --print-architecture)
  workdir=\$(mktemp -d)
  curl -fsSL -o \"\$workdir/kube-bench.tar.gz\" \
    'https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}/kube-bench_${KUBE_BENCH_VERSION}_linux_'\"\$arch\"'.tar.gz'
  tar -xzf \"\$workdir/kube-bench.tar.gz\" -C \"\$workdir\"
  sudo install -d -m 0755 /opt/kube-bench /etc/kube-bench
  sudo cp -a \"\$workdir\"/cfg /etc/kube-bench/cfg
  sudo install -m 0755 \"\$workdir/kube-bench\" /opt/kube-bench/kube-bench
  sudo ln -sf /opt/kube-bench/kube-bench /usr/local/bin/kube-bench
  rm -rf \"\$workdir\"
"
ssh "$WORKER_NODE" 'kube-bench version'

mkdir -p /var/work/tests/artifacts/10
ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/before.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/before.txt
# [FAIL] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```

`protectKernelDefaults` не входит в kubeadm-сгенерированный `KubeletConfiguration` вообще -
поле физически отсутствует (эквивалентно небезопасному default `false`), поэтому просто
добавьте его, а не ищите существующую строку для замены:

```bash
ssh "$WORKER_NODE" 'echo "protectKernelDefaults: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh "$WORKER_NODE" 'sudo systemctl restart kubelet'
k get node "$WORKER_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

Подтвердите через `/configz` (реально применённая конфигурация, не текст файла) и
повторным точечным запуском check:

```bash
k get --raw="/api/v1/nodes/$WORKER_NODE/proxy/configz" \
  | jq -e '.kubeletconfig.protectKernelDefaults == true'

ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/after.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/after.txt
# [PASS] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```
