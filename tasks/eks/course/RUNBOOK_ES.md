[Русская версия](RUNBOOK_RU.md) · [Eng version](RUNBOOK.md) · [Version française](RUNBOOK_FR.md) · [Deutsche Version](RUNBOOK_DE.md) · [ქართული ვერსია](RUNBOOK_GE.md) · [繁體中文版](RUNBOOK_TW.md) · [日本語版](RUNBOOK_JP.md)

# Guía de diagnóstico de EKS: síntoma, causa, comprobación

[Índice del curso](README_ES.md) · [Glosario](GLOSSARY_ES.md)

## Cómo usar esta guía

Este es un resumen de las secciones «Orden de diagnóstico y herramientas» de los capítulos 45,
46 y 47, reunidas en un solo archivo para las guardias: durante un incidente resulta incómodo
consultar tres capítulos. Funciona así: primero identifique la CLASE del síntoma mediante la tabla
«Acceso rápido por síntoma», luego vaya a su capa y recórrala de arriba abajo. La clasificación es
más importante que la herramienta: un pod en `ContainerCreating` y un 503 del balanceador se
resuelven con comandos distintos.
Aquí solo se incluye el orden de recorrido, las listas de comprobación y los comandos. El análisis
de las causas, la mecánica y las explicaciones permanecen en los capítulos 45-47; los enlaces a
ellos están en cada fila del navegador.

## Acceso rápido por síntoma

