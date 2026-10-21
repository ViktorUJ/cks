[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 109 - Verschlüsselung von Secrets in etcd und minimaler Zugriff

## Ziel

In diesem CKS-Lab belegst du, dass ein Kubernetes Secret ohne encryption at rest in
etcd als lesbare bytes gespeichert wird (base64 ist keine Verschlüsselung), aktivierst `aescbc` über
`EncryptionConfiguration`, bindest es an den static `kube-apiserver` an, schreibst alte
Secrets neu und schränkst den Zugriff auf die Daten mit RBAC und `automountServiceAccountToken` ein.

`aescbc` wurde hier nur gewählt, um die Prüfungsmechanik von
`EncryptionConfiguration` und re-encryption zu üben. Die aktuelle Kubernetes-Dokumentation hält AES-CBC
für schwach und empfiehlt es wegen des Risikos von padding-oracle-Angriffen nicht; `aesgcm` erfordert ebenfalls
eine automatisierte Schlüsselrotation. Wähle für production den provider anhand der aktuellen
Dokumentation und des threat model; bei einem externen key manager ist KMS v2 vorzuziehen
(siehe [Kapitel 21](../../course/21/de.md)).

## Threat model

Encryption at rest schützt vor storage compromise: Nehmen wir an, der Angreifer hat read-only Zugriff auf einen etcd snapshot oder den storage layer erhalten, zum Beispiel über ein backup oder einen volume snapshot, hat aber keinen autorisierten API-Zugriff. Aufgabe 1 belegt gerade dieses ursprüngliche Risiko durch rohes Lesen von etcd.

Nach dem Aktivieren von encryption at rest verringern die Aufgaben 2–4 den blast radius eines solchen Zugriffs: Direkt gelesene Daten dürfen das Secret nicht preisgeben. Das ist kein universeller Schutz und kein Ersatz für die Zugriffskontrolle auf die API.

Wenn der Angreifer einen legitimen API-Zugriff mit Rechten zum Lesen von Secrets hat, schützt encryption at rest vor dieser Bedrohung nicht: Die API gibt den Wert nach der Entschlüsselung zurück. Daher schränkt Aufgabe 5 RBAC und automount separat ein und verringert den blast radius einer workload identity mit solchen Rechten.

## Prüfe dich vor dem Start

<details>
<summary>1. Warum ist base64 in `Secret.data` keine Verschlüsselung?</summary>

base64 ist nur eine Kodierung, ohne Schlüssel umkehrbar: Jeder, der Zugriff auf die bytes selbst hat (zum Beispiel über rohes Lesen von etcd), kann den Wert sofort dekodieren, ohne irgendwelche kryptografischen Operationen. Verschlüsselung erfordert einen Schlüssel für die Rückumwandlung - base64 hat diese Eigenschaft überhaupt nicht.
</details>

<details>
<summary>2. Warum muss der `identity` provider als LETZTER in der Liste der providers stehen und nicht als erster?</summary>

Die providers in `EncryptionConfiguration` werden der Reihe nach zum LESEN vorhandener Einträge probiert, und der erste provider wird zum SCHREIBEN neuer Daten verwendet. Steht `identity` (also "ohne Verschlüsselung") an erster Stelle, werden alle neuen Einträge UNverschlüsselt geschrieben, trotz des Vorhandenseins von `aescbc` in der Liste. `identity` an letzter Stelle erlaubt das Lesen alter (noch nicht migrierter) plaintext-Einträge, garantiert aber, dass alle neuen Einträge vom ersten provider verschlüsselt werden.
</details>

<details>
<summary>3. Warum darf man den alten Verschlüsselungsschlüssel nicht einfach direkt nach dem Hinzufügen des neuen löschen?</summary>

Vorhandene Einträge in etcd bleiben mit dem ALTEN Schlüssel verschlüsselt, bis sie explizit neu geschrieben werden (re-encryption). Wenn man den alten Schlüssel aus der aktiven `EncryptionConfiguration` entfernt, bevor alle Einträge mit dem neuen neu geschrieben wurden, kann der API server die verbleibenden alten Einträge über die aktuelle provider chain nicht entschlüsseln - sie werden unlesbar, bis der alte Schlüssel wieder in die Konfiguration aufgenommen wird. Das bloße Löschen des Schlüssels aus der Konfiguration zerstört das key material nicht physisch: Wenn man den gespeicherten alten Schlüssel wieder in die provider chain aufnimmt, ist der Zugriff wiederhergestellt. Ein unumkehrbarer Datenverlust tritt nur ein, wenn das key material selbst tatsächlich verloren oder zerstört wurde (zum Beispiel wurde der Schlüssel vor dem Löschen nirgendwo gespeichert). Reihenfolge: den neuen Schlüssel an erster Stelle hinzufügen → alle Secrets neu schreiben → bestätigen, dass alle Einträge den neuen Schlüssel verwenden → den alten Schlüssel für ein rollback an einem sicheren Ort aufbewahren → erst dann aus der Konfiguration entfernen.
</details>

## Infrastruktur

Die Umgebung wird von Terragrunt in AWS `eu-central-1` ausgerollt:

| Komponente | Zweck |
|---|---|
| `vpc` | VPC `10.10.0.0/16` mit öffentlichen Subnetzen |
| `ssh-keys` | SSH-Schlüssel für worker und control-plane |
| `k8s-1` | Ein-Node-kubeadm control-plane: Kubernetes **1.36.0**, containerd, **Calico** |
| `worker` | Arbeitsmaschine mit `kubectl`; auf der control-plane (`ssh control-plane`) ist das Standard-`etcdctl` 3.6.0 installiert, wie in der Prüfung |

Die control-plane akzeptiert absichtlich gewöhnliche Pods - ein separater Kubernetes-worker wird nicht erstellt.
Vor Beginn der Aufgaben erstellt der bootstrap den Namespace `encryption-109` und ein harmloses
`legacy-secret`. Dieses Secret wurde **vor** der EncryptionConfiguration erstellt und dient daher als
kontrollierter Nachweis des plaintext-Zustands.

Operationen am Node werden auf der control-plane selbst ausgeführt, wie in der Prüfung: Melde dich dort an
(`ssh control-plane`), arbeite dort und verlasse sie wieder (`exit`); `kubectl` - von der Arbeitsmaschine. Der rohe Eintrag
von etcd wird mit dem Standard-`etcdctl` aus der Kubernetes-Dokumentation mit den kubeadm-Zertifikaten aus
`/etc/kubernetes/pki/etcd/` (`ca.crt`, `server.crt`, `server.key`) gelesen. Fertige Beispielbefehle stehen
im Abschnitt „Wo du Beispiele in der Dokumentation findest“ der Referenzlösung.

## Bereitstellung

```bash
TASK=109 make run_cks_task
```

Verbinde dich mit der Arbeitsmaschine. Der Kontext `cluster1-admin@cluster1` ist bereits eingerichtet.

```bash
time_left
check_result
```

## Aufgaben

---
| **1** | **Das ursprüngliche plaintext Secret belegen** |
| :---: | :--- |
| Was wir tun | • Fordere vor dem Aktivieren der Verschlüsselung den rohen Eintrag `/registry/secrets/encryption-109/legacy-secret` mit dem Standard-`etcdctl get ... --print-value-only` an<br/>• Melde dich auf der control-plane an (`ssh control-plane`) und arbeite dort, wie in der Prüfung: Leite die Ausgabe durch `strings` und speichere das Ergebnis in einer Datei auf der control-plane (`/tmp/plaintext-proof.txt`), kopiere sie dann mit `scp` auf die Arbeitsmaschine nach `/var/work/109/plaintext-proof.txt` |
| Abnahmekriterien | • Die Datei enthält die vollständige `strings`-Ausgabe des ursprünglichen rohen Eintrags (stimmt mit dem Snapshot des bootstrap überein, einschließlich des Markers `cks-109-legacy-plaintext`) und enthält nicht `k8s:enc:`<br/>• Eine von Hand eingetippte Zeile wird nicht akzeptiert<br/>• Das ist der Beleg des Ausgangszustands: `Secret.data` ist base64 und nicht encryption at rest |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

Diese Aufgabe muss ZUERST erledigt werden, vor Aufgabe 2 - sobald du die EncryptionConfiguration aktivierst und das Secret neu schreibst, verschwindet der plaintext-Nachweis, und du kannst ihn nicht mehr post-hoc festhalten. Der Befehl `etcdctl` mit den Flags `--cacert/--cert/--key` stammt aus der offiziellen Kubernetes-Dokumentation (Abschnitt „Verify that newly written data is encrypted“ auf der Seite Encrypting Confidential Data at Rest); die Zertifikatspfade von kubeadm: `/etc/kubernetes/pki/etcd/ca.crt`, `server.crt`, `server.key`. Die genauen Links stehen im Abschnitt „Wo du Beispiele in der Dokumentation findest“ der Referenzlösung.
</details>

---
| **2** | **EncryptionConfiguration für Secrets erstellen** |
| :---: | :--- |
| Was wir tun | • Erstelle auf der control-plane `/etc/kubernetes/enc/encryption-config.yaml`, owner `root:root`, mode `0600`<br/>• Format: `apiserver.config.k8s.io/v1`, `EncryptionConfiguration`<br/>• Setze für `secrets` als ersten provider `aescbc` mit einem benannten base64-Schlüssel aus **32 zufälligen bytes**, danach `identity: {}` |
| Abnahmekriterien | • Die Datei ist `root:root` mode `0600` in einem Verzeichnis `root:root` mode `0700`<br/>• Der primär wirksame provider für `secrets` ist der **erste** `aescbc` mit einem korrekten named base64 key aus 32 bytes<br/>• `identity` ist nur als letzter temporärer Fallback für legacy plaintext zulässig<br/>• Ein Symlink auf Datei/Verzeichnis ist verboten |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

Erzeuge den Schlüssel über `head -c 32 /dev/urandom | base64` - genau 32 BYTES (nicht 32 Zeichen eines base64-Strings, der durch die Kodierung länger wird). Prüfe dich selbst: `echo -n "<dein-base64-schlüssel>" | base64 -d | wc -c` muss genau `32` zurückgeben.
</details>

---
| **3** | **Config an den static kube-apiserver anbinden** |
| :---: | :--- |
| Was wir tun | • Ändere vorsichtig `/etc/kubernetes/manifests/kube-apiserver.yaml`: Füge das Flag `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`, ein read-only `volumeMount` `/etc/kubernetes/enc` und das entsprechende `hostPath` volume `/etc/kubernetes/enc` hinzu<br/>• Speichere vor der Änderung ein backup des Manifests |
| Abnahmekriterien | • Das laufende Manifest enthält Flag, mount und hostPath<br/>• Nach dem restart des static Pods gibt `kubectl get --raw='/readyz'` `ok` zurück |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

Drei separate Änderungen werden gleichzeitig gebraucht: das Flag `--encryption-provider-config` selbst, `volumeMounts` (im Container) UND `volumes` (hostPath auf Ebene der Pod spec) - fehlt eines der drei, führt das entweder zu CrashLoopBackOff (das Flag zeigt auf eine Datei, die der Container nicht sieht) oder dazu, dass das Flag einfach nicht übergeben wird. Speichere das backup **außerhalb** von `/etc/kubernetes/manifests`, zum Beispiel `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109`. Das Kubelet liest zusätzliche nicht versteckte Dateien aus dem Verzeichnis der static manifests; ein benachbartes `kube-apiserver.yaml.bak` kann als zweiter static Pod aufgefasst werden und das Anwenden der neuen Konfiguration blockieren.
</details>

---
| **4** | **Re-encrypt und ciphertext belegen** |
| :---: | :--- |
| Was wir tun | • Erstelle nach der Bereitschaft des API servers in `encryption-109` das Secret `encrypted-secret` mit dem literal `token=cks-109-fresh-ciphertext`<br/>• Schreibe alle zuvor vorhandenen Secrets über die API neu (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`)<br/>• Prüfe beide Secrets über die API und über rohes etcd<br/>• Lösche erst nach dieser Prüfung den temporären `identity` fallback, starte den static kube-apiserver neu und prüfe erneut `/readyz` und das Lesen beider Secrets |
| Abnahmekriterien | • `legacy-secret` und `encrypted-secret` werden über die API mit den ursprünglichen Werten gelesen<br/>• Der raw value von jedem beginnt mit `k8s:enc:aescbc:v1:`<br/>• Der legacy marker ist in rohem etcd nicht mehr sichtbar<br/>• Die ursprünglichen payload/UID des gesamten bootstrap Secret corpus sind erhalten, alle Einträge sind mit dem ersten wirksamen Schlüssel verschlüsselt<br/>• Der Schlüssel aus der finalen Datei kann den ciphertext beider canary Secrets entschlüsseln<br/>• In der finalen Konfiguration fehlt `identity`, die API ist healthy |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

Die Reihenfolge ist entscheidend: `encrypted-secret` erstellen → ALLE vorhandenen Secrets über `kubectl replace` neu schreiben → rohes etcd für BEIDE prüfen (legacy und encrypted) → ERST DANN `identity` aus der Konfiguration entfernen. Wenn du `identity` entfernst, bevor `legacy-secret` neu geschrieben wurde, kann der API server den alten plaintext-Eintrag über die provider chain nicht mehr lesen, und `legacy-secret` wird unzugänglich.
</details>

---
| **5** | **RBAC minimieren und automount deaktivieren** |
| :---: | :--- |
| Was wir tun | • Erstelle den ServiceAccount `secret-reader` in `encryption-109` mit `automountServiceAccountToken: false`<br/>• Die Role `secret-reader-109` muss nur `get` nur auf das Secret `encrypted-secret` geben<br/>• Binde sie mit einem gleichnamigen RoleBinding<br/>• Erstelle den Pod `secret-reader-109` mit diesem ServiceAccount, `automountServiceAccountToken: false`, dem Image `registry.k8s.io/pause:3.10` |
| Abnahmekriterien | • Das effective RBAC für den ServiceAccount mit seinen regulären Gruppen erlaubt `get encrypted-secret` in `encryption-109` und verbietet andere Secret-Operationen, auch den Zugriff auf Secrets anderer Namespaces<br/>• Role/RoleBinding sind exakt<br/>• Der Pod ist Running mit einem einzigen `pause:3.10`, ohne automatisch oder manuell gemountete ServiceAccount token und andere credential-bearing sources (Secret/hostPath/CSI/PVC volumes, Secret env/envFrom)<br/>• Harmlose emptyDir/ConfigMap volumes sind zulässig<br/>• `automountServiceAccountToken: false` in Pod und ServiceAccount |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

Verwende `resourceNames: ["encrypted-secret"]` in der Role - ohne dieses Feld würde `get`/`list` auf die Ressource `secrets` Zugriff auf ALLE Secrets im Namespace geben, einschließlich `legacy-secret`, was die Anforderung von least-privilege verletzt. `pause:3.10` ist ein Platzhalter-Image, das die Kubernetes API überhaupt nicht braucht, daher wird automount auf zwei Ebenen (SA und Pod) ohne funktionale Folgen deaktiviert.
</details>

## Prüfung

```bash
check_result
```

Die Prüfung enthält Init und fünf obligatorische Tests. Test 4 prüft nicht nur das Vorhandensein
der Konfigurationsdatei, sondern den echten ciphertext `k8s:enc:aescbc:v1:` für den neuen und den früheren
etcd-Eintrag und das Fehlen eines nur für die Migration gedachten `identity` in der finalen Konfiguration. Vor einer massenhaften re-encryption in einer realen Umgebung sind ein snapshot, ein Plan zur
Rotation der Schlüssel und ein kontrolliertes Zeitfenster erforderlich; dieses Lab ist kein production runbook.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD)

## Löschen

```bash
TASK=109 make delete_cks_task
```

## Zusatz: KMS v2 und der vollständige Lebenszyklus der Rotation

**KMS v2 (optionaler walkthrough).** Ein externes KMS-plugin wird als
provider `kms` in der `EncryptionConfiguration` an den API server angebunden; sein Endpoint ist ein lokaler Unix socket, und der Schlüssel
des providers erhält einen stabilen Namen, zum Beispiel `kms-v2-primary`. In KMS v2 erhält der API server über das plugin einen verschlüsselten seed (wrapped unter einem externen
**KEK**) und leitet daraus Schlüssel für die Verschlüsselung einzelner Objekte ab. KMS v2
verwendet seed/DEK auf Ebene des API servers und nicht einen separaten KMS-Aufruf für jedes Secret.
In etcd werden der ciphertext des Secrets und die notwendigen Daten zur Wiederherstellung des Schlüssels gespeichert. Somit liegt der KEK nicht in etcd; availability, ACL und backup des KMS werden
Teil des Sicherheitsmodells. Ein minimaler **illustrativer** provider (der Endpoint muss
zum installierten plugin passen) sieht so aus:

```yaml
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: kms-v2-primary
      endpoint: unix:///var/run/kms-plugin/socket.sock
```

Füge den provider für neue Einträge an erster Stelle hinzu, mounte den socket in den static `kube-apiserver`
und warte vor der re-encryption, bis das plugin healthy ist. Verwende für eine reale Konfiguration ein
unterstütztes plugin und das aktuelle Format von `kms` v2 aus der Dokumentation der verwendeten Version von
Kubernetes; dieses Lab startet kein KMS-plugin und stellt keinen funktionierenden socket bereit.

**Vollständige Rotation des Schlüssels des providers.** Die in Aufgabe 4 durchgeführte Migration von plaintext auf den ersten
`aescbc`-Schlüssel ist keine vollständige Schlüsselrotation. Für diese: (1) mache einen geschützten etcd snapshot und
prüfe, dass der alte Schlüssel gespeichert und für ein rollback verfügbar ist; (2) füge den neuen Schlüssel
an erster Stelle in `aescbc.keys` hinzu, lasse den alten an zweiter Stelle und starte dann den API server neu; (3)
schreibe die vorhandenen Secrets über die API neu, damit sie mit dem neuen ersten Schlüssel verschlüsselt werden;
(4) bestätige für stichprobenartige und dann alle rohen etcd-Einträge das Präfix
`k8s:enc:aescbc:v1:<name-des-neuen-schlüssels>:`; (5) entferne erst nach vollständiger Migration, backup und
Leseprüfung den alten Schlüssel, starte den API server neu und prüfe erneut `/readyz`
und die Secrets. Bei KMS v2 schaltet man analog zuerst den primary KEK/das plugin um, führt
die re-encryption durch und nimmt erst danach den alten KEK nach dem KMS-Verfahren außer Betrieb.
