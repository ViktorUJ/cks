#!/bin/bash

mkdir -p /opt/09/task \
  /tmp/tar \
  /tmp/zip/ \
  /opt/09/solution/tarbackup \
  /opt/09/solution/zipbackup

for i in {1..10}; do
  echo "This is a dummy file$i for tar." > /tmp/tar/file_$i.txt
  echo "This is a dummy file$i for zip." > /tmp/zip/file_$i.txt
done

cd /tmp/tar/
tar -czf /opt/09/task/backup.tar.gz *
cd -
cd /tmp/zip/
zip -r /opt/09/task/backup.zip file*
cd -
rm -rf /tmp/tar /tmp/zip
