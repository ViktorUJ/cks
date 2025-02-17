#!/bin/bash
echo " *** worker node mock-1  k8s-7"

exit 1
# Install Falco
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
apt-get install apt-transport-https -y
apt-get update -y

apt install -y dkms make linux-headers-$(uname -r)
# If you use falcoctl driver loader to build the eBPF probe locally you need also clang toolchain
apt install -y clang llvm
apt install -y dialog

export FALCO_FRONTEND=noninteractive
export FALCO_DRIVER_CHOICE=kmod
apt-get install -y falco=0.40.0


systemctl disable falco
systemctl stop falco
