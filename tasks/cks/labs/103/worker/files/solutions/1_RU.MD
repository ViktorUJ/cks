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
официальной support table kube-bench; `cis-2.0` официально сопоставлен с `1.34–1.35`.
Поэтому мы запускаем его принудительно как approximate hardening signal, а не как
authoritative CIS compliance assessment.

```bash
mkdir -p /var/work/tests/artifacts/1
scp -r /opt/kube-bench control-plane:/tmp/kube-bench
ssh control-plane 'sudo rm -rf /opt/kube-bench && sudo mv /tmp/kube-bench /opt/kube-bench'
{
  printf 'kubernetes_version=%s\n' "$(kubectl version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-2.0\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-2.0 --targets master,controlplane,node'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

test -s /var/work/tests/artifacts/1/kube-bench.txt
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

kubectl get nodes --context "$CTX"
ssh control-plane "sudo awk '/^[[:space:]]*readOnlyPort:[[:space:]]*0[[:space:]]*$/ {port=1} /^[[:space:]]*anonymous:[[:space:]]*$/ {anonymous=1; next} anonymous && /^[[:space:]]*enabled:[[:space:]]*false[[:space:]]*$/ {auth=1} END {exit !(port && auth)}' /var/lib/kubelet/config.yaml"
```

## Задание 3. Отключить profiling kube-apiserver

Добавьте параметр в список `command` контейнера `kube-apiserver`.

```bash
ssh control-plane
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml.bak
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
точного DNS-имени, затем создайте TLS Secret и Ingress.

```bash
kubectl create namespace cks-103 --context "$CTX"
kubectl -n cks-103 create deployment secure-app --image=nginx:1.27 --context "$CTX"
kubectl -n cks-103 expose deployment secure-app --name=secure-app --port=80 --target-port=80 --context "$CTX"

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

## Задание 5. TLS hardening kube-apiserver и etcd

В обоих static Pod manifests добавьте параметры в `command`. Набор cipher suites нужен для
TLS до 1.2; при `VersionTLS13` server принимает только TLS 1.3, а явный набор предотвращает
слабые наборы при последующем ослаблении минимальной версии.

```bash
ssh control-plane
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml.tls.bak
sudo cp /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/manifests/etcd.yaml.tls.bak
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
cat /var/work/tests/artifacts/5/tls13.txt
```

Ожидается строка вида `Protocol version: TLSv1.3` или `Protocol : TLSv1.3`.

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
