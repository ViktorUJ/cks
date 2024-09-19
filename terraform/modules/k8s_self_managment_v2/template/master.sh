#!/bin/bash
ssh_password_enable_check=${ssh_password_enable}
case $ssh_password_enable_check in
true)
    echo "*** ssh password enable "
    echo "ubuntu:${ssh_password}" |sudo chpasswd
    SSH_CONFIG_FILE="/etc/ssh/sshd_config"
    SSH_CONFIG_FILE_CLOUD="/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONFIG_FILE_CLOUD

    systemctl restart sshd
;;
*)
    echo "*** ssh password not enable "
;;
esac

local_ipv4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
runtime_sh=${runtime}
k8_version_sh=${k8_version}
k8s_config_sh=${k8s_config}
worker_join_sh=${worker_join}
pod_network_cidr_sh=${pod_network_cidr}
external_ip_sh=${external_ip}
utils_enable_sh=${utils_enable}
cni_type=${cni_type}
cilium_version=${cilium_version}


date
swapoff -a

apt-get update && sudo apt-get upgrade -y
apt-get install -y  unzip apt-transport-https ca-certificates curl jq

${runtime_script}
if [ -z "$external_ip_sh" ]; then
   echo "*** kubeadm init without eip "
   kubeadm init --kubernetes-version $k8_version_sh --pod-network-cidr $pod_network_cidr_sh --apiserver-cert-extra-sans=localhost,127.0.0.1,$local_ipv4
  else
   echo "*** kubeadm init with eip "
   kubeadm init --kubernetes-version $k8_version_sh --pod-network-cidr $pod_network_cidr_sh --apiserver-cert-extra-sans=localhost,127.0.0.1,$local_ipv4,$external_ip_sh
fi


mkdir -p /root/.kube
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown $(id -u):$(id -g) /root/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

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

echo "*** apply cni"
export KUBECONFIG=/root/.kube/config
case $acrh in
x86_64)
  cilium_url="https://github.com/cilium/cilium-cli/releases/download/${cilium_version}/cilium-linux-amd64.tar.gz"

;;
aarch64)
  cilium_url="https://github.com/cilium/cilium-cli/releases/download/${cilium_version}/cilium-linux-arm64.tar.gz"
;;
esac

case $cni_type in
calico)
   kubectl apply -f ${calico_url}   --kubeconfig=/root/.kube/config
;;
cilium)
   echo "*** install cilium cilium_url=$cilium_url"
   curl -Lo cilium.tar.gz $cilium_url
   tar -zxvf cilium.tar.gz
   mv cilium /usr/local/bin/cilium
   cilium install --version ${cilium_helm_version}
;;
*)
   echo "cni type = $cni_type  not support"
;;

esac

echo "sleep 10"
sleep 10

kubectl get node  --kubeconfig=/root/.kube/config
date

apt-get install -y bash-completion binutils vim
echo 'source /usr/share/bash-completion/bash_completion'>>/root/.bashrc
echo 'source <(kubectl completion bash)' >> /root/.bashrc
echo 'alias k=kubectl' >> /root/.bashrc
echo 'complete -F __start_kubectl k' >> /root/.bashrc
echo 'source /usr/share/bash-completion/bash_completion'>>/home/ubuntu/.bashrc
echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
echo 'complete -F __start_kubectl k' >> /home/ubuntu/.bashrc

acrh=$(uname -m)
case $acrh in
x86_64)
  skaffold_url="https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
;;
aarch64)
  skaffold_url="https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-arm64"
  curl -Lo helm.tar.gz https://get.helm.sh/helm-v3.13.1-linux-arm.tar.gz
  tar -zxvf helm.tar.gz
  mv linux-arm/helm /usr/local/bin/helm
;;
esac
if [[ "$utils_enable_sh" == "true" ]] ; then
  echo "*** install utils "
  helm plugin install https://github.com/jkroepke/helm-secrets --version v3.8.2
  helm plugin install https://github.com/sstarcher/helm-release
  curl -Lo skaffold $skaffold_url && \
  install skaffold /usr/local/bin/
  rm -rf skaffold
  echo 'complete -C "/usr/local/bin/aws_completer" aws'>>/root/.bashrc
  echo 'source <(helm completion bash)'>>/root/.bashrc
  echo 'source <(skaffold completion bash)'>>/root/.bashrc
  echo 'complete -C "/usr/local/bin/aws_completer" aws'>>/home/ubuntu/.bashrc
  echo 'source <(helm completion bash)'>>/home/ubuntu/.bashrc
  echo 'source <(skaffold completion bash)'>>/home/ubuntu/.bashrc
fi

curl "${task_script_url}" -o "task.sh"
chmod +x  task.sh
./task.sh

echo "${ssh_private_key}">/home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
echo "${ssh_pub_key}">>/home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
