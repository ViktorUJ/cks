#!/bin/bash
echo " *** worker node mock-1  k8s-3"
acrh=$(uname -m)
case $acrh in
x86_64)
  arc_name="amd64"
;;
aarch64)
  arc_name="arm64"
;;
esac
kube_bench_version="0.7.3"
kube_bench_url="https://github.com/aquasecurity/kube-bench/releases/download/v${kube_bench_version}/kube-bench_${kube_bench_version}_linux_${arc_name}.deb"
# https://github.com/aquasecurity/kube-bench/releases
curl -L $kube_bench_url  -o kube-bench.deb
apt install ./kube-bench.deb -f -y
