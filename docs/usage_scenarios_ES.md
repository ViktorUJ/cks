[Русский](usage_scenarios_RU.md) · [English](usage_scenarios.md) · Español · [Français](usage_scenarios_FR.md) · [Deutsch](usage_scenarios_DE.md) · [ქართული](usage_scenarios_GE.md) · [繁體中文](usage_scenarios_TW.md) · [日本語](usage_scenarios_JP.md) · [Página principal](../README_ES.MD)

<a id="usage"></a>

# Escenarios de uso y vídeos

<details>
<summary>Laboratorios CKA + CKAD y CKS: del inicio a la validación</summary>

1. Elige un ejercicio del [catálogo de laboratorios](labs.MD) y lee su descripción: `tasks/cka/labs/<number>/README_ES.MD` o `tasks/cks/labs/<number>/README_ES.MD` para los ejercicios traducidos.
2. Comprueba `env.hcl`: región, tipos de instancia y parámetros del entorno. Si especificas `ami_id` manualmente, la imagen debe corresponder a la región y arquitectura de la instancia; para la selección automática, sigue la configuración del escenario.
3. Crea el entorno: `TASK=101 make run_cka_task` o `TASK=101 make run_cks_task`.
4. Busca el comando SSH en la salida de Terraform. Los laboratorios compuestos suelen empezar en la máquina de trabajo `worker`, aunque algunos escenarios empiezan en un nodo del plano de control. Utiliza `worker_pc_ip`, `master_external_ip` o el comando de conexión que proporcione tu escenario.
5. Conéctate como `ubuntu`. Para el acceso por clave, utiliza `ssh ubuntu@<IP> -i <key_path>`; si el entorno muestra una contraseña, conéctate con `ssh ubuntu@<IP>` e introdúcela cuando se solicite.
6. Si es necesario, comprueba que la inicialización haya terminado en la máquina correspondiente: `tail -f /var/log/cloud-init-output.log`.
7. Completa las tareas. En los laboratorios compuestos, ejecuta `check_result` en la máquina de trabajo y sigue el método de validación de la descripción.
8. Revisa la solución de referencia. Para el laboratorio 101: [CKA + CKAD](../tasks/cka/labs/101/worker/files/solutions/1_ES.MD) y [CKS](../tasks/cks/labs/101/worker/files/solutions/1_ES.MD). En otros ejercicios las soluciones pueden estar en otro lugar; utiliza el enlace del catálogo o la descripción.
9. Realiza la limpieza previa indicada en la sección de eliminación y elimina el entorno: `TASK=101 make delete_cka_task` o `TASK=101 make delete_cks_task`.

Para reiniciar tras vaciar el directorio local del entorno, utiliza `run_cka_task_clean` o `run_cks_task_clean`. Los recursos en la nube deben eliminarse con los comandos `delete_*`.

</details>

<details>
<summary>Simulacros prácticos CKA, CKAD, CKS, ICA y HR</summary>

Procedimiento general:

1. Elige el número de examen y abre su README en `tasks/<track>/mock/<number>/`.
2. Si es necesario, cambia los parámetros admitidos en `env.hcl`: sistema operativo (`ubuntu_version`), modalidad de compra EC2 (`spot` u `ondemand`) y tipos de instancia.
3. Inicia el entorno con `TASK=<number> make run_<track>_mock`. Utiliza `run_<track>_mock_clean` para iniciar tras vaciar el directorio local.
4. Busca `worker_pc_ip` o el comando SSH en la salida de Terraform y conéctate a la máquina de trabajo como `ubuntu` con la clave o contraseña del entorno.
5. Abre las tareas y trabaja desde la máquina de trabajo. Para acceder a un nodo, utiliza `ssh <node_name>` siguiendo la descripción del examen.
6. Consulta el tiempo restante con `time_left` y el resultado con `check_result` cuando el entorno admita estos comandos.
7. Después del intento, revisa las soluciones y pruebas enlazadas más abajo.
8. Elimina el entorno con `TASK=<number> make delete_<track>_mock`.

| Área | Tareas del examen 01 | Soluciones | Comprobaciones automáticas |
|---|---|---|---|
| CKA | [Descripción](../tasks/cka/mock/01) | [Soluciones](../tasks/cka/mock/01/worker/files/solutions) | [tests.bats](../tasks/cka/mock/01/worker/files/tests.bats) |
| CKAD | [Descripción](../tasks/ckad/mock/01) | [Soluciones](../tasks/ckad/mock/01/worker/files/solutions) | [tests.bats](../tasks/ckad/mock/01/worker/files/tests.bats) |
| CKS | [Descripción](../tasks/cks/mock/01) | [Soluciones](../tasks/cks/mock/01/worker/files/solutions) | [tests.bats](../tasks/cks/mock/01/worker/files/tests.bats) |
| ICA | [Descripción](../tasks/ica/mock/01) | [Soluciones](../tasks/ica/mock/01/worker/files/solutions) | [Directorio de pruebas](../tasks/ica/mock/01/worker/files/tests) |
| HR | [Descripción](../tasks/hr/mock/01) | [Soluciones](../tasks/hr/mock/01/worker/files/solutions) | [tests.bats](../tasks/hr/mock/01/worker/files/tests.bats) |

Videoinstrucciones y explicaciones:

- CKA: [iniciar el simulacro](https://www.youtube.com/watch?v=P-YYX4CTWIg), [soluciones del examen 01](https://youtu.be/IZsqAPpbBxM).
- CKS: [iniciar el simulacro](https://youtu.be/_GbsBOMaJ9Q), [explicación de las soluciones](https://youtu.be/I8CPwcGbrG8).
- CKAD: [iniciar el simulacro](https://youtu.be/7X4Y9QhbTsk), [explicación de las soluciones](https://youtu.be/yQK7Ca8d-yw).
- HR: [vídeo del escenario](https://youtu.be/4CTC1jl8lxE).

</details>

<details>
<summary>Amazon EKS: realizar un laboratorio</summary>

1. Elige un número del [catálogo EKS](labs.MD#eks-labs) y lee la descripción.
2. Comprueba `env.hcl` y ejecuta `TASK=101 make run_eks_task`, sustituyendo el número del laboratorio elegido.
3. Busca `worker_pc_ip` o el comando SSH en la salida de Terraform. Conéctate como `ubuntu` con clave o contraseña según la descripción.
4. Completa las tareas y valida el resultado. Los laboratorios compuestos ofrecen `check_result`.
5. Revisa la solución enlazada desde la descripción o el catálogo, por ejemplo la [solución del laboratorio 101](../tasks/eks/labs/101/worker/files/solutions/1_ES.MD).
6. Realiza la limpieza previa de la sección de eliminación y ejecuta `TASK=101 make delete_eks_task` con el número correcto.

</details>

Otros escenarios: [Laboratorios Istio / ICA](../tasks/ica/README_ES.MD), [Simulacro LFCS n.º 01](../tasks/lfcs/mock/01), [Materiales de evaluación KCSA](../tasks/kcsa/README_ES.md), [Simulacro KCNA n.º 01](../tasks/kcna/mock/01/README.MD), [Simulacro AWS Certified AI Practitioner n.º 01](../tasks/aws_AI_practitioner/mock/01/README.MD).
