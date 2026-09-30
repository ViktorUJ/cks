#!/bin/bash
set -euo pipefail

echo "*** master node cks lab 102 k8s-1 ***"
export KUBECONFIG=/root/.kube/config

# Лаба одноузловая: разрешаем учебным workload планироваться на control-plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

# Модульный "cilium install" (template/master.sh) запускается из cloud-init, где $HOME
# не задан - cilium-cli/helm молча завершается без ошибки, ничего не установив
# ("neither $XDG_CACHE_HOME nor $HOME are defined"). Досттавляем установку здесь, с явным
# $HOME, если DaemonSet ещё не появился.
#
# Эта лаба - kube-proxy-free (disable_kube_proxy=true в env.hcl), поэтому просто "cilium
# install" без kubeProxyReplacement/k8sServiceHost/k8sServicePort оставил бы Cilium без
# рабочего replacement datapath: Service/DNS, на которых построены все задания 2-4, не
# были бы гарантированно корректны. k8sServiceHost/Port должны указывать на РЕАЛЬНЫЙ
# apiserver endpoint (Endpoints default/kubernetes), а не на Service ClusterIP - без
# kube-proxy и без ещё не поднятого Cilium ClusterIP resolution работать не может (та же
# chicken-and-egg проблема, которую явно решает kube-proxy-free bootstrap в лабе 115).
export HOME=/root
if ! kubectl -n kube-system get daemonset cilium >/dev/null 2>&1; then
  echo "*** cilium DaemonSet not found - installing kube-proxy-free Cilium (module install was a no-op without \$HOME)"

  API_SERVER_IP=$(kubectl get endpoints kubernetes -n default -o jsonpath='{.subsets[0].addresses[0].ip}')
  if [[ -z "$API_SERVER_IP" ]]; then
    echo "*** FATAL: could not resolve the real apiserver IP from Endpoints default/kubernetes" >&2
    exit 1
  fi

  cilium install \
    --version 1.20.1 \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost="$API_SERVER_IP" \
    --set k8sServicePort=6443
fi
cilium status --wait

if kubectl -n kube-system get daemonset kube-proxy >/dev/null 2>&1; then
  echo "*** FATAL: kube-proxy DaemonSet must not exist in this kube-proxy-free lab" >&2
  exit 1
fi

