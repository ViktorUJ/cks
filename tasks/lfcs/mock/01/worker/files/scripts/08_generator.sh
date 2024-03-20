#!/bin/bash

set -x

mkdir -p /opt/08/files/ /opt/08/results/

for file in {1..20};
do
  cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-100} | head -n 150 > /opt/08/files/file$file.txt
done
