[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Laboratorio: Fundamentos de Karpenter

## Descripción

Este laboratorio le presentará **Karpenter**, una herramienta de escalado automático de nodos en un clúster de Amazon EKS. Karpenter crea y elimina dinámicamente instancias EC2 según las necesidades de sus aplicaciones, optimizando los costes y el rendimiento.

**Lo que aprenderá:**
- Cómo configurar un NodePool y EC2NodeClass básicos
- Cómo Karpenter escala automáticamente los nodos cuando cambia la carga
- Cómo gestionar los recursos mediante límites
- Cómo funcionan la consolidación y la optimización de tamaños de nodos
- Cómo actualizar nodos cuando cambia la configuración (drift)
- Cómo usar varios NodePool para distintos tipos de carga

## Contenido
- [Preparación del entorno](#preparación-del-entorno)
  - [Inicio del laboratorio](#inicio-del-laboratorio)
  - [Recursos creados](#recursos-creados)
  - [Requisitos previos](#requisitos-previos)
- [Configuración básica de NodePool](#configuración-básica-de-nodepool)
  - [Comprobación del funcionamiento de Karpenter](#comprobación-del-funcionamiento-de-karpenter)
  - [Creación de una aplicación de prueba](#creación-de-una-aplicación-de-prueba)
  - [Creación de NodePool y EC2NodeClass](#creación-de-nodepool-y-ec2nodeclass)
  - [Comprobación de la creación automática de nodos](#comprobación-de-la-creación-automática-de-nodos)
- [Escalado de aplicaciones](#escalado-de-aplicaciones)
  - [Escalado horizontal](#escalado-horizontal)
  - [Adición automática de nodos](#adición-automática-de-nodos)
- [Limitación de recursos](#limitación-de-recursos)
  - [Configuración de límites de CPU](#configuración-de-límites-de-cpu)
  - [Diagnóstico de problemas con los límites](#diagnóstico-de-problemas-con-los-límites)
- [Gestión del ciclo de vida de los nodos (Disruption)](#gestión-del-ciclo-de-vida-de-los-nodos-disruption)
- [Optimización de tamaños de nodos (RightSizing)](#optimización-de-tamaños-de-nodos-rightsizing)
  - [Selección automática del tamaño óptimo](#selección-automática-del-tamaño-óptimo)
  - [Sustitución de nodos al cambiar los requisitos](#sustitución-de-nodos-al-cambiar-los-requisitos)
- [Actualización de la configuración de nodos (Drift)](#actualización-de-la-configuración-de-nodos-drift)
  - [Actualización de imágenes AMI](#actualización-de-imágenes-ami)
  - [Migración automática a versiones nuevas](#migración-automática-a-versiones-nuevas)
- [Trabajo con varios NodePool](#trabajo-con-varios-nodepool)
  - [Aislamiento de carga mediante Taints y Tolerations](#aislamiento-de-carga-mediante-taints-y-tolerations)
  - [Nodos especializados para Job](#nodos-especializados-para-job)
- [Limpieza de recursos](#limpieza-de-recursos)


## Preparación del entorno

### Inicio del laboratorio
[inicio mediante docker ](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)
Para iniciar el laboratorio, ejecute el siguiente comando:

```bash
TASK=02 make run_eks_task
```

**Qué sucede al ejecutar el comando:**
- Terraform/Terragrunt desplegará automáticamente toda la infraestructura necesaria en AWS
- El proceso tardará aproximadamente 15-20 minutos
- En la salida del comando verá información importante (conexión SSH, nombres de recursos)

### Recursos creados

Al ejecutar el comando se desplegará la siguiente infraestructura de AWS:

#### Infraestructura de red (VPC)
- **VPC** con el bloque CIDR `10.10.0.0/16` en la región `eu-central-1`
- **Subredes públicas** (para recursos con acceso a Internet):
  - `eks-AZ-1` (10.10.1.0/24) en la zona de disponibilidad `eu-central-1a`
  - `eks-AZ-2` (10.10.2.0/24) en la zona de disponibilidad `eu-central-1b`
- **Subredes privadas** (para recursos internos):
  - `private-subnet-1` (10.10.15.0/24) para nodos EKS en `eu-central-1a`
  - `private-subnet-2` (10.10.16.0/24) para nodos EKS en `eu-central-1b`
  - `rds-subnet-1` (10.10.21.0/24) para RDS en `eu-central-1a`
  - `rds-subnet-2` (10.10.22.0/24) para RDS en `eu-central-1b`
- **NAT Gateway** para el tráfico saliente a Internet desde las subredes privadas

#### Clúster EKS
- **EKS Control Plane** versión `1.34` (plano de control de Kubernetes)
- **Fargate profile** para pods de sistema (kube-system, karpenter)
- **Karpenter** versión `1.8.1` (controlador de escalado automático)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Configuración de Karpenter
- Controlador de Karpenter con recursos dedicados:
  - CPU: 0.4 núcleos (requests y limits)
  - Memory: 0.5Gi (requests y limits)
- Detección automática de subredes mediante etiquetas `karpenter.sh/discovery`

#### Componentes adicionales
- **Security Groups** con las reglas de seguridad correspondientes
- **Roles y políticas IAM** para Karpenter y EKS
- **OIDC provider** para la integración con servicios de AWS

#### Archivo de configuración principal

Todos los parámetros de la infraestructura se definen en el archivo `tasks/eks/labs/02/env.hcl`. Para cambiar la configuración, edite los parámetros correspondientes en este archivo.

### Requisitos previos

Asegúrese de haber configurado:
- **AWS CLI** con los permisos de acceso correspondientes
- Límites aumentados para la cantidad de nodos en la región `eu-central-1` (si es necesario)

## Configuración básica de NodePool

### Comprobación del funcionamiento de Karpenter

**Paso 1: Conexión al nodo de trabajo**

Busque en la salida del comando la línea de conexión SSH y conéctese al nodo de trabajo:

```bash
# Ejemplo de salida:
# 18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "

ssh ubuntu@18.199.222.47  # Use su dirección IP y contraseña
```

**Paso 2: Comprobación del estado del controlador Karpenter**

Asegúrese de que el controlador Karpenter está iniciado y funcionando:

```bash
kubectl get po -n karpenter
```

**Resultado esperado:**
```
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m
```

**Paso 3: Comprobación de los NodePool y EC2NodeClass existentes**

Compruebe que todavía no hay NodePool creados:

```bash
kubectl get nodepools
```

**Resultado:**
```
No resources found
```

Compruebe EC2NodeClass:

```bash
kubectl get ec2nodeclasses
```

**Resultado:**
```
No resources found
```

**Qué significa esto:** NodePool y EC2NodeClass son los recursos principales de Karpenter. NodePool define qué nodos crear, y EC2NodeClass cómo configurarlos (AMI, subredes, security groups, etc.).

### Creación de una aplicación de prueba

Despleguemos una aplicación de prueba sencilla:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Resultado:**
```
namespace/team-19 created
deployment.apps/team19 created
service/team19 created
```

**Paso 4: Comprobación del estado de los pods**

Compruebe el estado de los pods creados:

```bash
kubectl get po -n team-19
```

**Resultado:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```

**Tenga en cuenta:** El pod está en estado `Pending` (en espera). Esto es normal en esta etapa.

**Paso 5: Diagnóstico del problema**

Veamos información detallada sobre el pod:

```bash
kubectl describe po -n team-19
```

**Parte importante de la salida:**
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**Explicación del problema:**
- El pod no se puede programar en ninguno de los nodos
- Los 3 nodos existentes son nodos Fargate para pods de sistema (kube-system, karpenter)
- El Fargate profile está configurado solo para determinados namespace, y `team-19` no está incluido
- Necesitamos crear un NodePool para que Karpenter pueda crear nodos EC2 adecuados

### Creación de NodePool y EC2NodeClass

**Paso 6: Creación de NodePool**

NodePool define los parámetros de los nodos que creará Karpenter:

```bash
cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"  # Etiqueta para identificar los nodos
    spec:
      requirements:
        # Arquitecturas de procesador admitidas
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        # Sistema operativo
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        # Tipo de instancias: spot (más barato) u on-demand (más estable)
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # Categorías de instancias (t - burstable, m - uso general, r - optimizado para memoria)
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        # Generación de instancias (mayor que 2 = más nuevas)
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        # Tamaños de instancias
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      # Referencia a EC2NodeClass con la configuración de AWS
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      # Vida útil del nodo (30 días)
      expireAfter: 720h # 30 * 24h = 720h
  # Límites de recursos para todo el NodePool
  limits:
    cpu: 4  # Máximo de 4 CPU para todos los nodos de este pool
  # Configuración de consolidación (optimización)
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # Eliminar nodos vacíos o infrautilizados
    consolidateAfter: 30s  # 30 segundos después de que el nodo quede vacío
EoF

kubectl apply -f default-nodepool.yaml
```

**Paso 7: Obtención de parámetros de la salida de Terraform**

Busque los siguientes valores en la salida del comando `make run_eks_task`:

```bash
# Ejemplo de salida:
# 19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"
# 20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Paso 8: Creación de EC2NodeClass**

EC2NodeClass define la configuración específica de AWS para los nodos:

```bash
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # Rol IAM para los nodos (sustituya por el suyo de la salida de Terraform)
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"
  # Selección de imagen AMI
  amiSelectorTerms:
    - alias: "al2023@latest"  # Amazon Linux 2023, versión más reciente
  # Selección de subredes por etiquetas
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Sustituya por el nombre de su clúster
  # Selección de security groups por etiquetas
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Sustituya por el nombre de su clúster
  # Etiquetas para las instancias EC2 creadas
  tags:
      Name: "eks2-viktor-01-default"  # Sustituya por el nombre de su clúster
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01  # Sustituya por el nombre de su clúster
  # Configuración de discos
  blockDeviceMappings:
    - deviceName: /dev/xvda    # Disco raíz
      ebs:
        volumeType: gp3        # Tipo de disco (gp3 - moderno, de alto rendimiento)
        volumeSize: 25Gi       # Tamaño del disco
        iops: 3000             # IOPS para gp3
        throughput: 125        # Rendimiento MiB/s
        encrypted: true        # Cifrado de disco
        deleteOnTermination: true  # Eliminar el disco al eliminar la instancia
EoF

kubectl create -f default-nodeclass.yaml
```

### Comprobación de la creación automática de nodos

**Paso 9: Comprobación del estado de los recursos**

Compruebe que EC2NodeClass está creado y listo:

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Resultado esperado:**
```
NAME      READY   AGE
default   True    2m17s
```

Compruebe NodePool:

```bash
kubectl get nodepools.karpenter.sh
```

**Resultado esperado:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m
```

**Si el estado no es READY:**

Ejecute el diagnóstico de EC2NodeClass:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws default
```

**Ejemplo de salida correcta:**
```
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, Status: Unknown -> True
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReservationsReady, Status: Unknown -> True
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady, Status: Unknown -> True
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroupsReady, Status: Unknown -> True
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfileReady, Status: Unknown -> True
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSucceeded, Status: Unknown -> True
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status: Unknown -> True
```

Compruebe NodePool:

```bash
kubectl describe nodepools.karpenter.sh default
```

**Si hay errores, compruebe los registros del controlador:**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Ejemplo de registros correctos:**
```json
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
```

**Paso 10: Comprobación de NodeClaim**

NodeClaim es una solicitud para crear un nodo. Karpenter crea un NodeClaim, que después se convierte en una instancia EC2 real:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s
```

**Qué vemos:**
- Se creó un NodeClaim llamado `default-c549s`
- Se seleccionó una instancia de tipo `t3a.small` (2 vCPU, 2GB RAM)
- Se utiliza una instancia spot (más barata)
- El nodo se encuentra en la zona `eu-central-1a`

**Paso 11: Comprobación del pod de aplicación**

Ahora el pod debería iniciarse correctamente:

```bash
kubectl get po -n team-19
```

**Resultado:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m
```

**¡El estado cambió a `Running`!**

**Paso 12: Comprobación de los nodos del clúster**

Veamos todos los nodos del clúster:

```bash
kubectl get no
```

**Resultado:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6
```

**Tenga en cuenta:**
- Los primeros 3 nodos son Fargate (para pods de sistema)
- El último nodo es una instancia EC2 creada por Karpenter

### Comprobación de la eliminación automática de nodos

**Paso 13: Eliminación de la aplicación**

Eliminemos nuestra aplicación:

```bash
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Resultado:**
```
namespace "team-19" deleted
deployment.apps "team19" deleted
service "team19" deleted
```

**Paso 14: Comprobación de la eliminación de pods**

```bash
kubectl get po -n team-19
```

**Resultado:**
```
No resources found in team-19 namespace.
```

**Paso 15: Espera de la eliminación de NodeClaim**

Espere aproximadamente 30 segundos (el valor de `consolidateAfter` en NodePool) y compruebe:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
No resources found
```

**¡Karpenter eliminó automáticamente el NodeClaim, ya que el nodo quedó vacío!**

**Paso 16: Comprobación de nodos**

```bash
kubectl get no
```

**Resultado:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
```

**¡El nodo EC2 se eliminó! Solo quedan nodos Fargate.**

**Conclusión:** Karpenter gestiona automáticamente el ciclo de vida de los nodos: los crea cuando son necesarios y los elimina cuando ya no se necesitan, optimizando los costes.


## Escalado de aplicaciones

En esta sección aprenderemos cómo Karpenter añade nodos automáticamente cuando aumenta la carga.

### Escalado horizontal

**Paso 1: Despliegue de la aplicación de prueba**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Paso 2: Comprobación de los recursos creados**

Compruebe NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s
```

Compruebe los nodos:

```bash
kubectl get no
```

**Resultado:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6
```

Compruebe los pods:

```bash
kubectl get po -n team-19
```

**Resultado:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11m
```

### Adición automática de nodos

**Paso 3: Escalado a 6 réplicas**

Aumentemos el número de réplicas de la aplicación:

```bash
kubectl scale deployment -n team-19 team19 --replicas 6
```

**Resultado:**
```
deployment.apps/team19 scaled
```

**Paso 4: Comprobación del estado de los pods**

```bash
kubectl get po -n team-19
```

**Resultado:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s
```

**¡Los 6 pods se iniciaron correctamente!**

**Paso 5: Comprobación de NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Tenga en cuenta:** Karpenter añadió automáticamente un segundo nodo (`default-gm8sj`), ya que un nodo no era suficiente para alojar los 6 pods.

**Paso 6: Escalado a 16 réplicas**

Aumentemos aún más la carga:

```bash
kubectl scale deployment -n team-19 team19 --replicas 16
```

**Paso 7: Comprobación del estado de los pods**

```bash
kubectl get po -n team-19
```

**Resultado:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          10m
team19-5d69f69559-4m772   0/1     Pending   0          2m37s
team19-5d69f69559-5ml7m   1/1     Running   0          2m37s
team19-5d69f69559-6dk8l   1/1     Running   0          2m37s
team19-5d69f69559-9qs2b   1/1     Running   0          2m37s
team19-5d69f69559-bzq77   1/1     Running   0          24m
team19-5d69f69559-fmcjq   1/1     Running   0          2m37s
team19-5d69f69559-gpzgc   1/1     Running   0          10m
team19-5d69f69559-kxw6k   1/1     Running   0          10m
team19-5d69f69559-ndg8q   1/1     Running   0          2m37s
team19-5d69f69559-pc2dv   1/1     Running   0          10m
team19-5d69f69559-q6brn   1/1     Running   0          10m
team19-5d69f69559-qgrqt   1/1     Running   0          2m37s
team19-5d69f69559-rss5s   1/1     Running   0          2m37s
team19-5d69f69559-x6qp8   1/1     Running   0          2m37s
team19-5d69f69559-z2wbm   0/1     Pending   0          2m37s
```

**Problema:** Algunos pods están en estado `Pending`. ¿Por qué? Vayamos a la siguiente sección para averiguarlo.

## Limitación de recursos

En esta sección veremos por qué algunos pods permanecieron en estado `Pending` y aprenderemos a gestionar los límites de recursos en NodePool.

### Configuración de límites de CPU

**Paso 1: Comprobación de los límites actuales de NodePool**

```bash
kubectl get nodepools.karpenter.sh default -o jsonpath='{.spec.limits}' | jq
```

**Resultado:**
```json
{
  "cpu": 4
}
```

**Qué significa esto:** En NodePool se estableció un límite de 4 CPU. Esto significa que el número total de CPU de todos los nodos de este pool no puede superar 4 núcleos.

**Paso 2: Comprobación de los NodeClaim existentes**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Análisis:**
- Tenemos 2 nodos de tipo `t4g.small`
- Cada `t4g.small` tiene 2 vCPU
- Total: 2 nodos × 2 vCPU = 4 vCPU
- **¡Hemos alcanzado el límite!** Karpenter no puede crear más nodos.

### Diagnóstico de problemas con los límites

**Paso 3: Comprobación de los registros de Karpenter**

Veamos qué indican los registros del controlador:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq | grep ERROR -A 20
```

**Resultado:**
```json
{
  "level": "ERROR",
  "time": "2026-01-13T17:41:15.044Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "1ad0d78",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "0e86c755-4ab9-4d86-abb5-7e15e91241fc",
  "Pod": {
    "name": "team19-5d69f69559-4m772",
    "namespace": "team-19"
  },
  "NodePool": {
    "name": "default"
  },
  "error": "all available instance types exceed limits for nodepool (NodePool=default)"
}
```

**Mensaje clave:** `"all available instance types exceed limits for nodepool"`

Esto confirma que Karpenter no puede crear nodos nuevos debido al límite de CPU.

**Paso 4: Aumento del límite de CPU**

Aumentemos el límite de CPU a 6 núcleos:

```bash
kubectl edit nodepools.karpenter.sh default
```

Busque la sección `limits` y cambie el valor:

```yaml
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # Cámbielo a 6
```

Guarde los cambios (`:wq` en vim o Ctrl+O, Enter, Ctrl+X en nano).

**Paso 5: Comprobación de la creación de un nuevo nodo**

Espere unos segundos y compruebe NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m
```

**¡Excelente!** Karpenter creó un tercer nodo (`default-gpgn9`).

**Paso 6: Comprobación de los pods de la aplicación**

```bash
kubectl get po -n team-19
```

**Resultado:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          29m
team19-5d69f69559-4m772   1/1     Running   0          22m
team19-5d69f69559-5ml7m   1/1     Running   0          22m
team19-5d69f69559-6dk8l   1/1     Running   0          22m
team19-5d69f69559-9qs2b   1/1     Running   0          22m
team19-5d69f69559-bzq77   1/1     Running   0          44m
team19-5d69f69559-fmcjq   1/1     Running   0          22m
team19-5d69f69559-gpzgc   1/1     Running   0          29m
team19-5d69f69559-kxw6k   1/1     Running   0          29m
team19-5d69f69559-ndg8q   1/1     Running   0          22m
team19-5d69f69559-pc2dv   1/1     Running   0          29m
team19-5d69f69559-q6brn   1/1     Running   0          29m
team19-5d69f69559-qgrqt   1/1     Running   0          22m
team19-5d69f69559-rss5s   1/1     Running   0          22m
team19-5d69f69559-x6qp8   1/1     Running   0          22m
team19-5d69f69559-z2wbm   1/1     Running   0          22m
```

**¡Los 16 pods están ahora en estado `Running`!**

### Comprobación de la consolidación automática

**Paso 7: Reducción del número de réplicas**

Reduzcamos el número de réplicas a 3:

```bash
kubectl scale deployment -n team-19 team19 --replicas 3
```

**Paso 8: Monitorización de los registros de Karpenter**

Siga los registros en tiempo real:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**Verá mensajes sobre la consolidación:**

```json
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 2,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-30.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-gpgn9"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ]
}
```

**Qué sucede:**
- Karpenter detectó un nodo infrautilizado (`underutilized`)
- Tomó la decisión de eliminar el nodo (`decision: delete`)
- Primero marca el nodo con el taint `karpenter.sh/disrupted:NoSchedule`
- Mueve los pods a otros nodos
- Elimina el nodo

**Paso 9: Comprobación de los nodos restantes**

Espere aproximadamente un minuto y compruebe:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m
```

**¡Solo queda un nodo!** Karpenter eliminó los nodos sobrantes, optimizando los costes.

### Información adicional sobre los límites

Los límites se pueden establecer para distintos tipos de recursos:
- **cpu** — cantidad de núcleos de procesador
- **memory** — volumen de memoria RAM
- **gpu** — cantidad de GPU (para cargas ML/AI)
- **nodes** — cantidad máxima de nodos

**Ejemplo de configuración con varios límites:**

```yaml
limits:
  cpu: 100
  memory: 1000Gi
  nodes: 10
```

Para más información sobre límites, consulte la [documentación oficial de Karpenter](https://karpenter.sh/docs/concepts/nodepools/#speclimits).


## Gestión del ciclo de vida de los nodos (Disruption)

Karpenter admite la gestión automática del ciclo de vida de los nodos mediante el parámetro `consolidateAfter` en la especificación NodePool.

**Conceptos clave:**

- **consolidateAfter** — tiempo de espera antes de eliminar un nodo después de que quede vacío o infrautilizado
- **consolidationPolicy** — política de consolidación:
  - `WhenEmpty` — eliminar solo nodos completamente vacíos
  - `WhenEmptyOrUnderutilized` — eliminar nodos vacíos e infrautilizados (recomendado)

**Ejemplo de configuración:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s  # Eliminar 30 segundos después de liberarse
```

**Cómo funciona:**

1. Karpenter monitoriza constantemente el uso de recursos en los nodos
2. Cuando un nodo queda vacío o infrautilizado, Karpenter inicia un temporizador
3. Si después del tiempo especificado (`consolidateAfter`) el nodo sigue sin ser necesario, Karpenter:
   - Marca el nodo con el taint `karpenter.sh/disrupted:NoSchedule`
   - Mueve los pods a otros nodos de forma ordenada
   - Elimina el nodo

**Parámetros adicionales:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
  budgets:
    - nodes: "10%"  # No eliminar más del 10% de los nodos a la vez
```

Para más información sobre disruption, consulte la [documentación oficial](https://karpenter.sh/docs/concepts/disruption/).

---

## Optimización de tamaños de nodos (RightSizing)

Karpenter selecciona automáticamente el tamaño óptimo de los nodos según los requisitos de los pods. Esto se denomina "right-sizing": elegir el tipo de instancia más adecuado y económico.

### Selección automática del tamaño óptimo

**Paso 1: Establecimiento del límite de CPU**

Aumentemos el límite de NodePool a 10 núcleos:

```bash
kubectl edit nodepools.karpenter.sh default
```

Cambie:

```yaml
spec:
  limits:
    cpu: 6     # Cámbielo a 10
```

**Paso 2: Despliegue de una aplicación con requisitos elevados**

Despleguemos una aplicación que solicita 3 CPU:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Paso 3: Comprobación del NodeClaim creado**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-6ltdb   t3.xlarge   spot       eu-central-1a   ip-10-10-15-179.eu-central-1.compute.internal   True    117s
```

**Tenga en cuenta:** Karpenter seleccionó una instancia `t3.xlarge` con 4 vCPU, ya que el pod solicita 3 CPU.

**Paso 4: Comprobación de los detalles del nodo**

```bash
kubectl get no ip-10-10-15-179.eu-central-1.compute.internal -o yaml
```

**Etiquetas importantes:**

```yaml
labels:
  karpenter.k8s.aws/instance-cpu: "4"
  karpenter.k8s.aws/instance-type: t3.xlarge
  karpenter.k8s.aws/instance-category: t
  karpenter.sh/capacity-type: spot
```

### Sustitución de nodos al cambiar los requisitos

**Paso 5: Reducción de los requisitos del pod**

Cambie los requisitos de CPU en el deployment:

```bash
kubectl edit deployments.apps -n team-19 team19
```

Busque la sección `resources` y cambie:

```yaml
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: app
    resources:
      requests:
        cpu: "3"      # Cámbielo a "50m" (50 millicores)
        memory: 500Mi
```

Guarde los cambios.

**Paso 6: Monitorización de los registros de Karpenter**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**Verá:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.171Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "replace",
  "disrupted-node-count": 1,
  "replacement-node-count": 1,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-15-179.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-6ltdb"
      },
      "capacity-type": "spot",
      "instance-type": "t3.xlarge"
    }
  ],
  "replacement-nodes": [
    {
      "capacity-type": "spot",
      "instance-types": "t4g.small, t3.small, t3a.small, m8gd.medium, r7gd.medium and 10 other(s)"
    }
  ]
}
```

**Qué sucede:**
- Karpenter detectó que el nodo está infrautilizado (`underutilized`)
- Tomó la decisión de sustituir el nodo (`decision: replace`)
- Crea un nodo nuevo y más económico

**Creación de un nuevo NodeClaim:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.219Z",
  "logger": "controller",
  "message": "created nodeclaim",
  "controller": "disruption",
  "NodeClaim": {
    "name": "default-48ck8"
  },
  "requests": {
    "cpu": "200m",
    "memory": "50Mi",
    "pods": "4"
  },
  "instance-types": "m6g.medium, m6gd.medium, m7g.medium, m8g.medium, m8gd.medium and 10 other(s)"
}
```

**Inicio de la nueva instancia:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:10.582Z",
  "logger": "controller",
  "message": "launched nodeclaim",
  "provider-id": "aws:///eu-central-1b/i-0f0d32ba789615574",
  "instance-type": "t4g.small",
  "zone": "eu-central-1b",
  "capacity-type": "spot",
  "allocatable": {
    "cpu": "1930m",
    "memory": "1359Mi"
  }
}
```

**Paso 7: Comprobación del nuevo NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-48ck8   t4g.small   spot       eu-central-1b   ip-10-10-16-44.eu-central-1.compute.internal   True    8m59s
```

**¡Excelente!** Karpenter sustituyó `t3.xlarge` (4 vCPU) por `t4g.small` (2 vCPU), que es considerablemente más económico.

**Paso 8: Limpieza**

Elimine el deployment:

```bash
kubectl delete deployments.apps -n team-19 team19
```

Espere a que se elimine NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
No resources found
```

**Conclusión:** Karpenter optimiza automáticamente los tamaños de los nodos, seleccionando las opciones más económicas que cumplen los requisitos de las aplicaciones.


## Actualización de la configuración de nodos (Drift)

Drift es un mecanismo de actualización automática de nodos cuando cambia la configuración de EC2NodeClass. Cuando cambia la AMI, los security groups, user data u otros parámetros, Karpenter sustituye automáticamente los nodos existentes por otros nuevos con la configuración actualizada.

### Actualización de imágenes AMI

**Paso 1: Obtención de la AMI de la versión anterior de EKS**

Obtengamos el ID de AMI para EKS versión 1.33:

```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query "Parameter.Value" \
  --output text
```

**Resultado:**
```
ami-0fc1cdef3ebc3a8fe
```

**Paso 2: Configuración de la AMI antigua en EC2NodeClass**

Edite EC2NodeClass:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Busque la sección `amiSelectorTerms` y cambie:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Antes
```

Por:

```yaml
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - id: "ami-0fc1cdef3ebc3a8fe"  # ID de AMI específico de la versión 1.33
```

**Paso 3: Despliegue de la aplicación**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Paso 4: Comprobación de la versión del nodo**

```bash
kubectl get no
```

**Resultado:**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   58m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   2m23s v1.33.5-eks-ecaa3a6   <-- ¡Versión 1.33!
```

**Tenga en cuenta:** El nodo usa Kubernetes versión 1.33.5 (de la AMI antigua).

### Migración automática a versiones nuevas

**Paso 5: Regreso a la selección automática de AMI**

Vuelva a editar EC2NodeClass:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Cambie a:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Selección automática de la versión más reciente
```

**Qué sucede:**
- Karpenter detecta el cambio en EC2NodeClass
- Determina que el nodo existente usa una configuración obsoleta (drift)
- Crea automáticamente un nodo nuevo con la AMI actualizada
- Mueve los pods al nodo nuevo de forma ordenada
- Elimina el nodo antiguo

**Paso 6: Comprobación de la actualización del nodo**

Espere aproximadamente un minuto y compruebe los nodos:

```bash
kubectl get no
```

**Resultado (después de ~30 segundos):**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   87m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   33s   v1.34.2-eks-ecaa3a6   <-- ¡Versión nueva!
```

**Resultado (después de ~4 minutos):**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   91m     v1.34.2-eks-b3126f4
ip-10-10-16-230.eu-central-1.compute.internal           Ready    <none>   4m22s   v1.34.2-eks-ecaa3a6
```

**¡Excelente!** Karpenter sustituyó automáticamente el nodo por uno nuevo con la versión AMI actualizada (1.34.2).

**Paso 7: Limpieza**

```bash
kubectl delete deployments.apps -n team-19 team19
```

Espere a que se elimine NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
No resources found
```

**Conclusión:** Drift permite actualizar automáticamente los nodos cuando cambia la configuración, sin intervención manual. Esto es especialmente útil para:
- Actualización de AMI (parches de seguridad, versiones nuevas de Kubernetes)
- Cambio de security groups
- Actualización de scripts de user data
- Cambio de roles IAM

---

## Trabajo con varios NodePool

En un entorno de producción, con frecuencia se requiere separar la carga en distintos grupos de nodos. Por ejemplo:
- Controladores Ingress en nodos dedicados
- Nodos potentes para tareas periódicas (jobs)
- Nodos con GPU para cargas ML/AI
- Nodos con gran cantidad de memoria para bases de datos

### Aislamiento de carga mediante Taints y Tolerations

**Escenario:** Necesitamos ejecutar job periódicos con requisitos elevados de recursos (CPU, memoria, GPU).

**Requisitos:**
1. Los pods normales no deben llegar a estos nodos (solo job)
2. Mientras un job se ejecuta en el nodo, no debe producirse consolidación
3. Tan pronto como el job termina, el nodo debe eliminarse

### Nodos especializados para Job

**Paso 1: Creación de un NodePool especializado**

```bash
cat <<EoF> job-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: job
spec:
  template:
    metadata:
      labels:
        work_type: "job_karpenter"  # Etiqueta para identificar
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: job
      expireAfter: 720h # 30 días
      # IMPORTANTE: Taint evita que los pods normales se ejecuten en estos nodos
      taints:
        - key: workType
          value: "job"
          effect: NoSchedule  # Los pods sin la toleration correspondiente no podrán iniciarse
  limits:
    cpu: 6
  disruption:
    consolidationPolicy: WhenEmpty  # Eliminar SOLO nodos vacíos (no durante la ejecución del job)
    consolidateAfter: 10s           # Eliminación rápida tras finalizar el job
EoF

kubectl apply -f job-nodepool.yaml
```

**Diferencias clave respecto al NodePool default:**

1. **Taints** — evitan que se ejecuten pods normales:
   ```yaml
   taints:
     - key: workType
       value: "job"
       effect: NoSchedule
   ```

2. **consolidationPolicy: WhenEmpty** — el nodo se elimina solo cuando está completamente vacío (no interrumpe job en ejecución)

3. **consolidateAfter: 10s** — eliminación rápida tras finalizar

**Paso 2: Obtención de parámetros de la salida de Terraform**

Busque en la salida:

```bash
# Ejemplo:
# eks_name = "eks2-viktor-01"
# karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Paso 3: Creación de EC2NodeClass para job**

```bash
cat <<EoF> job-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: job
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"  # Sustituya por el suyo
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Sustituya por el nombre de su clúster
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Sustituya por el nombre de su clúster
  tags:
      Name: "eks2-viktor-01-job"  # Sustituya por el nombre de su clúster
      team: "infra"
      work_type: "job"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 25Gi
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
EoF

kubectl create -f job-nodeclass.yaml
```

**Paso 4: Comprobación del estado de los recursos**

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Resultado:**
```
NAME      READY   AGE
default   True    8m10s
job       True    2m22s
```

```bash
kubectl get nodepools.karpenter.sh
```

**Resultado:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    9m30s
job       job         0       True    3m38s
```

**Si el estado no es READY**, ejecute el diagnóstico:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws job
kubectl describe nodepools.karpenter.sh job
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Paso 5: Inicio de Job con Toleration**

Cree un job que pueda iniciarse en nodos con el taint `workType=job`:

```bash
cat <<EoF> test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: testjob
spec:
  template:
    spec:
      # Toleration permite que el pod se inicie en nodos con el taint correspondiente
      tolerations:
      - key: workType
        operator: Equal
        value: job
        effect: NoSchedule
      # Affinity garantiza que el pod se inicie específicamente en nodos del Job NodePool
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: work_type
                operator: In
                values:
                - job_karpenter
      containers:
      - name: job-container
        image: busybox
        command: ["sh", "-c", "echo 'Job started'; sleep 30; echo 'Job completed'"]
      restartPolicy: Never
  backoffLimit: 1
EoF

kubectl apply -f test-job.yaml
```

**Paso 6: Comprobación de la creación de NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado:**
```
NAME        TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
job-mpt7v   t4g.small   spot       eu-central-1b   ip-10-10-16-18.eu-central-1.compute.internal   True    58s
```

**Comprobación del pod:**

```bash
kubectl get po
```

**Resultado (durante la ejecución):**
```
NAME            READY   STATUS    RESTARTS   AGE
testjob-gtlbk   1/1     Running   0          64s
```

**Resultado (después de finalizar):**
```
NAME            READY   STATUS      RESTARTS   AGE
testjob-gtlbk   0/1     Completed   0          72s
```

**Comprobación de nodos:**

```bash
kubectl get no
```

**Resultado:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   130m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   128m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   130m   v1.34.2-eks-b3126f4
ip-10-10-16-18.eu-central-1.compute.internal            Ready    <none>   59s    v1.34.2-eks-ecaa3a6
```

**Paso 7: Comprobación de la eliminación automática del nodo**

Espere aproximadamente 10-15 segundos después de finalizar el job y compruebe los nodos:

```bash
kubectl get no
```

**Resultado:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**¡El nodo se eliminó correctamente!** Karpenter eliminó automáticamente el nodo 10 segundos después de finalizar el job.

**Conclusión:** Usar varios NodePool con taints y tolerations permite:
- Aislar distintos tipos de carga
- Optimizar los costes (eliminación rápida de nodos después de finalizar el job)
- Evitar que los pods normales se ejecuten en nodos especializados
- Gestionar de forma flexible las políticas de consolidación para distintos tipos de carga



## Limpieza de recursos

Después de completar el laboratorio, es necesario eliminar todos los recursos creados para evitar gastos innecesarios.

**Paso 1: Comprobación de que no haya NodeClaim activos**

Asegúrese de que no haya NodeClaim activos:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado esperado:**
```
No resources found
```

**Si hay NodeClaim activos:**

1. Compruebe que no haya pods en ejecución en los nodos:

```bash
kubectl get pods --all-namespaces -o wide
```

2. Elimine el deployment, pods o jobs:

```bash
# Ejemplo de eliminación de deployment
kubectl delete deployment -n team-19 team19

# Ejemplo de eliminación de job
kubectl delete job testjob
```

3. Después de eliminar los pods, elimine NodeClaim manualmente (si es necesario):

```bash
kubectl delete nodeclaim <name-of-nodeclaim>
```

**Paso 2: Comprobación de los nodos del clúster**

Asegúrese de que solo queden nodos Fargate:

```bash
kubectl get no
```

**Resultado esperado:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**Todos los nodos deben empezar por `fargate-`.**

**Paso 3: Eliminación de la infraestructura**

Elimine todos los recursos creados para el laboratorio:

```bash
TASK=02 make delete_eks_task
```

**Salida del comando:**

```
16:14:15.750 INFO   The stack at . will be processed in the following order for command destroy:
Group 1
- Module ./worker

Group 2
- Module ./eks_karpenter
- Module ./ssh-keys

Group 3
- Module ./eks_addons

Group 4
- Module ./eks_fargate_system

Group 5
- Module ./eks_control_plane

Group 6
- Module ./vpc


WARNING: Are you sure you want to run `terragrunt destroy` in each folder of the stack described above? There is no undo! (y/n)
```

**Introduzca `y` para confirmar la eliminación.**

**Qué se eliminará:**
- Nodo de trabajo (worker)
- Controlador Karpenter y recursos relacionados
- Claves SSH
- EKS add-ons
- Fargate profile
- EKS Control Plane
- VPC e infraestructura de red

**El proceso de eliminación tardará aproximadamente 10-15 minutos.**

---

## Conclusión

¡Enhorabuena! Ha completado correctamente el laboratorio sobre los fundamentos de Karpenter.

**Lo que ha aprendido:**

1. **Configuración básica** — creación de NodePool y EC2NodeClass para la gestión automática de nodos
2. **Escalado automático** — Karpenter añade nodos dinámicamente cuando aumenta la carga
3. **Gestión de límites** — control de la cantidad máxima de recursos mediante limits
4. **Consolidación** — eliminación automática de nodos vacíos e infrautilizados para optimizar costes
5. **Right-sizing** — selección automática del tamaño óptimo de los nodos según los requisitos de los pods
6. **Drift** — actualización automática de nodos al cambiar la configuración (AMI, security groups, etc.)
7. **Múltiples NodePool** — aislamiento de distintos tipos de carga mediante taints, tolerations y affinity

**Ventajas clave de Karpenter:**

- **Escalado rápido** — los nodos se crean en segundos, no en minutos
- **Optimización de costes** — selección automática de los tipos de instancias más económicos
- **Flexibilidad** — soporte de instancias spot y on-demand, distintas arquitecturas (amd64, arm64)
- **Simplicidad** — configuración declarativa mediante recursos de Kubernetes
- **Automatización** — mínima intervención manual en la gestión de nodos

**Recursos adicionales:**

- [Documentación oficial de Karpenter](https://karpenter.sh/docs/)
- [Prácticas recomendadas para Karpenter](https://karpenter.sh/docs/concepts/nodepools/#best-practices)
- [Guía de solución de problemas](https://karpenter.sh/docs/troubleshooting/)
- [Prácticas recomendadas de AWS EKS](https://aws.github.io/aws-eks-best-practices/)

**Siguientes pasos:**

- Explore las capacidades avanzadas de Karpenter (NodePools ponderados, AMI personalizadas, soporte de GPU)
- Integre Karpenter con sus aplicaciones de producción
- Configure la monitorización y las alertas para Karpenter
- Optimice los costes analizando el uso de instancias spot frente a on-demand
