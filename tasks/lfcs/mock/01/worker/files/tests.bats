#!/usr/bin/env bats

@test "0  Init  " {
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
