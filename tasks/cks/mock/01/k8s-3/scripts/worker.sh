#!/bin/bash
echo " *** worker node mock-1  k8s-3"


curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.6.10/kube-bench_0.6.10_linux_amd64.deb  -o kube-bench.deb
apt install ./kube-bench.deb -f -y
