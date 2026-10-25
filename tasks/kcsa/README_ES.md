[Русская версия](README_RU.md) · [Eng version](README.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: Kubernetes and Cloud Native Security Associate - materiales de formación

Preparación completa para la certificación **Kubernetes and Cloud Native Security Associate (KCSA)**: un curso de autoaprendizaje y exámenes de prueba completos, todo en un solo lugar.

KCSA es una certificación de nivel associate, preprofesional y conceptual de CNCF y Linux Foundation sobre seguridad cloud native y Kubernetes. El curso ocupa su lugar en la trayectoria de aprendizaje KCNA (optional) → KCSA → CKA → CKS: KCSA explica los fundamentos y modelos de amenazas, CKA proporciona la base práctica obligatoria para CKS, y CKS desarrolla las security skills hands-on. No hay prerrequisitos formales; basta con comprender a nivel básico qué son `Pod`, `Deployment`, `Service` y `kubectl`.

## Qué contiene

| Parte | Ruta | Qué es |
|------|------|-----------|
| **Curso** | [`course/`](course/README_ES.md) | 20 capítulos de autoaprendizaje que cubren los 6 dominios oficiales de KCSA |
| **Exámenes de prueba** | [`mock/`](mock/README.md) | 2 exámenes de prueba completos de 60 preguntas en formato MCQ |

La práctica de KCSA consiste en preguntas multiple choice y exámenes de prueba, no en laboratorios. Ruta recomendada: leer los capítulos del curso en orden y luego realizar ambos exámenes de prueba con presión de tiempo similar a la del examen real.

## El curso

El curso ([`course/README_ES.md`](course/README_ES.md)) tiene 20 capítulos, cada uno publicado en 8 idiomas: inglés (`README.md`), ruso (`ru.md`, fuente canónica), español (`es.md`), francés (`fr.md`), alemán (`de.md`), georgiano (`ge.md`), chino tradicional (`tw.md`) y japonés (`jp.md`). Los capítulos se agrupan por los dominios oficiales de KCSA:

| Dominio | Peso |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

Los términos se recopilan en el [glosario](course/GLOSSARY_ES.md). Los capítulos 1-2 presentan el examen y la seguridad cloud native; el capítulo 20 recoge la estrategia final, la gestión del tiempo y una lista de comprobación.

## Exámenes de prueba

Dos exámenes de prueba completos ([`mock/`](mock/README.md)) simulan la experiencia real de KCSA:

- **Mock 01** ([`mock/01`](mock/01/README.md)) - 60 preguntas distribuidas según los dominios.
- **Mock 02** ([`mock/02`](mock/02/README.md)) - un conjunto independiente de 60 preguntas, con la misma distribución.

Realiza cada mock en una sesión closed-book de 90 minutos: sin documentación, búsquedas, notas, herramientas ni sitios externos. En la última verificación, la LF Multiple Choice FAQ indicaba una puntuación de aprobación del 75% o superior; confirma los requisitos actuales de registro de KCSA con la Linux Foundation antes de inscribirte.

## Formato del examen y versión del curso

KCSA es un examen multiple choice: 60 preguntas, 90 minutos, 75% para aprobar, sin tareas hands-on (verifica los parámetros actuales con la Linux Foundation antes de registrarte, ya que pueden cambiar). Los ejemplos del curso están orientados a Kubernetes `v1.36`. Los pesos actuales, las fuentes y los cambios del programa están registrados en la [política de versiones](VERSION_POLICY.md).

## Qué leer después

- [Documentación oficial de Kubernetes: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- El curso CKS es el siguiente paso para profundizar en hardening práctico e investigación.
