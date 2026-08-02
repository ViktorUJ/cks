[Русская версия](README_RU.md) · [Eng version](README.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# CKA + CKAD: curso práctico autodidacta de Kubernetes

Curso práctico conjunto para preparar a la vez dos certificaciones de la CNCF y la
Linux Foundation:

- **CKA** (Certified Kubernetes Administrator) - administración del clúster:
  instalación, mantenimiento, red, almacenamiento, seguridad, troubleshooting.
- **CKAD** (Certified Kubernetes Application Developer) - desarrollo y ejecución
  de aplicaciones en Kubernetes: cargas de trabajo, configuración,
  observabilidad, servicios.

Los exámenes se solapan bastante (cargas de trabajo, servicios, configuración,
almacenamiento, observabilidad), por eso estudiarlos juntos es más eficiente que
por separado. El núcleo común se recorre una sola vez y lo específico de cada
examen queda en partes aparte. El curso está ligado a los laboratorios de `tasks/cka/labs`.

> **Versión de Kubernetes.** El curso está orientado a la versión actual de los
> exámenes - Kubernetes `v1.35` (programas de CKA y CKAD 2025-2026). Ambos
> exámenes son prácticos, en un clúster real y desde la línea de comandos: CKA - 2
> horas, CKAD - 2 horas, nota de aprobado 66%.

## Cómo está organizado el curso

Cada tema es una carpeta con número. Dentro están los archivos localizados. El
idioma principal es el ruso (`ru.md`) y a partir de él se hacen las traducciones:
inglés (`README.md`), español (`es.md`), francés (`fr.md`), alemán (`de.md`) y
georgiano (`ge.md`). El selector de idioma está en la primera línea de cada archivo.

Cada capítulo está marcado según el examen al que corresponde:

- 🟦 **CKA** - solo para el administrador
- 🟩 **CKAD** - solo para el desarrollador
- 🟪 **CKA + CKAD** - tema común para ambos exámenes

Al final del curso hay dos guías independientes que reúnen los capítulos y los
laboratorios de cada examen concreto:

- [Programa y laboratorios para CKA](CKA_ES.md)
- [Programa y laboratorios para CKAD](CKAD_ES.md)

Todos los términos del curso están recogidos en una referencia única:

- [Glosario del curso](GLOSSARY_ES.md) - todos los términos por capítulos con enlaces

## Programas oficiales de los exámenes

CKA (dominios y peso):

| Dominio | Peso |
|-------|-----|
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Storage | 10% |
| Services & Networking | 20% |
| Troubleshooting | 30% |

CKAD (dominios y peso):

| Dominio | Peso |
|-------|-----|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services and Networking | 20% |

## Índice

### Parte 0. Fundamentos para principiantes (opcional) 🟪 CKA + CKAD

Parte preparatoria para quienes llegan sin una base sólida en redes, DNS, TLS,
contenedores, Linux y YAML. Si dominas estos temas con soltura, puedes pasar
directamente a la Parte 1. Esta parte no tiene laboratorios propios: es el
fundamento sobre el que se apoyan los demás capítulos (las habilidades de 0.5-0.7
se aplican directamente en los laboratorios de nodos y de red).

- 0.1. [Redes desde cero: IP, puertos, CIDR y NAT](00-1-net/es.md)
- 0.2. [DNS desde cero: cómo los nombres se convierten en direcciones](00-2-dns/es.md)
- 0.3. [TLS y certificados desde cero: HTTPS, claves y autoridades de certificación](00-3-tls/es.md)
- 0.4. [Contenedores y Docker desde cero: imágenes, capas, registros y runtime](00-4-containers/es.md)
- 0.5. [Linux y las herramientas del nodo desde cero: SSH, sudo, systemd, logs, archivos](00-5-linux/es.md)
- 0.6. [YAML desde cero: indentación, listas, diccionarios y manifiestos](00-6-yaml/es.md)
- 0.7. [La red de Linux por dentro: network namespaces, veth y enrutamiento](00-7-netns/es.md)
- 0.8. [vim en 15 minutos: sobrevivir y configurarlo para YAML](00-8-vim/es.md)

### Parte 1. Fundamentos de Kubernetes 🟪 CKA + CKAD

1. [Introducción: Kubernetes, los exámenes CKA y CKAD y la estructura del curso](01/es.md)
2. [Arquitectura de Kubernetes: control plane y nodos worker](02/es.md)
3. [Trabajar con kubectl: enfoques imperativo y declarativo](03/es.md)
4. [Pods: ciclo de vida, creación y configuración](04/es.md)
5. [ReplicaSet y Deployment](05/es.md)
6. [Namespaces, labels, selectors y annotations](06/es.md)
7. [Services: ClusterIP, NodePort, LoadBalancer, Endpoints](07/es.md)

### Parte 2. Cargas de trabajo y planificación 🟪 CKA + CKAD

8. [Deployment: rolling update y rollback](08/es.md)
9. [Estrategias de despliegue: blue/green y canary](09/es.md) 🟩 CKAD
10. [Jobs y CronJobs](10/es.md)
11. [DaemonSet y StatefulSet](11/es.md)
12. [Planificación de Pods: nodeName, nodeSelector, affinity](12/es.md)
13. [Taints y tolerations](13/es.md)
14. [Recursos: requests, limits, LimitRange, ResourceQuota](14/es.md)
15. [Static Pods, PriorityClass y varios planificadores](15/es.md)
16. [Autoescalado de cargas: HPA](16/es.md)

### Parte 3. Configuración y seguridad de las aplicaciones 🟪 CKA + CKAD

17. [Comandos, argumentos y variables de entorno](17/es.md)
18. [ConfigMap](18/es.md)
19. [Secret](19/es.md)
20. [SecurityContext y capabilities](20/es.md)
21. [ServiceAccount; autenticación, autorización, admission](21/es.md)

### Parte 4. Diseño y construcción de aplicaciones 🟩 CKAD

22. [Pods multi-container: sidecar, adapter, ambassador, init](22/es.md)
23. [Imágenes de contenedores: construcción, Dockerfile, optimización](23/es.md)
24. [Volúmenes para aplicaciones: emptyDir y volúmenes efímeros](24/es.md)

### Parte 5. Almacenamiento de datos 🟪 CKA + CKAD

25. [Volumes, PersistentVolume y PersistentVolumeClaim](25/es.md)
26. [StorageClass, aprovisionamiento dinámico y almacenamiento en StatefulSet](26/es.md)

### Parte 6. Observabilidad y mantenimiento 🟪 CKA + CKAD

27. [Comprobaciones de estado: liveness, readiness y startup probes](27/es.md)
28. [Logging y monitorización: logs, metrics-server, kubectl top](28/es.md)
29. [Depuración de aplicaciones y obsolescencia de las API](29/es.md)

### Parte 7. Servicios y red 🟪 CKA + CKAD

30. [El modelo de red de Kubernetes, la red de pods y la CNI](30/es.md)
31. [Service por dentro, DNS y CoreDNS](31/es.md)
32. [Ingress y controladores Ingress](32/es.md)
33. [Gateway API](33/es.md)
34. [NetworkPolicy](34/es.md)

### Parte 8. Arquitectura del clúster, instalación y configuración 🟦 CKA

35. [Instalación del clúster con kubeadm](35/es.md)
- 35A. [Alta disponibilidad (HA): varios nodos de control plane, topologías de etcd y balanceador](35-2-ha/es.md) 🟦 CKA
- 35B. [Diseño y sizing del clúster: infraestructura, topología, IaC](35-3-design/es.md) 🟦 CKA
36. [Actualización del clúster (lifecycle)](36/es.md)
37. [Backup y restauración de etcd](37/es.md)
38. [RBAC: Role, ClusterRole y bindings](38/es.md)
39. [Certificados TLS, kubeconfig y la CSR API](39/es.md)
40. [Interfaces de extensión: CNI, CSI, CRI](40/es.md)
41. [CRD y operadores](41/es.md)
42. [Helm](42/es.md)
43. [Kustomize](43/es.md)

### Parte 9. Troubleshooting 🟦 CKA

44. [Depuración de fallos de aplicaciones](44/es.md)
45. [Depuración del control plane y de los nodos worker](45/es.md)
46. [Depuración de servicios y de la red](46/es.md)

### Parte 10. Preparación para los exámenes

47. [Examen CKAD: formato, gestión del tiempo, JSONPath y productividad con kubectl](47/es.md) 🟩 CKAD
48. [Examen CKA: formato, gestión del tiempo y estrategia](48/es.md) 🟦 CKA

## Práctica

- 🧪 [Laboratorios](../labs) - 25 laboratorios en estilo examen con comprobación automática `check_result`
- 🧪 [Exámenes de simulación CKA](../mock) - exámenes de simulación del CKA con cronómetro (multiclúster, SSH, pesos de las tareas)
- 🧪 [Exámenes de simulación CKAD](../../ckad/mock) - exámenes de simulación del CKAD con cronómetro

### Qué laboratorios elegir

Los laboratorios de nuestra plataforma son la práctica principal del curso y se ajustan
mejor a la preparación del examen: son compuestos (varias tareas enlazadas en un mismo
entorno, como en el examen real), se despliegan en un clúster completo con acceso a los
nodos por SSH, se verifican automáticamente con `check_result`, y los exámenes de
simulación corren con cronómetro y con pesos de las tareas. Es esto lo que reproduce las
condiciones del CKA y del CKAD.

Los escenarios de Killercoda en los capítulos son un **arranque rápido**: se abren en el
navegador, no requieren instalación y son gratuitos. Van bien justo después de leer un
capítulo, para afianzar un tema concreto, o para practicar cuando no hay un clúster a mano.
Pero son atómicos (un escenario, una tarea), están solo en inglés y no ofrecen ni trabajo
en los nodos ni ensayo con cronómetro.

Combinación recomendada: Killercoda para afianzar rápido un tema; nuestros laboratorios y
los exámenes de simulación para preparar el examen en sí.

## Qué leer después

Este curso está centrado en la preparación de los exámenes: cada capítulo está ligado a un
dominio del CKA o del CKAD. La filosofía arquitectónica, la historia del proyecto y una
panorámica del ecosistema (service mesh, GitOps, observabilidad) no se incluyen aquí de forma
deliberada: son temas aparte que no se preguntan en el examen. Si quieres ir más ancho y
más profundo:

- **Kubernetes: Up and Running** (Burns, Beda, Hightower, O'Reilly) - por qué apareció
  Kubernetes, la evolución desde Borg, los patrones arquitectónicos de las aplicaciones.
- **The Kubernetes Book** (Nigel Poulton) - introducción panorámica con énfasis en entender
  la plataforma en su conjunto; se actualiza cada año.
- [Documentación oficial de Kubernetes](https://kubernetes.io/docs/) - la fuente primaria,
  su uso está permitido en el propio examen.
- [CNCF Landscape](https://landscape.cncf.io/) - mapa del ecosistema cloud native.
