#!/bin/bash
runtime_sh=${runtime}
k8_version_sh=${k8_version}
worker_join_sh=${worker_join}


date
swapoff -a

apt-get update && sudo apt-get upgrade -y
apt-get install -y  unzip

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

echo "*** install aws cli "
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"  -o "awscliv2.zip" -s
unzip awscliv2.zip >/dev/null
./aws/install >/dev/null
aws --version

date
echo "wait master ready"
aws s3 ls s3://$worker_join_sh
while test $? -gt 0
  do
   sleep 5
   echo "Wait master ready .Trying again..."
   aws s3 ls s3://$worker_join_sh
  done
date

# add node labels
cat > /etc/systemd/system/kubelet.service.d/20-labels-taints.conf <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--node-labels=node_name=${node_name},${node_labels}"
EOF
systemctl enable kubelet
systemctl restart kubelet


echo " aws s3 cp s3://$worker_join_sh  worker_join   "
aws s3 cp s3://$worker_join_sh  worker_join
chmod +x worker_join
./worker_join

# add additional script
curl "${task_script_url}" -o "task.sh"
chmod +x  task.sh
./task.sh
