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

