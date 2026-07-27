#!/bin/bash
echo " *** master node cka lab-117 k8s-1"
export KUBECONFIG=/root/.kube/config

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# untaint control plane so the scheduler canary can be placed here
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true

# === сид-поломки уровня control plane ===

# 2) Ломаем kube-scheduler: подменяем образ статик-пода на несуществующий тег.
#    Симптом: под kube-scheduler-<cp> в ImagePullBackOff, планирование стоит.
sed -i 's#\(image: registry.k8s.io/kube-scheduler:\).*#\1v0.0.0-broken#' \
  /etc/kubernetes/manifests/kube-scheduler.yaml

# даём kubelet время пересоздать статик-под с битым образом
sleep 30

# 3) Канарейка, требующая работающего планировщика (bare Pod, без контроллеров).
#    Останется Pending, пока kube-scheduler не починят.
kubectl run sched-check --image=viktoruj/ping_pong:latest --restart=Never -n default || true

# 4) Битый статик-под на control plane: несуществующий образ.
#    Симптом: mirror-под staticweb-<cp> в ImagePullBackOff.
cat >/etc/kubernetes/manifests/staticweb.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: staticweb
  namespace: default
spec:
  containers:
  - name: web
    image: viktoruj/ping_pong:doesnotexist999
EOF

# 1) Ломаем kube-apiserver ПОСЛЕДНИМ (чтобы все предыдущие seed-действия прошли).
#    Добавляем несуществующий флаг в манифест — apiserver падает при старте.
#    kubectl перестаёт работать. Дебаг: crictl ps -a, crictl logs <id>.
#    Симптом: connection refused на :6443.
sleep 10

# 5) Создаём Pod dns-test в namespace dns-lab для задания на DNS-имя пода
kubectl create namespace dns-lab
kubectl run dns-test -n dns-lab --image=viktoruj/ping_pong:alpine --restart=Never -- sleep 60000

sed -i '/- --tls-private-key-file/a\    - --invalid-nonexistent-flag=true' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
