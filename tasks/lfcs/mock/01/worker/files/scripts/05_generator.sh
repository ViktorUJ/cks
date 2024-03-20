#!/bin/bash
set -x

arr[0]="256K"
arr[1]="512K"
arr[2]="1536K"
arr[3]="2M"

mkdir /opt/task5/

for i in {1..500}; do
  dd if=/dev/urandom bs=${arr[$[ $RANDOM % 4 ]]} count=1 of=/opt/task5/file$i  > /dev/null
  rand=$((RANDOM % 3))
  if [[ "$rand" -eq 0 ]]; then
    chmod u+x /opt/task5/file$i
  elif [[ "$rand" -eq 1 ]]; then
    chmod u+s /opt/task5/file$i
  fi
done
