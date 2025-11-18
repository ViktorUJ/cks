#!/bin/bash
# Full initialization script - runs everything (no size limit, hosted on GitHub)
# Environment variables are exported by the minimal bootstrap script

set -e

ssh_password_enable_check=${SSH_PASSWORD_ENABLE}

# Create work directory and init marker
mkdir -p /var/work
echo "$(date): Initialization started" > /var/work/init_status
chmod 644 /var/work/init_status

# Add hosts to /etc/hosts
for host in ${HOSTS}; do
  host_name=$(echo $host | cut -d'=' -f1)
  host_ip=$(echo $host | cut -d'=' -f2)
  echo "$host_ip $host_name" >>/etc/hosts
done

# Configure SSH password authentication
case  $ssh_password_enable_check in
true)
    echo "*** Configuring SSH password authentication"
    passwd -u ubuntu 2>/dev/null || true
    echo "ubuntu:${SSH_PASSWORD}" | chpasswd
    if [ $? -eq 0 ]; then
        echo "✓ Password set for ubuntu user"
    else
        echo "✗ Failed to set password"
    fi

    SSH_CONFIG_FILE="/etc/ssh/sshd_config"
    SSH_CONFIG_FILE_CLOUD="/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"

    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONFIG_FILE

    if [ -f "$SSH_CONFIG_FILE_CLOUD" ]; then
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONFIG_FILE_CLOUD
        echo "✓ Updated cloud-img SSH config"
    fi

    sshd -t && echo "✓ SSH config is valid"
    systemctl restart sshd
    sleep 2
    systemctl is-active --quiet sshd && echo "✓ SSH service is active"
    echo "✓ SSH password authentication enabled"
;;
*)
    echo "*** SSH password authentication not enabled"
;;
esac

acrh=$(uname -m)
hostnamectl set-hostname worker

configs_dir="/var/work/configs"
default_configs_dir="/root/.kube"

# ========================================
# SECTION 1: Install packages and tools
# ========================================

echo "*** apt update & install apps"
apt-get update -qq
apt-get install -y unzip apt-transport-https ca-certificates curl jq bash-completion binutils vim tar gzip bc git

# Install kubectl
case $acrh in
x86_64)
  kubectl_url="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
;;
aarch64)
  kubectl_url="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/arm64/kubectl"
;;
esac

curl -LO $kubectl_url
chmod +x kubectl
mv kubectl /usr/bin/

echo "*** install aws cli and helm"

case $acrh in
x86_64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
;;
aarch64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
;;
esac

# Install helm using official script (works for both architectures)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

curl $awscli_url -o "awscliv2.zip" -s
unzip awscliv2.zip >/dev/null
./aws/install --update >/dev/null 2>&1 || ./aws/install >/dev/null 2>&1 || true
aws --version

# install podman
echo "*** install podman"
apt-get update -qq
apt-get -y install podman

# Install Istio
echo "*** install Istio"
export ISTIO_VERSION=1.26.3
cd /root/
if [ ! -d "/root/istio-1.26.3" ]; then
  curl -L https://istio.io/downloadIstio | sh -
fi
install -m 755 istio-1.26.3/bin/istioctl /usr/bin/
cp -r /root/istio-1.26.3/manifests/profiles /home/ubuntu/ 2>/dev/null || true
chown -R ubuntu:ubuntu /home/ubuntu/profiles

snap install yq 2>&1 | grep -v "already installed" || true

# Install bats test engine
echo "*** add test engine"
if [ ! -d "/root/bats" ]; then
  git clone https://github.com/sstephenson/bats.git /root/bats
fi
cd /root/bats
./install.sh /usr/local
cd /root

# ========================================
# SECTION 2: Configure environment
# ========================================

# Setup kubectl completion and aliases for both users
for bashrc in /home/ubuntu/.bashrc /root/.bashrc; do
  echo 'source /usr/share/bash-completion/bash_completion' >> $bashrc
  echo 'source <(kubectl completion bash)' >> $bashrc
  echo 'alias k=kubectl' >> $bashrc
  echo 'complete -F __start_kubectl k' >> $bashrc
done

# Setup AWS completion for both users
echo 'complete -C "/usr/local/bin/aws_completer" aws' | tee -a /root/.bashrc /home/ubuntu/.bashrc > /dev/null

# Add istio and helm completion
echo "source <(istioctl completion bash)" | tee -a ~/.bashrc /home/ubuntu/.bashrc > /dev/null
echo "source <(helm completion bash)" | tee -a ~/.bashrc /home/ubuntu/.bashrc > /dev/null

# Add helm repos
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
su - ubuntu -c "helm repo add istio https://istio-release.storage.googleapis.com/charts && helm repo update"

# Add initialization wait check for ubuntu user
cat >> /home/ubuntu/.bashrc <<'INIT_CHECK_EOF'

