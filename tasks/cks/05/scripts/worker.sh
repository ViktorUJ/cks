#!/bin/bash
echo " *** worker node task 05"

curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.6.2/kube-bench_0.6.2_linux_amd64.deb -o kube-bench_0.6.2_linux_amd64.deb

apt install ./kube-bench_0.6.2_linux_amd64.deb -f