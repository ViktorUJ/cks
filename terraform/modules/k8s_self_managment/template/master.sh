#!/bin/bash
local_ipv4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
runtime_sh=${runtime}
k8_version_sh=${k8_version}
k8s_config_sh=${k8s_config}
worker_join_sh=${worker_join}
pod_network_cidr_sh=${pod_network_cidr}
external_ip_sh=${external_ip}
utils_enable_sh=${utils_enable}
task_script_enable_sh=${task_script_enable}

date
swapoff -a

apt-get update && sudo apt-get upgrade -y
apt-get install -y  unzip

# install runtime
${runtime_script}
# install kubernetes

sh -c "echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' >> /etc/apt/sources.list.d/kubernetes.list"
sh -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
apt-get update
apt-get install -y kubeadm=$k8_version_sh-00 kubelet=$k8_version_sh-00 kubectl=$k8_version_sh-00
apt-mark hold kubelet kubeadm kubectl

kubeadm init --kubernetes-version $k8_version_sh --pod-network-cidr $pod_network_cidr_sh --apiserver-cert-extra-sans=localhost,127.0.0.1,$external_ip_sh,$local_ipv4
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

chown $(id -u):$(id -g) /root/.kube/config

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

aws s3 cp  /root/.kube/config s3://$k8s_config_sh
kubeadm token create --print-join-command --ttl 90000m > join_node
aws s3 cp  join_node s3://$worker_join_sh
date
kubectl get node --kubeconfig=/root/.kube/config
while test $? -gt 0
  do
   sleep 5
   echo "Trying again..."
   kubectl get node   --kubeconfig=/root/.kube/config
  done
date
echo "apply cni"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml   --kubeconfig=/root/.kube/config

echo "sleep 10"
sleep 10

kubectl get node  --kubeconfig=/root/.kube/config
date


# add utils
if [[ "$utils_enable_sh" == "true" ]] ; then
  apt-get install bash-completion vim -y
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm plugin install https://github.com/jkroepke/helm-secrets --version v3.8.2
  helm plugin install https://github.com/sstarcher/helm-release
  curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && \
  install skaffold /usr/local/bin/
  rm -rf skaffold
  echo 'source /usr/share/bash-completion/bash_completion'>>/root/.bashrc
  echo 'source <(kubectl completion bash)'>>/root/.bashrc
  echo 'complete -C "/usr/local/bin/aws_completer" aws'>>/root/.bashrc
  echo 'source <(helm completion bash)'>>/root/.bashrc
  echo 'source <(skaffold completion bash)'>>/root/.bashrc
fi


# add additional script
if [[ "$task_script_enable_sh" == "true" ]] ; then

${task_script_file}

fi