#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
CTX="cluster1-admin@cluster1"
ETCD_VERSION="3.6.0"
ETCD_DIR="/var/lib/cks-109/etcd"

echo "*** CKS lab 109 worker bootstrap"
until kubectl get nodes --context "$CTX" --no-headers >/dev/null 2>&1; do sleep 5; done
for attempt in {1..24}; do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 control-plane 'sudo -n true' >/dev/null 2>&1; then break; fi
  sleep 5
  if [[ "$attempt" == 24 ]]; then echo "control-plane SSH is unavailable" >&2; exit 1; fi
done

arch=$(dpkg --print-architecture)
case "$arch" in amd64) etcd_arch=amd64 ;; arm64) etcd_arch=arm64 ;; *) echo "unsupported architecture: $arch" >&2; exit 1 ;; esac
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
curl -fsSL "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-${etcd_arch}.tar.gz" -o "$workdir/etcd.tgz"
tar -xzf "$workdir/etcd.tgz" -C "$workdir"
install -m 0755 "$workdir/etcd-v${ETCD_VERSION}-linux-${etcd_arch}/etcdctl" /usr/local/bin/etcdctl

# The private etcd client material is copied only to a root-owned directory on this
# disposable lab worker. The SSH tunnel keeps etcd bound to loopback on the control-plane.
install -d -m 0700 "$ETCD_DIR"
for file in ca.crt server.crt server.key; do
  ssh -o BatchMode=yes control-plane "sudo cat /etc/kubernetes/pki/etcd/${file}" >"${ETCD_DIR}/${file}"
done
chmod 0600 "$ETCD_DIR"/*

cat >/usr/local/bin/etcdctl-109 <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ETCD_DIR=/var/lib/cks-109/etcd
if ! ss -ltn 2>/dev/null | grep -q '127.0.0.1:23790'; then
  ssh -f -N -o BatchMode=yes -o ExitOnForwardFailure=yes \
    -L 127.0.0.1:23790:127.0.0.1:2379 control-plane
fi
exec env ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:23790 \
  --cacert="${ETCD_DIR}/ca.crt" \
  --cert="${ETCD_DIR}/server.crt" \
  --key="${ETCD_DIR}/server.key" "$@"
EOF
chmod 0755 /usr/local/bin/etcdctl-109

install -d -o ubuntu -g ubuntu -m 0755 /var/work/109
kubectl config use-context "$CTX" >/dev/null

# Trusted, checker-owned baseline evidence for legacy-secret, captured BEFORE the
# learner can touch anything. This is intentionally separate from the learner-owned
# /var/work/109/plaintext-proof.txt self-check file (task 1), which can be recreated at
# any time and therefore cannot by itself prove that the FINAL encrypted legacy-secret
# is the SAME object that started out as plaintext (a learner could delete+recreate a
# Secret with the same name/value and pass a checker that only inspects final state).
# root-only: contains the raw pre-encryption plaintext value.
# API readiness (checked above) does not guarantee master.sh has already created
# legacy-secret yet, so wait for the Secret itself before snapshotting it.
for attempt in {1..24}; do
  if kubectl -n encryption-109 get secret legacy-secret >/dev/null 2>&1; then break; fi
  sleep 5
  if [[ "$attempt" == 24 ]]; then echo "legacy-secret did not appear from control-plane bootstrap" >&2; exit 1; fi
done
install -d -m 0700 /var/lib/cks-109
legacy_uid=$(kubectl -n encryption-109 get secret legacy-secret -o jsonpath='{.metadata.uid}')
if [[ -z "$legacy_uid" ]]; then
  echo "FATAL: legacy-secret has no UID - cannot establish a trusted baseline" >&2
  exit 1
fi
legacy_raw=$(etcdctl-109 get /registry/secrets/encryption-109/legacy-secret --print-value-only | strings)
if [[ -z "$legacy_raw" ]]; then
  echo "FATAL: raw etcd read for legacy-secret returned nothing - cannot establish a trusted plaintext baseline" >&2
  exit 1
fi
if ! grep -Fq 'cks-109-legacy-plaintext' <<<"$legacy_raw"; then
  echo "FATAL: raw etcd value for legacy-secret does not contain the expected plaintext marker" >&2
  exit 1
fi
if grep -Fq 'k8s:enc:' <<<"$legacy_raw"; then
  echo "FATAL: raw etcd value for legacy-secret is already encrypted at bootstrap time - baseline would be invalid" >&2
  exit 1
fi
# All checks above passed: the baseline positively demonstrates the pre-encryption
# plaintext state (marker present AND no encryption prefix), rather than merely
# inferring "plaintext" from an empty/failed read that happens to also lack the prefix.
{
  echo "legacy_secret_uid=${legacy_uid}"
  echo "legacy_secret_raw_marker_present=yes"
  echo "legacy_secret_raw_had_no_enc_prefix=yes"
} >/var/lib/cks-109/legacy-secret-baseline.txt
chmod 0600 /var/lib/cks-109/legacy-secret-baseline.txt

# Baseline snapshot of ALL pre-existing Secret identities (namespace/name/uid) across
# the cluster, so the final checker can prove that EVERY Secret that existed before
# hardening - not just the two canaries (legacy-secret, encrypted-secret) - was actually
# migrated to k8s:enc: ciphertext once the learner removes the identity fallback.
# This capture must be fail-fast: a silently empty/missing baseline here would make the
# checker's full-corpus loop a no-op (defaulting all_migrated/all_readable to true),
# which would silently DISABLE the "all pre-existing Secrets were migrated" acceptance
# criterion instead of surfacing an infrastructure problem.
kubectl get secrets --all-namespaces \
  -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.metadata.uid}{"\n"}{end}' \
  >/var/lib/cks-109/all-secrets-baseline.txt
if [[ ! -s /var/lib/cks-109/all-secrets-baseline.txt ]]; then
  echo "FATAL: full Secret corpus baseline capture is empty - cannot establish trusted migration baseline" >&2
  exit 1
fi
if ! grep -q '^encryption-109 legacy-secret ' /var/lib/cks-109/all-secrets-baseline.txt; then
  echo "FATAL: full Secret corpus baseline does not contain the expected legacy-secret entry" >&2
  exit 1
fi
chmod 0600 /var/lib/cks-109/all-secrets-baseline.txt

echo "*** etcdctl $(etcdctl version | head -n1) is ready; use etcdctl-109 for the tunnelled lab endpoint"
