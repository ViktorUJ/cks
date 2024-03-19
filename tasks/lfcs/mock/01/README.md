# Allowed resources

## **Linux Foundation Certified System Administrator (LFCS) :**

- Man pages
- Documents installed by the distribution (i.e. /usr/share and its subdirectories)
- Packages that are part of the distribution (may also be installed by Candidate if not available by default)
- If you decide to install packages (not required to complete tasks) to your exam environment, you will want to be familiar with standard package managers (apt, dpkg, dnf, and yum).

## Questions

|        **1**        | **Create hard and soft links to the file `file1`**                                                                                                                                                                     |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                                                                                     |
|        Task         | - Create a hard link from file `file1` in your home directory to `/opt/file1`<br/>- Create a soft link from `file1` in your home directory to `/opt/softlinkfile`.<br/>  - Soft link should point to the absloute path |
| Acceptance criteria | <br/> - Hard and soft links are created?                                                                                                                                                                               |

---

|        **2**        | **Perform the following actions on the file `file2` in the home directory**                                                                                                                                                                                                                                  |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                                                                                                                                                                                           |
|        Task         | - Change owner of this file to uid `750` and gid `750` <br/> - Apply the following permissions to this file:<br/>&nbsp;&nbsp;- Group members should be able to write and read<br/>&nbsp;&nbsp;- Others only should be able to read.<br/> - Enable the SUID (set user id) special permission flag on `file2`. |
| Acceptance criteria | - File owners changes?<br/> - Set file permissions and SUID?                                                                                                                                                                                                                                                 |

---

|        **3**        | **Perform the following actions on the files `file31`,`file32`,`file33`**                                                                      |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                             |
|        Task         | - Create directory `/opt/newdir`<br/> - Move `file31` to this directory<br/> - Copy `file32` to `/opt/newdir` directory<br/> - Remove `file33` |
| Acceptance criteria | - Created directory?<br/> - Moved `file31`? <br/> - Copied `file32`?<br/> - Removed `file33` file?                                             |

---

|        **4**        | **Enable the sticky bit permissions on the directory**                                   |
| :-----------------: | :--------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                       |
|        Task         | - Enable the sticky bit special permission on the following directory: `/opt/stickydir/` |
| Acceptance criteria | - "sticky bit" is set on `/opt/stickydir` directory?                                     |

---

|        **5**        | **Filtering out specific files in the folder**                                                                                                                                                                                                                                                                                                                                |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                            |
|        Task         | In the `/opt/task5/` directory, you will find `500` files.<br/> - Filter out files that have the executable permissions for the user. Save output to the `/opt/05execuser`.<br/> - Find all files that have the SETUID permission enabled and copy them to the folder `/opt/05setuid`.<br/> - Find any file that is larger than 1KB and copy it to the `/opt/05kb` directory. |
| Acceptance criteria | - Filtered out files with executable permissions for user?<br/>- Moved all files with SETUID permissions?<br/> - Copied files that larder then 1KB?                                                                                                                                                                                                                           |

---

|        **6**        | **Find special file in the directory**                                                                                                                               |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                   |
|        Task         | - In the `/opt/task6` there is a tree based hierarchy with a bunch of files. Some of the them contains `findme` word. Copy these files to the `/opt/06result` folder |
| Acceptance criteria | - Files that contained special word were moved to the specified folder?                                                                                              |

---

|        **7**        | **Work with config file**                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
|        Task         | - Add a new line to the end of the file `/etc/config.conf` with the following content:<br/>&nbsp;&nbsp; `system71=enabled`<br/>- Write a simple bash script that filtering out all `enabled` parameters. Make this script executable and place it to the `/opt/07filter.sh` file<br/>- Enable all `disabled` parameters from changing it to `enable`. Be careful with apllying changes to the last subtask, you can make backup of the file before applying changes to it. |
| Acceptance criteria | - Added a new line at the end of the file?<br/> - Writed simple script to filter out enabled parameters<br/>- Updated all disabled parameters to be enabled?                                                                                                                                                                                                                                                                                                               |

---

