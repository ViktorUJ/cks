#!/bin/bash

yum update -y
yum install -y docker nginx  amazon-cloudwatch-agent
service docker start
usermod -a -G docker ec2-user
chkconfig docker on


declare -i  docker_worker_count=55 # small 55  , micro 27 ,
declare -i start_port=8080
#server_bin_url="https://ws-assets-prod-iad-r-fra-b129423e91500967.s3.amazonaws.com/5fb682bf-699a-4972-848b-ab4a1ec243d5/server-binary.py"
server_bin_url="https://ws-assets-prod-iad-r-fra-b129423e91500967.s3.amazonaws.com/5fb682bf-699a-4972-848b-ab4a1ec243d5/server-binary-v2.py"
# logs


cat <<'EOF' > /opt/aws/amazon-cloudwatch-agent/bin/cloudwatch-config.json
{
  "metrics": {  
    "append_dimensions": {   
      "InstanceId": "$${aws:InstanceId}",
      "autoScalingGroupName": "$${aws:AutoScalingGroupName}"
    },
    "metrics_collected": {      "cpu": {
        "measurement": [          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user"
        ],
        "metrics_collection_interval": 60,        "resources": ["*"]
      },      "disk": {        "measurement": [
          "used_percent"
        ],        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "net": {
        "measurement": [
          "bytes_sent",
          "bytes_recv"
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      }
    }
  },
  "agent": {
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
    "region": "${aws_region}"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "${aws_cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/init",
            "timezone": "UTC"
          },

          {
            "file_path": "/var/log/app.log",
            "log_group_name": "${aws_cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/app_log",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}


EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/bin/cloudwatch-config.json \
  -s


# app
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`

instance_id=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)



cat <<EOF > Dockerfile

FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O server-binary.py  $server_bin_url

RUN chmod +x server-binary.py

CMD ["python3.9", "server-binary.py"]

EOF

docker build -t app .



for ((i=0; i<docker_worker_count; i++)); do
  echo "Starting container $i"
  docker run -d -p $((start_port+i)):80 --name "app-$i" app
done

### Nginx

#!/bin/bash

# Параметры
declare -i docker_worker_count=50  # small 50, micro 25
declare -i start_port=8080         # Начальный порт для контейнеров

# Путь для конфигурации Nginx
nginx_conf="/etc/nginx/nginx.conf"

# Генерация основной конфигурации Nginx
echo "Генерация новой конфигурации для Nginx..."

cat > "$nginx_conf" <<EOL
user nginx;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

http {
    upstream backend {
EOL

# Добавляем бэкэнды для всех контейнеров
for ((i=0; i<docker_worker_count; i++)); do
  echo "        server 127.0.0.1:$((start_port+i));" >> "$nginx_conf"
done

cat >> "$nginx_conf" <<EOL
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}
EOL

echo "Новая конфигурация для Nginx сгенерирована: $nginx_conf"

# Перезапуск Nginx для применения новой конфигурации
echo "Перезапуск Nginx..."
nginx -t

chkconfig nginx on
service nginx start
