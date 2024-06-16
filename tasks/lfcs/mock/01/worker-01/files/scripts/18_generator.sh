#!/bin/bash

for image in ubuntu alpine busybox nginx httpd mysql postgres; do
  docker pull $image
done
