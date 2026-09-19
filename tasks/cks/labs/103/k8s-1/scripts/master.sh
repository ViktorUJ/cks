#!/usr/bin/env bash
set -euo pipefail

echo "*** master node cks lab 103 k8s-1"
export KUBECONFIG=/root/.kube/config

# The lab is intentionally single-node. Permit the TLS demo workload to schedule here.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

# Стартовая уязвимость для задания 7: kube-bench проверяет права static Pod manifests
# control-plane (CIS 1.1.1) и ожидает не более 600. Лабораторная инфраструктура намеренно
# выставляет mode 0644, чтобы получить контролируемый FAIL check 1.1.1.
chmod 644 /etc/kubernetes/manifests/kube-apiserver.yaml

# Стартовая уязвимость для задания 2: у kubeadm по умолчанию readOnlyPort=0 и
# authentication.anonymous.enabled=false, поэтому без явного контролируемого baseline
# студент обнаружил бы, что "исправление" уже выполнено до начала задания. kubeadm
# сериализует KubeletConfiguration целиком, поэтому оба поля физически присутствуют в
# файле с safe defaults - меняем существующие значения in-place через sed (без
# добавления дублирующих ключей), перезапускаем kubelet и дожидаемся Ready.
KUBELET_CONFIG=/var/lib/kubelet/config.yaml
cp "$KUBELET_CONFIG" "$KUBELET_CONFIG.orig"

sed -i 's/^readOnlyPort:[[:space:]]*0[[:space:]]*$/readOnlyPort: 10255/' "$KUBELET_CONFIG"

# authentication.anonymous.enabled: false -> true. Меняем только первое совпадение
# enabled: false, идущее непосредственно после блока anonymous: (не webhook: ниже).
awk '
  BEGIN { in_anon = 0; done = 0 }
  /^[[:space:]]*anonymous:[[:space:]]*$/ { in_anon = 1; print; next }
  in_anon && !done && /^[[:space:]]*enabled:[[:space:]]*false[[:space:]]*$/ {
    sub(/false/, "true"); print; done = 1; in_anon = 0; next
  }
  /^[[:space:]]*webhook:[[:space:]]*$/ { in_anon = 0 }
  { print }
' "$KUBELET_CONFIG" > "$KUBELET_CONFIG.new"
mv "$KUBELET_CONFIG.new" "$KUBELET_CONFIG"
chmod 600 "$KUBELET_CONFIG"

if ! grep -qE '^readOnlyPort:[[:space:]]*10255[[:space:]]*$' "$KUBELET_CONFIG"; then
  echo "*** FATAL: failed to set intentional insecure readOnlyPort baseline in $KUBELET_CONFIG" >&2
  exit 1
fi

systemctl restart kubelet

# Дожидаемся возврата ноды в Ready после перезапуска kubelet с небезопасным baseline.
node_ready=false
for i in $(seq 1 24); do
  if kubectl get node "$(hostname)" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q '^True$'; then
    echo "*** node $(hostname) is Ready with intentional insecure kubelet baseline (readOnlyPort=10255, anonymous.enabled=true)"
    node_ready=true
    break
  fi
  sleep 5
done

if [[ "$node_ready" != "true" ]]; then
  echo "*** FATAL: node did not return to Ready after applying the intentional insecure kubelet baseline for task 2" >&2
  exit 1
fi

# Lab-owned ingress controller fixture для задания 4: README/solution требуют
# ingressClassName: nginx, поэтому реальный controller должен существовать - Ingress API
# object сам по себе ничего не маршрутизирует без controller. Устанавливаем явно
# закреплённую, заранее проверенную версию (последний релиз до archive/retirement
# проекта в марте 2026 - controller-v1.15.1), используя официальный "bare metal" cloud
# manifest, адаптированный под single-node NodePort доступ.
INGRESS_NGINX_VERSION="controller-v1.15.1"
curl -fsSL -o /tmp/ingress-nginx-deploy.yaml \
  "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/baremetal/deploy.yaml"
kubectl apply -f /tmp/ingress-nginx-deploy.yaml
rm -f /tmp/ingress-nginx-deploy.yaml

echo "*** waiting for ingress-nginx-controller Deployment to become Available..."
if ! kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=180s; then
  echo "*** FATAL: ingress-nginx-controller did not become Available - task 4 fixture is broken" >&2
  exit 1
