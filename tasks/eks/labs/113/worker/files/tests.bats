#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-113"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-113 exists and cluster starts on version 1.35" {
  echo '1' >> /var/work/tests/result/all
  ns=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  ver=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion": *"v1\.[0-9]*' | tail -n1 | grep -o '1\.[0-9]*')
  if [[ "$ns" == "$NS" ]] && [[ -n "$cluster" ]] && [[ "$ver" == "1.35" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ns=$ns cluster=$cluster kubectl_minor=$ver"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2. Artifact records upgrade insights and no blocking ERROR" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/upgrade_insights.json
  if [[ -s "$f" ]] && grep -qi 'insights' "$f" && ! grep -q '"status": *"ERROR"' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty, does not look like insights output, or has a blocking ERROR"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Control plane was upgraded in place to 1.36" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  # Задание 6 откатывает control plane обратно на 1.35, поэтому к моменту финальной
  # проверки текущая версия кластера уже не 1.36 - сам факт апгрейда ищем в истории
  # обновлений (aws eks list-updates/describe-update), а не в текущей cluster.version.
  ids=$(aws eks list-updates --name "$cluster" --query 'updateIds[]' --output text 2>/dev/null)
  found=0
  for id in $ids; do
    type=$(aws eks describe-update --name "$cluster" --update-id "$id" \
      --query 'update.type' --output text 2>/dev/null)
    status=$(aws eks describe-update --name "$cluster" --update-id "$id" \
      --query 'update.status' --output text 2>/dev/null)
    ver=$(aws eks describe-update --name "$cluster" --update-id "$id" \
      --query "update.params[?type=='Version'].value" --output text 2>/dev/null)
    if [[ "$type" == "VersionUpdate" ]] && [[ "$status" == "Successful" ]] \
       && [[ "$ver" == "1.36" ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" == "1" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cluster=$cluster: no Successful VersionUpdate to 1.36 found in update history"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Core addons were upgraded to versions compatible with 1.36" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  # coredns не привязан к version skew control plane так жёстко, как kube-proxy,
  # поэтому его финальную версию можно проверять напрямую.
  cd=$(aws eks describe-addon --cluster-name "$cluster" --addon-name coredns \
    --query 'addon.addonVersion' --output text 2>/dev/null)
  # kube-proxy по штатной процедуре отката (глава 39) откатывается на версию под 1.35
  # ДО отката control plane - иначе rollback readiness insight по kube-proxy version
  # skew блокирует rollback. Поэтому к моменту финальной проверки текущая версия
  # kube-proxy уже не v1.36.*, и факт апгрейда до 1.36 ищем в истории аддон-обновлений.
  ids=$(aws eks list-updates --name "$cluster" --addon-name kube-proxy \
    --query 'updateIds[]' --output text 2>/dev/null)
  found=0
  for id in $ids; do
    status=$(aws eks describe-update --name "$cluster" --addon-name kube-proxy \
      --update-id "$id" --query 'update.status' --output text 2>/dev/null)
    ver=$(aws eks describe-update --name "$cluster" --addon-name kube-proxy \
      --update-id "$id" --query "update.params[?type=='AddonVersion'].value" \
      --output text 2>/dev/null)
    if [[ "$status" == "Successful" ]] && [[ "$ver" == v1.36.* ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" == "1" ]] && [[ "$cd" == v1.14.* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "kube-proxy v1.36.* upgrade found=$found, coredns=$cd, expected v1.14.*"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Artifact records rollback readiness insights and no blocking ERROR/UNKNOWN" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/rollback_readiness.json
  if [[ -s "$f" ]] && grep -qi 'ROLLBACK_READINESS\|insights' "$f" \
     && ! grep -q '"status": *"ERROR"' "$f" && ! grep -q '"status": *"UNKNOWN"' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty, wrong content, or has blocking ERROR/UNKNOWN"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Control plane was rolled back to 1.35 as a VersionRollback update" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  ver=$(aws eks describe-cluster --name "$cluster" --query 'cluster.version' --output text 2>/dev/null)
  f=/var/work/tests/artifacts/6/rollback_update.txt
  if [[ "$ver" == "1.35" ]] && [[ -s "$f" ]] && grep -qi 'VersionRollback' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cluster=$cluster version=$ver, file=$f (must contain VersionRollback)"
    result=1
  fi
  [ "$result" == "0" ]
}
