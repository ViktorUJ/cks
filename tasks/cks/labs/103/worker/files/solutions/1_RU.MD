[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 103 - эталонное решение

> Команды выполняются на worker, если явно не указан `control-plane`. Перед правкой
> static Pod manifests сохраните копии. Kubelet сам заметит изменение файлов и пересоздаст
> соответствующие static Pods; не удаляйте их через Kubernetes API.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
ssh control-plane sudo hostname
```

## Задание 1. Отчёт kube-bench

`kube-bench` `0.16.0` на worker уже расположен в `/opt/kube-bench`. Скопируйте полный
каталог, чтобы на узле были и binary, и `cfg`. Kubernetes `1.36` пока отсутствует в
официальной support table kube-bench; встроенный version mapping этой версии заканчивается
записью `"1.34": "cis-1.12"` - более новых профилей (включая какой-либо профиль под 1.35/1.36)
в `0.16.0` нет вовсе, поэтому используем именно `cis-1.12` как ближайший существующий.
Поэтому мы запускаем его принудительно как approximate hardening signal, а не как
authoritative CIS compliance assessment.

```bash
mkdir -p /var/work/tests/artifacts/1
scp -r /opt/kube-bench control-plane:/tmp/kube-bench
ssh control-plane 'sudo rm -rf /opt/kube-bench && sudo mv /tmp/kube-bench /opt/kube-bench'
{
  printf 'kubernetes_version=%s\n' "$(kubectl version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-1.12\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,node,controlplane,etcd,policies'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

test -s /var/work/tests/artifacts/1/kube-bench.txt
# Полный evidence должен включать '== Summary <target> ==' для КАЖДОГО target, а не
# просто произвольную строку [PASS]/[WARN]/[FAIL]. Проверка по подстрокам вроде
# 'Control Plane Node Configuration'/'API Server' недостаточна: обе строки уже
# встречаются внутри target 'master', поэтому отчёт без 'controlplane'/'etcd' всё равно
# мог бы её удовлетворить - это ложный PASS для требования запустить все пять targets.
sections_ok=true
for target in master node controlplane etcd policies; do
  grep -Eq "^== Summary ${target} ==\$" /var/work/tests/artifacts/1/kube-bench.txt \
    || { echo "ERROR: '== Summary ${target} ==' not found in report - target '${target}' did not run" >&2; sections_ok=false; }
done
if [[ "$sections_ok" != true ]]; then
  echo "FAIL: report is incomplete - re-run with --targets master,node,controlplane,etcd,policies" >&2
  false
fi
grep -E '\[(PASS|WARN|FAIL)\]' /var/work/tests/artifacts/1/kube-bench.txt | head
```

## Задание 2. Hardening kubelet

На control-plane kubelet читает `/var/lib/kubelet/config.yaml`. В YAML должны быть именно
следующие поля (не добавляйте одноимённые ключи второй раз):

```yaml
readOnlyPort: 0
authentication:
  anonymous:
    enabled: false
```

Безопасный способ - отредактировать существующие секции через `sudoedit`:

```bash
ssh control-plane
sudo cp /var/lib/kubelet/config.yaml /var/lib/kubelet/config.yaml.bak
sudoedit /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
sudo systemctl is-active kubelet
exit
```

Проверяем не статический текст файла, а действующую конфигурацию, которую kubelet
реально применил - через API `configz` (текстовый парсинг YAML легко обмануть похожими
полями вроде `webhook.enabled`, а `configz` отражает то, что kubelet сам считает своей
конфигурацией):

```bash
NODE=$(kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}')

kubectl get --raw="/api/v1/nodes/${NODE}/proxy/configz" --context "$CTX" \
  | jq -e '
      .kubeletconfig.readOnlyPort == 0 and
      .kubeletconfig.authentication.anonymous.enabled == false
    '

kubectl wait --for=condition=Ready "node/${NODE}" --timeout=120s --context "$CTX"
```

## Задание 3. Отключить profiling kube-apiserver

Добавьте параметр в список `command` контейнера `kube-apiserver`.

```bash
ssh control-plane
sudo install -d -m 0700 /etc/kubernetes/manifest-backups
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifest-backups/kube-apiserver.yaml.before-profiling
sudoedit /etc/kubernetes/manifests/kube-apiserver.yaml
# В массив command добавьте строку с тем же отступом, что у остальных аргументов:
# - --profiling=false
exit

until kubectl get --raw='/readyz' --context "$CTX" 2>/dev/null | grep -qx ok; do sleep 5; done
ssh control-plane "sudo grep -n -- '--profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
kubectl get pods -n kube-system -l component=kube-apiserver --context "$CTX"
```

## Задание 4. TLS Secret и Ingress

Создайте минимальное приложение и Service, сгенерируйте самоподписанный сертификат для
точного DNS-имени, затем создайте TLS Secret и Ingress. Controller `ingress-nginx` уже
установлен и Ready в этой лабе (lab-owned fixture, версия закреплена в bootstrap) - убедимся
в этом перед тем, как создавать Ingress.

```bash
kubectl get ingressclass --context "$CTX"
kubectl -n ingress-nginx get deploy ingress-nginx-controller --context "$CTX"
kubectl -n ingress-nginx get endpoints ingress-nginx-controller --context "$CTX"

kubectl create namespace cks-103 --context "$CTX"
kubectl -n cks-103 create deployment secure-app --image=nginx:1.27 --context "$CTX"
kubectl -n cks-103 expose deployment secure-app --name=secure-app --port=80 --target-port=80 --context "$CTX"
kubectl -n cks-103 wait --for=condition=Available deployment/secure-app --timeout=60s --context "$CTX"

mkdir -p /tmp/cks-103-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/cks-103-tls/tls.key \
  -out /tmp/cks-103-tls/tls.crt \
  -subj '/CN=secure.cks.local' \
  -addext 'subjectAltName=DNS:secure.cks.local'

kubectl -n cks-103 create secret tls secure-ingress-tls \
  --cert=/tmp/cks-103-tls/tls.crt --key=/tmp/cks-103-tls/tls.key --context "$CTX"

cat <<'EOF' | kubectl apply --context "$CTX" -f -
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

kubectl get secret,ingress -n cks-103 --context "$CTX"
kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o yaml
```

Полноценный self-check: не останавливаемся на `kubectl get ... -o yaml`, а подтверждаем,
что TLS Ingress фактически работает end-to-end через реальный controller.

```bash
# 1. Service secure-app имеет endpoint.
kubectl -n cks-103 get endpoints secure-app --context "$CTX"

# 2. Сертификат в Secret действительно содержит точное DNS-имя в SAN (не substring -
# 'notsecure.cks.local' не должен ложно засчитываться как совпадение).
san=$(kubectl -n cks-103 get secret secure-ingress-tls --context "$CTX" -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -ext subjectAltName)
if grep -Eq '(^|[ ,])DNS:secure[.]cks[.]local([, ]|$)' <<<"$san"; then
  echo "OK: SAN contains exact DNS:secure.cks.local"
else
  echo "FAIL: SAN does not contain the exact DNS name secure.cks.local" >&2
fi

# 3. certificate и private key являются парой - сравниваем public key, а не modulus
# (modulus-подход через `openssl rsa` работает только для RSA-ключей; README не требует
# именно RSA, поэтому корректная ECDSA-пара не должна получать false FAIL).
cert_pub=$(kubectl -n cks-103 get secret secure-ingress-tls --context "$CTX" -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum | awk '{print $1}')
key_pub=$(kubectl -n cks-103 get secret secure-ingress-tls --context "$CTX" -o jsonpath='{.data.tls\.key}' \
  | base64 -d | openssl pkey -pubout -outform DER | sha256sum | awk '{print $1}')
if [[ -n "$cert_pub" && "$cert_pub" == "$key_pub" ]]; then
  echo "OK: certificate and private key match"
else
  echo "FAIL: certificate and private key do NOT match" >&2
fi

# 4. Реальный HTTPS request через controller Service ClusterIP, выполненный с
# control-plane node. Pod IP из Endpoints не гарантированно маршрутизируется с отдельной
# worker VM (Pod CIDR 10.0.0.0/16 отличается от VPC CIDR 10.103.0.0/16 в этой лабе),
# поэтому проверяем через Service и с узла кластера, а не с worker по Pod IP. Проверяем
# конкретное заявленное поведение (status==200 и тело от именно secure-app), а не любой
# 2xx/3xx - иначе redirect-аннотация могла бы дать false PASS без реального доступа к backend.
controller_svc_ip=$(kubectl -n ingress-nginx get svc ingress-nginx-controller --context "$CTX" \
  -o jsonpath='{.spec.clusterIP}')

https_status=$(ssh control-plane "curl -sS -o /tmp/https_body -w '%{http_code}' --max-time 5 -k \
  --resolve secure.cks.local:443:${controller_svc_ip} https://secure.cks.local/")
echo "HTTPS status: $https_status"
ssh control-plane "cat /tmp/https_body; rm -f /tmp/https_body" | grep -q 'Welcome to nginx' \
  && echo "OK: HTTPS response body is from secure-app (nginx default page)" \
  || echo "FAIL: HTTPS response body does not look like secure-app" >&2

# 5. HTTP request получает redirect именно на https://secure.cks.local/ (не любой 3xx -
# захватываем Location и проверяем, что он указывает на правильный HTTPS host).
http_headers=$(ssh control-plane "curl -sS -D - -o /dev/null -w 'HTTPCODE:%{http_code}' --max-time 5 \
  --resolve secure.cks.local:80:${controller_svc_ip} http://secure.cks.local/")
http_status=$(grep -oE 'HTTPCODE:[0-9]+' <<<"$http_headers" | cut -d: -f2)
http_location=$(grep -i '^location:' <<<"$http_headers" | tr -d '\r' | awk '{print $2}')
echo "HTTP status: $http_status, Location: $http_location"
if [[ "$http_status" =~ ^3[0-9][0-9]$ && "$http_location" == "https://secure.cks.local/"* ]]; then
  echo "OK: HTTP redirects to the correct HTTPS host"
else
  echo "FAIL: HTTP did not redirect to https://secure.cks.local/" >&2
fi
```

Ожидаем `HTTPS status: 200` с телом, содержащим `Welcome to nginx` на шаге 4, и HTTP-статус
`3xx` с `Location: https://secure.cks.local/...` на шаге 5 (конкретно `308` для
`ssl-redirect: "true"`, но проверяем именно host в `Location`, а не только класс статуса).

## Задание 5. TLS hardening kube-apiserver и etcd

В обоих static Pod manifests добавьте параметры в `command`. Набор cipher suites нужен для
TLS до 1.2; при `VersionTLS13` server принимает только TLS 1.3, а явный набор предотвращает
слабые наборы при последующем ослаблении минимальной версии.

```bash
ssh control-plane
sudo install -d -m 0700 /etc/kubernetes/manifest-backups
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifest-backups/kube-apiserver.yaml.before-tls
sudo cp /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/manifest-backups/etcd.yaml.before-tls
sudoedit /etc/kubernetes/manifests/kube-apiserver.yaml
# Добавьте в command:
# - --tls-min-version=VersionTLS13
# - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
sudoedit /etc/kubernetes/manifests/etcd.yaml
# Добавьте в command:
# - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
exit

until kubectl get --raw='/readyz' --context "$CTX" 2>/dev/null | grep -qx ok; do sleep 5; done
kubectl get pods -n kube-system --context "$CTX" -l component=etcd
ssh control-plane "sudo grep -E -- '--tls-min-version=VersionTLS13|--tls-cipher-suites=' /etc/kubernetes/manifests/kube-apiserver.yaml"
ssh control-plane "sudo grep -- '--cipher-suites=' /etc/kubernetes/manifests/etcd.yaml"

mkdir -p /var/work/tests/artifacts/5
ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_3 -brief </dev/null' \
  > /var/work/tests/artifacts/5/tls13.txt 2>&1
if ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null' \
  >> /var/work/tests/artifacts/5/tls13.txt 2>&1; then
  echo 'TLS 1.2 unexpectedly succeeded' | tee -a /var/work/tests/artifacts/5/tls13.txt
  exit 1
else
  echo 'TLS 1.2 correctly rejected (non-zero exit / handshake failure)' \
    | tee -a /var/work/tests/artifacts/5/tls13.txt
fi
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
kubectl get --raw='/readyz'
kubectl -n kube-system get pods -l component=kube-apiserver
```
