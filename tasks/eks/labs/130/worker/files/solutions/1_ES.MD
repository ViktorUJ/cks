[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 130 - solución de referencia (ECR y supply chain)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. La CLI de AWS ya
está configurada para la cuenta correspondiente mediante el rol de la instancia (no hace
falta un `aws configure` adicional), y kubectl para el clúster del laboratorio. En lugar de
`docker` usamos `podman` (ya instalado en el worker).

Definamos el account id y la dirección del registro privado una sola vez:

```bash
export AWS_REGION=eu-central-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "$ECR_HOST"
```

## Tarea 1. Repositorio con tags IMMUTABLE y scanOnPush

```bash
aws ecr create-repository \
  --repository-name eks-lab130/app \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --region "$AWS_REGION"

aws ecr describe-repositories --repository-names eks-lab130/app --region "$AWS_REGION"
```

Verifica que en la salida aparece `imageTagMutability: IMMUTABLE` y
`imageScanningConfiguration.scanOnPush: true`.

## Tarea 2. Push de la imagen con el tag v1

Iniciamos sesión en el registro con un token de 12 horas y retagueamos la imagen pública:

```bash
aws ecr get-login-password --region "$AWS_REGION" \
  | podman login --username AWS --password-stdin "$ECR_HOST"

podman pull docker.io/library/alpine:3.19
podman tag docker.io/library/alpine:3.19 "$ECR_HOST/eks-lab130/app:v1"
podman push "$ECR_HOST/eks-lab130/app:v1"

aws ecr describe-images --repository-name eks-lab130/app --region "$AWS_REGION"
```

En la salida de `describe-images` debe aparecer una sola imagen con el tag `v1`.

Dos detalles prácticos. Primero: `alpine` se elige aquí no por «pesar menos», sino porque el
escaneo básico de ECR sabe analizar su base de paquetes - en la tarea 4 habrá findings reales
(verificado: HIGH 1, MEDIUM 1, LOW 2 en `alpine:3.19`). Segundo: mantén las tareas 2-6 en una
sola sesión SSH. `podman login` escribe el token en `$XDG_RUNTIME_DIR/containers/auth.json`,
y ese directorio se elimina junto con la sesión del usuario, así que tras reconectar el push
responde `unauthorized: authentication required` aunque el token de ECR de 12 horas siga
vigente.

## Tarea 3. Síntoma: el push repetido del tag v1 es rechazado

Tomamos otra imagen, la tagueamos con el mismo `v1` e intentamos sobrescribirla:

```bash
podman pull docker.io/library/busybox:1.36
podman tag docker.io/library/busybox:1.36 "$ECR_HOST/eks-lab130/app:v1"

mkdir -p /var/work/tests/artifacts/3
podman push "$ECR_HOST/eks-lab130/app:v1" 2>&1 \
  | tee /var/work/tests/artifacts/3/denied.txt
```

El push termina con un rechazo del registro (verificado en el stand):

```
tag invalid: The image tag 'v1' already exists in the 'eks-lab130/app' repository
and cannot be overwritten because the tag is immutable.
```

Así funciona precisamente IMMUTABLE: el tag `v1` ya está ocupado por la primera imagen, y no
se puede sobrescribir. La salida será larga - `podman` prueba sucesivamente varios formatos
de manifiesto (OCI, docker v2, docker v1) y en cada uno recibe el mismo rechazo; en el
artefacto `denied.txt` la línea necesaria aparece en cada intento. Nota que las capas ya se
subieron: IMMUTABLE protege precisamente el VÍNCULO DEL TAG, no el almacenamiento de blobs.

## Tarea 4. Findings del escaneo (scan on push)

El escaneo se inicia automáticamente al hacer push (tarea 2). Esperamos a que termine con un
ciclo de reintentos (en esta versión de la CLI hay un comando de espera ya listo):

```bash
aws ecr wait image-scan-complete \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION"

mkdir -p /var/work/tests/artifacts/4
aws ecr describe-image-scan-findings \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
  --query '{status: imageScanStatus.status, bySeverity: imageScanFindings.findingSeverityCounts}' \
  > /var/work/tests/artifacts/4/scan-summary.txt

cat /var/work/tests/artifacts/4/scan-summary.txt
```

Si `aws ecr wait image-scan-complete` no está disponible en tu versión de la CLI,
sustitúyelo por un ciclo manual de reintentos:

```bash
for i in $(seq 1 30); do
  status=$(aws ecr describe-image-scan-findings \
    --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
    --query 'imageScanStatus.status' --output text 2>/dev/null)
  [[ "$status" == "COMPLETE" ]] && break
  sleep 5
done
```

`findingSeverityCounts` mostrará la cantidad de findings por severity - en `alpine:3.19` fue
`{"HIGH": 1, "MEDIUM": 1, "LOW": 2}` (verificado en el stand, las cifras concretas dependen
de la fecha del escaneo y de la base de vulnerabilidades).

Hay un límite de aplicabilidad importante que conviene comprobar uno mismo. El escaneo
básico de ECR lee la base de paquetes de distribuciones conocidas, así que una imagen
construida con `FROM scratch` (por ejemplo un binario estático de Go) o distroless NO SE
PUEDE escanear:

```bash
aws ecr describe-image-scan-findings --repository-name eks-lab130/app \
  --image-id imageTag=<tag de la imagen scratch> --region "$AWS_REGION" \
  --query 'imageScanStatus' --output json
# {
#   "status": "FAILED",
#   "description": "UnsupportedImageError: The operating system and/or package manager
#                   are not supported."
# }
```

De aquí una conclusión práctica: «el escáner no encontró vulnerabilidades» y «el escáner no
pudo revisar» son cosas distintas, y en los reportes resumidos se mezclan fácilmente en «sin
observaciones». Si la política de gate exige un escaneo limpio, verifica precisamente el
estado, no solo la cantidad de findings.

## Tarea 5. Despliegue por digest

El digest de la imagen `v1` se puede obtener de ECR (más confiable que `podman inspect`, ya
que es el digest exacto del manifiesto que está en el registro):

```bash
DIGEST=$(aws ecr describe-images --repository-name eks-lab130/app --image-ids imageTag=v1 \
  --region "$AWS_REGION" --query 'imageDetails[0].imageDigest' --output text)
echo "$DIGEST"

kubectl create namespace eks-130 --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: digest-app
  namespace: eks-130
  labels:
    app: digest-app
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
  - name: app
    image: ${ECR_HOST}/eks-lab130/app@${DIGEST}
    command: ["sh", "-c", "sleep 86400"]
EOF

kubectl wait --for=condition=Ready pod/digest-app -n eks-130 --timeout=600s
kubectl get po -n eks-130 digest-app -o wide
```

El `nodeSelector` aquí es obligatorio, y es una trampa fácil de caer en ella. La máquina de
trabajo es x86_64, así que `podman push` envió a ECR un manifiesto DE UNA SOLA ARQUITECTURA
(solo `amd64`), y el NodePool del laboratorio permite también `arm64`. Verificado en el
stand: sin el selector Karpenter levantó un `t4g.small`, la imagen se descargó sin problema,
y el contenedor murió con `exitCode 255` y logs vacíos - `CrashLoopBackOff` sin una causa
clara. El mismo tipo de problema se trata en el laboratorio 124 (la imagen
`polinux/stress` era solo `amd64`). Conclusión para producción: o bien construyes manifiestos
multiarquitectura, o bien vinculas explícitamente la carga a la arquitectura.

El rol del nodo de Karpenter ya lleva la managed policy `AmazonEC2ContainerRegistryReadOnly`
(configurada en el módulo `eks_v2_karpenter`), así que el pod descarga la imagen con éxito y
pasa a `Running` sin `imagePullSecrets`. La referencia por `@sha256:` fija exactamente el
conjunto de bytes que escaneaste y verificaste en las tareas 2-4 - el tag podría cambiar, el
digest no puede.

## Tarea 6. Pull through cache para registry.k8s.io

Regla sin autenticación - el upstream es público:

```bash
aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix k8s-cache \
  --upstream-registry-url registry.k8s.io \
  --region "$AWS_REGION"
```

Al crear la PRIMERA regla en la cuenta, ECR configura el service-linked role
`AWSServiceRoleForECRPullThroughCache`, por lo que quien llama necesita el permiso
`iam:CreateServiceLinkedRole` (en la política de la máquina de trabajo está presente, con la
condición `iam:AWSServiceName = pullthroughcache.ecr.amazonaws.com`). Sin él, ECR no responde
directamente sobre el usuario IAM, sino con un envoltorio que es fácil confundir con un error
de parámetros: `ValidationException ... The Amazon ECR action failed due to an IAM
exception: ... is not authorized to perform: iam:CreateServiceLinkedRole` (reproducido en el
stand).

El primer pull a través de la caché crea el repositorio `k8s-cache/pause` en tu ECR y
almacena la imagen en caché:

```bash
podman pull "${ECR_HOST}/k8s-cache/pause:3.9"

aws ecr describe-repositories --region "$AWS_REGION" \
  --query "repositories[?starts_with(repositoryName,'k8s-cache/pause')].repositoryName"
```

## Tarea 7. Docker Hub pull through cache con secreto (sin pull real)

El tema del laboratorio pide precisamente un secreto, así que lo creamos de verdad, pero con
un valor de relleno en lugar de un token real de Docker Hub: un pull real con estas
credenciales no funcionará, pero la configuración (secreto más cache rule) no se ve afectada
por eso y se verifica completamente.

```bash
aws secretsmanager create-secret \
  --name ecr-pullthroughcache/dockerhub-creds \
  --description "Docker Hub creds for ECR pull through cache (lab placeholder)" \
  --secret-string '{"username":"lab-placeholder-user","accessToken":"lab-placeholder-token"}' \
  --region "$AWS_REGION"

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id ecr-pullthroughcache/dockerhub-creds --region "$AWS_REGION" \
  --query 'ARN' --output text)
echo "$SECRET_ARN"

aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix docker-hub \
  --upstream-registry-url registry-1.docker.io \
  --credential-arn "$SECRET_ARN" \
  --region "$AWS_REGION"

aws ecr describe-pull-through-cache-rules --region "$AWS_REGION"
```

El secreto debe tener obligatoriamente el prefijo `ecr-pullthroughcache/` - de lo contrario
ECR no lo aceptará para la cache rule. Un `podman pull` real a través de `docker-hub/...` con
este valor de relleno fallará como es de esperar (las credenciales no son reales) - la tarea
verifica la configuración (que el secreto y la regla existan), no el hecho de un pull
exitoso. Para el hecho de un pull exitoso a través de la caché sirve la tarea 6
(registry.k8s.io, sin autenticación).

Importante: no uses aquí credenciales reales de Docker Hub. El secreto es solo para verificar
la configuración del propio laboratorio.

## Tarea 8. Lifecycle policy

Regla: mantener no más de 5 imágenes con el tag `v.*`, eliminar el resto según la edad del
tag:

```bash
cat <<'EOF' > /tmp/lifecycle.json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "keep last 5 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": { "type": "expire" }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name eks-lab130/app \
  --lifecycle-policy-text file:///tmp/lifecycle.json \
  --region "$AWS_REGION"

aws ecr get-lifecycle-policy --repository-name eks-lab130/app --region "$AWS_REGION"
aws ecr start-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION" >/dev/null
sleep 5
aws ecr get-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION"
```

`get-lifecycle-policy-preview` puede no devolver el resultado de inmediato (la vista previa
se calcula de forma asíncrona) - si el estado sigue en `IN_PROGRESS`, repite la solicitud
después de unos segundos.

## Verificación rápida

```bash
check_result
```
