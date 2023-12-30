#!/bin/bash
echo " *** worker pc "

mkdir /var/work/ -p
cd /var/work/
apt install  wget -y
wget  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/labs/01/worker/files/k8s.conf
mkdir /home/ubuntu/.kube/ -p
cp /var/work/k8s.conf  /home/ubuntu/.kube/config
