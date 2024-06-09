#!/bin/bash

echo "${ssh_private_key}">/home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
echo "${ssh_pub_key}">>/home/ubuntu/.ssh/authorized_keys

date
swapoff -a

apt-get update && sudo apt-get upgrade -y