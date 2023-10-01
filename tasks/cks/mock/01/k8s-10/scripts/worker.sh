#!/bin/bash
echo " *** worker node mock-1  k8s-10"

mkdir /var/work/ -p
cd /var/work/
wget https://raw.githubusercontent.com/ViktorUJ/cks/0.3.2/tasks/cks/mock/01/k8s-10/scripts/profile-nginx.json


