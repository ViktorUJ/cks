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



clusters_config="${clusters_config}"
for cluster in $clusters_config; do
  echo "$cluster"
done
