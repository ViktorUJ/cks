#!/bin/bash
echo " *** worker pc mock-1  "

# Helm installation
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

mkdir -p /opt/logs/ /opt/18/
chmod a+w /opt/logs/ /opt/18/
