[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 113 - solución de referencia (actualización y rollback del clúster)

Todos los comandos se ejecutan en la máquina de trabajo por SSH. kubectl y aws cli ya están
configurados para el clúster del laboratorio. Primero, guarda el nombre del clúster en una
variable - la necesitarás en casi todos los comandos:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## Tarea 1. Namespace y la versión inicial del clúster

```bash
kubectl create namespace eks-113

aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Salida esperada - `"1.35"`. El clúster de este laboratorio arranca deliberadamente una
versión menor por debajo de la GA actual `1.36`, para que después puedas pasar por una
actualización y un rollback reales.

Extra (no se verifica, pero es útil antes de la actualización): mira qué `apiVersion` sirve
actualmente el API server, para compararlo con la versión después de la actualización más
adelante:

```bash
kubectl get --raw /apis | grep -o '"groupVersion":"[^"]*"'
```

## Tarea 2. Comprobar la upgrade readiness

Upgrade insights es una comprobación integrada de EKS que busca cosas que podrían bloquear la
actualización: uso de APIs que se eliminarán en la versión de destino, y la salud general del
clúster. La lista de insights del clúster sin `--filter` incluye todas las categorías,
incluida la de actualización:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks list-insights --cluster-name "$CLUSTER" \
  > /var/work/tests/artifacts/2/upgrade_insights.json
cat /var/work/tests/artifacts/2/upgrade_insights.json
```

Comprueba que no haya estado `ERROR` entre los insights (bloquea la actualización hasta que
se corrija):

```bash
grep '"status"' /var/work/tests/artifacts/2/upgrade_insights.json
```

Si algún insight tiene estado `WARNING` - eso no es un bloqueante, pero merece la pena leer la
recomendación mediante `aws eks describe-insight --cluster-name "$CLUSTER" --id <insight-id>`.
Si hay un `ERROR`, corrige la causa (habitualmente un `apiVersion` obsoleto en los manifiestos)
y ejecuta `aws eks list-insights` de nuevo - EKS refresca los insights una vez cada 24 horas,
puedes forzar un refresco mediante `aws eks start-insights-refresh --cluster-name "$CLUSTER"`.

## Tarea 3. Actualizar el control plane a 1.36

La actualización solo avanza una versión menor a la vez: `1.35` -> `1.36`. Inícala y guarda el
`id` de la actualización:

```bash
UPDATE_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.36 \
  --query 'update.id' --output text)
echo "$UPDATE_ID"
```

La actualización del control plane se ejecuta en segundo plano y puede tardar 20-40 minutos.
Espera al estado `Successful`:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$UPDATE_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

Confirma la nueva versión:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Salida esperada - `"1.36"`. Los nodos y los add-ons todavía no cambian de versión en este
punto - ese es el siguiente paso.

## Tarea 4. Actualizar los add-ons principales a versiones para 1.36

El control plane ya se ha actualizado, pero `kube-proxy` y `coredns` no lo siguen
automáticamente - se actualizan por separado, a versiones compatibles con la nueva versión
menor. Comprueba las versiones compatibles exactas así (si no tienes la tabla del curso a
mano):

```bash
aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
```

Actualiza ambos add-ons (las mismas versiones que en el laboratorio 101, donde el clúster
arranca directamente en `1.36`):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.36.0-eksbuild.14
aws eks update-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --addon-version v1.14.3-eksbuild.3
```

Espera a `ACTIVE` para cada uno de ellos:

```bash
for addon in kube-proxy coredns; do
  while true; do
    status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$addon" \
      --query 'addon.status' --output text)
    echo "$addon status=$status"
    [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
    sleep 10
  done
done
```

Comprueba las versiones resultantes:

```bash
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --query 'addon.addonVersion'
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --query 'addon.addonVersion'
```

`vpc-cni` y `eks-pod-identity-agent` no están tan estrechamente ligados a la versión menor de
Kubernetes como `kube-proxy` y `coredns`, así que dentro de este laboratorio puedes dejarlos
como están - pero en operación real sigue mereciendo la pena comprobar sus versiones mediante
`describe-addon-versions`.

## Tarea 5. Comprobar la rollback readiness

Los rollback readiness insights solo aparecen después de una actualización y viven
exactamente 7 días - la ventana de rollback. Míralos con un filtro de categoría:

```bash
mkdir -p /var/work/tests/artifacts/5
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  > /var/work/tests/artifacts/5/rollback_readiness.json
cat /var/work/tests/artifacts/5/rollback_readiness.json
```

Comprueba los estados - `ERROR` y `UNKNOWN` bloquean el rollback:

```bash
grep '"status"' /var/work/tests/artifacts/5/rollback_readiness.json
```

Si acabas de corregir uno de los bloqueantes y no quieres esperar al refresco diario:

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
```

## Tarea 6. Hacer el rollback del control plane a 1.35

En la tarea 4 actualizamos `kube-proxy` a la versión compatible con `1.36`. Si intentas hacer
el rollback del control plane ahora mismo, EKS recalcula los rollback readiness insights de
nuevo en el momento en que se llama a `update-cluster-version` y encuentra un `ERROR` en la
comprobación `kube-proxy version rollback compatibility`: la versión `1.36` de `kube-proxy`,
tras el rollback del control plane a `1.35`, terminaría siendo más nueva que el control plane,
lo cual viola la política de version skew. Esto es exactamente lo que dice el capítulo 39:
"haz el rollback de los nodos/add-ons antes que el del control plane si la versión del add-on
está por delante de la versión de destino" - `aws eks list-insights` justo después de la
actualización todavía no mostrará este problema (los insights de rollback se recalculan
contra el estado actual del clúster), pero aparecerá si los vuelves a pedir después de
actualizar el add-on.

El orden correcto es primero devolver `kube-proxy` a una versión compatible con `1.35`, y solo
después hacer el rollback del control plane:

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.35.3-eksbuild.13

while true; do
  status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
    --query 'addon.status' --output text)
  echo "kube-proxy status=$status"
  [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
  sleep 10
done
```

Comprueba que el insight de kube-proxy pasó a `PASSING` (puedes forzar un recálculo si no
quieres esperar un día):

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
sleep 30
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  --query 'insights[].{name:name,status:insightStatus.status}'
```

Ahora puedes hacer el rollback del control plane sin `--force` - de la forma estándar, igual
que la actualización, pero con la versión anterior:

```bash
ROLLBACK_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.35 \
  --query 'update.id' --output text)
echo "$ROLLBACK_ID"

aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type'
```

El tipo de actualización en la respuesta es `VersionRollback`, no un `VersionUpdate` normal.
Guarda esto como artefacto:

```bash
mkdir -p /var/work/tests/artifacts/6
aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type' --output text > /var/work/tests/artifacts/6/rollback_update.txt
cat /var/work/tests/artifacts/6/rollback_update.txt
```

El rollback también se ejecuta en segundo plano y puede tardar 20-40 minutos. Espera a
`Successful`:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

Confirma que el control plane volvió a `1.35`:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Salida esperada - `"1.35"`. Los datos de etcd, las cargas de trabajo y los volúmenes
persistentes no se tocan durante el rollback - solo hace rollback la versión del control
plane, esto no sustituye a una copia de seguridad.

## Verificación rápida

```bash
check_result
```
