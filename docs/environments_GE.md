[Русский](environments_RU.md) · [English](environments.md) · [Español](environments_ES.md) · [Français](environments_FR.md) · [Deutsch](environments_DE.md) · ქართული · [繁體中文](environments_TW.md) · [日本語](environments_JP.md) · [მთავარი გვერდი](../README_GE.MD)

<a id="environments"></a>

# დამოუკიდებელი გარემოები და CMDB

პლატფორმა ერთ მომხმარებელს რამდენიმე დამოუკიდებელი გარემოს, სტუდენტების ჯგუფს კი ცალკე გარემოების შექმნის საშუალებას აძლევს. ამისთვის მიუთითეთ `USER_ID` და `ENV_ID`:

```bash
USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock
USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock
```

[მეტი დამოუკიდებელი გარემოების შესახებ (EN)](multiple_users_envs.MD) · [ვიდეომაგალითი](https://youtu.be/3H0RMLXGmgg)

<details>
<summary>CMDB: რესურსებისა და ბლოკირებების ნახვა</summary>

| ბრძანება | მოქმედება |
|---|---|
| `make cmdb_get_env_all` | CMDB-ში რესურსებისა და გარემოების ჩანაწერების ჩამონათვალის მიღება |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data` | `myuser` მომხმარებლის რესურსების ჩანაწერების ნახვა `01` გარემოში |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock` | მომხმარებლის ბლოკირებების ჩანაწერების ნახვა `01` გარემოში |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_lock` | მომხმარებლის ბლოკირებების ნახვა ყველა გარემოში |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_data` | მომხმარებლის რესურსების ნახვა ყველა გარემოში |
| `CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item` | მითითებული ჩანაწერის დეტალური მონაცემების მიღება |

</details>
