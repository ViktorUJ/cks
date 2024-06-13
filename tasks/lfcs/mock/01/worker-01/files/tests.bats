#!/usr/bin/env bats

@test "0  Init" {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]
}

#1.1
@test "1.1 Check if a hard link exists." {
  file1_inode=$(stat -c '%i' "/home/ubuntu/file1")
  file2_inode=$(stat -c '%i' "/opt/file1")
  echo '0.5'>>/var/work/tests/result/all
  if [[ $file1_inode -eq $file2_inode ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ $file1_inode -eq $file2_inode ]
}

# 1.2
@test "1.2 Check if a symbolic link exists." {
  echo '0.5'>>/var/work/tests/result/all
  if  [[ -L "/opt/softlinkfile" ]]; then
   echo '0.5' >> /var/work/tests/result/ok
  fi
  [ -L "/opt/softlinkfile" ]
}

#2.1
@test "2.1 Check file UID and GID" {
  result=$(stat -c '%u:%g' "/home/ubuntu/file2")
  echo '0.5'>>/var/work/tests/result/all
  if [[ "$result" == "750:750" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "750:750" ]
}

#2.2
@test "2.2 Check file permissions" {
  result=$(stat -c '%a' "/home/ubuntu/file2")
  echo '0.5' >> /var/work/tests/result/all
  if [ "$result" == "644" ] || [ "$result" == "4664" ]; then
    echo $result
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "644" ] || [ "$result" == "4664" ]
}

#2.3
@test "2.3 Check SUID flag" {
  echo '1'>>/var/work/tests/result/all
  if [[ -u "/home/ubuntu/file2" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ -u "/home/ubuntu/file2" ]
}

#3.1
@test "3.1 Check if a folder exists" {
  echo '0.25'>>/var/work/tests/result/all
  if [[ -d "/opt/newdir" ]]; then
   echo '0.25'>>/var/work/tests/result/ok
  fi
  [ -d "/opt/newdir" ]
}

#3.2
@test "3.2 Check if a file31 was moved" {
  echo '0.25'>>/var/work/tests/result/all
  if [[ ! -e "/home/ubuntu/file31" ]] && [[ -e "/opt/newdir/file31" ]]; then
   echo '0.25'>>/var/work/tests/result/ok
  fi
  [ ! -e "/home/ubuntu/file31" ] && [ -e "/opt/newdir/file31" ]
}

#3.3
@test "3.3 Check if a file32 was copied" {
  echo '0.25'>>/var/work/tests/result/all
  if [ -e "/home/ubuntu/file32" ] && [ -e "/opt/newdir/file32" ]; then
   echo '0.25'>>/var/work/tests/result/ok
  fi
  [ -e "/home/ubuntu/file32" ] && [ -e "/opt/newdir/file32" ]
}

#3.4
@test "3.4 Check if a file33 was removed" {
  echo '0.25'>>/var/work/tests/result/all
  if [[ ! -e "/home/ubuntu/file33" ]]; then
   echo '0.25'>>/var/work/tests/result/ok
  fi
  [ ! -e "/home/ubuntu/file33" ]
}

# 4
@test "4 Check if a folder does have sticky bit enabled" {
  stat -c '%A' "/home/ubuntu/file2" | grep S
  status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ $status -eq 0 ]]; then
    echo $result
    echo '1' >> /var/work/tests/result/ok
  fi
  [ $status -eq 0 ]
}

# 5
@test "5.1 Check the filtering out files with executable permissions." {
  find "/opt/05/task" -type f -perm -u=x > /var/work/tests/artifacts/task0501
  echo '1' >> /var/work/tests/result/all
  if diff -q <(cat /var/work/tests/artifacts/task0501 | sort) <(cat /opt/05/result/execuser | sort) &>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff -q <(cat /var/work/tests/artifacts/task0501 | sort) <(cat /opt/05/result/execuser | sort) &>/dev/null
}

@test "5.2 Check the filtering out files with SETUID permissions." {
  rm -rf /var/work/tests/artifacts/task0502 && mkdir /var/work/tests/artifacts/task0502
  find "/opt/05/task" -type f -perm -4000 -exec cp {} /var/work/tests/artifacts/task0502/ \;
  echo '1' >> /var/work/tests/result/all
  if diff -q <(ls -1 /var/work/tests/artifacts/task0502 | sort) <(ls -1 /opt/05/result/setuid | sort) &>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff -q <(ls -1 /var/work/tests/artifacts/task0502 | sort) <(ls -1 /opt/05/result/setuid | sort);
}

