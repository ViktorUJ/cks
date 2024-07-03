#!/bin/bash
echo " *** worker-02 pc mock-1  "

sudo apt install traceroute -y

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sudo sysctl -p
