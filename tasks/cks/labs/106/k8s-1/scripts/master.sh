#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** control-plane / workload node CKS lab 106 bootstrap"
until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# This one-node lab uses the control-plane as the dedicated workload node. The profile
# is node-local, so it is explicitly labelled and all exercise Pods must select it.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl label node "$(hostname)" security.cks.io/localhost-profiles-106=true --overwrite

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apparmor apparmor-utils
systemctl enable --now apparmor

# Task 1 now requires the STUDENT to transfer this profile from the worker
# (/opt/lab106-fixtures/k8s-106-deny-write) and load it into this node's kernel
# themselves - this script must NOT pre-place the profile in /etc/apparmor.d/ or leave
# it loaded in the kernel at hand-off time. But tests.bats for task 2 (enforce
# transition) still needs a checker-owned, pre-existing baseline proving that a write
# matching this profile's '/work/**' pattern actually SUCCEEDS while the profile is
# still in complain mode, BEFORE the student does anything - without that, a checker
# that only observes "write fails after the student's enforce change" cannot rule out
# the write having failed for some unrelated reason from the very start. To get this
# evidence WITHOUT leaving any trace of the profile behind for the student, this script
# loads a private, transient copy of the identical profile content from a staging path
# outside /etc/apparmor.d/, runs the same aa-exec write-probe used before, records the
# result, then fully unloads (apparmor_parser -R) and deletes that transient copy again
# - so the student's fixture starts completely clean (profile absent from both
# /etc/apparmor.d/ and the kernel's own profile list) while the checker still holds
# valid, checker-owned evidence of complain-mode behaviour to compare against later.
# Using ordinary 'allow' rules here (rather than an explicit 'deny /work/** w,') is
# intentional and required for the complain->enforce demonstration this lab relies on:
# an explicit 'deny' rule is a distinct rule qualifier that is enforced by the kernel
# regardless of the profile's overall enforce/complain mode, and is silent by default
# (no 'apparmor="DENIED"' audit event unless combined with 'audit deny') - see the
# official apparmor.d(5) manual page ('deny: Specifies that permissions requests that
# match the rule should be denied without logging') and apparmor(7) ('complain: for a
# given action, if the profile rules do not grant permission the action will be
# allowed, but the violation will be logged'). Relying on the default-deny fallthrough
# instead makes both the complain-mode baseline and the later enforce-mode kernel-denial
# check behave exactly as this lab's tasks describe.
mkdir -p /var/lib/cks-lab106-checker/staging
staging_profile=/var/lib/cks-lab106-checker/staging/k8s-106-deny-write
cat > "$staging_profile" <<'EOF'
#include <tunables/global>

