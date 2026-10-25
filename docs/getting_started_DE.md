[Русский](getting_started_RU.md) · [English](getting_started.md) · [Español](getting_started_ES.md) · [Français](getting_started_FR.md) · Deutsch · [ქართული](getting_started_GE.md) · [繁體中文](getting_started_TW.md) · [日本語](getting_started_JP.md) · [Startseite](../README_DE.MD)

<a id="quick-start"></a>

# Einstieg und Voraussetzungen

Zum Lesen der Kurse genügt das Repository. Praktische Umgebungen benötigen AWS und die Plattformwerkzeuge. Ressourcen werden eurem AWS-Konto berechnet; löscht Umgebungen nach der Übung gemäß der Szenarioanleitung.

## 1. Werkzeuge vorbereiten

Ihr könnt das vorbereitete Docker-Image mit den Abhängigkeiten verwenden:

```bash
sudo docker run -it viktoruj/runner
```

[Docker-Startanleitung](run_from_docker_DE.MD) · [Videoanleitung](https://youtu.be/Xh6sWzafBmw)

[![Plattform mit Docker starten](images/run_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "Plattform mit Docker starten")

<details>
<summary>Voraussetzungen für die lokale Installation</summary>

- [GNU Make](https://www.gnu.org/software/make/) ≥ 4.2.1.
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) ≥ 1.6.6.
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) ≥ 0.54.8.
- [jq](https://jqlang.github.io/jq/download/) ≥ 1.6.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30.
- Ein [AWS-Profil](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) oder eine andere konfigurierte Authentifizierung.
- Ein [IAM-Benutzer](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) mit [Zugangsschlüssel](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) oder eine [IAM-Rolle](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) mit Berechtigungen zum Erstellen und Löschen der Szenarioressourcen. Die ursprüngliche Konfiguration setzt weitreichende Rechte für VPC, EC2, IAM und EKS voraus; siehe [AWS-Zugriffsrichtlinien](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html).

Dies sind die ursprünglichen Mindestversionen der Plattformdokumentation. Weitere Anforderungen an Werkzeuge und Provider findet ihr im ausgewählten Szenario und seiner Terraform-Konfiguration.

</details>

## 2. Repository holen und AWS konfigurieren

Führt diese Befehle im Docker-Container oder auf einem Rechner mit installierten Werkzeugen aus:

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

Konfiguriert AWS-Zugriff. Setzt euren eigenen `backend_bucket` in [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl); ändert bei Bedarf `region` und `backend_region`. Prüft Region und Einstellungen in der `env.hcl` des Szenarios. Die [Docker-Anleitung](run_from_docker_DE.MD) beschreibt die Einrichtung.

## 3. Übung auswählen und starten

Beispiel für das erste zusammengesetzte CKA + CKAD-Lab:

```bash
TASK=101 make run_cka_task
```

Öffnet [Lab 101](../tasks/cka/labs/101/README_DE.MD), verbindet euch anhand der Terraform-Ausgabe und bearbeitet die Aufgaben.

## 4. Umgebung löschen

Folgt nach der Übung deren Löschanleitung und führt anschließend Folgendes aus:

```bash
TASK=101 make delete_cka_task
```

Ersetzt für andere Übungen die Nummer und verwendet den passenden Befehl aus der [Befehlsreferenz](commands_DE.md).