CILIUM_POD=$(kubectl -n kube-system get pod -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
echo "*** effective kube-proxy-replacement state:"
KPR_STATUS=$(kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- cilium-dbg status)
printf '%s\n' "$KPR_STATUS"
if ! grep -Eq '^KubeProxyReplacement:[[:space:]]+True([[:space:]]|$)' <<<"$KPR_STATUS"; then
  echo "*** FATAL: Cilium kube-proxy replacement is not enabled (effective state != True)" >&2
  kubectl -n kube-system exec "$CILIUM_POD" -c cilium-agent -- cilium-dbg status --verbose >&2
  exit 1
fi

# Task 4 fixture: lab-owned, deterministic FQDN targets. example.com/www.google.com are
# real Internet endpoints outside our control - if they are temporarily unreachable
# (network policy on the runner, IANA/Google best-effort availability), the checker had no
# choice but to treat that probe as inconclusive, and Task 4 could PASS without a single
# proven positive/negative FQDN control ever actually running.
#
# allowed.cks102.test/blocked.cks102.test must NOT resolve to a Kubernetes Pod/Service/Node
# address: Cilium's toFQDNs is a DNS-to-IP/CIDR mechanism for traffic leaving the cluster -
# "If the resolved IPs are IPs within the kubernetes cluster, the ToFQDN rule will not apply
# to that IP" (Cilium docs). A ClusterIP-backed fixture would make a CORRECT student policy
# fail (false-FAIL), because toFQDNs would simply never match. So this fixture lives entirely
# outside Kubernetes: a separate Linux network namespace on the control-plane host, reachable
# only via normal IP routing (the same path real "external" traffic takes), with two distinct
# synthetic IPs from the RFC 2544 benchmarking range (never routable on the real Internet).
echo "*** setting up lab-owned, non-Kubernetes FQDN fixture (host network namespace) for task 4 ***"
FQDN_NS=cks102-fqdn-fixture
FQDN_HOST_IF=c102-fqdn-h
FQDN_NS_IF=c102-fqdn-n
ALLOWED_IP=198.18.0.10
BLOCKED_IP=198.18.0.20
FQDN_TLS_DIR=/etc/cks102-fqdn-fixture

systemctl stop cks102-fqdn-http cks102-fqdn-https-allowed cks102-fqdn-https-blocked 2>/dev/null || true
ip netns del "$FQDN_NS" 2>/dev/null || true
ip link del "$FQDN_HOST_IF" 2>/dev/null || true

ip netns add "$FQDN_NS"
ip link add "$FQDN_HOST_IF" type veth peer name "$FQDN_NS_IF"
ip link set "$FQDN_NS_IF" netns "$FQDN_NS"

ip addr add 198.18.0.1/24 dev "$FQDN_HOST_IF"
ip link set "$FQDN_HOST_IF" up

ip -n "$FQDN_NS" link set lo up
ip -n "$FQDN_NS" link set "$FQDN_NS_IF" up
ip -n "$FQDN_NS" addr add "$ALLOWED_IP/24" dev "$FQDN_NS_IF"
ip -n "$FQDN_NS" addr add "$BLOCKED_IP/24" dev "$FQDN_NS_IF"
ip -n "$FQDN_NS" route add default via 198.18.0.1

sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -C FORWARD -o "$FQDN_HOST_IF" -j ACCEPT 2>/dev/null || iptables -I FORWARD -o "$FQDN_HOST_IF" -j ACCEPT
iptables -C FORWARD -i "$FQDN_HOST_IF" -j ACCEPT 2>/dev/null || iptables -I FORWARD -i "$FQDN_HOST_IF" -j ACCEPT

mkdir -p "$FQDN_TLS_DIR"
openssl req -x509 -newkey rsa:2048 -keyout "$FQDN_TLS_DIR/tls.key" -out "$FQDN_TLS_DIR/tls.crt" \
  -days 825 -noenc -subj "/CN=allowed.cks102.test" >/dev/null 2>&1

mkdir -p /var/www/cks102-fqdn-allowed
echo "allowed-http" > /var/www/cks102-fqdn-allowed/index.html

# TCP/80 exists only on the "allowed" identity (blocked has no :80 listener at all -
# task 4 also proves that allowed.cks102.test:80 gets a transport DENY once policy applies).
systemd-run --unit=cks102-fqdn-http --collect --quiet -- \
  ip netns exec "$FQDN_NS" python3 -m http.server 80 --bind "$ALLOWED_IP" --directory /var/www/cks102-fqdn-allowed
systemd-run --unit=cks102-fqdn-https-allowed --collect --quiet -- \
  ip netns exec "$FQDN_NS" openssl s_server -quiet -naccept 100000 \
    -accept "${ALLOWED_IP}:443" -cert "$FQDN_TLS_DIR/tls.crt" -key "$FQDN_TLS_DIR/tls.key" -www
# "blocked" reuses the same working TLS identity/cert as "allowed" on a SEPARATE IP - the
# point is to prove the CiliumNetworkPolicy denies-by-FQDN-name, not that the backend behind
# blocked.cks102.test is broken. Hostname verification is intentionally not part of the task
# (student/checker curl with -k), so sharing the cert here is fine.
systemd-run --unit=cks102-fqdn-https-blocked --collect --quiet -- \
  ip netns exec "$FQDN_NS" openssl s_server -quiet -naccept 100000 \
    -accept "${BLOCKED_IP}:443" -cert "$FQDN_TLS_DIR/tls.crt" -key "$FQDN_TLS_DIR/tls.key" -www

echo "*** wiring CoreDNS to resolve allowed.cks102.test / blocked.cks102.test to the fixture ***"
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > /tmp/Corefile.orig
# Always regenerate: a re-run on an instance that already went through an OLDER version of
# this script (e.g. the previous rewrite-based Service aliasing) must not be mistaken for
# "already patched" just because it also mentions cks102.test - strip any prior cks102.test
# wiring (old rewrite lines or a previous hosts block) before re-inserting the current one.
awk '
  /^[[:space:]]*hosts[[:space:]]*\{/ { skip=1 }
  skip==1 { if ($0 ~ /^[[:space:]]*\}[[:space:]]*$/) skip=0; next }
  /cks102\.test/ { next }
  { print }
' /tmp/Corefile.orig > /tmp/Corefile.clean
sed '/^\s*ready\s*$/a\
    hosts {\
       198.18.0.10 allowed.cks102.test\
       198.18.0.20 blocked.cks102.test\
       fallthrough\
    }' /tmp/Corefile.clean > /tmp/Corefile.new
if ! diff -q /tmp/Corefile.orig /tmp/Corefile.new >/dev/null 2>&1; then
  kubectl -n kube-system create configmap coredns --from-file=Corefile=/tmp/Corefile.new \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n kube-system rollout restart deployment coredns
  if ! kubectl -n kube-system rollout status deployment coredns --timeout=120s; then
    echo "*** FATAL: CoreDNS did not roll out with the cks102.test hosts entries" >&2
    exit 1
  fi
fi
rm -f /tmp/Corefile.orig /tmp/Corefile.clean /tmp/Corefile.new

echo "*** verifying the FQDN fixture actually resolves (to non-cluster IPs) and serves before handing off the lab ***"
kubectl run fixture-probe --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 60 >/dev/null
kubectl wait --for=condition=Ready pod/fixture-probe --timeout=60s >/dev/null
fixture_ok=true
allowed_resolved=$(kubectl exec fixture-probe -- getent hosts allowed.cks102.test 2>/dev/null | awk '{print $1}') || fixture_ok=false
blocked_resolved=$(kubectl exec fixture-probe -- getent hosts blocked.cks102.test 2>/dev/null | awk '{print $1}') || fixture_ok=false
[[ "$allowed_resolved" == "$ALLOWED_IP" ]] || fixture_ok=false
[[ "$blocked_resolved" == "$BLOCKED_IP" ]] || fixture_ok=false
kubectl exec fixture-probe -- curl -sSk -o /dev/null -m5 https://allowed.cks102.test/ || fixture_ok=false
kubectl exec fixture-probe -- curl -sS -o /dev/null -m5 http://allowed.cks102.test:80/ || fixture_ok=false
kubectl exec fixture-probe -- curl -sSk -o /dev/null -m5 https://blocked.cks102.test/ || fixture_ok=false
kubectl delete pod fixture-probe --ignore-not-found --wait=false >/dev/null 2>&1

if [[ "$fixture_ok" != "true" ]]; then
  echo "*** FATAL: task 4 FQDN fixture does not resolve to $ALLOWED_IP/$BLOCKED_IP or does not serve correctly - lab cannot be handed off in this state (allowed_resolved=$allowed_resolved blocked_resolved=$blocked_resolved)" >&2
  exit 1
fi
echo "*** task 4 FQDN fixture ready: allowed.cks102.test ($ALLOWED_IP, 80+443), blocked.cks102.test ($BLOCKED_IP, 443) - both outside Kubernetes address space"
