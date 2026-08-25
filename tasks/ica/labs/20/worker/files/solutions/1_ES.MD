[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 20: solución de referencia

Istio `1.29.1` está instalado. Se han desplegado tres cargas de trabajo:
- `ping-pong` en el espacio de nombres `app` (sidecar inyectado, sirve la aplicación);
- `mesh-client` en el espacio de nombres `app` (sidecar inyectado, se comunica mediante mTLS);
- `legacy-client` en el espacio de nombres `legacy` (**sin** sidecar, solo texto sin cifrar).

Sin `PeerAuthentication`, mTLS es **PERMISSIVE** de forma predeterminada: tanto el cliente de la mesh
(mTLS) como el cliente heredado (texto sin cifrar) pueden acceder a la aplicación.

## Objetivo

Migrar el espacio de nombres `app` a mTLS **STRICT** para que solo se acepte tráfico mTLS, sin
interrumpir el cliente dentro de la mesh.

## Paso 1. Observar la línea base PERMISSIVE

```bash
# in-mesh client -> app : works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : ALSO works under PERMISSIVE
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200
```

## Paso 2. (recomendado) Hacer explícita la intención con PERMISSIVE

Una migración segura primero fija PERMISSIVE de forma explícita y luego cambia a STRICT una vez que haya
confirmado (mediante métricas) que no queda tráfico de texto sin cifrar:

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

## Paso 3. Cambiar el espacio de nombres a STRICT

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: STRICT
EOF
```

## Paso 4. Verificar

```bash
# in-mesh client -> app : still works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : now rejected (connection reset)
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 http://ping-pong.app.svc.cluster.local:8080/
# -> 000 (curl exit 56: reset by peer)
```

## Cómo funciona

- **PeerAuthentication** controla cómo el sidecar del *lado del servidor* acepta conexiones
  entrantes:
  - `PERMISSIVE` (valor predeterminado de la mesh) acepta tanto mTLS como texto sin cifrar. Esto permite una
    migración sin tiempo de inactividad: puede incorporar cargas de trabajo a la mesh gradualmente
    mientras los clientes heredados de texto sin cifrar siguen funcionando.
  - `STRICT` acepta solo mTLS; las conexiones de texto sin cifrar se restablecen.
- Jerarquía de ámbito: un `PeerAuthentication` en `istio-system` (raíz) se aplica a toda la mesh; uno
  en un espacio de nombres lo sobrescribe allí; uno con un `selector` lo sobrescribe por carga de trabajo.
- **Receta de migración segura**: mantenga PERMISSIVE, observe la métrica
  `istio_requests_total{connection_security_policy="none"}` hasta que llegue a
  cero (no queda texto sin cifrar), y luego cambie a STRICT.

## Relacionado

El laboratorio 04 trata el estado final STRICT combinado con `AuthorizationPolicy` (quién puede llamar
a quién). Este laboratorio se centra en la transición en sí y en el rol de PERMISSIVE.
