#!/bin/bash
apt-get update ;  apt-get install -y gzip
echo "${boot_zip}" | base64 -d | gzip -d  > boot.sh
chmod +x boot.sh
./boot.sh