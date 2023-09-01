#!/bin/bash
echo " *** master node task 16 "
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

kubectl  apply -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/16/scripts/task.yaml  --kubeconfig=/root/.kube/config

mkdir  /var/work
cd /var/work

curl "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/16/scripts/docker/Dockerfile"  -o "Dockerfile" -s
curl "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/16/scripts/docker/run.sh"  -o "run.sh" -s
curl "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/16/scripts/docker/build.sh"  -o "build.sh" -s
chmod +x build.sh
