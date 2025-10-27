#!/bin/bash

# -------- import values from terraform into local bash vars --------
ssh_password_enable_check=${ssh_password_enable}
ssh_password_sh=${ssh_password}

runtime_sh=${runtime}
k8_version_sh=${k8_version}
k8s_config_sh=${k8s_config}
worker_join_sh=${worker_join}
pod_network_cidr_sh=${pod_network_cidr}
external_ip_sh=${external_ip}
utils_enable_sh=${utils_enable}
cni_type_sh=${cni_type}
cilium_version_sh=${cilium_version}
cilium_helm_version_sh=${cilium_helm_version}
disable_kube_proxy_sh=${disable_kube_proxy}
kubeadm_init_extra_args_sh=${kubeadm_init_extra_args}
runtime_script_sh=${runtime_script}
calico_url_sh=${calico_url}
task_script_url_sh=${task_script_url}
ssh_private_key_sh=${ssh_private_key}
ssh_pub_key_sh=${ssh_pub_key}

date
swapoff -a

# -------- ssh password auth enable/disable --------
case "$ssh_password_enable_check" in
true)
    echo "*** ssh password enable "
    echo "ubuntu:${ssh_password_sh}" | sudo chpasswd

    SSH_CONFIG_FILE="/etc/ssh/sshd_config"
    SSH_CONFIG_FILE_CLOUD="/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"

    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' "$SSH_CONFIG_FILE"
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' "$SSH_CONFIG_FILE"
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' "$SSH_CONFIG_FILE_CLOUD"

    systemctl restart sshd
    ;;
*)
    echo "*** ssh password not enable "
    ;;
esac

# -------- prereqs --------
apt-get update && sudo apt-get upgrade -y
apt-get install -y unzip apt-transport-https ca-certificates curl jq
swapoff -a

# install runtime (containerd/crio/etc) from provided script snippet
# NOTE: runtime_script_sh is expected to be valid bash commands
eval "$runtime_script_sh"

# -------- build kubeadm config file --------
local_ipv4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || echo "127.0.0.1")

apiserver_sans="localhost,127.0.0.1,${local_ipv4}"
if [ -n "$external_ip_sh" ]; then
    apiserver_sans="${apiserver_sans},${external_ip_sh}"
fi

KUBEADM_CONFIG_FILE="/root/kubeadm-lab.yaml"

# 1. static part (no extraArgs yet)
cat > "$KUBEADM_CONFIG_FILE" <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "v${k8_version_sh}"
networking:
  podSubnet: "${pod_network_cidr_sh}"
apiServer:
  certSANs:
EOF

# 2. certSANs list
echo "$apiserver_sans" | tr ',' '\n' | sed 's/^/    - "/; s/$/"/' >> "$KUBEADM_CONFIG_FILE"

# 3. extraArgs from kubeadm_init_extra_args_sh ("k=v,k2=v2,...")
if [ -n "$kubeadm_init_extra_args_sh" ]; then
    echo "  extraArgs:" >> "$KUBEADM_CONFIG_FILE"
    IFS=',' read -ra kv_list <<< "$kubeadm_init_extra_args_sh"
    for kv in "${kv_list[@]}"; do
        key="${kv%%=*}"
        val="${kv#*=}"
        printf '    %s: "%s"\n' "$key" "$val" >> "$KUBEADM_CONFIG_FILE"
    done
fi

echo "*** kubeadm config file $KUBEADM_CONFIG_FILE:"
cat "$KUBEADM_CONFIG_FILE"

# -------- kubeadm init using config --------
if [ "$disable_kube_proxy_sh" = "true" ]; then
    echo "*** disable kube-proxy"
    echo "*** kubeadm init --ignore-preflight-errors=NumCPU,Mem --config $KUBEADM_CONFIG_FILE --skip-phases=addon/kube-proxy"
    kubeadm init --ignore-preflight-errors=NumCPU,Mem --config "$KUBEADM_CONFIG_FILE" --skip-phases=addon/kube-proxy
else
    echo "*** kubeadm init default kube-proxy"
    echo "*** kubeadm init --ignore-preflight-errors=NumCPU,Mem --config $KUBEADM_CONFIG_FILE"
    kubeadm init --ignore-preflight-errors=NumCPU,Mem --config "$KUBEADM_CONFIG_FILE"
