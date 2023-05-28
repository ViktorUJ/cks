#!/bin/bash
echo " *** worker pc mock-1  "

mkdir -p /opt/course/9/
cd /opt/course/9/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/profile

mkdir -p /var/work/14/
cd /var/work/14/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/14/Dockerfile
chmod 777 Dockerfile

. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$VERSION_ID/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$VERSION_ID/Release.key" | sudo apt-key add -
apt-get update -qq
apt-get  -y install podman cri-tools containers-common
rm /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
cat <<EOF | sudo tee /etc/containers/registries.conf
[registries.search]
registries = ['docker.io']
EOF