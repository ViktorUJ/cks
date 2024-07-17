#/bin/bash

mkdir -p /opt/22/tasks

echo "SuperSecretString1" > /opt/22/tasks/aclfile
echo "SuperSecretString2" > /opt/22/tasks/frozenfile

adduser --disabled-password --gecos "" user0
adduser --disabled-password --gecos "" user22

setfacl -m u:user0:r /opt/22/tasks/aclfile
chattr +i /opt/22/tasks/frozenfile
