#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="encryption-109"
LEGACY_KEY="/registry/secrets/${NS}/legacy-secret"
ENCRYPTED_KEY="/registry/secrets/${NS}/encrypted-secret"

record_result() {
  echo '1' >> /var/work/tests/result/all
  if [[ "$1" -eq 0 ]]; then echo '1' >> /var/work/tests/result/ok; fi
  return "$1"
}

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Evidence proves the bootstrap Secret was plaintext in raw etcd" {
  proof=/var/work/109/plaintext-proof.txt
  if [[ -s "$proof" ]] && grep -Fqx 'cks-109-legacy-plaintext' "$proof" && ! grep -Fq 'k8s:enc:' "$proof"; then
    result=0
  else
    echo "HINT: plaintext-proof.txt must contain the exact line 'cks-109-legacy-plaintext' and must NOT contain 'k8s:enc:' (that prefix means the value was already encrypted). Capture this evidence BEFORE creating any EncryptionConfiguration."
    echo "Expected a pre-encryption strings proof in $proof containing only the legacy marker."
    result=1
  fi
  record_result "$result"
}

@test "2. EncryptionConfiguration protects secrets with a 32-byte aescbc key" {
  config_check=$(ssh -o BatchMode=yes control-plane 'sudo test -f /etc/kubernetes/enc/encryption-config.yaml && sudo stat -c "%a %U:%G" /etc/kubernetes/enc/encryption-config.yaml && sudo stat -c "dir_perm=%a dir_owner=%U:%G" /etc/kubernetes/enc && sudo grep -E "^(apiVersion: apiserver.config.k8s.io/v1|kind: EncryptionConfiguration|  - secrets|  - aescbc:|  - identity:)" /etc/kubernetes/enc/encryption-config.yaml && sudo awk "/secret:/ {print \$2; exit}" /etc/kubernetes/enc/encryption-config.yaml | base64 -d | wc -c' 2>/dev/null || true)
  # File must be exactly "600 root:root" - checking mode alone would let e.g.
  # "ubuntu:ubuntu 0600" pass, which widens local access to the encryption key material
  # to a non-privileged/non-control-plane account.
  file_perm_owner_ok=$([[ "$config_check" == *$'600 root:root\n'* ]] && echo true || echo false)
  dir_owned_by_root=$([[ "$config_check" == *'dir_owner=root:root'* ]] && echo true || echo false)
  if [[ "$file_perm_owner_ok" == 'true' && "$dir_owned_by_root" == 'true' && "$config_check" == *'apiVersion: apiserver.config.k8s.io/v1'* && "$config_check" == *'kind: EncryptionConfiguration'* && "$config_check" == *'  - secrets'* && "$config_check" == *'  - aescbc:'* && "$config_check" == *$'\n32' ]]; then
    result=0
  else
    if [[ "$file_perm_owner_ok" != 'true' ]]; then
      echo "HINT: /etc/kubernetes/enc/encryption-config.yaml must be exactly mode 600 AND owned by root:root - it contains the encryption key material. A file with the right mode but a non-root owner (e.g. ubuntu:ubuntu) still widens local access and must be rejected. Use 'sudo chown root:root' and 'sudo chmod 600' on the file."
    elif [[ "$dir_owned_by_root" != 'true' ]]; then
      echo "HINT: The parent directory /etc/kubernetes/enc must be owned by root:root too."
    elif [[ "$config_check" != *'  - aescbc:'* ]]; then
      echo "HINT: The config must use the 'aescbc' provider, not identity-only or a different algorithm."
    elif [[ "$config_check" != *$'\n32' ]]; then
      echo "HINT: The base64-decoded 'secret:' value must be exactly 32 bytes for AES-256-CBC - check your key generation command (e.g. 'head -c 32 /dev/urandom | base64')."
    else
      echo "HINT: One of the required YAML markers (apiVersion, kind, resources: secrets) is missing or misspelled - check the file structure matches EncryptionConfiguration exactly."
    fi
    echo "EncryptionConfiguration check failed: ${config_check:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "3. kube-apiserver mounts and uses EncryptionConfiguration and is ready" {
  manifest_content=$(ssh -o BatchMode=yes control-plane 'sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml' 2>/dev/null || true)
  ready=$(kubectl --context "$CTX" get --raw='/readyz' 2>/dev/null || true)
  # Structural validation instead of unconnected string grep: a manifest could contain
  # the flag, an unrelated mountPath: /etc/kubernetes/enc on some OTHER container, and an
  # unrelated volume with path: /etc/kubernetes/enc that nothing actually mounts - a plain
  # substring grep cannot tell these apart from a genuinely wired-up, read-only mount on
  # the kube-apiserver container itself.
  structural_ok=$(python3 -c "
import sys, yaml
try:
    doc = yaml.safe_load(sys.stdin.read()) or {}
    containers = (doc.get('spec') or {}).get('containers') or []
    kapi = next((c for c in containers if c.get('name') == 'kube-apiserver'), None)
    if kapi is None:
        print('false'); sys.exit()
    cmd = kapi.get('command') or []
    has_flag = any(isinstance(a, str) and a == '--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml' for a in cmd)
    mounts = kapi.get('volumeMounts') or []
    mount = next((m for m in mounts if m.get('mountPath') == '/etc/kubernetes/enc'), None)
    has_readonly_mount = bool(mount) and mount.get('readOnly') is True
    vol_name = (mount or {}).get('name')
    volumes = (doc.get('spec') or {}).get('volumes') or []
    vol = next((v for v in volumes if v.get('name') == vol_name), None)
    has_matching_volume = bool(vol) and ((vol.get('hostPath') or {}).get('path') == '/etc/kubernetes/enc')
    print('true' if (has_flag and has_readonly_mount and has_matching_volume) else 'false')
except Exception:
    print('false')
" <<<"$manifest_content" 2>/dev/null || echo false)
  if [[ "$structural_ok" == 'true' && "$ready" == 'ok' ]]; then
    result=0
  else
    if [[ "$structural_ok" != 'true' ]]; then
      echo "HINT: kube-apiserver container needs ALL of: (1) --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml in 'command', (2) a volumeMount with mountPath: /etc/kubernetes/enc AND readOnly: true on the kube-apiserver container specifically, (3) a matching volume (same 'name' as the mount) with hostPath.path: /etc/kubernetes/enc. Having the flag and an unrelated mountPath/path elsewhere in the file is not enough - they must reference each other by volume name on the kube-apiserver container itself, and the mount must be readOnly."
    else
      echo "HINT: API server is not ready after the manifest edit. Check for a YAML syntax error or a missing/wrong path in the volume definition."
    fi
    echo "apiserver_manifest=$(tr '\n' ' ' <<<"$manifest_content") structural_ok=$structural_ok ready=${ready:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "4. Legacy and new Secrets are re-encrypted and stored as k8s:enc ciphertext" {
  legacy_value=$(kubectl -n "$NS" --context "$CTX" get secret legacy-secret -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)
  fresh_value=$(kubectl -n "$NS" --context "$CTX" get secret encrypted-secret -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)
  # Cross-check against the checker-owned bootstrap baseline (captured before the
  # learner could touch anything) so a delete+recreate of a same-named/same-value
  # legacy-secret cannot pass as a genuine in-place re-encryption of the original object.
  # The baseline directory/files are root-only (0700/0600) by design - check_result runs
  # bats as the unprivileged 'ubuntu' user, which cannot even traverse into a 0700
  # root-owned directory, so every read of these files MUST go through sudo, otherwise
  # baseline_uid/baseline_was_plaintext are silently empty and this test guarantees a
  # false FAIL for an otherwise-correct solution.
  baseline_uid=$(sudo awk -F= '/^legacy_secret_uid=/{print $2}' /var/lib/cks-109/legacy-secret-baseline.txt 2>/dev/null || true)
  baseline_marker_present=$(sudo awk -F= '/^legacy_secret_raw_marker_present=/{print $2}' /var/lib/cks-109/legacy-secret-baseline.txt 2>/dev/null || true)
  baseline_was_plaintext=$(sudo awk -F= '/^legacy_secret_raw_had_no_enc_prefix=/{print $2}' /var/lib/cks-109/legacy-secret-baseline.txt 2>/dev/null || true)
  current_uid=$(kubectl -n "$NS" --context "$CTX" get secret legacy-secret -o jsonpath='{.metadata.uid}' 2>/dev/null || true)
  set -o pipefail
  sudo etcdctl-109 get "$LEGACY_KEY" --print-value-only 2>/dev/null | grep -aq '^k8s:enc:aescbc:v1:'
  legacy_cipher=$?
  sudo etcdctl-109 get "$ENCRYPTED_KEY" --print-value-only 2>/dev/null | grep -aq '^k8s:enc:aescbc:v1:'
  fresh_cipher=$?
  set +o pipefail
  uid_matches_baseline=$([[ -n "$baseline_uid" && "$current_uid" == "$baseline_uid" ]] && echo true || echo false)
  # Full-corpus migration proof: every Secret that existed at bootstrap time (not just
  # the two canaries) must now be both API-readable and stored as k8s:enc ciphertext in
  # raw etcd - otherwise removing the identity fallback could leave unrelated
  # bootstrap/system Secrets unreadable or plaintext without either canary detecting it.
  # Same root-only baseline file access constraint as above: use sudo for both the
  # existence/non-empty check and the actual read. bootstrap now fails fast if this
  # capture is empty, but the checker still treats an empty/missing baseline as an
  # explicit infrastructure failure here (corpus_baseline_ok=false) rather than silently
  # defaulting all_migrated/all_readable to true, which would otherwise turn this
  # acceptance criterion into a no-op for every learner if bootstrap ever regressed.
  corpus_baseline_ok=false
  all_migrated=true
  all_readable=true
  if sudo test -s /var/lib/cks-109/all-secrets-baseline.txt 2>/dev/null; then
    corpus_baseline_ok=true
    while read -r base_ns base_name base_uid; do
      [[ -z "$base_name" ]] && continue
      cur_val=$(kubectl -n "$base_ns" --context "$CTX" get secret "$base_name" -o name 2>/dev/null || true)
      if [[ -z "$cur_val" ]]; then all_readable=false; continue; fi
      sudo etcdctl-109 get "/registry/secrets/${base_ns}/${base_name}" --print-value-only 2>/dev/null | grep -aq '^k8s:enc:aescbc:v1:' || all_migrated=false
    done < <(sudo cat /var/lib/cks-109/all-secrets-baseline.txt 2>/dev/null)
  fi
  final_config=$(ssh -o BatchMode=yes control-plane 'sudo cat /etc/kubernetes/enc/encryption-config.yaml' 2>/dev/null || true)
  ready=$(kubectl --context "$CTX" get --raw='/readyz' 2>/dev/null || true)
  if [[ "$legacy_value" == 'cks-109-legacy-plaintext' && "$fresh_value" == 'cks-109-fresh-ciphertext' \
    && "$legacy_cipher" -eq 0 && "$fresh_cipher" -eq 0 && "$final_config" != *'identity:'* && "$ready" == 'ok' \
    && "$baseline_marker_present" == 'yes' && "$baseline_was_plaintext" == 'yes' && "$uid_matches_baseline" == 'true' \
    && "$corpus_baseline_ok" == 'true' && "$all_readable" == 'true' && "$all_migrated" == 'true' ]]; then
    result=0
  else
    if [[ "$baseline_marker_present" != 'yes' || "$baseline_was_plaintext" != 'yes' ]]; then
      echo "HINT: The bootstrap baseline for legacy-secret is missing or invalid - this is a checker/bootstrap infrastructure issue, not a learner action; contact lab support if this persists."
    elif [[ "$corpus_baseline_ok" != 'true' ]]; then
      echo "HINT: The full Secret corpus baseline (captured at bootstrap) is missing or empty - this is a checker/bootstrap infrastructure issue, not a learner action; contact lab support if this persists."
    elif [[ "$uid_matches_baseline" != 'true' ]]; then
      echo "HINT: The current legacy-secret's UID does not match the one captured at bootstrap - this means the Secret was DELETED and RECREATED rather than re-encrypted in place. Use 'kubectl replace' (or 'kubectl get -o json | kubectl apply/replace -f -') on the EXISTING object, not delete+create."
    elif [[ "$legacy_cipher" -ne 0 ]]; then
      echo "HINT: The pre-existing 'legacy-secret' is still plaintext in etcd. Encryption at rest only applies to NEW writes - you must trigger a re-encryption (e.g. 'kubectl get secrets --all-namespaces -o json | kubectl replace -f -', or the standard rotation procedure) for existing Secrets to be rewritten."
    elif [[ "$fresh_cipher" -ne 0 ]]; then
      echo "HINT: A freshly created Secret ('encrypted-secret') is NOT stored as k8s:enc:aescbc ciphertext - check the EncryptionConfiguration from tasks 2-3 actually applied before this Secret was created."
    elif [[ "$all_readable" != 'true' ]]; then
      echo "HINT: At least one Secret that existed before you started this lab is no longer readable via the API - removing the 'identity' fallback before migrating ALL pre-existing Secrets (not just the two canaries) makes the un-migrated plaintext Secrets unreadable through the current provider chain. Re-add the identity fallback to recover access, migrate ALL pre-existing Secrets, verify ciphertext, and only then remove identity again."
    elif [[ "$all_migrated" != 'true' ]]; then
      echo "HINT: At least one Secret that existed before you started this lab is still plaintext in raw etcd - 'kubectl replace' must be applied to the FULL Secret corpus across all namespaces, not just legacy-secret and encrypted-secret."
    elif [[ "$final_config" == *'identity:'* ]]; then
      echo "HINT: encryption-config.yaml still lists 'identity:' as a provider - if it comes before aescbc, new writes may still use plaintext identity. For this task the final config should not offer identity as an active provider ahead of aescbc."
    elif [[ "$ready" != 'ok' ]]; then
      echo "HINT: API server is not ready after your re-encryption changes."
    fi
    echo "legacy_value=$legacy_value fresh_value=$fresh_value legacy_cipher=$legacy_cipher fresh_cipher=$fresh_cipher identity_present=$([[ "$final_config" == *'identity:'* ]] && echo yes || echo no) ready=$ready baseline_marker_present=$baseline_marker_present baseline_was_plaintext=$baseline_was_plaintext uid_matches_baseline=$uid_matches_baseline corpus_baseline_ok=$corpus_baseline_ok all_readable=$all_readable all_migrated=$all_migrated"
    result=1
  fi
  record_result "$result"
}

@test "5. Secret reader RBAC is least-privilege and its Pod does not mount a token" {
  allowed=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader get secret/encrypted-secret -n "$NS" 2>/dev/null)
  list_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader list secrets -n "$NS" 2>/dev/null)
  other_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader get secret/legacy-secret -n "$NS" 2>/dev/null)
  # A Role granting only "list secrets" excluded above would still let watch/create/
  # update/patch/delete on Secrets slip through unnoticed - probe each verb individually
  # against the specific named resource (and the broader "secrets" resource for verbs
  # that are meaningless with resourceNames, like create) to close that gap.
  watch_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader watch secret/encrypted-secret -n "$NS" 2>/dev/null)
  create_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader create secrets -n "$NS" 2>/dev/null)
  update_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader update secret/encrypted-secret -n "$NS" 2>/dev/null)
  patch_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader patch secret/encrypted-secret -n "$NS" 2>/dev/null)
  delete_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader delete secret/encrypted-secret -n "$NS" 2>/dev/null)
  sa_json=$(kubectl -n "$NS" --context "$CTX" get serviceaccount secret-reader -o json 2>/dev/null || true)
  sa_automount=$(jq -r '.automountServiceAccountToken' <<<"$sa_json" 2>/dev/null)
  pod=$(kubectl -n "$NS" --context "$CTX" get pod secret-reader-109 -o json 2>/dev/null || true)
  sa=$(jq -r '.spec.serviceAccountName // empty' <<<"$pod" 2>/dev/null)
  automount=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  phase=$(jq -r '.status.phase // empty' <<<"$pod" 2>/dev/null)
  no_token_volume=$(jq -r '[.spec.volumes[]? | select(.projected != null and (.name | startswith("kube-api-access")))] | length == 0' <<<"$pod" 2>/dev/null)
  if [[ "$allowed" == yes && "$list_denied" == no && "$other_denied" == no \
    && "$watch_denied" == no && "$create_denied" == no && "$update_denied" == no && "$patch_denied" == no && "$delete_denied" == no \
    && "$sa_automount" == 'false' && "$sa" == secret-reader && "$automount" == false && "$phase" == Running && "$no_token_volume" == true ]]; then
    result=0
  else
    if [[ "$allowed" != yes ]]; then
      echo "HINT: ServiceAccount 'secret-reader' cannot get secret 'encrypted-secret' - it needs a Role/RoleBinding granting 'get' on that specific resource name."
    elif [[ "$list_denied" != no ]]; then
      echo "HINT: ServiceAccount 'secret-reader' can 'list' secrets - this is broader than needed. Grant only 'get' on the specific named Secret via resourceNames, not a blanket 'list'/'get' on all secrets."
    elif [[ "$other_denied" != no ]]; then
      echo "HINT: ServiceAccount 'secret-reader' can read 'legacy-secret' too - the Role must use resourceNames to scope access to 'encrypted-secret' ONLY."
    elif [[ "$watch_denied" != no || "$update_denied" != no || "$patch_denied" != no || "$delete_denied" != no ]]; then
      echo "HINT: ServiceAccount 'secret-reader' can watch/update/patch/delete the Secret - the Role must grant ONLY the 'get' verb, nothing else, even scoped to the single resourceName."
    elif [[ "$create_denied" != no ]]; then
      echo "HINT: ServiceAccount 'secret-reader' can create secrets - the Role must not grant 'create' (resourceNames does not restrict 'create' anyway, since the object does not exist yet, so 'create' must simply be absent from verbs)."
    elif [[ "$sa_automount" != 'false' ]]; then
      echo "HINT: ServiceAccount 'secret-reader' itself must set automountServiceAccountToken: false (not just the Pod) - both levels are required by this task."
    elif [[ "$sa" != secret-reader || "$phase" != Running ]]; then
      echo "HINT: Pod 'secret-reader-109' must use serviceAccountName 'secret-reader' and be Running."
    elif [[ "$automount" != false || "$no_token_volume" != true ]]; then
      echo "HINT: Pod must have automountServiceAccountToken: false with no kube-api-access token volume - if this Pod does not call the Kubernetes API directly (it reads the Secret via env/volume, not via client-go), it does not need a token at all."
    fi
    echo "allowed=$allowed list=$list_denied other=$other_denied watch=$watch_denied create=$create_denied update=$update_denied patch=$patch_denied delete=$delete_denied sa_automount=$sa_automount sa=$sa automount=$automount phase=$phase token_volume_absent=$no_token_volume"
    result=1
  fi
  record_result "$result"
}
