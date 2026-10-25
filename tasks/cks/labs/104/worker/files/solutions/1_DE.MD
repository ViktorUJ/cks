[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 104 - Referenzlösung: RBAC, ServiceAccount token und anonymous API

> Führe die Befehle von der Arbeitsmaschine aus, sofern im Schritt nichts anderes steht. Der Namespace
> `security-104` existiert bereits.
>
> In der Prüfung sind `k` (`alias k=kubectl`) und die bash-completion dafür auf dem SSH-Host bereits eingerichtet -
> verschwende keine Zeit mit deren Einrichtung, verwende einfach `k` (siehe Kapitel 33.6).

## 1. Minimaler Zugriff von `auditor` nur auf Pods

In der Prüfung ist es Zeitverschwendung, das vollständige YAML für ein typisches RBAC-Objekt von Hand zu schreiben:
`kubectl create` erzeugt ServiceAccount/Role/RoleBinding mit je einem Befehl:

```bash
k create sa auditor -n security-104
k create role pod-observer -n security-104 --resource=pods --verb=get,list,watch
k create rolebinding auditor-pod-observer -n security-104 \
  --role=pod-observer --serviceaccount=security-104:auditor

k auth can-i list pods -n security-104 \
  --as=system:serviceaccount:security-104:auditor
k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:auditor # muss no sein
```

## 2. Projected token des ServiceAccount

Ein TokenRequest volume stellt einen kurzlebigen token aus; das gewöhnliche automount ist deaktiviert.
Wir legen `audience: kubernetes.default.svc` nicht fest: Für kubeadm ist das nicht unbedingt ein Wert, den der
API server akzeptiert. Wird `audience` weggelassen, verwendet das kubelet den Standard-identifier des
API server. Eine eigene audience darf erst nach der Prüfung von
`--api-audiences` (oder dem default aus `--service-account-issuer`) auf der control-plane angegeben werden.
`expirationSeconds` muss im Bereich `600`-`3600` einschließlich liegen - die Kubernetes API
lehnt jeden Wert unter `600` Sekunden für eine `serviceAccountToken`
projected source als invalid ab, unabhängig davon, was im Manifest steht.

Die genaue Syntax von `projected.sources[].serviceAccountToken` musst du in der Prüfung nicht aus dem Gedächtnis
abrufen - auf `kubernetes.io/docs` steht sie im Abschnitt Concepts → Storage →
[Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), unter der
Überschrift **„serviceAccountToken projected volumes“** (dort gibt es ein fertiges Beispiel eines Pods mit diesem
volume - übernimm die Struktur von dort und schreibe sie nicht von Grund auf). `kubectl run` kann
ein solches volume nicht über Flags hinzufügen - wir erzeugen das Pod-Skelett über `--dry-run=client -o yaml` und
ergänzen in `vim` nur die nötigen, aus dem Beispiel in der Dokumentation kopierten Felder:

```bash
k create sa api-client -n security-104
k run token-client -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > token-client.yaml
vim token-client.yaml
```

```yaml
# Ergänze in der spec des Pods (containers/image/command wurden bereits von kubectl run erzeugt):
spec:
  serviceAccountName: api-client              # hinzufügen
  automountServiceAccountToken: false         # hinzufügen
  containers:
  - name: token-client
    volumeMounts:                             # hinzufügen
    - name: api-token                         # hinzufügen
      mountPath: /var/run/secrets/tokens       # hinzufügen
      readOnly: true                          # hinzufügen
    ...
  volumes:                                    # hinzufügen
  - name: api-token                           # hinzufügen
    projected:                                # hinzufügen
      sources:                                # hinzufügen
      - serviceAccountToken:                  # hinzufügen
          path: api-token                     # hinzufügen
          expirationSeconds: 3600             # hinzufügen
```

```bash
k apply -f token-client.yaml
k wait -n security-104 --for=condition=Ready po/token-client --timeout=120s
k exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token
# die Datei existiert - wenn das Manifest dem Beispiel aus der Dokumentation entspricht, hat das kubelet sie ausgestellt

k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:api-client
# no
```

Wir prüfen nicht nur das Vorhandensein der Datei, sondern auch, dass sich der gemountete projected token
tatsächlich als der erwartete ServiceAccount authentifiziert, indem wir ihn an `TokenReview` senden:

```bash
TOKEN=$(k exec -n security-104 token-client -- cat /var/run/secrets/tokens/api-token)

k create -o jsonpath='{.status.authenticated}{" "}{.status.user.username}{"\n"}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: $TOKEN
EOF
# true system:serviceaccount:security-104:api-client
```

Für das Lab ist diese Prüfung Pflicht: Das Vorhandensein der Datei beweist allein nicht,
dass der projected token gültig ist und sich als der erwartete ServiceAccount authentifiziert. `TokenReview`
muss `authenticated: true` und den username
`system:serviceaccount:security-104:api-client` zurückgeben.

In der Prüfung muss `TokenReview` nicht separat ausgeführt werden, sofern es die Aufgabenstellung nicht verlangt:
Dort genügt es, schnell ein korrektes projected token volume zu erstellen und das Ergebnis auf die
Weise zu prüfen, die in der konkreten Aufgabe nötig ist. Hier ist `TokenReview` eine Lern-verification-Prüfung,
die zugleich dem Abnahmekriterium des Labs entspricht.

## 3. Pod ohne API-token

Wir deaktivieren das automount sowohl am ServiceAccount als auch am Pod: Das schützt vor späteren
Änderungen an der Vorlage oder am ServiceAccount.

`kubectl create serviceaccount` hat kein Flag für `automountServiceAccountToken` - wir erstellen
und patchen sofort:

```bash
k create sa no-token-sa -n security-104
k patch sa no-token-sa -n security-104 -p '{"automountServiceAccountToken":false}'
k run no-token -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > no-token.yaml
vim no-token.yaml
```

```yaml
# Ergänze in der spec des Pods:
spec:
  serviceAccountName: no-token-sa       # hinzufügen
  automountServiceAccountToken: false   # hinzufügen
  containers:
  - name: no-token
    ...
```

```bash
k apply -f no-token.yaml
k wait -n security-104 --for=condition=Ready po/no-token --timeout=60s
k get po no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'

# Wir bestätigen auf runtime-Ebene und nicht nur auf der Ebene der YAML-Spezifikation: Im
# Container gibt es tatsächlich keine token-Datei.
k exec -n security-104 no-token -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - die Datei existiert nicht, der exec selbst wurde erfolgreich ausgeführt
```

Mounte auch kein legacy `Secret` mit `type: kubernetes.io/service-account-token` separat -
selbst bei deaktiviertem automount kann ein solches Secret manuell über
`volumes[].secret` gemountet werden, und dann ist der Pod formal „ohne token“ nach dem automount-Feld, hat aber faktisch
trotzdem einen gültigen API-token im Container.

## 4. Entfernen der wildcard-Rechte

Wir löschen sowohl das binding (das Subjekt erhält keinen Zugriff mehr) als auch die ClusterRole selbst (die gefährliche
Vorlage bleibt nicht zur Wiederverwendung zurück):

```bash
k delete clusterrolebinding legacy-operator-admin
k delete clusterrole legacy-operator-admin
k auth can-i get secrets -n security-104 \
  --as=system:serviceaccount:security-104:legacy-operator # muss no sein
```

## 5. Deaktivieren von anonymous-auth

Ein einfaches `--anonymous-auth=false` ist hier nicht geeignet: kubeadm `release-1.36` erzeugt den
static Pod des kube-apiserver mit HTTPS liveness/readiness/startup probes auf `/livez` und
`/readyz`, und HTTP probes des kubelet übergeben keine client credentials - bei vollständiger Deaktivierung von
anonymous access erhalten diese Anfragen `401`, und das kubelet beginnt, den kube-apiserver für
ungesund zu halten (was wiederum auch Aufgabe 9 zum Scheitern bringt, die von einem stabil laufenden API
server abhängt). Stattdessen verwenden wir die `AuthenticationConfiguration` mit `anonymous.conditions`,
die anonymous access nur auf drei Health-Pfade beschränken. Setze in der Prüfung nicht vor
jeden Befehl `sudo` - werde einmal root (`sudo -i`), das ist schneller:

```bash
ssh control-plane
sudo -i
cat > /etc/kubernetes/authentication-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

Wir bearbeiten das static manifest: Wir entfernen `--anonymous-auth=true` vollständig (es darf nicht neben
`--authentication-config` stehen bleiben - kube-apiserver verweigert den Start, wenn beide gesetzt sind),
fügen `--authentication-config` hinzu sowie ein `hostPath` volume/volumeMount für die neue
Konfigurationsdatei - kube-apiserver liest `authentication-config.yaml` vom Dateisystem des Nodes,
daher muss die Datei im Container über ein volumeMount sichtbar sein und nicht
nur auf dem Host liegen:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Im command-Array:
# - entferne die Zeile "- --anonymous-auth=true"
# - füge eine Zeile mit derselben Einrückung wie die übrigen Argumente hinzu:
#   - --authentication-config=/etc/kubernetes/authentication-config.yaml
# In den volumeMounts des Containers (dieselbe Einrückung wie die benachbarten Elemente):
#   - mountPath: /etc/kubernetes/authentication-config.yaml
#     name: authentication-config
#     readOnly: true
# In den volumes des Pods (dieselbe Einrückung wie die benachbarten Elemente):
#   - hostPath:
#       path: /etc/kubernetes/authentication-config.yaml
#       type: File
#     name: authentication-config
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` erzwingt den sofortigen Neuaufbau des static Pods - in der Prüfung
schneller, als zu warten, bis das kubelet die Änderung der Datei selbst bemerkt (meist Sekunden, aber nicht
garantiert sofort):

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS muss Running werden - wenn noch nicht, warte ein paar Sekunden und wiederhole
```

Prüfe alle drei Verhaltensweisen: `/version` lehnt anonyme Anfragen ab, während `/livez`/`/readyz`
sie annehmen:

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401 - anonymous access ist geschlossen
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/livez"   # 200 - die health probe funktioniert
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/readyz"  # 200 - die health probe funktioniert
```

Eine authentifizierte Anfrage an `/readyz` (über den bereits eingerichteten kubectl context)
funktioniert genau gleich weiter - `AuthenticationConfiguration.anonymous.conditions`
ERWEITERT nur den Zugriff für anonyme Anfragen auf bestimmte Pfade, schränkt aber den Zugriff
für bereits authentifizierte Clients nicht ein:

```bash
k get --raw=/readyz # ok
```

Authentication ohne einschränkende Autorisierung ist sinnlos - prüfe, dass
`--authorization-mode` am static Pod weiterhin `Node,RBAC` ist und nicht `AlwaysAllow` enthält
(kubeadm setzt das standardmäßig, aber man sollte sicherstellen, dass nichts das Flag verändert hat):

```bash
k get po -n kube-system -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep authorization-mode
# --authorization-mode=Node,RBAC
```

Separat auditieren wir ClusterRoleBinding, deren subjects auf den anonymen Benutzer
oder die Gruppe verweisen - im Cluster wurde absichtlich eine solche lab-owned Bindung zurückgelassen:

```bash
k get clusterrolebinding -o json | jq -r \
  '.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name == "system:unauthenticated")] | length > 0) | .metadata.name'
# system:public-info-viewer
# lab104-unintended-anonymous-access
```

`system:public-info-viewer` ist eine reguläre kubeadm-Bindung: Sie zielt ebenfalls auf
`system:unauthenticated`, aber ihre ClusterRole erlaubt read-only `GET` nur auf
non-resource URLs `/livez`, `/readyz`, `/healthz`, `/version`, `/version/` und nicht auf gewöhnliche
Kubernetes-Ressourcen - das ist default Kubernetes RBAC, ein erforderlicher Teil des bootstrap, fasse
sie nicht an. Das ist nicht dasselbe wie `anonymous.conditions` aus derselben Aufgabe: Jene Liste
begrenzt, auf welchen Pfaden eine Anfrage in der Phase authentication überhaupt eine anonymous identity erhält
(dort nur `/livez`/`/readyz`/`/healthz`) - `/version` liefert anonym
`401` gerade deshalb, weil dort keine anonymous identity zugewiesen wird, und nicht deshalb, weil
`system:public-info-viewer` dort zu wenige Rechte hat. `lab104-unintended-anonymous-access`
ist der absichtliche lab-owned Befund: Seine ClusterRole `lab104-anonymous-debug-access` gibt
vollwertiges RBAC `get`/`list` auf `pods`/`secrets`/`configmaps` clusterweit, das heißt JEDE
anonyme Anfrage kann sie lesen. Wir löschen beide Objekte, wie in den Aufgaben 4/7:

```bash
k delete clusterrolebinding lab104-unintended-anonymous-access
k delete clusterrole lab104-anonymous-debug-access
```

Wir bestätigen den Widerruf mit einer negativen Kontrolle im Namen genau der nicht authentifizierten Identität
(`system:anonymous` + Gruppe `system:unauthenticated`, und sonst nichts) über
`SubjectAccessReview` - es wird vom admin-Kontext erstellt, daher muss die Gruppenliste nicht
künstlich erweitert werden:

```bash
for R in pods secrets configmaps; do
  for NS in $(k get ns -o jsonpath='{.items[*].metadata.name}'); do
    ALLOWED=$(k create -o jsonpath='{.status.allowed}' -f - <<EOF
apiVersion: authorization.k8s.io/v1
kind: SubjectAccessReview
spec:
  user: system:anonymous
  groups: ["system:unauthenticated"]
  resourceAttributes:
    namespace: $NS
    resource: $R
    verb: get
EOF
    )
    printf '%-12s %-24s %s\n' "$R" "$NS" "$ALLOWED"
  done
done
# für jede Zeile wird false erwartet
```

Füge `--as-group=system:authenticated` nicht zu `can-i --as=system:anonymous` hinzu: Eine echte
nicht authentifizierte Anfrage gehört dieser Gruppe nicht an, und die Prüfung würde nicht mehr die
echte anonymous identity widerspiegeln. Wir prüfen jeden Namespace separat, weil
ein RoleBinding nur in seinem Namespace wirkt: Das Fehlen einer cluster-wide Bindung
beweist nicht das Fehlen einer lokalen, und das Abnahmekriterium verbietet den Zugriff in jedem Namespace.

Führe am Ende `check_result` aus.

## 6. Leck eines Secrets über env in `/proc/1/environ`: Umstellung auf volume

`app-vulnerable` erhält `db-creds` über `envFrom`, daher landet der Wert im
environment des Prozesses PID 1 des Containers. Jeder, der das Recht auf `kubectl exec` in diesen
Pod hat, kann das Secret direkt aus `/proc` lesen, ohne Zugriff auf die Kubernetes API und ohne RBAC
auf `get secrets`:

```bash
mkdir -p /var/work/tests/artifacts/6
k exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | grep DB_PASSWORD | tee /var/work/tests/artifacts/6/env-leak-before.txt
```

Wir speichern genau die Zeile `DB_PASSWORD=<echter Wert>` aus dem Prozess-environment und nicht
einfach das Wort `DB_PASSWORD` ohne Wert - der Checker gleicht sie selbst mit dem tatsächlichen Wert
aus dem Secret `db-creds` ab, der Wert muss nicht separat berechnet und verglichen werden.

Wir erstellen den Pod mit demselben Namen neu: Wir entfernen `envFrom`, mounten dasselbe Secret als volume
`db-creds-vol` nach `/etc/secrets`, read-only, mit `defaultMode: 0400` (`256` in decimal, wie es
`kubectl get pod -o json` anzeigt). `0400` bedeutet read-only nur für den Eigentümer der Datei
im Container; der Prozess der Anwendung selbst muss trotzdem unter dieser UID laufen, sonst
kann er die Datei nicht lesen.

Die meisten Felder eines Pods (einschließlich `volumes`) sind unveränderlich, deshalb muss der Pod gelöscht und mit demselben Namen neu erstellt werden. Wieder ist es günstiger,
ein Skelett über `--dry-run` zu erzeugen und das volume in `vim` zu ergänzen, als das gesamte YAML zu schreiben:

```bash
k run app-vulnerable -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > app-vulnerable-fixed.yaml
vim app-vulnerable-fixed.yaml
```

```yaml
# Ergänze in der spec des Pods:
spec:
  automountServiceAccountToken: false     # hinzufügen
  containers:
  - name: app-vulnerable
    volumeMounts:                         # hinzufügen
    - name: db-creds-vol                  # hinzufügen
      mountPath: /etc/secrets             # hinzufügen
      readOnly: true                      # hinzufügen
    ...
  volumes:                                # hinzufügen
  - name: db-creds-vol                    # hinzufügen
    secret:                               # hinzufügen
      secretName: db-creds                # hinzufügen
      defaultMode: 0400                   # hinzufügen
```

```bash
k delete pod app-vulnerable -n security-104
k apply -f app-vulnerable-fixed.yaml
k wait -n security-104 --for=condition=Ready po/app-vulnerable --timeout=120s
```

Wir bestätigen drei finale Eigenschaften und nicht nur „das Secret ist nicht im environment“: Die Dateirechte
sind genau `400` (und enthalten nicht bloß irgendwo den Substring `400`), und, was wichtiger ist, die Anwendung
kann den Wert des Secrets weiterhin TATSÄCHLICH lesen - sonst könnte das hardening unbemerkt die
Funktionalität der Anwendung selbst beeinträchtigen:

```bash
k exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# nichts gefunden - das ist erwartet

k exec -n security-104 app-vulnerable -- stat -L -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400 - genau dieser Wert und kein beliebiger Text, der irgendwo „400“ enthält. Das Flag -L
# ist Pflicht: Das Secret-volume wird über eine Kette von Symlinks gemountet („..data“), und ohne -L
# zeigt stat den Modus des Symlinks selbst (unter Linux immer 777) und nicht der echten Datei.

# Positive control: Der Prozess der Anwendung muss den Wert des Secrets tatsächlich lesen können.
k exec -n security-104 app-vulnerable -- cat /etc/secrets/DB_PASSWORD
# muss mit dem Wert übereinstimmen, der vor dem Fix in env-leak-before.txt stand
```

`defaultMode: 0400` schützt vor dem Lesen durch andere UIDs im selben Pod (zum Beispiel einen benachbarten
Sidecar-Container ohne die nötige UID), ersetzt aber nicht die encryption at rest von etcd und hindert
einen unter der erwarteten UID laufenden Prozess nicht daran, die Datei selbst zu lesen - der mount erlaubt genau das.
Vergewissere dich auch, dass `db-creds` nicht gleichzeitig auf einem ZWEITEN Weg gemountet ist
(zum Beispiel zusätzlich über ein `projected` volume) - es muss genau ein volume übrig bleiben,
das dieses Secret mountet.

Führe am Ende `check_result` aus.

## 7. Audit und Widerruf versteckter RBAC-Pfade der privilege escalation

`build-agent-hidden-privesc` enthält kein wildcard `*`, aber `impersonate`/`bind`/`escalate`/
CSR-approval sind eine eigene Kategorie gefährlicher verbs: Sie erweitern die Liste der sichtbaren
Ressourcen nicht, sondern geben die Möglichkeit, **im Namen eines anderen zu handeln** oder **sich selbst
zusätzliche Rechte zu geben**. In dieser Version der fixture enthält die ClusterRole auch die Basis-`create`/`update` auf `clusterroles`/`clusterrolebindings` - ohne sie wären `bind`/`escalate`
unvollständige escalation primitives (RBAC verlangt ENTWEDER, die Rechte aus der Rolle bereits zu haben, ODER
`escalate`/`bind` explizit zu besitzen BEIM Versuch, eine Role/ein Binding tatsächlich zu erstellen/zu aktualisieren).
Wir finden alle ClusterRoleBinding, deren ClusterRole eines der gefährlichen verbs erlaubt. Wir gehen nicht
von den ClusterRole aus (davon gibt es im Cluster Dutzende, einschließlich der regulären `system:*`), sondern vom
ClusterRoleBinding - `kubectl get clusterrolebinding` zeigt standardmäßig bereits die Spalte
`ROLE` (Format `ClusterRole/<Name>`), und `-o wide` ergänzt noch `USERS`/`GROUPS`/
`SERVICEACCOUNTS` - weder custom-columns noch YAML sind nötig:

```bash
mkdir -p /var/work/tests/artifacts/7
k get clusterrolebinding -o wide | grep -v system:
# build-agent-hidden-privesc   ClusterRole/build-agent-hidden-privesc   ...   security-104/build-agent
```

Für jeden Kandidaten sehen wir uns seine ClusterRole menschenlesbar an, ohne `jq`/`grep` auf YAML -
`kubectl describe` gibt die verbs selbst als Tabelle aus, dort sieht man sofort `impersonate`/`bind`/
`escalate` und die separate Regel auf `certificatesigningrequests/approval`:

```bash
k describe clusterrole build-agent-hidden-privesc
# Die Verbs in der PolicyRule-Tabelle zeigen impersonate / bind / escalate / update
# (auf certificatesigningrequests/approval) - mit bloßem Auge sieht man, dass die Rolle gefährlich ist
```

Wir speichern den Namen des ClusterRoleBinding (nicht der ClusterRole - sie müssen nicht übereinstimmen, in diesem Lab
stimmen sie zufällig überein) im artifact:

```bash
echo build-agent-hidden-privesc > /var/work/tests/artifacts/7/dangerous-bindings-before.txt
cat /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` muss in der finalen Datei stehen (als Name des ClusterRoleBinding,
nicht der ClusterRole). Wir löschen genau dieses ClusterRoleBinding (und die ClusterRole, damit die Vorlage nicht
zur Wiederverwendung zurückbleibt) und fassen die `system:*` bindings nicht an, die den
core-Komponenten von Kubernetes den notwendigen `impersonate`/CSR-Zugriff geben:

```bash
k delete clusterrolebinding build-agent-hidden-privesc
k delete clusterrole build-agent-hidden-privesc
```

Wir bestätigen den Widerruf ALLER genannten gefährlichen Rechte und nicht nur eines Teils davon. Zwei Nuancen:
Die fixture gibt `impersonate` gleich auf drei Ressourcentypen (`users`/`groups`/`serviceaccounts`) -
die Prüfung nur von `users` beweist den Widerruf der anderen beiden nicht; und `TYPE/NAME` in `kubectl auth
can-i` ist ein resourceName und keine subresource (`kubectl auth can-i --help` zeigt direkt
das Beispiel „jobs.batch/bar“ - Prüfung eines Objekts, das buchstäblich `bar` heißt), daher braucht es für
`certificatesigningrequests/approval` ein separates Flag `--subresource=approval` und keinen
Schrägstrich:

```bash
k auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate groups --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate serviceaccounts -n security-104 --as=system:serviceaccount:security-104:build-agent
k auth can-i bind clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i update certificatesigningrequests --subresource=approval --as=system:serviceaccount:security-104:build-agent
k auth can-i approve signers/kubernetes.io/kube-apiserver-client --as=system:serviceaccount:security-104:build-agent
# no / no / no / no / no / no / no
```

Führe am Ende `check_result` aus.

## 8. Namespace-level baseline: `default` SA ohne automount

Aufgabe 3 hat automount punktuell deaktiviert, bei einem konkreten Pod und seinem eigenen SA. Hier
brauchst du eine systemische Baseline: Wir ändern den `default` SA des Namespace, **bevor** darin irgendwelche
Pods erstellt werden, damit kein neuer workload standardmäßig einen token erhält, selbst wenn der Entwickler
das explizite Feld im Manifest vergisst.

Der ServiceAccount `default` wird von einem separaten Controller asynchron nach dem Erscheinen des
Namespace erstellt - `kubectl wait` kann ausdrücklich auf das Erscheinen des Objekts warten (`--for=create`), nicht nur auf
seine condition, daher braucht es weder manuelles retry noch eine selbstgebaute Schleife:

```bash
k create namespace security-104-baseline
k wait -n security-104-baseline --for=create sa/default --timeout=30s

k -n security-104-baseline patch sa default \
  -p '{"automountServiceAccountToken":false}'
k -n security-104-baseline get sa default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

Wir erstellen einen Pod, der **weder** `serviceAccountName` **noch** `automountServiceAccountToken` angibt -
das ist der in der Realität häufigste Fall, wenn der Entwickler einfach nicht an den SA denkt. Das Feld
`automountServiceAccountToken` muss in der spec des Pods FEHLEN - die explizite Angabe von `false`
würde nur die punktuelle Einstellung des Pods selbst beweisen (wie in Aufgabe 3) und nicht, dass
die namespace-level Baseline tatsächlich funktioniert.

Hier braucht es nicht einmal `--dry-run` - da dem Pod kein einziges Feld zu SA/automount hinzugefügt wird,
erstellt `kubectl run` ohne Flags genau das Benötigte direkt:

```bash
k run implicit-default-sa -n security-104-baseline --image=busybox:1.36 --command -- sh -c "sleep 3600"
k wait -n security-104-baseline --for=condition=Ready po/implicit-default-sa --timeout=60s
k get po implicit-default-sa -n security-104-baseline -o jsonpath='{.spec.serviceAccountName}{"\n"}'
# default

k get po implicit-default-sa -n security-104-baseline \
  -o jsonpath='{.spec.automountServiceAccountToken}{"\n"}'
# leere Ausgabe - das Feld fehlt in der spec und ist nicht auf false gesetzt

k exec -n security-104-baseline implicit-default-sa -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - die Datei existiert nicht, und der exec selbst wurde erfolgreich ausgeführt (anders als bei einem banalen
# „cat“ auf eine nicht existierende Datei, dessen exit code von cat ebenfalls ungleich null ist, aber aus einem anderen
# Grund - test ! -e führt genau die benötigte Prüfung aus, und ihr eigener Erfolg
# muss separat verlangt werden und nicht einfach „jeder Fehler = Datei existiert nicht“)
```

Der Wert des SA gilt nur, wenn der Pod ihn nicht selbst überschreibt. Wenn derselbe Namespace
einen Pod mit API-Zugriff braucht, füge `automountServiceAccountToken: true` explizit im
konkreten Manifest hinzu, nachdem du geprüft hast, dass der Zugriff tatsächlich nötig ist - ändere die Baseline des
`default` SA nicht für den ganzen Namespace zurück auf `true`. Mounte außerdem kein altes
(legacy) `Secret` mit `type: kubernetes.io/service-account-token` manuell über `volumes[].secret` -
das würde dem Pod unabhängig von den automount-Einstellungen einen gültigen API-token geben.

Führe am Ende `check_result` aus.

## 9. Integrationsaufgabe: Erkennung einer gefährlichen RBAC-Änderung → audit log → containment

Die Aufgaben 1-8 haben konkrete Pfade der privilege escalation geschlossen, die `build-agent` selbst zugänglich waren
(wildcard, impersonate/bind/escalate, automount). Hier geht es um eine andere Schutzschicht -
die Erkennung eines **gefährlichen RBAC grant, der von einem Administrator vergeben wurde** (versehentlich, durch
kompromittierte Automatisierung oder böswillig) und nicht nur um den aktuellen Snapshot von RBAC.
Wir verbinden uns mit der control-plane und bereiten ein minimales audit backend vor:

```bash
ssh control-plane
sudo -i
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings"]
- level: Metadata
EOF
```

Die RBAC-Regel steht an erster Stelle - die spezifischere Regel muss dem allgemeinen
catch-all vorausgehen, sonst fängt `Metadata` das Ereignis früher ab. `omitStages: [RequestReceived]`
auf Ebene der gesamten policy entfernt den überflüssigen Eintrag vor der Verarbeitung der Anfrage - er hat kein
`requestObject`/`responseStatus`, und der Checker verwirft solche Einträge ohnehin (`stage ==
"ResponseComplete"`), und mit der catch-all `Metadata`-Regel auf ALLE übrigen Anfragen des Clusters
würde diese Stage das Volumen von audit.log ohne Nutzen verdoppeln.

Wir bearbeiten das static manifest: Wir fügen `--audit-policy-file`/`--audit-log-path` und hostPath
volume/volumeMount für die Verzeichnisse von policy und logs hinzu - mit demselben Kniff wie in Aufgabe 5 für
`authentication-config.yaml`:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/9-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Füge in das command-Array Zeilen mit derselben Einrückung wie die übrigen Argumente ein:
#   - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
#   - --audit-log-path=/var/log/kubernetes/audit/audit.log
# In den volumeMounts des Containers (dieselbe Einrückung wie die benachbarten Elemente):
#   - mountPath: /etc/kubernetes/audit
#     name: audit-policy
#     readOnly: true
#   - mountPath: /var/log/kubernetes/audit
#     name: audit-log
# In den volumes des Pods (dieselbe Einrückung wie die benachbarten Elemente):
#   - hostPath:
#       path: /etc/kubernetes/audit
#       type: Directory
#     name: audit-policy
#   - hostPath:
#       path: /var/log/kubernetes/audit
#       type: DirectoryOrCreate
#     name: audit-log
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` erzwingt den sofortigen Neuaufbau des static Pods - ebenso wie in
Aufgabe 5 ist es schneller, als zu warten, bis das kubelet die Änderung der Datei selbst bemerkt:

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS muss Running werden - wenn noch nicht, warte ein paar Sekunden und wiederhole
```

Wir kehren zur Arbeitsmaschine zurück (im Namen des Administrators `cluster1-admin`) und erstellen
die gefährliche Bindung - das ist **kein** Eskalationsversuch von `build-agent` (er hat nach Aufgabe 7
keine echten Pfade dorthin mehr), sondern eine modellierte Administratoraktion,
die der audit log als reproduzierbare evidence darüber erfassen muss, wer genau dies
getan hat und wem genau die Rechte vergeben wurden:

```bash
k create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

Zuerst vergewissern wir uns einfach mit eigenen Augen, dass die audit-Regel tatsächlich funktioniert und das Ereignis im
log gelandet ist - in der CKS-Prüfung genügt gewöhnlich genau diese Kontrolle und kein fertiges artifact:

```bash
ssh control-plane
sudo cat /var/log/kubernetes/audit/audit.log | jq . | grep -A 30 incident-simulated-escalation
exit
```

`jq .` gibt jeden Eintrag des logs menschenlesbar aus (ein Feld pro Zeile), `grep -A 30`
zeigt die gefundene Zeile mit dem Namen und 30 Zeilen DANACH - das genügt, um `stage`, `user.username`
(der reale Auslöser), `requestObject.roleRef`, `requestObject.subjects` mit bloßem Auge zu sehen,
ohne spezielle jq-Syntax.

Für die echte Prüfung genügt das, aber dieses Lab verlangt zusätzlich eine artifact-Datei mit dem
Ereignis - nicht, weil es dem Checker nicht reichen würde zu wissen, dass die Regel funktioniert (er liest `audit.log` auf der
control-plane selbst, unabhängig, über SSH), sondern um eine separate Fähigkeit zu prüfen:
genau den ECHTEN Eintrag als forensic evidence zu extrahieren und zu speichern und ihn nicht mit
eigenen Worten nachzuerzählen (der Checker gleicht die `auditID` deiner Datei mit der `auditID` des echten Eintrags im log ab).
`/var/work/tests/artifacts/9/` ist ein Pfad auf der ARBEITSMASCHINE und nicht auf der control-plane, daher
speichern wir von der Arbeitsmaschine aus über `ssh control-plane "..."`, mit derselben Kombination von grep auf gewöhnliche
Teilstrings (Name des Ereignisses + `ResponseComplete`, um nicht auf den Zwischeneintrag
`ResponseStarted` derselben Anfrage zu geraten):

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | grep incident-simulated-escalation | grep ResponseComplete \
  | tail -n1 > /var/work/tests/artifacts/9/audit-escalation-event.json
```

Wir speichern das Ereignis **vollständig**, so wie es tatsächlich im audit log liegt (einschließlich `auditID`) - wir
schreiben es nicht um und bauen das JSON nicht von Hand zusammen, sonst stimmt das artifact bei der Verifikation nicht mit dem echten
Eintrag im log überein.

Containment: Wir löschen die Bindung und bestätigen, dass der Zugriff tatsächlich widerrufen ist und nicht nur
das Objekt nicht mehr lesbar ist. `can-i` ohne `-n`/`-A` prüft nur den aktuellen Namespace des
kubeconfig-Kontexts und nicht den gesamten Cluster - für ein namespaced RoleBinding in `security-104`
(anders als beim bereits gelöschten cluster-wide ClusterRoleBinding) ändert das das Ergebnis,
daher geben wir den Namespace explizit an:

```bash
k delete clusterrolebinding incident-simulated-escalation
k auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent \
  | tee /var/work/tests/artifacts/9/containment-result.txt
# no
```

Unterschied zu Aufgabe 7: Dort haben wir einen **bereits vorhandenen** versteckten Pfad durch
statische Analyse der RBAC-Objekte gefunden und widerrufen, der dem workload selbst (`build-agent`) gehörte. Hier
ist die source of truth ein **Ereignis in der Zeit** (audit log), das beweist, wer genau
(das Feld `user.username` - der reale Auslöser der Anfrage, hier der Administrator und nicht
`build-agent`) die gefährlichen Rechte vergeben hat und wem genau - das ist es, was bei einem realen
Vorfall gebraucht wird, wenn das Objekt selbst nach der Verwendung bereits gelöscht sein könnte, während `build-agent` im
Ereignis nur als Empfänger der Rechte und nicht als Urheber der Anfrage erscheint.

Führe am Ende `check_result` aus.

## 10. Ein Secret dekodieren, erstellen und mounten

`legacy-config` existiert bereits. Wir lesen beide Werte über die API aus und raten nicht:

```bash
mkdir -p /var/work/tests/artifacts/10
SERVICE_USER=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_USER}' | base64 -d)
SERVICE_TOKEN=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_TOKEN}' | base64 -d)
printf 'SERVICE_USER=%s\nSERVICE_TOKEN=%s\n' "$SERVICE_USER" "$SERVICE_TOKEN" \
  | tee /var/work/tests/artifacts/10/decoded-values.txt
