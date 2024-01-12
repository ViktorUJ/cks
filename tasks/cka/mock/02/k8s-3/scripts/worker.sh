#!/bin/bash
echo " *** worker node mock-2  k8s-3"

systemctl disable kubelet
service kubelet stop
