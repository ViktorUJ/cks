[RU version](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md)

# Istio: praktischer Selbstlernkurs

Ein praxisorientierter Kurs zum Service Mesh Istio, verknüpft mit den praktischen Übungen
(`tasks/ica/labs`). Geschrieben für Ingenieure, die den CKA bereits bestanden haben. Teil 1
deckt die ICA-Prüfung ab, Teil 2 behandelt Best Practices für den Betrieb in der Praxis.

Aufbau: Jedes Thema ist ein nummerierter Ordner. Darin liegen lokalisierte Dateien.
Die Hauptsprache ist Russisch (`ru.md`); daraus werden die Übersetzungen erstellt.

Verfügbare Lokalisierungen (Kurskapitel und Übungen sind vollständig übersetzt):

- 🇷🇺 Русский - `ru.md` (Hauptsprache, Source of Truth)
- 🇬🇧 English - `en.md`
- 🇪🇸 Español - `es.md`
- 🇫🇷 Français - `fr.md`
- 🇩🇪 Deutsch - `de.md`

Zwischen den Sprachen wechseln Sie über die Links in der ersten Zeile jedes Kapitels und in
der Kopfzeile dieses Inhaltsverzeichnisses. Die Mock-Prüfungen (`tasks/ica/mock`) gibt es
nur auf Englisch.

## Inhaltsverzeichnis

### Teil 1. Grundlagen und ICA-Vorbereitung

1. [Einführung in Service Mesh und die Istio-Architektur](01/de.md)
2. [Installation und Konfiguration von Istio](02/de.md)
3. [Istio aktualisieren: Helm, Revisionen, Canary und In-place](03/de.md)
4. [Data Plane: Envoy und Sidecar-Injektion](04/de.md)
5. [Traffic-Management: Gateway, VirtualService, DestinationRule](05/de.md)
6. [Deployment-Strategien: Canary, Header-Routing, Traffic-Mirroring](06/de.md)
7. [Load Balancing und lokalitätsbewusstes Failover](07/de.md)
8. [Resilienz: Fault Injection, Timeouts, Retries, Circuit Breaking](08/de.md)
9. [Edge-TLS: Ingress in den Modi SIMPLE, MUTUAL, PASSTHROUGH](09/de.md)
10. [Routing von TCP-, gRPC- und WebSocket-Traffic](10/de.md)
11. [Kubernetes Gateway API](11/de.md)
12. [Egress: ServiceEntry, Egress Gateway, TLS-Origination](12/de.md)
13. [mTLS und PeerAuthentication: das Zero-Trust-Modell](13/de.md)
14. [AuthorizationPolicy: Service-zu-Service-Autorisierung](14/de.md)
15. [Endbenutzer-Authentifizierung: RequestAuthentication und JWT](15/de.md)
16. [Zertifikatsverwaltung: eigene CA, cert-manager und istio-csr](16/de.md)
17. [Observability: Prometheus, Grafana, Jaeger, Kiali](17/de.md)
18. [Telemetry API: Access-Logs und verteiltes Tracing](18/de.md)
19. [Sidecar-Scoping und Optimierung der Proxy-Konfiguration](19/de.md)
20. [Rate Limiting: lokale Begrenzung von Anfragen](20/de.md)
21. [Data Plane erweitern: EnvoyFilter, Lua und WasmPlugin](21/de.md)
22. [Ambient-Modus: ztunnel und Waypoint-Proxy](22/de.md)
23. [StatefulSets und Headless-Services im Mesh](23/de.md)
24. [Troubleshooting von Istio](24/de.md)

### Teil 2. Best Practices für den realen Einsatz

25. [Progressive Delivery mit Flagger](25/de.md)
26. [Produktionsmigration ohne Ausfallzeit: von ingress-nginx zu Istio](26/de.md)
27. [Istio auf EKS: Produktionsinstallation](27/de.md)
28. [Multi-Cluster-Mesh](28/de.md)
29. [Workloads außerhalb von Kubernetes: VMs im Mesh](29/de.md)
30. [Control-Plane-Performance und -Betrieb](30/de.md)
31. [Härtung und das Bedrohungsmodell des Mesh](31/de.md)

### Prüfungsvorbereitung

32. [Die ICA-Prüfung: Format und Vorbereitung](32/de.md)
