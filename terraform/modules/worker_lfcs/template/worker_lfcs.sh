#!/bin/bash
set -x
#-------------------
for host in ${hosts} ; do
 host_name=$(echo $host | cut -d'=' -f1)
 host_ip=$(echo $host | cut -d'=' -f2)
 echo "$host_ip $host_name" >>/etc/hosts
done

case  ${ssh_password_enable} in
true)
    echo -e "${ssh_password}\n${ssh_password}" | passwd ubuntu
    SSH_CONFIG_FILE="/etc/ssh/sshd_config"
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    systemctl restart sshd
;;
*)
    echo "*** ssh password not enable "
;;
esac


acrh=$(uname -m)
hostnamectl  set-hostname node

configs_dir="/var/work/configs"

echo "*** apt update  & install apps "
apt-get update -qq
apt-get install -y  unzip apt-transport-https ca-certificates curl jq bash-completion binutils vim tar


echo "*** install aws cli "

case $acrh in
x86_64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
;;
aarch64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
;;
esac

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

# install docker
echo "*** install docker"
. /etc/os-release

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo usermod -aG docker ubuntu


mkdir $configs_dir -p

echo "${ssh_private_key}">/root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
echo "${ssh_pub_key}">>/root/.ssh/authorized_keys

echo "${ssh_private_key}">/home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
echo "${ssh_pub_key}">>/home/ubuntu/.ssh/authorized_keys


echo "================================================="
echo "**** Environment setup is ready. You can start   "
echo "**** Time for exam ${exam_time_minutes} minutes  "
echo "**** Please reload bash config"
echo " "
echo "   source ~/.bashrc       "
echo " "
echo "**** for checking time run     <  time_left  >   "
echo "**** for checking result run   <  check_result > "
echo "**** for connect to node use 'ssh  {nodename} '  "
echo "================================================="

target_time_stamp=$(echo "$(date +%s)+${exam_time_minutes}*60" | bc)
start_time_stamp=$(date +%s)
cat > /usr/bin/exam_check.sh <<EOF
#!/bin/bash
if [[   "\$(date +%s)" -gt "$target_time_stamp"  ]] ; then
  wall  "*** time is over  . disabled config , please run <  check_result  > "
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
curl -L "${task_script_url}" | bash
