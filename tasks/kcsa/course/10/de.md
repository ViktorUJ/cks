[Русская версия](ru.md) · [Eng version](README.md) · [Versión en español](es.md) · [Version française](fr.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# Kapitel 10. Authentifizierung und Autorisierung

> **Wie geht es weiter?** In den Kapiteln 07-09 haben wir Clusterkomponenten, Worker-Knoten, `Pod` und Netzwerkgrenzen abgesichert. Nun betrachten wir den Weg einer Anfrage an die Kubernetes-API: Zuerst stellt der Cluster die Identität fest, danach entscheidet er, ob die Aktion erlaubt ist. Dies gehört zur KCSA-Domäne **Kubernetes Security Fundamentals** mit einer Gewichtung von 22 %.

## 10.1 Wer greift auf die API zu: Benutzer und `ServiceAccount`

Jede Anfrage an die Kubernetes-API durchläuft die Authentifizierung, oder authentication. Ihre Aufgabe besteht darin, die Frage „Wer ist das?“ zu beantworten. Nach erfolgreicher Authentifizierung übergibt der API Server den Benutzernamen und die Gruppen an die nächste Stufe, die Autorisierung.

Ein normaler Benutzer, beispielsweise ein Engineer oder ein CI-System außerhalb des Clusters, ist kein Kubernetes-Objekt `User`. Kubernetes erhält eine solche Identität über einen konfigurierten Authentifizierungsmechanismus. `ServiceAccount` ist ein Kubernetes-API-Objekt, das vor allem für Prozesse in einem `Pod` vorgesehen ist. Sein vollständiger Name enthält den Namespace: `system:serviceaccount:shop:catalog`.

| Methode | Wann wird sie verwendet? | Wichtige Einschränkung |
|---|---|---|
| TLS-Clientzertifikat | Administrator, Clusterkomponente oder Automatisierung | Der private Schlüssel und die Gültigkeitsdauer des Zertifikats müssen geschützt werden. |
| Bearer token | Automatisierung oder Integration | Der Token überträgt die Berechtigungen seines Besitzers und darf nicht in Code oder Logs stehen. |
| `ServiceAccount`-Token | Ein Prozess innerhalb eines `Pod` greift auf die API zu | Die Rechte werden durch RBAC bestimmt, nicht allein durch das Vorhandensein eines Tokens. |
| OIDC | Externer Identitätsanbieter, beispielsweise Unternehmens-SSO | Der API Server muss dem issuer vertrauen und die claims des Tokens prüfen. |
| Authentication webhook | Ein externer Dienst bestätigt die credential des Clients | Dies ist eine authentication integration, kein admission webhook und kein authorizer. |
| Bootstrap token | Zweckgebundener Token für den ersten Beitritt eines Knotens | Er ist für bootstrap/TLS bootstrap gedacht, nicht als langlebige application identity. |

Eine anonyme Anfrage wird bei aktivierter anonymer Authentifizierung zum Benutzer `system:anonymous` und zur Gruppe `system:unauthenticated`. Das ist kein geeigneter Modus für gewöhnlichen API-Zugriff. In einer abgesicherten Konfiguration wird anonymer Zugriff deaktiviert oder nur für bewusst offene, sichere Endpunkte zugelassen.

Authentifizierung gewährt nicht selbstständig Zugriff. Zertifikat, Token oder OIDC-Identität benennen lediglich das Subjekt. Was dieses Subjekt tun darf, legt die Autorisierung fest.

## 10.2 `ServiceAccount`-Tokens und das Risiko des Kontos `default`

Jeder `Namespace` enthält einen `ServiceAccount` mit dem Namen `default`. Wenn in der Spezifikation eines `Pod` kein `serviceAccountName` angegeben ist, weist Kubernetes genau diesen zu. Das bedeutet nicht, dass `default` automatisch weitreichende Rechte besitzt: Das Risiko entsteht, wenn ihm der Einfachheit halber ein `RoleBinding` oder `ClusterRoleBinding` erteilt wurde.

Modernes Kubernetes, einschließlich v1.36, stellt einem `Pod` üblicherweise über den TokenRequest-Mechanismus einen projizierten gebundenen Token bereit. Ein solcher Token ist an den `ServiceAccount` und den konkreten `Pod` gebunden, hat eine begrenzte Lebensdauer und wird automatisch vom kubelet erneuert. Ein langlebiges Secret mit einem `ServiceAccount`-Token sollte nicht ohne begründeten Anlass erstellt werden.

Wenn eine Anwendung die Kubernetes-API nicht benötigt, braucht sie keinen Token. Sein Mounting wird im `Pod` oder im `ServiceAccount` selbst deaktiviert:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: shop
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: shop
spec:
  serviceAccountName: web
  automountServiceAccountToken: false
  containers:
    - name: web
      image: nginx:1.30.4
```

Bei einer Kompromittierung des Containers kann ein gemounteter Token gelesen und außerhalb des Clusters verwendet werden, solange er gültig ist. Deshalb wird für jeden `Pod` ein eigener `ServiceAccount` mit minimalen Rechten gewählt, und `default` wird nicht als gemeinsames Anwendungskonto verwendet. Das Deaktivieren von automount hebt RBAC nicht auf, entfernt jedoch das Secret aus dem Dateisystem eines Pod, der keine API benötigt.

## 10.3 Autorisierung: RBAC und andere authorizer

Die Autorisierung beantwortet die Frage „Darf das bereits authentifizierte Subjekt diese Aktion ausführen?“. Der API Server bewertet die Kombination aus Benutzer oder Gruppe, `verb`, Ressource, Namespace und manchmal Objektname sowie API-Pfad.

In Kubernetes können mehrere authorizer aktiviert sein. Sie werden in der konfigurierten Reihenfolge geprüft: Der erste, der `Allow` oder `Deny` zurückgibt, beendet die Entscheidung sofort; nur wenn alle `NoOpinion` zurückgeben, wird die Anfrage standardmäßig abgelehnt. Der wichtigste und für die meisten Cluster empfohlene Mechanismus ist RBAC.

| Mechanismus | Zweck | Praktische Bedeutung |
|---|---|---|
| RBAC | Regeln in `Role`, `ClusterRole` und Bindungen | Die übliche Wahl für kontrollierten, überprüfbaren Zugriff. |
| Node | Beschränkt Aktionen des kubelet im Namen eines Knotens | Wird für Knotenidentitäten verwendet, nicht anstelle von Benutzer-RBAC. |
| Webhook | Fragt einen externen Autorisierungsdienst ab | Geeignet, wenn die Entscheidung von einem externen System abhängt. |
| ABAC | Vergleicht die Anfrage mit einer statischen Richtliniendatei | Ein für neue Projekte veralteter Ansatz, der schwer zu auditieren und zu warten ist. |

Verwechseln Sie RBAC nicht mit authentication. Ein `RoleBinding` bestätigt keine Identität und erstellt keinen Token. Es verbindet ein bereits bekanntes Subjekt mit einem Satz von Berechtigungen. Ebenso beschränkt `NetworkPolicy` Netzwerkverbindungen, ersetzt aber nicht die Entscheidung des API Server über Rechte auf eine Ressource.

### Node authorizer und `NodeRestriction`: benachbarte, aber unterschiedliche Ebenen

**Node authorizer** ist ein spezieller authorizer für die kubelet/node identity `system:node:<nodeName>` aus der Gruppe `system:nodes`. Er beschränkt, welche API-Operationen das kubelet für seinen Knoten und die ihm zugewiesenen `Pod` ausführen kann, einschließlich der benötigten `Secret`, `ConfigMap` und Volume-Informationen. Dies ist **authorization**.

**`NodeRestriction`** ist ein validating admission plugin. Es beschränkt zusätzlich, welche `Node`-Objekte und zugehörigen `Pod` ein kubelet ändern darf: Ein korrekt identifiziertes kubelet darf keinen fremden Node/Pod ändern oder eigenmächtig geschützte labels setzen. Dies ist **admission**, kein authorizer.

> **Nicht verwechseln.** Der Node authorizer beantwortet „Ist dieser node identity diese API-Aktion erlaubt?“. `NodeRestriction` beantwortet „Ist diese Änderung des Objekts auch nach der Autorisierung zulässig?“. Beide Mechanismen sind für least privilege beim kubelet wichtig, ersetzen aber weder Benutzer-RBAC noch TLS oder den Schutz des Knotens.

## 10.4 RBAC: Rollen, Bindungen und minimale Berechtigungen

`Role` beschreibt Regeln nur in einem `Namespace`. `ClusterRole` beschreibt Regeln auf Ebene des gesamten Clusters oder kann über ein `RoleBinding` an einen einzelnen Namespace gebunden werden. `RoleBinding` wirkt in seinem Namespace, `ClusterRoleBinding` im gesamten Cluster.

RBAC-Berechtigungen sind additiv: Mehrere Bindungen werden zusammengeführt, und es gibt keine eigene Regel zum „Verbieten“. Daher bedeutet das Prinzip der minimalen Berechtigungen, nur die erforderlichen `apiGroups`, `resources` und `verbs` zu vergeben und außerdem den kleinstmöglichen Geltungsbereich zu wählen.

Die folgende `Role` erlaubt einer Anwendung, nur eine einzige `ConfigMap` im Namespace `shop` zu lesen. Dies ist ein Beispiel für eine eng gefasste Regel, keine Vorlage für alle Aufgaben.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-site-config
  namespace: shop
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["site-config"]
    verbs: ["get"]
```

Die erwartete Berechtigung lässt sich mit dem Befehl `kubectl auth can-i` prüfen. Ein Administrator kann beispielsweise eine Aktion für ein bestimmtes Konto prüfen:

```bash
kubectl auth can-i get configmap/site-config -n shop \
  --as=system:serviceaccount:shop:web
```

Der Befehl ist für die Prüfung nützlich, ersetzt jedoch nicht das Review der Manifeste und der tatsächlichen Bindungen. Besonderer Aufmerksamkeit bedürfen die Rechte `get`, `list` und `watch` für `secrets` sowie `create`, `update`, `patch` und `delete` für Workloads. Zugriff auf RBAC-Ressourcen, `bind`, `escalate` und `impersonate` kann erlauben, zusätzliche Rechte zu vergeben oder zu nutzen. `cluster-admin`, `verbs: ["*"]` und `resources: ["*"]` sind kein sicherer Ausgangspunkt.

Diese speziellen authorization checks lösen unterschiedliche Aufgaben:

- `bind` bezieht sich auf das Erstellen oder Ändern von `RoleBinding` / `ClusterRoleBinding`. Normalerweise muss der caller bereits die permissions besitzen, die in der zu bindenden `Role`/`ClusterRole` enthalten sind, und zwar im jeweiligen scope. Eine ausdrückliche Berechtigung `bind` für eine konkrete Rolle erlaubt es, das binding auch ohne den eigenen vollständigen Satz dieser permissions auszuführen.

- `escalate` bezieht sich nicht auf binding, sondern auf das Erstellen oder Ändern von `Role` / `ClusterRole`. Normalerweise kann der caller keine permissions in eine Rolle schreiben, die er selbst nicht besitzt. Eine ausdrückliche Berechtigung `escalate` ist eine Ausnahme von diesem Schutz.

- Das klassische `impersonate` erlaubt das Senden von Anfragen im Namen des angegebenen user/group/ServiceAccount oder eines anderen unterstützten identity attribute. Dies ist eine separate Fähigkeit und darf nicht mit `bind` oder `escalate` verwechselt werden.

In Kubernetes v1.36 ist außerdem der Beta-Mechanismus `ConstrainedImpersonation` verfügbar, standardmäßig enabled. Er fügt engere verbs der Familien `impersonate:*` und `impersonate-on:*` hinzu, um nicht nur die identity, sondern auch die in ihrem Namen ausgeführten Aktionen zu beschränken. Bestehende RBAC rules mit dem klassischen `impersonate` funktionieren weiterhin; der API Server kann constrained checks verwenden und bei Bedarf auf klassisches `impersonate` zurückfallen.

Die Berechtigung `create` für `pods` verdient besondere Aufmerksamkeit: Bereits die Möglichkeit, einen `Pod` zu erstellen, kann die Einflussmöglichkeiten eines Subjekts erhöhen, selbst wenn dieses Subjekt keinen direkten Zugriff auf die Zieldaten hat. Die Argumentationskette lautet: Das Subjekt darf einen `Pod` erstellen → der neue `Pod` kann `serviceAccountName` eines beliebigen `ServiceAccount` angeben, der im Namespace verfügbar ist, sofern kein ausdrückliches Verbot separat konfiguriert wurde → über den gewählten `ServiceAccount` oder über gemountete `Secret`/`ConfigMap`/Volumes kann dieser `Pod` Zugriff auf Daten oder API-Rechte erhalten, die das ursprüngliche Subjekt nicht direkt hatte. Das endgültige Ausmaß hängt davon ab, welche `ServiceAccount` und Volumes im Namespace tatsächlich verfügbar sind, sowie von separaten einschränkenden controls (beispielsweise `automountServiceAccountToken: false`, PSA/PSS, eingeschränkte RBAC-Bindungen für vorhandene `ServiceAccount`). Das Recht, einen Workload zu erstellen, sollte nicht als bedingungsloser Weg zu jedem `Secret` oder jedem `ServiceAccount` im Cluster verstanden werden - es erweitert die möglichen Einflussmöglichkeiten genau in dem Umfang, den die übrige Namespace-Konfiguration erlaubt.

## 10.5 Anwendung in der Praxis

Das Plattformteam trennt menschliche und maschinelle Identitäten. Mitarbeitende melden sich über das Unternehmens-OIDC an, die Automatisierung erhält separate Anmeldedaten, und jede Komponente in einem `Namespace` verwendet einen eigenen `ServiceAccount`.

Für einen HTTP-Anwendungsdienst, der die Kubernetes-API nicht aufruft, wird `automountServiceAccountToken: false` gesetzt. Ein Controller, der die API benötigt, erhält einen eigenen `ServiceAccount` und eine `Role` mit konkreten Ressourcen und verbs. Vor der Auslieferung einer Änderung wird `kubectl auth can-i` geprüft, anschließend werden `RoleBinding` und `ClusterRoleBinding` einem Review unterzogen.

Regelmäßig werden Bindungen an `default` und weitreichende `ClusterRoleBinding` gesucht. Beim Ausscheiden eines Mitarbeitenden, beim Verlust eines Tokens oder eines Zertifikatschlüssels werden die Anmeldedaten widerrufen oder ersetzt und die zugehörigen Rechte überprüft. So wird der Verlust eines einzelnen Tokens nicht zu dauerhaftem Zugriff auf den gesamten Cluster.

## 10.6 Exam vocabulary / Mini-Glossar

| Begriff | Bedeutung |
|---|---|
| authentication | Feststellung der Identität des Absenders einer API-Anfrage. |
| authorization | Entscheidung, ob diese Identität eine konkrete Aktion ausführen darf. |
| `ServiceAccount` | Kubernetes-Identität für Prozesse, die üblicherweise in einem `Pod` laufen. |
| bearer token | Ein Token, dessen Inhaber die damit verbundenen Berechtigungen erhält. |
| OIDC | Protokoll zur Anbindung von Kubernetes an einen externen Identitätsanbieter. |
| RBAC | Zugriffssteuerung über Rollen und Rollenbindungen. |
| `Role` / `ClusterRole` | Ein Satz von Regeln in einem Namespace / auf Cluster-Ebene. |
| `RoleBinding` / `ClusterRoleBinding` | Bindung einer Rolle an Benutzer, Gruppe oder `ServiceAccount`. |
| `bind` | Spezielle RBAC-Berechtigung zum Binden von Role/ClusterRole, ohne selbst alle permissions der gebundenen Rolle besitzen zu müssen. |
| `escalate` | Spezielle RBAC-Berechtigung zum Erstellen/Ändern von Role/ClusterRole mit permissions, die über die eigenen permissions des caller hinausgehen. |
| `impersonate` | Klassische Kubernetes permission für die impersonation einer anderen identity; in v1.36 existiert außerdem die Beta-Funktion ConstrainedImpersonation mit engeren verbs. |

## 10.7 Exam Essentials / Zusammenfassung des Kapitels

- Normale Benutzer werden durch externe Mechanismen authentifiziert, während `ServiceAccount` ein Kubernetes-Objekt für Prozesse in einem `Pod` ist.
- Clientzertifikate, bearer tokens, `ServiceAccount`-Tokens und OIDC stellen die Identität fest, gewähren jedoch ohne Autorisierung keine Rechte.
- `default` besitzt nicht automatisch weitreichende Rechte, aber eine Bindung daran macht alle Pod, die es implizit verwenden, zu potenziellen Trägern dieser Rechte.
- Ein `ServiceAccount`-Token, den die Anwendung nicht benötigt, wird nicht über `automountServiceAccountToken: false` gemountet.
- RBAC ist der wichtigste authorizer; `Role` und `RoleBinding` verringern den Zugriffsbereich im Vergleich zu Varianten auf Cluster-Ebene normalerweise.
- Berechtigungen addieren sich, daher erhöhen gefährliche verbs und weitreichende Wildcard-Rechte die Folgen einer Kompromittierung.

## 10.8 Nicht verwechseln und Vorkommen in der Prüfung

Bei einer MCQ (multiple choice question, Frage mit Antwortauswahl) muss man in der Regel authentication von authorization unterscheiden und den engsten sicheren Zugriff auswählen. Häufige Fallen:

- anzunehmen, dass `ServiceAccount` oder ein Token allein Rechte verleiht; die Rechte werden durch RBAC-Bindungen bestimmt;
- `RoleBinding` mit `ClusterRoleBinding` zu verwechseln: Ersteres ist auf seinen Namespace begrenzt;
- `default` unbedingt für gefährlich zu halten: Das Risiko hängt von den erteilten Berechtigungen und dem Token-Mounting ab;
- OIDC für eine Autorisierungsmethode zu halten: OIDC bestätigt die externe Identität, während ein authorizer die Zugriffsentscheidung trifft;
- `cluster-admin` oder Wildcards statt einer separaten Rolle mit präzisem Satz aus Ressourcen und verbs zu wählen.

Bestimmen Sie zuerst, worum es in der Frage geht: Wer stellt die Anfrage, auf welche Weise wurde die Identität festgestellt oder welche Aktion ist erlaubt? Prüfen Sie dann den Geltungsbereich: einen Namespace oder den gesamten Cluster.

## 10.9 Fragen zur Selbstkontrolle

### 1. Welche Aussage über `ServiceAccount` ist richtig?

   - a. Er erhält in seinem Namespace automatisch `cluster-admin`.

   - b. Es ist eine Kubernetes-Identität für Prozesse in einem `Pod`; seine Rechte werden durch RBAC-Bindungen festgelegt.

   - c. Er ersetzt `NetworkPolicy` für Netzwerkzugriff.

   - d. Es ist ein externer Benutzer, der sich immer über OIDC authentifiziert.

<details>
<summary>Antwort und Erläuterung</summary>

**Richtige Antwort: b.** `ServiceAccount` wird üblicherweise von Prozessen in Pods verwendet, und seine Möglichkeiten werden durch Rollen und Bindungen bestimmt. OIDC, `cluster-admin` und Netzwerkregeln folgen nicht allein aus der Erstellung eines `ServiceAccount`.

</details>

### 2. Was verringert das Risiko für einen `Pod`, der keine Kubernetes-API benötigt?

   - a. Die anonyme Authentifizierung des API Server aktivieren.

   - b. `verbs: ["*"]` zu einer `ClusterRole` hinzufügen.

   - c. Dem `default` `ServiceAccount` `cluster-admin` zuweisen.

   - d. `automountServiceAccountToken: false` festlegen.

<details>
<summary>Antwort und Erläuterung</summary>

**Richtige Antwort: d.** Dadurch mountet Kubernetes keinen `ServiceAccount`-Token in den Pod. Die übrigen Optionen erweitern den Zugriff oder schaffen eine unnötige Angriffsfläche.

</details>

### 3. Welches Objekt definiert Berechtigungen, die auf einen `Namespace` begrenzt sind?

   - a. `Role`

   - b. `ClusterRoleBinding`

   - c. `NetworkPolicy`

   - d. `ServiceAccount`

<details>
<summary>Antwort und Erläuterung</summary>

**Richtige Antwort: a.** `Role` definiert Namespace-begrenzte Regeln (welche verbs für welche Ressourcen erlaubt sind), vergibt diese Rechte jedoch nicht selbst an ein Subjekt - zur tatsächlichen Rechtevergabe wird ein `RoleBinding` im selben Namespace verwendet, das die `Role` mit konkreten subjects verbindet.

</details>

### 4. Welcher Kubernetes-Mechanismus ist die wichtigste Wahl für die Verwaltung der Berechtigungen von Benutzern und `ServiceAccount`?

   - a. Node authorizer

   - b. ABAC

   - c. RBAC

   - d. OIDC

<details>
<summary>Antwort und Erläuterung</summary>

**Richtige Antwort: c.** RBAC definiert überprüfbare Zugriffsregeln über Rollen und Bindungen. OIDC gehört zur Authentifizierung, der Node authorizer bedient Knotenidentitäten und ABAC basiert auf statischen Richtlinien.

</details>

### 5. Warum erfordert die Berechtigung `get` für `secrets` besondere Vorsicht?

   - a. Sie kann credentials, Schlüssel und Tokens offenlegen, die anschließend Zugriff auf Kubernetes oder externe Systeme ermöglichen.
   - b. Sie gibt nur Secret-Metadaten zurück und erlaubt einem API-Client niemals, den gespeicherten Wert abzurufen.
   - c. Sie gibt dem Subjekt automatisch das Recht, einen `Pod` zu erstellen, selbst wenn RBAC keine entsprechende Berechtigung enthält.
   - d. Sie zwingt den API Server, das Secret bei jedem Lesen erneut zu verschlüsseln, und erhöht daher die Rechte des Clients.

<details>
<summary>Antwort und Erläuterung</summary>

**Richtige Antwort: a.** `Secret` enthält häufig Daten, die Zugriff auf andere Ressourcen eröffnen. Daher sollten `get`, besonders aber die weiterreichenden `list/watch`, nach least privilege vergeben werden. Das Lesen eines Secret erstellt nicht automatisch weitere RBAC-Berechtigungen.

</details>

> **Wie geht es weiter?** Vertiefen Sie praktische Fähigkeiten in Kapitel 10 CKS: RBAC und Minimierung des Zugriffs, Kapitel 11 CKS: ServiceAccounts und Tokens sowie Kapitel 12 CKS: Beschränkung des Zugriffs auf die Kubernetes-API. Die grundlegende Syntax von Rollen finden Sie auch in Kapitel 38 CKA: RBAC, und die Kette aus `ServiceAccount` und admission in Kapitel 21 CKA. In KCSA geht es mit [Kapitel 11](../11/de.md) über Pod Security Standards und Pod Security Admission weiter.

[Inhaltsverzeichnis](../README_DE.md) · [Kapitel 09](../09/de.md) · [Kapitel 11](../11/de.md)