```

Wir erstellen ein neues generic Secret mit denselben Schlüsselnamen und denselben Werten -
`--from-literal` kodiert den Wert selbst in base64, das musst du nicht von Hand tun:

```bash
k create secret generic rehydrated-config -n security-104 \
  --from-literal=SERVICE_USER="$SERVICE_USER" \
  --from-literal=SERVICE_TOKEN="$SERVICE_TOKEN"
```

Wir mounten es als read-only volume in den Pod - wieder dry-run + punktuelle Änderung in `vim`:

```bash
k run secret-workflow -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > secret-workflow.yaml
vim secret-workflow.yaml
```

```yaml
# Ergänze in der spec des Pods:
spec:
  automountServiceAccountToken: false      # hinzufügen
  containers:
  - name: secret-workflow
    volumeMounts:                          # hinzufügen
    - name: rehydrated-config-vol          # hinzufügen
      mountPath: /etc/rehydrated           # hinzufügen
      readOnly: true                       # hinzufügen
    ...
  volumes:                                 # hinzufügen
  - name: rehydrated-config-vol            # hinzufügen
    secret:                                # hinzufügen
      secretName: rehydrated-config        # hinzufügen
```

```bash
k apply -f secret-workflow.yaml
k wait -n security-104 --for=condition=Ready po/secret-workflow --timeout=60s
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_USER
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_TOKEN
# müssen mit $SERVICE_USER / $SERVICE_TOKEN oben übereinstimmen
```

Führe am Ende `check_result` aus.

## 11. Eine bestehende Role reparieren und an einen SA aus einem anderen Namespace binden

Die vorhandene Role `pod-role` in `rbac-a` erlaubt `get`, `list`, `delete` - wir entfernen
das überflüssige `delete` und fügen das benötigte `watch` hinzu:

```bash
k patch role pod-role -n rbac-a --type=json -p \
  '[{"op":"replace","path":"/rules/0/verbs","value":["get","list","watch"]}]'
