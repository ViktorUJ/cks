[Русский](environments_RU.md) · [English](environments.md) · [Español](environments_ES.md) · [Français](environments_FR.md) · [Deutsch](environments_DE.md) · [ქართული](environments_GE.md) · [繁體中文](environments_TW.md) · 日本語 · [ホーム](../README_JP.MD)

<a id="environments"></a>

# 独立した環境と CMDB

プラットフォームでは、1人のユーザーに複数の独立した環境を用意したり、学習グループの各自に別の環境を作成したりできます。`USER_ID` と `ENV_ID` を指定してください。

```bash
USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock
USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock
```

[独立した環境の詳細 (EN)](multiple_users_envs.MD) · [操作例の動画](https://youtu.be/3H0RMLXGmgg)

<details>
<summary>CMDB：リソースとロックを確認</summary>

| コマンド | 操作 |
|---|---|
| `make cmdb_get_env_all` | CMDB のリソースと環境のレコードを一覧表示 |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data` | 環境 `01` における `myuser` のリソースレコードを表示 |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock` | 環境 `01` におけるユーザーのロックレコードを表示 |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_lock` | 全環境におけるユーザーのロックレコードを表示 |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_data` | 全環境におけるユーザーのリソースレコードを表示 |
| `CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item` | 指定したレコードの詳細情報を取得 |

</details>
