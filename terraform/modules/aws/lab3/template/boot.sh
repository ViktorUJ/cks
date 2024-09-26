#!/bin/bash

yum update -y
yum install -y docker
service docker start
usermod -a -G docker ec2-user
chkconfig docker on

# logs

yum install -y amazon-cloudwatch-agent

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
instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)

docker run -e SERVER_NAME="$instance_id" -p 0.0.0.0:80:8080 --name app viktoruj/ping_pong   > /var/log/app.log