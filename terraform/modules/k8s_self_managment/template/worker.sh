#!/bin/bash
runtime_sh=${runtime}
k8_version_sh=${k8_version}
worker_join_sh=${worker_join}
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

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

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

echo " aws s3 cp s3://$worker_join_sh  worker_join   "
aws s3 cp s3://$worker_join_sh  worker_join
chmod +x worker_join
./worker_join

# add additional script
if [[ "$task_script_enable_sh" == "true" ]] ; then

${task_script_file}

fi