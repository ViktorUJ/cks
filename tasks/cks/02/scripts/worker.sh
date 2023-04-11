#!/bin/bash
echo " *** worker node  task 02"


curl -s https://falco.org/repo/falcosecurity-packages.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" \ | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update

apt search linux-headers-$(uname -r)
apt-get -y install linux-headers-$(uname -r)
apt-get install -y falco=0.33.1

systemctl start falco

