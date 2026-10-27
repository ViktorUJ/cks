[Русский](run_from_docker_RU.MD) · [English](run_from_docker.MD) · [Español](run_from_docker_ES.MD) · [Français](run_from_docker_FR.MD) · Deutsch · [ქართული](run_from_docker_GE.MD) · [繁體中文](run_from_docker_TW.MD) · [日本語](run_from_docker_JP.MD) · [Startseite](../README_DE.MD)

# Schnellstart mit Docker

Das vorbereitete Docker-Image enthält die Abhängigkeiten und Werkzeuge zum Starten praktischer Labs und Probeprüfungen. Das folgende Beispiel startet die CKA-Probeprüfung Nr. 01.

[Videoanleitung](https://youtu.be/Xh6sWzafBmw)

## 1. Container starten

Führt auf einem Rechner mit installiertem Docker Folgendes aus:

```bash
sudo docker run -it viktoruj/runner
```

Führt alle weiteren Befehle innerhalb des Containers aus.

## 2. Repository klonen

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

## 3. Speicherung des Terraform-States konfigurieren

Öffnet [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl). Ersetzt `backend_bucket` durch den Namen eures eigenen S3-Buckets für den Terraform-State. Ändert bei Bedarf die Infrastrukturregion `region` und die Region für die State-Speicherung `backend_region`:

```hcl
locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "your-platform-state-bucket"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

Prüft außerdem die Region und die Einstellungen in der Datei `env.hcl` des ausgewählten Szenarios.

## 4. AWS-Zugriff konfigurieren

Ersetzt die Platzhalter durch eure eigenen Zugangsschlüssel:

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

Setzt bei temporären Zugangsdaten zusätzlich `AWS_SESSION_TOKEN`.

## 5. AWS-Kontingente prüfen

Die Umgebung benötigt möglicherweise mehrere EC2-Instanzen. Öffnet in der AWS-Konsole **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)** und prüft die Kontingente für die verwendete Region und Instanzfamilie:

- **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances** für On-Demand.
- **All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests** für Spot.

Diese Kontingente werden in vCPUs und nicht in der Anzahl von Instanzen gemessen. Reicht das verfügbare Kontingent für euer Szenario nicht aus, beantragt eine Erhöhung. Prüft für andere Instanzfamilien die entsprechenden Kontingente.

## 6. Szenario starten

Für eine einzelne Umgebung:

```bash
TASK=01 make run_cka_mock
```

Für einen bestimmten Benutzer oder mehrere unabhängige Umgebungen:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

Verbindet euch mit den Angaben aus der Terraform-Ausgabe mit dem Arbeitsrechner und folgt der [Prüfungsbeschreibung](../tasks/cka/mock/01/README.MD).

Wählt für eine andere Übung das Themengebiet und die Nummer im [Lab-Katalog](labs.MD) oder auf der [Startseite](../README_DE.MD). Die Startbefehle stehen in der [Befehlsreferenz](commands_DE.md).

## 7. Umgebung nach der Übung löschen

Die Ressourcen werden eurem AWS-Konto in Rechnung gestellt. Führt die in der README des Szenarios beschriebene Vorbereinigung durch und löscht anschließend die Umgebung.

Für eine einzelne Umgebung:

```bash
TASK=01 make delete_cka_mock
```

Für die Umgebung eines bestimmten Benutzers:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

Verwendet dieselben Werte für `TASK`, `USER_ID` und `ENV_ID` wie beim Starten des Szenarios.

[Unabhängige Umgebungen und CMDB](environments_DE.md) · [Nutzungsszenarien](usage_scenarios_DE.md)
