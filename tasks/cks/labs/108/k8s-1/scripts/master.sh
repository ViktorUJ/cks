#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** master node cks lab 108 k8s-1"
until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# Лаба одноузловая: пользовательские тестовые Pod допускаются на control-plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: policy-108
  labels:
    purpose: cks-kyverno-lab
EOF

# Checker-owned baseline for task 6: record the --enable-admission-plugins value that
# kubeadm actually configured BEFORE the student edits the static manifest to add
# ImagePolicyWebhook. Task 6 explicitly requires ADDING to this list, not replacing it -
# a checker that only greps for the substring 'ImagePolicyWebhook' cannot tell whether
# any originally-enabled plugin (e.g. NodeRestriction, if kubeadm set it explicitly) was
# dropped in the process. This file is read-only evidence of the pre-change state;
# tests.bats parses it alongside the CURRENT manifest to require every originally-listed
# plugin to still be present. If the flag is absent entirely in the baseline (kubeadm on
# this Kubernetes version may rely on built-in defaults without an explicit
# --enable-admission-plugins flag), the file records that explicitly so the checker does
# not require preserving a flag that never existed pre-change.
baseline_flag=$(grep -oE -- '--enable-admission-plugins=[^"[:space:]]*' /etc/kubernetes/manifests/kube-apiserver.yaml || true)
mkdir -p /var/lib/cks-lab108-checker
if [[ -n "$baseline_flag" ]]; then
  echo "${baseline_flag#--enable-admission-plugins=}" > /var/lib/cks-lab108-checker/baseline-admission-plugins.txt
else
  echo "" > /var/lib/cks-lab108-checker/baseline-admission-plugins.txt
fi
chown root:root /var/lib/cks-lab108-checker /var/lib/cks-lab108-checker/baseline-admission-plugins.txt
chmod 0755 /var/lib/cks-lab108-checker
chmod 0644 /var/lib/cks-lab108-checker/baseline-admission-plugins.txt

# Задание 7 использует Gatekeeper (OPA) - третий, отдельный admission engine в этой
# лабе, чтобы тренировать именно OPA/Rego skill, а не только Kyverno CEL. В отличие от
# Kyverno (задание 1: студент сам устанавливает через install-kyverno), Gatekeeper
# предустановлен здесь bootstrap-ом: задание посвящено починке уже готовой (слегка
# неполной) policy, а не установке admission engine с нуля - это уже покрыто заданием 1.
GATEKEEPER_VERSION="v3.17.1"  # текущий stable release gatekeeper-library на дату лабы
kubectl apply -f "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml"
kubectl -n gatekeeper-system wait --for=condition=Available --timeout=180s deployment/gatekeeper-controller-manager
kubectl -n gatekeeper-system wait --for=condition=Available --timeout=180s deployment/gatekeeper-audit

# Задание 7 работает в СОБСТВЕННОМ namespace, отдельном от Kyverno-заданий 2-5
# (policy-108): Kyverno task 4 (allow-approved-registries) уже отклоняет untrusted
# registries в policy-108, поэтому тестовый Pod для Gatekeeper там был бы отклонён
# ОБОИМИ admission engine одновременно - неоднозначный источник denial, потенциальный
# false-FAIL. Изоляция в gatekeeper-108 убирает эту двусмысленность.
kubectl apply -f - <<'EOF_NS'
apiVersion: v1
kind: Namespace
metadata:
  name: gatekeeper-108
EOF_NS

# Даём webhook TLS/service reconciliation устояться перед первым apply
# ConstraintTemplate - Deployment "Available" не гарантирует, что validating webhook
# уже готов принимать CRD conversion запросы сию секунду.
sleep 15

# Rego здесь - намеренно неполный blocklist (hardcoded registries, НЕ parameters):
# mock exams тренируют именно редактирование ConstraintTemplate.spec.targets[].rego
# (найти policy logic, дописать новый registry в Rego), а не правку Constraint
# parameters - это другой, более поверхностный workflow. very-bad-registry.test
# намеренно отсутствует из списка blocked_registry(...) - его должен добавить студент.
kubectl apply -f - <<'EOF_CT'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sblockedregistries
spec:
  crd:
    spec:
      names:
        kind: K8sBlockedRegistries
      validation:
        openAPIV3Schema:
          type: object
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sblockedregistries

      blocked_registry("untrusted-registry.example")
      blocked_registry("docker-fake.test")

      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        registry := split(container.image, "/")[0]
        blocked_registry(registry)
        msg := sprintf("image registry %v is blocked by k8sblockedregistries", [registry])
      }
EOF_CT

# Ждём, пока ConstraintTemplate реально скомпилируется в CRD K8sBlockedRegistries -
# без этого ожидания следующий apply Constraint может провалиться с "no matches for
# kind K8sBlockedRegistries" из-за пропущенного окна CRD-регистрации.
for i in $(seq 1 30); do
  kubectl get crd k8sblockedregistries.constraints.gatekeeper.sh >/dev/null 2>&1 && break
  sleep 2
done

# Constraint - простой и уже полностью правильный, никаких parameters: студент не
# должен трогать этот объект вообще, только Rego в ConstraintTemplate выше.
kubectl apply -f - <<'EOF_CONSTRAINT'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockedRegistries
metadata:
  name: deny-bad-registries
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces: ["gatekeeper-108"]
EOF_CONSTRAINT

echo "*** CKS lab 108 bootstrap is ready; install Kyverno from the worker ***"
