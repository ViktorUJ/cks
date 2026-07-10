[RU version](README_RU.md) · [Eng version](README.md)

# Istio: curso práctico de autoaprendizaje

Un curso práctico sobre la malla de servicios Istio, ligado a los laboratorios prácticos
(`tasks/ica/labs`). Escrito para ingenieros que ya han aprobado el CKA. La Parte 1 cubre el
examen ICA, la Parte 2 cubre las buenas prácticas para operaciones en el mundo real.

Estructura: cada tema es una carpeta numerada. Dentro hay archivos localizados (`ru.md` es
el principal por ahora; las traducciones al inglés y al español se añaden después).

## Contenido

### Parte 1. Fundamentos y preparación para el ICA

1. [Introducción a la malla de servicios y la arquitectura de Istio](01/es.md)
2. [Instalación y configuración de Istio](02/es.md)
3. [Actualización de Istio: Helm, revisiones, canary e in-place](03/es.md)
4. [Data plane: Envoy e inyección de sidecar](04/es.md)
5. [Gestión del tráfico: Gateway, VirtualService, DestinationRule](05/es.md)
6. [Estrategias de despliegue: canary, header-routing, mirroring de tráfico](06/es.md)
7. [Balanceo de carga y failover según la localidad](07/es.md)
8. [Resiliencia: fault injection, timeouts, reintentos, circuit breaking](08/es.md)
9. [TLS en el borde: ingress en modos SIMPLE, MUTUAL, PASSTHROUGH](09/es.md)
10. [Enrutamiento de tráfico TCP, gRPC y WebSocket](10/es.md)
11. [Kubernetes Gateway API](11/es.md)
12. [Egress: ServiceEntry, egress gateway, originación de TLS](12/es.md)
13. [mTLS y PeerAuthentication: el modelo Zero Trust](13/es.md)
14. [AuthorizationPolicy: autorización servicio a servicio](14/es.md)
15. [Autenticación del usuario final: RequestAuthentication y JWT](15/es.md)
16. [Gestión de certificados: CA propia, cert-manager e istio-csr](16/es.md)
17. [Observabilidad: Prometheus, Grafana, Jaeger, Kiali](17/es.md)
18. [Telemetry API: access logs y trazas distribuidas](18/es.md)
19. [Scoping del Sidecar y optimización de la configuración del proxy](19/es.md)
20. [Rate limiting: limitación local de peticiones](20/es.md)
21. [Extender el data plane: EnvoyFilter, Lua y WasmPlugin](21/es.md)
22. [Modo ambient: ztunnel y waypoint proxy](22/es.md)
23. [StatefulSets y servicios headless en la malla](23/es.md)
24. [Troubleshooting de Istio](24/es.md)

### Parte 2. Buenas prácticas para uso en el mundo real

25. [Entrega progresiva con Flagger](25/es.md)
26. [Migración en producción sin downtime: de ingress-nginx a Istio](26/es.md)
27. [Istio en EKS: instalación de producción](27/es.md)
28. [Malla multiclúster](28/es.md)
29. [Cargas de trabajo fuera de Kubernetes: VMs en la malla](29/es.md)
30. [Rendimiento y operación del control plane](30/es.md)
31. [Hardening y el modelo de amenazas de la malla](31/es.md)

### Preparación para el examen

32. [El examen ICA: formato y preparación](32/es.md)
