[Русский](architecture_RU.md) · [English](architecture.md) · Español · [Français](architecture_FR.md) · [Deutsch](architecture_DE.md) · [ქართული](architecture_GE.md) · [繁體中文](architecture_TW.md) · [日本語](architecture_JP.md) · [Página principal](../README_ES.MD)

<a id="architecture"></a>

# Arquitectura de la plataforma

Los entornos prácticos se definen como código. Makefile selecciona el escenario, Terragrunt coordina los módulos de Terraform y Terraform crea los recursos necesarios de AWS y muestra los datos de conexión.

Los escenarios de Kubernetes autogestionado instalan los clústeres con **kubeadm**. Los laboratorios de **Amazon EKS** utilizan Kubernetes administrado en AWS. Según el escenario, la plataforma crea VPC, subredes, grupos de seguridad, instancias EC2 (incluidas Spot), S3 y otros recursos necesarios.

<details>
<summary>Estructura del repositorio</summary>

| Ruta | Propósito |
|---|---|
| [Makefile](../Makefile) | Comandos para iniciar, eliminar y consultar entornos y comprobar el proyecto |
| [tasks](../tasks) | Cursos, tareas, laboratorios y simulacros de examen |
| [tasks/cka](../tasks/cka) | Curso conjunto CKA + CKAD, [laboratorios](../tasks/cka/labs) y [simulacros CKA](../tasks/cka/mock) |
| [tasks/ckad](../tasks/ckad) | [Simulacros CKAD](../tasks/ckad/mock) |
| [tasks/cks](../tasks/cks) | Curso CKS, [laboratorios](../tasks/cks/labs) y [simulacros](../tasks/cks/mock) |
| [tasks/eks](../tasks/eks) | Curso y laboratorios de Amazon EKS |
| [tasks/ica](../tasks/ica) | Curso, laboratorios y simulacros de Istio / ICA |
| [tasks/kcsa](../tasks/kcsa) | Curso, preguntas y simulacros KCSA |
| [tasks/kcna](../tasks/kcna) | [Simulacros KCNA](../tasks/kcna/mock) |
| [tasks/lfcs](../tasks/lfcs) | Simulacros prácticos LFCS |
| [tasks/hr](../tasks/hr) | Escenarios HR |
| [tasks/aws_AI_practitioner](../tasks/aws_AI_practitioner) | [Simulacros AWS Certified AI Practitioner](../tasks/aws_AI_practitioner/mock) |
| [terraform](../terraform) | Definiciones de infraestructura |
| [terraform/environments](../terraform/environments) | Configuración de Terragrunt y directorios locales de los entornos |
| [terraform/modules](../terraform/modules) | Módulos Terraform reutilizables |
| [docs](../docs) | Catálogo de laboratorios, instrucciones y materiales adicionales |
| [CHANGELOG](../CHANGELOG/CHANGELOG.MD) | Historial de cambios del proyecto |

</details>

<details>
<summary>Kubernetes, runtimes, sistema operativo y CNI</summary>

Puedes utilizar el módulo [k8s_self_managment](../terraform/modules/k8s_self_managment) para tus propios escenarios. Define un clúster Kubernetes autogestionado; su versión, runtime, sistema operativo, AMI y red se establecen en cada escenario.

El proyecto utiliza o ha utilizado las siguientes opciones:

| Componente | Opciones |
|---|---|
| Kubernetes | Escenarios históricos con versiones 1.21-1.34; consulta `env.hcl` y la descripción del curso para los ejercicios nuevos |
| Container runtime | `containerd`, `containerd_gvizor`; los escenarios antiguos también utilizan `docker` y `cri-o` |
| Sistema operativo de los nodos autogestionados | Ubuntu 20.04 LTS y 22.04 LTS, según el escenario |
| CNI | Calico o Cilium, según el escenario |

La descripción anterior de la plataforma indicaba Docker con Kubernetes 1.21-1.23, CRI-O con 1.21-1.29 y containerd y `containerd_gvizor` con 1.21-1.33, además de Kubernetes 1.33 por defecto para CKA/CKS y Ubuntu 22.04 para CKS. Son datos de configuraciones antiguas, no una matriz de compatibilidad de los laboratorios nuevos. Elige los parámetros actuales a partir de los archivos del ejercicio; el [historial de versiones de Kubernetes](https://kubernetes.io/releases/) está disponible en su sitio web.

</details>
