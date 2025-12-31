echo "*** eks worker lab 2 ***"
wget https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml
cat 1.yaml
sleep 20
kubectl get ns
kubectl  apply -f 1.yaml
