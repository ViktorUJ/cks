[Русский](run_from_docker_RU.MD) · [English](run_from_docker.MD) · Español · [Français](run_from_docker_FR.MD) · [Deutsch](run_from_docker_DE.MD) · [ქართული](run_from_docker_GE.MD) · [繁體中文](run_from_docker_TW.MD) · [日本語](run_from_docker_JP.MD) · [Página principal](../README_ES.MD)

# Inicio rápido con Docker

La imagen de Docker preparada incluye las dependencias y utilidades necesarias para ejecutar laboratorios y simulacros de examen prácticos. El siguiente ejemplo inicia el simulacro CKA n.º 01.

[Videoinstrucciones](https://youtu.be/Xh6sWzafBmw)

## 1. Inicia el contenedor

En una máquina con Docker instalado, ejecuta:

```bash
sudo docker run -it viktoruj/runner
```

Ejecuta todos los comandos siguientes dentro del contenedor.

## 2. Clona el repositorio

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

## 3. Configura el almacenamiento del estado de Terraform

Abre [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl). Sustituye `backend_bucket` por el nombre de tu propio bucket S3 para el estado de Terraform. Si es necesario, cambia la región de la infraestructura `region` y la región de almacenamiento del estado `backend_region`:

```hcl
locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "your-platform-state-bucket"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

Comprueba también la región y los parámetros en el archivo `env.hcl` del escenario elegido.

## 4. Configura el acceso a AWS

Sustituye los valores de ejemplo por tus propias claves de acceso:

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

Si utilizas credenciales temporales, configura también `AWS_SESSION_TOKEN`.

## 5. Comprueba las cuotas de AWS

El entorno puede necesitar varias instancias EC2. En la consola de AWS, abre **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)** y comprueba las cuotas de la región y la familia de instancias que vas a utilizar:

- **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances** para On-Demand.
- **All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests** para Spot.

Estas cuotas se expresan en vCPU, no en número de instancias. Si la cuota disponible no es suficiente para el escenario, solicita un aumento. Para otras familias de instancias, comprueba las cuotas correspondientes.

## 6. Inicia el escenario

Para un único entorno:

```bash
TASK=01 make run_cka_mock
```

Para un usuario concreto o varios entornos independientes:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

Conéctate a la máquina de trabajo con los datos de la salida de Terraform y sigue las [instrucciones del examen](../tasks/cka/mock/01/README.MD).

Para otro ejercicio, elige el área y el número en el [catálogo de laboratorios](labs.MD) o en la [página principal](../README_ES.MD). Los comandos de inicio figuran en la [referencia de comandos](commands_ES.md).

## 7. Elimina el entorno al terminar

Los recursos se facturan a tu cuenta de AWS. Realiza la limpieza previa que indique el README del escenario y después elimina el entorno.

Para un único entorno:

```bash
TASK=01 make delete_cka_mock
```

Para el entorno de un usuario concreto:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

Utiliza los mismos valores de `TASK`, `USER_ID` y `ENV_ID` con los que iniciaste el escenario.

[Entornos independientes y CMDB](environments_ES.md) · [Escenarios de uso](usage_scenarios_ES.md)
