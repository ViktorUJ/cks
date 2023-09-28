#!/bin/bash
runtime_sh=${runtime}
k8_version_sh=${k8_version}
worker_join_sh=${worker_join}
VERSION="$(echo $k8_version_sh| cut -d'.' -f1).$(echo $k8_version_sh| cut -d'.' -f2)"

date
swapoff -a

apt-get update && sudo apt-get upgrade -y
apt-get install -y  unzip

${runtime_script}

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
case $VERSION in
   1.28)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
   ;;
   *)
     kubelet_config_url="/etc/systemd/system/kubelet.service.d"
   ;;
 esac

cat > $kubelet_config_url/01-labels-taints.conf <<EOF
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

echo "${ssh_private_key}">/home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
echo "${ssh_pub_key}">>/home/ubuntu/.ssh/authorized_keys
