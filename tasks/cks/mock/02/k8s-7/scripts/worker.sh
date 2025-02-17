#!/bin/bash
echo " *** worker node mock-1  k8s-7"



curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
apt-get install apt-transport-https -y
apt-get update -y

apt install -y dkms make linux-headers-$(uname -r)
# If you use falcoctl driver loader to build the eBPF probe locally you need also clang toolchain
apt install -y clang llvm
# You can install also the dialog package if you want it
apt install -y dialog

export FALCO_FRONTEND=noninteractive
export FALCO_DRIVER_CHOICE
apt-get install -y falco=0.40.0
systemctl disable falco
systemctl stop falco



#curl -s https://falco.org/repo/falcosecurity-packages.asc | apt-key add -
#echo "deb https://download.falco.org/packages/deb stable main" \ | tee -a /etc/apt/sources.list.d/falcosecurity.list
#apt-get update
#
#apt search linux-headers-$(uname -r)
#apt-get -y install linux-headers-$(uname -r)
#apt-get install -y falco=0.33.1
#
#systemctl disable falco
#systemctl stop falco
#
#curl -s https://download.sysdig.com/DRAIOS-GPG-KEY.public | sudo apt-key add -
#curl -s -o /etc/apt/sources.list.d/draios.list https://download.sysdig.com/stable/deb/draios.list
#apt-get update
#apt-get -y install sysdig
#