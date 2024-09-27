#!/bin/bash

url=ping-pong-lb-511094172.eu-north-1.elb.amazonaws.com

while true; do
for i in {1..15}; do
  curl -s $url &
done
sleep 1
done