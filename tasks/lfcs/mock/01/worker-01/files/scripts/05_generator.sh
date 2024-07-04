#!/bin/bash

arr[0]="256K"
arr[1]="512K"
arr[2]="1536K"
arr[3]="2M"

mkdir -p /opt/05/task
mkdir -p /opt/05/result/05kb
mkdir -p /opt/05/result/setuid/

for i in {1..500}; do
  dd if=/dev/urandom bs=${arr[$[ $RANDOM % 4 ]]} count=1 of=/opt/05/task/file$i  > /dev/null
  chown ubuntu:ubuntu /opt/05/task/file$i
  rand=$((RANDOM % 2))
  if [[ $rand -eq 0 ]]; then
    chmod u+x /opt/05/task/file$i
  elif [[ $rand -eq 1 ]]; then
    chmod u+s /opt/05/task/file$i
  fi
done
