#!/bin/bash
ssh_password_enable_check=${ssh_password_enable}
function wait_cluster_ready {

echo "wait cluster $1 ready"
gsutil ls $2
while test $? -gt 0
  do
   sleep 10
   echo "wait cluster $1 ready .Trying again..."
   gsutil ls $2
  done
date

}
#-------------------
for host in ${hosts} ; do
 host_name=$(echo $host | cut -d'=' -f1)
 host_ip=$(echo $host | cut -d'=' -f2)
 echo "$host_ip $host_name" >>/etc/hosts
done

case  $ssh_password_enable_check in
true)
    echo "ubuntu:${ssh_password}" |sudo chpasswd
    SSH_CONFIG_FILE="/etc/ssh/sshd_config"
    SSH_CONFIG_FILE_CLOUD="/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONFIG_FILE_CLOUD

    systemctl restart sshd
    echo "*** ssh password "
;;
*)
    echo "*** ssh password not enable "
;;
esac


acrh=$(uname -m)
hostnamectl  set-hostname worker

configs_dir="/var/work/configs"
default_configs_dir="/root/.kube"

echo "*** apt update  & install apps "
apt-get update -qq
apt-get install -y  unzip apt-transport-https ca-certificates curl jq bash-completion binutils vim tar

case $acrh in
x86_64)
  kubectl_url="https://dl.k8s.io/release/v${kubectl_version}/bin/linux/amd64/kubectl"
;;
aarch64)
  kubectl_url="https://dl.k8s.io/release/v${kubectl_version}/bin/linux/arm64/kubectl"
;;
esac

curl -LO $kubectl_url
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

echo "*** install aws cli and helm  "

case $acrh in
x86_64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
;;
aarch64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
  curl -Lo helm.tar.gz https://get.helm.sh/helm-v3.13.1-linux-arm.tar.gz
  tar -zxvf helm.tar.gz
  mv linux-arm/helm /usr/local/bin/helm
;;
esac

helm plugin install https://github.com/jkroepke/helm-secrets --version v3.8.2
helm plugin install https://github.com/sstarcher/helm-release

curl $awscli_url  -o "awscliv2.zip" -s
unzip awscliv2.zip >/dev/null
./aws/install >/dev/null
aws --version

echo 'complete -C "/usr/local/bin/aws_completer" aws'>>/root/.bashrc
echo 'complete -C "/usr/local/bin/aws_completer" aws' >>/home/ubuntu/.bashrc
echo 'export PS1="\[\033[0;38;5;10m\]\u@\h\[\033[0;38;5;14m\]:\[\033[0;38;5;6m\]\w\[\033[0;38;5;10m\]>\[\033[0m\] "' >>/home/ubuntu/.bashrc

echo "*** add test engine "
git clone https://github.com/sstephenson/bats.git
cd bats
./install.sh /usr/local

echo "*** download tests "
mkdir /var/work/tests/result -p
mkdir /var/work/tests/artifacts -p
curl "${test_url}"  -o "tests.bats" -s
chown ubuntu:ubuntu tests.bats
mv tests.bats  /var/work/tests/
chmod  -R 777 /var/work/tests/

#check_result
echo "**** add check_result"
cat > /usr/bin/check_result <<EOF
#!/bin/bash
bats /var/work/tests/tests.bats
sum_all=0; for i in \$(cat /var/work/tests/result/all) ; do sum_all=\$(echo "\$sum_all+\$i"| bc ) ; done
sum_ok=0; for i in \$(cat /var/work/tests/result/ok) ; do sum_ok=\$(echo "\$sum_ok+\$i"| bc ) ; done
result=\$(echo "scale=2 ; \$sum_ok/\$sum_all*100" | bc  )
echo " result = \$result %   ok_points=\$sum_ok  all_points=\$sum_all  "
time_left
EOF
chmod +x /usr/bin/check_result

# install podman
echo "*** install podman "
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$VERSION_ID/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$VERSION_ID/Release.key" | sudo apt-key add -
apt-get update -qq
apt-get  -y install podman cri-tools containers-common
rm /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
cat <<EOF | sudo tee /etc/containers/registries.conf
[registries.search]
registries = ['docker.io']
EOF


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
  gsutil cp $cluster_config_url $cluster_name
  cat $cluster_name | sed -e 's/kubernetes/'$cluster_name'/g' >/var/work/configs/$cluster_name
  KUBECONFIG+="$configs_dir/$cluster_name:"
done

kubectl config view --flatten > $default_configs_dir/config

export KUBECONFIG=/root/.kube/config
kubectl config get-contexts

mkdir /home/ubuntu/.kube  -p
cp /root/.kube/config /home/ubuntu/.kube/config
cp /root/.kube/config /home/ubuntu/.kube/_config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/_config
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
echo "****  for connect to node use 'ssh  {kubernetes_nodename} '"
echo "=============================================="

target_time_stamp=$(echo "$(date +%s)+${exam_time_minutes}*60" | bc)
start_time_stamp=$(date +%s)
cat > /usr/bin/exam_check.sh <<EOF
#!/bin/bash
if [[   "\$(date +%s)" -gt "$target_time_stamp"  ]] ; then
  wall  "*** time is over  . disabled config , please run <  check_result  > "
  rm /home/ubuntu/.kube/config
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
env_working_time=\$(echo "(\$(date +%s) - $start_time_stamp)/60" | bc)
echo "you  spend \$env_working_time minutes"
EOF
chmod +x /usr/bin/time_left



# add additional script
curl "${task_script_url}" -o "task.sh"
chmod +x  task.sh
./task.sh
