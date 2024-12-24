#!/bin/bash
echo " *** worker node mock-1  k8s-7"


curl -s https://falco.org/repo/falcosecurity-packages.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" \ | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update

apt search linux-headers-$(uname -r)
apt-get -y install linux-headers-$(uname -r)
apt-get install -y falco=0.33.1

systemctl disable falco
systemctl stop falco

curl -s https://download.sysdig.com/DRAIOS-GPG-KEY.public | sudo apt-key add -
curl -s -o /etc/apt/sources.list.d/draios.list https://download.sysdig.com/stable/deb/draios.list
apt-get update
apt-get -y install sysdig
