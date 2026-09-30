#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
echo "*** worker PC CKS lab 105"

until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,8,9,10}
chown -R ubuntu:ubuntu /var/work/tests/artifacts

# The solution/README use bare "ssh $CP" and "ssh docker-host". Fresh nodes are not in
# known_hosts, so without this every non-interactive ssh fails with "Host key verification
# failed". Node names are instance hostnames (ip-10-...), aliases come from /etc/hosts.
for ssh_home in /root /home/ubuntu; do
  install -d -m 0700 "$ssh_home/.ssh"
  printf 'Host ip-10-* k8s1_* docker-host\n  User ubuntu\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' >> "$ssh_home/.ssh/config"
  chmod 0600 "$ssh_home/.ssh/config"
done
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Cache recovery context before the firewall exercise. A correct source-scoped rule keeps
# worker -> API available; the cached name remains useful if a student makes a mistake.
kubectl get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}' > /var/work/tests/cp-name 2>/dev/null || true
chown ubuntu:ubuntu /var/work/tests/cp-name 2>/dev/null || true

# A real workload is part of the firewall health check. It must stay Ready and retain an
# HTTP path to kubernetes.default.svc after UFW is enabled.
kubectl create namespace cks-105-health --dry-run=client -o yaml | kubectl apply -f -
kubectl create deployment health-probe -n cks-105-health \
  --image=curlimages/curl:8.11.1 --dry-run=client -o yaml -- sleep 3600 | kubectl apply -f -
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=180s

# Checker-owned baseline storage for task 3 (UFW). NOTE: /var/work/tests itself is made
# world-writable (chmod -R 777) by the shared work_pc_v2 bootstrap template, so nothing
# stored inside /var/work/tests - regardless of its own owner/mode - is actually
# checker-owned: a world-writable PARENT directory lets any local account delete and
# recreate a root:root 0444 file inside it (Unix delete/create permission is governed by
# the directory, not the file). This baseline therefore lives in a SEPARATE directory
# outside /var/work/tests.
#
# IMPORTANT ARCHITECTURAL LIMITATION (documented in ADVERSARIAL_ACCEPTANCE_STANDARD.md):
# this lab's own 'check_result' (from the shared work_pc_v2 template) runs 'bats
# /var/work/tests/tests.bats' WITHOUT sudo, as the 'ubuntu' account - so tests.bats itself
# must be able to read this baseline WITHOUT sudo for the normal PASS path to work at
# all. The directory therefore needs search+read (0711, not 0700) so 'ubuntu' can stat/cat
# the files inside it. Because 'ubuntu' also has passwordless NOPASSWD sudo on this same
# host (standard Ubuntu cloud image default, not overridden anywhere in this lab's
# bootstrap), a student who deliberately uses 'sudo' can still rewrite this baseline and
# restore root:root/0444 before running check_result - a fully tamper-proof, purely local,
# self-hosted checker baseline is not achievable on this architecture. This 0711/0444
# scheme is defense-in-depth against accidental/incidental modification (e.g. a stray
# 'chmod -R' by the student while working on unrelated tasks), NOT a claim of a hardened
# adversarial trust boundary against a student who deliberately escalates via sudo.
install -d -m 0711 -o root -g root /var/lib/cks-lab105-checker

# Checker-owned baseline for task 3 (UFW), captured BEFORE the lab is handed to the
# student and BEFORE any UFW change exists on the node. This is independent of anything
# the student can write into their own artifacts/3/preflight.txt: a fabricated or
# post-hardening "baseline" line cannot substitute for this bootstrap-time evidence, and
# tests.bats compares the post-hardening state against THIS file, not just the student's.
CP_NAME=$(cat /var/work/tests/cp-name 2>/dev/null || true)
NODE_IP=$(kubectl get node "$CP_NAME" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
if [[ -n "$NODE_IP" ]]; then
  set +e
  BOOTSTRAP_KUBELET_CODE=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 \
    "https://${NODE_IP}:10250/healthz")
  BOOTSTRAP_KUBELET_RC=$?
  set -e
else
  BOOTSTRAP_KUBELET_RC=1
  BOOTSTRAP_KUBELET_CODE="000"
fi
printf 'node_ip=%s\nbootstrap baseline kubelet 10250: CURL_EXIT=%s HTTPCODE=%s\n' \
  "$NODE_IP" "$BOOTSTRAP_KUBELET_RC" "$BOOTSTRAP_KUBELET_CODE" \
  > /var/lib/cks-lab105-checker/bootstrap-baseline-3.txt

# Checker-owned baseline hash of the UFW framework rule files on the control plane,
# captured BEFORE the student can touch anything. 'ufw show added'/'ufw status' only
# reflect rules added through the ufw CLI; a student could instead hand-edit
# /etc/ufw/before*.rules or /etc/ufw/after*.rules directly to open an extra ingress path
# that never shows up in either report. Comparing a post-hardening hash against this
# baseline catches that bypass. This capture is fail-fast: an incomplete/failed capture
# must not silently hand out the lab with a missing reference baseline (see below).
UFW_FRAMEWORK_FILES='/etc/ufw/before.rules /etc/ufw/before6.rules /etc/ufw/after.rules /etc/ufw/after6.rules'
if [[ -z "$CP_NAME" ]]; then
  echo "FATAL: could not determine control-plane node name; cannot capture UFW framework baseline" >&2
  exit 1
fi
# worker.sh runs as root here, so a bare "ssh $CP_NAME" would default to root@ - root
# login is not permitted/keyed on the control-plane node. Use the ubuntu account (the one
# actually authorized) and sudo on the remote command instead, matching how tests.bats
# (which runs as the ubuntu user) reaches the same node.
UFW_FRAMEWORK_BASELINE=$(ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=8 "ubuntu@$CP_NAME" \
  "sudo sha256sum $UFW_FRAMEWORK_FILES 2>&1 | sort -k2") || {
  echo "FATAL: SSH to control plane '$CP_NAME' failed while capturing the UFW framework baseline" >&2
  exit 1
}
UFW_FRAMEWORK_LINE_COUNT=$(printf '%s\n' "$UFW_FRAMEWORK_BASELINE" | grep -cE '^[0-9a-f]{64}[[:space:]]+/etc/ufw/')
if [[ "$UFW_FRAMEWORK_LINE_COUNT" -ne 4 ]]; then
  echo "FATAL: expected exactly 4 valid SHA-256 lines for the UFW framework baseline, got $UFW_FRAMEWORK_LINE_COUNT. Raw output: $UFW_FRAMEWORK_BASELINE" >&2
  exit 1
fi
printf '%s\n' "$UFW_FRAMEWORK_BASELINE" > /var/lib/cks-lab105-checker/bootstrap-ufw-framework-baseline.txt

# Lock down ownership/mode as defense in depth - but the REAL trust boundary is the
# directory itself (0711 root:root, created above), not these per-file bits: a
# world-writable parent would make root:root 0444 on the file meaningless (see note
# above). Both properties are checked in tests.bats.
chown root:root /var/lib/cks-lab105-checker/bootstrap-baseline-3.txt
chmod 0444 /var/lib/cks-lab105-checker/bootstrap-baseline-3.txt
chown root:root /var/lib/cks-lab105-checker/bootstrap-ufw-framework-baseline.txt
chmod 0444 /var/lib/cks-lab105-checker/bootstrap-ufw-framework-baseline.txt

echo "*** cluster and SSH targets are ready; use check_result after completing the tasks"
