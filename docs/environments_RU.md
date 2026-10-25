Русский · [English](environments.md) · [Español](environments_ES.md) · [Français](environments_FR.md) · [Deutsch](environments_DE.md) · [ქართული](environments_GE.md) · [繁體中文](environments_TW.md) · [日本語](environments_JP.md) · [На главную](../README_RU.MD)

<a id="environments"></a>

# Независимые окружения и CMDB

Платформа позволяет создать несколько независимых окружений для одного пользователя или отдельные окружения для группы студентов. Для этого передавайте `USER_ID` и `ENV_ID`:

```bash
USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock
USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock
```

[Подробнее о независимых окружениях](multiple_users_envs.MD) · [Видео с примером](https://youtu.be/3H0RMLXGmgg)

<details>
<summary>CMDB: просмотр ресурсов и блокировок</summary>

| Команда | Действие |
|---|---|
| `make cmdb_get_env_all` | Получить список записей ресурсов и окружений в CMDB |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data` | Показать записи ресурсов пользователя `myuser` в окружении `01` |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock` | Показать записи блокировок пользователя в окружении `01` |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_lock` | Показать записи блокировок пользователя во всех окружениях |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_data` | Показать записи ресурсов пользователя во всех окружениях |
| `CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item` | Получить подробные данные указанной записи |

</details>
