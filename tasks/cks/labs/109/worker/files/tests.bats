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
    echo "Expected a pre-encryption strings proof in $proof containing only the legacy marker."
    result=1
  fi
  record_result "$result"
}

@test "2. EncryptionConfiguration protects secrets with a 32-byte aescbc key" {
  config_check=$(ssh -o BatchMode=yes control-plane 'sudo test -f /etc/kubernetes/enc/encryption-config.yaml && sudo stat -c "%a" /etc/kubernetes/enc/encryption-config.yaml && sudo grep -E "^(apiVersion: apiserver.config.k8s.io/v1|kind: EncryptionConfiguration|  - secrets|  - aescbc:|  - identity:)" /etc/kubernetes/enc/encryption-config.yaml && sudo awk "/secret:/ {print \$2; exit}" /etc/kubernetes/enc/encryption-config.yaml | base64 -d | wc -c' 2>/dev/null || true)
  if [[ "$config_check" == *$'600'* && "$config_check" == *'apiVersion: apiserver.config.k8s.io/v1'* && "$config_check" == *'kind: EncryptionConfiguration'* && "$config_check" == *'  - secrets'* && "$config_check" == *'  - aescbc:'* && "$config_check" == *$'\n32' ]]; then
    result=0
  else
    echo "EncryptionConfiguration check failed: ${config_check:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "3. kube-apiserver mounts and uses EncryptionConfiguration and is ready" {
  manifest=$(ssh -o BatchMode=yes control-plane 'sudo grep -E -- "--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml|mountPath: /etc/kubernetes/enc|path: /etc/kubernetes/enc" /etc/kubernetes/manifests/kube-apiserver.yaml' 2>/dev/null || true)
  ready=$(kubectl --context "$CTX" get --raw='/readyz' 2>/dev/null || true)
  if [[ "$manifest" == *'--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml'* && "$manifest" == *'mountPath: /etc/kubernetes/enc'* && "$manifest" == *'path: /etc/kubernetes/enc'* && "$ready" == 'ok' ]]; then
    result=0
  else
    echo "apiserver_manifest=$(tr '\n' ' ' <<<"$manifest") ready=${ready:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "4. Legacy and new Secrets are re-encrypted and stored as k8s:enc ciphertext" {
  legacy_value=$(kubectl -n "$NS" --context "$CTX" get secret legacy-secret -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)
  fresh_value=$(kubectl -n "$NS" --context "$CTX" get secret encrypted-secret -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)
  set -o pipefail
  sudo etcdctl-109 get "$LEGACY_KEY" --print-value-only 2>/dev/null | grep -aq '^k8s:enc:aescbc:v1:'
  legacy_cipher=$?
  sudo etcdctl-109 get "$ENCRYPTED_KEY" --print-value-only 2>/dev/null | grep -aq '^k8s:enc:aescbc:v1:'
  fresh_cipher=$?
  set +o pipefail
  if [[ "$legacy_value" == 'cks-109-legacy-plaintext' && "$fresh_value" == 'cks-109-fresh-ciphertext' && "$legacy_cipher" -eq 0 && "$fresh_cipher" -eq 0 ]]; then
    result=0
  else
    echo "legacy_value=$legacy_value fresh_value=$fresh_value legacy_cipher=$legacy_cipher fresh_cipher=$fresh_cipher"
    result=1
  fi
  record_result "$result"
}

@test "5. Secret reader RBAC is least-privilege and its Pod does not mount a token" {
  allowed=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader get secret/encrypted-secret -n "$NS" 2>/dev/null)
  list_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader list secrets -n "$NS" 2>/dev/null)
  other_denied=$(kubectl auth can-i --context "$CTX" --as=system:serviceaccount:${NS}:secret-reader get secret/legacy-secret -n "$NS" 2>/dev/null)
  pod=$(kubectl -n "$NS" --context "$CTX" get pod secret-reader-109 -o json 2>/dev/null || true)
  sa=$(jq -r '.spec.serviceAccountName // empty' <<<"$pod" 2>/dev/null)
  automount=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  phase=$(jq -r '.status.phase // empty' <<<"$pod" 2>/dev/null)
  no_token_volume=$(jq -r '[.spec.volumes[]? | select(.projected != null and (.name | startswith("kube-api-access")))] | length == 0' <<<"$pod" 2>/dev/null)
  if [[ "$allowed" == yes && "$list_denied" == no && "$other_denied" == no && "$sa" == secret-reader && "$automount" == false && "$phase" == Running && "$no_token_volume" == true ]]; then
    result=0
  else
    echo "allowed=$allowed list=$list_denied other=$other_denied sa=$sa automount=$automount phase=$phase token_volume_absent=$no_token_volume"
    result=1
  fi
  record_result "$result"
}