|        **8**        | **Work with archives**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
|        Task         | Create the following archive from the files in the `/opt/08/files/` directory:<br/> - Create a simple *TAR* archive from the files inside the folder. Store this archive in `/opt/08results/mytar.tar`<br/> - Compress entire `/opt/08/files/` directory into *GZIP* archive. Save it at `/opt/08/results/mytargz.tar.gz`<br/> - Compress entire `/opt/08/files/` directory into *BZ* archive. Save it at `/opt/08/results/mybz.tar.bz2`<br/> - Compress entire `/opt/08/files/` directory into *ZIP* archive. Save it at `/opt/08/results/myzip.zip` |
| Acceptance criteria | - `tar` archive is created?<br/>- `gzip` archive is created?<br/>- `bz` archive is created?<br/> - `zip` archive is created?                                                                                                                                                                                                                                                                                                                                                                                                                          |

---

|        **9**        | **Extracting content**                                                                                                                                                                                         |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                             |
|        Task         | There are two archives in the `/opt/08/task` folder:<br/> - Extract the content of `backup.tar.gz` to `/opt/08/solution/tarbackup` <br/> - Extract the content of `backup.zip` to `/opt/08/solution/zipbackup` |
| Acceptance criteria | `backup.tar.gz` is extracted? `backup.zip` is extracted?                                                                                                                                                       |

---

|       **10**        | **Installing the service**                                                                                                                |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                        |
|        Task         | - Install the service nginx using package manager<br/> - Make this service automatically start up after rebooting <br/> - Run the service |
| Acceptance criteria | - nginx is installed?<br/> - nginx is enabled?<br/> - nginx is running?                                                                   |

---

|       **11**        | **Adding a new user**                                                                                                                                                                                                                                                             |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                |
|        Task         | Add a new admin user with the following requirenments:<br/> - with the name `cooluser` <br/> - with a password `superstrongpassword` <br/> - Set the default shell for this user as `/bin/zsh`<br/> - if that's an admin user,`cooluser` should be able to run commands with sudo |
| Acceptance criteria | - user `cooluser` with password is created ?<br/> - default shell for this user is `zsh`?<br/> - This user is able to perform sudo?                                                                                                                                               |

---

|       **12**        | **Locking and unlocking users**                                                                                                                                                                                                                                                                                               |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                                                                                                                                                                                            |
|        Task         | There are two users in the system `spiderman` and `batman`. In this task is needed to perform some actions to lock/unlock password for these users:<br/> - `spiderman` cannot login to the system with his password, as password was locked, we need to unlock this user <br/> - `batman` is unlocked, so we need to lock him |
| Acceptance criteria | - user `spiderman` is unlocked?<br/> - user `batman` is locked?                                                                                                                                                                                                                                                               |

---

|       **13**        | **Set a limit for the users**                                                                                                                    |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                               |
|        Task         | There is a user `phoenix` in the system. Set a limit for this user so that it can open no more than `20` processes. This should be a hard limit. |
| Acceptance criteria | - hard limit is set for user `phoenix` processes?                                                                                                |

---

|       **14**        | **Set a skeleton for the user users**                                                                                                                             |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                |
|        Task         | Edit the so-called skeleton directory so that whenever a new user is created on this system, a file called `IMPORTANT_NOTES` is copied to his/her home directory. |
| Acceptance criteria | - Make sure a file called `IMPORTANT_NOTES` is copied to the new user's home directory                                                                            |

---

|       **15**        | **Revoke sudo privilligies**                                                                 |
| :-----------------: | :------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                           |
|        Task         | There is a user `jackson` in the system. This user should not have sudo permissions anymore. |
| Acceptance criteria | - Make sure that a user `jackson` is not able to perform commands with sudo                  |

---

|       **16**        | **Redirect filtering output**                                                                                                     |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                |
|        Task         | Display all the lines in the `/etc/services` file that start out with the text `net`. Redirect the output to `/opt/15/result.txt` |
| Acceptance criteria | - Filtered output redirected to the file                                                                                          |

---

|       **17**        | **Check the difference between files and folders**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
|        Task         | - There are 2 files in the folder `/opt/task16/file1` and `/opt/task16/file2`. Files are almost the same, but they have one line that exist in one file and don't exist in another one. Find that line and save the difference to `/opt/task16/result/text_difference`.<br/> - `/opt/task16/dir1/` and `/opt/task16/dir2/` have almost similar files. Find out which files only exist in `/opt/task16/dir2/` but not in `/opt/task16/dir1/`. Find these files and save the output in the `/opt/task16/result/folder_difference` file. |
| Acceptance criteria | - The difference between 2 files was found?<br/>- The difference between 2 folders was found?                                                                                                                                                                                                                                                                                                                                                                                                                                         |

---

