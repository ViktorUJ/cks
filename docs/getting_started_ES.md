[Русский](getting_started_RU.md) · [English](getting_started.md) · Español · [Français](getting_started_FR.md) · [Deutsch](getting_started_DE.md) · [ქართული](getting_started_GE.md) · [繁體中文](getting_started_TW.md) · [日本語](getting_started_JP.md) · [Página principal](../README_ES.MD)

<a id="quick-start"></a>

# Primeros pasos y requisitos

Puedes leer los cursos directamente en el repositorio. Para ejecutar entornos prácticos necesitas AWS y las herramientas de la plataforma. Los recursos se facturan a tu cuenta de AWS; elimina los entornos al terminar siguiendo las instrucciones del escenario.

## 1. Prepara las herramientas

Puedes utilizar la imagen de Docker preparada con las dependencias:

```bash
sudo docker run -it viktoruj/runner
```

[Instrucciones de inicio con Docker](run_from_docker_ES.MD) · [Videoinstrucciones](https://youtu.be/Xh6sWzafBmw)

[![Ejecutar la plataforma con Docker](images/run_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "Ejecutar la plataforma con Docker")

<details>
<summary>Requisitos de instalación local</summary>

- [GNU Make](https://www.gnu.org/software/make/) ≥ 4.2.1.
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) ≥ 1.6.6.
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) ≥ 0.54.8.
- [jq](https://jqlang.github.io/jq/download/) ≥ 1.6.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30.
- Un [perfil de AWS](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) u otro método de autenticación configurado.
- Un [usuario IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) con [clave de acceso](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html), o un [rol IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html), con permisos para crear y eliminar los recursos del escenario. La configuración original presupone permisos amplios sobre VPC, EC2, IAM y EKS; consulta las [políticas de acceso de AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html).

Estas son las versiones mínimas originales de la documentación de la plataforma. Consulta el escenario elegido y su configuración de Terraform para conocer los requisitos adicionales de herramientas y proveedores.

</details>

## 2. Obtén el repositorio y configura AWS

Ejecuta los siguientes comandos dentro del contenedor Docker o en una máquina con las herramientas instaladas:

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

Configura el acceso a AWS. Indica tu propio `backend_bucket` en [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl); cambia `region` y `backend_region` si es necesario. Comprueba la región y los parámetros del `env.hcl` del escenario. La [guía de Docker](run_from_docker_ES.MD) explica la configuración en detalle.

## 3. Elige e inicia un ejercicio

Ejemplo del primer laboratorio compuesto de CKA + CKAD:

```bash
TASK=101 make run_cka_task
```

Abre el [laboratorio 101](../tasks/cka/labs/101/README_ES.MD), conéctate con los datos de la salida de Terraform y completa las tareas.

## 4. Elimina el entorno

Al terminar, sigue las instrucciones de eliminación del ejercicio y ejecuta:

```bash
TASK=101 make delete_cka_task
```

Para otro ejercicio, sustituye el número y utiliza el comando del área correspondiente de la [referencia de comandos](commands_ES.md).
