[Русский](usage_scenarios_RU.md) · [English](usage_scenarios.md) · [Español](usage_scenarios_ES.md) · [Français](usage_scenarios_FR.md) · Deutsch · [ქართული](usage_scenarios_GE.md) · [繁體中文](usage_scenarios_TW.md) · [日本語](usage_scenarios_JP.md) · [Startseite](../README_DE.MD)

<a id="usage"></a>

# Nutzungsszenarien und Videos

<details>
<summary>CKA + CKAD- und CKS-Labs: vom Start zur Prüfung</summary>

1. Wählt eine Übung im [Lab-Katalog](labs.MD) und lest ihre Beschreibung: `tasks/cka/labs/<number>/README_DE.MD` oder `tasks/cks/labs/<number>/README_DE.MD` für übersetzte Übungen.
2. Prüft `env.hcl`: Region, Instanztypen und Einstellungen. Ein manuell gesetztes `ami_id` muss zur Region und Instanzarchitektur passen; folgt bei automatischer Auswahl der Szenariokonfiguration.
3. Erstellt die Umgebung mit `TASK=101 make run_cka_task` oder `TASK=101 make run_cks_task`.
4. Findet den SSH-Befehl in der Terraform-Ausgabe. Zusammengesetzte Labs beginnen meist auf dem Arbeitsrechner `worker`, manche Szenarien auf einem Control-Plane-Knoten. Nutzt `worker_pc_ip`, `master_external_ip` oder den vom Szenario ausgegebenen Verbindungsbefehl.
5. Verbindet euch als `ubuntu`. Nutzt bei Schlüsselzugriff `ssh ubuntu@<IP> -i <key_path>`. Wird ein Passwort ausgegeben, verbindet euch mit `ssh ubuntu@<IP>` und gebt es auf Nachfrage ein.
6. Prüft bei Bedarf den Abschluss der Einrichtung auf dem passenden Rechner: `tail -f /var/log/cloud-init-output.log`.
7. Bearbeitet die Aufgaben. Führt in zusammengesetzten Labs `check_result` auf dem Arbeitsrechner aus und beachtet die beschriebene Prüfmethode.
8. Seht euch die Referenzlösung an. Für Lab 101: [CKA + CKAD](../tasks/cka/labs/101/worker/files/solutions/1_DE.MD) und [CKS](../tasks/cks/labs/101/worker/files/solutions/1_DE.MD). Andere Übungen können Lösungen anders ablegen; nutzt den Katalog oder die Beschreibung.
9. Führt die im Löschabschnitt beschriebene Vorbereinigung durch und löscht mit `TASK=101 make delete_cka_task` oder `TASK=101 make delete_cks_task`.

Verwendet für einen Neustart nach Leeren des lokalen Verzeichnisses `run_cka_task_clean` oder `run_cks_task_clean`. Cloud-Ressourcen werden mit `delete_*` gelöscht.

</details>

<details>
<summary>Praktische CKA-, CKAD-, CKS-, ICA- und HR-Probeprüfungen</summary>

Allgemeiner Ablauf:

1. Wählt eine Prüfungsnummer und öffnet die README unter `tasks/<track>/mock/<number>/`.
2. Ändert bei Bedarf vorgesehene Einstellungen in `env.hcl`: Betriebssystem (`ubuntu_version`), EC2-Kaufmodell (`spot` oder `ondemand`) und Instanztypen.
3. Startet mit `TASK=<number> make run_<track>_mock`. `run_<track>_mock_clean` startet nach Leeren des lokalen Verzeichnisses.
4. Findet `worker_pc_ip` oder den SSH-Befehl in der Terraform-Ausgabe und verbindet euch als `ubuntu` mit dem vorgesehenen Schlüssel oder Passwort.
5. Öffnet die Aufgaben und arbeitet vom Arbeitsrechner aus. Verwendet `ssh <node_name>` für den Knotenzugriff gemäß Prüfungsbeschreibung.
6. Prüft Restzeit mit `time_left` und Ergebnisse mit `check_result`, sofern vorgesehen.
7. Seht euch nach dem Versuch die unten verlinkten Lösungen und Tests an.
8. Löscht mit `TASK=<number> make delete_<track>_mock`.

| Themengebiet | Aufgaben der Prüfung 01 | Lösungen | Automatische Prüfungen |
|---|---|---|---|
| CKA | [Beschreibung](../tasks/cka/mock/01) | [Lösungen](../tasks/cka/mock/01/worker/files/solutions) | [tests.bats](../tasks/cka/mock/01/worker/files/tests.bats) |
| CKAD | [Beschreibung](../tasks/ckad/mock/01) | [Lösungen](../tasks/ckad/mock/01/worker/files/solutions) | [tests.bats](../tasks/ckad/mock/01/worker/files/tests.bats) |
| CKS | [Beschreibung](../tasks/cks/mock/01) | [Lösungen](../tasks/cks/mock/01/worker/files/solutions) | [tests.bats](../tasks/cks/mock/01/worker/files/tests.bats) |
| ICA | [Beschreibung](../tasks/ica/mock/01) | [Lösungen](../tasks/ica/mock/01/worker/files/solutions) | [Testverzeichnis](../tasks/ica/mock/01/worker/files/tests) |
| HR | [Beschreibung](../tasks/hr/mock/01) | [Lösungen](../tasks/hr/mock/01/worker/files/solutions) | [tests.bats](../tasks/hr/mock/01/worker/files/tests.bats) |

Videoanleitungen und Besprechungen:

- CKA: [Probeprüfung starten](https://www.youtube.com/watch?v=P-YYX4CTWIg), [Lösungen der Prüfung 01](https://youtu.be/IZsqAPpbBxM).
- CKS: [Probeprüfung starten](https://youtu.be/_GbsBOMaJ9Q), [Lösungsbesprechung](https://youtu.be/I8CPwcGbrG8).
- CKAD: [Probeprüfung starten](https://youtu.be/7X4Y9QhbTsk), [Lösungsbesprechung](https://youtu.be/yQK7Ca8d-yw).
- HR: [Video zum Szenario](https://youtu.be/4CTC1jl8lxE).

</details>

<details>
<summary>Amazon EKS: ein Lab bearbeiten</summary>

1. Wählt eine Nummer im [EKS-Katalog](labs.MD#eks-labs) und lest die Beschreibung.
2. Prüft `env.hcl` und führt `TASK=101 make run_eks_task` mit der gewählten Lab-Nummer aus.
3. Findet `worker_pc_ip` oder den SSH-Befehl in der Terraform-Ausgabe. Verbindet euch als `ubuntu` per Schlüssel oder Passwort gemäß Beschreibung.
4. Bearbeitet die Aufgaben und prüft das Ergebnis. Zusammengesetzte Labs bieten `check_result`.
5. Seht euch die verlinkte Lösung an, beispielsweise die [Lösung zu Lab 101](../tasks/eks/labs/101/worker/files/solutions/1_DE.MD).
6. Führt die Vorbereinigung im Löschabschnitt durch und startet `TASK=101 make delete_eks_task` mit der richtigen Nummer.

</details>

Weitere Szenarien: [Istio / ICA-Labs](../tasks/ica/README_DE.MD), [LFCS-Probeprüfung Nr. 01](../tasks/lfcs/mock/01), [KCSA-Testmaterialien](../tasks/kcsa/README_DE.md), [KCNA-Probeprüfung Nr. 01](../tasks/kcna/mock/01/README.MD), [AWS Certified AI Practitioner-Probeprüfung Nr. 01](../tasks/aws_AI_practitioner/mock/01/README.MD).
