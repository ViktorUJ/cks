#!/bin/bash

mkdir -p /opt/17/results /opt/17/dir1 /opt/17/dir2

for i in {1..100}; do
  if (( i != 50 )); then
    str=$(echo "$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 80 ; echo '')")
    echo $str >> /opt/17/file1
    echo $str >> /opt/17/file2
  else
    echo "This is the different line" >> /opt/17/file2
  fi
done

num_files=$(( RANDOM % 21 + 20 ))

for ((i=1; i<=$num_files; i++)); do
    echo "Dummy file $i" >> /opt/17/dir1/file$i
  if (( RANDOM % 2 )); then
    cp "/opt/17/dir1/file$i" "/opt/17/dir2/file$i"
  fi
done
