# Allowed resources

## **Linux Foundation Certified System Administrator (LFCS) :**

- Man pages
- Documents installed by the distribution (i.e. /usr/share and its subdirectories)
- Packages that are part of the distribution (may also be installed by Candidate if not available by default)
- If you decide to install packages (not required to complete tasks) to your exam environment, you will want to be familiar with standard package managers (apt, dpkg, dnf, and yum).

## Questions

|        **1**        | **Create hard and soft links to the file `file1`**                                                                                                                                                                     |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                     |
|        Task         | - Create a hard link from file `file1` in your home directory to `/opt/file1`<br/>- Create a soft link from `file1` in your home directory to `/opt/softlinkfile`.<br/>  - Soft link should point to the absloute path |
| Acceptance criteria | <br/> - Hard and soft links are created?                                                                                                                                                                               |

---

|        **2**        | **Perform the following actions on the file `file2` in the home directory**                                                                                                                                                                                                                                  |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                           |
|        Task         | - Change owner of this file to uid `750` and gid `750` <br/> - Apply the following permissions to this file:<br/>&nbsp;&nbsp;- Group members should be able to write and read<br/>&nbsp;&nbsp;- Others only should be able to read.<br/> - Enable the SUID (set user id) special permission flag on `file2`. |
| Acceptance criteria | - File owners changes?<br/> - Set file permissions and SUID?                                                                                                                                                                                                                                                 |

---

|        **3**        | **Perform the following actions on the files `file31`,`file32`,`file33`**                                                                      |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                             |
|        Task         | - Create directory `/opt/newdir`<br/> - Move `file31` to this directory<br/> - Copy `file32` to `/opt/newdir` directory<br/> - Remove `file33` |
| Acceptance criteria | - Created directory?<br/> - Moved `file31`? <br/> - Copied `file32`?<br/> - Removed `file5` file?                                              |

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

|        **8**        | **Work with archivies**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|        Task         | Create the following archieve from the files in the `/opt/08files/` directory:<br/> - Create a simple *TAR* archieve from the files inside the folder. Store this archieve in `/opt/08results/mytar.tar`<br/> - Compress entire `/opt/08files/` directory into *GZIP* archieve. Save it at `/opt/08results/mytargz.tar.gz`<br/> - Compress entire `/opt/08files/` directory into *BZ* archieve. Save it at `/opt/08results/mybz.tar.bz2`<br/> - Compress entire `/opt/08files/` directory into *ZIP* archieve. Save it at `/opt/08results/myzip.zip` |
| Acceptance criteria | - `tar` archieve is created?<br/>- `gzip` archieve is created?<br/>- `bz` archieve is created?<br/> - `zip` archieve is created?                                                                                                                                                                                                                                                                                                                                                                                                                     |

---

|        **8**        | **Extracting content**                                                                                                                                                                                        |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | ?%                                                                                                                                                                                                            |
|        Task         | There are two archives in the `/opt/08task` folder:<br/> - Extract the content of `backup.tar.gz` to `/opt/08solution/tarbackup` <br/> - - Extract the content of `backup.zip` to `/opt/08solution/zipbackup` |
| Acceptance criteria | `backup.tar.gz` is extracted? `backup.zip` is extracted?                                                                                                                                                      |

---

|        **9**        | **Installing the service**                                                                                                                |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                        |
|        Task         | - Install the service nginx using package manager<br/> - Make this service automatically start up after rebooting <br/> - Run the service |
| Acceptance criteria | - nginx is installed?<br/> - nginx is enabled?<br/> - nginx is running?                                                                   |

---

|       **10**        | **Adding a new user**                                                                                                                                                                                                                                                             |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                |
|        Task         | Add a new admin user with the following requirenments:<br/> - with the name `cooluser` <br/> - with a password `superstrongpassword` <br/> - Set the default shell for this user as `/bin/zsh`<br/> - if that's an admin user,`cooluser` should be able to run commands with sudo |
| Acceptance criteria | - user `cooluser` with password is created ?<br/> - default shell for this user is `zsh`?<br/> - This user is able to perform sudo?                                                                                                                                               |

---

|       **11**        | **Locking and unlocking users**                                                                                                                                                                                                                                                                                                |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                                                                                                                                                                             |
|        Task         | There are two users in the system `spiderman` and `batman`. In this task is needed to perform some actions to lock/unlock password for these users:<br/> - `spiderman` cannot login to the system with his password, as password was locked, we need to unlock this user  <br/> - `batman` is unlocked, so we need to lock him |
| Acceptance criteria | - user `spiderman` is unlocked?<br/> - user `batman` is locked?                                                                                                                                                                                                                                                                |

---

|       **12**        | **Set a limit for the user users**                                                                                                                |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | ?%                                                                                                                                                |
|        Task         | There is a user `phoenix` in the system. Set a limit for this user so that she can open no more than `20` processes. This should be a hard limit. |
| Acceptance criteria | - hard limit is set for user `phoenix` processes  ?                                                                                               |

---

|       **13**        | **Set a skeleton for the user users**                                                                                                                             |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                                |
|        Task         | Edit the so-called skeleton directory so that whenever a new user is created on this system, a file called `IMPORTANT_NOTES` is copied to his/her home directory. |
| Acceptance criteria | - Make sure a file called `IMPORTANT_NOTES` is copied to the new user's home directory                                                                            |

---

|       **14**        | **Revoke sudo privilligies**                                                              |
| :-----------------: | :---------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                        |
|        Task         | There is a user `jack` in the system. This user should not have sudo permissions anymore. |
| Acceptance criteria | - Make sure that a user `jack` is not able to perform commands with sudo                  |

---

# Not ready
|       **15**        | **Redirect filtering output**                                                        |
| :-----------------: | :----------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                   |
|        Task         | Display all the lines in the `/etc/services` file that start out with the text core. |
| Acceptance criteria | -                                                                                    |

---