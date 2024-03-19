#!/bin/bash
echo " *** worker pc mock-1  "
GIT_BRANCH="lfcs_development"

apt install -y zip zsh openssl

useradd batman
useradd spiderman
useradd phoenix
useradd jackson
usermod -aG sudo jackson

chmod o+w /opt

echo "This is a file for task1!"  > /home/ubuntu/file1
echo "This is a file for task2!"  > /home/ubuntu/file2
chmod 600 /home/ubuntu/file2

for i in 1 2 3; do echo "This is a file for task3$i!" >> /home/ubuntu/file3$i ; done

mkdir /opt/stickydir/

curl -L https://raw.githubusercontent.com/ViktorUJ/cks/${GIT_BRANCH}/tasks/lfcs/mock/01/worker/files/scripts/05_generator.sh | bash

chown ubuntu:ubuntu -R /home/ubuntu/file* /opt/*
