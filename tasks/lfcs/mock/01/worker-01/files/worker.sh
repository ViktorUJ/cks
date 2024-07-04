#!/bin/bash
echo " *** worker-01 pc mock-1  "
GIT_BRANCH="master"

apt install -y zip zsh openssl acl redis net-tools

useradd phoenix
useradd jackson
usermod -aG sudo jackson

chmod o+w /opt

echo "This is a file for task1!"  > /home/ubuntu/file1
echo "This is a file for task2!"  > /home/ubuntu/file2
chmod 600 /home/ubuntu/file2

for i in 1 2 3; do echo "This is a file for task3$i!" >> /home/ubuntu/file3$i ; done

mkdir /opt/stickydir/

curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/06_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/07_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/08_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/09_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/12_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/17_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/18_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/21_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/22_generator.sh | bash

mkdir -p /opt/19/result
chown ubuntu:ubuntu -R /home/ubuntu/file* /opt/*
# this is neededto be after that as chown rewrites needed permissions
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/05_generator.sh | bash

systemctl enable redis-server --now

# This is for task 20.3
sudo iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
sudo iptables -A FORWARD -i ens5 -o ens5 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i ens5 -o ens5 -j ACCEPT

EC2_INSTANCE_ID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
aws ec2 modify-instance-attribute --no-source-dest-check --instance-id $EC2_INSTANCE_ID --region $REGION
