#!/bin/bash

set -x

for ((k=1;k<=70;k++)); do
  rand=$((RANDOM % 2))
    if [[ "$rand" -eq 0 ]]; then
      echo "system$k=enabled" >> /etc/config.conf
    else
      echo "system$k=disabled" >> /etc/config.conf
    fi
done