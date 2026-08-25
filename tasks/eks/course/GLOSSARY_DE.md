[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# EKS-Kursglossar

[Inhaltsverzeichnis des Kurses](README_DE.md)

Ein einheitliches alphabetisches Nachschlagewerk für die Begriffe des Kurses. Begriffe bleiben auf Englisch, wenn dies die Bezeichnung in AWS oder Kubernetes ist; die Beschreibung ist auf Deutsch. Die Spalte „Kapitel“ verweist auf die Kapitel, in denen der Begriff erläutert wird. Suche auf der Seite mit Ctrl+F.

| Begriff | Beschreibung | Kapitel |
|--------|----------|-------|
| **ABAC / RBAC** | Zugriff über Tags mittels `aws:PrincipalTag` gegenüber Zugriff über Rollen und Richtlinien mit konkreten Aktionen und Ressourcen. | [0.2](00-2-iam/de.md) |
| **Access entry** | Eintrag der Clusterzugriffskonfiguration, der einen IAM-Prinzipal mit `username` und `kubernetesGroups` verknüpft; `STANDARD` für Menschen und Dienste, `EC2_LINUX`, `EC2_WINDOWS`, `FARGATE_LINUX`, `HYBRID_LINUX` und `EC2` für Nodes. | [01](01/de.md), [05](05/de.md), [47](47/de.md) |
| **access entry vom Typ `EC2_LINUX`** | Eintrag, der den ARN einer Node-Rolle im Cluster autorisiert. | [45](45/de.md) |
| **access point** | Einstieg in ein EFS-Unterverzeichnis mit eigenen Rechten und POSIX-Identität; Grundlage für dynamisches Provisioning und Verzeichnisisolation. | [24](24/de.md) |
| **Access policy** | Von AWS verwaltete Kubernetes-Berechtigungsrichtlinie für einen access entry; enthält verbs und resources, keine IAM-Rechte, und ist nicht editierbar. | [05](05/de.md), [47](47/de.md) |
| **Access scope** | Geltungsbereich einer access policy: `cluster` oder eine Liste von `namespace`. | [05](05/de.md) |
| **ACM (AWS Certificate Manager)** | Zertifikate am Load Balancer; der Schlüssel wird nicht exportiert und die Verlängerung erfolgt automatisch. | [27](27/de.md), [29](29/de.md) |
| **actions / conditions** | Annotationen für benutzerdefinierte Aktionen und zusätzliche Routingbedingungen. | [27](27/de.md) |
| **Admission webhook** | Externer Handler, den der API-Server vor dem Schreiben nach etcd aufruft; mutating ändert Objekte, validating lässt nur zu oder lehnt ab. | [22](22/de.md) |
| **ADOT** | AWS Distro for OpenTelemetry: AWS-Distribution von OTel mit SDKs, Agents und Collector. | [36](36/de.md) |
| **ALIAS** | Route-53-Eintrag auf eine AWS-Ressource, etwa ELB; funktioniert am Domain-Apex und wird nicht als einzelner Request berechnet. | [29](29/de.md) |
| **Allocatable** | Für Pods verfügbare Ressourcen nach `kube-reserved`, `system-reserved` und Eviction-Schwelle; daran orientiert sich der Scheduler. | [14](14/de.md) |
| **`allowVolumeExpansion`** | StorageClass-Flag zum Vergrößern eines Volumes durch Erweiterung des PVC. | [23](23/de.md) |
| **Amazon EKS** | Verwaltetes Kubernetes in AWS: AWS betreibt die control plane, Nodes und Infrastruktur liegen bei Ihnen. | [01](01/de.md) |
| **Amazon Managed Grafana (AMG)** | Verwaltetes Grafana; nutzt AMP als Datenquelle und IAM Identity Center für Benutzerzugriff. | [33](33/de.md) |
| **Amazon Managed Service for Prometheus (AMP)** | Verwaltetes Prometheus-kompatibles Backend mit Workspace, remote-write, PromQL und AWS-seitiger Aufbewahrung. | [33](33/de.md) |
| **amazon-cloudwatch-observability** | Verwaltetes EKS-Add-on für CloudWatch Agent und Container Insights with enhanced observability. | [33](33/de.md) |
| **AMI (Amazon Machine Image)** | Instanz-Datenträgerabbild mit Kernel, Dateisystem und Software; für Nodes dient ein EKS-optimiertes AMI mit abgestimmtem `kubelet` und `containerd`. | [0.4](00-4-ec2/de.md), [10](10/de.md) |
| **API Priority and Fairness** | Kubernetes-Mechanismus zur Verteilung gleichzeitiger Requests; bei Erschöpfung erhält der Client `429`. | [02](02/de.md) |
| **app-of-apps** | Übergeordnetes `Application`, das eine Menge untergeordneter Anwendungen ausrollt. | [44](44/de.md) |
| **Application** | Argo-CD-CRD: Verbindung aus Git-Quelle sowie Zielcluster und Namespace. | [44](44/de.md) |
| **Application Load Balancer (ALB)** | L7-Load-Balancer für HTTP/HTTPS mit Host-/Path-Routing, TLS-Terminierung, WAF und Authentifizierung; LBC erstellt ihn aus Ingress. | [27](27/de.md) |
| **ApplicationSet** | Argo-CD-Controller, der `Application` aus Vorlagen generiert. | [44](44/de.md) |
| **ARN** | `arn:partition:service:region:account-id:resource`, die Adresse einer Ressource. | [0.1](00-1-aws/de.md) |
| **`AssumeRoleWithWebIdentity`** | STS-Operation zum Tausch eines Web-Identity-Tokens gegen temporäre IAM-Rollenzugangsdaten. | [16](16/de.md) |
| **auditID** | Eindeutige Request-ID im Audit-Log; für alle Stages einer Operation gleich. | [21](21/de.md) |
| **`authenticationMode`** | Cluster-Authentifizierungsmodus: `CONFIG_MAP`, `API_AND_CONFIG_MAP` oder `API`; Wechsel nur in Richtung `API`. | [04](04/de.md), [05](05/de.md), [47](47/de.md) |
| **`authenticationSource`** | Quelle der Volume-Zugangsdaten: `driver` oder `pod`. | [25](25/de.md) |
| **Availability Zone (AZ)** | Isolierte Gruppe von Rechenzentren einer Region und grundlegende Fehlerdomäne für Replikate. | [0.1](00-1-aws/de.md), [40](40/de.md) |
| **AWS Backup** | Zentraler AWS-Sicherungsdienst für EKS, EBS, EFS, S3 und weitere Ressourcen nach einheitlichen Plänen und Tresoren. | [41](41/de.md) |
| **aws cli v2** | Haupt-CLI für AWS; Konfiguration in `~/.aws/config`, Zugriff über `--profile` oder `AWS_PROFILE`. | [0.5](00-5-tools/de.md) |
| **AWS Control Tower** | Fertige AWS-Landing-Zone mit Controls, Drift-Erkennung und account factory. | [0.1](00-1-aws/de.md) |
| **`aws eks get-token`** | `exec`-Plugin in kubeconfig, das ein presigned STS-Token für den Clusterzugriff erzeugt. | [47](47/de.md) |
| **AWS Gateway API Controller** | Controller `aws-application-networking-k8s` mit GatewayClass `amazon-vpc-lattice`; übersetzt Gateway API in VPC-Lattice-Objekte. | [28](28/de.md) |
| **AWS Load Balancer Controller (Gateway API)** | Implementierung mit `controllerName` `gateway.k8s.aws/alb` für ALB und `gateway.k8s.aws/nlb` für NLB. | [28](28/de.md) |
| **AWS Load Balancer Controller (LBC)** | Cluster-Controller für NLB aus LoadBalancer-Services und ALB aus Ingress; wird per Helm installiert und benötigt eine IAM-Rolle. | [26](26/de.md) |
| **AWS Organizations** | Dienst zur Verwaltung mehrerer Accounts: OU-Hierarchie, SCPs und konsolidierte Abrechnung. | [0.1](00-1-aws/de.md), [32](32/de.md) |
| **AWS PrivateLink** | Privater Zugriff auf AWS-Dienste und kontoübergreifende Dienste über interface endpoints. | [31](31/de.md) |
| **AWS RAM (Resource Access Manager)** | Dienst zum Teilen von Ressourcen wie Subnets, Transit Gateway und Resolver-Regeln mit Accounts und der Organisation. | [0.1](00-1-aws/de.md), [32](32/de.md) |
| **`aws sts get-caller-identity`** | Befehl „Wer bin ich?“: Account, ARN und userId. | [0.5](00-5-tools/de.md) |
| **AWS X-Ray** | Verwaltetes Trace-Backend mit Speicherung, service map, Latenzaufteilung und Trace-Suche. | [36](36/de.md) |
| **`aws-auth` ConfigMap** | Legacy-Zuordnung in `kube-system` mit den Feldern `mapRoles` und `mapUsers`. | [05](05/de.md), [45](45/de.md), [47](47/de.md) |
| **aws-for-fluent-bit** | Von AWS gebautes Fluent-Bit-Image mit Ausgabeplugins für AWS-Dienste. | [34](34/de.md) |
| **`aws-vault`** | Speichert Zugangsdaten im Keychain und führt Befehle in einer temporären Sitzung aus. | [0.5](00-5-tools/de.md) |
| **`AWS_VPC_K8S_CNI_EXTERNALSNAT`** | Deaktiviert Node-SNAT für Pod-Egress (`true`), sodass externe Ziele die echte Pod-Adresse sehen. | [07](07/de.md) |
| **`AWSTraceHeader`** | SQS-Systemattribut für den X-Ray-Trace-Header und die Kontextweitergabe über asynchrone Grenzen. | [36](36/de.md) |
| **backend-protocol-version** | Anwendungsprotokoll der Target Group: `HTTP1`, `HTTP2` oder `GRPC`. | [27](27/de.md) |
| **backup plan** | Sicherungsplan: Zeitplan, Aufbewahrung, Lifecycle und Ressourcenzuordnung. | [41](41/de.md) |
| **backup vault** | Speicher für recovery points mit KMS-Schlüssel und Zugriffsrichtlinie; dort wird Vault Lock aktiviert. | [41](41/de.md) |
| **BackupStorageLocation (BSL)** | Speicherort der Velero-Backups, etwa ein S3-Bucket. | [42](42/de.md) |
| **bake period** | Pause zwischen Upgrade der control plane und der Nodes, die auf N-1 bleiben. | [39](39/de.md) |
| **Basic / Enhanced scanning** | ECR-CVE-Scanmodi: basic für OS-Pakete, enhanced fortlaufend für OS- und Sprachpakete durch Amazon Inspector. | [20](20/de.md) |
| **behavior / stabilizationWindowSeconds** | HPA-Abschnitt zur Glättung von Skalierungsgeschwindigkeit und -schwankungen. | [35](35/de.md) |
| **bin packing** | Platzierung von Pods auf Nodes entsprechend ihren requests. | [14](14/de.md) |
| **blue/green cluster** | Neuer Cluster auf der Zielversion neben dem alten mit Workload-Migration und Traffic-Umschaltung. | [03](03/de.md), [38](38/de.md) |
| **bootstrap.sh** | Skript zur kubelet-Konfiguration auf AL2 aus user data. | [45](45/de.md) |
| **`bootstrapClusterCreatorAdminPermissions`** | Zugriffsoption bei der Erstellung; bei `true` erhält der Cluster-Ersteller Admin-Rechte. | [04](04/de.md), [05](05/de.md) |
| **Bottlerocket** | Minimales Container-OS mit schreibgeschütztem Root, Image-Updates und API-Verwaltung statt offenem SSH. | [10](10/de.md) |
| **Burstable (T-Serie)** | Basis-CPU-Anteil plus CPU credits; für Produktions-Nodes ungeeignet. | [0.4](00-4-ec2/de.md) |
| **Capacity** | Vollständige Instanzkapazität an CPU, Speicher und Pods. | [14](14/de.md) |
| **Capacity Blocks** | Reservierung von GPU-/Trainium-Kapazität für Training. | [0.4](00-4-ec2/de.md) |
| **capacity type** | Kapazitätstyp der Node (`spot`/`on-demand`) mit den Labels `karpenter.sh/capacity-type` und `eks.amazonaws.com/capacityType`. | [13](13/de.md) |
| **CapacityProvisioned** | Pod-Annotation mit der nach Rundung tatsächlich bereitgestellten vCPU-/Speicherkombination; sie bestimmt die Kosten. | [15](15/de.md) |
| **cert-manager** | Controller für Zertifikate als `Secret` im Cluster; Quelle ist ClusterIssuer oder Issuer. | [29](29/de.md) |
| **CFS throttling** | Verlangsamung eines Containers bei Überschreitung seines CPU limit. | [14](14/de.md) |
| **chargeback** | Tatsächliche Kosten werden dem Budget eines Teams belastet. | [43](43/de.md) |
| **`CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy`** | Cilium-CRDs für L7-, FQDN- und clusterweite Regeln. | [08](08/de.md), [30](30/de.md) |
| **CloudTrail** | AWS-API-Aufrufprotokoll; für EKS erfasst es AWS-Ressourcenoperationen, nicht Kubernetes-Ereignisse im Cluster. | [21](21/de.md) |
| **CloudWatch Application Signals** | APM auf OTel-Basis für SLOs, Latenz und Fehler, aktiviert per `amazon-cloudwatch-observability`. | [36](36/de.md) |
| **CloudWatch Logs** | AWS-Logspeicher mit log groups, log streams und Logs Insights. | [34](34/de.md) |
| **CloudWatch Logs Insights** | Abfragesprache für Logs mit `fields`, `filter`, `sort` und `stats`; wichtiges Werkzeug zur Analyse des Audit-Logs. | [21](21/de.md) |
| **Cluster Autoscaler (CA)** | Node-Autoscaler über Auto Scaling groups; ändert `desiredSize` nach nicht platzierbaren Pods und Unterauslastung. | [11](11/de.md) |
| **cluster creator admin** | IAM-Prinzipal, der den Cluster erstellt und automatisch Admin-Zugriff erhält. | [47](47/de.md) |
| **Cluster endpoint** | Kubernetes-API-Adresse des Clusters; public ist per CIDR begrenzt, private innerhalb der VPC über die cluster security group. | [01](01/de.md), [02](02/de.md) |
| **Cluster insights** | Automatische EKS-Prüfungen zu `UPGRADE_READINESS` und `ROLLBACK_READINESS`. | [03](03/de.md), [38](38/de.md) |
| **Cluster security group** | Automatisch für den Cluster erstellte Security Group für Cluster-Schnittstellen und Managed-Node-Group-Nodes. | [02](02/de.md), [45](45/de.md) |
| **cluster version rollback** | Rücksetzung der EKS-control-plane auf die vorige Minor-Version innerhalb von sieben Tagen. | [03](03/de.md), [39](39/de.md) |
| **ClusterIssuer / Issuer** | cert-manager-Objekte für eine Zertifikatsquelle im gesamten Cluster bzw. Namespace. | [29](29/de.md) |
| **ClusterMesh** | Verbindung mehrerer Cilium-Pod-Netzwerke über `clustermesh-apiserver`; benötigt eindeutige `cluster-id` und nicht überlappende PodCIDR. | [08](08/de.md) |
| **CMK (customer managed key)** | Eigener KMS-Schlüssel mit Kontrolle über Schlüsselrichtlinie und CloudTrail-Audit. | [18](18/de.md) |
| **CNI chaining** | VPC CNI vergibt Adressen und Schnittstellen, Cilium ergänzt Richtlinien und Observability; `aws-node` bleibt bestehen. | [08](08/de.md), [30](30/de.md) |
| **`cni-metrics-helper`** | Komponente, die `awscni_*` von `aws-node` abruft und Aggregate an CloudWatch sendet. | [06](06/de.md) |
| **composite recovery point** | Zusammengesetzter EKS-Wiederherstellungspunkt für Clusterzustand und Volume-Backups. | [41](41/de.md) |
| **Compute Savings Plans** | Stundenweise Ausgabenverpflichtung für ein bis drei Jahre gegen Rabatt, flexibel über Instanzfamilien, Regionen, Fargate und Lambda. | [43](43/de.md) |
| **Compute SP / EC2 Instance SP** | Flexibler Plan für EC2, Fargate und Lambda / stärkerer Rabatt für eine Instanzfamilie in einer Region. | [0.4](00-4-ec2/de.md) |
| **configurationValues** | Add-on-Feld für deklarative Konfiguration ohne manuelle Manifeständerung. | [37](37/de.md) |
| **connection draining** | Abbau aktiver Verbindungen beim Deregistrieren eines Targets; `deregistration_delay.timeout_seconds` ist standardmäßig 300. | [40](40/de.md) |
| **conntrack** | Verbindungstabelle des Node-Kernels; bei Überlauf werden neue Verbindungen verworfen. | [46](46/de.md) |
| **Consolidated billing** | Gemeinsame Organisationsrechnung; Mengenrabatte und Savings Plans gelten für alle Accounts. | [0.1](00-1-aws/de.md) |
| **Consolidation** | Freiwillige Verdichtung zur Kostensenkung mit Richtlinien `WhenEmpty` und `WhenEmptyOrUnderutilized` sowie dem Parameter `consolidateAfter`. | [11](11/de.md), [12](12/de.md) |
| **Container Insights** | CloudWatch-Monitoring für EKS mit Node-/Pod-Metriken, Dashboards und Alarmen. | [33](33/de.md) |
| **ContainerResource** | HPA-Metriktyp für die Auslastung eines einzelnen Pod-Containers statt aller Container. | [35](35/de.md) |
| **context propagation** | Weitergabe der `trace id` zwischen Diensten über Header, damit ein Trace nicht abreißt. | [36](36/de.md) |
| **continuous profiling** | Kontinuierliche Erfassung von CPU- und Speicher-Hotspots im Code. | [36](36/de.md) |
| **Control plane** | API-Server, Scheduler, Controller Manager und etcd; in EKS im AWS-Account außerhalb Ihrer VPC und nicht über `kubectl get pods -n kube-system` sichtbar. | [01](01/de.md) |
| **control plane logging** | Übermittlung der EKS-Steuerungsebenen-Logs `api`, `audit`, `authenticator`, `controllerManager` und `scheduler` nach CloudWatch Logs. | [34](34/de.md) |
| **core-Add-ons** | `vpc-cni`, `kube-proxy`, `coredns`: obligatorischer Kern jedes Clusters. | [37](37/de.md) |
| **cost allocation** | Verteilung von AWS-Kosten auf Kubernetes-Objekte nach Verbrauch oder requests. | [43](43/de.md) |
| **cost allocation tags** | AWS-Tags zur Rechnungsaufteilung; benutzerdefinierte Tags müssen in Billing aktiviert werden. | [43](43/de.md) |
| **Cost and Usage Report** | Detaillierte AWS-Abrechnung in S3; Athena ermöglicht OpenCost/Kubecost den Abgleich mit der realen Rechnung. | [43](43/de.md) |
| **Cost Anomaly Detection** | AWS-Dienst zur ML-Erkennung ungewöhnlicher Kostensteigerungen mit E-Mail- oder SNS-Alarmen. | [43](43/de.md) |
| **crash-consistent / application-consistent** | Snapshot ohne Schreibstopp gegenüber Snapshot mit Anwendungskonsistenz. | [41](41/de.md) |
| **Cross-account ENI** | Schnittstellen, die EKS in Ihren Subnets für die Verbindung von control plane, Nodes, Webhooks und OIDC anlegt. | [02](02/de.md) |
| **cross-AZ traffic** | Datenübertragung zwischen Availability Zones, üblicherweise in beide Richtungen kostenpflichtig. | [31](31/de.md) |
| **cross-zone load balancing** | Verteilung auf Ziele in allen Zonen; gleichmäßigere Last, aber mehr cross-AZ-Traffic. | [31](31/de.md) |
| **Custom networking** | Modus, in dem sekundäre ENIs und Pod-Adressen aus dem Subnet und den Security Groups eines `ENIConfig` kommen, das über `ENI_CONFIG_LABEL_DEF` ausgewählt wird. | [07](07/de.md) |
| **custom.metrics.k8s.io** | API für benutzerdefinierte Metriken von Clusterobjekten für HPA. | [35](35/de.md) |
| **Data Firehose** | Verwalteter Buffer und Router für Datenströme zu S3, OpenSearch und weiteren Zielen. | [34](34/de.md) |
| **Data plane** | Ihre Nodes und alles, was auf ihnen läuft. | [01](01/de.md) |
| **Delegated administrator** | Organisationsaccount, der GuardDuty/Security Hub für die Organisation verwaltet und die Findings aller Mitglieder sieht. | [0.1](00-1-aws/de.md), [21](21/de.md) |
| **`deletionProtection`** | Flag, das die Löschung des Clusters verhindert. | [04](04/de.md) |
| **deprecated / removed API** | Eine `apiVersion` wird als veraltet markiert und später entfernt; danach lassen sich Manifeste damit nicht anwenden. | [38](38/de.md) |
| **describe-addon-versions** | EKS-API-Operation für Add-on-Versionen, Kubernetes-Minor-Kompatibilität und `defaultVersion`. | [37](37/de.md) |
| **`describe-target-health`** | Befehl, der Zustand und Ursache für Target-Group-Ziele anzeigt. | [46](46/de.md) |
| **Digest** | `sha256`-Hash des Image-Inhalts, ein unveränderlicher Identifikator. | [20](20/de.md) |
| **Disruption budget** | Begrenzung freiwilliger Unterbrechungen nach Node-Anteil/-Anzahl, `schedule`, `duration` und `reasons`. | [12](12/de.md) |
| **DNS-01** | ACME-Nachweis der Domaininhaberschaft per TXT-Eintrag; cert-manager erstellt ihn in Route 53. | [29](29/de.md) |
| **Drift** | Abweichung einer Node vom gewünschten Zustand; wird vor consolidation behandelt. | [12](12/de.md) |
| **Dual-stack** | VPC und Subnets mit IPv4 und IPv6 (`/56` und `/64`); IPv6 beseitigt Adressmangel für Pods. | [0.3](00-3-vpc/de.md) |
| **EBS / instance store** | Netzwerkvolume in einer AZ / flüchtiges lokales NVMe. | [0.4](00-4-ec2/de.md) |
| **EBS CSI-Treiber** | `aws-ebs-csi-driver`, verwaltetes Add-on mit Provisioner `ebs.csi.aws.com` für den EBS-Volume-Lebenszyklus. | [23](23/de.md) |
| **EC2NodeClass** | CRD (`karpenter.k8s.aws/v1`) für AMI, IAM-Rolle, Subnets, SGs, Datenträger und IMDS. | [12](12/de.md) |
| **ECR** | Verwaltete AWS-Registry für OCI-Images, privat je Account/Region unter `<account-id>.dkr.ecr.<region>.amazonaws.com` oder öffentlich unter `public.ecr.aws`. | [20](20/de.md) |
| **EFS** | Amazon Elastic File System, verwaltetes regionales NFS mit elastischer Kapazität und ReadWriteMany. | [24](24/de.md) |
| **EFS CSI-Treiber** | `aws-efs-csi-driver`, verwaltetes Add-on mit Provisioner `efs.csi.aws.com`. | [24](24/de.md) |
| **EKS audit log** | control-plane-Logtyp `audit` mit Kubernetes-Audit-JSON: wer, welcher verb, Ressource, Quelle und Ergebnis. | [21](21/de.md) |
| **EKS authenticator** | control-plane-Webhook, der das presigned STS-Token prüft und IAM-Identität einem Kubernetes-Subjekt zuordnet. | [47](47/de.md) |
| **EKS Auto Mode** | AWS verwaltet Appliance-Nodes, Skalierung mit Karpenter sowie integriertes Netzwerk, DNS, EBS CSI und ELB. | [01](01/de.md), [09](09/de.md) |
| **EKS Cluster State** | Kubernetes-Objektmanifeste wie Secret, ConfigMap, StatefulSet, PVC, RBAC und CRD sowie Clusterkonfiguration. | [41](41/de.md) |
| **EKS Pod Identity** | Zuweisung einer IAM-Rolle an einen Pod über Node-Agent und EKS-API, ohne Cluster-OIDC-Provider. | [17](17/de.md), [47](47/de.md) |
| **EKS Pod Identity Agent** | Add-on `eks-pod-identity-agent` als `DaemonSet`, das Pods temporäre Zugangsdaten über einen lokalen Endpoint ausgibt. | [17](17/de.md) |
| **EKS-optimiertes AMI** | AWS-Image mit passenden Node-Komponenten; Familien AL2023, Bottlerocket, Windows und auslaufendes AL2. | [10](10/de.md) |
| **eksctl** | Offizielle EKS-CLI auf Basis von CloudFormation, imperativ nutzbar. | [0.5](00-5-tools/de.md) |
| **enableNetworkPolicy** | Parameter des verwalteten VPC-CNI-Add-ons `enableNetworkPolicy` zum Durchsetzen von standardmäßigem NetworkPolicy. | [30](30/de.md) |
| **Encryption at rest** | Verschlüsselung von ECR-Layern: standardmäßig SSE-S3, optional SSE-KMS mit `aws/ecr`; nur beim Anlegen festlegbar. | [20](20/de.md) |
| **endpoint service** | Veröffentlichung eines eigenen NLB-basierten Dienstes als PrivateLink-Ziel für andere VPCs und Accounts. | [31](31/de.md) |
| **`endpointPublicAccess` / `endpointPrivateAccess`** | Boolesche Flags des Endpoint-Zugriffsmodus; standardmäßig `true` und `false`. | [02](02/de.md) |
| **enforcer** | CNI-Komponente, die NetworkPolicy in echte Traffic-Filter umsetzt. | [30](30/de.md) |
| **Enhanced subnet discovery** | Subnets mit Tag `kubernetes.io/role/cni=1` ohne `ENIConfig`. | [07](07/de.md) |
| **ENI** | Elastic Network Interface; Anzahl der ENIs und IPv4-Adressen hängt vom Instanztyp ab. | [0.3](00-3-vpc/de.md), [06](06/de.md) |
| **Envelope encryption** | Zwei-Schlüssel-Verschlüsselung: DEK verschlüsselt Daten, KEK verschlüsselt den DEK. | [18](18/de.md) |
| **ephemeral ports** | Hoher Portbereich `1024-65535` für Rückverkehr, der in NACLs manuell erlaubt wird. | [46](46/de.md) |
| **eviction threshold** | Speicherschwelle, unterhalb der kubelet Pods verdrängt. | [14](14/de.md) |
| **exec-Plugin in kubeconfig** | Abschnitt `exec`, der `aws eks get-token` aufruft; `client-go` cached Credentials bis `status.expirationTimestamp`. | [0.5](00-5-tools/de.md) |
| **Expander** | Cluster-Autoscaler-Strategie zur Node-Group-Wahl, etwa `least-waste`, `priority`, `most-pods`, `random`. | [11](11/de.md) |
| **Extended support** | Phase nach standard support mit weiter unterstützter Version gegen erhöhten Stundensatz. | [03](03/de.md), [38](38/de.md) |
| **External Secrets Operator (ESO)** | Controller, der AWS-Secrets liest und native `Secret` erstellt; mit `SecretStore`, `ClusterSecretStore` und `ExternalSecret`. | [18](18/de.md) |
| **external-dns** | Controller, der DNS-Einträge aus Kubernetes-Objekten mit einem Provider wie Route 53 synchronisiert. | [29](29/de.md) |
| **external.metrics.k8s.io** | API externer Metriken für HPA, etwa Queues und Topics. | [35](35/de.md) |
| **externalTrafficPolicy** | Service-Richtlinie: `Cluster` leitet auf beliebige Nodes weiter und SNATt, `Local` nur auf lokale Pods und erhält die Client-IP. | [26](26/de.md) |
| **`failed to assign an IP address to container`** | VPC CNI konnte dem Pod keine IP geben: Node oder Subnet enthält keine freien Adressen mehr. | [46](46/de.md) |
| **failurePolicy** | Reaktion auf nicht verfügbaren Webhook: `Fail` stoppt admission, `Ignore` lässt das Objekt passieren. | [22](22/de.md) |
| **Fargate** | Ausführung eines Pods in einer eigenen Mikro-VM ohne Nodes; keine DaemonSets, Privilegien, `HostNetwork`, GPUs oder Node-Zugriff. | [09](09/de.md) |
| **fargate-scheduler** | EKS-Scheduler neben kube-scheduler, der passende Profil-Pods auf Fargate lenkt. | [15](15/de.md) |
| **Fargate-Profil** | Clusterobjekt mit Selektoren, pod execution role und privaten Subnets; nur durch Neuerstellung änderbar. | [15](15/de.md) |
| **Finding** | GuardDuty-Befund, der zu Security Hub und EventBridge für Alarmierung und Reaktion gelangt. | [21](21/de.md) |
| **Fluent Bit** | Leichter C-Log-Forwarder als DaemonSet auf jeder Node; liest, ergänzt und sendet Logs. | [34](34/de.md) |
| **Forbidden (403)** | Autorisierungsfehler: RBAC erlaubt die Aktion nicht. | [47](47/de.md) |
| **game day** | Übung, bei der DR- und Incident-Szenarien praktisch erprobt werden. | [48](48/de.md) |
| **Gatekeeper** | OPA-basierte Policy Engine mit Rego und dem Modell aus `ConstraintTemplate` und `Constraint`. | [22](22/de.md) |
| **Gateway** | Eintrittspunkt mit Listenern für Protokoll, Port und TLS; in VPC Lattice einer Service Network zugeordnet. | [28](28/de.md) |
| **Gateway API** | Kubernetes-Standard für Traffic-Management und Nachfolger von Ingress mit typisierten Ressourcen und Rollenaufteilung. | [28](28/de.md) |
| **gateway endpoint** | VPC-Endpoint-Typ für S3 und DynamoDB durch Route-Table-Eintrag; kostenlos. | [25](25/de.md), [31](31/de.md) |
| **GatewayClass** | Implementierungsvorlage mit `controllerName`, die den Gateway verarbeitenden Controller bestimmt. | [28](28/de.md) |
| **GitOps** | Modell, in dem Git den gewünschten Zustand beschreibt und ein Agent den Cluster fortlaufend daran angleicht. | [44](44/de.md) |
| **GitOps Toolkit** | Satz von Flux-Controllern für source, kustomize, helm, image und mehr. | [44](44/de.md) |
| **Golden image** | Reproduzierbares, angepasstes Image auf Basis eines optimierten AMI, erstellt per image builder. | [10](10/de.md) |
| **graceful node shutdown** | kubelet-Funktion zum Beenden von Pods innerhalb der grace period beim OS-Herunterfahren. | [40](40/de.md) |
| **Grafana Loki** | Logspeicher, der nur Stream-Labels indiziert, Logs komprimiert ablegt und LogQL verwendet. | [34](34/de.md) |
| **`granted` (`assume`)** | Schneller Wechsel von SSO-Profilen und Konsolenanmeldung. | [0.5](00-5-tools/de.md) |
| **Graviton** | AWS-arm64-Prozessoren mit Suffix `g`; benötigen Multi-Arch-Images. | [0.4](00-4-ec2/de.md) |
| **GuardDuty EKS Protection** | Bedrohungsanalyse der EKS-Audit-Logs über einen unabhängigen GuardDuty-Strom. | [21](21/de.md) |
| **GuardDuty Runtime Monitoring** | Beobachtung des Node-Verhaltens über `aws-guardduty-agent` und eBPF; unterstützt kein Fargate und keine Hybrid Nodes. | [21](21/de.md) |
| **Hard multi-tenancy** | Mandanten in getrennten Clustern/Accounts: starke Grenze bei höherer Komplexität. | [22](22/de.md) |
| **HashiCorp Vault** | Externer Secrets-Speicher; Pod-Authentifizierung über Kubernetes, JWT/OIDC oder AWS IAM auth und Bereitstellung durch mehrere Vault-Integrationen. | [18](18/de.md) |
| **head-based und tail-based sampling** | Aufnahmeentscheidung beim Eingang gegenüber Entscheidung nach Aufbau des Traces im Gateway. | [36](36/de.md) |
| **helmfile** | Deklarative Beschreibung mehrerer Helm-Releases samt Versionen und values. | [0.5](00-5-tools/de.md) |
| **hop limit (`httpPutResponseHopLimit`)** | Anzahl Netzwerkhops der IMDS-Antwort; bei 1 erreicht der Pod IMDS nicht. | [19](19/de.md) |
| **hosted zone** | Container von DNS-Einträgen einer Domain in Route 53; public oder VPC-gebunden private. | [29](29/de.md) |
| **HPA (HorizontalPodAutoscaler)** | Controller, der die Replica-Zahl eines Deployment anhand von Metriken ändert. | [35](35/de.md) |
| **HTTPRoute** | Regeln für Host-, Path- und Header-Routing zu Backends, mit Gateway-Referenz über `parentRefs`. | [28](28/de.md) |
| **hub-and-spoke** | Topologie mit zentralem Transit Gateway und angeschlossenen Team-VPCs. | [32](32/de.md) |
| **Hubble** | Cilium-Observability mit Flusskarte und per-flow verdict. | [08](08/de.md), [30](30/de.md) |
| **IAM Access Analyzer** | Findet externe Vertrauensbeziehungen in resource-based Policies und trust policies. | [0.2](00-2-iam/de.md) |
| **IAM auth policy** | IAM-formatierte Richtlinie zur Autorisierung des Datenverkehrs zwischen Diensten, im Controller als `IAMAuthPolicy`. | [28](28/de.md) |
| **IAM database authentication** | RDS-/Aurora-Anmeldung mit einem temporären Token aus `aws rds generate-db-auth-token` statt Passwort. | [18](18/de.md) |
| **IAM Identity Center** | Zentraler Login und Zugriffsvergabe über permission sets. | [0.1](00-1-aws/de.md) |
| **IAM OIDC identity provider** | IAM-Objekt für die issuer URL des Clusters, auf das Rollentrust-Policies verweisen. | [16](16/de.md) |
| **IAM role** | Identität ohne dauerhafte Schlüssel, die zeitweise angenommen wird. | [0.2](00-2-iam/de.md) |
| **IAM user / group** | Langlebige Identität und eine Menge solcher Identitäten; in Produktion vermeiden. | [0.2](00-2-iam/de.md) |
| **idle capacity** | Differenz zwischen bezahlter Node-Kapazität und tatsächlichem Verbrauch; Marker für überhöhte requests und schlechtes bin packing. | [43](43/de.md) |
| **image automation** | Flux-Controller, die neue Image-Tags nach Git zurückschreiben. | [44](44/de.md) |
| **IMDS** | Instance Metadata Service auf `169.254.169.254`; Quelle für Metadaten und Node-Rollenzugangsdaten; IMDSv2 verwendet `PUT` plus Token. | [0.2](00-2-iam/de.md), [0.4](00-4-ec2/de.md), [19](19/de.md) |
| **Immutable-Parameter** | Clusterparameter, der nach Erstellung nicht änderbar ist, etwa `ipFamily`, `serviceIpv4Cidr`, VPC, Name oder Cluster-IAM-Rolle. | [04](04/de.md) |
| **In-place upgrade** | Upgrade desselben Clusters auf die nächste Minor-Version: control plane, Add-ons, dann Nodes. | [03](03/de.md), [38](38/de.md) |
| **in-tree cloud provider** | In Kubernetes-Komponenten eingebauter AWS-Code, der standardmäßig einen Classic Load Balancer für LoadBalancer-Services erstellt. | [26](26/de.md) |
| **in-tree provisioner** | Eingebauter, veralteter `kubernetes.io/aws-ebs` ohne `gp3` und Snapshots; der Standard `gp2` ist ebenfalls in-tree. | [23](23/de.md) |
| **IngressClass alb** | Klasse mit Controller `ingress.k8s.aws/alb`; der LBC verarbeitet Ingress mit `ingressClassName: alb`. | [27](27/de.md) |
| **IngressGroup** | Bündelt Ingress über `group.name` auf einem ALB; `group.order` bestimmt die Regelpriorität. | [27](27/de.md) |
| **INPUT / FILTER / OUTPUT** | Drei Pipeline-Abschnitte von Fluent Bit: Lesen, Verarbeitung, Senden. | [34](34/de.md) |
| **`InsufficientCidrBlocks`** | EC2-API-Fehler wegen fehlender zusammenhängender Blöcke trotz formal freier Adressen. | [07](07/de.md) |
| **Interface endpoint** | PrivateLink-basierter VPC-Endpoint: ENI im Subnet, Stunden- und Datengebühr. | [31](31/de.md) |
| **Internet Gateway** | Kostenloses Gateway ins Internet für öffentliche Adressen. | [0.3](00-3-vpc/de.md) |
| **involuntary disruption** | Unkontrollierte Unterbrechung wie Node-/AZ-Ausfall, OOM oder Spot-Unterbrechung; Schutz erfolgt durch Verteilung, nicht PDB. | [40](40/de.md) |
| **ipamd** | Daemon in `aws-node`, der den Node-IP-Pool verwaltet, sekundäre Adressen bindet und ENIs per EC2 API erstellt. | [06](06/de.md) |
| **`ipFamily`** | Adressfamilie des Clusters, die nur bei der Erstellung festgelegt wird. | [07](07/de.md) |
| **IRSA** | IAM Roles for Service Accounts: IAM-Rolle für einen Pod über gebundenen `ServiceAccount` und OIDC-Föderation. | [0.2](00-2-iam/de.md), [16](16/de.md), [47](47/de.md) |
| **Karpenter** | Node-Autoscaler, der EC2-Instanzen direkt für konkrete unplatzierbare Pods erstellt und Typen selbst auswählt. | [11](11/de.md) |
| **KEDA** | Erweiterung für ereignisbasierte Autoskalierung; speist Metriken in HPA ein und steuert ihn. | [35](35/de.md) |
| **`kms:CreateGrant`** | Recht, das der Treiber zum Einhängen eines mit eigenem CMK erstellten EBS-Volumes braucht. | [23](23/de.md) |
| **krew** | Plugin-Manager mit Index, `search`, `install` und `upgrade`; unterstützt eigene Indizes. | [0.5](00-5-tools/de.md) |
| **kube-prometheus-stack** | Helm-Chart mit Prometheus Operator, Prometheus, Grafana, Alertmanager, node-exporter und kube-state-metrics. | [33](33/de.md) |
| **`kube-reserved` / `system-reserved`** | Vom kubelet für Kubernetes bzw. das Betriebssystem reservierte Ressourcen. | [14](14/de.md) |
| **kube-state-metrics** | Komponente, die Kubernetes-Objektzustände als Metriken ausgibt. | [33](33/de.md) |
| **Kubecost** | OpenCost-basiertes Produkt mit UI, Berichten und Empfehlungen; für EKS als optimiertes Bundle verfügbar. | [43](43/de.md) |
| **`kubectl plugin list`** | Zeigt, was kubectl in `PATH` findet. | [0.5](00-5-tools/de.md) |
| **`kubeProxyReplacement`** | Cilium-Modus, in dem eBPF Service-/NodePort-Load-Balancing statt kube-proxy übernimmt; `true` aktiviert die Ersetzung. | [08](08/de.md) |
| **Kustomization / HelmRelease** | Flux-CRDs, die beschreiben, was aus einer Quelle wohin angewendet wird. | [44](44/de.md) |
| **Kyverno** | Policy Engine mit YAML-Ressourcen `ClusterPolicy`/`Policy` und Regeln validate/mutate/generate/verifyImages mit `Enforce` oder `Audit`. | [22](22/de.md) |
| **Landing zone** | Vorgefertigte Multi-Account-Struktur für Management, Shared Services, Umgebungen und Teams. | [0.1](00-1-aws/de.md), [32](32/de.md) |
| **Launch template** | Versionierte Instanzvorlage für AMI, Typ, Datenträger, SG, user data und IMDS. | [10](10/de.md) |
| **Launch template / Auto Scaling group** | Versionierte Startvorlage / Instanzgruppe mit `min`, `desired`, `max` über AZ-Subnets. | [0.4](00-4-ec2/de.md) |
| **Lifecycle policy** | Regeln zum automatischen Löschen von Images nach Alter oder Anzahl. | [20](20/de.md) |
| **limits** | Obergrenze des Ressourcenverbrauchs eines Containers. | [14](14/de.md) |
| **log group / log stream** | Gruppe, meist pro Anwendung, und Stream darin, meist pro Pod, in CloudWatch Logs. | [34](34/de.md) |
| **Managed / inline policy** | Wiederverwendbare versionierte Richtlinie / direkt in eine Rolle eingebettete Richtlinie. | [0.2](00-2-iam/de.md) |
| **Managed addon (EKS managed addon)** | Von AWS betreute Clusterkomponente, deren Version EKS per eigener API verwaltet. | [0.5](00-5-tools/de.md), [01](01/de.md), [37](37/de.md) |
| **managed collector (scraper)** | Verwalteter agentloser AMP-Sammler, der EKS-Metriken abruft und per remote-write in einen Workspace schreibt. | [33](33/de.md) |
| **managed fields / server-side apply** | Mechanismus, mit dem ein Add-on seine Felder erklärt und anwendet; Grundlage der Konfliktauflösung. | [37](37/de.md) |
| **Managed node group** | EKS-verwaltete EC2-Gruppe: AWS verwaltet ASG und Launch Template; OS und Node-Inhalt bleiben Ihre Verantwortung. | [01](01/de.md), [09](09/de.md) |
| **Management account** | Root-Zahleraccount der Organisation; Workloads gehören nicht dorthin. | [0.1](00-1-aws/de.md) |
| **`matchLabelKeys`** | Pod-Label-Schlüssel, die dem `labelSelector` einer Verteilungsbeschränkung hinzugefügt werden, etwa `pod-template-hash`. | [40](40/de.md) |
| **max-pods** | Pod-Limit einer Node: `ENI * (IP pro ENI - 1) + 2`; bei Managed Node Groups begrenzt. | [0.4](00-4-ec2/de.md), [06](06/de.md), [46](46/de.md) |
| **maxSkew** | Zulässige Differenz der Pod-Anzahl zwischen vollster und leerster Domäne. | [40](40/de.md) |
| **`memory_limiter`** | Collector-Prozessor zur Begrenzung des Speicherverbrauchs; lehnt Daten vor `OOMKilled` ab. | [36](36/de.md) |
| **metric_relabel_configs** | Scrape-Konfiguration mit `metricRelabelings`, um per `drop` auf `__name__` oder `labeldrop` hochkardinale Metriken und Labels vor Speicherung und remote-write zu verwerfen. | [33](33/de.md) |
| **Metrics API (`metrics.k8s.io`)** | Kubernetes-API aktueller Ressourcenmetriken für `kubectl top` und HPA. | [33](33/de.md), [35](35/de.md) |
| **metrics-server** | Sammelt CPU und Speicher vom kubelet und stellt sie über Metrics API für `kubectl top` und HPA bereit. | [33](33/de.md) |
| **mount target** | EFS-Netzwerkschnittstelle in einem AZ-Subnet; Zugangspunkt für Nodes dieser Zone. | [24](24/de.md) |
| **Mountpoint for Amazon S3** | Client, der Bucket-Objekte über eine Dateischnittstelle anbietet; Grundlage des CSI-Treibers. | [25](25/de.md) |
| **Mountpoint S3 CSI-Treiber** | `aws-mountpoint-s3-csi-driver`, verwaltetes Add-on mit Provisioner `s3.csi.aws.com`; nur statisches Provisioning. | [25](25/de.md) |
| **must have** | Punkt, ohne den ein Produktionsstart gefährlich ist und blockiert werden muss. | [48](48/de.md) |
| **NACL** | Zustandsloser Filter auf Subnet-Ebene; eingehende und ausgehende Regeln sind unabhängig. | [46](46/de.md) |
| **namespace restore** | Gezielte Wiederherstellung von bis zu fünf Namespaces in einen bestehenden Cluster ohne clusterweite Ressourcen. | [42](42/de.md) |
| **NAT Gateway** | Verwalteter AWS-Dienst zur Adressübersetzung für Internet-Egress privater Subnets; Stunden- und Datengebühr. | [0.3](00-3-vpc/de.md), [31](31/de.md) |
| **`ndots:5`** | resolv.conf-Einstellung der Pods, durch die Namen über search-Domains probiert werden. | [46](46/de.md) |
| **nested (child) recovery point** | Verschachtelter Punkt in einem composite recovery point: Clusterzustand oder einzelnes Volume. | [41](41/de.md) |
| **Network ACL** | Zustandsloser Subnet-Filter mit allow und deny nach Regelnummern. | [0.3](00-3-vpc/de.md) |
| **`NETWORK_POLICY_ENFORCING_MODE`** | Modus beim Pod-Start: `standard` mit default allow und Policy-Fenster oder `strict` mit default deny. | [08](08/de.md), [30](30/de.md) |
| **NetworkPolicy** | Standard-Kubernetes-Objekt für erlaubten Pod-Ingress und -Egress; ohne enforcer blockiert es nichts. | [30](30/de.md) |
| **nice to have** | Reifesteigernder Punkt, der auch nach dem Produktionsstart umgesetzt werden darf. | [48](48/de.md) |
| **NLB (Network Load Balancer)** | L4-Load-Balancer für TCP/UDP mit hoher Leistung und statischen IPs; LBC erstellt ihn aus LoadBalancer-Services. | [26](26/de.md) |
| **node instance role** | IAM-Rolle, die eine EC2-Node annimmt und mit der kubelet AWS-APIs aufruft. | [45](45/de.md) |
| **Node Termination Handler (NTH)** | AWS-Komponente zur Behandlung von Unterbrechungen bei managed und self-managed Nodes ohne Karpenter. | [13](13/de.md) |
| **nodeadm** | Node-Initialisierer für AL2023 und Bottlerocket mit YAML-Manifest `NodeConfig` mit `apiVersion: node.eks.aws/v1alpha1`; Nachfolger von `bootstrap.sh`. | [10](10/de.md), [45](45/de.md) |
| **NodeClaim** | Karpenter-Anforderung für eine konkrete Node, die `NodePool` und echte `Node` verbindet. | [12](12/de.md) |
| **NodeCreationFailure** | Health Issue einer Managed Node Group: Nodes traten dem Cluster binnen 15 Minuten nicht bei. | [45](45/de.md) |
| **NodeLocal DNSCache** | Lokaler DNS-Cache auf der Node, der CoreDNS und per-ENI-Throttling entlastet. | [46](46/de.md) |
| **NodePool** | CRD (`karpenter.sh/v1`) für Node-Grenzen: `requirements`, `limits`, `weight`, labels/taints und disruption policy. | [12](12/de.md) |
| **NodePool und NodeClass** | Objekte, die beschreiben, welche Nodes wie bereitgestellt werden; im Auto Mode sind Standardobjekte unveränderlich. | [09](09/de.md) |
| **non-destructive restore** | Modus, der bestehende Objekte nicht überschreibt, sondern überspringt. | [42](42/de.md) |
| **NotReady bei aktivem kubelet** | Meist ist das CNI nicht bereit und Pods erhalten keine IPs. | [45](45/de.md) |
| **OIDC issuer URL** | Öffentlicher OIDC-Endpoint `oidc.eks.<region>.amazonaws.com/id/` des Clusters mit öffentlichen Signaturschlüsseln für projected tokens. | [16](16/de.md) |
| **On-demand / Spot** | Bedarfsbasierte Zahlung / rabattierte Kapazität mit Unterbrechung nach zwei Minuten. | [0.4](00-4-ec2/de.md) |
| **OOMKilled** | Beendigung eines Containers durch den Kernel bei Überschreitung des memory limit. | [14](14/de.md) |
| **OpenCost** | Offener, herstellerneutraler Standard und CNCF-Engine zur Kostenallokation aus Prometheus-Verbrauch und AWS-Ressourcenpreisen. | [43](43/de.md) |
| **OpenSearch Service** | Verwaltetes OpenSearch für Volltextsuche und Dashboards; Abrechnung pro Cluster/Node. | [34](34/de.md) |
| **OpenTelemetry (OTel)** | CNCF-Standard mit einheitlichen APIs, SDKs und Protokoll; trennt Instrumentierung und Backend. | [36](36/de.md) |
| **OpenTelemetry Collector** | Sammler: receivers empfangen, processors verarbeiten, exporters übertragen Telemetrie. | [36](36/de.md) |
| **OpenTelemetry Operator** | Operator für Auto-Instrumentierung durch Agent-Injektion in Pods. | [36](36/de.md) |
| **OpenTofu** | Offener Terraform-Fork, kompatibel mit den Kursmodulen; Wahl über `terraform_binary = "tofu"`. | [0.5](00-5-tools/de.md) |
| **OTLP** | Telemetrieübertragungsprotokoll von Anwendung zum Collector und zwischen Collectors. | [36](36/de.md) |
| **OU** | Gruppe von Accounts, auf die Richtlinien angewendet werden. | [0.1](00-1-aws/de.md) |
| **ownership** | Festgelegte Verantwortung für eine Domäne oder einen Checklistenpunkt. | [48](48/de.md) |
| **Permissions boundary** | Obergrenze der Rechte einer Rolle oder eines Benutzers; erteilt selbst keine Rechte. | [0.2](00-2-iam/de.md) |
| **Placement group** | Steuerung der Instanzplatzierung als `cluster`, `partition` oder `spread`. | [0.4](00-4-ec2/de.md) |
| **`placementGroupSelector`** | Feld einer eigenen `NodeClass`, das placement groups über `nodeSelector` und `eks.amazonaws.com/placement-group-id` auswählt. | [09](09/de.md), [12](12/de.md) |
| **Platform version** | Patch-Stand und Funktionsumfang der EKS-control-plane innerhalb einer Kubernetes-Minor-Version im Format `eks.<n>`. | [01](01/de.md), [02](02/de.md) |
| **pluto / kube-no-trouble (kubent)** | Werkzeuge zum Finden veralteter APIs: pluto in Git/Helm, kubent im laufenden Cluster. | [38](38/de.md) |
| **Pod execution role** | IAM-Rolle, mit der `kubelet` auf Fargate den Pod registriert und ECR-Images zieht; auch für integrierten Log-Router. | [15](15/de.md) |
| **Pod Identity association** | EKS-API-Eintrag für `Cluster + Namespace + ServiceAccount` und IAM-Rolle, erstellt mit `aws eks create-pod-identity-association`. | [17](17/de.md), [37](37/de.md) |
| **pod readiness gate** | Zusätzliche Pod-Ready-Bedingung; LBC hält `target-health.elbv2.k8s.aws` bis zum gesunden Target `healthy` auf false. | [40](40/de.md) |
| **Pod Security Admission (PSA)** | Eingebauter Admission-Controller, der Pod Security Standards per Namespace-Labels durchsetzt. | [19](19/de.md) |
| **Pod Security Standards** | Profile privileged, baseline und restricted für unterschiedlich strenge Sicherheit. | [19](19/de.md) |
| **`POD_SECURITY_GROUP_ENFORCING_MODE`** | `strict` ohne source NAT gegenüber `standard`, in dem VPC-Traffic die primäre ENI und Node-SG nutzt. | [46](46/de.md) |
| **PodDisruptionBudget (PDB)** | Objekt zur Begrenzung gleichzeitig freiwillig verdrängter Pods mittels `minAvailable`/`maxUnavailable`. | [40](40/de.md) |
| **`pods.eks.amazonaws.com`** | Dienstprinzipal in der Trust Policy einer Pod-Identity-Rolle; Credentials stellt EKS über `AssumeRoleForPodIdentity` aus. | [17](17/de.md) |
| **Policy** | JSON mit `Version`, `Statement`, `Effect`, `Action`, `Resource`, `Condition`; identity- oder resource-based. | [0.2](00-2-iam/de.md) |
| **Policy engine** | Admission-Webhook mit eigenen Regeln, etwa Kyverno oder Gatekeeper, der Objekte vor etcd prüft und ggf. ändert. | [22](22/de.md) |
| **`pollingInterval` und `cooldownPeriod`** | KEDA-Quellabfrageintervall und Wartezeit vor dem Herunterskalieren auf null. | [35](35/de.md) |
| **Prefix delegation** | ENI-Slot enthält ein `/28`-Präfix mit 16 Adressen; aktiviert durch `ENABLE_PREFIX_DELEGATION`, benötigt Nitro. | [07](07/de.md), [46](46/de.md) |
| **preserve_client_ip** | NLB-Target-Group-Attribut für den Erhalt der Client-Quell-IP im `ip`-Modus. | [26](26/de.md) |
| **preStop** | Hook vor SIGTERM, etwa für eine Pause vor dem Beenden. | [40](40/de.md) |
| **Principal** | Die anfragende Entität: Benutzer, Rolle oder AWS-Dienst. | [0.2](00-2-iam/de.md) |
| **private / public endpoint** | Zugriffsmodus auf den API-Server des Clusters. | [45](45/de.md) |
| **Private hosted zone** | Route-53-Zone, die EKS erstellt und mit Ihrer VPC verbindet, damit der Endpoint privat aufgelöst wird. | [02](02/de.md) |
| **Projected service account token** | OIDC-kompatibler JWT mit SA-Identität, Audience `sts.amazonaws.com` und Laufzeit, den STS gegen Credentials tauscht. | [16](16/de.md) |
| **prometheus-adapter** | Adapter, der Prometheus-Metriken im custom/external API veröffentlicht. | [35](35/de.md) |
| **provisioningMode: efs-ap** | StorageClass-Modus, in dem der Treiber für jeden PVC einen access point erzeugt. | [24](24/de.md) |
| **`publicAccessCidrs`** | Liste zulässiger CIDRs für den public endpoint; standardmäßig `0.0.0.0/0`. | [02](02/de.md) |
| **Pull through cache** | ECR-Regel, die Images externer Registries wie `registry.k8s.io` bei Abruf im privaten ECR cached. | [20](20/de.md) |
| **pull-Modell** | Agent im Cluster zieht aus Git; bei push aktualisiert eine externe Pipeline. | [44](44/de.md) |
| **QoS-Klasse** | `Guaranteed`, `Burstable` oder `BestEffort`; bestimmt die Eviction-Reihenfolge bei Speichermangel. | [14](14/de.md) |
| **ReadWriteMany (RWX)** | Access mode, bei dem viele Pods auf vielen Nodes ein Volume gleichzeitig schreibend einhängen. | [24](24/de.md) |
| **Rebalance recommendation** | Frühes Signal eines erhöhten Entzugsrisikos vor der zweiminütigen Spot-Unterbrechungsmitteilung. | [13](13/de.md) |
| **recovery point** | Wiederherstellungspunkt als Ergebnis eines erfolgreichen backup job. | [41](41/de.md) |
| **ReferenceGrant** | Gateway-API-Ressource im Ziel-Namespace, die Cross-Namespace-Referenzen über `backendRefs` und `certificateRefs` erlaubt. | [28](28/de.md) |
| **Replication configuration** | ECR-Regeln zum Kopieren von Images in andere Regionen und Accounts; kontoübergreifend benötigt der Empfänger `ecr:CreateRepository` und `ecr:ReplicateImage`. | [20](20/de.md) |
| **Repository creation template** | Vorlage für Verschlüsselung, Lifecycle, Immutability und Policy von Cache-Repositories, deren Standard `MUTABLE` ist. | [20](20/de.md) |
| **Repository policy / registry policy** | Resource-based Policies für ein Repository bzw. eine gesamte Account-Registry, einschließlich `aws:PrincipalOrgID`. | [20](20/de.md), [32](32/de.md) |
| **requests** | Ressourcenmenge für packing und Autoscaler-Entscheidung; Reservierung für den Pod. | [14](14/de.md) |
| **resolveConflicts** | Add-on-Verhalten bei Feldkonflikten: `NONE`, `OVERWRITE`, `PRESERVE`. | [37](37/de.md) |
| **Resource Modifiers** | Velero-ConfigMap mit JSON-Patches für Objekte beim Restore, konfiguriert über `--resource-modifier-configmap`. | [42](42/de.md) |
| **ResourceQuota / LimitRange** | Namespace-Gesamtverbrauchslimit bzw. Standardwerte und Grenzen je Container. | [22](22/de.md) |
| **restore hook** | Init-Container oder exec-Befehl, den Velero beim Pod-Restore ausführt. | [42](42/de.md) |
| **restore job** | Wiederherstellungsauftrag in AWS Backup, steuerbar mit `start-restore-job` und abfragbar mit `list-restore-jobs` sowie `describe-restore-job`. | [42](42/de.md) |
| **retention policy** | Aufbewahrungsfrist der Logs in einer log group; standardmäßig laufen Logs nicht ab. | [34](34/de.md) |
| **right-sizing** | Anpassung von requests/limits an den realen Verbrauch zur Node-Verdichtung. | [14](14/de.md), [43](43/de.md) |
| **rollback readiness** | Bereitschaft zum Versionsrollback: Fenster und Reihenfolge sind bekannt. | [48](48/de.md) |
| **rollback readiness insights** | `ROLLBACK_READINESS`-Clusterinsights mit PASSING/WARNING/ERROR/UNKNOWN. | [39](39/de.md) |
| **Root-Benutzer** | Account-Inhaber mit unbegrenzten Rechten, nur für die Ersteinrichtung erforderlich. | [0.1](00-1-aws/de.md) |
| **Route 53 Resolver** | Integriertes VPC-DNS unter „CIDR plus 2“, Upstream für CoreDNS. | [0.3](00-3-vpc/de.md) |
| **Route table** | Routingtabelle eines Subnets; public und private unterscheiden sich nur durch die Standardroute. | [0.3](00-3-vpc/de.md) |
| **RPO** | Zulässiger Datenverlust, bestimmt durch die Backup-Frequenz. | [42](42/de.md) |
| **RTO** | Zielzeit für die Wiederherstellung eines Dienstes nach einem Ausfall. | [42](42/de.md) |
| **S3 Express One Zone** | Zonale Speicherklasse mit geringer Latenz und hohem IOPS in einer AZ; unterstützt im Gegensatz zu General-Purpose-Buckets `append`. | [25](25/de.md) |
| **S3 Object Lock** | WORM-Schutz eines S3-Buckets mit unveränderlichen Objektversionen für die retention. | [42](42/de.md) |
| **sampling** | Aufzeichnung nur eines Anteils aller Traces zur Begrenzung von Volumen und Kosten. | [36](36/de.md) |
| **sampling rules** | X-Ray-Regeln für den Anteil aufgezeichneter Requests über reservoir und fixed rate. | [36](36/de.md) |
| **Savings Plans / RI** | Rabatt von 30-70 % gegen eine Verpflichtung für ein oder drei Jahre. | [0.4](00-4-ec2/de.md) |
| **scale-to-zero** | Herunterskalieren eines Deployment auf null Replikate im Leerlauf; KEDA kann das, HPA nicht. | [35](35/de.md) |
| **ScaledJob** | KEDA-CRD zur Skalierung paralleler Jobs für Arbeitspakete. | [35](35/de.md) |
| **ScaledObject** | KEDA-CRD für Skalierungsziel und Trigger eines Deployment. | [35](35/de.md) |
| **scaler** | KEDA-Metrikquelle wie `aws-sqs-queue`, `aws-cloudwatch`, `prometheus`, `kafka` oder `cron`. | [35](35/de.md) |
| **Schedule** | Velero-Objekt für regelmäßige cron-Backups und RPO. | [42](42/de.md) |
| **SCP (Service Control Policy)** | Beschränkende Policy auf OU oder Account, die maximale Rechte vorgibt und selbst nichts erlaubt. | [0.1](00-1-aws/de.md), [0.2](00-2-iam/de.md) |
| **Secondary CIDR** | Zusätzlicher IPv4-Block einer VPC, für EKS häufig aus `100.64.0.0/10`. | [07](07/de.md) |
| **Secrets Store CSI Driver + AWS provider (ASCP)** | Treiber zum Einhängen von AWS-Secrets als Dateien in ein Node-Volume über `SecretProviderClass`, optional als `Secret`. | [18](18/de.md) |
| **Security group** | Stateful Firewall an ENIs mit nur allow-Regeln; Quelle kann eine andere SG sein. | [0.3](00-3-vpc/de.md), [46](46/de.md) |
| **`SecurityGroupPolicy`** | Ressource, die SGs per Selector an Pods bindet; ein Pod mit branch ENI erbt die Node-SG nicht mehr. | [46](46/de.md) |
| **self-heal** | Automatische Rückführung von Drift auf den Zustand aus Git. | [44](44/de.md) |
| **self-managed addon** | Per Helm oder Manifest installiertes Add-on; Lebenszyklus und Kompatibilität liegen vollständig beim Engineering. | [37](37/de.md) |
| **Self-managed node** | Selbst erstellte und eingebundene EC2-Instanz mit access entry `EC2_LINUX`; der gesamte Node-Lebenszyklus liegt bei Ihnen. | [09](09/de.md) |
| **service map** | Karte von Diensten und Verbindungen mit Latenz und Fehleranteil an den Kanten. | [36](36/de.md) |
| **Service Network** | VPC-Lattice-Grenze für eine Dienstmenge; Client-VPCs werden für Zugriff zugeordnet. | [28](28/de.md) |
| **Service Quotas** | Pro Account und Region geltende Service-Limits, die auf Anfrage erhöhbar sind. | [0.1](00-1-aws/de.md) |
| **`serviceIpv4Cidr`** | Virtueller, nicht mit der VPC verbundener Service-Adressbereich. | [06](06/de.md) |
| **ServiceMonitor, PodMonitor** | Prometheus-Operator-CRDs, die deklarativ beschreiben, welche Endpoints abgerufen werden. | [33](33/de.md) |
| **Session tags** | Session-Tags für Cluster, Namespace und SA, die Pod Identity an STS übergibt; ABAC nutzen `aws:PrincipalTag/kubernetes-namespace`, `aws:PrincipalTag/eks-cluster-name` und `sts:TagSession`. | [17](17/de.md) |
| **shared costs** | Gemeinsame Clusterkosten wie control plane, System-Namespaces und idle capacity, die Teams nach Regel zugerechnet oder separat gezeigt werden. | [43](43/de.md) |
| **Shared responsibility** | AWS verantwortet die Sicherheit der Cloud, Sie die Sicherheit in der Cloud. | [0.1](00-1-aws/de.md), [01](01/de.md) |
| **shared services account** | Account mit gemeinsamen Ressourcen wie ECR, privaten DNS-Zonen und Observability für andere Accounts. | [32](32/de.md) |
| **shared VPC** | Modell, bei dem ein Eigentümer Subnets via RAM teilt und andere Accounts dort Ressourcen wie EKS-Nodes betreiben. | [32](32/de.md) |
| **showback** | Teams sehen ihre Kosten, ohne dass Geld umgebucht wird. | [43](43/de.md) |
| **SNAT** | Ersetzung der Quelladresse durch die Node-Adresse für Pod-Egress; deaktivierbar mit `AWS_VPC_K8S_CNI_EXTERNALSNAT`. | [06](06/de.md) |
| **Soft multi-tenancy** | Mandanten in einem Cluster mit Namespace, RBAC, Quotas, Limits, NetworkPolicy und Policies. | [22](22/de.md) |
| **span** | Einzelne Operation eines Traces mit Zeit und Attributen; aus spans entsteht ein Trace-Baum. | [36](36/de.md) |
| **split-horizon DNS** | Ein Name mit unterschiedlichen Antworten außerhalb und innerhalb der VPC über public/private Zonen. | [29](29/de.md) |
| **Spot interruption notice** | Unterbrechungsmitteilung zwei Minuten vor Stopp oder Terminierung einer Instanz. | [13](13/de.md) |
| **Spot-Instanz** | Rabattierte freie EC2-Kapazität, die AWS bei On-demand-Bedarf jederzeit zurückfordern kann. | [13](13/de.md) |
| **Spot-Pool** | Kombination aus Instanztyp und Availability Zone; Kapazität wird poolweise zurückgenommen. | [13](13/de.md) |
| **ssl-redirect** | Annotation für HTTP-zu-HTTPS-Weiterleitung auf einen Listener-Port. | [27](27/de.md) |
| **SSM Session Manager** | Zugriff auf eine Instanz ohne SSH über den SSM-Agent. | [45](45/de.md) |
| **Staging labels** | Secrets-Manager-Versionslabels: `AWSCURRENT`, `AWSPENDING`, `AWSPREVIOUS`. | [18](18/de.md) |
| **Stakater Reloader** | Controller für rolling restart eines Deployment bei Änderung eingebundener `Secret` oder `ConfigMap`. | [18](18/de.md) |
| **Standard support** | Supportphase einer EKS-Minor-Version von etwa 14 Monaten ohne Versionsaufschlag. | [03](03/de.md), [38](38/de.md), [48](48/de.md) |
| **State** | Zuordnungsdatei zwischen Terraform-Code und echten Ressourcen; in S3 mit Versionierung und Schreibsperre. | [0.5](00-5-tools/de.md), [04](04/de.md) |
| **stdout/stderr** | Standardausgabeströme des Containers; Kubernetes-Anwendungen schreiben Logs konventionsgemäß dorthin. | [34](34/de.md) |
| **STS** | Dienst für temporäre Zugangsschlüssel; `sts:AssumeRole`, `sts:AssumeRoleWithWebIdentity`. | [0.2](00-2-iam/de.md) |
| **Subnet CIDR reservation** | Reservierung eines zusammenhängenden Blocks im Subnet für Präfixe. | [07](07/de.md) |
| **subnet IP exhaustion** | Im Subnet gibt es keine freien Adressen mehr für ENIs und Pods. | [46](46/de.md) |
| **sync waves** | Reihenfolge der Ressourcenanwendung in Argo CD nach Wellen innerhalb der sync-Phasen. | [44](44/de.md) |
| **Tag immutability** | Repository-Modus `IMMUTABLE` verhindert das Überschreiben eines Tags; `MUTABLE` erlaubt es. | [20](20/de.md) |
| **target EKS cluster** | Bestehender Cluster für den Restore oder ein von AWS Backup mit `newCluster=true` während des Restore erstellter Cluster. | [42](42/de.md) |
| **target-type** | NLB-Zieltyp: `instance` über `NodePort` oder `ip` direkt auf Pod-IP; für Fargate obligatorisch. | [26](26/de.md), [27](27/de.md) |
| **`terminationGracePeriod`** | Obergrenze für Node-Drain; Drift erfolgt damit auch trotz blockierender PDB und `do-not-disrupt`. | [12](12/de.md) |
| **terminationGracePeriodSeconds** | Zeit zwischen SIGTERM und SIGKILL zum Beenden eines Pods; standardmäßig 30. | [40](40/de.md) |
| **terragrunt** | Terraform-Wrapper für gemeinsames Backend, `env.hcl`, `dependency`, `run-all` und DRY-Module. | [0.5](00-5-tools/de.md) |
| **Thanos** | Komponenten für langfristige Prometheus-Speicherung im Objektspeicher: `sidecar`, `store gateway`, `compactor`, `querier` und `ruler` für Abfragen und HA-Deduplizierung. | [33](33/de.md) |
| **throughput mode** | EFS-Durchsatzmodus: Elastic, Bursting oder Provisioned. | [24](24/de.md) |
| **topology aware routing** | Bevorzugung von Endpoints in der Client-Zone, aktivierbar mit `trafficDistribution: PreferClose`. | [31](31/de.md) |
| **topologySpreadConstraints** | Pod-Feld für gleichmäßige Replikaverteilung über Domänen mit `maxSkew`, `topologyKey`, `whenUnsatisfiable` und `minDomains`. | [40](40/de.md) |
| **trace** | Vollständiger Weg eines Requests durch Dienste mit gemeinsamer `trace id`. | [36](36/de.md) |
| **Transit Gateway** | Regionaler Router-Hub mit transitivem Routing zwischen VPCs, VPN und Direct Connect; via RAM teilbar. | [32](32/de.md) |
| **TriggerAuthentication** | KEDA-CRD mit Zugangsdaten für Trigger, in AWS über Provider `aws` mit IRSA oder Pod Identity. | [35](35/de.md) |
| **Trust policy** | Vertrauensrichtlinie einer Rolle mit `Federated`-Prinzipal, `Action` `sts:AssumeRoleWithWebIdentity` und `StringEquals` auf `sub`/`aud`. | [0.2](00-2-iam/de.md), [16](16/de.md), [47](47/de.md) |
| **TXT-Registry** | external-dns-Mechanismus, der eigene Einträge mit TXT-Markern kennzeichnet; Eigentümer über `--txt-owner-id`. | [29](29/de.md) |
| **Unauthorized (401)** | Authentifizierungsfehler: Identität ist nicht nachgewiesen oder nicht zugeordnet. | [47](47/de.md) |
| **`unhealthyPodEvictionPolicy`** | PDB-Feld: `IfHealthyBudget` verhindert bei bereits gestörter Anwendung die Verdrängung ungesunder Pods, `AlwaysAllow` erlaubt sie. | [40](40/de.md) |
| **upgrade insights** | Insight-Typ, der Upgrade-Bereitschaft und zu entfernende APIs markiert. | [38](38/de.md) |
| **Upgrade policy (`supportType`)** | Clusterkonfigurationsfeld `STANDARD`/`EXTENDED` für das Verhalten am Ende von standard support. | [03](03/de.md) |
| **`useCachedMetrics` und `fallback`** | Zwischenspeicherung eines Werts im Abfrageintervall und Replikazahl bei nicht verfügbarer Quelle, um `<unknown>` in `TARGETS` zu vermeiden. | [35](35/de.md) |
| **User data** | Skript oder Konfiguration beim ersten Instanzstart; startet Bootstrap und konfiguriert `kubelet`. | [0.4](00-4-ec2/de.md), [10](10/de.md) |
| **ValidatingAdmissionPolicy** | Im API-Server integrierte CEL-Validierung ohne externen Webhook, zusammen mit `ValidatingAdmissionPolicyBinding` und den Aktionen `Deny`, `Warn` oder `Audit`. | [22](22/de.md) |
| **Vault Lock** | WORM-Schutz eines Vaults gegen Backup-Löschung in governance- oder compliance-Modus. | [41](41/de.md) |
| **Velero** | Kubernetes-native Sicherung/Wiederherstellung; Objekte in S3, Volumes mit CSI-Snapshots oder File System Backup. | [42](42/de.md) |
| **velero-plugin-for-aws** | Offizielles Velero-Plugin für AWS mit S3 object store und EBS volume snapshotter. | [42](42/de.md) |
| **Version skew** | Nach Upstream-Policy zulässiger Rückstand von kubelet gegenüber dem API-Server. | [03](03/de.md), [37](37/de.md) |
| **version skew policy** | Kubernetes-Regel: Nodes dürfen nicht neuer als die control plane sein; bestimmt die Rollback-Reihenfolge. | [38](38/de.md), [39](39/de.md) |
| **VersionRollback** | Update-Typ in der Antwort von `update-cluster-version` bei einem Rollback. | [39](39/de.md) |
| **VictoriaLogs** | Schemafreie Logdatenbank mit spaltenorientierter Speicherung, LogsQL und mehreren Ingest-Protokollen; Cluster-Komponenten sind `vlinsert`, `vlstorage` und `vlselect`. | [34](34/de.md) |
| **VictoriaMetrics** | Metrikspeicher mit `vmagent`, `vmsingle` oder `vminsert`/`vmstorage`/`vmselect`, `vmalert` und `-retentionPeriod` für MetricsQL. | [33](33/de.md) |
| **volume node affinity conflict** | Scheduler-Ereignis, wenn die `nodeAffinity` eines Volumes auf eine Zone ohne passende Node verweist. | [23](23/de.md) |
| **`volumeBindingMode`** | Zeitpunkt des Volume-Provisioning: `Immediate` beim PVC oder `WaitForFirstConsumer` bei der Pod-Planung. | [23](23/de.md) |
| **VolumeSnapshot / Content / Class** | CSI-Snapshot-Objekte: Anfrage, AWS-Snapshot und Klasse. | [23](23/de.md) |
| **voluntary disruption** | Bewusste Pod-Verdrängung durch drain, Node-Upgrade oder consolidation; durch PDB geschützt. | [40](40/de.md) |
| **VPC** | Isoliertes Netzwerk in einer Region; primäres CIDR (`/16` bis `/28`) ist unveränderlich und nur per secondary CIDR erweiterbar. | [0.3](00-3-vpc/de.md) |
| **VPC CNI** | AWS-Netzwerkplugin, das Pods echte private Adressen aus VPC-Subnets gibt; `aws-node` DaemonSet in `kube-system`. | [06](06/de.md) |
| **VPC CNI network policy** | eBPF-Implementierung von `NetworkPolicy` mit control-plane-Controller und `aws-network-policy-agent` in `aws-node`, aktiviert über `enableNetworkPolicy`. | [08](08/de.md), [30](30/de.md) |
| **VPC endpoint** | Privater Zugang zu AWS-Diensten als gateway oder interface Endpoint. | [0.3](00-3-vpc/de.md), [31](31/de.md) |
| **VPC endpoint (PrivateLink)** | Privater Einstiegspunkt zu einem AWS-Dienst in der VPC; für private Datenebenen für ECR, S3, STS, EKS und mehr nötig. | [19](19/de.md) |
| **VPC Flow Logs** | Protokoll angenommener und abgelehnter Flüsse; `action = REJECT` in Logs Insights dient SecOps und Diagnose. | [0.3](00-3-vpc/de.md) |
| **VPC Lattice** | Verwalteter Application-Networking-Dienst für East-West-Kommunikation zwischen VPCs und Accounts ohne Sidecars und Peering. | [28](28/de.md) |
| **VPC peering** | Direkte Eins-zu-eins-Verbindung zweier VPCs; nicht transitiv und nur mit nicht überlappenden CIDRs. | [32](32/de.md) |
| **wafv2-acl-arn** | Annotation zum Binden einer AWS-WAF-v2-Web-ACL an einen ALB. | [27](27/de.md) |
| **warm pool** | Vorrat vorab zugeteilter IPv4-Adressen auf einer Node für schnellen Pod-Start. | [06](06/de.md) |
| **`WARM_PREFIX_TARGET`** | Vorrat an Präfixen auf einer Node; `WARM_IP_TARGET` und `MINIMUM_IP_TARGET` haben Vorrang. | [07](07/de.md) |
| **workspace** | Isolierter AMP-Metrikspeicher mit eigenem remote-write-Endpoint und Prometheus-kompatibler API. | [33](33/de.md) |
| **X-Amzn-Trace-Id** | X-Ray-Header mit `Root`, `Parent`, `Sampled`; ADOT ordnet ihn W3C `traceparent` mit gemeinsamem `trace id` zu. | [36](36/de.md) |
| **ZoneId (`euc1-az1`)** | Stabiles Verfügbarkeitszonen-Kürzel, in allen Accounts identisch. | [0.1](00-1-aws/de.md) |
| **Add-on `adot`** | Verwaltetes EKS-Add-on, das den ADOT Operator zur Verwaltung von Collectors bereitstellt. | [36](36/de.md) |
| **Account** | Isolierter Ressourcenraum und Abrechnungseinheit; seine 12-stellige Nummer kommt in ARN und trust policy vor. | [0.1](00-1-aws/de.md) |
| **Sekundäre private Adresse** | Zusätzliche IPv4-Adresse auf einer Node-ENI, die an einen Pod vergeben wird. | [06](06/de.md) |
| **Diversifizierung** | Viele Instanztypen in mehreren AZs, damit der Entzug eines Pools nicht einen kritischen Node-Anteil trifft. | [13](13/de.md) |
| **Readiness-Domäne** | Eine Betriebsachse wie control plane, Nodes, Sicherheit, Netzwerk, Speicher, Observability, Betrieb oder Incidents. | [48](48/de.md) |
| **Drift (Abweichung)** | Differenz des Istzustands zum in Code oder Git beschriebenen Sollzustand. | [04](04/de.md), [44](44/de.md) |
| **Abhängigkeit zwischen Stacks** | Übergabe der Outputs eines Stacks in die Inputs eines anderen, in Terragrunt über `dependency`. | [04](04/de.md) |
| **EC2-Instanz** | Virtuelle Maschine; in EKS eine Node mit containerd und kubelet. | [0.4](00-4-ec2/de.md) |
| **lokaler Cache** | Mountpoint-Datencache auf einem Node-Volume mit `cache: emptyDir` oder `ephemeral` für schnelleres erneutes Lesen; Metadaten-Cache via `metadata-ttl`. | [25](25/de.md) |
| **Skalierung von Nodes gegenüber Pods** | Unterschiedliche Ebenen: CA/Karpenter skalieren Nodes, HPA/VPA/KEDA Pods. | [11](11/de.md) |
| **Mikro-VM** | Dedizierte VM für einen Pod mit eigenem Kernel, CPU, Speicher und Netzwerkinterface; Fargate-Isolationsgrenze. | [15](15/de.md) |
| **Objektspeicher** | Schlüssel-Wert-Modell: unveränderliches Objekt aus Bytes und Metadaten unter einem String-Schlüssel; Updates vollständig per `PutObject`. | [25](25/de.md) |
| **Rollback-Fenster (7 Tage)** | Zeitraum nach einem Upgrade, in dem Rollback verfügbar ist; danach sind Rollback und Insights nicht verfügbar. | [39](39/de.md) |
| **kubectl-Plugin** | Datei `kubectl-<name>` in `PATH`, verfügbar als `kubectl <name>`. | [0.5](00-5-tools/de.md) |
| **Subnet** | Teil eines VPC-CIDR in einer Availability Zone. | [0.3](00-3-vpc/de.md) |
| **vollständiger Ersatz** | `aws-node` wird entfernt; Cilium ist alleiniger CNI mit ENI-IPAM oder cluster-pool-IPAM. | [08](08/de.md) |
| **Präfix** | Teil eines Schlüssels vor `/`, aus dem Mountpoint ein Verzeichnis emuliert; echte Verzeichnisse gibt es in S3 nicht. | [25](25/de.md) |
| **erzwungenes Upgrade** | Automatische Versionserhöhung am Ende von extended support; solcher Cluster kann nicht zurückgesetzt werden. | [38](38/de.md) |
| **Provider** | Terraform-Plugin wie `aws`, `kubernetes` oder `helm`. | [0.5](00-5-tools/de.md) |
| **progressive Auslieferung** | Canary-/Blue-Green-Deployment von Anwendungen mit Argo Rollouts oder Flagger. | [44](44/de.md) |
| **Produktionscheckliste** | Systematische Readiness-Prüfliste nach Domänen, deren Punkte geschlossen oder als bekanntes Risiko markiert sind. | [48](48/de.md) |
| **Profil** | Benannter Parametersatz wie Region, Rolle und SSO. | [0.5](00-5-tools/de.md) |
| **Region** | Geografischer Standort wie `eu-central-1`, an den Ressourcen gebunden sind. | [0.1](00-1-aws/de.md) |
| **Modus external** | Wert der Annotation `aws-load-balancer-type`, der die Service-Reconciliation an den externen LBC statt an den in-tree provider übergibt. | [26](26/de.md) |
| **EBS-Zugriffsmodi** | `ReadWriteOnce` für eine Node, `ReadWriteOncePod` für genau einen Pod und `ReadWriteMany` nur als Multi-Attach `io2` im Modus `volumeMode: Block`; gemeinsamer Dateizugriff erfolgt über EFS oder FSx. | [23](23/de.md) |
| **Reconciliation** | Kontinuierlicher Abgleich des gewünschten Git-Zustands mit dem tatsächlichen Clusterzustand. | [44](44/de.md) |
| **statisches Provisioning** | PV wird mit `bucketName` manuell beschrieben; der Treiber kann weder dynamisch provisionieren noch Buckets erstellen. | [25](25/de.md) |
| **Stack** | Unabhängig anwendbare Infrastruktureinheit mit eigenem state. | [0.5](00-5-tools/de.md), [04](04/de.md) |
| **Rotationsstrategie** | `single user` ändert ein Passwort mit kurzem Fehlerrisiko; `alternating users` wechselt zwischen zwei Benutzern. | [18](18/de.md) |
| **Spot-Strategie** | Auswahl eines Pools: `capacity-optimized(-prioritized)` gegenüber `lowest-price`; kapazitätsorientierte Strategien werden seltener unterbrochen. | [0.4](00-4-ec2/de.md) |
| **Tag** | Schlüssel-Wert-Paar; EKS-Controller finden Ressourcen daran, aktivierte cost allocation tags teilen die Rechnung auf. | [0.1](00-1-aws/de.md) |
| **Instanztyp** | `Familie + Generation + Suffix . Größe`, etwa `m7g.xlarge`. | [0.4](00-4-ec2/de.md) |
| **control-plane-Logtypen** | `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`; schreiben erst nach Aktivierung nach CloudWatch Logs. | [02](02/de.md) |
| **verwaltete EKS-Fähigkeit für Argo CD** | Argo CD als EKS Capability: Controller in der AWS-control-plane, Ziele nur EKS-Cluster per ARN, Zugriff über access entries. | [44](44/de.md) |
| **kubernetes filter** | Fluent-Bit-FILTER, der Einträgen Namespace, Pod, Container, Labels und Annotationen hinzufügt. | [34](34/de.md) |
| **Argo-CD-Sharding** | Verteilung verbundener Cluster auf Replikate des application-controller. | [44](44/de.md) |
| **--force** | Flag zum Umgehen von Insight-Prüfungen, nicht jedoch von Voraussetzungen wie Fenster, Minor-Abstand und Feature-Kompatibilität. | [39](39/de.md) |
| **/var/log/containers** | Node-Verzeichnis mit Verweisen auf Container-Logdateien, aus dem der Sammler Logs liest. | [34](34/de.md) |
