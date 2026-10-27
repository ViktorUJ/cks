[Русский](architecture_RU.md) · [English](architecture.md) · [Español](architecture_ES.md) · [Français](architecture_FR.md) · Deutsch · [ქართული](architecture_GE.md) · [繁體中文](architecture_TW.md) · [日本語](architecture_JP.md) · [Startseite](../README_DE.MD)

<a id="architecture"></a>

# Architektur der Plattform

Praktische Umgebungen sind als Code definiert. Das Makefile wählt ein Szenario, Terragrunt koordiniert Terraform-Module und Terraform erstellt AWS-Ressourcen und gibt Verbindungsdaten aus.

Selbstverwaltete Kubernetes-Szenarien installieren Cluster mit **kubeadm**. **Amazon EKS**-Labs verwenden verwaltetes Kubernetes auf AWS. Je nach Szenario entstehen VPCs, Subnetze, Sicherheitsgruppen, EC2-Instanzen (auch Spot), S3 und weitere benötigte Ressourcen.

<details>
<summary>Repository-Struktur</summary>

| Pfad | Zweck |
|---|---|
| [Makefile](../Makefile) | Befehle zum Starten, Löschen und Anzeigen von Umgebungen sowie zur Projektprüfung |
| [tasks](../tasks) | Kurse, Aufgaben, Labs und Probeprüfungen |
| [tasks/cka](../tasks/cka) | Gemeinsamer CKA + CKAD-Kurs, [Labs](../tasks/cka/labs) und [CKA-Probeprüfungen](../tasks/cka/mock) |
| [tasks/ckad](../tasks/ckad) | [CKAD-Probeprüfungen](../tasks/ckad/mock) |
| [tasks/cks](../tasks/cks) | CKS-Kurs, [Labs](../tasks/cks/labs) und [Probeprüfungen](../tasks/cks/mock) |
| [tasks/eks](../tasks/eks) | Amazon EKS-Kurs und Labs |
| [tasks/ica](../tasks/ica) | Istio / ICA-Kurs, Labs und Probeprüfungen |
| [tasks/kcsa](../tasks/kcsa) | KCSA-Kurs, Fragen und Probeprüfungen |
| [tasks/kcna](../tasks/kcna) | [KCNA-Probeprüfungen](../tasks/kcna/mock) |
| [tasks/lfcs](../tasks/lfcs) | Praktische LFCS-Probeprüfungen |
| [tasks/hr](../tasks/hr) | HR-Szenarien |
| [tasks/aws_AI_practitioner](../tasks/aws_AI_practitioner) | [AWS Certified AI Practitioner-Probeprüfungen](../tasks/aws_AI_practitioner/mock) |
| [terraform](../terraform) | Infrastrukturdefinitionen |
| [terraform/environments](../terraform/environments) | Terragrunt-Konfiguration und lokale Umgebungsverzeichnisse |
| [terraform/modules](../terraform/modules) | Wiederverwendbare Terraform-Module |
| [docs](../docs) | Lab-Katalog, Anleitungen und ergänzende Materialien |
| [CHANGELOG](../CHANGELOG/CHANGELOG.MD) | Änderungsprotokoll des Projekts |

</details>

<details>
<summary>Kubernetes, Runtimes, Betriebssystem und CNI</summary>

Für eigene Szenarien könnt ihr das Modul [k8s_self_managment](../terraform/modules/k8s_self_managment) verwenden. Es definiert einen selbstverwalteten Kubernetes-Cluster; Version, Runtime, Betriebssystem, AMI und Netzwerk werden im jeweiligen Szenario festgelegt.

Das Projekt verwendet oder verwendete folgende Optionen:

| Komponente | Optionen |
|---|---|
| Kubernetes | Historische Szenarien mit Versionen 1.21-1.34; neuere Übungen sind in `env.hcl` und der Kursbeschreibung dokumentiert |
| Container runtime | `containerd`, `containerd_gvizor`; ältere Szenarien auch `docker` und `cri-o` |
| Betriebssystem selbstverwalteter Clusterknoten | Ubuntu 20.04 LTS und 22.04 LTS, je nach Szenario |
| CNI | Calico oder Cilium, je nach Szenario |

Die frühere Beschreibung nannte Docker mit Kubernetes 1.21-1.23, CRI-O mit 1.21-1.29 sowie containerd und `containerd_gvizor` mit 1.21-1.33. Als Standard waren Kubernetes 1.33 für CKA/CKS und Ubuntu 22.04 für CKS angegeben. Das beschreibt ältere Konfigurationen und keine Kompatibilitätsmatrix neuer Labs. Entnehmt aktuelle Einstellungen den Quelldateien der Übung; die [Kubernetes-Releasehistorie](https://kubernetes.io/releases/) steht auf der Projektwebsite.

</details>
