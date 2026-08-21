[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Labor: Grundlagen von Karpenter

## Beschreibung

Dieses Labor führt Sie in **Karpenter** ein – ein Tool zur automatischen Skalierung von Knoten (Nodes) in einem Amazon-EKS-Cluster. Karpenter erstellt und entfernt EC2-Instances dynamisch entsprechend den Anforderungen Ihrer Anwendungen und optimiert damit Kosten und Leistung.

**Das lernen Sie:**
- Wie Sie einen grundlegenden NodePool und eine EC2NodeClass konfigurieren
- Wie Karpenter Knoten bei Laständerungen automatisch skaliert
- Wie Sie Ressourcen über Limits verwalten
- Wie Konsolidierung und Optimierung der Knotengrößen funktionieren
- Wie Knoten bei Konfigurationsänderungen aktualisiert werden (Drift)
- Wie Sie mehrere NodePools für verschiedene Lasttypen verwenden

## Inhalt
- [Vorbereitung der Umgebung](#vorbereitung-der-umgebung)
  - [Starten des Labors](#starten-des-labors)
  - [Erstellte Ressourcen](#erstellte-ressourcen)
  - [Voraussetzungen](#voraussetzungen)
- [Grundkonfiguration von NodePool](#grundkonfiguration-von-nodepool)
  - [Überprüfen der Karpenter-Funktion](#überprüfen-der-karpenter-funktion)
  - [Erstellen einer Testanwendung](#erstellen-einer-testanwendung)
  - [Erstellen von NodePool und EC2NodeClass](#erstellen-von-nodepool-und-ec2nodeclass)
  - [Überprüfen der automatischen Knotenerstellung](#überprüfen-der-automatischen-knotenerstellung)
- [Skalieren von Anwendungen](#skalieren-von-anwendungen)
  - [Horizontale Skalierung](#horizontale-skalierung)
  - [Automatisches Hinzufügen von Knoten](#automatisches-hinzufügen-von-knoten)
- [Ressourcenbegrenzung](#ressourcenbegrenzung)
  - [Konfiguration von CPU-Limits](#konfiguration-von-cpu-limits)
  - [Diagnose von Problemen mit Limits](#diagnose-von-problemen-mit-limits)
- [Verwaltung des Knotenlebenszyklus (Disruption)](#verwaltung-des-knotenlebenszyklus-disruption)
- [Optimierung der Knotengrößen (RightSizing)](#optimierung-der-knotengrößen-rightsizing)
  - [Automatische Auswahl der optimalen Größe](#automatische-auswahl-der-optimalen-größe)
  - [Ersetzen von Knoten bei geänderten Anforderungen](#ersetzen-von-knoten-bei-geänderten-anforderungen)
- [Aktualisieren der Knotenkonfiguration (Drift)](#aktualisieren-der-knotenkonfiguration-drift)
  - [Aktualisieren von AMI-Images](#aktualisieren-von-ami-images)
  - [Automatische Migration auf neue Versionen](#automatische-migration-auf-neue-versionen)
- [Arbeiten mit mehreren NodePools](#arbeiten-mit-mehreren-nodepools)
  - [Lastisolierung mit Taints und Tolerations](#lastisolierung-mit-taints-und-tolerations)
  - [Spezialisierte Knoten für Jobs](#spezialisierte-knoten-für-jobs)
- [Bereinigen von Ressourcen](#bereinigen-von-ressourcen)

## Vorbereitung der Umgebung

### Starten des Labors
[Starten über Docker](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)
Führen Sie zum Starten des Labors den folgenden Befehl aus:

```bash
TASK=02 make run_eks_task
```

**Was bei der Befehlsausführung geschieht:**
- Terraform/Terragrunt stellt die gesamte erforderliche Infrastruktur automatisch in AWS bereit
- Der Vorgang dauert etwa 15–20 Minuten
- In der Befehlsausgabe sehen Sie wichtige Informationen (SSH-Verbindung, Ressourcennamen)

### Erstellte Ressourcen

Bei der Befehlsausführung wird die folgende AWS-Infrastruktur bereitgestellt:

#### Netzwerkinfrastruktur (VPC)
- **VPC** mit dem CIDR-Block `10.10.0.0/16` in der Region `eu-central-1`
- **Öffentliche Subnetze** (für Ressourcen mit Internetzugang):
  - `eks-AZ-1` (10.10.1.0/24) in der Availability Zone `eu-central-1a`
  - `eks-AZ-2` (10.10.2.0/24) in der Availability Zone `eu-central-1b`
- **Private Subnetze** (für interne Ressourcen):
  - `private-subnet-1` (10.10.15.0/24) für EKS-Knoten in `eu-central-1a`
  - `private-subnet-2` (10.10.16.0/24) für EKS-Knoten in `eu-central-1b`
  - `rds-subnet-1` (10.10.21.0/24) für RDS in `eu-central-1a`
  - `rds-subnet-2` (10.10.22.0/24) für RDS in `eu-central-1b`
- **NAT Gateway** für ausgehenden Internetverkehr aus privaten Subnetzen

#### EKS-Cluster
- **EKS Control Plane** der Version `1.34` (Kubernetes-Steuerungsebene)
- **Fargate profile** für System-Pods (kube-system, karpenter)
- **Karpenter** der Version `1.8.1` (Autoscaling-Controller)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Karpenter-Konfiguration
- Karpenter-Controller mit reservierten Ressourcen:
  - CPU: 0.4 Kerne (requests und limits)
  - Memory: 0.5Gi (requests und limits)
- Automatische Subnetzerkennung über Tags `karpenter.sh/discovery`

#### Zusätzliche Komponenten
- **Security Groups** mit entsprechenden Sicherheitsregeln
- **IAM-Rollen und -Richtlinien** für Karpenter und EKS
- **OIDC provider** zur Integration mit AWS-Services

#### Hauptkonfigurationsdatei

Alle Infrastrukturparameter sind in der Datei `tasks/eks/labs/02/env.hcl` definiert. Bearbeiten Sie die entsprechenden Parameter in dieser Datei, um die Konfiguration zu ändern.

### Voraussetzungen

Stellen Sie sicher, dass Folgendes eingerichtet ist:
- **AWS CLI** mit entsprechenden Zugriffsrechten
- Erhöhte Limits für die Anzahl von Knoten in der Region `eu-central-1` (falls erforderlich)

## Grundkonfiguration von NodePool

### Überprüfen der Karpenter-Funktion

**Schritt 1: Verbindung zum Arbeitsknoten herstellen**

Suchen Sie in der Befehlsausgabe die SSH-Verbindungszeile und verbinden Sie sich mit dem Arbeitsknoten:

```bash
# Beispielausgabe:
# 18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "

ssh ubuntu@18.199.222.47  # Verwenden Sie Ihre IP-Adresse und Ihr Passwort
```

**Schritt 2: Status des Karpenter-Controllers überprüfen**

Stellen Sie sicher, dass der Karpenter-Controller läuft:

```bash
kubectl get po -n karpenter
```

**Erwartetes Ergebnis:**
```
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m
```

**Schritt 3: Vorhandene NodePools und EC2NodeClass überprüfen**

Überprüfen Sie, dass noch keine NodePools erstellt wurden:

```bash
kubectl get nodepools
```

**Ergebnis:**
```
No resources found
```

Überprüfen Sie die EC2NodeClass:

```bash
kubectl get ec2nodeclasses
```

**Ergebnis:**
```
No resources found
```

**Bedeutung:** NodePool und EC2NodeClass sind die zentralen Ressourcen von Karpenter. NodePool bestimmt, welche Knoten erstellt werden, und EC2NodeClass, wie sie konfiguriert werden (AMI, Subnetze, security groups usw.).

### Erstellen einer Testanwendung

Stellen wir eine einfache Testanwendung bereit:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Ergebnis:**
```
namespace/team-19 created
deployment.apps/team19 created
service/team19 created
```

**Schritt 4: Pod-Status überprüfen**

Überprüfen Sie den Status der erstellten Pods:

```bash
kubectl get po -n team-19
```

**Ergebnis:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```

**Beachten Sie:** Der Pod hat den Status `Pending` (wartend). Das ist in dieser Phase normal.

**Schritt 5: Problem diagnostizieren**

Sehen wir uns die detaillierten Informationen zum Pod an:

```bash
kubectl describe po -n team-19
```

**Wichtiger Teil der Ausgabe:**
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**Problemerklärung:**
- Der Pod kann auf keinem Knoten eingeplant werden
- Alle 3 vorhandenen Knoten sind Fargate-Knoten für System-Pods (kube-system, karpenter)
- Das Fargate profile ist nur für bestimmte Namespaces konfiguriert, und `team-19` gehört nicht dazu
- Wir müssen einen NodePool erstellen, damit Karpenter passende EC2-Knoten erstellen kann

### Erstellen von NodePool und EC2NodeClass

**Schritt 6: NodePool erstellen**

NodePool definiert die Parameter der Knoten, die Karpenter erstellt:

```bash
cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"  # Label zur Identifizierung der Knoten
    spec:
      requirements:
        # Unterstützte Prozessorarchitekturen
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        # Betriebssystem
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        # Instance-Typ: spot (günstiger) oder on-demand (stabiler)
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # Instance-Kategorien (t - burstable, m - general purpose, r - memory optimized)
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        # Instance-Generation (größer 2 = neuer)
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        # Instance-Größen
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      # Verweis auf EC2NodeClass mit AWS-Einstellungen
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      # Knotenlebensdauer (30 Tage)
      expireAfter: 720h # 30 * 24h = 720h
  # Ressourcenlimits für den gesamten NodePool
  limits:
    cpu: 4  # Maximal 4 CPU für alle Knoten in diesem Pool
  # Konsolidierungs- (Optimierungs-) Einstellungen
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # Leere oder unterausgelastete Knoten entfernen
    consolidateAfter: 30s  # 30 Sekunden, nachdem der Knoten leer geworden ist
EoF

kubectl apply -f default-nodepool.yaml
```

**Schritt 7: Parameter aus der Terraform-Ausgabe abrufen**

Suchen Sie in der Ausgabe des Befehls `make run_eks_task` nach folgenden Werten:

```bash
# Beispielausgabe:
# 19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"
# 20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Schritt 8: EC2NodeClass erstellen**

EC2NodeClass definiert AWS-spezifische Knoteneinstellungen:

```bash
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # IAM-Rolle für Knoten (durch Ihre aus der Terraform-Ausgabe ersetzen)
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"
  # AMI-Image auswählen
  amiSelectorTerms:
    - alias: "al2023@latest"  # Amazon Linux 2023, neueste Version
  # Subnetze anhand von Tags auswählen
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Durch Namen Ihres Clusters ersetzen
  # Security Groups anhand von Tags auswählen
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Durch Namen Ihres Clusters ersetzen
  # Tags für die erstellten EC2-Instances
  tags:
      Name: "eks2-viktor-01-default"  # Durch Namen Ihres Clusters ersetzen
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01  # Durch Namen Ihres Clusters ersetzen
  # Datenträger konfigurieren
  blockDeviceMappings:
    - deviceName: /dev/xvda    # Root-Datenträger
      ebs:
        volumeType: gp3        # Datenträgertyp (gp3 - modern, leistungsfähig)
        volumeSize: 25Gi       # Datenträgergröße
        iops: 3000             # IOPS für gp3
        throughput: 125        # Durchsatz MiB/s
        encrypted: true        # Datenträgerverschlüsselung
        deleteOnTermination: true  # Datenträger beim Löschen der Instance entfernen
EoF

kubectl create -f default-nodeclass.yaml
```

### Überprüfen der automatischen Knotenerstellung

**Schritt 9: Ressourcenstatus überprüfen**

Überprüfen Sie, dass EC2NodeClass erstellt und bereit ist:

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Erwartetes Ergebnis:**
```
NAME      READY   AGE
default   True    2m17s
```

Überprüfen Sie NodePool:

```bash
kubectl get nodepools.karpenter.sh
```

**Erwartetes Ergebnis:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m
```

**Wenn der Status nicht READY ist:**

Führen Sie die Diagnose für EC2NodeClass aus:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws default
```

**Beispiel einer erfolgreichen Ausgabe:**
```
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, Status: Unknown -> True
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReservationsReady, Status: Unknown -> True
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady, Status: Unknown -> True
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroupsReady, Status: Unknown -> True
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfileReady, Status: Unknown -> True
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSucceeded, Status: Unknown -> True
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status: Unknown -> True
```

Überprüfen Sie NodePool:

```bash
kubectl describe nodepools.karpenter.sh default
```

**Wenn Fehler auftreten, überprüfen Sie die Controller-Logs:**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Beispiel erfolgreicher Logs:**
```json
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
```

**Schritt 10: NodeClaim überprüfen**

NodeClaim ist eine Anforderung zum Erstellen eines Knotens. Karpenter erstellt einen NodeClaim, der anschließend in eine tatsächliche EC2-Instance umgewandelt wird:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s
```

**Was wir sehen:**
- Ein NodeClaim mit dem Namen `default-c549s` wurde erstellt
- Die Instance `t3a.small` (2 vCPU, 2GB RAM) wurde gewählt
- Es wird eine Spot-Instance (günstiger) verwendet
- Der Knoten befindet sich in der Zone `eu-central-1a`

**Schritt 11: Anwendungspod überprüfen**

Jetzt sollte der Pod erfolgreich starten:

```bash
kubectl get po -n team-19
```

**Ergebnis:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m
```

**Der Status hat sich zu `Running` geändert!**

**Schritt 12: Clusterknoten überprüfen**

Sehen wir uns alle Knoten im Cluster an:

```bash
kubectl get no
```

**Ergebnis:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6
```

**Beachten Sie:**
- Die ersten 3 Knoten sind Fargate-Knoten (für System-Pods)
- Der letzte Knoten ist eine von Karpenter erstellte EC2-Instance

### Überprüfen der automatischen Knotenentfernung

**Schritt 13: Anwendung löschen**

Löschen wir unsere Anwendung:

```bash
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Ergebnis:**
```
namespace "team-19" deleted
deployment.apps "team19" deleted
service "team19" deleted
```

**Schritt 14: Entfernen der Pods überprüfen**

```bash
kubectl get po -n team-19
```

**Ergebnis:**
```
No resources found in team-19 namespace.
```

**Schritt 15: Auf die Entfernung von NodeClaim warten**

Warten Sie etwa 30 Sekunden (den Wert von `consolidateAfter` im NodePool) und überprüfen Sie:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
No resources found
```

**Karpenter hat NodeClaim automatisch entfernt, weil der Knoten leer wurde!**

**Schritt 16: Knoten überprüfen**

```bash
kubectl get no
```

**Ergebnis:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
```

**Der EC2-Knoten wurde entfernt! Es bleiben nur Fargate-Knoten.**

**Fazit:** Karpenter verwaltet den Knotenlebenszyklus automatisch – es erstellt Knoten bei Bedarf und entfernt sie, wenn sie nicht mehr benötigt werden, wodurch Kosten optimiert werden.

## Skalieren von Anwendungen

In diesem Abschnitt lernen wir, wie Karpenter bei steigender Last automatisch Knoten hinzufügt.

### Horizontale Skalierung

**Schritt 1: Testanwendung bereitstellen**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Schritt 2: Erstellte Ressourcen überprüfen**

Überprüfen Sie NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s
```

Überprüfen Sie die Knoten:

```bash
kubectl get no
```

**Ergebnis:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6
```

Überprüfen Sie die Pods:

```bash
kubectl get po -n team-19
```

**Ergebnis:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11m
```

### Automatisches Hinzufügen von Knoten

**Schritt 3: Auf 6 Replikate skalieren**

Erhöhen wir die Anzahl der Anwendungsreplikate:

```bash
kubectl scale deployment -n team-19 team19 --replicas 6
```

**Ergebnis:**
```
deployment.apps/team19 scaled
```

**Schritt 4: Pod-Status überprüfen**

```bash
kubectl get po -n team-19
```

**Ergebnis:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s
```

**Alle 6 Pods wurden erfolgreich gestartet!**

**Schritt 5: NodeClaim überprüfen**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Beachten Sie:** Karpenter hat automatisch einen zweiten Knoten (`default-gm8sj`) hinzugefügt, da ein Knoten für die Platzierung aller 6 Pods nicht ausreichte.

**Schritt 6: Auf 16 Replikate skalieren**

Erhöhen wir die Last weiter:

```bash
kubectl scale deployment -n team-19 team19 --replicas 16
```

**Schritt 7: Pod-Status überprüfen**

```bash
kubectl get po -n team-19
```

**Ergebnis:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          10m
team19-5d69f69559-4m772   0/1     Pending   0          2m37s
team19-5d69f69559-5ml7m   1/1     Running   0          2m37s
team19-5d69f69559-6dk8l   1/1     Running   0          2m37s
team19-5d69f69559-9qs2b   1/1     Running   0          2m37s
team19-5d69f69559-bzq77   1/1     Running   0          24m
team19-5d69f69559-fmcjq   1/1     Running   0          2m37s
team19-5d69f69559-gpzgc   1/1     Running   0          10m
team19-5d69f69559-kxw6k   1/1     Running   0          10m
team19-5d69f69559-ndg8q   1/1     Running   0          2m37s
team19-5d69f69559-pc2dv   1/1     Running   0          10m
team19-5d69f69559-q6brn   1/1     Running   0          10m
team19-5d69f69559-qgrqt   1/1     Running   0          2m37s
team19-5d69f69559-rss5s   1/1     Running   0          2m37s
team19-5d69f69559-x6qp8   1/1     Running   0          2m37s
team19-5d69f69559-z2wbm   0/1     Pending   0          2m37s
```

**Problem:** Einige Pods haben den Status `Pending`. Warum? Im nächsten Abschnitt klären wir das.

## Ressourcenbegrenzung

In diesem Abschnitt untersuchen wir, warum einige Pods den Status `Pending` behalten haben, und lernen, Ressourcenlimits in NodePool zu verwalten.

### Konfiguration von CPU-Limits

**Schritt 1: Aktuelle NodePool-Limits überprüfen**

```bash
kubectl get nodepools.karpenter.sh default -o jsonpath='{.spec.limits}' | jq
```

**Ergebnis:**
```json
{
  "cpu": 4
}
```

**Bedeutung:** Im NodePool ist ein Limit von 4 CPU festgelegt. Das bedeutet, dass die Gesamtzahl der CPU aller Knoten in diesem Pool 4 Kerne nicht überschreiten darf.

**Schritt 2: Vorhandene NodeClaims überprüfen**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Analyse:**
- Wir haben 2 Knoten vom Typ `t4g.small`
- Jeder `t4g.small` hat 2 vCPU
- Insgesamt: 2 Knoten × 2 vCPU = 4 vCPU
- **Wir haben das Limit erreicht!** Karpenter kann keine weiteren Knoten erstellen.

### Diagnose von Problemen mit Limits

**Schritt 3: Karpenter-Logs überprüfen**

Sehen wir nach, was die Controller-Logs sagen:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq | grep ERROR -A 20
```

**Ergebnis:**
```json
{
  "level": "ERROR",
  "time": "2026-01-13T17:41:15.044Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "1ad0d78",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "0e86c755-4ab9-4d86-abb5-7e15e91241fc",
  "Pod": {
    "name": "team19-5d69f69559-4m772",
    "namespace": "team-19"
  },
  "NodePool": {
    "name": "default"
  },
  "error": "all available instance types exceed limits for nodepool (NodePool=default)"
}
```

**Schlüsselmeldung:** `"all available instance types exceed limits for nodepool"`

Dies bestätigt, dass Karpenter aufgrund des CPU-Limits keine neuen Knoten erstellen kann.

**Schritt 4: CPU-Limit erhöhen**

Erhöhen wir das CPU-Limit auf 6 Kerne:

```bash
kubectl edit nodepools.karpenter.sh default
```

Suchen Sie den Abschnitt `limits` und ändern Sie den Wert:

```yaml
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # Auf 6 ändern
```

Speichern Sie die Änderungen (`:wq` in vim oder Ctrl+O, Enter, Ctrl+X in nano).

**Schritt 5: Erstellung eines neuen Knotens überprüfen**

Warten Sie einige Sekunden und überprüfen Sie NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m
```

**Ausgezeichnet!** Karpenter hat den dritten Knoten (`default-gpgn9`) erstellt.

**Schritt 6: Anwendungspods überprüfen**

```bash
kubectl get po -n team-19
```

**Ergebnis:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          29m
team19-5d69f69559-4m772   1/1     Running   0          22m
team19-5d69f69559-5ml7m   1/1     Running   0          22m
team19-5d69f69559-6dk8l   1/1     Running   0          22m
team19-5d69f69559-9qs2b   1/1     Running   0          22m
team19-5d69f69559-bzq77   1/1     Running   0          44m
team19-5d69f69559-fmcjq   1/1     Running   0          22m
team19-5d69f69559-gpzgc   1/1     Running   0          29m
team19-5d69f69559-kxw6k   1/1     Running   0          29m
team19-5d69f69559-ndg8q   1/1     Running   0          22m
team19-5d69f69559-pc2dv   1/1     Running   0          29m
team19-5d69f69559-q6brn   1/1     Running   0          29m
team19-5d69f69559-qgrqt   1/1     Running   0          22m
team19-5d69f69559-rss5s   1/1     Running   0          22m
team19-5d69f69559-x6qp8   1/1     Running   0          22m
team19-5d69f69559-z2wbm   1/1     Running   0          22m
```

**Alle 16 Pods haben jetzt den Status `Running`!**

### Überprüfen der automatischen Konsolidierung

**Schritt 7: Anzahl der Replikate verringern**

Verringern wir die Anzahl der Replikate auf 3:

```bash
kubectl scale deployment -n team-19 team19 --replicas 3
```

**Schritt 8: Karpenter-Logs überwachen**

Beobachten Sie die Logs in Echtzeit:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**Sie sehen Meldungen zur Konsolidierung:**

```json
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 2,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-30.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-gpgn9"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ]
}
```

**Was geschieht:**
- Karpenter hat einen unterausgelasteten Knoten (`underutilized`) erkannt
- Es hat entschieden, den Knoten zu entfernen (`decision: delete`)
- Zuerst markiert es den Knoten mit dem Taint `karpenter.sh/disrupted:NoSchedule`
- Es verschiebt Pods auf andere Knoten
- Es entfernt den Knoten

**Schritt 9: Verbleibende Knoten überprüfen**

Warten Sie etwa eine Minute und überprüfen Sie:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m
```

**Es bleibt nur ein Knoten!** Karpenter hat überflüssige Knoten entfernt und damit Kosten optimiert.

### Zusätzliche Informationen zu Limits

Limits können für verschiedene Ressourcentypen festgelegt werden:
- **cpu** — Anzahl der Prozessorkerne
- **memory** — Umfang des Arbeitsspeichers
- **gpu** — Anzahl der GPUs (für ML/AI-Lasten)
- **nodes** — maximale Anzahl von Knoten

**Beispielkonfiguration mit mehreren Limits:**

```yaml
limits:
  cpu: 100
  memory: 1000Gi
  nodes: 10
```

Weitere Informationen zu Limits finden Sie in der [offiziellen Karpenter-Dokumentation](https://karpenter.sh/docs/concepts/nodepools/#speclimits).

## Verwaltung des Knotenlebenszyklus (Disruption)

Karpenter unterstützt die automatische Verwaltung des Knotenlebenszyklus über den Parameter `consolidateAfter` in der NodePool-Spezifikation.

**Kernkonzepte:**

- **consolidateAfter** — Wartezeit vor der Knotenentfernung, nachdem der Knoten leer oder unterausgelastet wurde
- **consolidationPolicy** — Konsolidierungsrichtlinie:
  - `WhenEmpty` — nur vollständig leere Knoten entfernen
  - `WhenEmptyOrUnderutilized` — leere und unterausgelastete Knoten entfernen (empfohlen)

**Beispielkonfiguration:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s  # 30 Sekunden nach Freigabe entfernen
```

**So funktioniert es:**

1. Karpenter überwacht die Ressourcennutzung auf Knoten kontinuierlich
2. Wenn ein Knoten leer oder unterausgelastet wird, startet Karpenter einen Timer
3. Wenn der Knoten nach der angegebenen Zeit (`consolidateAfter`) weiterhin nicht benötigt wird, führt Karpenter Folgendes aus:
   - Es markiert den Knoten mit dem Taint `karpenter.sh/disrupted:NoSchedule`
   - Es verschiebt Pods kontrolliert auf andere Knoten
   - Es entfernt den Knoten

**Zusätzliche Parameter:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
  budgets:
    - nodes: "10%"  # Nicht mehr als 10% der Knoten gleichzeitig entfernen
```

Weitere Informationen zu Disruption finden Sie in der [offiziellen Dokumentation](https://karpenter.sh/docs/concepts/disruption/).

---

## Optimierung der Knotengrößen (RightSizing)

Karpenter wählt abhängig von den Pod-Anforderungen automatisch die optimale Knotengröße. Dies wird „Right-Sizing“ genannt – die Auswahl des passendsten und wirtschaftlichsten Instance-Typs.

### Automatische Auswahl der optimalen Größe

**Schritt 1: CPU-Limit festlegen**

Erhöhen wir das NodePool-Limit auf 10 Kerne:

```bash
kubectl edit nodepools.karpenter.sh default
```

Ändern Sie:

```yaml
spec:
  limits:
    cpu: 6     # Auf 10 ändern
```

**Schritt 2: Anwendung mit hohen Anforderungen bereitstellen**

Stellen wir eine Anwendung bereit, die 3 CPU anfordert:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Schritt 3: Erstellten NodeClaim überprüfen**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-6ltdb   t3.xlarge   spot       eu-central-1a   ip-10-10-15-179.eu-central-1.compute.internal   True    117s
```

**Beachten Sie:** Karpenter hat die Instance `t3.xlarge` mit 4 vCPU gewählt, da der Pod 3 CPU anfordert.

**Schritt 4: Knotendetails überprüfen**

```bash
kubectl get no ip-10-10-15-179.eu-central-1.compute.internal -o yaml
```

**Wichtige Labels:**

```yaml
labels:
  karpenter.k8s.aws/instance-cpu: "4"
  karpenter.k8s.aws/instance-type: t3.xlarge
  karpenter.k8s.aws/instance-category: t
  karpenter.sh/capacity-type: spot
```

### Ersetzen von Knoten bei geänderten Anforderungen

**Schritt 5: Pod-Anforderungen verringern**

Ändern wir die CPU-Anforderungen im Deployment:

```bash
kubectl edit deployments.apps -n team-19 team19
```

Suchen Sie den Abschnitt `resources` und ändern Sie:

```yaml
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: app
    resources:
      requests:
        cpu: "3"      # Auf "50m" ändern (50 Millicores)
        memory: 500Mi
```

Speichern Sie die Änderungen.

**Schritt 6: Karpenter-Logs überwachen**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**Sie sehen:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.171Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "replace",
  "disrupted-node-count": 1,
  "replacement-node-count": 1,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-15-179.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-6ltdb"
      },
      "capacity-type": "spot",
      "instance-type": "t3.xlarge"
    }
  ],
  "replacement-nodes": [
    {
      "capacity-type": "spot",
      "instance-types": "t4g.small, t3.small, t3a.small, m8gd.medium, r7gd.medium and 10 other(s)"
    }
  ]
}
```

**Was geschieht:**
- Karpenter hat erkannt, dass der Knoten unterausgelastet ist (`underutilized`)
- Es hat entschieden, den Knoten zu ersetzen (`decision: replace`)
- Es erstellt einen neuen, günstigeren Knoten

**Erstellung eines neuen NodeClaim:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.219Z",
  "logger": "controller",
  "message": "created nodeclaim",
  "controller": "disruption",
  "NodeClaim": {
    "name": "default-48ck8"
  },
  "requests": {
    "cpu": "200m",
    "memory": "50Mi",
    "pods": "4"
  },
  "instance-types": "m6g.medium, m6gd.medium, m7g.medium, m8g.medium, m8gd.medium and 10 other(s)"
}
```

**Starten der neuen Instance:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:10.582Z",
  "logger": "controller",
  "message": "launched nodeclaim",
  "provider-id": "aws:///eu-central-1b/i-0f0d32ba789615574",
  "instance-type": "t4g.small",
  "zone": "eu-central-1b",
  "capacity-type": "spot",
  "allocatable": {
    "cpu": "1930m",
    "memory": "1359Mi"
  }
}
```

**Schritt 7: Neuen NodeClaim überprüfen**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-48ck8   t4g.small   spot       eu-central-1b   ip-10-10-16-44.eu-central-1.compute.internal   True    8m59s
```

**Ausgezeichnet!** Karpenter hat `t3.xlarge` (4 vCPU) durch `t4g.small` (2 vCPU) ersetzt, was deutlich günstiger ist.

**Schritt 8: Bereinigen**

Löschen Sie das Deployment:

```bash
kubectl delete deployments.apps -n team-19 team19
```

Warten Sie auf die Entfernung von NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
No resources found
```

**Fazit:** Karpenter optimiert Knotengrößen automatisch und wählt die wirtschaftlichsten Optionen, die den Anwendungsanforderungen entsprechen.

## Aktualisieren der Knotenkonfiguration (Drift)

Drift ist ein Mechanismus zur automatischen Knotenaktualisierung, wenn sich die Konfiguration von EC2NodeClass ändert. Wenn Sie AMI, security groups, user data oder andere Parameter ändern, ersetzt Karpenter vorhandene Knoten automatisch durch neue mit aktualisierter Konfiguration.

### Aktualisieren von AMI-Images

**Schritt 1: AMI der vorherigen EKS-Version abrufen**

Rufen wir die AMI-ID für EKS-Version 1.33 ab:

```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query "Parameter.Value" \
  --output text
```

**Ergebnis:**
```
ami-0fc1cdef3ebc3a8fe
```

**Schritt 2: Altes AMI in EC2NodeClass festlegen**

Bearbeiten Sie EC2NodeClass:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Suchen Sie den Abschnitt `amiSelectorTerms` und ändern Sie:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Vorher
```

Zu:

```yaml
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - id: "ami-0fc1cdef3ebc3a8fe"  # Konkrete AMI-ID der Version 1.33
```

**Schritt 3: Anwendung bereitstellen**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Schritt 4: Knotenversion überprüfen**

```bash
kubectl get no
```

**Ergebnis:**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   58m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   2m23s v1.33.5-eks-ecaa3a6   <-- Version 1.33!
```

**Beachten Sie:** Der Knoten verwendet Kubernetes-Version 1.33.5 (aus dem alten AMI).

### Automatische Migration auf neue Versionen

**Schritt 5: Zur automatischen AMI-Auswahl zurückkehren**

Bearbeiten Sie EC2NodeClass wieder:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Ändern Sie zu:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Automatische Auswahl der neuesten Version
```

**Was geschieht:**
- Karpenter erkennt eine Änderung in EC2NodeClass
- Es stellt fest, dass der vorhandene Knoten eine veraltete Konfiguration (Drift) verwendet
- Es erstellt automatisch einen neuen Knoten mit aktualisiertem AMI
- Es verschiebt Pods kontrolliert auf den neuen Knoten
- Es entfernt den alten Knoten

**Schritt 6: Knotenaktualisierung überprüfen**

Warten Sie etwa eine Minute und überprüfen Sie die Knoten:

```bash
kubectl get no
```

**Ergebnis (nach ~30 Sekunden):**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   87m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   33s   v1.34.2-eks-ecaa3a6   <-- Neue Version!
```

**Ergebnis (nach ~4 Minuten):**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   91m     v1.34.2-eks-b3126f4
ip-10-10-16-230.eu-central-1.compute.internal           Ready    <none>   4m22s   v1.34.2-eks-ecaa3a6
```

**Ausgezeichnet!** Karpenter hat den Knoten automatisch durch einen neuen mit aktualisierter AMI-Version (1.34.2) ersetzt.

**Schritt 7: Bereinigen**

```bash
kubectl delete deployments.apps -n team-19 team19
```

Warten Sie auf die Entfernung von NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
No resources found
```

**Fazit:** Drift ermöglicht automatische Knotenaktualisierungen bei Konfigurationsänderungen ohne manuellen Eingriff. Dies ist besonders nützlich für:
- AMI-Aktualisierungen (Sicherheits-Patches, neue Kubernetes-Versionen)
- Änderungen an security groups
- Aktualisierung von user data-Skripten
- Änderungen an IAM-Rollen

---

## Arbeiten mit mehreren NodePools

In Produktionsumgebungen ist es häufig erforderlich, Last auf verschiedene Knotengruppen aufzuteilen. Beispielsweise:
- Ingress-Controller auf dedizierten Knoten
- Leistungsstarke Knoten für periodische Aufgaben (jobs)
- Knoten mit GPUs für ML/AI-Lasten
- Knoten mit viel Speicher für Datenbanken

### Lastisolierung mit Taints und Tolerations

**Szenario:** Wir müssen periodische jobs mit hohen Ressourcenanforderungen (CPU, Arbeitsspeicher, GPU) ausführen.

**Anforderungen:**
1. Auf diese Knoten dürfen keine normalen Pods gelangen (nur jobs)
2. Während ein job auf dem Knoten läuft, darf keine Konsolidierung stattfinden
3. Sobald der job abgeschlossen ist, soll der Knoten entfernt werden

### Spezialisierte Knoten für Jobs

**Schritt 1: Spezialisierten NodePool erstellen**

```bash
cat <<EoF> job-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: job
spec:
  template:
    metadata:
      labels:
        work_type: "job_karpenter"  # Label zur Identifizierung
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: job
      expireAfter: 720h # 30 Tage
      # WICHTIG: Der Taint verhindert, dass normale Pods auf diesen Knoten laufen
      taints:
        - key: workType
          value: "job"
          effect: NoSchedule  # Pods ohne entsprechende Toleration können nicht starten
  limits:
    cpu: 6
  disruption:
    consolidationPolicy: WhenEmpty  # NUR leere Knoten entfernen (nicht während ein job läuft)
    consolidateAfter: 10s           # Schnelles Entfernen nach Abschluss des job
EoF

kubectl apply -f job-nodepool.yaml
```

**Wesentliche Unterschiede zum default NodePool:**

1. **Taints** — verhindern das Starten normaler Pods:
   ```yaml
   taints:
     - key: workType
       value: "job"
       effect: NoSchedule
   ```

2. **consolidationPolicy: WhenEmpty** — der Knoten wird nur entfernt, wenn er vollständig leer ist (unterbricht keine laufenden jobs)

3. **consolidateAfter: 10s** — schnelles Entfernen nach Abschluss

**Schritt 2: Parameter aus der Terraform-Ausgabe abrufen**

Suchen Sie in der Ausgabe nach:

```bash
# Beispiel:
# eks_name = "eks2-viktor-01"
# karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Schritt 3: EC2NodeClass für jobs erstellen**

```bash
cat <<EoF> job-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: job
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"  # Durch Ihre ersetzen
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Durch Namen Ihres Clusters ersetzen
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Durch Namen Ihres Clusters ersetzen
  tags:
      Name: "eks2-viktor-01-job"  # Durch Namen Ihres Clusters ersetzen
      team: "infra"
      work_type: "job"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 25Gi
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
EoF

kubectl create -f job-nodeclass.yaml
```

**Schritt 4: Ressourcenstatus überprüfen**

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Ergebnis:**
```
NAME      READY   AGE
default   True    8m10s
job       True    2m22s
```

```bash
kubectl get nodepools.karpenter.sh
```

**Ergebnis:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    9m30s
job       job         0       True    3m38s
```

**Wenn der Status nicht READY ist**, führen Sie die Diagnose aus:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws job
kubectl describe nodepools.karpenter.sh job
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Schritt 5: Job mit Toleration starten**

Erstellen Sie einen job, der auf Knoten mit dem Taint `workType=job` starten kann:

```bash
cat <<EoF> test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: testjob
spec:
  template:
    spec:
      # Toleration ermöglicht dem Pod den Start auf Knoten mit dem entsprechenden Taint
      tolerations:
      - key: workType
        operator: Equal
        value: job
        effect: NoSchedule
      # Affinity stellt sicher, dass der Pod genau auf Knoten des job NodePool startet
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: work_type
                operator: In
                values:
                - job_karpenter
      containers:
      - name: job-container
        image: busybox
        command: ["sh", "-c", "echo 'Job started'; sleep 30; echo 'Job completed'"]
      restartPolicy: Never
  backoffLimit: 1
EoF

kubectl apply -f test-job.yaml
```

**Schritt 6: Erstellung von NodeClaim überprüfen**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ergebnis:**
```
NAME        TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
job-mpt7v   t4g.small   spot       eu-central-1b   ip-10-10-16-18.eu-central-1.compute.internal   True    58s
```

**Pod überprüfen:**

```bash
kubectl get po
```

**Ergebnis (während der Ausführung):**
```
NAME            READY   STATUS    RESTARTS   AGE
testjob-gtlbk   1/1     Running   0          64s
```

**Ergebnis (nach Abschluss):**
```
NAME            READY   STATUS      RESTARTS   AGE
testjob-gtlbk   0/1     Completed   0          72s
```

**Knoten überprüfen:**

```bash
kubectl get no
```

**Ergebnis:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   130m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   128m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   130m   v1.34.2-eks-b3126f4
ip-10-10-16-18.eu-central-1.compute.internal            Ready    <none>   59s    v1.34.2-eks-ecaa3a6
```

**Schritt 7: Automatisches Entfernen des Knotens überprüfen**

Warten Sie etwa 10–15 Sekunden nach Abschluss des job und überprüfen Sie die Knoten:

```bash
kubectl get no
```

**Ergebnis:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**Der Knoten wurde erfolgreich entfernt!** Karpenter hat den Knoten 10 Sekunden nach Abschluss des job automatisch entfernt.

**Fazit:** Die Verwendung mehrerer NodePools mit taints und tolerations ermöglicht Folgendes:
- Unterschiedliche Lasttypen isolieren
- Kosten optimieren (schnelles Entfernen von Knoten nach Abschluss eines job)
- Das Starten normaler Pods auf spezialisierten Knoten verhindern
- Konsolidierungsrichtlinien für verschiedene Lasttypen flexibel verwalten

## Bereinigen von Ressourcen

Nach Abschluss des Labors müssen alle erstellten Ressourcen entfernt werden, um unnötige Kosten zu vermeiden.

**Schritt 1: Keine aktiven NodeClaims überprüfen**

Stellen Sie sicher, dass keine aktiven NodeClaims vorhanden sind:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Erwartetes Ergebnis:**
```
No resources found
```

**Wenn aktive NodeClaims vorhanden sind:**

1. Überprüfen Sie, ob Pods auf den Knoten laufen:

```bash
kubectl get pods --all-namespaces -o wide
```

2. Löschen Sie deployments, pods oder jobs:

```bash
# Beispiel: deployment entfernen
kubectl delete deployment -n team-19 team19

# Beispiel: job entfernen
kubectl delete job testjob
```

3. Entfernen Sie NodeClaim nach dem Löschen der Pods manuell (falls erforderlich):

```bash
kubectl delete nodeclaim <name-of-nodeclaim>
```

**Schritt 2: Clusterknoten überprüfen**

Stellen Sie sicher, dass nur Fargate-Knoten übrig sind:

```bash
kubectl get no
```

**Erwartetes Ergebnis:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**Alle Knoten müssen mit `fargate-` beginnen.**

**Schritt 3: Infrastruktur entfernen**

Entfernen Sie alle für das Labor erstellten Ressourcen:

```bash
TASK=02 make delete_eks_task
```

**Befehlsausgabe:**

```
16:14:15.750 INFO   The stack at . will be processed in the following order for command destroy:
Group 1
- Module ./worker

Group 2
- Module ./eks_karpenter
- Module ./ssh-keys

Group 3
- Module ./eks_addons

Group 4
- Module ./eks_fargate_system

Group 5
- Module ./eks_control_plane

Group 6
- Module ./vpc


WARNING: Are you sure you want to run `terragrunt destroy` in each folder of the stack described above? There is no undo! (y/n)
```

**Geben Sie zur Bestätigung des Löschvorgangs `y` ein.**

**Was entfernt wird:**
- Arbeitsknoten (worker)
- Karpenter-Controller und zugehörige Ressourcen
- SSH-Schlüssel
- EKS add-ons
- Fargate profile
- EKS Control Plane
- VPC und Netzwerkinfrastruktur

**Der Löschvorgang dauert etwa 10–15 Minuten.**

---

## Fazit

Herzlichen Glückwunsch! Sie haben das Labor zu den Grundlagen von Karpenter erfolgreich abgeschlossen.

**Das haben Sie gelernt:**

1. **Grundkonfiguration** — Erstellen von NodePool und EC2NodeClass für die automatische Knotenverwaltung
2. **Automatische Skalierung** — Karpenter fügt bei steigender Last dynamisch Knoten hinzu
3. **Verwaltung von Limits** — Kontrolle der maximalen Ressourcenmenge über limits
4. **Konsolidierung** — automatisches Entfernen leerer und unterausgelasteter Knoten zur Kostenoptimierung
5. **Right-sizing** — automatische Auswahl der optimalen Knotengröße entsprechend den Pod-Anforderungen
6. **Drift** — automatische Aktualisierung der Knoten bei Konfigurationsänderungen (AMI, security groups usw.)
7. **Mehrere NodePools** — Isolierung verschiedener Lasttypen über taints, tolerations und affinity

**Wesentliche Vorteile von Karpenter:**

- **Schnelle Skalierung** — Knoten werden in Sekunden statt Minuten erstellt
- **Kostenoptimierung** — automatische Auswahl der wirtschaftlichsten Instance-Typen
- **Flexibilität** — Unterstützung von spot- und on-demand-Instances sowie verschiedener Architekturen (amd64, arm64)
- **Einfachheit** — deklarative Konfiguration über Kubernetes-Ressourcen
- **Automatisierung** — minimaler manueller Eingriff in die Knotenverwaltung

**Zusätzliche Ressourcen:**

- [Offizielle Karpenter-Dokumentation](https://karpenter.sh/docs/)
- [Best Practices für Karpenter](https://karpenter.sh/docs/concepts/nodepools/#best-practices)
- [Troubleshooting Guide](https://karpenter.sh/docs/troubleshooting/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

**Nächste Schritte:**

- Erkunden Sie fortgeschrittene Karpenter-Funktionen (weighted NodePools, custom AMI, GPU support)
- Integrieren Sie Karpenter in Ihre Produktionsanwendungen
- Konfigurieren Sie Monitoring und Alerting für Karpenter
- Optimieren Sie Kosten durch die Analyse der Nutzung von spot- gegenüber on-demand-Instances
