export KUBECONFIG=/root/.kube/config

echo "*** eks worker lab 2 ***"
kubectl  apply  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml

