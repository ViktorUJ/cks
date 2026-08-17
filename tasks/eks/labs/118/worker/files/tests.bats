#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-118"
ARGONS="argocd"
APP="demo-app"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Argo CD is installed and argocd-server is Ready" {
  echo '1' >> /var/work/tests/result/all
  ns=$(kubectl get ns "$ARGONS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  ready=$(kubectl get deploy argocd-server -n "$ARGONS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$ns" == "$ARGONS" ]] && [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "namespace=$ns argocd-server readyReplicas=$ready"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2. Application demo-app: correct source/destination, selfHeal+prune, Synced/Healthy" {
  echo '1' >> /var/work/tests/result/all
  repo=$(kubectl get application "$APP" -n "$ARGONS" \
    -o jsonpath='{.spec.source.repoURL}' 2>/dev/null)
  path=$(kubectl get application "$APP" -n "$ARGONS" \
    -o jsonpath='{.spec.source.path}' 2>/dev/null)
  dest_ns=$(kubectl get application "$APP" -n "$ARGONS" \
    -o jsonpath='{.spec.destination.namespace}' 2>/dev/null)
  self_heal=$(kubectl get application "$APP" -n "$ARGONS" \
    -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null)
  prune=$(kubectl get application "$APP" -n "$ARGONS" \
    -o jsonpath='{.spec.syncPolicy.automated.prune}' 2>/dev/null)
  sync=$(kubectl get application "$APP" -n "$ARGONS" \
    -o jsonpath='{.status.sync.status}' 2>/dev/null)
  health=$(kubectl get application "$APP" -n "$ARGONS" \
    -o jsonpath='{.status.health.status}' 2>/dev/null)
  if [[ "$repo" == *ViktorUJ/cks* ]] && [[ "$path" == "tasks/eks/labs/118/gitops-demo" ]] \
    && [[ "$dest_ns" == "$NS" ]] && [[ "$self_heal" == "true" ]] && [[ "$prune" == "true" ]] \
    && [[ "$sync" == "Synced" ]] && [[ "$health" == "Healthy" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "repo=$repo path=$path dest_ns=$dest_ns selfHeal=$self_heal prune=$prune sync=$sync health=$health"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. demo-app Deployment and demo-config ConfigMap are actually applied in eks-118" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy demo-app -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy demo-app -n "$NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  greeting=$(kubectl get configmap demo-config -n "$NS" \
    -o jsonpath='{.data.greeting}' 2>/dev/null)
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "2" ]] && [[ -n "$greeting" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "image=$image ready=$ready greeting=$greeting"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Drift artifact shows OutOfSync then self-heal back to Synced, replicas restored" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/drift.txt
  replicas=$(kubectl get deploy demo-app -n "$NS" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [[ -s "$f" ]] && grep -q 'OutOfSync' "$f" && grep -q 'Synced' "$f" \
    && [[ "$replicas" == "2" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not show OutOfSync/Synced; replicas=$replicas"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Sync waves: demo-config wave 0, demo-app wave 1, both applied and Synced" {
  echo '1' >> /var/work/tests/result/all
  cm_wave=$(kubectl get configmap demo-config -n "$NS" \
    -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}' 2>/dev/null)
  dep_wave=$(kubectl get deploy demo-app -n "$NS" \
    -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}' 2>/dev/null)
  sync=$(kubectl get application "$APP" -n "$ARGONS" \
    -o jsonpath='{.status.sync.status}' 2>/dev/null)
  if [[ "$cm_wave" == "0" ]] && [[ "$dep_wave" == "1" ]] && [[ "$sync" == "Synced" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cm_wave=$cm_wave dep_wave=$dep_wave sync=$sync"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Prune removes manual-extra while demo-app and demo-config survive" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/prune.txt
  extra=$(kubectl get configmap manual-extra -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null || true)
  demo_cm=$(kubectl get configmap demo-config -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  demo_dep=$(kubectl get deploy demo-app -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ -s "$f" ]] && grep -q 'manual-extra' "$f" && grep -qi 'prune' "$f" \
    && [[ -z "$extra" ]] && [[ "$demo_cm" == "demo-config" ]] && [[ "$demo_dep" == "demo-app" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty, or manual-extra=$extra still present, or demo objects missing"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Artifact explains sync status versus health status as two independent axes" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/health.txt
  if [[ -s "$f" ]] && grep -qi 'Synced' "$f" \
    && grep -Eqi 'Degraded|Progressing' "$f" \
    && grep -qi 'sync' "$f" && grep -qi 'health' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not explain Synced with Degraded/Progressing"
    result=1
  fi
  [ "$result" == "0" ]
}
