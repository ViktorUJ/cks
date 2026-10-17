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
  local proof=/var/work/109/plaintext-proof.txt
  local baseline=/var/lib/cks-109/legacy-secret-baseline.txt
  local expected actual marker plaintext
  expected=$(sudo awk -F= '/^legacy_secret_strings_sha256=/{print $2}' "$baseline" 2>/dev/null || true)
  marker=$(sudo awk -F= '/^legacy_secret_raw_marker_present=/{print $2}' "$baseline" 2>/dev/null || true)
  plaintext=$(sudo awk -F= '/^legacy_secret_raw_had_no_enc_prefix=/{print $2}' "$baseline" 2>/dev/null || true)
  actual=$(sha256sum "$proof" 2>/dev/null | awk '{print $1}')
  if [[ -s "$proof" && "$marker" == yes && "$plaintext" == yes &&
        "$expected" =~ ^[0-9a-f]{64}$ && "$actual" == "$expected" &&
        "$(grep -Fq 'k8s:enc:' "$proof" && echo yes || echo no)" == no ]]; then
    result=0
  else
    echo "HINT: capture the complete pre-encryption raw etcd value with 'sudo etcdctl-109 get ... --print-value-only | strings | tee /var/work/109/plaintext-proof.txt' BEFORE changing encryption. A manually typed marker does not match the checker-owned bootstrap fingerprint."
    result=1
  fi
  record_result "$result"
}

# Return the first aescbc key name only for a structurally valid and effective
# Secrets encryption rule. For final state, migration-only identity must be gone.
check_109_encryption_config() {
  local phase="$1" contents
  contents=$(ssh -o BatchMode=yes control-plane \
    'sudo cat /etc/kubernetes/enc/encryption-config.yaml' 2>/dev/null) || return 1
  CKS109_PHASE="$phase" python3 -c '
import base64, os, re, sys, yaml
try:
    obj=yaml.safe_load(sys.stdin.read())
    assert isinstance(obj,dict)
    assert obj.get("apiVersion")=="apiserver.config.k8s.io/v1"
    assert obj.get("kind")=="EncryptionConfiguration"
    entries=obj.get("resources")
    assert isinstance(entries,list) and entries
    # Wildcards applying to core Secrets cannot precede/mask our explicit rule.
    matching=[]
    for entry in entries:
        assert isinstance(entry,dict) and isinstance(entry.get("resources"),list)
        hits=any(x in ("secrets","*.","*.*") for x in entry["resources"])
        if hits: matching.append(entry)
    assert len(matching)==1
    entry=matching[0]
    assert "secrets" in entry["resources"]
    providers=entry.get("providers")
    assert isinstance(providers,list) and providers
    assert isinstance(providers[0],dict) and set(providers[0])=={"aescbc"}
    if os.environ["CKS109_PHASE"]=="final":
        assert len(providers)==1
    else:
        assert len(providers) in (1,2)
        if len(providers)==2:
            assert providers[1]=={"identity":{}}
    aescbc=providers[0]["aescbc"]
    assert isinstance(aescbc,dict) and isinstance(aescbc.get("keys"),list)
    assert len(aescbc["keys"])>=1
    names=set()
    for key in aescbc["keys"]:
        assert isinstance(key,dict) and set(key)=={"name","secret"}
        assert isinstance(key["name"],str) and re.fullmatch(r"[A-Za-z0-9_-]+",key["name"])
        assert key["name"] not in names
        names.add(key["name"])
        raw=base64.b64decode(key["secret"],validate=True)
        assert len(raw)==32
    print(aescbc["keys"][0]["name"])
except Exception:
    sys.exit(1)
' <<<"$contents"
}

