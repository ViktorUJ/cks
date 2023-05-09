#!/bin/bash
# install util
# prepare k8 configs
# check connections


apt-get update && sudo apt-get upgrade -y
apt-get install -y  unzip apt-transport-https ca-certificates curl jq bash-completion binutils vim

curl -LO https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl  /usr/bin/

echo "*** install aws cli "
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"  -o "awscliv2.zip" -s
unzip awscliv2.zip >/dev/null
./aws/install >/dev/null
aws --version


mkdir /var/work/configs -p
mkdir /root/.kube/ -p

clusters_config="${clusters_config}"
for cluster in $clusters_config; do
  cluster_name=$(echo "$cluster" | cut -d'=' -f1 )
  cluster_config_url=$(echo "$cluster" | cut -d'=' -f2 )
  echo "$cluster_name   $cluster_config_url "
  aws s3 cp $cluster_config_url $cluster_name
  cat $cluster_name | sed -e 's/kubernetes/'$cluster_name'/g' >/var/work/configs/$cluster_name
done
export KUBECONFIG=/var/work/configs:$(find . -type f | tr '\n' ':')
kubectl config view --flatten > /root/.kube/config

export KUBECONFIG=/root/.kube/config
kubectl config get-contexts