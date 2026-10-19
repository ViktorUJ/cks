#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
CTX="cluster1-admin@cluster1"
ETCD_VERSION="3.6.0"

echo "*** CKS lab 109 worker bootstrap"
until kubectl get nodes --context "$CTX" --no-headers >/dev/null 2>&1; do sleep 5; done

# The checker uses jq, Python PyYAML and strings. Do not rely on an undocumented
# package set in the shared work_pc_v2 image; provision missing dependencies.
missing_packages=()
command -v python3 >/dev/null 2>&1 || missing_packages+=(python3)
command -v jq >/dev/null 2>&1 || missing_packages+=(jq)
command -v strings >/dev/null 2>&1 || missing_packages+=(binutils)
command -v ssh >/dev/null 2>&1 || missing_packages+=(openssh-client)
python3 -c "import yaml" >/dev/null 2>&1 || missing_packages+=(python3-yaml)
python3 -c "from cryptography.hazmat.primitives.ciphers import Cipher" >/dev/null 2>&1 || missing_packages+=(python3-cryptography)
if ((${#missing_packages[@]})); then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing_packages[@]}"
fi
python3 -c "import yaml"

# The README/solution use "ssh control-plane", but the alias is not created by the shared
# worker template, and root login is keyed on the node for ubuntu only. This script, the
# Any root-run checker defaults to root@ - map the alias to ubuntu for both root and the
# student user.
CONTROL_PLANE_IP=$(kubectl get nodes --context "$CTX" -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
grep -q ' control-plane$' /etc/hosts || printf '%s control-plane\n' "$CONTROL_PLANE_IP" >> /etc/hosts
for ssh_home in /root /home/ubuntu; do
  install -d -m 0700 "$ssh_home/.ssh"
  printf 'Host control-plane\n  User ubuntu\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' >> "$ssh_home/.ssh/config"
  chmod 0600 "$ssh_home/.ssh/config"
done
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
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
# As on the exam, etcdctl is run ON the control-plane node with the standard kubeadm client
# certificates from /etc/kubernetes/pki/etcd. Ship the pinned binary there; nothing etcd-private
# is copied to the worker.
ssh -o BatchMode=yes control-plane 'sudo tee /usr/local/bin/etcdctl >/dev/null && sudo chmod 0755 /usr/local/bin/etcdctl' \
  <"$workdir/etcd-v${ETCD_VERSION}-linux-${etcd_arch}/etcdctl"
ssh -o BatchMode=yes control-plane 'etcdctl version | head -n1'

# Checker-side helper (the same standard command the learner runs on the control-plane).
etcd_get() {
  ssh -o BatchMode=yes control-plane "sudo ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get '$1' --print-value-only"
}

# The learner reads etcd on the control-plane and copies the proof here with scp.
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
legacy_raw=$(etcd_get /registry/secrets/encryption-109/legacy-secret | strings)
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
  # The complete `strings` output is bound to the observed bootstrap etcd bytes.
  # A handwritten marker alone no longer counts as the required raw-etcd proof.
  echo "legacy_secret_strings_sha256=$(printf '%s\n' "$legacy_raw" | sha256sum | awk '{print $1}')"
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
# Capture original content digests as well as identities: a migration must preserve
# every pre-existing Secret's payload and type, not merely its UID.
kubectl get secrets --all-namespaces -o json | python3 -c '
import hashlib, json, sys
items = json.load(sys.stdin)["items"]
for s in items:
    m = s["metadata"]
    identity = (m["namespace"], m["name"], m["uid"])
    payload = {"type": s.get("type"), "data": s.get("data") or {}, "immutable": s.get("immutable")}
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    print(*identity, hashlib.sha256(raw).hexdigest())
' > /var/lib/cks-109/all-secrets-baseline.txt
if [[ ! -s /var/lib/cks-109/all-secrets-baseline.txt ]] || \
  ! awk 'NF != 4 || ($4 !~ /^[0-9a-f]+$/ || length($4) != 64) { bad=1 } END { exit bad ? 1 : 0 }' /var/lib/cks-109/all-secrets-baseline.txt; then
  echo "FATAL: incomplete identity/data hash baseline" >&2
  exit 1
fi
if ! grep -q '^encryption-109 legacy-secret ' /var/lib/cks-109/all-secrets-baseline.txt; then
  echo "FATAL: full Secret corpus baseline does not contain legacy-secret" >&2
  exit 1
fi
chmod 0600 /var/lib/cks-109/all-secrets-baseline.txt

echo "*** etcdctl is installed on the control-plane (ssh control-plane); use the standard kubeadm etcd certificates in /etc/kubernetes/pki/etcd"
