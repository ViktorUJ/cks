#!/bin/bash

function wait_cluster_ready {

echo "wait cluster $1 ready"
aws s3 ls $2
while test $? -gt 0
  do
   sleep 10
   echo "wait cluster $1 ready .Trying again..."
   aws s3 ls $2
  done
date

}
#-------------------
hostnamectl  set-hostname worker

configs_dir="/var/work/configs"
default_configs_dir="/root/.kube"

apt-get update -qq
apt-get install -y  unzip apt-transport-https ca-certificates curl jq bash-completion binutils vim

curl -LO https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl  /usr/bin/

echo 'source /usr/share/bash-completion/bash_completion'>>/home/ubuntu/.bashrc
echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
echo 'alias k=kubectl' >>/home/ubuntu/.bashrc
echo 'complete -F __start_kubectl k' >>/home/ubuntu/.bashrc

echo 'source /usr/share/bash-completion/bash_completion'>>/root/.bashrc
echo 'source <(kubectl completion bash)' >> /root/.bashrc
echo 'alias k=kubectl' >> /root/.bashrc
echo 'complete -F __start_kubectl k' >> /root/.bashrc

echo "*** install aws cli "
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"  -o "awscliv2.zip" -s
unzip awscliv2.zip >/dev/null
./aws/install >/dev/null
aws --version
echo 'complete -C "/usr/local/bin/aws_completer" aws'>>/root/.bashrc
echo 'complete -C "/usr/local/bin/aws_completer" aws' >>/home/ubuntu/.bashrc


echo "*** add test engine "
git clone https://github.com/sstephenson/bats.git
cd bats
./install.sh /usr/local

echo "*** download tests "
mkdir /var/work/tests -p
curl "${test_url}"  -o "tests.bats" -s
chown ubuntu:ubuntu tests.bats
mv tests.bats  /var/work/tests/

#check_result
cat > /usr/bin/check_result <<EOF
bats /var/work/tests/tests.bats
EOF
chmod +x /usr/bin/check_result


mkdir $configs_dir -p
mkdir $default_configs_dir -p

echo "${ssh_private_key}">/root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
echo "${ssh_pub_key}">>/root/.ssh/authorized_keys

echo "${ssh_private_key}">/home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
echo "${ssh_pub_key}">>/home/ubuntu/.ssh/authorized_keys

export KUBECONFIG=''
clusters_config="${clusters_config}"
for cluster in $clusters_config; do
  cluster_name=$(echo "$cluster" | cut -d'=' -f1 )
  cluster_config_url=$(echo "$cluster" | cut -d'=' -f2 )
  echo "$cluster_name   $cluster_config_url "
  wait_cluster_ready "$cluster_name" "$cluster_config_url"
  aws s3 cp $cluster_config_url $cluster_name
  cat $cluster_name | sed -e 's/kubernetes/'$cluster_name'/g' >/var/work/configs/$cluster_name
  KUBECONFIG+="$configs_dir/$cluster_name:"
done

kubectl config view --flatten > $default_configs_dir/config

export KUBECONFIG=/root/.kube/config
kubectl config get-contexts

mkdir /home/ubuntu/.kube  -p
cp /root/.kube/config /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 777 -R  /home/ubuntu/.kube/

echo "==============================================="
echo "****  all cluster is done . You can start "
echo "**** time for exam ${exam_time_minutes} minutes "
echo "****  please  reload   bash config"
echo " "
echo "   source ~/.bashrc       "
echo " "
echo "**** for checking time run     <  time_left  >    "
echo "**** for checking result run   <  check_result  >    "
echo "=============================================="
target_time_stamp=$(echo "$(date +%s)+${exam_time_minutes}*60" | bc)
cat > /usr/bin/exam_check.sh <<EOF
#!/bin/bash
if [[   "\$(date +%s)" -gt "$target_time_stamp"  ]] ; then
  wall  "*** time is over  . disable config , run test "
  mv /home/ubuntu/.kube/config   /home/ubuntu/.kube/_config
  rm /usr/bin/exam_check.sh
fi
EOF

chmod +x /usr/bin/exam_check.sh

#Create Cron Job
cat << EOF | crontab -
* * * * * /usr/bin/exam_check.sh >> /var/log/exam_check.log

EOF

#time left
cat > /usr/bin/time_left <<EOF
#!/bin/bash
time_left=\$(echo "($target_time_stamp-\$(date +%s))/60" | bc)
if [[   "\$time_left" -gt "0"  ]] ; then
   echo "time_left=\$time_left minutes"
 else
   echo " time is over "
fi
EOF
chmod +x /usr/bin/time_left

