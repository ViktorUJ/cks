#!/bin/bash
echo " *** worker-01 pc mock-1  "
GIT_BRANCH="lfcs_preparation"

apt install -y zip zsh openssl acl redis

useradd phoenix
useradd jackson
usermod -aG sudo jackson

chmod o+w /opt

echo "This is a file for task1!"  > /home/ubuntu/file1
echo "This is a file for task2!"  > /home/ubuntu/file2
chmod 600 /home/ubuntu/file2

for i in 1 2 3; do echo "This is a file for task3$i!" >> /home/ubuntu/file3$i ; done

mkdir /opt/stickydir/

curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/05_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/06_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/07_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/08_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/09_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/12_generator.sh | bash
curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker-01/files/scripts/22_generator.sh | bash
chown ubuntu:ubuntu -R /home/ubuntu/file* /opt/*

systemctl enable redis-server --now