[Русский](environments_RU.md) · [English](environments.md) · [Español](environments_ES.md) · Français · [Deutsch](environments_DE.md) · [ქართული](environments_GE.md) · [繁體中文](environments_TW.md) · [日本語](environments_JP.md) · [Accueil](../README_FR.MD)

<a id="environments"></a>

# Environnements indépendants et CMDB

La plateforme permet de créer plusieurs environnements indépendants pour un utilisateur ou des environnements distincts pour un groupe d'étudiants. Transmettez `USER_ID` et `ENV_ID` :

```bash
USER_ID='myuser' ENV_ID='3' TASK=01 make run_ckad_mock
USER_ID='myuser' ENV_ID='3' TASK=01 make delete_ckad_mock
```

[En savoir plus sur les environnements indépendants (EN)](multiple_users_envs.MD) · [Exemple en vidéo](https://youtu.be/3H0RMLXGmgg)

<details>
<summary>CMDB : consulter les ressources et les verrous</summary>

| Commande | Action |
|---|---|
| `make cmdb_get_env_all` | Lister les enregistrements de ressources et d'environnements dans la CMDB |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data` | Afficher les ressources de `myuser` dans l'environnement `01` |
| `USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock` | Afficher les verrous de l'utilisateur dans l'environnement `01` |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_lock` | Afficher les verrous de l'utilisateur dans tous les environnements |
| `USER_ID='myuser' ENV_ID='' make cmdb_get_user_env_data` | Afficher les ressources de l'utilisateur dans tous les environnements |
| `CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item` | Obtenir les informations détaillées de l'enregistrement indiqué |

</details>