profile k8s-106-deny-write flags=(attach_disconnected, complain, mediate_deleted) {
  #include <abstractions/base>

  /** rix,
  /work/** r,
}
EOF
apparmor_parser -r -W "$staging_profile"

# Checker-owned bootstrap baseline: prove that a write matching this profile's '/work/**'
# pattern actually SUCCEEDS while the (transient, checker-owned) profile is in complain
# mode, BEFORE the student ever sees the lab. Use 'aa-exec' to confine THIS probe
# process by the exact same loaded profile (matching what the student's container will
# experience later, once they load their own copy in task 1). Critically, the probe
# target MUST be the profile's actual '/work/**' path on the HOST filesystem (the same
# node-local path the student's Pod mounts an emptyDir onto), NOT a path under the
# checker's own storage directory - a probe against an unrelated path (e.g.
# /var/lib/cks-lab106-checker/work/...) would not be governed by the '/work/** r,' rule
# at all (it would fall under the profile's general '/** rix,' rule instead, which
# grants no 'w' anywhere), so its result would say nothing about whether the
# '/work/**' flow this lab's tasks actually exercise behaved correctly in complain
# mode. The probe therefore targets a real, temporary file directly under the host's
# own /work (created here for exactly this purpose, and removed again immediately after
# the probe) - the exact same absolute path prefix the student's Pod will read/write via
# its emptyDir mount. The baseline file records the profile name, mode, and exact probe
# path alongside the result, so tests.bats can validate those fields, not just a bare
# 'RC=0' that could otherwise have come from probing an unrelated, unguarded path. This
# baseline is captured once, at provision time, and stored read-only outside
# /var/work/tests (which the shared work_pc_v2 template makes world-writable), so the
# student cannot fabricate or backdate it. tests.bats always reads control-plane state
# over SSH with 'sudo' (unlike some other labs' worker-local, non-sudo checkers), so
# 0700/0400 is safe here without breaking the normal PASS path. This is still
# defense-in-depth, not a hardened boundary: the student has their own passwordless
# sudo on this same control-plane node (standard cloud image default), so a student who
# deliberately chooses to could still overwrite this baseline before check_result runs -
# a fully tamper-proof, purely local, self-hosted baseline is not achievable on this
# architecture without an off-host/third-party evidence channel that does not exist yet
# for this lab (see ADVERSARIAL_ACCEPTANCE_STANDARD.md, labs/106 entry, for the full
# writeup of this same limitation - which, unlike labs/105's equivalent note, is NOT an
# accepted architectural exception, since this checker (unlike labs/105's) already
# always reads control-plane state via sudo and could in principle use a stronger
# evidence channel; this is an open gap, not a signed-off trade-off. "checker-owned"/
# "independently" above refer only to this baseline's ORIGIN - captured by bootstrap
# before the student ever saw the lab - and to defense-in-depth against accidental
# modification, not to a hardened boundary against the same student's own deliberate
# sudo-escalation, on either this node or the worker station).
mkdir -p /var/lib/cks-lab106-checker
mkdir -p /work
baseline_probe_name="bootstrap-write-probe-$(date +%s%N)-$$.txt"
baseline_probe_target="/work/${baseline_probe_name}"
if aa-exec -p k8s-106-deny-write -- sh -c "printf baseline >'${baseline_probe_target}'" 2>/var/lib/cks-lab106-checker/bootstrap-write-probe.err; then
  BASELINE_WRITE_RC=0
else
  BASELINE_WRITE_RC=$?
fi
rm -f "${baseline_probe_target}"
printf 'baseline apparmor write probe: profile=k8s-106-deny-write mode=complain path=%s RC=%s\n' \
  "${baseline_probe_target}" "$BASELINE_WRITE_RC" \
  > /var/lib/cks-lab106-checker/bootstrap-baseline-1.txt
if [[ "$BASELINE_WRITE_RC" -ne 0 ]]; then
  echo "FATAL: bootstrap write probe under complain-mode profile k8s-106-deny-write failed unexpectedly (RC=$BASELINE_WRITE_RC) - complain mode must not block writes. See /var/lib/cks-lab106-checker/bootstrap-write-probe.err" >&2
  exit 1
fi

# Tear down the transient copy completely: the student's fixture must start with the
# profile absent from both the kernel's own profile list and /etc/apparmor.d/ - they
# deliver and load their own copy from the worker fixture in task 1.
apparmor_parser -R "$staging_profile"
rm -f "$staging_profile"
rmdir /var/lib/cks-lab106-checker/staging 2>/dev/null || true

# Task 9 seed: a second profile with a genuine syntax error, written to disk but never
# loaded. The student must fix the syntax and load it with apparmor_parser -r -v.
broken_profile=/etc/apparmor.d/k8s-106-broken-profile
cat > "$broken_profile" <<'EOF'
#include <tunables/global>

profile k8s-106-broken-profile flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  /** rix,
  deny /work/** w
}
EOF

# Checker-owned bootstrap baseline for task 9: independently capture the parser's error
# on THIS never-loaded, still-broken profile file, BEFORE the student is handed the lab.
# The task also asks the student to save their own parser-error evidence into
# /var/work/tests/artifacts/8/apparmor-debug.txt (artifact directory kept at its
# original internal number, unrelated to the task's displayed number) - but that file
# lives inside
# /var/work/tests, which the shared work_pc_v2 bootstrap template makes world-writable,
# so a student COULD in principle write a fabricated 'syntax error' string into it AFTER
# already fixing the profile, with no way for a checker that only reads that one file to
# tell the difference. This bootstrap-time capture is independent, checker-owned
# evidence of the ORIGINAL broken state that does not rely on trusting the student's own
# artifact for that specific fact.
if apparmor_parser -Q "$broken_profile" >/var/lib/cks-lab106-checker/bootstrap-baseline-2.txt 2>&1; then
  echo "FATAL: bootstrap parser probe on $broken_profile succeeded, but this profile is supposed to contain a genuine syntax error - task 9's seed profile is broken." >&2
  exit 1
fi
if ! grep -qi 'syntax error' /var/lib/cks-lab106-checker/bootstrap-baseline-2.txt; then
  echo "FATAL: bootstrap parser probe on $broken_profile did not report 'syntax error' as expected - task 9's seed profile may have a different kind of failure than intended." >&2
  exit 1
fi

# Lock down the checker-owned baseline directory now that both bootstrap-time probes
# (task 2's write baseline and task 9's parser-error baseline) have been captured. See
# the note above baseline-1 for why 0700/0400 here is safe (this checker always reads
# control-plane state over SSH with 'sudo') and for the honest architectural limitation
# (student has their own passwordless sudo on this same node, so this is
# defense-in-depth, not a hardened boundary).
chown -R root:root /var/lib/cks-lab106-checker
chmod 0700 /var/lib/cks-lab106-checker
chmod 0400 /var/lib/cks-lab106-checker/bootstrap-baseline-1.txt /var/lib/cks-lab106-checker/bootstrap-baseline-2.txt

# Task 5's seccomp profile is intentionally NOT pre-placed here: it is delivered only
# on the worker (/opt/lab106-fixtures/cks-106-deny-unshare.json) and the student must
# copy it to /var/lib/kubelet/seccomp/profiles/ on this node themselves.

echo "*** CKS lab 106 node-local baselines are ready (AppArmor profile and seccomp profile are delivered on the worker; nothing is pre-installed on this node)"
