[Русская версия](README_RU.md) · [Eng version](README.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: guía práctica de autoaprendizaje sobre seguridad cloud native y Kubernetes

KCSA (Kubernetes and Cloud Native Security Associate) es una certificación de nivel associate, preprofesional y conceptual de CNCF y Linux Foundation sobre seguridad cloud native y Kubernetes. El curso ocupa su lugar en la trayectoria de aprendizaje KCNA (optional) → KCSA → CKA → CKS: KCSA explica los fundamentos y modelos de amenazas, CKA proporciona la base práctica obligatoria para CKS, y CKS desarrolla las security skills hands-on. No hay prerrequisitos formales; basta con comprender a nivel básico qué son `Pod`, `Deployment`, `Service` y `kubectl`.

> **Sobre los enlaces a CKA y CKS.** El archivo autónomo de KCSA no incluye los directorios de CKA y CKS. Por ello, en standalone-distribution los enlaces dentro del propio KCSA permanecen clicables, mientras que las cross-course references a CKA/CKS se publican como texto normal sin URL relativas. En monorepo-build se pueden generar como enlaces funcionales a cursos contiguos o como absolute URLs estables.

> **Formato del examen y versión de los ejemplos.** KCSA es un examen multiple choice. Según las reglas de Linux Foundation verificadas el 1 de septiembre de 2026, el examen MCQ (multiple choice question, pregunta de opción múltiple) estándar contiene 60 preguntas, dura 90 minutos y exige un 75% para aprobar; no hay tareas hands-on. Antes de registrarte, vuelve a comprobar los requisitos actuales de LF, ya que estos parámetros pueden cambiar. Los ejemplos del curso están orientados a Kubernetes `v1.36`. Los pesos actuales, las fuentes y los cambios del programa están registrados en la [política de versiones](../VERSION_POLICY.md).

## Cómo está organizado el curso

Cada tema es un directorio con un número y la fuente canónica rusa `ru.md`. Para cada capítulo también se han publicado traducciones: English `README.md`, Español `es.md`, Français `fr.md`, Deutsch `de.md`, ქართული `ge.md`, 繁體中文 `tw.md` y 日本語 `jp.md`. Los capítulos se agrupan por dominios de KCSA y se identifican por color:

- 🟦 Overview of Cloud Native Security - 14%
- 🟥 Kubernetes Cluster Component Security - 22%
- 🟩 Kubernetes Security Fundamentals - 22%
- 🟪 Kubernetes Threat Model - 16%
- 🟨 Platform Security - 16%
- 🟫 Compliance and Security Frameworks - 10%
- ⬜ introducción, fundamentos y preparación para el examen

La práctica de KCSA consiste en preguntas multiple choice y exámenes de prueba, no en laboratorios. Este archivo contiene una ruta de preparación unificada y la navegación del examen. Los términos se recopilan en el [glosario](GLOSSARY_ES.md).

## Programa oficial del examen

| Dominio | Peso |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

## Contenido

### Parte 0. Introducción y fundamentos ⬜

1. [Introducción: examen KCSA, formato, lugar en la escalera de certificaciones, versiones](01/es.md)
2. [Cloud native y por qué importa la seguridad](02/es.md)

### Parte 1. Overview of Cloud Native Security - 14% 🟦

3. [Las 4C de la seguridad en la nube: Cloud, Cluster, Container, Code](03/es.md)
4. [Seguridad del proveedor de nube y de la infraestructura](04/es.md)
5. [Controles, frameworks y técnicas de aislamiento](05/es.md)
6. [Seguridad de artefactos, imágenes y código](06/es.md)

### Parte 2. Kubernetes Cluster Component Security - 22% 🟥

7. [Seguridad del control plane: API Server, Controller Manager, Scheduler, Etcd](07/es.md)
8. [Seguridad del nodo: Kubelet, Container Runtime, KubeProxy](08/es.md)
9. [Pod, red de contenedores, storage y seguridad del cliente](09/es.md)

### Parte 3. Kubernetes Security Fundamentals - 22% 🟩

10. [Autenticación y autorización](10/es.md)
11. [Pod Security Standards y Pod Security Admission](11/es.md)
12. [Secrets](12/es.md)
13. [Network Policy, aislamiento y segmentación](13/es.md)
14. [Audit Logging](14/es.md)

### Parte 4. Kubernetes Threat Model - 16% 🟪

15. [Límites de confianza, flujos de datos y modelo de amenazas](15/es.md)
16. [Categorías de amenazas de Kubernetes](16/es.md)

### Parte 5. Platform Security - 16% 🟨

17. [Supply chain, registros de imágenes y admission control](17/es.md)
18. [Observability, PKI, connectivity y service mesh](18/es.md)

### Parte 6. Compliance and Security Frameworks - 10% 🟫

19. [Cumplimiento y frameworks de seguridad](19/es.md)

### Parte 7. Preparación para el examen ⬜

20. [Examen KCSA: estrategia, gestión del tiempo, lista de comprobación](20/es.md)

## Práctica

- 📝 [Exámenes de prueba de KCSA](../mock) - están disponibles Mock 01 y Mock 02 en inglés en formato MCQ para prácticas independientes. Las preguntas se distribuyen según los pesos de los dominios; no se crean laboratorios terragrunt/bats para KCSA.

Comienza por los capítulos 01-02 y luego recorre los dominios en orden. La táctica final y la lista de comprobación se reúnen en el [capítulo 20](20/es.md).

## Qué leer después

- [Documentación oficial de Kubernetes: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- El curso CKS es el siguiente paso para profundizar en hardening práctico e investigación.
