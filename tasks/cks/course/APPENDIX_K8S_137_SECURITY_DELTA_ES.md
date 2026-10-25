[Русская версия](APPENDIX_K8S_137_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_137_SECURITY_DELTA.md) · [Version française](APPENDIX_K8S_137_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_137_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_137_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_137_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_137_SECURITY_DELTA_JP.md)

# Apéndice. Kubernetes v1.37 Delta de seguridad

> Marcador: PRODUCTION / VERSION-SENSITIVE. La inclusión en este apéndice no significa que un tema pertenezca al grupo de exámenes CKS actual. La instantánea del examen oficial del curso (ver [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) utiliza Kubernetes v1.35, mientras que la base de capacitación del curso es v1.36. La última versión estable ascendente es Kubernetes v1.37. No promueva una característica de este apéndice en 🎯 CKS Core sin una confirmación por separado de su relevancia para el examen o el plan de estudios.

Este apéndice recopila cambios relevantes para la seguridad en Kubernetes v1.37. Los capítulos y laboratorios principales permanecen vinculados al contexto de examen/formación verificado; este documento registra el conjunto de cambios actuales para producción.

## 1. Manifest-Based Admission Control: Beta y habilitado por defecto

**Relevancia de CKS:** Deep Dive / Producción / Sensible a la versión.

En la línea base de entrenamiento v1.36, Manifest-Based Admission Control permanece alfa y deshabilitado de forma predeterminada. En v1.37 se convirtió en Beta, con la feature gate `ManifestBasedAdmissionControlConfig` habilitada de forma predeterminada. El servidor API carga webhooks y políticas de admisión basadas en CEL desde archivos estáticos: están activos en el inicio del servidor API, no dependen de etcd para almacenar la configuración de admisión en sí y pueden proteger los recursos de admisión basados ​​en API contra modificaciones.

Esto cierra la brecha de arranque y autoprotección, pero aumenta el riesgo operativo: un manifiesto no válido en la carga inicial impide que el servidor API esté listo. En HA, cada servidor API lee sus propios archivos, lo que requiere una entrega atómica y consistente.

Fuente: [Manifest-Based Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/manifest-admission-control/).

## 2. SELinuxMount: GA y habilitado de forma predeterminada

**Relevancia de CKS:** Deep Dive / Producción / Sensible a la versión.

En v1.36, `SELinuxMount` estaba deshabilitado de forma predeterminada; en v1.37 es GA y está habilitado de forma predeterminada. Para los PVC CSI elegibles, Kubernetes utiliza una opción de montaje de etiqueta SELinux en lugar de un reetiquetado recursivo más lento solo cuando se cumplen `CSIDriver.spec.seLinuxMount: true` y todas las demás condiciones de elegibilidad. Esto cambia el comportamiento: con un volumen compartido en un nodo, un Pod con una etiqueta SELinux incompatible puede permanecer en `ContainerCreating`.

Antes de actualizar un clúster habilitado para SELinux, habilite `SELinuxWarningController`, resuelva los conflictos detectados y observe su métrica. Una carga de trabajo que comparte intencionalmente un volumen entre diferentes etiquetas puede conservar el comportamiento anterior mediante:

```yaml
spec:
  securityContext:
    seLinuxChangePolicy: Recursive
```

Fuente: [Configurar un contexto de seguridad para un Pod o contenedor](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).

## 3. Pod Certificates y ClusterTrustBundles: Estable

**Relevancia de CKS:** Deep Dive / Producción.

Un JWT de ServiceAccount sigue siendo una credencial de portador: el token está limitado por su vigencia, la vinculación al objeto y la audiencia, pero se presenta al otro extremo. Pod Certificates añade credenciales X.509 para cargas de trabajo, con clave privada y un modelo de prueba de posesión. Kubelet crea un `PodCertificateRequest`, obtiene una cadena de certificados del firmante y rota la credencial. El certificado y el paquete de confianza se entregan mediante volúmenes proyectados; `ClusterTrustBundle` proporciona los anclajes de confianza.

El firmante sigue siendo conectable. Kubernetes v1.37 no incluye un firmante central universal listo para usar para SPIFFE o todas las cargas de trabajo. Por lo tanto, Pod Certificates no reemplaza automáticamente los JWT ServiceAccount ni hace innecesarios los mecanismos de identidad Istio/SPIFFE existentes.

Fuente: [Kubernetes v1.37: Pod Certificates y paquetes de confianza de clúster](https://kubernetes.io/blog/2026/08/28/kubernetes-v1-37-pod-certificates-and-cluster-trust-bundles/).

## 4. KubeletInUserNamespace: ruta del nodo beta sin raíz

**Relevancia de CKS:** Deep Dive / Producción.

`KubeletInUserNamespace` es Beta en v1.37. Cuando está habilitado, kubelet, el tiempo de ejecución CRI/OCI, CNI y kube-proxy se pueden ejecutar como un usuario del host sin privilegios root dentro de un espacio de nombres de usuario Linux. Esta arquitectura de nodo sin raíz reduce el impacto de los componentes del nodo comprometidos y puede requerir comprobaciones de compatibilidad CNI y CSI.

No confunda esto con `spec.hostUsers: false`, que crea un espacio de nombres de usuario para Pod mientras los componentes del nodo aún pueden ejecutarse como raíz del host. Estos son límites de seguridad diferentes y compatibles. Habilitar la feature gate no convierte automáticamente los nodos raíz existentes al modo sin raíz.

Fuente: [Kubernetes v1.37: KubeletInUserNamespace se gradúa en Beta](https://kubernetes.io/blog/2026/09/04/kubernetes-v1-37-rootless-beta/).

## 5. Eliminar recursos ilegibles/corruptos: ruta de recuperación insegura

**Relevancia de CKS:** Producción / Recuperación / Operación peligrosa.

En v1.37, la feature gate Beta, habilitada de forma predeterminada, `AllowUnsafeMalformedObjectDeletion`, permite la eliminación insegura de un objeto que no se puede leer desde el almacenamiento debido a una falla de descifrado o corrupción de descodificación. La solicitud de eliminación utiliza `ignoreStoreReadErrorWithClusterBreakingPotential`; Se requieren permisos tanto `delete` como `unsafe-delete-ignore-read-errors`.

> ⚠️ Este es un mecanismo de recuperación de último recurso con potencial para inutilizar el clúster. Omite las comprobaciones de finalizador y condiciones previas, no reemplaza la retención de claves de cifrado antiguas ni la copia de seguridad/restauración, y no es una forma normal de corregir un error de EncryptionConfiguration.

Fuente: [Kubernetes API Conceptos: Forzar eliminación](https://kubernetes.io/docs/reference/using-api/api-concepts/#force-deletion).

## 6. StorageVersionMigration: GA y habilitado de forma predeterminada

**Relevancia de CKS:** Producción / Deep Dive.

En v1.37, el `storagemigration.k8s.io/v1` API integrado y el controlador pasaron a ser GA y se habilitaron de forma predeterminada. Storage Version Migration reescribe de forma declarativa los objetos API persistentes en la versión de almacenamiento actual. Esto es útil para la migración de la versión de almacenamiento API y puede formar parte de un nuevo cifrado controlado después de un cambio de clave o proveedor de cifrado.

SVM no es lo mismo que la rotación de proveedores de cifrado: el orden de los proveedores, el descifrado de datos antiguos, las copias de seguridad y la estrategia de restauración siguen siendo responsabilidades separadas del operador.

Fuente: [Kubernetes v1.37: Storage Version Migration habilitado de forma predeterminada](https://kubernetes.io/blog/2026/08/31/kubernetes-v1-37-storage-version-migration-ga/).

---
[Contenido](README_ES.md)
