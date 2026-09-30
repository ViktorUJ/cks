#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
CTX="cluster1-admin@cluster1"
HELM_VERSION="v3.17.3"
# Kyverno 1.19 / chart 3.9.0: current supported branch verified 2026-08-31.
# This is the first release with full CEL-policy feature parity; legacy ClusterPolicy is
# deprecated and scheduled for removal in 1.20.
KYVERNO_CHART_VERSION="3.9.0"

echo "*** worker pc cks lab 108 k8s-1"
until kubectl get nodes --context "$CTX" --no-headers 2>/dev/null | grep -q .; do
  sleep 5
done

# Helm нужен для задания 1. Версия закреплена, чтобы команда установки была
# воспроизводимой; сам Kyverno намеренно ещё не установлен.
arch=$(dpkg --print-architecture)
case "$arch" in
  amd64) helm_arch="amd64" ;;
  arm64) helm_arch="arm64" ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${helm_arch}.tar.gz" -o "$workdir/helm.tgz"
tar -xzf "$workdir/helm.tgz" -C "$workdir"
install -m 0755 "$workdir/linux-${helm_arch}/helm" /usr/local/bin/helm

cat >/usr/local/bin/install-kyverno <<EOF
#!/usr/bin/env bash
set -euo pipefail
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm upgrade --install kyverno kyverno/kyverno \\
  --namespace kyverno --create-namespace \\
  --version ${KYVERNO_CHART_VERSION} \\
  --set admissionController.replicas=1 \\
  --wait --timeout 5m
EOF
chmod 0755 /usr/local/bin/install-kyverno

# Задание 6 использует отдельный механизм - ImagePolicyWebhook. Backend пишется на
# Python не потому, что это единственный вариант, а чтобы не тянуть внешний
# сторонний образ с неконтролируемым тегом; студент сам создаёт ConfigMap/Deployment
# из этого файла как часть задания, сам код backend уже дан, чтобы задание проверяло
# понимание ImageReview API и wiring admission plugin, а не умение писать HTTP-сервер.
# Backend слушает HTTPS (stdlib ssl, без сторонних зависимостей) - upstream Kubernetes
# документация для ImagePolicyWebhook явно требует 'It is required that the backend
# communicate over TLS' и пример kubeconfig использует 'server: https://...'; сертификат
# генерируется отдельно самим заданием (после того как известен ClusterIP backend'а для
# SAN) и монтируется тем же ConfigMap механизмом, что и сам server.py.
mkdir -p /opt/image-policy-backend
cat >/opt/image-policy-backend/server.py <<'PYEOF'
#!/usr/bin/env python3
"""Minimal ImagePolicyWebhook backend implementing the ImageReview contract.

Denies any container image ending in ':latest' or with no tag at all (which
Kubernetes/OCI resolve to implicit 'latest'). Allows everything else.

Serves over HTTPS using a certificate/key mounted at /opt/image-policy/tls -
the upstream ImagePolicyWebhook contract requires the backend to communicate
over TLS (see the 'Configuration file format' section of the Kubernetes
admission-controllers reference), so this backend does not offer a plain HTTP
fallback.
"""
import json
import ssl
from http.server import BaseHTTPRequestHandler, HTTPServer


def is_untrusted(image: str) -> bool:
    if image.endswith(":latest"):
        return True
    # No ':' after the last '/' means no tag was given at all (implicit latest).
    tail = image.rsplit("/", 1)[-1]
    return ":" not in tail


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        # client-go's REST client appends a query string to every call (e.g.
        # '?timeout=30s'), so self.path is '/imagepolicy?timeout=30s', not a bare
        # '/imagepolicy' - comparing self.path by strict equality against the bare
        # path makes this backend 404 EVERY real admission request from
        # kube-apiserver, which client-go then surfaces as a generic "the server
        # could not find the requested resource" error with no indication that the
        # cause is a path/query mismatch, not a connectivity or TLS problem.
        if self.path.split("?", 1)[0] != "/imagepolicy":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length) or b"{}")
        images = body.get("spec", {}).get("containers", [])
        image_names = [c.get("image", "") for c in images]
        denied = [img for img in image_names if is_untrusted(img)]
        if denied:
            status = {
                "allowed": False,
                "reason": "image policy webhook backend denied one or more images: "
                "Images using latest tag are not allowed",
            }
        else:
            status = {"allowed": True}
        response = {
            "apiVersion": "imagepolicy.k8s.io/v1alpha1",
            "kind": "ImageReview",
            "status": status,
        }
        payload = json.dumps(response).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8443), Handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(
        certfile="/opt/image-policy/tls/tls.crt",
        keyfile="/opt/image-policy/tls/tls.key",
    )
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
    server.serve_forever()
PYEOF
chmod 0644 /opt/image-policy-backend/server.py

kubectl config use-context "$CTX" >/dev/null
echo "*** cluster is ready; complete the tasks and run check_result ***"