|       **18**        | **Perform docker operations**                                                                         |
| :-----------------: | :---------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                    |
|        Task         | - Run docker `apache` container with name `webserv`.<br/> - Removed all docker images except `apache` |
| Acceptance criteria | - Container is running? <br/>- Removed all images except `apache`                                     |

---

|       **19**        | **Analyze networking information**                                                                                                                                                                                                                                                                      |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                      |
|        Task         | - Check the ip address of the `eth0` network interface, save IP address to `/opt/18/result/ip` file. <br/> - Print out the route table and save the output to the `/opt/18/result/routes` file.<br/> - Check the PID of the service that uses 22 port and save the pid to the `/opt/18/result/pid` file |
| Acceptance criteria | - IP adrress was saved to the file? <br/>- Route table was written to the file?<br/>- PID of the service was saved to the file?                                                                                                                                                                         |

---

|       **20**        | **Networking settings**                                                                                                                                                                                                                                                                                                                                                                            |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                                                 |
|        Task         | SSH to the node02 and perform the following actions:<br/> - Add an extra DNS resolver (nameserver) on this system: `1.1.1.1`<br/> - Add a static dns resolution to make `database.local` host to be resolver to `10.10.20.5`. DNS resolver should repond with this IP on `database.local` hostname<br\> - Configure route table of this host to route all of the traffic through this node01 host. |
| Acceptance criteria | - DNS resolver was configured?<br/> - Static host entry for `database.local` was added?<br/> - Static route was configured properly?                                                                                                                                                                                                                                                               |

---

|       **21**        | **Create a bash script**                                                                                                                                                                                                                                                                                                                                          |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                |
|        Task         | This script should perform the following actions. You should put this script to `/opt/19/result/script.sh`: <br/>- Recursively copies the `/opt/19/task/` directory into the `/opt/19/task-backup/` directory.<br/>- Creates an empty file called `empty_file` at this location: `/opt/19/result/`<br/>- Make this script automatically running every day at 2AM. |
| Acceptance criteria | - Script was created, made executable and placed as it's required?<br/>- Test the script?<br/>- Make sure that this script was added to cron?                                                                                                                                                                                                                     |

---

|       **22**        | **Work with advanced file permissions and attributes**                                                                                                                                                                                                                                                                                                                                                                  |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                                                                      |
|        Task         | - In the folder `/opt/21/tasks` you will find a file `aclfile`. Currently this file can only be read by `user21`. Add a new ACL permission so that `user22` can also read this. `user22` should have only read permissions.<br/> - Next, in the `/opt/21/tasks` directory you will find a file named `frozenfile`. This currently has the immutable attribute set on it. Remove the immutable attribute from this file. |
| Acceptance criteria | - ACL permissions are set?<br/> - `frozenfile` file is no longer immutable?                                                                                                                                                                                                                                                                                                                                             |

---

|       **23**        | **Send signal to a process**                     |
| :-----------------: | :----------------------------------------------- |
|     Task weight     | ?%                                               |
|        Task         | - Send the SIGHUP signal to the `redis` process. |
| Acceptance criteria | - SIGHUP sent to the `redis` service?            |

---

|       **24**        | **Perform disk operations**                                                                                                                                                                                                                                                                                                                                                                                  |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                                                           |
|        Task         | You will find a disk `/dev/sda2` to be used in the system. We need to perform the following actions: <br/> - This disk has unpartitioned space. Create two partitions. Each should be exactly 1GB in size for each.<br/> - Mount this file to be mounted to the `/drive` folder. It should be mounted even after rebooting of the system<br/> - Format the second partitions to be used in `xfs` file system |
| Acceptance criteria | - Verify created partitions?<br/> - Verify that required partitions was mounted? <br/> - Partition is mounted automatically even after rebooting of the instance?                                                                                                                                                                                                                                            |

---

|       **25**        | **Perform LVM operations**                                                                                                                                                                                                                                                                                         |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                 |
|        Task         | - Add these two physical volumes to lvm: `/dev/sda3` and `/dev/sda4`<br/> - Create a volume group called `volgroup1` out of these two physical volumes, `/dev/sda3` and `/dev/sda4`<br/> - Create a logical volume of 1GB on the volume group `volgroup1`. The name of this logical volume should be `logvolume1`. |
| Acceptance criteria | - Verify the LVM <br/>- Volume Group (VG) named `volgroup1` has been created?<br/> - `logvolume1` LV has been created?                                                                                                                                                                                             |

---