@test "5.3 Check the filtering out files that larget than 1KB" {
  rm -rf /var/work/tests/artifacts/task0503 && mkdir /var/work/tests/artifacts/task0503
  find "/opt/05/task" -type f -size +1k -exec cp {} "/var/work/tests/artifacts/task0503/" \;
  echo '1' >> /var/work/tests/result/all
  if diff -q <(ls -1 /var/work/tests/artifacts/task0503 | sort) <(ls -1 /opt/05/result/05kb | sort) &>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff -q <(ls -1 /var/work/tests/artifacts/task0503 | sort) <(ls -1 /opt/05/result/05kb | sort) &>/dev/null;
}

# 6
@test "6 Check the files that contain findme word" {
  rm -rf /var/work/tests/artifacts/task06 && mkdir /var/work/tests/artifacts/task06
  find /opt/06/task -type f -exec grep -q 'findme' {} \; -exec cp {} /var/work/tests/artifacts/task06 \;
  echo '2' >> /var/work/tests/result/all
  if diff -q <(ls -1 /var/work/tests/artifacts/task06 | sort) <(ls -1 /opt/06/result | sort) &>/dev/null; then
    echo '2' >> /var/work/tests/result/ok
  fi
  diff -q <(ls -1 /var/work/tests/artifacts/task06 | sort) <(ls -1 /opt/06/result | sort) &>/dev/null
}

#7
@test "7.1 Check the new line system71=enabled added to the end of file" {
  echo '0.5' >> /var/work/tests/result/all
  if tail -n 1 /etc/config.conf | grep "system71=enabled"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  tail -n 1 /etc/config.conf | grep "system71=enabled"
}

@test "7.2 Check if the script /opt/07/filter.sh is working" {
  echo '1' >> /var/work/tests/result/all
  if diff -q <( /opt/07/filter.sh | sort) <( cat /etc/config.conf | grep enabled | sort) &>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff -q <( /opt/07/filter.sh | sort) <( cat /etc/config.conf | grep enabled | sort) &>/dev/null;
}

