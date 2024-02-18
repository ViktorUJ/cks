#!/bin/bash
echo " *** worker pc mock-1  "

chmod o+w /opt

echo "This is a file for task1!"  > /home/ubuntu/file1
echo "This is a file for task2!"  > /home/ubuntu/file2
chmod 600 /home/ubuntu/file2

for i in 1 2 3; do echo "This is a file for task3$i!" >> file3$i ; done

chown ubuntu:ubuntu /home/ubuntu/file1
