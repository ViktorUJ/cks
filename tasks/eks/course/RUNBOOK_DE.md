[Русская версия](RUNBOOK_RU.md) · [Eng version](RUNBOOK.md) · [Versión en español](RUNBOOK_ES.md) · [Version française](RUNBOOK_FR.md) · [ქართული ვერსია](RUNBOOK_GE.md) · [繁體中文版](RUNBOOK_TW.md) · [日本語版](RUNBOOK_JP.md)

# EKS-Diagnoseleitfaden: Symptom, Ursache, Prüfung

[Kursübersicht](README_DE.md) · [Glossar](GLOSSARY_DE.md)

## So verwenden Sie diesen Leitfaden

Dies ist eine Zusammenfassung der Abschnitte „Diagnoseablauf und Werkzeuge“ aus den Kapiteln 45,
46 und 47, zusammengeführt in einer Datei für den Bereitschaftsdienst: Während eines Incidents ist
es unpraktisch, durch drei Kapitel zu blättern. Gehen Sie so vor: Bestimmen Sie zuerst anhand der
Tabelle „Schnelleinstieg nach Symptom“ die KLASSE des Symptoms, gehen Sie dann zu Ihrer Schicht
und arbeiten Sie sie von oben nach unten ab. Die Klassifizierung ist wichtiger als das Werkzeug:
Ein Pod in `ContainerCreating` und ein 503 vom Load Balancer werden mit unterschiedlichen Befehlen
behandelt. Hier stehen nur Ablauf, Checklisten und Befehle. Ursachenanalyse, Mechanik und
Erklärungen bleiben in den Kapiteln 45-47; jede Zeile des Navigators verweist darauf.

## Schnelleinstieg nach Symptom