@test "7.3 Check if the all parameters have been enabled." {
  echo '0.5' >> /var/work/tests/result/all
  if [[ $(grep -o disabled /etc/config.conf | wc -l) == 0 ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [[ $(grep -o disabled /etc/config.conf | wc -l) == 0 ]]
}

# 8
@test "8.1 Check tar archieve to be created" { 
  mkdir -p /var/work/tests/artifacts/08-tar/
  rm -rf /var/work/tests/artifacts/08-tar/*
  tar -xf /opt/08/results/mytar.tar -C /var/work/tests/artifacts/08-tar/
  diff /var/work/tests/artifacts/08-tar/ /opt/08/files/
  status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "8.2 Check tar.gz archive to be created" {
  mkdir -p /var/work/tests/artifacts/08-targz/
  rm -rf /var/work/tests/artifacts/08-targz/*
  tar -xf /opt/08/results/mytargz.tar.gz -C /var/work/tests/artifacts/08-targz/
  echo '1' >> /var/work/tests/result/all
  diff /var/work/tests/artifacts/08-targz/ /opt/08/files/
  status=$?
  if [[ "$status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "8.3 Check tar.bz2 archive to be created" {
  mkdir -p /var/work/tests/artifacts/08-tarbz/
  rm -rf /var/work/tests/artifacts/08-tarbz/*
  tar -xf /opt/08/results/mybz.tar.bz2 -C /var/work/tests/artifacts/08-tarbz/
  echo '1' >> /var/work/tests/result/all
  diff /var/work/tests/artifacts/08-tarbz/ /opt/08/files/
  status=$?
  if [[ "$status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "8.4 Check zip archive to be created" {
  mkdir -p /var/work/tests/artifacts/08-zip/
  rm -rf /var/work/tests/artifacts/08-zip/*
  unzip /opt/08/results/myzip.zip -d /var/work/tests/artifacts/08-zip/
  echo '1' >> /var/work/tests/result/all
  diff /var/work/tests/artifacts/08-zip/ /opt/08/files/
  status=$?
  if [[ "$status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

# 9
@test "9.1 Check extracted tar.gz archive" {
  mkdir -p /var/work/tests/artifacts/09/targz/ && tar -xf /opt/09/task/backup.tar.gz -C /var/work/tests/artifacts/09/targz/
  echo '1' >> /var/work/tests/result/all
  diff /var/work/tests/artifacts/09-tar/ /opt/09/solution/tarbackup
  status=$?
  if [[ "$status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "9.2 Check extracted zip archive" {
  mkdir -p /var/work/tests/artifacts/09/zip/ && tar -xf /opt/09/task/backup.zip -C /var/work/tests/artifacts/09/zip/
  echo '1' >> /var/work/tests/result/all
  diff /var/work/tests/artifacts/09/zip/ /opt/09/solution/tarbackup
  status=$?
  if [[ "$status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

# 10
@test "10.1 Check if the nginx service was installed." {
  echo '0.5' >> /var/work/tests/result/all
  systemctl list-units | grep nginx
  status=$?
  if [[ "$status" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "10.2 Check if the nginx service was enabled." {
  echo '0.5' >> /var/work/tests/result/all
  systemctl is-enabled nginx | grep enabled
  status=$?
  if [[ "$status" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

# 11
@test "11.1 Check creatiom of a user with name.cooluser" {
  id cooluser
  status=$?
  echo '0.5' >> /var/work/tests/result/all
  if [[ "$status" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "11.2 Check if a user has correct shell configured" {
  check_sh=$(cat /etc/passwd | grep cooluser | awk -F ':' '{print $7}')
  echo '0.25' >> /var/work/tests/result/all
  if [[ "$status" == "/bin/zsh" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "/bin/zsh" ]
}

@test "11.3 Check if user cooluser has sudo permissions" {
  sudo -lU cooluser &>/dev/null
  check_sudo=$?
  echo '0.25' >> /var/work/tests/result/all
  if [[ "$check_sudo" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$check_sudo" == "0" ]
}

#12
@test "12.1 Check a user spiderman for being unlocked." {
  status=$(sudo passwd -S spiderman | awk '{print $2}')
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" != "L" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" != "L" ]
}

@test "12.2 Check a batman spiderman for being locked." {
  status=$(sudo passwd -S batman | awk '{print $2}')
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" == "L" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "L" ]
}

#13
@test "13 Check if a user phoenix has hard limit of opening 20 processes." {
  exit_status=$(cat /etc/security/limits.conf | grep -E "phoenix.*hard.*nproc.*20")
  echo '1' >> /var/work/tests/result/all
  if [[ "$exit_status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$exit_status" == "0" ]
}

#14
@test "14 Check if skeleton file IMPORTANT_NOTES has been created." {
  exit_status=$(ls /etc/skel/IMPORTANT_NOTES)
  echo '1' >> /var/work/tests/result/all
  if [[ "$exit_status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$exit_status" -eq 0 ]
}

#15
@test "15 Check if a user jackson cannot use sudo." {
  sudo su - jackson -c 'sudo echo' &>/dev/null;
  exit_status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ "$exit_status" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$exit_status" -eq 1 ]
}

#16
@test "16 Check filtering out /etc/services file with the lines started from net." {
  diff <(grep "net" /etc/services | sort) <(sort /opt/16/result.txt)
  exit_status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ "$exit_status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$exit_status" == "0" ]
}

#17
@test "17.1 Check the correct difference between /opt/17/file1 and /opt/17/file2." {
  diff /opt/17/file1 /opt/17/file2 > /var/work/tests/artifacts/17_text_difference
  diff <(sort /var/work/tests/artifacts/17_text_difference) <(sort /opt/17/results/text_difference)
  exit_status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ "$exit_status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$exit_status" -eq 0 ]
}

@test "17.2 Check the correct difference between /opt/17/file1 and /opt/17/file2." {
  diff -rq /opt/17/dir1/ /opt/17/dir2/ > /var/work/tests/artifacts/17_folder_difference
  diff <(sort /var/work/tests/artifacts/17_folder_difference) <(sort /opt/17/results/folder_difference)
  exit_status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ "$exit_status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$exit_status" -eq 0 ]
} 

#18
@test "18 Check if docker ubuntu/apache2 container is running with name webserv" {
  status=$(docker inspect webserv | jq -r '.[].State.Status' )
  image=$(docker inspect webserv | jq -r '.[].Config.Image')
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" == "running" && "$image" == "ubuntu/apache2" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "running" && "$image" == "ubuntu/apache2" ]
}

#19
@test "19.1 Check the correct IP address of eth0 interface." {
  ipv4=$(ip addr show ens5 | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1 )
  grep $ipv4 /opt/19/result/ip
  status=$?
  echo '0.5' >> /var/work/tests/result/all
  if [[ "$status" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "19.2 Check the correct route table" {
  ip_route_result=$(ip route | sort)
  netstat_result=$(netstat -rn | sort)
  diff <(echo "$ip_route_result") <(sort /opt/19/result/routes) || diff <(echo "$netstat_result") <(sort /opt/19/result/routes)
  status=$?
  echo '0.5' >> /var/work/tests/result/all
  if [[ "$status" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "19.3 Check the correct PID of the service used 22 port." {
  diff $(lsof -i :22) -t $(cat /opt/19/result/pid)
  status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" -eq 0 ]
}

#20
@test "20.1 Check DNS resolver 1.1.1.1 on node02" {
  status=$(ssh -o 'StrictHostKeyChecking=no' node02 "grep -E \"nameserver.*1.1.1.1\" /etc/resolv.conf; echo \$?" )
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "20.2 Check static DNS resolution" {
  status=$(ssh -o 'StrictHostKeyChecking=no' node02 "grep -E \"10.10.20.5.*database.local\" /etc/hosts; echo \$?" )
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "20.3 Check if default route through node01 was added" {
  ip=$(dig +short node01 | head -n 1)
  status=$(ssh -o 'StrictHostKeyChecking=no' node02 "ip route | grep -q 'default via $ip'; echo \$?")
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" -eq 0 ]
}

#21
@test "21.1 Ensure that scripts copies files from '/opt/21/task/' '/opt/21/task-backup/'" {
  rm -rf /opt/21/task-backup/*
  /opt/21/result/script.sh
  diff -r /opt/21/task/ /opt/21/task-backup/
  status=$?
  echo '0.5' >> /var/work/tests/result/all
  if [[ "$status" -eq 0 ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" -eq 0 ]
}

@test "21.2 Check if empty_file is created at /opt/19/result/" {
  /opt/21/result/script.sh
  [[ -e /opt/21/result/empty_file ]]
  status=$?
  echo '0.5' >> /var/work/tests/result/all
  if [[ "$status" -eq 0 ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" -eq 0 ]
}

@test "21.3 Check if script is set to run every day at 2AM" {
  result=$(crontab -l | grep "/opt/21/result/script.sh")
  [[ "$result" == "0 2 * * * /opt/21/result/script.sh" ]]
  status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ "$status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" -eq 0 ]
}

# 22
@test "22.1 Check if user 'user22' has permissions to read 'aclfile'." {
  getfacl /opt/22/tasks/aclfile | grep "user:user0:r--"
  status=$?
  echo '0.5' >> /var/work/tests/result/all
  if [[ "$status" -eq 0 ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" -eq 0 ]
}

@test "22.2 Check if 'frozenfile' is no longer immutable" {
  lsattr /opt/22/tasks/frozenfile | grep -o 'i'
  status=$?
  echo '0.5' >> /var/work/tests/result/all
  if [[ "$status" -eq 0 ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" -eq 0 ]
}

# 23
# ???

# 24
@test "24.1 Two partitions have been created with size 2GB." {
  SIZE1=$(lsblk /dev/nvme2n1p1 --output SIZE -b)
  SIZE2=$(lsblk /dev/nvme2n1p2 --output SIZE -b)
  echo '1' >> /var/work/tests/result/all
  if [[ $SIZE1 == "1073741824" && $SIZE2 == "1073741824" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ $SIZE1 == "1073741824" && $SIZE2 == "1073741824" ]
}

@test "24.2 - 1 Partition has been mounted properly." {
  lsblk /dev/nvme2n1p1 --output MOUNTPOINT | grep "/drive"
  status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ $status -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ $status -eq 0 ]
}

@test "24.3 Check that partition has been formatted to xfs" {
  sudo file -sL /dev/nvme2n1p2 | grep XFS
  status=$?
  echo '1' >> /var/work/tests/result/all
  if [[ $status -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ $status -eq 0 ]
}

#25
@test "25.1 Check volume group has been created properly" {
  result=$(sudo pvs | grep volgroup1 | grep -cE '/dev/nvme1n1|/dev/nvme3n1')
  echo '2' >> /var/work/tests/result/all
  if [[ $result == "2" ]]; then
    echo '2' >> /var/work/tests/result/ok
  fi
  [ $result == "2" ]
}

@test "25.2 Check logic volume has been created properly wuth required size" {
  result=$(sudo lvs volgroup1 | grep -c 'logvolume1')
  size=$(sudo lvs --units G --noheadings -o lv_size volgroup1/logvolume1 | xargs)
  echo '2' >> /var/work/tests/result/all
  if [[ $result -eq 1 && $(echo $size | grep -E "1.*G") ]]; then
    echo '2' >> /var/work/tests/result/ok
  fi
  [ $result -eq 1 && $(echo $size | grep -E "1.*G") ]
}

