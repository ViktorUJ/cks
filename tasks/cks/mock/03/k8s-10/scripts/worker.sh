#!/bin/bash
echo " *** worker node mock-3  k8s-10"

mkdir /var/work/ -p
cd /var/work/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/k8s-10/scripts/profile-nginx.json
