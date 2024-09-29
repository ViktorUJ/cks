#!/bin/bash

declare -i  docker_worker_count=300
declare -i start_port=8080

yum update -y
yum install -y docker nginx
service docker start
usermod -a -G docker ec2-user
chkconfig docker on

cat <<"EOF" > Dockerfile

FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://ws-assets-prod-iad-r-fra-b129423e91500967.s3.amazonaws.com/5fb682bf-699a-4972-848b-ab4a1ec243d5/server-binary.py

RUN chmod +x server-binary.py

CMD ["python3.9", "server-binary.py"]

EOF

docker build -t app .
for ((i=0; i<docker_worker_count; i++)); do
  docker run -d -p $((start_port+i)):8080 --name "app-${i}" app
done




