#!/bin/bash
# set -x

mkdir -p /opt/06/result
mkdir -p /opt/06/task

r=$(( $RANDOM % 10 + 10 ));
for i in $(seq 1 $r);
do
    mkdir -p /opt/06/task/dir$i
    rand=$((RANDOM % 2))
    if [[ "$rand" -eq 0 ]]; then
        for ((k=1;k<=$(($RANDOM % 11));k++)); do
            mkdir /opt/06/task/dir$i/subdir$k
            COUNT_FILES=$(($RANDOM % 11))
            for y in $(seq 1 $COUNT_FILES); do
                RANDM=$((RANDOM % 2))
                if [[ "$RANDM" -eq 0 ]]; then
                    head -c 1K </dev/urandom > /opt/06/task/dir$i/subdir$k/file$i$k$y.txt
                 elif [[ "$RANDM" -eq 1 ]]; then
                    head -c 1K </dev/urandom > /opt/06/task/dir$i/subdir$k/file$i$k$y.txt
                    echo "findme" >> /opt/06/task/dir$i/subdir$k/file$i$k$y.txt
                fi
            done
        done
    elif [[ "$rand" -eq 1 ]]; then
        RANDM=$((RANDOM % 2))
        if [[ "$RANDM" -eq 0 ]]; then
            head -c 1K </dev/urandom > /opt/06/task/dir$i/file$i$y.txt
            elif [[ "$RANDM" -eq 1 ]]; then
            head -c 1K </dev/urandom > /opt/06/task/dir$i/file$i$y.txt
            echo "findme" >> /opt/06/task/dir$i/file$i$y.txt
        fi
    fi
done
