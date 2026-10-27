[Русский](environments_RU.md) · [English](environments.md) · [Español](environments_ES.md) · [Français](environments_FR.md) · [Deutsch](environments_DE.md) · [ქართული](environments_GE.md) · 繁體中文 · [日本語](environments_JP.md) · [首頁](../README_TW.MD)

<a id="environments"></a>

# 獨立環境與 CMDB

平台支援為同一位使用者建立多個獨立環境，也能為一組學生建立各自的環境。請傳入 `USER_ID` 與 `ENV_ID`：

```bash
USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock
USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock
```

[獨立環境的詳細說明 (EN)](multiple_users_envs.MD) · [範例影片](https://youtu.be/3H0RMLXGmgg)

<details>
<summary>CMDB：查看資源與鎖定資訊</summary>

| 指令 | 操作 |
|---|---|
| `make cmdb_get_env_all` | 列出 CMDB 中的資源與環境紀錄 |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data` | 顯示 `myuser` 在環境 `01` 的資源紀錄 |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock` | 顯示該使用者在環境 `01` 的鎖定紀錄 |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_lock` | 顯示該使用者所有環境的鎖定紀錄 |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_data` | 顯示該使用者所有環境的資源紀錄 |
| `CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item` | 取得指定紀錄的詳細資訊 |

</details>
