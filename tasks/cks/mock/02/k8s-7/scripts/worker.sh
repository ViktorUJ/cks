#!/bin/bash
echo " *** worker node mock-1  k8s-7"

# Install Falco
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
sudo tee -a /etc/apt/sources.list.d/falcosecurity.list


sudo apt-get install apt-transport-https -y
sudo apt-get update -y

sudo apt-cache madison falco

sudo apt install -y dkms make linux-headers-$(uname -r)
# If you use falcoctl driver loader to build the eBPF probe locally you need also clang toolchain
sudo apt install -y clang llvm
sudo apt install -y dialog

FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=kmod apt-get install -y falco=0.40.0


systemctl stop falco
