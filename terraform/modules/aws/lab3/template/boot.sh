#!/bin/bash

yum update -y
yum install -y docker
service docker start
usermod -a -G docker ec2-user
chkconfig docker on

docker run -p 0.0.0.0:80:8080 --name app viktoruj/ping_pong > /var/log/app.log