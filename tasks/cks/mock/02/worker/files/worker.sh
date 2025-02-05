#!/bin/bash
echo " *** worker pc mock-1  "

mkdir -p /opt/course/9/
cd /opt/course/9/
wget https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/worker/files/profile

mkdir -p /var/work/14/
cd /var/work/14/
wget https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/worker/files/14/Dockerfile
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
chmod 600 "$KEY_FILE"
chmod 600 "$CERT_FILE"

# Output information about the created files
echo "Self-signed certificate created:"
echo "  Certificate: $CERT_FILE"
echo "  Key: $KEY_FILE"