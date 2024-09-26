#!/bin/bash

yum update -y
yum install -y docker
service docker start
usermod -a -G docker ec2-user
chkconfig docker on

# logs

yum install -y amazon-cloudwatch-agent

cat <<EOF > /opt/aws/amazon-cloudwatch-agent/bin/cloudwatch-config.json
{
  "metrics": {
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user"
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
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
          "bytes_in",
          "bytes_out"
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${aws_cloudwatch_log_group}/system",
            "log_stream_name": "{instance_id}/messages",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "${aws_cloudwatch_log_group}/secure",
            "log_stream_name": "{instance_id}/secure",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/dmesg",
            "log_group_name": "${aws_cloudwatch_log_group}/dmesg",
            "log_stream_name": "{instance_id}/dmesg",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/boot.log",
            "log_group_name": "${aws_cloudwatch_log_group}/boot",
            "log_stream_name": "{instance_id}/boot",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/app.log",
            "log_group_name": "${aws_cloudwatch_log_group}/app_log",
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
docker run -p 0.0.0.0:80:8080 --name app viktoruj/ping_pong > /var/log/app.log