| Qué se observa | Clase | Dónde ir |
|---|---|---|
| `kubectl get nodes` vacío, no hay nodos | el nodo no se unió | [nodo](#el-nodo-no-se-unió-al-clúster), [capítulo 45](45/es.md) |
| `NodeCreationFailure`, `Instances failed to join the kubernetes cluster` | el nodo no se unió | [nodo](#el-nodo-no-se-unió-al-clúster), [capítulo 45](45/es.md) |
| node group en `CREATE_FAILED` o `DEGRADED` | el nodo no se unió | [nodo](#el-nodo-no-se-unió-al-clúster), [capítulo 45](45/es.md) |
| en el log de kubelet `node "" not found` | nodo: DNS y private DNS name | [nodo](#el-nodo-no-se-unió-al-clúster), [capítulo 45](45/es.md) |
| el nodo es visible, pero `NotReady` | CNI no está listo, otra capa | [nodo](#el-nodo-no-se-unió-al-clúster), [capítulo 45](45/es.md), capítulo 8 |
| pod en `ContainerCreating`, `failed to assign an IP address to container` | red: IP y ENI | [red](#fallos-de-red-en-un-clúster-en-funcionamiento), [capítulo 46](46/es.md) |
| pod-pod o pod-RDS `connection timed out`, DNS se resuelve | red: security group | [red](#fallos-de-red-en-un-clúster-en-funcionamiento), [capítulo 46](46/es.md) |
| la solicitud sale, pero la conexión se bloquea | red: NACL y ephemeral ports | [red](#fallos-de-red-en-un-clúster-en-funcionamiento), [capítulo 46](46/es.md) |
| el pod no resuelve nombres ni supera readiness | red: su propio SG para el pod | [red](#fallos-de-red-en-un-clúster-en-funcionamiento), [capítulo 46](46/es.md) |
| DNS funciona de forma intermitente, timeouts variables | red: DNS | [red](#fallos-de-red-en-un-clúster-en-funcionamiento), [capítulo 46](46/es.md) |
| carga DNS adicional sobre nombres externos | red: efecto `ndots:5` | [red](#fallos-de-red-en-un-clúster-en-funcionamiento), [capítulo 46](46/es.md) |
| targets en el target group `unhealthy`, 502 `Bad gateway` | red: balanceador | [red](#fallos-de-red-en-un-clúster-en-funcionamiento), [capítulo 46](46/es.md) |
| 503 `Service unavailable` del servicio tras el LB | red: no hay targets sanos | [red](#fallos-de-red-en-un-clúster-en-funcionamiento), [capítulo 46](46/es.md) |
| `You must be logged in to the server (Unauthorized)` | acceso: autenticación | [acceso](#acceso-denegado-persona-y-pod), [capítulo 47](47/es.md) |
| `couldn't get current server API group list: Unauthorized` | acceso: kubeconfig o región | [acceso](#acceso-denegado-persona-y-pod), [capítulo 47](47/es.md) |
| `Forbidden: cannot <verb> resource` | acceso: RBAC | [acceso](#acceso-denegado-persona-y-pod), [capítulo 47](47/es.md) |
| el pod falla con `AccessDenied` al llamar a AWS | acceso del pod: STS y rol | [acceso](#acceso-denegado-persona-y-pod), [capítulo 47](47/es.md) |
| el pod falla con `WebIdentityErr: failed to retrieve credentials` | acceso del pod: IRSA | [acceso](#acceso-denegado-persona-y-pod), [capítulo 47](47/es.md) |

## El nodo no se unió al clúster

Capítulo 45. El síntoma es uno: `kubectl get nodes` vacío y `NodeCreationFailure`, pero las causas
se encuentran en capas distintas. Orden de recorrido de arriba abajo:

1. Capa IAM: permisos del node instance role y autorización del rol en el clúster (sección 45.2).
2. Capa de red: ruta al endpoint del servidor API en 443, tipo de endpoint, DNS (sección 45.3).
3. Capa de user data y bootstrap: `bootstrap.sh` en AL2, `nodeadm`/`NodeConfig` en AL2023 (45.4).
4. Capa kubelet: el demonio está iniciado, kubeconfig y certificado están íntegros, el registro se completó (45.5).

Lógica: primero consulte EKS mediante `describe-nodegroup`, luego compruebe la autorización del
rol (es barato y con frecuencia es el culpable), después la red hacia el endpoint, y solo entonces
entre al nodo para revisar los logs de cloud-init y kubelet. Distinga «no hay nodos» de `NotReady`:
lo segundo, con kubelet activo, es casi siempre CNI; corresponde al capítulo 8.

| Síntoma | Causa probable | Qué comprobar |
|---|---|---|
| `NodeCreationFailure`, no hay nodos | el rol del nodo no está autorizado | `aws eks list-access-entries`, `aws-auth` |
| no hay nodos, IAM está bien | no hay ruta al API en 443 | SG, ruta NAT/IGW, tipo de endpoint |
| no hay nodos, clúster privado | el endpoint no se resuelve | DNS, DHCP options set en la VPC |
| no hay nodos, AMI personalizada | bootstrap no se ejecutó | `/var/log/cloud-init-output.log` |
| no hay nodos, kubelet falla | kubeconfig/certificado dañado | `journalctl -u kubelet` |
| hay nodo, pero `NotReady` | CNI no está listo, los pods no tienen IP | pod `aws-node`, eventos del nodo (capítulo 8) |
| en el log `node "" not found` | no hay private DNS name | DHCP options, DNS en la VPC |

```bash
# 1. qué informa EKS sobre el node group
aws eks describe-nodegroup --cluster-name prod --nodegroup-name ng-1 \
  --query 'nodegroup.health.issues'
# 2. si el clúster ve los nodos
kubectl get nodes
# 3. si el rol del nodo está autorizado
aws eks list-access-entries --cluster-name prod
# ruta obsoleta: mapeos en aws-auth
kubectl -n kube-system get configmap aws-auth -o yaml
# 4. en el nodo mediante SSM Session Manager: log de bootstrap/cloud-init
sudo cat /var/log/cloud-init-output.log
# 5. en el nodo: estado y logs de kubelet
systemctl status kubelet
journalctl -u kubelet -n 200 --no-pager
```

El acceso al nodo sin SSH se realiza mediante SSM Session Manager: se necesitan el agente SSM y
los permisos. Si SSM no está disponible, quedan la salida de consola de la instancia (system log)
y `/var/log`.

## Fallos de red en un clúster en funcionamiento

Capítulo 46. El clúster funciona, los nodos están `Ready`, pero la red puede fallar de distintas
formas. Primero clasifique el síntoma: no hay IP, corte de conectividad, DNS, 5xx del balanceador.
La clase determina la capa y el comando. `describe pod` y `get pods -o wide` son económicos y
primero descartan problemas de IP; `describe-target-health` localiza de inmediato un fallo del
balanceador; VPC Flow Logs es el último recurso para cortes que no explican ni la IP ni el health
check. Recuerde la diferencia entre capas: security group es stateful y opera a nivel de ENI, NACL
es stateless y opera a nivel de subred, por eso el tráfico de retorno en ephemeral ports se permite
manualmente en NACL.

| Síntoma | Causa probable | Qué comprobar |
|---|---|---|
| `failed to assign an IP address` | no hay IP libres en el nodo o en la subred | `describe pod`, `AvailableIpAddressCount` |
| timeout pod-pod o pod-RDS | SG no permite el tráfico | `describe-network-interfaces` Groups, SG de RDS |
| corte, pero la solicitud sale | NACL bloquea ephemeral ports | reglas NACL de entrada/salida, VPC Flow Logs |
| DNS con timeouts intermitentes | CoreDNS, conntrack, throttling por ENI | métricas de CoreDNS (capítulo 33), conntrack, PPS |
| carga DNS adicional sobre nombres externos | efecto `ndots:5` | dominios de búsqueda, FQDN con punto |
| 502 o 503 del servicio tras LB | targets `unhealthy` | `describe-target-health`, health check, SG |
| targets `unhealthy`, pod activo | ruta/puerto del health check o SG | ruta y puerto de comprobación, SG del balanceador |
| pod sin DNS ni readiness | su propio SG para el pod en vez del SG del nodo | `SecurityGroupPolicy` del pod, 53 TCP/UDP, entrada desde SG de nodos |

```bash
# 1. eventos del pod: motivo de ContainerCreating y asignación de IP
kubectl describe pod <pod>
# 2. dónde está el pod y en qué nodo
kubectl get pods -o wide
# 3. ENI, IP y SG de una dirección concreta
aws ec2 describe-network-interfaces \
  --filters "Name=private-ip-address,Values=<ip>" --query 'NetworkInterfaces[0]'
# 4. direcciones libres en la subred
aws ec2 describe-subnets --subnet-ids <subnet> \
  --query 'Subnets[0].AvailableIpAddressCount'
# 5. salud de los targets del balanceador
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
# si hay endpoints listos tras el servicio
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
# 6. comprobar la resolución desde el pod
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup <name>
# SG propia del pod: modo de aplicación y búsqueda del error en el id de SG
kubectl describe daemonset aws-node -n kube-system | grep -iE 'SECURITY_GROUP|DEMUX'
kubectl describe pod <pod> | grep -i InvalidSecurityGroupID
# 7. en el nodo: recopilar el volcado de red de VPC CNI (logs ipamd/plugin, ENI, eni-configs)
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids <instance-id> \
  --parameters 'commands=["/opt/cni/bin/aws-cni-support.sh"]'
```

El estado de ipamd también puede verse directamente mediante su endpoint local: `/v1/enis` muestra
los ENI e IP asignados, y `/v1/pods`, la vinculación de direcciones con los pods.

## Acceso denegado: persona y pod

Capítulo 47. Los fallos de acceso se dividen en dos ejes independientes, y la primera pregunta de
quien está de guardia es cuál de ellos está roto: una persona o CI no puede entrar al clúster, o un
pod recibe `AccessDenied` al llamar a AWS. Después, el código de denegación completa la
clasificación. `Unauthorized` (401) es un fallo de autenticación: no hay token, ha expirado o la
identity no está mapeada; se corrige en kubeconfig, las credenciales y el mapeo (access entry o
aws-auth). `Forbidden` (403) es un fallo de autorización: la identity ya es conocida, pero RBAC no
concede permisos; se corrige en Role, ClusterRole y bindings. `AccessDenied` desde un pod apunta
a IRSA o Pod Identity. La bifurcación rápida «el clúster o yo»: si `aws sts get-caller-identity`
muestra una identity distinta, el problema es local: perfil, región o credenciales.

| Síntoma | Causa probable | Qué comprobar |
|---|---|---|
| `Unauthorized`, `must be logged in` | identity incorrecta o no mapeada | `sts get-caller-identity`, `list-access-entries` |
| `Unauthorized` justo tras `edit aws-auth` | se eliminó el propio mapeo | `get cm aws-auth`, restaurar mediante access entry |
| `Forbidden: cannot <verb>` | RBAC no concede permisos | `kubectl auth can-i`, Role y bindings |
| `couldn't get server API group` | kubeconfig o región dañados | `update-kubeconfig`, `current-context`, perfil |
| pod con `AccessDenied` en IRSA | trust policy, OIDC, anotación de SA | proveedor OIDC, `sub`/`aud`, anotación `role-arn` |
| pod con `WebIdentityErr` | token no montado, rol incorrecto | recrear el pod, comprobar trust policy |
| pod con `AccessDenied` en Pod Identity | no hay association, agente o token | `list-pod-identity-associations`, agente, token en el pod |

```bash
# quién soy realmente a ojos de AWS
aws sts get-caller-identity
# modo de autenticación y accessConfig del clúster
aws eks describe-cluster --name <cluster> --query 'cluster.accessConfig'
# quién está mapeado mediante access entries
aws eks list-access-entries --cluster-name <cluster>
# contenido de aws-auth (si el modo aún lo utiliza)
kubectl -n kube-system get cm aws-auth -o yaml
# authz: qué puedo hacer realmente
kubectl auth can-i --list
kubectl auth can-i get pods -n <ns>
# regenerar kubeconfig y comprobar el contexto
aws eks update-kubeconfig --name <cluster> --region <region> --profile <profile>
kubectl config current-context
# eje del pod: anotación de rol en ServiceAccount (IRSA)
kubectl get sa <sa> -n <ns> -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# asociaciones de Pod Identity
aws eks list-pod-identity-associations --cluster-name <cluster>
# si el agente Pod Identity se está ejecutando
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-pod-identity-agent
# si el token Pod Identity está montado en el propio pod (sin archivo, agente/association no funcionaron)
kubectl exec <pod> -n <ns> -- ls /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/
```

Un clúster bloqueado se recupera mediante la API de EKS: `update-cluster-config` con
`authenticationMode=API_AND_CONFIG_MAP`, después `create-access-entry` y
`associate-access-policy` con `AmazonEKSClusterAdminPolicy` (sección 47.4). No es posible volver
a `CONFIG_MAP`.

## Qué revisar cuando nada encaja

- **VPC Flow Logs** registran si un paquete recibió `ACCEPT` o `REJECT` a nivel de ENI o subred.
  `REJECT` indica SG o NACL, y la ausencia de paquetes de respuesta cuando salió una solicitud
  apunta a NACL stateless y ephemeral ports.
- **Los logs del control plane** (api, audit, authenticator) se habilitan con antelación, no a
  posteriori: los logs de authenticator muestran si la identity entrante está mapeada (capítulos 21
  y 34).
- **`aws-cni-support.sh` mediante SSM** recopila los logs de ipamd y plugin junto con el estado de
  ENI/IP y la configuración en un archivo `/var/log/eks_<instance-id>_<...>.tar.gz`, sin SSH al
  nodo.
- **Los logs de `/var/log/aws-routed-eni`** (`ipamd.log`, `plugin.log`) se leen en el nodo cuando
  el pod queda bloqueado con `failed to assign an IP address` y no está claro si se agotaron las IP
  o no se levantó la ENI.

## Lo que no incluye esta guía

Esto no sustituye a los capítulos: las explicaciones de las causas, la mecánica de las capas y el
análisis de por qué el síntoma se presenta así no están aquí; se encuentran en los capítulos 45, 46
y 47. Aquí solo están el orden de recorrido y los comandos. Los laboratorios de troubleshooting del
curso (119, 120, 121 y también el 126 sobre security groups for pods) no se duplican en este
archivo: se realizan siguiendo sus propias tareas.