# Wait for initialization to complete
if [ ! -f /var/work/.init_complete ] && [ -f /var/work/init_status ]; then
  echo ""
  echo "⏳ Lab environment is still initializing..."
  echo "   Please wait while setup completes."
  echo ""
  while [ ! -f /var/work/.init_complete ]; do
    if [ -f /var/work/init_status ]; then
      tail -1 /var/work/init_status
    fi
    sleep 5
  done
  echo ""
  echo "✓ Initialization complete! Welcome to the lab."
  echo ""
fi
INIT_CHECK_EOF

# Add function to calculate time left for prompt
cat >> /home/ubuntu/.bashrc <<'PROMPT_EOF'

# Function to show time left in prompt
prompt_time_left() {
  if [ -f /var/work/target_time ]; then
    local target=$(cat /var/work/target_time 2>/dev/null)
    local current=$(date +%s)
    local left=$(echo "($target-$current)/60" | bc 2>/dev/null)
    if [ "$left" -gt 0 ] 2>/dev/null; then
      echo "${left}min"
    else
      echo "TIME_UP"
    fi
  fi
}

# Custom PS1 with time left
export PS1='\[\033[0;38;5;10m\]\u@\h\[\033[0;38;5;11m\]{\[\033[0;38;5;9m\]$(prompt_time_left)\[\033[0;38;5;11m\]}\[\033[0;38;5;14m\]:\[\033[0;38;5;6m\]\w\[\033[0;38;5;10m\]>\[\033[0m\] '
PROMPT_EOF

