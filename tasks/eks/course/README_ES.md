[Русская версия](README_RU.md) · [Eng version](README.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# Amazon EKS: curso práctico autodidacta de operaciones de producción

Curso práctico de Amazon EKS vinculado a los laboratorios de `tasks/eks/labs`.
Está dirigido a ingenieros que **ya han completado CKA** (o dominan Kubernetes a
nivel de administrador) y pasan a un clúster administrado en AWS.

No existe una certificación independiente de EKS, por eso el curso no está
orientado a un examen, sino a la operación real: aquello de lo que es responsable
el ingeniero cuando AWS mantiene el control plane, pero los nodos, la red, los
accesos, el coste y las actualizaciones siguen en tus manos.

> **Conocimientos previos.** Pods, Deployment, Service, Ingress, RBAC, PV/PVC,
> probes, kubectl y la depuración de cargas son la base del curso CKA y aquí no se
> repiten. Si aún no dominas estos temas, empieza con el
> [curso CKA + CKAD](../../cka/course/README_ES.md).

> **Versiones.** El curso se orienta a las versiones actuales de EKS (Kubernetes
> `1.33` - `1.36`). EKS tiene su propio ciclo de vida de versiones: 14 meses de
> standard support más 12 meses de extended support (26 meses por versión menor),
> por lo que el capítulo sobre actualizaciones se vincula al proceso, no a un
> número concreto. Los laboratorios del curso se despliegan con la versión de
> `env.hcl` de cada laboratorio.

## Cómo está organizado el curso

Cada tema es una carpeta numerada. Dentro se encuentran los archivos localizados.
El idioma principal es el ruso (`ru.md`), a partir del cual se hicieron las
traducciones (como en los cursos de CKA e Istio). El selector de idiomas aparece
en la primera línea de cada archivo después de la primera traducción.

El curso requiere **tu propia cuenta de AWS**: casi todos los temas solo se
verifican en un clúster activo, y una parte de ellos (interrupciones spot, NAT y
tráfico, actualizaciones, coste) no puede reproducirse en kind local. Los
laboratorios se despliegan mediante Terragrunt y se eliminan con un solo comando
para no gastar dinero.

Además de capítulos y laboratorios, el curso incluye referencias de trabajo: no
se leen de principio a fin, sino cuando hacen falta:

- [Glosario del curso](GLOSSARY_ES.md) - todos los términos por capítulo con enlaces
- [Guía de diagnóstico](RUNBOOK_ES.md) - síntoma, causa, comprobación: Parte 8 en resumen
- [Decisiones de arquitectura (ADR)](ADR_ES.md) - plantillas de decisiones para las bifurcaciones del curso
- [Matriz de madurez de EKS](SCORECARD_ES.md) - cuestionario de preparación del clúster en ocho dominios
- [Modelo de costes](COST_MODEL_ES.md) - lista de partidas y fórmulas; introduces tus propias tarifas

## Contenido

### Parte 0. Fundamentos de AWS (opcional)

Parte preparatoria para quienes llegan con Kubernetes sólido y AWS débil. Si IAM,
VPC y EC2 son herramientas habituales para ti, pasa directamente a la Parte 1.
Esta parte no tiene laboratorios separados: sirve para que los demás capítulos se
lean sin lagunas.

- 0.1. [AWS para el ingeniero de Kubernetes: cuentas, regiones, AZ, cuotas, etiquetas y facturación](00-1-aws/es.md)
- 0.2. [IAM desde cero: políticas, roles, confianza, STS y claves temporales](00-2-iam/es.md)
- 0.3. [VPC desde cero: subredes, enrutamiento, IGW y NAT, security groups, VPC endpoints](00-3-vpc/es.md)
- 0.4. [EC2 y modelos de pago: tipos de instancia, AMI, on-demand, spot, Savings Plans](00-4-ec2/es.md)
- 0.5. [Herramientas: aws cli, eksctl, terraform y terragrunt, helm, plugins útiles](00-5-tools/es.md)

### Parte 1. Arquitectura y creación del clúster

1. [Introducción: qué asume EKS y qué queda en tus manos](01/es.md)
2. [Control plane de EKS: endpoint público y privado, platform versions, SLA, logs](02/es.md)
3. [Ciclo de vida de versiones: standard y extended support, estrategia de actualización](03/es.md)
4. [Creación del clúster: eksctl, Terraform y Terragrunt, CloudFormation](04/es.md) 🧪
5. [Acceso al clúster: IAM y RBAC, access entries, migración desde aws-auth](05/es.md)
6. [Red del clúster: VPC CNI, ENI y direcciones IP, planificación de CIDR](06/es.md) 🧪
7. [Escala del plan de direccionamiento: prefix delegation, CIDR secundario, custom networking](07/es.md)
8. [Alternativas a VPC CNI: Cilium, modos de red, cuándo cambiar el CNI](08/es.md) 🧪

### Parte 2. Nodos y recursos de cómputo

9. [Tipos de cómputo: managed node groups, self-managed, Fargate, Auto Mode](09/es.md) 🧪
10. [AMI y bootstrap: AL2023, Bottlerocket, launch templates, kubelet y user data](10/es.md) 🧪
11. [Cluster Autoscaler y Karpenter: dos enfoques para el escalado de nodos](11/es.md)
12. [Karpenter: NodePool, EC2NodeClass, disruption, consolidation, drift](12/es.md)
13. [Instancias spot: interrupciones, diversificación, gestión de eventos](13/es.md)
14. [Densidad y dimensionamiento: pods por nodo, límites de ENI, requests y limits en la nube](14/es.md)
15. [Fargate: perfiles, limitaciones, coste y casos de uso](15/es.md)

### Parte 3. Identidad y seguridad

16. [IRSA: proveedor OIDC, trust policy, anotaciones de ServiceAccount](16/es.md)
17. [EKS Pod Identity: agente, asociaciones, migración desde IRSA](17/es.md)
18. [Secretos: cifrado KMS, Secrets Manager y SSM mediante External Secrets y CSI](18/es.md)
19. [Hardening: IMDSv2 y hop limit, Pod Security Admission, clúster privado](19/es.md)
20. [Imágenes y supply chain: ECR, análisis, firmas, pull through cache](20/es.md) 🧪
21. [Auditoría y detección: logs del control plane, CloudTrail, GuardDuty, monitorización de runtime](21/es.md)
22. [Políticas y multitenencia: Kyverno y Gatekeeper, aislamiento de equipos](22/es.md) 🧪

### Parte 4. Almacenamiento de datos

23. [EBS CSI: gp3, StorageClass, expansión, snapshots, vinculación a AZ](23/es.md)
24. [EFS y FSx: shared storage para cargas entre AZ](24/es.md)
25. [S3 en aplicaciones: Mountpoint for Amazon S3 CSI y patrones de acceso](25/es.md) 🧪

### Parte 5. Red y tráfico

26. [AWS Load Balancer Controller y Service de tipo LoadBalancer: NLB](26/es.md)
27. [Ingress mediante ALB: target-type, anotaciones, TLS y ACM, WAF](27/es.md)
28. [Gateway API en AWS: ALB Gateway API y VPC Lattice](28/es.md) 🧪
29. [DNS y certificados: external-dns, Route 53, cert-manager](29/es.md)
30. [NetworkPolicy en EKS: VPC CNI network policy y Cilium](30/es.md)
31. [Egress y coste del tráfico: NAT, VPC endpoints, PrivateLink](31/es.md)
32. [Multiclúster y multicuenta: conectividad, recursos compartidos, patrones](32/es.md)

### Parte 6. Observabilidad

33. [Métricas: Container Insights, Managed Prometheus y Grafana, kube-prometheus-stack](33/es.md)
34. [Logs: Fluent Bit, CloudWatch Logs, OpenSearch, control de gastos](34/es.md)
35. [Autoescalado de aplicaciones: HPA, métricas externas, KEDA](35/es.md) 🧪
36. [Trazado y profiling: ADOT y X-Ray](36/es.md)

### Parte 7. Operaciones

37. [Add-ons de EKS: managed addons frente a Helm, versiones y orden de actualización](37/es.md)
38. [Actualización del clúster: in-place por versiones, clústeres blue/green, API obsoletas](38/es.md)
39. [Reversión de la versión del clúster: rollback readiness insights, ventana de 7 días, orden de reversión](39/es.md)
40. [Fiabilidad: multi-AZ, PDB, topology spread, apagado correcto de nodos](40/es.md) 🧪
41. [Copia de seguridad del clúster mediante AWS Backup: estado del clúster, volúmenes persistentes, composite recovery point](41/es.md) 🧪
42. [Restauración y DR: restore en un clúster existente y nuevo, namespace-restore, Velero](42/es.md) 🧪
43. [Coste: OpenCost y Kubecost, right-sizing, Savings Plans, mezcla spot, tráfico](43/es.md)
44. [GitOps y entrega: Argo CD y Flux, gestión de una flota de clústeres](44/es.md) 🧪

Esta parte incluye dos referencias: el [modelo de costes](COST_MODEL_ES.md), un
formulario de estimación para el capítulo 43, y las
[decisiones de arquitectura](ADR_ES.md), plantillas ADR para las bifurcaciones de
todo el curso.

### Parte 8. Troubleshooting

45. [El nodo no se unió al clúster: IAM, SG, user data, bootstrap, kubelet](45/es.md)
46. [Fallos de red: ENI exhausted, SG y NACL, DNS, targets unhealthy en el balanceador](46/es.md) 🧪
47. [Acceso e IAM: access entries, IRSA y Pod Identity, webhook, kubeconfig](47/es.md) 🧪

Las secciones «Orden de diagnóstico» de estos tres capítulos se reúnen en la
[guía de diagnóstico](RUNBOOK_ES.md): síntoma, causa probable, qué comprobar. En
una guardia es más cómodo abrirla que tres capítulos.

### Parte 9. Final

48. [Checklist de producción de EKS y qué leer después](48/es.md)

Los checklists del capítulo 48 en forma de cuestionario con puntuación y lista de
deuda técnica están en la [matriz de madurez de EKS](SCORECARD_ES.md).

## Práctica

El curso cuenta con su propio conjunto de laboratorios numerados a partir de
`101`, vinculados a los capítulos. Los laboratorios se despliegan en tu cuenta de
AWS mediante Terragrunt, se verifican automáticamente con `check_result` y se
eliminan con un solo comando:

- 🧪 [Laboratorios de EKS](../../../docs/labs.MD#eks-labs) - lista de laboratorios y comandos de ejecución

El conjunto de laboratorios del curso está actualmente en desarrollo. El icono 🧪
en el índice significa que el capítulo ya tiene su propio laboratorio; los
capítulos sin icono se estudian por ahora como teoría.

El repositorio también contiene laboratorios anteriores de EKS ([Karpenter](../labs/02/README_ES.MD),
[autoescalado con KEDA y Prometheus](../labs/03/README_ES.MD)). No forman parte
del curso y tienen una vida propia, pero sus temas se cruzan con los capítulos 12
y 35, por lo que puedes realizarlos como práctica adicional.

## Qué leer después

- [Documentación de Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/) -
  fuente primaria sobre versiones, add-ons y límites.
- [EKS Best Practices Guides](https://docs.aws.amazon.com/eks/latest/best-practices/) -
  recomendaciones oficiales sobre red, seguridad, fiabilidad y coste.
- [EKS Workshop](https://www.eksworkshop.com/) - módulos interactivos gratuitos de AWS.
- [AWS Backup: copia de seguridad y restauración de EKS](https://docs.aws.amazon.com/aws-backup/latest/devguide/eks-backups.html) -
  documentación sobre la copia de seguridad del estado del clúster y de los volúmenes persistentes.
- [De Spot.io a Karpenter](../../../docs/articles/from_spot_io_to_karpenter/readme_RU.MD) -
  nuestro análisis de la migración de la gestión de nodos en producción.