fi

# Проверяем не lifecycle временных admission Job'ов (ingress-nginx-admission-create /
# ingress-nginx-admission-patch), а их устойчивые postconditions. Оба Job в официальном
# controller-v1.15.1 bare-metal manifest объявлены с ttlSecondsAfterFinished: 0, поэтому
# сразу после Complete они eligible for deletion TTL-контроллером - "kubectl wait
# --for=condition=Complete job/..." после ожидания Deployment Available - это race:
# к моменту вызова Job уже может быть удалён (NotFound), что даёт ложный FATAL на
# полностью исправной лабе. Вместо этого проверяем то, что admission-create/-patch
# должны были реально произвести и что переживает удаление самих Job.

echo "*** waiting for ingress-nginx-admission TLS Secret to be created..."
admission_secret_ok=false
for i in $(seq 1 24); do
  if kubectl -n ingress-nginx get secret ingress-nginx-admission >/dev/null 2>&1; then
    admission_secret_ok=true
    break
  fi
  sleep 5
done
if [[ "$admission_secret_ok" != "true" ]]; then
  echo "*** FATAL: Secret ingress-nginx-admission was not created - admission webhook TLS material is missing" >&2
  exit 1
fi

echo "*** waiting for ValidatingWebhookConfiguration ingress-nginx-admission to have a non-empty caBundle..."
ca_bundle=""
for i in $(seq 1 24); do
  ca_bundle=$(kubectl get validatingwebhookconfiguration ingress-nginx-admission \
    -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null)
  [[ -n "$ca_bundle" ]] && break
  sleep 5
done
if [[ -z "$ca_bundle" ]]; then
  echo "*** FATAL: ValidatingWebhookConfiguration ingress-nginx-admission is missing or has an empty caBundle - admission-patch did not complete its job" >&2
  exit 1
fi

echo "*** waiting for ingress-nginx-controller-admission Service to have an endpoint..."
admission_endpoint=""
for i in $(seq 1 24); do
  admission_endpoint=$(kubectl -n ingress-nginx get endpoints ingress-nginx-controller-admission \
    -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
  [[ -n "$admission_endpoint" ]] && break
  sleep 5
done
if [[ -z "$admission_endpoint" ]]; then
  echo "*** FATAL: ingress-nginx-controller-admission Service has no endpoint - the admission webhook is not reachable" >&2
  exit 1
fi

echo "*** verifying the admission webhook actually accepts a request (server-side dry-run Ingress)..."
cat <<'PREFLIGHT_EOF' > /tmp/ingress-nginx-preflight.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-nginx-bootstrap-preflight
  namespace: ingress-nginx
spec:
  ingressClassName: nginx
  rules:
  - host: bootstrap-preflight.invalid
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ingress-nginx-controller-admission
            port:
              number: 443
PREFLIGHT_EOF

if ! kubectl apply --dry-run=server -f /tmp/ingress-nginx-preflight.yaml >/dev/null 2>/tmp/preflight-err.txt; then
  echo "*** FATAL: server-side dry-run Ingress was rejected by the API - admission webhook path is not actually usable:" >&2
  cat /tmp/preflight-err.txt >&2
  rm -f /tmp/ingress-nginx-preflight.yaml /tmp/preflight-err.txt
  exit 1
fi
rm -f /tmp/ingress-nginx-preflight.yaml /tmp/preflight-err.txt
echo "*** admission webhook postconditions verified: Secret present, caBundle non-empty, admission Service has an endpoint, server-side dry-run accepted"

# Подтверждаем, что controller endpoint реально доступен - не просто Deployment Ready,
# а Service действительно имеет backing Pod IP.
controller_endpoint=""
for i in $(seq 1 24); do
  controller_endpoint=$(kubectl -n ingress-nginx get endpoints ingress-nginx-controller \
    -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
  [[ -n "$controller_endpoint" ]] && break
  sleep 5
done

if [[ -z "$controller_endpoint" ]]; then
  echo "*** FATAL: ingress-nginx-controller Service has no endpoint - task 4 fixture is broken" >&2
  exit 1
fi

echo "*** ingress-nginx-controller ($INGRESS_NGINX_VERSION) is ready with endpoint $controller_endpoint"
