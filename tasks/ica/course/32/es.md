[RU version](ru.md) · [Eng version](en.md)

# Capítulo 32. El examen ICA: formato y preparación

> **El capítulo final.** A lo largo del curso preparamos tanto la teoría como la práctica para la
> certificación **Istio Certified Associate (ICA)**. Aquí reunimos cómo está estructurado el examen,
> cómo prepararse para él y dónde conseguir ensayos: nuestros exámenes de práctica (mocks).

## 32.1. Qué es el examen

**ICA (Istio Certified Associate)** es una certificación de la CNCF y la Linux Foundation
(originalmente desarrollada por Tetrate) que confirma tu capacidad de trabajar con Istio. El examen es
**online, supervisado (proctored)** y de formato híbrido: **tareas basadas en el rendimiento
(performance-based) más preguntas de opción múltiple**. En la parte práctica te dan acceso a un
clúster y se te pide resolver tareas a mano: configurar enrutamiento, habilitar mTLS, escribir una
política, encontrar y corregir un problema; en la parte teórica comprueban tu comprensión de los
principios y la terminología. La duración es de **2 horas**, y el entorno se ha actualizado a **Istio
v1.26**.

Durante el examen se permite el acceso a la documentación oficial (istio.io y sus subdominios; por lo
general también el blog de Istio y la documentación de Kubernetes: comprueba la lista actual de
recursos permitidos en el Candidate Handbook). Esto importa: nadie te obliga a recordar de memoria
todos los campos YAML, pero necesitas encontrar y aplicar **rápidamente** lo que necesitas.

