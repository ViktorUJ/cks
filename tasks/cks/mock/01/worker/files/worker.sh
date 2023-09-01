#!/bin/bash
echo " *** worker pc mock-1  "

mkdir -p /opt/course/9/
cd /opt/course/9/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/profile

mkdir -p /var/work/14/
cd /var/work/14/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/14/Dockerfile
chmod 777 Dockerfile