| Sichtbares Symptom | Klasse | Wohin gehen |
|---|---|---|
| `kubectl get nodes` ist leer, keine Nodes vorhanden | Node ist nicht beigetreten | [Node](#node-ist-dem-cluster-nicht-beigetreten), [Kapitel 45](45/de.md) |
| `NodeCreationFailure`, `Instances failed to join the kubernetes cluster` | Node ist nicht beigetreten | [Node](#node-ist-dem-cluster-nicht-beigetreten), [Kapitel 45](45/de.md) |
| Node Group in `CREATE_FAILED` oder `DEGRADED` | Node ist nicht beigetreten | [Node](#node-ist-dem-cluster-nicht-beigetreten), [Kapitel 45](45/de.md) |
| Im kubelet-Log `node "" not found` | Node: DNS und privater DNS-Name | [Node](#node-ist-dem-cluster-nicht-beigetreten), [Kapitel 45](45/de.md) |
| Node sichtbar, aber `NotReady` | CNI nicht bereit, andere Schicht | [Node](#node-ist-dem-cluster-nicht-beigetreten), [Kapitel 45](45/de.md), Kapitel 8 |
| Pod in `ContainerCreating`, `failed to assign an IP address to container` | Netzwerk: IP und ENI | [Netzwerk](#netzwerkfehler-in-einem-laufenden-cluster), [Kapitel 46](46/de.md) |
| Pod-zu-Pod oder Pod-zu-RDS `connection timed out`, DNS löst auf | Netzwerk: Security Group | [Netzwerk](#netzwerkfehler-in-einem-laufenden-cluster), [Kapitel 46](46/de.md) |
| Anfrage geht ab, aber die Verbindung hängt | Netzwerk: NACL und ephemeral ports | [Netzwerk](#netzwerkfehler-in-einem-laufenden-cluster), [Kapitel 46](46/de.md) |
| Pod löst keine Namen auf und besteht Readiness nicht | Netzwerk: eigene SG am Pod | [Netzwerk](#netzwerkfehler-in-einem-laufenden-cluster), [Kapitel 46](46/de.md) |
| DNS funktioniert nur gelegentlich, wechselnde Timeouts | Netzwerk: DNS | [Netzwerk](#netzwerkfehler-in-einem-laufenden-cluster), [Kapitel 46](46/de.md) |
| Zusätzliche DNS-Last für externe Namen | Netzwerk: Effekt von `ndots:5` | [Netzwerk](#netzwerkfehler-in-einem-laufenden-cluster), [Kapitel 46](46/de.md) |
| Targets in der Target Group `unhealthy`, 502 `Bad gateway` | Netzwerk: Load Balancer | [Netzwerk](#netzwerkfehler-in-einem-laufenden-cluster), [Kapitel 46](46/de.md) |
| 503 `Service unavailable` von einem Service hinter einem LB | Netzwerk: keine gesunden Targets | [Netzwerk](#netzwerkfehler-in-einem-laufenden-cluster), [Kapitel 46](46/de.md) |
| `You must be logged in to the server (Unauthorized)` | Zugriff: Authentifizierung | [Zugriff](#zugriffsverweigerung-mensch-und-pod), [Kapitel 47](47/de.md) |
| `couldn't get current server API group list: Unauthorized` | Zugriff: kubeconfig oder Region | [Zugriff](#zugriffsverweigerung-mensch-und-pod), [Kapitel 47](47/de.md) |
| `Forbidden: cannot <verb> resource` | Zugriff: RBAC | [Zugriff](#zugriffsverweigerung-mensch-und-pod), [Kapitel 47](47/de.md) |
| Pod beendet sich mit `AccessDenied` bei einem AWS-Aufruf | Pod-Zugriff: STS und Rolle | [Zugriff](#zugriffsverweigerung-mensch-und-pod), [Kapitel 47](47/de.md) |
| Pod beendet sich mit `WebIdentityErr: failed to retrieve credentials` | Pod-Zugriff: IRSA | [Zugriff](#zugriffsverweigerung-mensch-und-pod), [Kapitel 47](47/de.md) |

## Node ist dem Cluster nicht beigetreten

Kapitel 45. Das Symptom ist eines: leeres `kubectl get nodes` und `NodeCreationFailure`; die
Ursachen liegen jedoch auf unterschiedlichen Schichten. Arbeiten Sie von oben nach unten:

1. IAM-Schicht: Rechte der Node Instance Role und Autorisierung der Rolle im Cluster (Abschnitt 45.2).
2. Netzwerkschicht: Pfad zum API-Server-Endpoint auf 443, Endpoint-Typ, DNS (Abschnitt 45.3).
3. User-Data- und Bootstrap-Schicht: `bootstrap.sh` auf AL2, `nodeadm`/`NodeConfig` auf AL2023 (45.4).
4. Kubelet-Schicht: Der Daemon läuft, kubeconfig und Zertifikat sind intakt, die Registrierung war erfolgreich (45.5).

Die Logik: Fragen Sie zuerst EKS mit `describe-nodegroup`, prüfen Sie dann die Autorisierung der
Rolle (kostengünstig und meist die Ursache), anschließend das Netzwerk zum Endpoint und gehen Sie
erst danach für cloud-init- und kubelet-Logs auf die Node. Unterscheiden Sie „keine Nodes“ von
`NotReady`: Letzteres bei einem lebenden kubelet ist fast immer CNI, siehe Kapitel 8.

| Symptom | Wahrscheinliche Ursache | Prüfen |
|---|---|---|
| `NodeCreationFailure`, keine Nodes | Node-Rolle nicht autorisiert | `aws eks list-access-entries`, `aws-auth` |
| keine Nodes, IAM in Ordnung | kein Pfad zur API auf 443 | SG, NAT/IGW-Route, Endpoint-Typ |
| keine Nodes, privater Cluster | Endpoint wird nicht aufgelöst | DNS, DHCP Options Set in der VPC |
| keine Nodes, benutzerdefiniertes AMI | Bootstrap nicht ausgeführt | `/var/log/cloud-init-output.log` |
| keine Nodes, kubelet beendet sich | beschädigte kubeconfig/Zertifikat | `journalctl -u kubelet` |
| Node vorhanden, aber `NotReady` | CNI nicht bereit, keine IPs für Pods | Pod `aws-node`, Node-Ereignisse (Kapitel 8) |
| Im Log `node "" not found` | kein privater DNS-Name | DHCP Options, DNS in der VPC |

```bash
# 1. Was EKS selbst über die Node Group sagt
aws eks describe-nodegroup --cluster-name prod --nodegroup-name ng-1 \
  --query 'nodegroup.health.issues'
# 2. Ob der Cluster Nodes sieht
kubectl get nodes
# 3. Ob die Node-Rolle autorisiert ist
aws eks list-access-entries --cluster-name prod
# Veralteter Weg: Mappings in aws-auth
kubectl -n kube-system get configmap aws-auth -o yaml
# 4. Auf der Node über SSM Session Manager: Bootstrap-/cloud-init-Log
sudo cat /var/log/cloud-init-output.log
# 5. Auf der Node: Status und Logs von kubelet
systemctl status kubelet
journalctl -u kubelet -n 200 --no-pager
```

Zugriff auf die Node ohne SSH erfolgt über SSM Session Manager: SSM Agent und Berechtigungen sind
erforderlich. Ist SSM nicht verfügbar, bleiben die Konsolenausgabe der Instanz (System Log) und
`/var/log`.

## Netzwerkfehler in einem laufenden Cluster

Kapitel 46. Der Cluster läuft, die Nodes sind `Ready`, doch das Netzwerk kann auf unterschiedliche
Weise ausfallen. Klassifizieren Sie zuerst das Symptom: keine IP, Verbindungsabbruch, DNS, 5xx vom
Load Balancer. Die Klasse bestimmt Schicht und Befehl. `describe pod` und `get pods -o wide` sind
kostengünstig und schließen IP-Probleme als Erstes aus, `describe-target-health` lokalisiert einen
Load-Balancer-Fehler sofort, VPC Flow Logs sind die letzte Instanz für Abbrüche, die weder durch IP
noch Health Check erklärt werden. Beachten Sie den Unterschied der Schichten: Security Groups sind
stateful und arbeiten auf ENI-Ebene, NACLs sind stateless und arbeiten auf Subnetz-Ebene; daher
muss der Rückverkehr auf ephemeral ports in NACLs manuell erlaubt werden.

| Symptom | Wahrscheinliche Ursache | Prüfen |
|---|---|---|
| `failed to assign an IP address` | keine freie IP auf der Node oder im Subnetz | `describe pod`, `AvailableIpAddressCount` |
| Pod-zu-Pod- oder Pod-zu-RDS-Timeout | SG erlaubt keinen Traffic | `describe-network-interfaces` Groups, SG von RDS |
| Abbruch, obwohl die Anfrage abgeht | NACL blockiert ephemeral ports | NACL-Regeln ein/aus, VPC Flow Logs |
| DNS mit wechselnden Timeouts | CoreDNS, conntrack, Per-ENI-Throttling | CoreDNS-Metriken (Kapitel 33), conntrack, PPS |
| Zusätzliche DNS-Last für externe Namen | Effekt von `ndots:5` | Search-Domains, FQDN mit Punkt |
| 502 oder 503 von einem Service hinter einem LB | Targets `unhealthy` | `describe-target-health`, Health Check, SG |
| Targets `unhealthy`, Pod lebt | Health-Check-Pfad/-Port oder SG | Prüfpfad und -port, SG des Load Balancers |
| Pod ohne DNS und ohne Readiness | eigene SG am Pod statt SG der Node | `SecurityGroupPolicy` am Pod, 53 TCP/UDP, Eingang von Node-SG |

```bash
# 1. Pod-Ereignisse: Ursache für ContainerCreating und IP-Zuweisung
kubectl describe pod <pod>
# 2. Wo der Pod läuft und auf welcher Node
kubectl get pods -o wide
# 3. ENI, IP und SG für eine bestimmte Adresse
aws ec2 describe-network-interfaces \
  --filters "Name=private-ip-address,Values=<ip>" --query 'NetworkInterfaces[0]'
# 4. Freie Adressen im Subnetz
aws ec2 describe-subnets --subnet-ids <subnet> \
  --query 'Subnets[0].AvailableIpAddressCount'
# 5. Zustand der Load-Balancer-Targets
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
# Gibt es bereite Endpoints hinter dem Service?
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
# 6. Namensauflösung aus dem Pod prüfen
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup <name>
# Eigene SG am Pod: Anwendungsmodus und Fehler in der SG-ID suchen
kubectl describe daemonset aws-node -n kube-system | grep -iE 'SECURITY_GROUP|DEMUX'
kubectl describe pod <pod> | grep -i InvalidSecurityGroupID
# 7. Auf der Node: Netzwerk-Dump des VPC CNI erfassen (ipamd/plugin-Logs, ENI, eni-configs)
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids <instance-id> \
  --parameters 'commands=["/opt/cni/bin/aws-cni-support.sh"]'
```

Der Status von ipamd ist auch direkt über seinen lokalen Endpoint sichtbar: `/v1/enis` zeigt die
zugewiesenen ENIs und IPs, `/v1/pods` die Bindung von Adressen an Pods.

## Zugriffsverweigerung: Mensch und Pod

Kapitel 47. Zugriffsfehler teilen sich in zwei unabhängige Achsen, und die erste Frage im
Bereitschaftsdienst lautet: Welche davon ist defekt? Kommt ein Mensch oder CI nicht in den Cluster,
oder erhält ein Pod bei einem AWS-Aufruf `AccessDenied`? Der Ablehnungscode vervollständigt die
Klassifizierung. `Unauthorized` (401) ist ein Fehler der Authentifizierung: Token fehlt oder ist
abgelaufen, die Identity ist nicht gemappt; korrigiert wird dies in kubeconfig, Credentials und
Mappings (Access Entry oder aws-auth). `Forbidden` (403) ist ein Fehler der Autorisierung: Die
Identity ist bereits bekannt, aber RBAC gibt keine Rechte; korrigiert wird dies in Role,
ClusterRole und Bindings. `AccessDenied` aus einem Pod führt zu IRSA oder Pod Identity. Die schnelle
Abzweigung „Cluster oder ich“: Zeigt `aws sts get-caller-identity` die falsche Identity, liegt das
Problem lokal bei Profil, Region oder Credentials.

| Symptom | Wahrscheinliche Ursache | Prüfen |
|---|---|---|
| `Unauthorized`, `must be logged in` | falsche oder nicht gemappte Identity | `sts get-caller-identity`, `list-access-entries` |
| `Unauthorized` direkt nach `edit aws-auth` | eigenes Mapping entfernt | `get cm aws-auth`, über Access Entry wiederherstellen |
| `Forbidden: cannot <verb>` | RBAC gewährt keine Rechte | `kubectl auth can-i`, Role und Bindings |
| `couldn't get server API group` | beschädigte kubeconfig oder Region | `update-kubeconfig`, `current-context`, Profil |
| Pod `AccessDenied` mit IRSA | Trust Policy, OIDC, SA-Anmerkung | OIDC Provider, `sub`/`aud`, Anmerkung `role-arn` |
| Pod `WebIdentityErr` | Token nicht gemountet, falsche Rolle | Pod neu erstellen, Trust Policy prüfen |
| Pod `AccessDenied` mit Pod Identity | Association, Agent oder Token fehlen | `list-pod-identity-associations`, Agent, Token im Pod |

```bash
# Wer bin ich aus Sicht von AWS wirklich?
aws sts get-caller-identity
# Authentifizierungsmodus und accessConfig des Clusters
aws eks describe-cluster --name <cluster> --query 'cluster.accessConfig'
# Wer über Access Entries gemappt ist
aws eks list-access-entries --cluster-name <cluster>
# Inhalt von aws-auth (falls der Modus es noch verwendet)
kubectl -n kube-system get cm aws-auth -o yaml
# Authz: Was darf ich überhaupt?
kubectl auth can-i --list
kubectl auth can-i get pods -n <ns>
# kubeconfig neu erzeugen und Kontext prüfen
aws eks update-kubeconfig --name <cluster> --region <region> --profile <profile>
kubectl config current-context
# Pod-Achse: Rollenannotation auf dem ServiceAccount (IRSA)
kubectl get sa <sa> -n <ns> -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# Pod-Identity-Associations
aws eks list-pod-identity-associations --cluster-name <cluster>
# Läuft der Pod Identity Agent?
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-pod-identity-agent
# Ist das Pod-Identity-Token im Pod gemountet? (Kein File: Agent/Association hat nicht funktioniert.)
kubectl exec <pod> -n <ns> -- ls /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/
```

Einen ausgesperrten Cluster stellen Sie über die EKS API wieder her: `update-cluster-config` mit
`authenticationMode=API_AND_CONFIG_MAP`, danach `create-access-entry` und
`associate-access-policy` mit `AmazonEKSClusterAdminPolicy` (Abschnitt 47.4). Ein Wechsel zurück
zu `CONFIG_MAP` ist nicht möglich.

## Was ansehen, wenn nichts zusammenpasst

- **VPC Flow Logs** erfassen, ob ein Paket auf ENI- oder Subnetz-Ebene `ACCEPT` oder `REJECT`
erhielt. `REJECT` weist auf SG oder NACL hin, fehlende Antwortpakete bei einer abgegangenen
Anfrage auf stateless NACLs und ephemeral ports.
- **Control-Plane-Logs** (api, audit, authenticator) werden im Voraus aktiviert, nicht erst im
Nachhinein: Authenticator-Logs zeigen, ob die eingehende Identity gemappt ist (Kapitel 21 und 34).
- **`aws-cni-support.sh` über SSM** sammelt ipamd- und Plugin-Logs zusammen mit ENI/IP-Status und
Konfiguration in einem Archiv `/var/log/eks_<instance-id>_<...>.tar.gz`, ohne SSH auf die Node.
- **Logs in `/var/log/aws-routed-eni`** (`ipamd.log`, `plugin.log`) lesen Sie auf der Node, wenn
ein Pod bei `failed to assign an IP address` hängt und unklar ist, ob die IPs erschöpft sind oder
die ENI nicht hochgekommen ist.

## Was hier nicht enthalten ist

Dies ist kein Ersatz für die Kapitel: Erklärungen der Ursachen, der Schichtmechanik und warum ein
Symptom genau so aussieht, stehen in den Kapiteln 45, 46 und 47. Hier finden Sie nur den Ablauf
und die Befehle. Die Troubleshooting-Labs des Kurses (119, 120, 121 sowie 126 zu security groups
for pods) werden in dieser Datei nicht dupliziert; bearbeiten Sie sie anhand ihrer eigenen
Aufgaben.
