#!/bin/bash
echo " *** worker node mock-3  k8s-1"

apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" |  tee -a /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install trivy -y