k auth can-i delete pods -n rbac-a --as=system:serviceaccount:rbac-a:dev # no
k auth can-i watch pods -n rbac-a --as=system:serviceaccount:rbac-a:dev  # yes
```

`shared-config` existiert bereits in `rbac-b`. Wir erstellen eine NEUE Role+RoleBinding genau in
`rbac-b` - ein RoleBinding unterstützt ein subject aus einem anderen Namespace, aber die Rechte selbst
gelten nur im Namespace des RoleBinding selbst:

```bash
k create role configmap-reader -n rbac-b --resource=configmaps --verb=get,list
k create rolebinding configmap-reader-binding -n rbac-b \
  --role=configmap-reader --serviceaccount=rbac-a:dev

k auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev    # yes
k auth can-i delete configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev # no
k auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev       # no
```

Wir erstellen in `rbac-a` einen Pod, der tatsächlich `dev` verwendet:

```bash
k run rbac-a-workload -n rbac-a --image=busybox:1.36 \
  --overrides='{"spec":{"serviceAccountName":"dev"}}' -- sh -c "sleep 3600"
```

Führe am Ende `check_result` aus.

## 12. Benutzer mit Client-Zertifikat über CSR + namespaced RBAC

Wir erzeugen einen private key und eine CSR mit `CN=john` - RBAC für einen zertifikatsbasierten Benutzer
wird über `kind: User` gebunden und nicht über `ServiceAccount`, und ein `User` hat kein eigenes API-Objekt: Seine identity wird vollständig dadurch bestimmt, dass der CN im Client-Zertifikat
mit dem `name` im binding übereinstimmt.

```bash
mkdir -p /var/work/tests/artifacts/12
openssl genrsa -out /var/work/tests/artifacts/12/john.key 2048
openssl req -new -key /var/work/tests/artifacts/12/john.key \
  -out /tmp/john.csr -subj "/CN=john"
