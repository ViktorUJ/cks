#!/bin/bash
echo " *** worker pc mock-3  "

mkdir -p /opt/course/9/
cd /opt/course/9/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/worker/files/profile

mkdir -p /var/work/14/
cd /var/work/14/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/worker/files/14/Dockerfile
chmod 777 Dockerfile

sudo mkdir -p /etc/containers
sudo tee /etc/containers/policy.json <<EOF
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
EOF

# _________________________________________________________________
# 19 TASK
address=$(kubectl get no -l work_type=worker --context cluster6-admin@cluster6 -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address cks.local">>/etc/hosts


# Set the directory for certificates
CERT_DIR="/var/work/19"
KEY_DIR="/var/work/19"
DOMAIN="cks.local"
mkdir -p $CERT_DIR $KEY_DIR
CERT_FILE="$CERT_DIR/$DOMAIN.crt"
KEY_FILE="$KEY_DIR/$DOMAIN.key"

# Check if the certificate and key already exist
if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
    echo "Certificate and key already exist:"
    echo "  Certificate: $CERT_FILE"
    echo "  Key: $KEY_FILE"
    exit 0
fi

# Generate a self-signed certificate
openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Set the correct permissions
chmod +r "$KEY_FILE"
chmod +r "$CERT_FILE"

# Output information about the created files
echo "Self-signed certificate created:"
echo "  Certificate: $CERT_FILE"
echo "  Key: $KEY_FILE"

# bom install

acrh=$(uname -m)
case $acrh in
  x86_64)
    url="https://sre-platform.aws-guru.com/download/bom-linux-amd64"
    ;;
  aarch64)
    url="https://sre-platform.aws-guru.com/download/bom-linux-arm64"
    ;;
esac

curl -o bom -L $url
chmod +x bom
mv bom  /usr/bin/

# trivy install
apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" |  tee -a /etc/apt/sources.list.d/trivy.list
apt-get update
apt-get install trivy -y
sudo -u ubuntu trivy image --download-db-only

# tast 2

mkdir -p /var/work/02/
chmod 777 -R /var/work/02/
sudo -u ubuntu bom generate --image registry.k8s.io/kube-controller-manager:v1.32.0 --format json --output /var/work/02/check_sbom.json

sudo -u ubuntu trivy image  nginx:1.23-bullseye-perl

sudo -u ubuntu trivy image --format cyclonedx --output /tmp/1.json  nginx:1.23-bullseye-perl
