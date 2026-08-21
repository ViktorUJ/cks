[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# Amazon EKS: praktisches Selbstlernbuch für den Produktionsbetrieb

Praxisorientierter Kurs zu Amazon EKS mit Verknüpfung zu den Laborübungen in
`tasks/eks/labs`. Der Kurs richtet sich an Ingenieurinnen und Ingenieure, die
**CKA bereits absolviert haben** (oder Kubernetes sicher auf Administratorniveau
beherrschen) und zu einem verwalteten Cluster in AWS wechseln.

Es gibt keine eigene EKS-Zertifizierung. Deshalb ist der Kurs nicht auf eine Prüfung,
sondern auf den realen Betrieb ausgerichtet: die Aufgaben von Ingenieurinnen und
Ingenieuren, wenn AWS die Control Plane betreibt, Knoten, Netzwerk, Zugriffe, Kosten
und Upgrades aber bei Ihnen bleiben.

> **Vorausgesetztes Wissen.** Pods, Deployments, Services, Ingress, RBAC, PV/PVC,
> Probes, `kubectl` und das Debuggen von Workloads sind Grundlagen des CKA-Kurses
> und werden hier nicht wiederholt. Falls diese Themen noch fehlen, beginnen Sie mit
> dem [CKA- + CKAD-Kurs](../../cka/course/README_DE.md).

> **Versionen.** Der Kurs orientiert sich an aktuellen EKS-Versionen (Kubernetes
> `1.33` - `1.36`). EKS hat einen eigenen Versionslebenszyklus: 14 Monate Standard
> Support plus 12 Monate Extended Support (26 Monate pro Minor-Version). Daher ist
> das Kapitel zu Upgrades nicht an eine bestimmte Versionsnummer, sondern an den
> Prozess gebunden. Die Kurs-Labs werden mit der Version aus der `env.hcl` des
> jeweiligen Labs bereitgestellt.

## Aufbau des Kurses

Jedes Thema ist ein Ordner mit einer Nummer. Darin liegen lokalisierte Dateien. Die
Hauptsprache ist Russisch (`ru.md`), aus der Übersetzungen entstehen (wie in den
Kursen CKA und Istio). Der Sprachumschalter steht ab der ersten Übersetzung in der
ersten Zeile jeder Datei.

Der Kurs benötigt **ein eigenes AWS-Konto**: Fast alle Themen lassen sich nur an
einem Live-Cluster prüfen, und einige davon (Spot-Unterbrechungen, NAT und Traffic,
Upgrades, Kosten) können nicht in lokalem kind nachgestellt werden. Die Labs werden
über Terragrunt bereitgestellt und mit einem einzigen Befehl entfernt, damit keine
unnötigen Kosten entstehen.

Neben Kapiteln und Labs enthält der Kurs Arbeitsreferenzen. Sie werden nicht am Stück,
sondern bei Bedarf gelesen:

- [Kursglossar](GLOSSARY_DE.md) - alle Begriffe nach Kapiteln mit Links
- [Diagnosehandbuch](RUNBOOK_DE.md) - Symptom, Ursache, Prüfung: Teil 8 in einer Übersicht
- [Architekturentscheidungen (ADR)](ADR_DE.md) - Entscheidungsvorlagen für die Verzweigungen des Kurses
- [EKS-Reifegradmatrix](SCORECARD_DE.md) - Fragebogen zur Clusterbereitschaft in acht Domänen
- [Kostenmodell](COST_MODEL_DE.md) - Posten und Formeln, die Preise tragen Sie selbst ein

## Inhalt

### Teil 0. AWS-Grundlagen (optional)

Vorbereitender Teil für alle, die mit Kubernetes gut vertraut sind, aber noch wenig
AWS-Erfahrung haben. Wenn IAM, VPC und EC2 vertraute Werkzeuge sind, gehen Sie direkt
zu Teil 1. Dieser Teil hat keine eigenen Labs: Er sorgt dafür, dass die übrigen
Kapitel ohne Lücken gelesen werden können.

- 0.1. [AWS für Kubernetes-Ingenieure: Konten, Regionen, AZs, Quoten, Tags, Abrechnung](00-1-aws/de.md)
- 0.2. [IAM von Grund auf: Richtlinien, Rollen, Vertrauen, STS und temporäre Schlüssel](00-2-iam/de.md)
- 0.3. [VPC von Grund auf: Subnetze, Routing, IGW und NAT, Security Groups, VPC Endpoints](00-3-vpc/de.md)
- 0.4. [EC2 und Zahlungsmodelle: Instanztypen, AMI, On-Demand, Spot, Savings Plans](00-4-ec2/de.md)
- 0.5. [Werkzeuge: aws cli, eksctl, terraform und terragrunt, helm, nützliche Plugins](00-5-tools/de.md)

### Teil 1. Architektur und Clustererstellung

1. [Einführung: Was EKS übernimmt und was bei Ihnen bleibt](01/de.md)
2. [EKS-Control-Plane: öffentlicher und privater Endpoint, Platform Versions, SLA, Logs](02/de.md)
3. [Versionslebenszyklus: Standard und Extended Support, Upgrade-Strategie](03/de.md)
4. [Cluster erstellen: eksctl, Terraform und Terragrunt, CloudFormation](04/de.md) 🧪
5. [Clusterzugriff: IAM und RBAC, Access Entries, Migration von aws-auth](05/de.md)
6. [Clusternetzwerk: VPC CNI, ENI und IP-Adressen, CIDR-Planung](06/de.md) 🧪
7. [Skalierung des Adressplans: Prefix Delegation, Secondary CIDR, Custom Networking](07/de.md)
8. [Alternativen zu VPC CNI: Cilium, Netzwerkmodi, wann ein CNI gewechselt werden sollte](08/de.md) 🧪

### Teil 2. Knoten und Rechenressourcen

9. [Rechenarten: Managed Node Groups, Self-Managed, Fargate, Auto Mode](09/de.md) 🧪
10. [AMI und Bootstrap: AL2023, Bottlerocket, Launch Templates, kubelet und User Data](10/de.md) 🧪
11. [Cluster Autoscaler und Karpenter: zwei Ansätze zur Knotenskalierung](11/de.md)
12. [Karpenter: NodePool, EC2NodeClass, Disruption, Consolidation, Drift](12/de.md)
13. [Spot-Instanzen: Unterbrechungen, Diversifizierung, Ereignisbehandlung](13/de.md)
14. [Dichte und Sizing: Pods pro Knoten, ENI-Limits, Requests und Limits in der Cloud](14/de.md)
15. [Fargate: Profile, Einschränkungen, Kosten, Einsatzszenarien](15/de.md)

### Teil 3. Identität und Sicherheit

16. [IRSA: OIDC-Provider, Trust Policy, ServiceAccount-Anmerkungen](16/de.md)
17. [EKS Pod Identity: Agent, Zuordnungen, Migration von IRSA](17/de.md)
18. [Secrets: KMS-Verschlüsselung, Secrets Manager und SSM über External Secrets und CSI](18/de.md)
19. [Hardening: IMDSv2 und Hop Limit, Pod Security Admission, privater Cluster](19/de.md)
20. [Images und Supply Chain: ECR, Scans, Signaturen, Pull-Through-Cache](20/de.md) 🧪
21. [Audit und Erkennung: Control-Plane-Logs, CloudTrail, GuardDuty, Runtime-Monitoring](21/de.md)
22. [Richtlinien und Mandantentrennung: Kyverno und Gatekeeper, Teamisolation](22/de.md) 🧪

### Teil 4. Datenspeicherung

23. [EBS CSI: gp3, StorageClass, Erweiterung, Snapshots, Bindung an AZs](23/de.md)
24. [EFS und FSx: Shared Storage für Workloads über mehrere AZs](24/de.md)
25. [S3 in Anwendungen: Mountpoint for Amazon S3 CSI und Zugriffsmuster](25/de.md) 🧪

### Teil 5. Netzwerk und Traffic

26. [AWS Load Balancer Controller und Service vom Typ LoadBalancer: NLB](26/de.md)
27. [Ingress über ALB: Target Type, Anmerkungen, TLS und ACM, WAF](27/de.md)
28. [Gateway API in AWS: ALB Gateway API und VPC Lattice](28/de.md) 🧪
29. [DNS und Zertifikate: external-dns, Route 53, cert-manager](29/de.md)
30. [NetworkPolicy in EKS: VPC-CNI-Network-Policy und Cilium](30/de.md)
31. [Egress und Traffic-Kosten: NAT, VPC Endpoints, PrivateLink](31/de.md)
32. [Mehrere Cluster und Konten: Konnektivität, gemeinsame Ressourcen, Muster](32/de.md)

### Teil 6. Beobachtbarkeit

33. [Metriken: Container Insights, Managed Prometheus und Grafana, kube-prometheus-stack](33/de.md)
34. [Logs: Fluent Bit, CloudWatch Logs, OpenSearch, Kostenkontrolle](34/de.md)
35. [Autoskalierung von Anwendungen: HPA, externe Metriken, KEDA](35/de.md) 🧪
36. [Tracing und Profiling: ADOT und X-Ray](36/de.md)

### Teil 7. Betrieb

37. [EKS-Add-ons: Managed Add-ons gegenüber Helm, Versionen und Upgradereihenfolge](37/de.md)
38. [Clusterupgrade: In-Place nach Versionen, Blue/Green-Cluster, veraltete APIs](38/de.md)
39. [Rollback der Clusterversion: Rollback Readiness Insights, 7-Tage-Fenster, Reihenfolge des Rollbacks](39/de.md)
40. [Zuverlässigkeit: Multi-AZ, PDB, Topology Spread, geordnetes Herunterfahren von Knoten](40/de.md) 🧪
41. [Cluster-Backup mit AWS Backup: Clusterzustand, persistente Volumes, Composite Recovery Point](41/de.md) 🧪
42. [Wiederherstellung und DR: Restore in einen bestehenden und einen neuen Cluster, Namespace Restore, Velero](42/de.md) 🧪
43. [Kosten: OpenCost und Kubecost, Right-Sizing, Savings Plans, Spot-Mix, Traffic](43/de.md)
44. [GitOps und Bereitstellung: Argo CD und Flux, Verwaltung einer Clusterflotte](44/de.md) 🧪

Zu diesem Teil gehören zwei Referenzen: das [Kostenmodell](COST_MODEL_DE.md) - ein
Bewertungsformular zu Kapitel 43, und die [Architekturentscheidungen](ADR_DE.md) -
ADR-Vorlagen für die Verzweigungen des gesamten Kurses.

### Teil 8. Troubleshooting

45. [Knoten ist dem Cluster nicht beigetreten: IAM, SG, User Data, Bootstrap, kubelet](45/de.md)
46. [Netzwerkstörungen: ENI exhausted, SG und NACL, DNS, ungesunde Targets im Load Balancer](46/de.md) 🧪
47. [Zugriff und IAM: Access Entries, IRSA und Pod Identity, Webhook, kubeconfig](47/de.md) 🧪

Die Abschnitte „Diagnosereihenfolge“ dieser drei Kapitel sind im
[Diagnosehandbuch](RUNBOOK_DE.md) zusammengefasst: Symptom, wahrscheinliche Ursache,
was geprüft werden muss. Im Bereitschaftsdienst ist es bequemer, dieses zu öffnen als
drei Kapitel.

### Teil 9. Abschluss

48. [EKS-Produktionscheckliste und weiterführende Lektüre](48/de.md)

Die Checklisten aus Kapitel 48 stehen als Fragebogen mit Punktzahl und Liste der
technischen Schulden in der [Reifegradmatrix](SCORECARD_DE.md).

## Praxis

Der Kurs hat einen eigenen Satz Laborübungen mit Nummerierung `101+`, die den Kapiteln
zugeordnet sind. Die Labs werden über Terragrunt in Ihrem AWS-Konto bereitgestellt,
automatisch mit `check_result` geprüft und mit einem Befehl entfernt:

- 🧪 [EKS-Laborübungen](../../../docs/labs.MD#eks-labs) - Liste der Labs und Startbefehle

Der Satz der Kurs-Labs ist derzeit in Arbeit. Das 🧪-Symbol im Inhaltsverzeichnis
bedeutet, dass das Kapitel bereits ein eigenes Lab hat; Kapitel ohne Symbol werden
vorerst als Theorie behandelt.

Im Repository gibt es außerdem frühere EKS-Labs ([Karpenter](../labs/02/README_DE.MD),
[Autoskalierung mit KEDA und Prometheus](../labs/03/README_DE.MD)). Sie sind nicht
Teil des Kurses und werden unabhängig gepflegt, überschneiden sich thematisch aber mit
den Kapiteln 12 und 35. Sie können daher als zusätzliche Praxis absolviert werden.

## Weiterführende Lektüre

- [Amazon-EKS-Dokumentation](https://docs.aws.amazon.com/eks/latest/userguide/) -
  Primärquelle zu Versionen, Add-ons und Limits.
- [EKS Best Practices Guides](https://docs.aws.amazon.com/eks/latest/best-practices/) -
  offizielle Empfehlungen zu Netzwerk, Sicherheit, Zuverlässigkeit und Kosten.
- [EKS Workshop](https://www.eksworkshop.com/) - kostenlose interaktive Module von AWS.
- [AWS Backup: Backup und Wiederherstellung von EKS](https://docs.aws.amazon.com/aws-backup/latest/devguide/eks-backups.html) -
  Dokumentation zum Backup von Clusterzustand und persistenten Volumes.
- [Von Spot.io zu Karpenter](../../../docs/articles/from_spot_io_to_karpenter/readme_RU.MD) -
  unsere Analyse der Migration der Knotenverwaltung im Produktionsbetrieb.
