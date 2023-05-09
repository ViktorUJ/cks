#!/bin/bash
# install util
# prepare k8 configs
# check connections
configs_dir="/var/work/configs"
default_configs_dir="/root/.kube"

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


mkdir $configs_dir -p
mkdir $default_configs_dir -p

export KUBECONFIG=''
clusters_config="${clusters_config}"
for cluster in $clusters_config; do
  cluster_name=$(echo "$cluster" | cut -d'=' -f1 )
  cluster_config_url=$(echo "$cluster" | cut -d'=' -f2 )
  echo "$cluster_name   $cluster_config_url "
  aws s3 cp $cluster_config_url $cluster_name
  cat $cluster_name | sed -e 's/kubernetes/'$cluster_name'/g' >/var/work/configs/$cluster_name
  KUBECONFIG+="$configs_dir/$cluster_name:"
done

kubectl config view --flatten > $default_configs_dir/config

export KUBECONFIG=/root/.kube/config
kubectl config get-contexts