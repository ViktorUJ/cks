[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 22 - Solución de referencia

Istio `1.29.1` está instalado. Un backend "externo", **solo HTTPS**, está desplegado en
el espacio de nombres `external` (sin sidecar): nginx termina TLS en el puerto `8443` y el Service
`httpsvc` lo expone en el puerto de texto sin formato `80` (`targetPort: 8443`). Un cliente
dentro de la malla, `app-client`, se ejecuta en el espacio de nombres `app`.

## Objetivo

Haz que la malla **origine TLS** hacia el servicio externo: la aplicación habla HTTP sin cifrar con
`httpsvc.external:80`, y su sidecar actualiza la conexión a TLS antes de llegar al
backend.

## Paso 1. Observa el fallo sin originación

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> 400 : plaintext hit the TLS-only port
```

## Paso 2. Configura la originación TLS con una DestinationRule

El backend utiliza un certificado autofirmado, por lo que omitimos la verificación ascendente con
`insecureSkipVerify: true`. En producción configurarías `caCertificates` con la CA que
firmó el servicio ascendente en su lugar.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpsvc-tls-origination
  namespace: app
spec:
  host: httpsvc.external.svc.cluster.local
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 80
      tls:
        mode: SIMPLE
        insecureSkipVerify: true
EOF
```

## Paso 3. Verifica

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -w "\nHTTP %{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> secure-ok
#    HTTP 200
```

## Cómo funciona

- El cliente envía **HTTP** sin cifrar a `httpsvc.external:80`. No hay cambios en el código de la aplicación ni
  certificados que gestionar en la aplicación.
- La `DestinationRule` con `tls.mode: SIMPLE` en el puerto 80 indica al Envoy del lado del cliente
  que **origine TLS** hacia los endpoints ascendentes (el `targetPort: 8443` del backend).
- El backend recibe una conexión TLS adecuada y devuelve `200`.
- En Istio, `SIMPLE` **verifica** el certificado ascendente de forma predeterminada. Nuestro backend utiliza un
  certificado autofirmado, por lo que configuramos `insecureSkipVerify: true`. En producción, en su lugar
  configurarías `caCertificates` (y opcionalmente `subjectAltNames`) para verificar el servicio ascendente, o usarías
  `MUTUAL` para la autenticación mediante certificado de cliente.

## Por qué originar TLS en la malla

- Las aplicaciones pueden mantenerse sencillas (HTTP sin cifrar) mientras que todo TLS hacia servicios
  externos/heredados se gestiona de forma uniforme por la malla.
- En combinación con un **egress gateway** (Lab 05), la originación puede centralizarse en un
  nodo dedicado para que todo TLS saliente abandone el clúster a través de un único salto auditado y
  controlado por políticas.
