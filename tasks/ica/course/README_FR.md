[RU version](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Deutsche Version](README_DE.md)

# Istio : cours pratique en autoformation

Un cours pratique sur le maillage de services Istio, lié aux travaux pratiques
(`tasks/ica/labs`). Écrit pour des ingénieurs ayant déjà réussi le CKA. La Partie 1 couvre
l'examen ICA, la Partie 2 couvre les bonnes pratiques pour l'exploitation dans le monde
réel.

Structure : chaque sujet est un dossier numéroté. À l'intérieur se trouvent des fichiers
localisés. La langue principale est le russe (`ru.md`) ; les traductions en sont issues.

Localisations disponibles (les chapitres du cours et les travaux pratiques sont
entièrement traduits) :

- 🇷🇺 Русский - `ru.md` (principal, source de vérité)
- 🇬🇧 English - `en.md`
- 🇪🇸 Español - `es.md`
- 🇫🇷 Français - `fr.md`
- 🇩🇪 Deutsch - `de.md`

Changez de langue via les liens de la première ligne de chaque chapitre et de l'en-tête de
ce sommaire. Les examens blancs (`tasks/ica/mock`) sont uniquement en anglais.

## Sommaire

### Partie 1. Fondamentaux et préparation à l'ICA

1. [Introduction au maillage de services et à l'architecture d'Istio](01/fr.md)
2. [Installation et configuration d'Istio](02/fr.md)
3. [Mise à niveau d'Istio : Helm, révisions, canary et in-place](03/fr.md)
4. [Data plane : Envoy et injection de sidecar](04/fr.md)
5. [Gestion du trafic : Gateway, VirtualService, DestinationRule](05/fr.md)
6. [Stratégies de déploiement : canary, header-routing, mirroring du trafic](06/fr.md)
7. [Répartition de charge et failover selon la localité](07/fr.md)
8. [Résilience : fault injection, timeouts, reintentos, circuit breaking](08/fr.md)
9. [TLS en périphérie : ingress en modes SIMPLE, MUTUAL, PASSTHROUGH](09/fr.md)
10. [Routage du trafic TCP, gRPC et WebSocket](10/fr.md)
11. [Kubernetes Gateway API](11/fr.md)
12. [Egress : ServiceEntry, egress gateway, origination TLS](12/fr.md)
13. [mTLS et PeerAuthentication : le modèle Zero Trust](13/fr.md)
14. [AuthorizationPolicy : autorisation de service à service](14/fr.md)
15. [Authentification de l'utilisateur final : RequestAuthentication et JWT](15/fr.md)
16. [Gestion des certificats : CA personnalisée, cert-manager et istio-csr](16/fr.md)
17. [Observabilité : Prometheus, Grafana, Jaeger, Kiali](17/fr.md)
18. [Telemetry API : logs d'accès et traçage distribué](18/fr.md)
19. [Scoping du Sidecar et optimisation de la configuration du proxy](19/fr.md)
20. [Rate limiting : limitation locale des requêtes](20/fr.md)
21. [Étendre le data plane : EnvoyFilter, Lua et WasmPlugin](21/fr.md)
22. [Mode ambient : ztunnel et waypoint proxy](22/fr.md)
23. [StatefulSets et services headless dans le maillage](23/fr.md)
24. [Troubleshooting d'Istio](24/fr.md)

### Partie 2. Bonnes pratiques pour un usage réel

25. [Livraison progressive avec Flagger](25/fr.md)
26. [Migration en production sans interruption : d'ingress-nginx vers Istio](26/fr.md)
27. [Istio sur EKS : installation de production](27/fr.md)
28. [Maillage multi-cluster](28/fr.md)
29. [Charges de travail hors Kubernetes : VMs dans le maillage](29/fr.md)
30. [Performance et exploitation du control plane](30/fr.md)
31. [Durcissement et modèle de menaces du maillage](31/fr.md)

### Préparation à l'examen

32. [L'examen ICA : format et préparation](32/fr.md)
