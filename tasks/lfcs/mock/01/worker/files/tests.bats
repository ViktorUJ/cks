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

#4
@test "4 Check if a folder does have sticky bit enabled" {
  result=$(stat -c '%A' "/home/ubuntu/file2")
  echo '1' >> /var/work/tests/result/all
  if [ "$result" == "drwxrwxrwt" ]; then
    echo $result
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "drwxrwxrwt" ]
}

#5.1
@test "5.1 Check the filtering out files with executable permissions." {
  find "/opt/task5" -type f -perm -u=x > /var/work/tests/artifacts/task0501
  echo '1' >> /var/work/tests/result/all
  if diff -q <(cat /var/work/tests/artifacts/task0501 | sort) <(cat /opt/05execuser | sort) &>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff -q <(cat /var/work/tests/artifacts/task0501 | sort) <(cat /opt/05execuser | sort) &>/dev/null
}

#5.2
@test "5.2 Check the filtering out files with SETUID permissions." {
  rm -rf /var/work/tests/artifacts/task0502 && mkdir /var/work/tests/artifacts/task0502
  find "/opt/task5" -type f -perm -4000 -exec cp {} /var/work/tests/artifacts/task0502/ \;
  echo '1' >> /var/work/tests/result/all
  if diff -q <(ls -1 /var/work/tests/artifacts/task0502 | sort) <(ls -1 /opt/05setuid/ | sort) &>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff -q <(ls -1 /var/work/tests/artifacts/task0502 | sort) <(ls -1 /opt/05setuid/ | sort);
}

#5.3
@test "5.3 Check the filtering out files that larget than 1KB" {
  rm -rf /var/work/tests/artifacts/task0503 && mkdir /var/work/tests/artifacts/task0503
  find "/opt/task5" -type f -size +1k -exec cp {} "/var/work/tests/artifacts/task0503/" \;
  echo '1' >> /var/work/tests/result/all
  if diff -q <(ls -1 /var/work/tests/artifacts/task0503 | sort) <(ls -1 /opt/05kb/ | sort) &>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff -q <(ls -1 /var/work/tests/artifacts/task0503 | sort) <(ls -1 /opt/05kb/ | sort) &>/dev/null;
}

#6
@test "6 Check the files that contain findme word" {
  rm -rf /var/work/tests/artifacts/task06 && mkdir /var/work/tests/artifacts/task06
  find /opt/task6 -type f -exec grep -q 'findme' {} \; -exec cp {} /var/work/tests/artifacts/task06 \;
  echo '1' >> /var/work/tests/result/all
  if diff -q <(ls -1 /var/work/tests/artifacts/task06 | sort) <(ls -1 /opt/06result | sort) &>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
  fi
   diff -q <(ls -1 /var/work/tests/artifacts/task06 | sort) <(ls -1 /opt/06result | sort) &>/dev/null
}

#7
@test "7.1 Check the new line system71=enabled added to the end of file" {
  echo '0.5' >> /var/work/tests/result/all
  if tail -n 1 /etc/config.conf | grep "system71=enabled"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  tail -n 1 /etc/config.conf | grep "system71=enabled"
}