```

Wir reichen sie als Kubernetes `CertificateSigningRequest` mit demselben signer ein, der bereits
in Aufgabe 7 für die Genehmigung von CSR verwendet wird (`kubernetes.io/kube-apiserver-client` -
der korrekte signer speziell für ein client-auth Zertifikat, das Anfragen an den API server
authentifizieren wird):

```bash
cat > john-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: $(base64 -w0 /tmp/john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF
k apply -f john-csr.yaml
k certificate approve john-csr
k get csr john-csr -o jsonpath='{.status.certificate}' \
  | base64 -d > /var/work/tests/artifacts/12/john.crt
```

Wir prüfen, dass das Zertifikat tatsächlich von diesem Cluster signiert wurde und nicht nur, dass das Feld
`status.certificate` nicht leer ist:

```bash
openssl verify -CAfile <(ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt) \
  /var/work/tests/artifacts/12/john.crt
# /var/work/tests/artifacts/12/john.crt: OK
openssl x509 -in /var/work/tests/artifacts/12/john.crt -noout -subject
# subject=CN = john
```

RBAC: Role in `development`, RoleBinding auf `kind: User, name: john` - `--user=john` in
`kubectl create rolebinding` setzt `kind: User` selbst, es muss kein YAML geschrieben werden:

```bash
k create role john-pod-access -n development --resource=pods --verb=create,list,get
k create rolebinding john-pod-access-binding -n development \
  --role=john-pod-access --user=john

k auth can-i create pods -n development --as=john  # yes
k auth can-i list pods -n development --as=john    # yes
k auth can-i get pods -n development --as=john     # yes
k auth can-i delete pods -n development --as=john  # no
k auth can-i create pods -n security-104 --as=john # no
```

`--as=john` beweist nur die RBAC-Logik (impersonation, jedem admin zugänglich,
unabhängig davon, ob ein echtes Zertifikat ausgestellt wurde). Separat beweisen wir, dass genau das
AUSGESTELLTE Zertifikat vom API server über eine echte TLS client-auth
Anfrage akzeptiert wird:

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt > /tmp/cluster-ca.crt
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/development/pods"     # 200
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/security-104/pods"     # 403
```

Derselbe Beweis, aber über das gewohnte `kubectl` und nicht über `curl` - wir bauen für John eine separate
kubeconfig aus dem bereits ausgestellten Zertifikat (`set-credentials` mit `--client-certificate`/
`--client-key` und nicht `--token`, weil die identity hier ein client-cert ist und kein
ServiceAccount token):

```bash
k config set-cluster cluster1 --server="$SERVER" \
  --certificate-authority=/tmp/cluster-ca.crt --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-credentials john \
  --client-certificate=/var/work/tests/artifacts/12/john.crt \
  --client-key=/var/work/tests/artifacts/12/john.key --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-context john@cluster1 --cluster=cluster1 --user=john \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config use-context john@cluster1 \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development
# funktioniert - RBAC lässt durch

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n security-104
# Error from server (Forbidden) - dasselbe 403 wie in der curl-Prüfung oben

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig auth whoami
# Username: john - bestätigt, dass sich die kubeconfig tatsächlich als
# john authentifiziert und nicht nur zufällig die benötigten Antwortcodes liefert
```

Führe am Ende `check_result` aus.
