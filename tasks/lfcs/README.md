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
