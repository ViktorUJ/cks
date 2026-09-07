#!/bin/bash
echo " *** worker pc mock-3  "

# --- check_result_timed -----------------------------------------------------
# Mock03 содержит 22 задания - больше типичного диапазона реального экзамена
# (15-20 performance-based задач за 2 часа, по официальному LF snapshot). Общий
# check_result (из shared worker.sh) честно считает все 22 задания и не даёт
# 100% за выполнение только первых ~20 - это well-known ограничение fidelity.
#
# check_result_timed - локальное дополнение именно для этого мока. Раньше оно
# пыталось вырезать первые N строк из общих result/all и result/ok, но это
# было логически некорректно: result/ok пишется ТОЛЬКО при успехе теста, поэтому
# после первого провала все последующие успешные записи сдвигаются на одну
# позицию вверх - успешная задача 21-22 могла "занять" позицию проваленной
# задачи 1-20 и дать 100% при реально незакрытом timed-наборе.
#
# Правильное решение: tests_timed.bats - отдельный файл, точная копия секции
# Tasks 1-20 из tests.bats (включая Init), пишущий в СВОИ файлы результатов
# (result/timed_all, result/timed_ok), не пересекающиеся с обычным result/all
# и result/ok. Это гарантирует позиционную корректность денумератора и
# нумератора без вырезания строк, и не запускает acceptance-проверки заданий
# 21-22 вовсе - то есть их провал/успех физически не может повлиять на timed score.
cat > /usr/bin/check_result_timed <<'EOF'
#!/bin/bash
bats /var/work/tests/tests_timed.bats
sum_all=0; for v in $(cat /var/work/tests/result/timed_all); do sum_all=$(echo "$sum_all+$v" | bc); done
sum_ok=0; for v in $(cat /var/work/tests/result/timed_ok); do sum_ok=$(echo "$sum_ok+$v" | bc); done
result=$(echo "scale=2 ; $sum_ok/$sum_all*100" | bc)
echo " timed result (tasks 1-20 only, tasks 21-22 not evaluated here) = $result %   ok_points=$sum_ok  all_points=$sum_all  "
echo " (полный check_result с учётом заданий 21-22 запускается отдельно: check_result)"
time_left
EOF
chmod +x /usr/bin/check_result_timed
wget -q -O /var/work/tests/tests_timed.bats https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/worker/files/tests_timed.bats
chown ubuntu:ubuntu /var/work/tests/tests_timed.bats
# -----------------------------------------------------------------------------

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