fi

# -------- kubeconfig for root and ubuntu --------
mkdir -p /root/.kube
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown "$(id -u)":"$(id -g)" /root/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# -------- upload kubeconfig and join command --------
aws s3 cp /root/.kube/config "s3://${k8s_config_sh}"

kubeadm token create --print-join-command --ttl 90000m > /root/join_node
aws s3 cp /root/join_node "s3://${worker_join_sh}"

date

# wait for api/node ready
kubectl get node --kubeconfig=/root/.kube/config || true
while ! kubectl get node --kubeconfig=/root/.kube/config >/dev/null 2>&1 ; do
   sleep 5
   echo "Trying again..."
done

date

# -------- CNI install --------
echo "*** apply cni"
export KUBECONFIG=/root/.kube/config
acrh=$(uname -m)

case "$acrh" in
x86_64)
  cilium_url="https://github.com/cilium/cilium-cli/releases/download/${cilium_version_sh}/cilium-linux-amd64.tar.gz"
  ;;
aarch64)
  cilium_url="https://github.com/cilium/cilium-cli/releases/download/${cilium_version_sh}/cilium-linux-arm64.tar.gz"
  ;;
*)
  cilium_url=""
  ;;
esac

case "$cni_type_sh" in
calico)
   kubectl apply -f "${calico_url_sh}" --kubeconfig=/root/.kube/config
   ;;
cilium)
   echo "*** install cilium cilium_url=$cilium_url"
   curl -Lo /root/cilium.tar.gz "$cilium_url"
   tar -C /root -zxvf /root/cilium.tar.gz
   mv /root/cilium /usr/local/bin/cilium
   cilium install --version "${cilium_helm_version_sh}"
   ;;
*)
   echo "cni type = $cni_type_sh not support"
   ;;
esac

echo "sleep 10"
sleep 10

kubectl get node --kubeconfig=/root/.kube/config
date

# -------- utils --------
apt-get install -y bash-completion binutils vim

{
echo 'source /usr/share/bash-completion/bash_completion'
echo 'source <(kubectl completion bash)'
echo 'alias k=kubectl'
echo 'complete -F __start_kubectl k'
} >> /root/.bashrc

{
echo 'source /usr/share/bash-completion/bash_completion'
echo 'source <(kubectl completion bash)'
echo 'alias k=kubectl'
echo 'complete -F __start_kubectl k'
} >> /home/ubuntu/.bashrc

case "$acrh" in
x86_64)
  skaffold_url="https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ;;
aarch64)
  skaffold_url="https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-arm64"
  curl -Lo /root/helm.tar.gz https://get.helm.sh/helm-v3.13.1-linux-arm.tar.gz
  tar -C /root -zxvf /root/helm.tar.gz
  mv /root/linux-arm/helm /usr/local/bin/helm
  ;;
esac

if [ "$utils_enable_sh" = "true" ] ; then
  echo "*** install utils "
  helm plugin install https://github.com/jkroepke/helm-secrets --version v3.8.2
  helm plugin install https://github.com/sstarcher/helm-release

  curl -Lo /usr/local/bin/skaffold "$skaffold_url"
  chmod +x /usr/local/bin/skaffold

  {
  echo 'complete -C "/usr/local/bin/aws_completer" aws'
  echo 'source <(helm completion bash)'
  echo 'source <(skaffold completion bash)'
  } >> /root/.bashrc

  {
  echo 'complete -C "/usr/local/bin/aws_completer" aws'
  echo 'source <(helm completion bash)'
  echo 'source <(skaffold completion bash)'
  } >> /home/ubuntu/.bashrc
fi

# -------- custom task --------
curl -s "$task_script_url_sh" -o /root/task.sh
chmod +x /root/task.sh
/root/task.sh

# -------- ssh keys for ubuntu --------
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

cat > /home/ubuntu/.ssh/id_rsa <<EOF
$ssh_private_key_sh
EOF
chmod 600 /home/ubuntu/.ssh/id_rsa

cat >> /home/ubuntu/.ssh/authorized_keys <<EOF
$ssh_pub_key_sh
EOF

chown -R ubuntu:ubuntu /home/ubuntu/.ssh