@test "2. EncryptionConfiguration protects secrets with a 32-byte aescbc key" {
  local permissions keyname
  permissions=$(ssh -o BatchMode=yes control-plane \
    'sudo stat -c "%a %U:%G" /etc/kubernetes/enc/encryption-config.yaml && sudo stat -c "%a %U:%G" /etc/kubernetes/enc && sudo test ! -L /etc/kubernetes/enc/encryption-config.yaml && sudo test ! -L /etc/kubernetes/enc' 2>/dev/null || true)
  keyname=$(check_109_encryption_config initial 2>/dev/null || true)
  if [[ "$permissions" == $'600 root:root\n700 root:root' && -n "$keyname" ]]; then
    result=0
  else
    echo "HINT: use root-owned 0700 directory and root-owned 0600 non-symlink configuration file. The effective 'secrets' rule must use aescbc FIRST, with 32-byte strictly decoded base64 key; optional legacy identity must be LAST."
    echo "permissions=$permissions effective_key=${keyname:-invalid}"
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
  # A modified manifest is not evidence that its flags reached the live process.
  live_flag=$(ssh -o BatchMode=yes control-plane 'sudo bash -s' 2>/dev/null <<'REMOTE' || true
set -euo pipefail
for pid in $(pgrep -x kube-apiserver || true); do
  if tr '\000' '\n' <"/proc/$pid/cmdline" | grep -Fxq -- '--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml'; then
    echo true
    exit 0
  fi
done
echo false
REMOTE
)
  if [[ "$structural_ok" == 'true' && "$ready" == 'ok' && "$live_flag" == true ]]; then
    result=0
  else
    if [[ "$structural_ok" != 'true' ]]; then
      echo "HINT: kube-apiserver container needs ALL of: (1) --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml in 'command', (2) a volumeMount with mountPath: /etc/kubernetes/enc AND readOnly: true on the kube-apiserver container specifically, (3) a matching volume (same 'name' as the mount) with hostPath.path: /etc/kubernetes/enc. Having the flag and an unrelated mountPath/path elsewhere in the file is not enough - they must reference each other by volume name on the kube-apiserver container itself, and the mount must be readOnly."
    else
      echo "HINT: API server must be ready AND its LIVE kube-apiserver process must run with --encryption-provider-config. Check static Pod rollout and /proc/<pid>/cmdline on control-plane."
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
  all_uuids_preserved=true
  if sudo test -s /var/lib/cks-109/all-secrets-baseline.txt 2>/dev/null; then
    corpus_baseline_ok=true
    while read -r base_ns base_name base_uid; do
      [[ -z "$base_name" ]] && continue
      cur_uid=$(kubectl -n "$base_ns" --context "$CTX" get secret "$base_name" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)
      if [[ -z "$cur_uid" ]]; then all_readable=false; continue; fi
      [[ "$cur_uid" == "$base_uid" ]] || all_uuids_preserved=false
      sudo etcdctl-109 get "/registry/secrets/${base_ns}/${base_name}" --print-value-only 2>/dev/null | grep -aq '^k8s:enc:aescbc:v1:' || all_migrated=false
    done < <(sudo cat /var/lib/cks-109/all-secrets-baseline.txt 2>/dev/null)
  fi
  final_config=$(ssh -o BatchMode=yes control-plane 'sudo cat /etc/kubernetes/enc/encryption-config.yaml' 2>/dev/null || true)
  final_keyname=$(check_109_encryption_config final 2>/dev/null || true)
  # The final disk configuration must have been loaded by the currently running process.
  # A healthy OLD process plus a just-edited YAML file is not proof of effective state.
  config_loaded=$(ssh -o BatchMode=yes control-plane 'sudo bash -s' 2>/dev/null <<'REMOTE' || true
set -euo pipefail
config_mtime=$(stat -c %Y /etc/kubernetes/enc/encryption-config.yaml)
manifest_mtime=$(stat -c %Y /etc/kubernetes/manifests/kube-apiserver.yaml)
now=$(date +%s)
for pid in $(pgrep -x kube-apiserver || true); do
  age=$(ps -o etimes= -p "$pid" | tr -d ' ')
  [[ "$age" =~ ^[0-9]+$ ]] || continue
  start=$((now - age))
  if ((start + 2 >= config_mtime && start + 2 >= manifest_mtime)) &&       tr '\000' '\n' <"/proc/$pid/cmdline" | grep -Fxq -- '--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml'; then
    echo true
    exit 0
  fi
done
echo false
REMOTE
)
  ready=$(kubectl --context "$CTX" get --raw='/readyz' 2>/dev/null || true)
  if [[ "$legacy_value" == 'cks-109-legacy-plaintext' && "$fresh_value" == 'cks-109-fresh-ciphertext' \
    && "$legacy_cipher" -eq 0 && "$fresh_cipher" -eq 0 && -n "$final_keyname" && "$config_loaded" == true && "$ready" == 'ok' \
    && "$baseline_marker_present" == 'yes' && "$baseline_was_plaintext" == 'yes' && "$uid_matches_baseline" == 'true' \
    && "$corpus_baseline_ok" == 'true' && "$all_readable" == 'true' && "$all_migrated" == 'true' && "$all_uuids_preserved" == 'true' ]]; then
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
    elif [[ "$all_uuids_preserved" != 'true' ]]; then
      echo "HINT: A pre-existing Secret was deleted and recreated rather than re-encrypted in place (UID changed); restore original object/redo this disposable lab."
    elif [[ "$all_migrated" != 'true' ]]; then
      echo "HINT: At least one Secret that existed before you started this lab is still plaintext in raw etcd - 'kubectl replace' must be applied to the FULL Secret corpus across all namespaces, not just legacy-secret and encrypted-secret."
    elif [[ "$config_loaded" != true ]]; then
      echo "HINT: kube-apiserver must have restarted AFTER the final EncryptionConfiguration edit; the live process is older than the file or does not have the required flag."
    elif [[ -z "$final_keyname" ]]; then
      echo "HINT: the FINAL effective Secrets rule must contain ONLY an aescbc provider with a valid 32-byte key; remove all migration-only fallbacks and other primary providers."
    elif [[ "$ready" != 'ok' ]]; then
      echo "HINT: API server is not ready after your re-encryption changes."
    fi
    echo "legacy_value=$legacy_value fresh_value=$fresh_value legacy_cipher=$legacy_cipher fresh_cipher=$fresh_cipher identity_present=$([[ "$final_config" == *'identity:'* ]] && echo yes || echo no) ready=$ready baseline_marker_present=$baseline_marker_present baseline_was_plaintext=$baseline_was_plaintext uid_matches_baseline=$uid_matches_baseline corpus_baseline_ok=$corpus_baseline_ok all_readable=$all_readable all_migrated=$all_migrated all_uuids_preserved=$all_uuids_preserved final_keyname=${final_keyname:-invalid} config_loaded=$config_loaded"
    result=1
  fi
  record_result "$result"
}