@test "7.2 Check if the script /opt/07filter.sh is working" {
  echo '0.5' >> /var/work/tests/result/all
  if diff -q <( /opt/07filter.sh | sort) <( cat /etc/config.conf | grep enabled | sort) &>/dev/null; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  diff -q <( /opt/07filter.sh | sort) <( cat /etc/config.conf | grep enabled | sort) &>/dev/null;
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
  mkdir -p /var/work/tests/artifacts/08-tar/ && tar -xf /opt/08/results/mytar.tar -C /var/work/tests/artifacts/08-tar/
  echo '1' >> /var/work/tests/result/all
  if [[ diff /var/work/tests/artifacts/08-tar/ /opt/08/files/ ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff /var/work/tests/artifacts/08-tar/ /opt/08/files/
}

# 8
@test "8.1 Check tar archive to be created" {
  mkdir -p /var/work/tests/artifacts/08-tar/ && tar -xf /opt/08/results/mytar.tar -C /var/work/tests/artifacts/08-tar/
  echo '1' >> /var/work/tests/result/all
  if [[ diff /var/work/tests/artifacts/08-tar/ /opt/08/files/ ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff /var/work/tests/artifacts/08-tar/ /opt/08/files/
}

@test "8.2 Check tar.gz archive to be created" {
  mkdir -p /var/work/tests/artifacts/08-targz/ && tar -xf /opt/08/results/mytargz.tar.gz -C /var/work/tests/artifacts/08-targz/
  echo '1' >> /var/work/tests/result/all
  if [[ diff /var/work/tests/artifacts/08-targz/ /opt/08/files/ ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff /var/work/tests/artifacts/08-targz/ /opt/08/files/
}

@test "8.3 Check tar.bz2 archive to be created" {
  mkdir -p /var/work/tests/artifacts/08-tarbz/ && tar -xf /opt/08/results/mybz.tar.bz2 -C /var/work/tests/artifacts/08-tarbz/
  echo '1' >> /var/work/tests/result/all
  if [[ diff /var/work/tests/artifacts/08-tarbz/ /opt/08/files/ ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff /var/work/tests/artifacts/08-tarbz/ /opt/08/files/
}

@test "8.4 Check zip archive to be created" {
  mkdir -p /var/work/tests/artifacts/08-zip/ && unzip /opt/08/results/myzip.zip -d /var/work/tests/artifacts/08-zip/
  echo '1' >> /var/work/tests/result/all
  if [[ diff /var/work/tests/artifacts/08-zip/ /opt/08/files/ ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff /var/work/tests/artifacts/08-zip/ /opt/08/files/
}

# 9
@test "9.1 Check extracted tar.gz archive" {
  mkdir -p /var/work/tests/artifacts/09/targz/ && tar -xf /opt/09/task/backup.tar.gz -C /var/work/tests/artifacts/09/targz/
  echo '1' >> /var/work/tests/result/all
  if [[ diff /var/work/tests/artifacts/09/targz/ /opt/08/solution/tarbackup ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff /var/work/tests/artifacts/09-tar/ /opt/09/solution/tarbackup
}

@test "9.2 Check extracted zip archive" {
  mkdir -p /var/work/tests/artifacts/09/zip/ && tar -xf /opt/09/task/backup.zip -C /var/work/tests/artifacts/09/zip/
  echo '1' >> /var/work/tests/result/all
  if [[ diff /var/work/tests/artifacts/09/zip/ /opt/09/solution/zipbackup ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  diff /var/work/tests/artifacts/09/zip/ /opt/09/solution/tarbackup
}

# 10
@test "10.1 Check if the nginx service was installed." {
  echo '0.5' >> /var/work/tests/result/all
  if [[ systemctl list-units | grep nginx ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  systemctl list-units | grep nginx
}

@test "10.2 Check if the nginx service was enabled." {
  echo '0.5' >> /var/work/tests/result/all
  if [[ systemctl is-enabled nginx | grep enabled ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  systemctl is-enabled nginx | grep enabled
}

# 11
@test "11.1 Check creatiom of a user with name.cooluser" {
  id cooluser
  status=$?
  echo '0.5' >> /var/work/tests/result/all
  if [ "$status" == "0" ]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "0" ]
}

@test "11.2 Check if a user has correct shell configured" {
  check_sh=$(cat /etc/passwd | grep cooluser | awk -F ':' '{print $7}')
  echo '0.5' >> /var/work/tests/result/all
  if [ "$status" == "/bin/zsh" ]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "/bin/zsh" ]
}

@test "11.3 Check if user cooluser has sudo permissions" {
  sudo -lU cooluser &>/dev/null
  check_sudo=$?
  echo '0.5' >> /var/work/tests/result/all
  if [ "$check_sudo" == "0" ]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$check_sudo" == "0" ]
}


# Check
#12
@test "12.1 Check a user spiderman for being unlocked." {
  status=$(sudo passwd -S spiderman | awk '{print $2}')
  echo '0.5' >> /var/work/tests/result/all
  if [ "$status" != "L" ]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" != "L" ]
}

@test "12.2 Check a batman spiderman for being locked." {
  status=$(sudo passwd -S batman | awk '{print $2}')
  echo '0.5' >> /var/work/tests/result/all
  if [ "$status" == "L" ]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$status" == "L" ]
}

#13
@test "13.1 Check if a user phoenix has hard limit of opening 20 processes." {
  exit_status=$(cat /etc/security/limits.conf | grep -E "phoenix.*hard.*nproc.*20")
  echo '0.5' >> /var/work/tests/result/all
  if [ "$exit_status" == "0" ]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$exit_status" == "0" ]
}
