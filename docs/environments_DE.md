[Русский](environments_RU.md) · [English](environments.md) · [Español](environments_ES.md) · [Français](environments_FR.md) · Deutsch · [ქართული](environments_GE.md) · [繁體中文](environments_TW.md) · [日本語](environments_JP.md) · [Startseite](../README_DE.MD)

<a id="environments"></a>

# Unabhängige Umgebungen und CMDB

Die Plattform kann mehrere unabhängige Umgebungen für einen Benutzer oder getrennte Umgebungen für eine Lerngruppe erstellen. Übergebt dafür `USER_ID` und `ENV_ID`:

```bash
USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock
USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock
```

[Mehr über unabhängige Umgebungen (EN)](multiple_users_envs.MD) · [Videobeispiel](https://youtu.be/3H0RMLXGmgg)

<details>
<summary>CMDB: Ressourcen und Sperren prüfen</summary>

| Befehl | Aktion |
|---|---|
| `make cmdb_get_env_all` | Ressourcen- und Umgebungsdatensätze in der CMDB auflisten |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data` | Ressourcendatensätze von `myuser` in Umgebung `01` anzeigen |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock` | Sperrdatensätze des Benutzers in Umgebung `01` anzeigen |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_lock` | Sperrdatensätze des Benutzers in allen Umgebungen anzeigen |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_data` | Ressourcendatensätze des Benutzers in allen Umgebungen anzeigen |
| `CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item` | Details zum angegebenen Datensatz abrufen |

</details>