# Configure MOTD
echo "*** Configuring colorful dynamic MOTD"
chmod -x /etc/update-motd.d/* 2>/dev/null || true

cat > /etc/update-motd.d/00-custom-banner <<'MOTD_EOF'
#!/bin/bash
RED='\033[1;91m'
YELLOW='\033[1;93m'
GREEN='\033[1;92m'
CYAN='\033[1;96m'
BLUE='\033[1;94m'
MAGENTA='\033[1;95m'
WHITE='\033[1;97m'
RESET='\033[0m'
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}          ICA Lab Environment - Custom Configuration          ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${YELLOW}📋 AVAILABLE COMMANDS:${RESET}"
echo -e "   ${GREEN}•${RESET} ${WHITE}time_left${RESET}      - Check remaining lab time"
echo -e "   ${GREEN}•${RESET} ${WHITE}check_result${RESET}   - Verify exercise completion"
echo -e "   ${GREEN}•${RESET} ${WHITE}check_result <task> like check_result 12 will check task 12${RESET}"
echo -e "   ${GREEN}•${RESET} ${WHITE}hosts${RESET}          - Show ingress gateway info"
echo ""
echo -e "${BLUE}🔧 PRE-CONFIGURED TOOLS ${CYAN}(with bash completion)${BLUE}:${RESET}"
echo -e "   ${GREEN}•${RESET} ${WHITE}kubectl | k${RESET}    - Kubernetes CLI ( ${RED}k${RESET} alias for kubectl )"
echo -e "   ${GREEN}•${RESET} ${WHITE}istioctl${RESET}       - Istio service mesh CLI"
echo -e "   ${GREEN}•${RESET} ${WHITE}helm${RESET}           - Kubernetes package manager"
echo ""
echo -e "${MAGENTA}🛠️  UTILITY TOOLS:${RESET}"
echo -e "   ${GREEN}•${RESET} ${WHITE}yq${RESET}             - YAML processor"
echo -e "   ${GREEN}•${RESET} ${WHITE}curl, wget${RESET}     - HTTP testing tools"
echo -e "   ${GREEN}•${RESET} ${WHITE}podman${RESET}         - Container management"
echo -e "   ${GREEN}•${RESET} ${WHITE}aws${RESET}            - AWS CLI"
echo ""
echo -e "${YELLOW}💡 Note:${RESET} All tools include bash completion ${CYAN}(not in original exam)${RESET}"
echo ""
echo -e "${GREEN}🔗 SSH to cluster nodes:${RESET} ${WHITE}ssh <kubernetes_nodename>${RESET}"
echo ""
MOTD_EOF

chmod +x /etc/update-motd.d/00-custom-banner

for pam_file in /etc/pam.d/sshd /etc/pam.d/login; do
  sed -i 's/^session.*pam_motd.so/#&/' $pam_file 2>/dev/null || true
done

systemctl disable --now motd-news.timer 2>/dev/null || true
rm -f /etc/motd 2>/dev/null || true
echo "run-parts /etc/update-motd.d/" | tee -a /root/.bashrc /home/ubuntu/.bashrc > /dev/null

# Install Cockpit web console (optional)
enable_web_console="${ENABLE_WEB_CONSOLE}"
if [ "$enable_web_console" = "true" ]; then
    echo "Installing Cockpit web console..."
    apt-get update
    apt-get install -y cockpit cockpit-system
    systemctl enable --now cockpit.socket

    cat << 'COCKPIT_CONF' | tee /etc/cockpit/cockpit.conf
[WebService]
LoginTitle = ICA Lab Terminal
Shell = /bin/bash

[Session]
IdleTimeout = 0
COCKPIT_CONF

    systemctl restart cockpit
    echo "Cockpit installed - access at https://$(hostname -I | awk '{print $1}'):9090"

    echo "Installing nginx redirect..."
    apt-get install -y nginx
    cat <<'NGINX_CONF' | tee /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    location / {
        return 302 https://$host:9090/cockpit/@localhost/system/terminal.html;
    }
}
NGINX_CONF

    systemctl restart nginx
    systemctl enable nginx
    echo "Nginx redirect installed - http://$(hostname -I | awk '{print $1}')/"
else
    echo "Web console (Cockpit) is disabled."
fi

# ========================================
# SECTION 3: Download tests and setup SSH keys
# ========================================

echo "*** download tests and create directories"
mkdir -p /var/work/tests/result /var/work/tests/artifacts $configs_dir $default_configs_dir /home/ubuntu/.kube

# Download all test files
echo "Downloading test files..."
for i in {01..17}; do
  test_file="tests-$i.bats"
  echo "  Downloading $test_file..."
  curl -f "${TEST_BASE_URL}/$test_file" -o "/var/work/tests/$test_file" -s 2>/dev/null || echo "  $test_file not found (skipping)"
done

chown -R ubuntu:ubuntu /var/work/tests/
chmod -R 777 /var/work/tests/

# Setup SSH keys for both users
for user_home in /root /home/ubuntu; do
  echo "${SSH_PRIVATE_KEY}" > $user_home/.ssh/id_rsa
  chmod 600 $user_home/.ssh/id_rsa
  echo "${SSH_PUB_KEY}" >> $user_home/.ssh/authorized_keys
done
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

# ========================================
# SECTION 4: Cluster operations
# ========================================

# Function to wait for cluster readiness
function wait_cluster_ready {
  echo "wait cluster $1 ready"
  aws s3 ls $2
  while test $? -gt 0; do
    sleep 10
    echo "wait cluster $1 ready .Trying again..."
    aws s3 ls $2
  done
  date
}

# Download and merge kubeconfig files from clusters
export KUBECONFIG=''
clusters_config="${CLUSTERS_CONFIG}"
for cluster in $clusters_config; do
  cluster_name=$(echo "$cluster" | cut -d'=' -f1)
  cluster_config_url=$(echo "$cluster" | cut -d'=' -f2)
  echo "$cluster_name   $cluster_config_url"
  wait_cluster_ready "$cluster_name" "$cluster_config_url"
  aws s3 cp $cluster_config_url $cluster_name
  cat $cluster_name | sed -e 's/kubernetes/'$cluster_name'/g' >/var/work/configs/$cluster_name
  KUBECONFIG+="$configs_dir/$cluster_name:"
done

kubectl config view --flatten > $default_configs_dir/config

export KUBECONFIG=/root/.kube/config
kubectl config get-contexts

# Copy kubeconfig to ubuntu user
cp /root/.kube/config /home/ubuntu/.kube/config
cp /root/.kube/config /home/ubuntu/.kube/_config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 700 /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config /home/ubuntu/.kube/_config

# Setup exam timer
target_time_stamp=$(echo "$(date +%s)+${EXAM_TIME_MINUTES}*60" | bc)
start_time_stamp=$(date +%s)

echo "$target_time_stamp" > /var/work/target_time
echo "$start_time_stamp" > /var/work/start_time
chmod 644 /var/work/target_time /var/work/start_time

cat > /usr/bin/exam_check.sh <<EOF
#!/bin/bash
if [[ "\$(date +%s)" -gt "$target_time_stamp" ]]; then
  wall "*** time is over. disabled config, please run < check_result >"
  rm /home/ubuntu/.kube/config
  rm /usr/bin/exam_check.sh
fi
EOF

chmod +x /usr/bin/exam_check.sh

cat << 'CRON_EOF' | crontab -
* * * * * /usr/bin/exam_check.sh >> /var/log/exam_check.log

CRON_EOF

# Download task-specific script
curl "${TASK_SCRIPT_URL}" -o "task.sh"
chmod +x task.sh
./task.sh

# Mark initialization as complete
echo "$(date): Initialization complete" >> /var/work/init_status
touch /var/work/.init_complete
chmod 644 /var/work/.init_complete


wall "
=======================================================================
========= Initialization complete, please reload your terminal ========
========= Cause some functions init might take additional time ========
=======================================================================

                        ██████████████  
                      ████░░████████████
                      ██████████████████
                      ██████████████████
                      ██████████████████
                      ████████          
                      ██████████████░░  
                      ██████            
  ██              ██████████            
  ██▒▒        ▒▒▒▒██████████▒▒▒▒        
  ████▓▓      ██████████████  ▒▒        
  ██████▒▒▒▒████████████████            
  ██████████████████████████            
    ██████████████████████              
        ██████████████████              
        ▒▒██████████████                
          ▒▒██████▒▒██▓▓                
            ████      ▓▓                
            ██▒▒      ▓▓                
            ██        ██                 
"
