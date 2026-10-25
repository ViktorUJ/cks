[Русский](environments_RU.md) · [English](environments.md) · Español · [Français](environments_FR.md) · [Deutsch](environments_DE.md) · [ქართული](environments_GE.md) · [繁體中文](environments_TW.md) · [日本語](environments_JP.md) · [Página principal](../README_ES.MD)

<a id="environments"></a>

# Entornos independientes y CMDB

La plataforma permite crear varios entornos independientes para un usuario o entornos separados para un grupo de estudiantes. Para ello, especifica `USER_ID` y `ENV_ID`:

```bash
USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock
USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock
```

[Más sobre los entornos independientes (EN)](multiple_users_envs.MD) · [Vídeo de ejemplo](https://youtu.be/3H0RMLXGmgg)

<details>
<summary>CMDB: consultar recursos y bloqueos</summary>

| Comando | Acción |
|---|---|
| `make cmdb_get_env_all` | Listar los registros de recursos y entornos en CMDB |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data` | Mostrar los registros de recursos de `myuser` en el entorno `01` |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock` | Mostrar los registros de bloqueo del usuario en el entorno `01` |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_lock` | Mostrar los registros de bloqueo del usuario en todos los entornos |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_data` | Mostrar los registros de recursos del usuario en todos los entornos |
| `CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item` | Obtener información detallada del registro indicado |

</details>
