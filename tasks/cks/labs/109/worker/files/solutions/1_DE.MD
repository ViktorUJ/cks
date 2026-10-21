[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 - Referenzlösung: encryption at rest für Secrets

> Wir arbeiten wie in der Prüfung: `kubectl`-Befehle werden auf der Arbeitsmaschine ausgeführt, und Operationen am
> Node (etcd, Dateien und manifest der control-plane) - auf der control-plane selbst: Melde dich dort mit
> `ssh control-plane` an, führe die Befehle aus und verlasse sie wieder (`exit`). Das ist **nur ein Ein-Node-Lerncluster**; in production gibt man Benutzern keinen direkten Zugriff auf etcd.

## Wo du Beispiele in der Dokumentation findest

Alle Befehle unten stammen aus der offiziellen Kubernetes-Dokumentation - in der Prüfung musst du sie
dort finden und nicht auswendig kennen:

| Was gebraucht wird | Seite und Abschnitt |
| :--- | :--- |
| Den rohen Eintrag von etcd lesen und das Präfix `k8s:enc:aescbc:v1:` sehen (Befehl `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret1 \| hexdump -C`) | [Encrypting Confidential Data at Rest - Verify that newly written data is encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted) |
| Beispiel einer `EncryptionConfiguration` mit `aescbc` und `identity` | [Encrypting Confidential Data at Rest - Write an encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file) |
| Das Flag `--encryption-provider-config` und das Mounten der Datei in den static Pod des kube-apiserver | [Encrypting Confidential Data at Rest - Use the new encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file) |
| Alle Secrets neu schreiben (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`) | [Encrypting Confidential Data at Rest - Ensure all relevant data are encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted) |
| Schlüsselrotation (Schritte 1-7) und Löschen des alten Schlüssels | [Encrypting Confidential Data at Rest - Rotate a decryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#rotating-a-decryption-key) |
| Wo man die Pfade zu den etcd-Zertifikaten findet, wenn man sie sich nicht merkt: „`trusted-ca-file`, `cert-file` und `key-file` lassen sich der Beschreibung des etcd-Pods entnehmen“ (`kubectl -n kube-system describe pod etcd-<node>` oder `/etc/kubernetes/manifests/etcd.yaml`) | [Operating etcd clusters for Kubernetes - Snapshot using etcdctl options](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) |
| Role/RoleBinding und ServiceAccount (`automountServiceAccountToken`) | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) |

Pfade zu den Zertifikaten in einem kubeadm-Cluster: `/etc/kubernetes/pki/etcd/ca.crt`,
`/etc/kubernetes/pki/etcd/server.crt`, `/etc/kubernetes/pki/etcd/server.key`; der Standard-Endpoint ist
`https://127.0.0.1:2379`, daher wird auf der control-plane das Flag `--endpoints` nicht gebraucht.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
export NS=encryption-109
kubectl config use-context "$CTX"
```

## 1. Nachweis des plaintext vor dem Aktivieren der Verschlüsselung festhalten

`Secret.data` ist in der API base64-kodiert und nicht verschlüsselt. Der Bootstrap hat einen sicheren
canary vor dem Erscheinen der EncryptionConfiguration erstellt. Zuerst sehen wir uns den rohen Eintrag von etcd mit dem Befehl aus der
Dokumentation an, dann speichern wir den String-Nachweis in einer Datei auf der control-plane
(`/tmp/plaintext-proof.txt`) und kopieren ihn dann auf die Arbeitsmaschine nach
`/var/work/109/plaintext-proof.txt` (das Verzeichnis wurde vom bootstrap erstellt): Die Prüfung liest die Datei auf der Arbeitsmaschine.

Melde dich auf der control-plane an und führe dort aus (in diesem Befehl stammt alles aus der Dokumentation, außer dem Schlüssel in
etcd: `/registry/secrets/<namespace>/<name>`):

```bash
ssh control-plane
sudo -i
```

```bash
# auf der control-plane: roher Eintrag von etcd, die Ausgabe von hexdump -C zeigt plaintext
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C

# den Nachweis speichern (nur den Wert, über strings) - ebenfalls auf der control-plane
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings > /tmp/plaintext-proof.txt
cat /tmp/plaintext-proof.txt
# cks-109-legacy-plaintext
exit   # aus root
exit   # von der control-plane
```

```bash
# auf der Arbeitsmaschine: den Nachweis kopieren
scp control-plane:/tmp/plaintext-proof.txt /var/work/109/plaintext-proof.txt
cat /var/work/109/plaintext-proof.txt
```

In diesem Schritt steht in der Datei kein `k8s:enc:`. Das ist der Nachweis des Zustands **vor** der Konfiguration;
nach der re-encryption muss die erneute Ausgabe ciphertext sein, und der marker verschwindet.

## 2. EncryptionConfiguration erstellen

`aescbc` wurde nur für die Lernmechanik der CKS gewählt. Kubernetes hält AES-CBC wegen des
Risikos von padding-oracle-Angriffen für schwach und empfiehlt es nicht als production default. Verwende für einen externen key
manager KMS v2; einen lokalen provider wähle nur mit aktuellem threat model
und einem Rotationsverfahren.

Wir erzeugen einen 32-byte AES-256-Schlüssel, kodieren ihn in base64 und erstellen die Konfiguration auf der control-plane.
`aescbc` steht an erster Stelle: Mit ihm werden neue Secrets geschrieben. `identity` an letzter Stelle erlaubt dem API
server, den alten plaintext-Eintrag nur bis zur Migration zu lesen. Ein Beispiel der Datei steht auf der Seite der
Dokumentation (Link am Anfang der Lösung).

```bash
ssh control-plane
sudo -i
```

```bash
# auf der control-plane (root)
mkdir -m 700 /etc/kubernetes/enc
key=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/encryption-config.yaml
ls -ld /etc/kubernetes/enc; ls -l /etc/kubernetes/enc
exit   # aus root
exit   # von der control-plane
```

Den echten Schlüssel darf man nicht in Git, ein Ticket, ein Terminal-log oder Terraform state legen.
Bei Verlust des Schlüssels wird das encrypted Secret aus einem snapshot unlesbar.

## 3. Die Konfiguration an den static kube-apiserver anbinden

Zuerst speichern wir das manifest **außerhalb** des Verzeichnisses `/etc/kubernetes/manifests/`: Das kubelet liest jede nicht versteckte Datei dieses Verzeichnisses als static
Pod, einschließlich `*.bak`. Eine Kopie des ursprünglichen manifest innerhalb des
Verzeichnisses ist ein zweiter static Pod mit demselben Namen; das kubelet kann weiterhin genau diesen starten
(die alte Konfiguration ohne `--encryption-provider-config`), und die Änderung der Hauptdatei
wird stillschweigend nicht wirksam, und die Verschlüsselung bleibt bei äußerlich gesundem API server ausgeschaltet.
Öffne auf der control-plane genau das vorhandene static-Pod-Manifest
und füge **zu den vorhandenen** `command`, `volumeMounts` und `volumes` diese Elemente hinzu;
ersetze nicht die gesamte Datei durch eine Vorlage.

```bash
ssh control-plane
sudo -i
```

```bash
# auf der control-plane (root)
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# container name: kube-apiserver
command:
- kube-apiserver
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
volumeMounts:
- name: encryption-config
  mountPath: /etc/kubernetes/enc
  readOnly: true

# spec.volumes
volumes:
- name: encryption-config
  hostPath:
    path: /etc/kubernetes/enc
    type: Directory
```

Das Kubelet bemerkt die Änderung und startet den static Pod neu. Warte vor dem Fortfahren auf den API
server, sonst kann ein Fehler im YAML/Pfad die control-plane unzugänglich lassen.

```bash
# immer noch auf der control-plane: prüfen, dass das Flag ins laufende manifest gelangt ist, dann verlassen
grep -n -- '--encryption-provider-config\|encryption-config' /etc/kubernetes/manifests/kube-apiserver.yaml
exit   # aus root
exit   # von der control-plane
```

```bash
# auf der Arbeitsmaschine: Der API server startet etwa eine Minute lang neu; wiederhole, bis der Befehl
# "readyz check passed" zurückgibt (davor kommt "connection refused")
kubectl get --raw='/readyz?verbose'
```

## 4. Alte Secrets neu schreiben und ciphertext prüfen

Die Konfiguration ändert bereits gespeicherte Einträge nicht. Zuerst erstellen wir ein Secret nach dem Aktivieren des
providers, dann schreiben wir alle vorhandenen Secrets über die API neu. In production macht man davor
einen geschützten snapshot und verwendet ein kontrolliertes Verfahren mit retry.

```bash
kubectl -n "$NS" create secret generic encrypted-secret \
  --from-literal=token='cks-109-fresh-ciphertext'
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

kubectl -n "$NS" get secret legacy-secret -o jsonpath='{.data.token}' | base64 -d; echo
kubectl -n "$NS" get secret encrypted-secret -o jsonpath='{.data.token}' | base64 -d; echo
# cks-109-legacy-plaintext
# cks-109-fresh-ciphertext
```

Die rohen Einträge lesen wir auf der control-plane, wie in Aufgabe 1:

```bash
ssh control-plane
sudo -i
```

```bash
# auf der control-plane (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/encrypted-secret | hexdump -C
# beide Einträge beginnen mit k8s:enc:aescbc:v1:...
exit   # aus root
exit   # von der control-plane
```

Die API gibt einem autorisierten Client plaintext zurück - das ist normal und beweist die
Verschlüsselung at rest nicht. Der Nachweis ist hier: Rohes etcd enthält `k8s:enc:aescbc:v1:` für den
alten und den neuen Eintrag und enthält den legacy marker nicht mehr.

Jetzt wird der migration fallback nicht mehr gebraucht. Wir entfernen `identity`, starten den
static kube-apiserver zwangsweise über CRI neu und prüfen erneut Gesundheit und Lesen. Tue das nur
nach einem snapshot und der Bestätigung des ciphertext aller betroffenen Ressourcentypen.

```bash
ssh control-plane
sudo -i
```

```bash
# auf der control-plane (root): identity entfernen und den static kube-apiserver neu starten
vim /etc/kubernetes/enc/encryption-config.yaml   # die Zeile "- identity: {}" löschen
crictl stop $(crictl ps --name kube-apiserver -q)
exit   # aus root
exit   # von der control-plane
```

```bash
# auf der Arbeitsmaschine
until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
kubectl -n "$NS" get secret legacy-secret encrypted-secret
```

Der Endzustand dieses Labs: Der verschlüsselnde provider (`aescbc`) ist der erste und einzige, `identity`
ist entfernt. Der temporäre fallback darf nicht als dauerhafte „Absicherung“ stehen bleiben.

## 5. API-Zugriff einschränken und token automount deaktivieren

Encryption at rest ersetzt RBAC nicht: Ein Subjekt mit `get` auf ein Secret sieht plaintext über die API.
Wir erstellen einen ServiceAccount, dem genau ein Secret zugänglich ist, und einen Diagnose-Pod ohne
gemounteten service-account token.

```yaml
# rbac-109.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: encryption-109
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader-109
  namespace: encryption-109
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["encrypted-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-109
  namespace: encryption-109
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: encryption-109
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader-109
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader-109
  namespace: encryption-109
spec:
  serviceAccountName: secret-reader
  automountServiceAccountToken: false
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.10
```

```bash
kubectl apply -f rbac-109.yaml
kubectl wait -n "$NS" --for=condition=Ready pod/secret-reader-109 --timeout=120s
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/encrypted-secret -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader list secrets -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/legacy-secret -n "$NS"
# yes
# no
# no

check_result
```

`automountServiceAccountToken: false` verringert die für den Pod verfügbare credential surface, schränkt aber das RBAC des
ServiceAccount selbst nicht ein, falls die Anwendung andere credentials erhält.

## Zusatz: Wie KMS v2 und die vollständige Schlüsselrotation aussehen

### KMS v2: envelope encryption ohne lokalen Schlüssel in der Config

`aescbc` oben wird nur für die Lernmechanik gebraucht. In production bindet KMS v2 ein
unterstütztes KMS-plugin über einen lokalen Unix socket in der `EncryptionConfiguration` an.
Bei KMS v2 verwendet der API server einen verschlüsselten seed/DEK auf Ebene des API servers und
leitet daraus die Verschlüsselungsschlüssel einzelner Einträge ab. Das plugin schützt den seed über einen externen KEK;
dadurch unterscheidet sich KMS v2 vom per-resource KMS v1. Etcd speichert den ciphertext der Ressourcen und die
für die Entschlüsselung nötigen metadata. Der KEK bleibt im externen KMS und nicht in etcd oder Git. Das Schema
der Konfiguration hängt von der Kubernetes- und der plugin-Version ab, aber grundsätzlich werden ein provider `kms`,
ein stabiler key-Name und der Endpoint des sockets gebraucht. Kopiere keinen Beispiel-Endpoint aus einem fremden Cluster:
gleiche das Format von KMS v2 und die health/ACL-Anforderungen mit der Dokumentation deiner Version von Kubernetes ab.

### Vollständiger lifecycle der Rotation des aescbc key

Der Übergang `identity -> aescbc` in Aufgabe 4 ist eine migration und keine Rotation des Schlüssels für bereits
verschlüsselte Daten. Mache vor der Rotation einen verschlüsselten etcd snapshot und speichere
den alten Schlüssel für ein rollback. Füge den neuen Schlüssel **an erster Stelle** hinzu, und lasse den alten vorübergehend
an zweiter Stelle: providers werden der Reihe nach gelesen, und neue Einträge werden mit dem ersten Schlüssel geschrieben.

```yaml
- aescbc:
    keys:
    - name: cks-109-aescbc-2026-rotation
      secret: <base64-32-byte-new-key>
    - name: cks-109-aescbc
      secret: <base64-32-byte-old-key>
```

Schreibe nach dem Neustart des API servers die Ressourcen neu und prüfe genau den Namen des neuen key im rohen
ciphertext und nicht nur das allgemeine Präfix `k8s:enc`:

```bash
# auf der Arbeitsmaschine
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
ssh control-plane
sudo -i
```

```bash
# auf der control-plane (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings | grep -F 'k8s:enc:aescbc:v1:cks-109-aescbc-2026-rotation:'
exit   # aus root
exit   # von der control-plane
```

Wenn die migration aller Secrets bestätigt ist, das backup gemacht wurde, die API die Daten liest und `/readyz`
`ok` zurückgibt, entferne den alten key aus der Liste, starte den API server neu und wiederhole die
Prüfungen. Entferne den alten key nicht früher: Einträge, die nicht vom neuen provider neu geschrieben wurden, werden
unlesbar. Bei KMS v2 ist die Reihenfolge dieselbe: zuerst der neue primary KEK/das plugin, dann
re-encryption, Prüfung und erst nach der migration die Außerbetriebnahme des alten KEK.
