#!/bin/bash
echo " *** worker node  task 02"
echo " *** install falco"

# https://github.com/sysdiglabs/falco-workshop
apt-get update
apt-get -y install gpg curl

curl -o install-falco.sh -s \
  https://s3.amazonaws.com/download.draios.com/stable/install-falco

bash install-falco.sh

##https://falco.org/docs/getting-started/installation/
#curl -s https://falco.org/repo/falcosecurity-packages.asc | apt-key add -
#echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
#apt-get update -y
#apt-get  install linux-headers-$(uname -r) clang llvm   dkms make -y
#apt-get install -y falco
#
#systemctl enable  falco
#systemctl start falco
#