> Los detalles exactos (duración, puntuación de aprobado, número de tareas, reglas de repetición)
> cambian con el tiempo y dependen de la versión del programa. Consulta siempre la página oficial:
> [Istio Certified Associate (ICA)](https://training.linuxfoundation.org/certification/istio-certified-associate-ica).

## 32.2. Los dominios y en qué centrarse

El examen se construye en torno a dominios ponderados. El desglose actual (tras la actualización del
programa en agosto de 2025):

| Dominio | Peso | Capítulos del curso |
|---------|------|---------------------|
| Traffic Management | 35% | 5-12 |
| Securing Workloads | 25% | 9, 13-16 |
| Installation, Upgrade & Configuration | 20% | 2-4, 22 (ambient) |
| Troubleshooting | 20% | 24, 30 |

Lo importante que hay que saber del nuevo programa:

- **Ya no hay un dominio "Advanced Scenarios" separado**: sus temas se redistribuyeron: la instalación
  de ambient pasó a Installation, el egress y la conexión a servicios externos a Traffic Management.
- **Installation creció al 20%** y ahora incluye explícitamente la instalación **en modo sidecar y en
  modo ambient**, la personalización y la actualización (canary/in-place).
- **Traffic Management incluye egress, ingress, resiliencia** (circuit breaking, failover, outlier
  detection, timeouts, reintentos) **e inyección de fallos (fault injection)**.
- **Securing Workloads**: autorización, autenticación (mTLS, JWT) y **asegurar el tráfico del borde
  con TLS**.
- **Troubleshooting**: configuración, el control plane y el data plane.

La conclusión: **entrena la gestión del tráfico lo máximo posible** (Gateway, VirtualService,
DestinationRule, enrutamiento, resiliencia, egress, fault injection): es el dominio más grande (35%).
Después las prioridades quedan casi a la par: seguridad (25%), instalación/actualización y
troubleshooting (20% cada uno): no te saltes la instalación ni la depuración, su peso ha crecido
notablemente.

## 32.3. Consejos prácticos

La experiencia de CKA/CKS se transfiere directamente:

- **Alias y autocompletado.** Configura `alias k=kubectl`, habilita el completado para `kubectl` e
  `istioctl`: ahorra tiempo en cada tarea.
- **Comprueba el contexto.** Verifica siempre en qué clúster y namespace estás trabajando
  (`kubectl config current-context`), especialmente si hay muchas tareas.
- **Lee la tarea literalmente.** Los nombres exactos de los recursos, el namespace, los puertos, las
  versiones: un error en el nombre de un subset o en un selector y la regla no funcionará (capítulo
  5).
- **Verifica el resultado.** Tras configurar, ejecuta `curl` desde un pod, mira los códigos y las
  cabeceras: asegúrate de que el tráfico realmente va a donde debe.
- **`istioctl analyze` es tu amigo.** Detecta rápidamente errores de configuración (capítulo 24). Ante
  un problema: `proxy-status` (¿SYNCED?) y `proxy-config`.
- **Gestión del tiempo.** No te atasques en una sola tarea. Salta una difícil, vuelve más tarde: como
  en CKA.
- **Documentación a mano.** Sabe de antemano dónde en istio.io están los ejemplos de Gateway,
  VirtualService, PeerAuthentication: durante el examen copiarás de ahí y editarás.

## 32.4. Exámenes de práctica (mocks)

La mejor preparación es hacer exámenes realistas contra el reloj. Este repositorio tiene **dos
exámenes de práctica** que imitan el formato ICA:

- **Mock 01**: 17 tareas sobre los temas básicos: instalación, Gateway/VirtualService,
  AuthorizationPolicy, gestión de la inyección.
  [tasks/ica/mock/01](../../mock/01/README.MD)
- **Mock 02**: 16 tareas sobre patrones avanzados: una actualización canary con el operador,
  instalación vía Helm, un egress gateway, balanceo a nivel de puerto, fault injection, autorización
  cross-namespace.
  [tasks/ica/mock/02](../../mock/02/README.MD)

Una descripción general del entorno, los comandos (`check_result`, `time_left`, `hosts`) y consejos:
en el README raíz de la infraestructura: [tasks/ica/README.MD](../../README.MD).

Cómo usar los mocks:

1. Repasa los capítulos y labs relevantes del tema.
2. Ejecuta el mock **contra el reloj**, como un examen real, sin pistas.
3. Comprueba tu trabajo con `check_result`, revisa los errores contra las soluciones.
4. Repite hasta que entres cómodamente dentro del tiempo con un resultado del **70%+**.

Los mocks entrenan la parte **práctica** del examen. Pero recuerda que el formato es híbrido: también
hay preguntas de opción múltiple sobre la comprensión de los principios y la terminología. Así que
además de los mocks, repasa la **teoría** por capítulos (qué hace cada recurso, cómo funcionan mTLS,
xDS, el balanceo por localidad): se prueban tanto el "sé hacerlo a mano" como el "entiendo por qué".

## 32.5. Cómo prepararse con este curso

La ruta recomendada:

1. **Parte 1 (capítulos 1-24)**: lo básico y todos los dominios del examen. Refuerza cada capítulo con
   un lab (🧪).
2. **Los mocks** (sección 32.4): ejecútalos después de la Parte 1, contra el reloj.
3. **Parte 2 (capítulos 25-31)**: buenas prácticas para el trabajo real. No obligatorias para el
   examen en sí, pero te convierten en un ingeniero que entiende Istio en producción, no solo en uno
   que aprueba un test.

## 32.6. Resumen

- ICA es un examen online, supervisado, de formato híbrido: tareas prácticas en un clúster más
  preguntas de opción múltiple; se permite el acceso a la documentación de istio.io, la duración es de
  2 horas, el entorno es v1.26.
- Los dominios actuales (a agosto de 2025): **Traffic Management 35%**, Securing Workloads 25%,
  Installation/Upgrade/Config 20%, Troubleshooting 20%; ya no hay un dominio "Advanced Scenarios".
- Entrena la gestión del tráfico lo máximo posible, pero no te saltes la instalación ni el
  troubleshooting: su peso ha crecido al 20%.
- Traslada los hábitos de CKA/CKS: alias, autocompletado, comprobar el contexto, leer las tareas
  literalmente, verificar el resultado, gestión del tiempo.
- Ejecuta **mock 01 y mock 02** contra el reloj para practicar, y repasa la teoría por capítulos (para
  la parte de opción múltiple); apunta a un 70%+ estable.
- Comprueba la logística y las reglas exactas (puntuación de aprobado, número de preguntas, recursos
  permitidos) en la página oficial de ICA.

---

Con esto concluye el curso. Has pasado de la idea de una malla de servicios a la operación en
producción de Istio: gestión del tráfico, resiliencia, seguridad, observabilidad, escenarios
avanzados, troubleshooting, migraciones reales, hardening, y la preparación para el examen. Vuelve a
los capítulos, labs y mocks cuando lo necesites. Suerte con el ICA y con Istio en batalla.

[Índice](../README_ES.md) · [Capítulo 31](../31/es.md)
