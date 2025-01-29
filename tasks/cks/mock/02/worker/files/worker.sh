#!/bin/bash
echo " *** worker pc mock-1  "

mkdir -p /opt/course/9/
cd /opt/course/9/
wget https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/01/worker/files/profile

mkdir -p /var/work/14/
cd /var/work/14/
wget https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/01/worker/files/14/Dockerfile
chmod 777 Dockerfile

sudo mkdir -p /etc/containers
sudo tee /etc/containers/policy.json <<EOF
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
EOF