@test "5. Secret reader RBAC is least-privilege and its Pod does not mount a token" {
  allowed=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader get secret/encrypted-secret -n "$NS" 2>/dev/null || true)
  list_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader list secrets -n "$NS" 2>/dev/null || true)
  other_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader get secret/legacy-secret -n "$NS" 2>/dev/null || true)
  # A Role granting only "list secrets" excluded above would still let watch/create/
  # update/patch/delete on Secrets slip through unnoticed - probe each verb individually
  # against the specific named resource (and the broader "secrets" resource for verbs
  # that are meaningless with resourceNames, like create) to close that gap.
  watch_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader watch secret/encrypted-secret -n "$NS" 2>/dev/null || true)
  create_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader create secrets -n "$NS" 2>/dev/null || true)
  update_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader update secret/encrypted-secret -n "$NS" 2>/dev/null || true)
  patch_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader patch secret/encrypted-secret -n "$NS" 2>/dev/null || true)
  delete_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader delete secret/encrypted-secret -n "$NS" 2>/dev/null || true)
  role_json=$(kubectl -n "$NS" --context "$CTX" get role secret-reader-109 -o json 2>/dev/null || true)
  binding_json=$(kubectl -n "$NS" --context "$CTX" get rolebinding secret-reader-109 -o json 2>/dev/null || true)
  role_ok=$(jq -r '(.metadata.name=="secret-reader-109") and (.metadata.namespace=="encryption-109") and (.rules == [{"apiGroups":[""],"resources":["secrets"],"resourceNames":["encrypted-secret"],"verbs":["get"]])' <<<"$role_json" 2>/dev/null || true)
  binding_ok=$(jq -r '(.metadata.name=="secret-reader-109") and (.metadata.namespace=="encryption-109") and (.roleRef.kind=="Role") and (.roleRef.apiGroup=="rbac.authorization.k8s.io") and (.roleRef.name=="secret-reader-109") and ((.subjects // [])|length == 1) and (.subjects[0].kind=="ServiceAccount") and (.subjects[0].name=="secret-reader") and (.subjects[0].namespace=="encryption-109")' <<<"$binding_json" 2>/dev/null || true)
  sa_json=$(kubectl -n "$NS" --context "$CTX" get serviceaccount secret-reader -o json 2>/dev/null || true)
  sa_automount=$(jq -r '.automountServiceAccountToken' <<<"$sa_json" 2>/dev/null)
  pod=$(kubectl -n "$NS" --context "$CTX" get pod secret-reader-109 -o json 2>/dev/null || true)
  sa=$(jq -r '.spec.serviceAccountName // empty' <<<"$pod" 2>/dev/null)
  automount=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  phase=$(jq -r '.status.phase // empty' <<<"$pod" 2>/dev/null)
  # automount:false only disables automatic injection; a manually projected
  # serviceAccountToken remains a valid source of API credentials under ANY name.
  no_token_volume=$(jq -r '[(.spec.volumes // [])[] | select(.name | startswith("kube-api-access"))] | length == 0' <<<"$pod" 2>/dev/null)
  no_manual_token=$(jq -r '[(.spec.volumes // [])[] | .projected.sources[]? | select(has("serviceAccountToken"))] | length == 0' <<<"$pod" 2>/dev/null)
  image_ok=$(jq -r '(.spec.containers | length == 1) and (.spec.containers[0].image == "registry.k8s.io/pause:3.10")' <<<"$pod" 2>/dev/null)
  if [[ "$allowed" == yes && "$list_denied" == no && "$other_denied" == no \
    && "$watch_denied" == no && "$create_denied" == no && "$update_denied" == no && "$patch_denied" == no && "$delete_denied" == no \
    && "$role_ok" == true && "$binding_ok" == true && "$image_ok" == true \
    && "$sa_automount" == 'false' && "$sa" == secret-reader && "$automount" == false && "$phase" == Running && "$no_token_volume" == true && "$no_manual_token" == true ]]; then
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
    elif [[ "$role_ok" != true || "$binding_ok" != true ]]; then
      echo "HINT: create EXACT Role secret-reader-109 with ONLY get on Secret encrypted-secret and EXACT RoleBinding secret-reader-109 to ServiceAccount secret-reader."
    elif [[ "$image_ok" != true ]]; then
      echo "HINT: Pod secret-reader-109 must run the required registry.k8s.io/pause:3.10 container image."
    elif [[ "$no_manual_token" != true ]]; then
      echo "HINT: manually projected serviceAccountToken volumes still supply API credentials even with automount:false; remove all such projections."
    elif [[ "$sa_automount" != 'false' ]]; then
      echo "HINT: ServiceAccount 'secret-reader' itself must set automountServiceAccountToken: false (not just the Pod) - both levels are required by this task."
    elif [[ "$sa" != secret-reader || "$phase" != Running ]]; then
      echo "HINT: Pod 'secret-reader-109' must use serviceAccountName 'secret-reader' and be Running."
    elif [[ "$automount" != false || "$no_token_volume" != true ]]; then
      echo "HINT: Pod must have automountServiceAccountToken: false with no kube-api-access token volume - if this Pod does not call the Kubernetes API directly (it reads the Secret via env/volume, not via client-go), it does not need a token at all."
    fi
    echo "allowed=$allowed list=$list_denied other=$other_denied watch=$watch_denied create=$create_denied update=$update_denied patch=$patch_denied delete=$delete_denied sa_automount=$sa_automount sa=$sa automount=$automount phase=$phase token_volume_absent=$no_token_volume manual_token_absent=$no_manual_token role_ok=$role_ok binding_ok=$binding_ok image_ok=$image_ok"
    result=1
  fi
  record_result "$result"
}
