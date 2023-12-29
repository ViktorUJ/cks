# Why it needed ?

This is necessary when you need to create many identical independent environments. e.g. for a group of students.

Or you need to create several independent environments for one student with different tasks.

To create an independent environment you need to set additional variables USER_ID='myuser' ENV_ID='01' before running the make command.

[for example](https://youtu.be/3H0RMLXGmgg) :

- `USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock` - create environment **3** for user **myuser** with task set **01** ckad mock 
- `USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock` -  delete environment **3** for user **myuser** with job set **01** ckad mock 


- ``make cmdb_get_env_all`` - get a list of all resources in CMDB
- ``USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data`` - show all created resources of user **myuser** in environment **01**
- ``USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock`` - show all lock resources of user **myuser** in environment **01**
- ``USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock`` - show all lock resources of user **myuser** in environment **01**
- ``USER_ID='myuser' make cmdb_get_user_env_lock`` - show all lock resources of user **myuser** in **all** environment
- ``USER_ID='myuser' make cmdb_get_user_env_data`` - show all data resources of user **myuser** in **all** environment
- ``CMDB_ITEM='CMDB_data_myuser_01_k8s_cluster1' make cmdb_get_item`` - getting detailed information about **CMDB_data_myuser_01_k8s_cluster1** resource.
