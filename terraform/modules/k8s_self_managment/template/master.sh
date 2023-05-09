#!/bin/bash
local_ipv4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
runtime_sh=${runtime}
k8_version_sh=${k8_version}
k8s_config_sh=${k8s_config}
worker_join_sh=${worker_join}
pod_network_cidr_sh=${pod_network_cidr}
external_ip_sh=${external_ip}
utils_enable_sh=${utils_enable}


date
swapoff -a

apt-get update && sudo apt-get upgrade -y
apt-get install -y  unzip apt-transport-https ca-certificates curl jq

# install runtime
${runtime_script}
# install kubernetes
ubuntu_release=$(lsb_release -a | grep 'Release:'| cut -d':' -f2|tr -d "\n" | tr -d '\t')
case $ubuntu_release in
20.04)
  sh -c "echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' >> /etc/apt/sources.list.d/kubernetes.list"
  sh -c "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
  ;;
*)
  curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  ;;
esac


apt-get update
apt-get install -y kubeadm=$k8_version_sh-00 kubelet=$k8_version_sh-00 kubectl=$k8_version_sh-00
apt-mark hold kubelet kubeadm kubectl

kubeadm init --kubernetes-version $k8_version_sh --pod-network-cidr $pod_network_cidr_sh --apiserver-cert-extra-sans=localhost,127.0.0.1,$external_ip_sh,$local_ipv4
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

chown $(id -u):$(id -g) /root/.kube/config

echo "*** install aws cli "
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"  -o "awscliv2.zip" -s
unzip awscliv2.zip >/dev/null
./aws/install >/dev/null
aws --version


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
kubectl apply -f ${calico_url}   --kubeconfig=/root/.kube/config

echo "sleep 10"
sleep 10

kubectl get node  --kubeconfig=/root/.kube/config
date

apt-get install -y bash-completion binutils vim
echo 'source /usr/share/bash-completion/bash_completion'>>/root/.bashrc
echo 'source <(kubectl completion bash)' >> /root/.bashrc
echo 'alias k=kubectl' >> /root/.bashrc
echo 'complete -F __start_kubectl k' >> /root/.bashrc

# add utils
if [[ "$utils_enable_sh" == "true" ]] ; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  helm plugin install https://github.com/jkroepke/helm-secrets --version v3.8.2
  helm plugin install https://github.com/sstarcher/helm-release
  curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && \
  install skaffold /usr/local/bin/
  rm -rf skaffold
  echo 'complete -C "/usr/local/bin/aws_completer" aws'>>/root/.bashrc
  echo 'source <(helm completion bash)'>>/root/.bashrc
  echo 'source <(skaffold completion bash)'>>/root/.bashrc
#  . /etc/os-release
#  echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$VERSION_ID/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
#  curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$VERSION_ID/Release.key" | sudo apt-key add -
#  apt-get update -qq
#  apt-get  -y install podman cri-tools containers-common
#  rm /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
#  cat <<EOF | sudo tee /etc/containers/registries.conf
#  [registries.search]
#  registries = ['docker.io']
#EOF

fi


# add additional script
curl "${task_script_url}" -o "task.sh"
chmod +x  task.sh
./task.sh

echo "${ssh_private_key}">/home/ubuntu/.ssh/id_rsa
echo "${ssh_pub_key}">>/home/ubuntu/.ssh/authorized_keys
chmod 400 -R /home/ubuntu/.ssh