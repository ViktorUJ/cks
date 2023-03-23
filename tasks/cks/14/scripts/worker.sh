#!/bin/bash
echo " *** worker node  task 12"

apt update
apt install nginx -y
systemctl enable nginx
service nginx start