[Русская версия](APPENDIX_K8S_136_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_136_SECURITY_DELTA.md) · [Version française](APPENDIX_K8S_136_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_136_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_136_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_136_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_136_SECURITY_DELTA_JP.md)

# Apéndice. Kubernetes v1.36 Delta de seguridad

> Marcador: PRODUCTION / VERSION-SENSITIVE. La inclusión en este apéndice no significa que un tema pertenezca al grupo de exámenes CKS actual. La instantánea del examen oficial del curso (ver [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) utiliza Kubernetes v1.35, mientras que la base de capacitación del curso es v1.36. Verifique cada elemento antes de tratarlo como un dato de examen: algunos cambios son importantes en la producción, pero el plan de estudios puede retrasarse con respecto a una versión menor.

Este apéndice complementa los capítulos principales del curso. Reúne los cambios Kubernetes v1.36 relevantes para la seguridad en un solo lugar, en lugar de distribuirlos en los 33 capítulos o confundir la actualidad de la producción con la fidelidad del examen.

## 1. User Namespaces GA

**Relevancia de CKS:** Deep Dive / Producción.

- `spec.hostUsers: false` coloca un Pod en un espacio de nombres de usuario: el usuario root dentro del contenedor se asigna a un UID sin privilegios en el host.
- Este es un límite de defensa en profundidad adicional, no un reemplazo de los controles existentes (capacidades, seccomp, AppArmor, RBAC). Ver [capítulo 03](03/es.md).
- Solo Linux; consulte el capítulo 03 para conocer limitaciones específicas (volúmenes en bloque sin formato, NFS).

## 2. Fine-Grained Kubelet API Authorization GA

**Relevancia de CKS:** Núcleo (usado en el [capítulo 05](05/es.md)).

- Anteriormente, `nodes/proxy` era el único subrecurso para casi todas las rutas kubelet API, incluidas las aparentemente seguras `/metrics` y las peligrosas `/exec`.
- GA presenta subrecursos independientes: `nodes/stats`, `nodes/metrics`, `nodes/log`, `nodes/pods`, `nodes/healthz`, `nodes/configz`, `nodes/spec`, `nodes/checkpoint`.
- Para `/pods`, `/runningPods/`, `/healthz` y `/configz`, kubelet primero comprueba el subrecurso detallado y recurre a `nodes/proxy` en caso de denegación por compatibilidad con versiones anteriores.
- **Por qué esto es importante para la revisión de seguridad:** se puede abusar de un agente de monitoreo con `nodes/proxy GET` a través de la semántica de WebSocket kubelet API para RCE en cualquier contenedor del nodo. `GET` se asigna a RBAC `get`, pero `kubelet` no verifica por separado `create` para la operación de escritura posterior. Ver el capítulo 05 y su bloque “Perspectiva del atacante”.
- Fuente: [Blog Kubernetes v1.36 - Graduados Fine-Grained Kubelet API Authorization en GA](https://kubernetes.io/blog/2026/04/24/kubernetes-v1-36-fine-grained-kubelet-authorization-ga/).

## 3. Política de admisión de mutación/validación GA y Manifest-Based Admission Control (alfa)

**Relevancia de CKS:** Núcleo para VAP (usado en el [capítulo 20](20/es.md)); Manifest-Based Admission Control es Deep Dive (alfa, deshabilitado de forma predeterminada).

- La capa de políticas nativa basada en CEL reduce la necesidad de un webhook de admisión adicional para muchas reglas comunes. No reemplaza a Kyverno/Gatekeeper para generación, mutación de objetos complejos o verificación de imágenes de la cadena de suministro (consulte los capítulos 20 y 26).
- Manifest-Based Admission Control (v1.36, alfa) admite objetos de admisión estáticos: todos los objetos requieren un sufijo de nombre `.static.k8s.io`; `paramRef` en los bindings está prohibido; Los webhooks estáticos solo permiten `clientConfig.url`, no `clientConfig.service`. Un manifiesto estático no válido puede impedir que el servidor API esté listo.

## 4. Service.spec.externalIPs formalmente obsoleto

**Relevancia de CKS:** Producción/Deep Dive.

- `externalIPs` está formalmente obsoleto en Kubernetes v1.36. Se espera que una futura versión menor elimine el comportamiento de kube-proxy y su requisito de soporte de los criterios de conformidad.
- **Motivo de seguridad:** el campo ha sido un riesgo durante mucho tiempo: un usuario sin privilegios capaz de crear/editar Services puede reclamar una IP arbitraria sin validación de propiedad. Esto crea un riesgo MITM en clústeres multiinquilino y se relaciona directamente con **CVE-2020-8554** (hombre en el medio que usa LoadBalancer o IP externas).
- **Alternativa actual:** un LoadBalancer Service a través de un controlador local o en la nube, o Gateway API en lugar del uso directo de `externalIPs`.
- Fuentes: [Blog Kubernetes v1.36: obsolescencia y eliminación de IP externas Service](https://v1-36.docs.kubernetes.io/blog/2026/05/14/kubernetes-v1-36-deprecation-and-removal-of-service-externalips/), [aviso CVE-2020-8554](https://discuss.kubernetes.io/t/security-advisory-cve-2020-8554-man-in-the-middle-using-loadbalancer-or-externalips/14003).

## 5. Volumen de gitRepo permanentemente deshabilitado

**Relevancia de CKS:** Producción/Deep Dive (lección sobre cadena de suministro/fuente mutable).

- El tipo de volumen `gitRepo` está **permanentemente deshabilitado** en Kubernetes v1.36 y no se puede volver a habilitar mediante una feature gate. El Kubernetes API todavía acepta un Pod con un volumen `gitRepo`, pero kubelet se niega a iniciarlo y devuelve un error.
- **Motivo de seguridad:** el controlador de volumen `gitRepo` ejecutó `git clone` dentro de un proceso administrado por kubelet en el nodo sin suficiente aislamiento. Por lo tanto, un repositorio Git especialmente diseñado podría provocar RCE a través de un hook de escritura durante `git clone`.
- **Lección sobre la cadena de suministro:** un tipo de volumen que ejecuta código externo arbitrario durante el aprovisionamiento (incluso “solo” `git clone`) tiene la misma clase de riesgo que una etiqueta de imagen mutable sin fijación por digest. La confianza se transfiere en tiempo de ejecución a una fuente externa no completamente controlada en lugar de verificarse de antemano.
- Fuentes: [Notas de la versión de AWS EKS: eliminación del volumen de gitRepo](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html), [kubernetes/kubernetes#125983: eliminación del tipo de volumen de gitRepo](https://github.com/kubernetes/kubernetes/issues/125983).

## 6. Cambios en la etiqueta de volumen SELinux (nuevo etiquetado en el tiempo de montaje)

**Relevancia de CKS:** Deep Dive (usado en el [capítulo 18](18/es.md)).

- El tiempo de ejecución del contenedor, en lugar de kubelet, realiza el reetiquetado recursivo de SELinux.
- Para PVC con un modo de acceso distinto de `ReadWriteOncePod`, el reetiquetado basado en montaje (`-o context=`) requiere la feature gate `SELinuxMount` (deshabilitada de forma predeterminada en v1.36) y `CSIDriver.spec.seLinuxMount: true` en el controlador CSI particular. De lo contrario, se utiliza un reetiquetado recursivo más lento.
- Consulte el capítulo 18 para conocer la distinción entre reetiquetado recursivo y `MountOption`.

## Cómo utilizar este apéndice

Antes de citar un elemento como “hecho actual” en una conferencia o preparación de un examen:

1. Verifique `checked_at` en [`metadata/tool-compatibility.yaml`](../metadata/tool-compatibility.yaml) y [`metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml).
2. Compruebe si la característica específica está en el plan de estudios actual (PDF `CKS_Curriculum`). No asuma que producción actual significa automáticamente relevante para el examen.
3. Si un elemento se utiliza como material *básico* en un laboratorio o capítulo (consulte [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml)), mantenga sincronizada su redacción aquí y en ese capítulo.

---
[Contenido](README_ES.md)
