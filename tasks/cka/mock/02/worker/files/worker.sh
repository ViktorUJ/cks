#!/bin/bash
echo " *** worker pc  cka mock-2  "

mkdir -p /var/work/artifact/
echo '# script fo 9 question' >/var/work/artifact/9.sh
echo '# script fo 16 question' >/var/work/artifact/16.sh
echo '# script fo 17 question' >/var/work/artifact/17.sh
chmod 777 -R /var/work/artifact


address=$(kubectl get no -l work_type=infra_core --context cluster1-admin@cluster1 -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address cka.local">>/etc/hosts
