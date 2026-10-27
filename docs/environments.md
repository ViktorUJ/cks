[Русский](environments_RU.md) · English · [Español](environments_ES.md) · [Français](environments_FR.md) · [Deutsch](environments_DE.md) · [ქართული](environments_GE.md) · [繁體中文](environments_TW.md) · [日本語](environments_JP.md) · [Home](../README.MD)

<a id="environments"></a>

# Independent environments and CMDB

The platform can create multiple independent environments for one user or separate environments for a group of students. Pass `USER_ID` and `ENV_ID` to do this:

```bash
USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock
USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock
```

[More about independent environments (EN)](multiple_users_envs.MD) · [Example video](https://youtu.be/3H0RMLXGmgg)

<details>
<summary>CMDB: inspect resources and locks</summary>

| Command | Action |
|---|---|
| `make cmdb_get_env_all` | List resource and environment records in CMDB |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data` | Show resource records for user `myuser` in environment `01` |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock` | Show lock records for the user in environment `01` |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_lock` | Show the user's lock records across all environments |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_data` | Show the user's resource records across all environments |
| `CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item` | Retrieve detailed information for the specified record |

</details>
