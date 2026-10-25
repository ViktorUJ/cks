[Русский](commands_RU.md) · [English](commands.md) · [Español](commands_ES.md) · [Français](commands_FR.md) · Deutsch · [ქართული](commands_GE.md) · [繁體中文](commands_TW.md) · [日本語](commands_JP.md) · [Startseite](../README_DE.MD)

<a id="commands"></a>

# Befehlsreferenz

Führt alle Befehle im Repository-Stamm aus. `TASK` ist die Nummer des Labs oder der Probeprüfung. Verwendet dieselben `TASK`, `USER_ID` und `ENV_ID` beim Start, beim Anzeigen der Terraform-Ausgaben und beim Löschen.

Befehle mit `_clean` leeren vor der Operation das lokale Verzeichnis der betreffenden Umgebung. Sie ersetzen nicht das Löschen der Cloud-Ressourcen mit `delete_*`.

<details>
<summary>CKA + CKAD: Labs und CKA-Probeprüfungen</summary>

Die zusammengesetzten Labs des gemeinsamen CKA + CKAD-Kurses verwenden `cka_task`.

| Befehl | Aktion |
|---|---|
| `TASK=101 make run_cka_task` | Erstellen: [Lab CKA + CKAD 101](labs.MD#cka-labs) |
| `TASK=101 make delete_cka_task` | Lab-Umgebung löschen |
| `TASK=101 make run_cka_task_clean` | Lab nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=101 make output_cka_task` | Terraform-Ausgaben anzeigen |
| `TASK=01 make run_cka_mock` | Erstellen: [Probeprüfung CKA 01](../tasks/cka/mock/01) |
| `TASK=01 make delete_cka_mock` | Umgebung der Probeprüfung löschen |
| `TASK=01 make run_cka_mock_clean` | Prüfung nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=01 make output_cka_mock` | Terraform-Ausgaben anzeigen |

</details>

<details>
<summary>CKAD: Probeprüfungen</summary>

| Befehl | Aktion |
|---|---|
| `TASK=01 make run_ckad_mock` | Erstellen: [Probeprüfung CKAD 01](../tasks/ckad/mock/01) |
| `TASK=01 make delete_ckad_mock` | Umgebung der Probeprüfung löschen |
| `TASK=01 make run_ckad_mock_clean` | Prüfung nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=01 make output_ckad_mock` | Terraform-Ausgaben anzeigen |

</details>

<details>
<summary>CKS: Labs und Probeprüfungen</summary>

| Befehl | Aktion |
|---|---|
| `TASK=101 make run_cks_task` | Erstellen: [Lab CKS 101](labs.MD#cks-labs) |
| `TASK=101 make delete_cks_task` | Lab-Umgebung löschen |
| `TASK=101 make run_cks_task_clean` | Lab nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=101 make output_cks_task` | Terraform-Ausgaben anzeigen |
| `TASK=01 make run_cks_mock` | Erstellen: [Probeprüfung CKS 01](../tasks/cks/mock/01) |
| `TASK=01 make delete_cks_mock` | Umgebung der Probeprüfung löschen |
| `TASK=01 make run_cks_mock_clean` | Prüfung nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=01 make output_cks_mock` | Terraform-Ausgaben anzeigen |

</details>

<details>
<summary>Istio / ICA: Labs und Probeprüfungen</summary>

| Befehl | Aktion |
|---|---|
| `TASK=01 make run_ica_task` | Erstellen: [Lab ICA 01](labs.MD#ica-labs-istio-certified-associate) |
| `TASK=01 make delete_ica_task` | Lab-Umgebung löschen |
| `TASK=01 make run_ica_task_clean` | Lab nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=01 make output_ica_task` | Terraform-Ausgaben anzeigen |
| `TASK=01 make run_ica_mock` | Erstellen: [Probeprüfung ICA 01](../tasks/ica/mock/01) |
| `TASK=01 make delete_ica_mock` | Umgebung der Probeprüfung löschen |
| `TASK=01 make run_ica_mock_clean` | Prüfung nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=01 make output_ica_mock` | Terraform-Ausgaben anzeigen |

</details>

<details>
<summary>Amazon EKS: Labs</summary>

| Befehl | Aktion |
|---|---|
| `TASK=101 make run_eks_task` | Erstellen: [Lab EKS 101](labs.MD#eks-labs) |
| `TASK=101 make delete_eks_task` | Lab-Umgebung löschen |
| `TASK=101 make run_eks_task_clean` | Lab nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=101 make output_eks_task` | Terraform-Ausgaben anzeigen |

Führt vor dem Löschen einer EKS-Umgebung die im Lab beschriebene Vorbereinigung durch. Manche Ressourcen entstehen durch Kubernetes-Controller oder manuell und müssen vor Terraform destroy gelöscht werden.

</details>

<details>
<summary>LFCS: Probeprüfungen</summary>

| Befehl | Aktion |
|---|---|
| `TASK=01 make run_lfcs_mock` | Erstellen: [Probeprüfung LFCS 01](../tasks/lfcs/mock/01) |
| `TASK=01 make delete_lfcs_mock` | Umgebung der Probeprüfung löschen |
| `TASK=01 make run_lfcs_mock_clean` | Prüfung nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=01 make delete_lfcs_mock_clean` | Prüfung nach Leeren des lokalen Umgebungsverzeichnisses löschen |
| `TASK=01 make output_lfcs_mock` | Terraform-Ausgaben anzeigen |

</details>

<details>
<summary>HR: praktische Szenarien</summary>

| Befehl | Aktion |
|---|---|
| `TASK=01 make run_hr_mock` | Erstellen: [HR-Szenario 01](../tasks/hr/mock/01) |
| `TASK=01 make delete_hr_mock` | Szenarioumgebung löschen |
| `TASK=01 make run_hr_mock_clean` | Szenario nach Leeren des lokalen Umgebungsverzeichnisses starten |
| `TASK=01 make output_hr_mock` | Terraform-Ausgaben anzeigen |

</details>

<details>
<summary>KCNA, KCSA und AWS Certified AI Practitioner: Testmaterialien</summary>

Öffnet den passenden Abschnitt und folgt dessen Anleitung:

- [KCNA: Probeprüfung Nr. 01](../tasks/kcna/mock/01/README.MD).
- [KCSA: Kurs, Fragen und Probeprüfungen](../tasks/kcsa/README_DE.md).
- [AWS Certified AI Practitioner: Probeprüfung Nr. 01](../tasks/aws_AI_practitioner/mock/01/README.MD).

</details>

<details>
<summary>Entwicklung und Prüfungen</summary>

`make lint` - die konfigurierten Projektprüfungen über pre-commit ausführen.

</details>
