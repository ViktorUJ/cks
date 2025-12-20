#!/bin/bash
# Minimal bypass bootstrap - downloads full init script from GitHub
set -e

# Export variables for the main script
export HOSTS="${hosts}"
export CLUSTERS_CONFIG="${clusters_config}"
export KUBECTL_VERSION="${kubectl_version}"
export SSH_PRIVATE_KEY="${ssh_private_key}"
export SSH_PUB_KEY="${ssh_pub_key}"
export EXAM_TIME_MINUTES="${exam_time_minutes}"
export TEST_BASE_URL="${test_base_url}"
export TASK_SCRIPT_URL="${task_script_url}"
export SSH_PASSWORD="${ssh_password}"
export SSH_PASSWORD_ENABLE="${ssh_password_enable}"
export ENABLE_WEB_CONSOLE="${enable_web_console}"

# Download and execute full initialization script from GitHub
FULL_INIT_URL="https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ica/mock/01/worker/files/init-full.sh"

echo "*** Downloading full initialization script from GitHub..."
curl -fsSL "$FULL_INIT_URL" -o /tmp/init-full.sh
chmod +x /tmp/init-full.sh

echo "*** Executing full initialization..."
/tmp/init-full.sh