[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# KCSA-Kursglossar

Englische Begriffe bleiben in ihrer ursprünglichen Form, da sie zum Lesen der KCSA-Fragen und -Antwortoptionen benötigt werden. Die Beschreibungen erläutern ihre Bedeutung auf Deutsch, ersetzen aber nicht das Üben der Begriffe in englischen MCQ (multiple choice question, Frage mit mehreren Antwortmöglichkeiten).

| Begriff | Beschreibung | Typische Verwechslung | Kapitel |
|---|---|---|---|
| `4C model` | Modell mit den Ebenen Cloud, Cluster, Container und Code zur Analyse von Cloud-Native-Schutzmaßnahmen. | Beschränkt sich nicht nur auf die Cloud-Infrastruktur. | [03](03/de.md) |
| `ABAC` | Autorisierung anhand von Attributen der Anfrage und des Subjekts. | Ist kein RBAC mit Rollen. | [10](10/de.md) |
| `Access control` | Einschränkung des Zugriffs auf eine Ressource anhand von Regeln und Identität. | Umfasst mehr als nur authentication. | [10](10/de.md) |
| `admission` | Phase zur Prüfung oder Änderung einer API-Anfrage nach authentication und authorization. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [07](07/de.md) |
| `Admission control` | API-Phase nach authentication und authorization, die ein Objekt zulässt oder ändert. | Bestätigt keine identity und erteilt keine Rechte. | [11](11/de.md), [17](17/de.md) |
| `Admission policy` | Deklarative Regel zur Prüfung von Objekten bei admission. | Ist nicht dasselbe wie audit policy. | [17](17/de.md) |
| `Admission webhook` | Externer webhook, der am mutating oder validating admission beteiligt ist. | Ist kein Netzwerk-webhook einer Anwendung. | [17](17/de.md) |
| `Alert` | Signal, das gemäß einer Regel Aufmerksamkeit oder Reaktion erfordert. | Ersetzt keine primären Logs und Metriken. | [18](18/de.md) |
| `Allowlist` | Explizite Liste erlaubter Quellen, Aktionen oder Objekte. | Entspricht nicht dem Fehlen von deny-Regeln. | [09](09/de.md), [17](17/de.md) |
| `Anomaly detection` | Erkennung von Abweichungen vom erwarteten Verhalten. | Eine Anomalie allein beweist keinen Angriff. | [18](18/de.md) |
| `API server` | Komponente, die Kubernetes-API-Anfragen entgegennimmt und den Zugriff auf den Zustand koordiniert. | Speichert den Zustand nicht anstelle von etcd. | [07](07/de.md) |
| `Artifact` | Ergebnis der Entwicklung oder des Builds, etwa ein image, Paket oder SBOM. | Ist nicht zwingend ein container image. | [06](06/de.md), [17](17/de.md) |
| `Attack surface` | Gesamtheit der Punkte, über die ein System angegriffen werden kann. | Ist nicht eine einzelne gefundene Schwachstelle. | [02](02/de.md), [16](16/de.md) |
| `Attack vector` | Konkreter Weg oder Methode zur Durchführung eines Angriffs. | Ist enger gefasst als attack surface. | [15](15/de.md), [16](16/de.md) |
| `audit` | PSA-Modus, der Verstöße im Audit protokolliert, ohne die Anfrage abzulehnen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [11](11/de.md) |
| `Audit backend` | Konfigurierter Ort zum Speichern oder Weiterleiten von audit-Ereignissen des API Server. | Der API Server erstellt Ereignisse, das backend speichert oder empfängt sie. | [14](14/de.md) |
| `audit event` | Eintrag von `kube-apiserver` über die Verarbeitung einer Anfrage an die Kubernetes API. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [14](14/de.md) |
| `audit level` | Detailgrad eines Kubernetes-audit-Ereignisses, etwa `Metadata` oder `RequestResponse`. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [20](20/de.md) |
| `Audit logging` | Protokollierung von Anfrageereignissen der Kubernetes API. | Ersetzt nicht die runtime detection von Prozessen. | [14](14/de.md) |
| `Audit policy` | Konfiguration, die festlegt, welche API-Ereignisse mit welchem Detailgrad protokolliert werden. | Ist keine admission policy. | [14](14/de.md) |
| `auditID` | Kennung, die Ereignisse verschiedener Phasen derselben Anfrage verknüpft. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [14](14/de.md) |
| `Authentication` | Feststellung, wer eine Anfrage stellt. | Beantwortet nicht, ob die Aktion erlaubt ist. | [10](10/de.md) |
| `Authorization` | Prüfung, ob ein bereits bekanntes Subjekt eine Aktion ausführen darf. | Stellt keine identity fest. | [10](10/de.md) |
| `Authorization mode` | Konfigurierter Mechanismus zur Entscheidung über API-Berechtigungen. | Ist nicht dasselbe wie eine Methode der authentication. | [10](10/de.md) |
| `Availability` | Verfügbarkeit von Daten oder Diensten für autorisierte Benutzer. | Ist nicht dasselbe wie Vertraulichkeit oder Integrität. | [02](02/de.md), [16](16/de.md) |
| `Backup` | Kopie von Daten zur Wiederherstellung nach Verlust oder Beschädigung. | Auch ein Backup muss wie die ursprünglichen Daten geschützt werden. | [07](07/de.md), [12](12/de.md) |
| `Base64` | Reversible Kodierung von Bytes zur Textdarstellung. | Ist keine encryption. | [12](12/de.md) |
| `baseline` | Profil, das verbreitete Wege zur Privilegieneskalation blockiert. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [11](11/de.md) |
| `Baseline profile` | PSS-Stufe, die bekannte gefährliche Einstellungen blockiert und zugleich kompatibel bleibt. | Ist nicht dasselbe wie das strengste restricted profile. | [11](11/de.md) |
| `Bearer token` | Token, dessen Vorlage die Rechte seines Inhabers gewährt. | Ist kein Passwort, das bedenkenlos in Code abgelegt werden kann. | [10](10/de.md) |
| `bind` | Spezielle RBAC-Berechtigung, um Role/ClusterRole zu binden, ohne selbst alle permissions der gebundenen Rolle besitzen zu müssen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [10](10/de.md) |
| `blast radius` | Umfang der Folgen bei Kompromittierung einer Komponente. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [16](16/de.md) |
| `Bound ServiceAccount token` | Kurzlebiges Token, das an ServiceAccount und Pod gebunden ist. | Ist nicht dasselbe wie ein altes langlebiges Secret-Token. | [10](10/de.md) |
| `Build provenance` | Provenance mit Daten über den Build eines Artefakts. | Ist nicht dasselbe wie eine Signatur oder SBOM. | [17](17/de.md), [19](19/de.md) |
| `CA` | Zertifizierungsstelle, der die Ausstellung oder Prüfung von Zertifikaten anvertraut wird. | Ist kein privater Schlüssel. | [18](18/de.md) |
| `capability` | Einzelnes Linux-Privileg, das unabhängig von UID 0 erteilt oder entzogen werden kann. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [09](09/de.md) |
| `CEL` | Common Expression Language - in die Kubernetes API eingebettete Ausdruckssprache für Bedingungen und Regeln ohne Ausführung beliebigen Codes. | Ist keine allgemeine Sprache für beliebigen Code. | [17](17/de.md) |
| `Certificate` | Dokument mit öffentlichem Schlüssel und Identität, signiert von einer vertrauenswürdigen CA. | Enthält keinen privaten Schlüssel. | [18](18/de.md) |
| `Certificate authority` | Vollständige Bezeichnung für CA als vertrauenswürdige PKI-Instanz. | Ist nicht gleichbedeutend mit jedem TLS-Zertifikat. | [18](18/de.md) |
| `CIA triad` | Drei Sicherheitsziele: confidentiality, integrity und availability. | Ist kein Bedrohungsmodell oder control. | [02](02/de.md), [15](15/de.md) |
| `Cilium` | CNI und Sammlung von Netzwerkwerkzeugen, die NetworkPolicy anwenden können. | Ist nicht selbst die API-Ressource NetworkPolicy. | [13](13/de.md) |
| `CIS Kubernetes Benchmark` | Sammlung von Empfehlungen zur sicheren Konfiguration von Kubernetes. | Ist ein Empfehlungs-framework, kein fertiges control. | [05](05/de.md), [19](19/de.md) |
| `CKS` | Certified Kubernetes Security Specialist, praxisorientierte performance-based Zertifizierung für Kubernetes-Sicherheit. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [01](01/de.md) |
| `Cloud` | Externe Ebene des 4C-Modells: Infrastruktur, IAM und Dienste des Anbieters. | Ist nicht gleichbedeutend mit einem Kubernetes cluster. | [03](03/de.md), [04](04/de.md) |
| `Cloud IAM` | Verwaltung von Identitäten und Berechtigungen für Cloud-Ressourcen. | Ersetzt Kubernetes RBAC nicht. | [04](04/de.md) |
| `Cluster-admin` | Integrierte ClusterRole mit uneingeschränkten Rechten für alle Cluster-Ressourcen. | Sollte nicht als alltägliche identity verwendet werden. | [10](10/de.md), [16](16/de.md) |
| `ClusterRole` | Satz erlaubter API-Aktionen ohne Namespace-Grenze, für Cluster-Ressourcen oder alle Namespaces zugleich. | Ist nicht gleichbedeutend mit Role, die auf einen Namespace beschränkt ist. | [10](10/de.md) |
| `ClusterRoleBinding` | Bindung eines subject an eine ClusterRole auf Ebene des gesamten Clusters. | Ist nicht gleichbedeutend mit RoleBinding, das nur in einem Namespace wirkt. | [10](10/de.md) |
| `CNI` | Standard und Plugins zum Verbinden von Containern mit dem Kubernetes-Netzwerk. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [09](09/de.md), [13](13/de.md) |
| `Code` | 4C-Ebene mit Quellcode, Abhängigkeiten und Entwicklungspraktiken. | Ist nicht gleichbedeutend mit einem bereits gebauten image. | [03](03/de.md), [06](06/de.md) |
| `Compliance` | Erfüllung anwendbarer Anforderungen mit nachweisbaren evidence. | Garantiert nicht das Fehlen aller Risiken. | [19](19/de.md) |
| `Confidentiality` | Schutz von Daten vor Offenlegung gegenüber nicht autorisierten Parteien. | Ist nicht gleichbedeutend mit integrity oder availability. | [02](02/de.md), [12](12/de.md) |
| `Container` | Isolierter Prozess mit image und Runtime-Einschränkungen. | Ist nicht gleichbedeutend mit Pod, der mehrere Container enthalten kann. | [03](03/de.md), [09](09/de.md) |
| `container escape` | Ausbruch eines Prozesses aus der Container-Isolierung zu Ressourcen des Worker-Knotens. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [16](16/de.md) |
| `Container image` | Unveränderliche Vorlage aus Dateien und Metadaten zum Starten eines Containers. | Ist nicht gleichbedeutend mit einem laufenden container. | [06](06/de.md), [17](17/de.md) |
| `Container registry` | Dienst zum Speichern und Verteilen von container images. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [06](06/de.md) |
| `Container runtime` | Softwareschicht, die Container auf einem Knoten über CRI startet. | Ist nicht gleichbedeutend mit kubelet. | [08](08/de.md) |
| `context` | Auswahl von cluster, user und namespace, die `kubectl` verwendet. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [09](09/de.md) |
| `Control` | Konkrete Maßnahme, die die Wahrscheinlichkeit eines Risikos oder seine Folgen verringert. | Ist nicht gleichbedeutend mit framework, das Maßnahmen strukturiert. | [05](05/de.md), [19](19/de.md) |
| `Control plane` | Logische Gesamtheit der Komponenten, die den Zustand von Kubernetes steuern. | Ist nicht gleichbedeutend mit worker node. | [07](07/de.md) |
| `Controller Manager` | Komponente, die Controller zur Angleichung an den gewünschten Zustand ausführt. | Wählt keinen Knoten für einen Pod aus. | [07](07/de.md) |
| `CRI` | Kubernetes-Schnittstelle zwischen kubelet und container runtime. | Ist weder CNI noch CSI. | [08](08/de.md) |
| `CronJob` | Kubernetes-Ressource, die Job nach Zeitplan erstellt. | Kann von Angreifern zur Persistenz im Cluster verwendet werden, nicht nur für den vorgesehenen Zweck. | [16](16/de.md) |
| `CVE` | Kennung einer öffentlich bekannten Schwachstelle. | Ein CVE ist nicht gleichbedeutend mit nachgewiesener Ausnutzung. | [06](06/de.md), [16](16/de.md) |
| `Data flow` | Übertragungsweg von Daten zwischen Systembeteiligten. | Ist nicht gleichbedeutend mit trust boundary, kreuzt diese aber. | [15](15/de.md) |
| `Default deny` | Ausgangsrichtlinie, die implizit nicht erlaubten Traffic verbietet. | Ist nicht gleichbedeutend mit dem Verbot sämtlichen API-Zugriffs. | [13](13/de.md) |
| `default-deny` | Ansatz, bei dem Traffic in der gewählten Richtung verboten ist, bis eine explizite policy ihn erlaubt. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [13](13/de.md) |
| `Defense in depth` | Kombination unabhängiger Schutzebenen. | Bedeutet nicht, dieselbe control zu duplizieren. | [02](02/de.md), [05](05/de.md) |
| `Denial of Service` | Beeinträchtigung der Verfügbarkeit durch Erschöpfung oder Überlastung von Ressourcen. | Ist nicht gleichbedeutend mit jeder langsamen Systemausführung. | [16](16/de.md) |
| `Deployment` | Kubernetes-Ressource zur Verwaltung von ReplicaSet und Pod-Aktualisierungen. | Ist keine eigenständige Sicherheitsgrenze. | [02](02/de.md), [09](09/de.md) |
| `Detection` | Erkennung eines bereits beobachteten Ereignisses oder einer Abweichung. | Verhindert kein Objekt vor seiner Erstellung. | [14](14/de.md), [18](18/de.md) |
| `Digest` | Kryptografische Kennung eines bestimmten Artefaktinhalts. | Beweist weder Autor, Sicherheit noch Herkunft. | [06](06/de.md), [17](17/de.md) |
| `distractor` | Plausible, aber falsche Antwortoption. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [20](20/de.md) |
| `Distroless` | Minimales runtime image ohne übliche shell und package manager. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [06](06/de.md) |
| `DNS` | Dienst zur Namensauflösung für Dienste und externe Adressen. | Ist kein Mechanismus für network segmentation. | [09](09/de.md) |
| `DoS` | Dienstverweigerung durch Ressourcenerschöpfung oder Überlastung. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [16](16/de.md) |
| `Egress` | Ausgehender Netzwerkverkehr von einem ausgewählten Pod. | Ist nicht gleichbedeutend mit ingress-Traffic zu einem Pod. | [13](13/de.md), [18](18/de.md) |
| `Encryption` | Kryptografischer Schutz von Daten unter Verwendung eines Schlüssels. | Ist nicht gleichbedeutend mit reversibler encoding. | [04](04/de.md), [12](12/de.md) |
| `Encryption at rest` | Verschlüsselung gespeicherter Daten, etwa in etcd. | Schützt nicht vor API-Lesezugriff durch ein Subjekt mit Berechtigung. | [07](07/de.md), [12](12/de.md) |
| `Encryption in transit` | Verschlüsselung von Daten während der Übertragung über das Netzwerk. | Ersetzt weder authorization noch segmentation. | [04](04/de.md), [18](18/de.md) |
| `EncryptionConfiguration` | API-Server-Konfiguration zur Verschlüsselung von API-Ressourcen in etcd. | Ist keine RBAC-policy. | [12](12/de.md) |
| `Endpoint` | Adresse oder Netzwerkzugriffspunkt eines Dienstes oder einer Komponente. | Ist nicht in jedem Kontext gleichbedeutend mit Kubernetes EndpointSlice. | [04](04/de.md), [09](09/de.md) |
| `enforce` | PSA-Modus, der einen regelverletzenden `Pod` ablehnt. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [11](11/de.md) |
| `envelope encryption` | Ansatz, bei dem Daten mit einem Datenschlüssel verschlüsselt und dieser durch einen KMS-Schlüssel geschützt wird. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [12](12/de.md) |
| `escalate` | Spezielle RBAC-Berechtigung zum Erstellen oder Ändern von Role/ClusterRole mit permissions, die über die eigenen permissions des caller hinausgehen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [10](10/de.md) |
| `Etcd` | Zustandsspeicher der Kubernetes control plane. | Ist nicht gleichbedeutend mit API Server. | [07](07/de.md), [12](12/de.md) |
| `Evidence` | Überprüfbarer Nachweis für die Wirksamkeit einer control oder eines Prozesses. | Ist nicht gleichbedeutend mit der Compliance-Anforderung selbst. | [14](14/de.md), [19](19/de.md) |
| `Exploit` | Code oder Technik, die eine Schwachstelle ausnutzt. | Nicht jede vulnerability hat einen bekannten exploit. | [16](16/de.md) |
| `External Secrets Operator` | Operator, der Secrets aus einem externen Speicher synchronisiert. | Nach der Synchronisierung bleiben Risiken des Kubernetes Secret bestehen. | [12](12/de.md) |
| `Falco` | Werkzeug zur runtime detection des Verhaltens von Containern und Knoten. | Ersetzt audit logging von API-Anfragen nicht. | [16](16/de.md), [18](18/de.md) |
| `Firewall` | Netzwerk-control, die Traffic an einer definierten Grenze filtert. | Ist nicht gleichbedeutend mit NetworkPolicy innerhalb von Kubernetes. | [04](04/de.md) |
| `FQDN` | Vollständig qualifizierter Domainname eines Netzwerkziels. | Ist weder IP-Adresse noch identity. | [09](09/de.md), [18](18/de.md) |
| `Framework` | Struktur zur Bewertung von Risiken, Anforderungen oder Vollständigkeit von controls. | Ist selbst keine technische control. | [05](05/de.md), [19](19/de.md) |
| `Grafana` | Werkzeug zur Visualisierung von Dashboards und Alerts anhand von Observability-Daten. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [18](18/de.md) |
| `gVisor` | Sandbox runtime, die Isolierung zwischen workload und Kernel des Knotens hinzufügt. | Ersetzt PSS, RBAC und NetworkPolicy nicht. | [05](05/de.md) |
| `hard multi-tenancy` | Mandantenisolierung mit starken, häufig infrastrukturbasierten Grenzen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [05](05/de.md) |
| `Hash` | Ergebnis einer Hash-Funktion zur Prüfung der Datenidentität. | Ist keine Signatur mit Autorenprüfung. | [06](06/de.md), [17](17/de.md) |
| `HIPAA` | Regelwerk zum Schutz medizinischer Informationen in den USA. | Ist keine Kubernetes-Ressource. | [19](19/de.md) |
| `hostPath` | Volume, das einen Dateisystempfad des Worker-Knotens in einen `Pod` einhängt. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [09](09/de.md) |
| `Hubble` | Werkzeug zur Beobachtung von Cilium-Netzwerkflüssen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [18](18/de.md) |
| `Identity` | Darstellung des Subjekts, in dessen Namen eine Aktion ausgeführt wird. | Ist nicht gleichbedeutend mit einem Satz von Berechtigungen. | [10](10/de.md), [18](18/de.md) |
| `Image digest` | Digest, der den konkreten Inhalt eines image festlegt. | Ist nicht gleichbedeutend mit mutable tag. | [06](06/de.md), [17](17/de.md) |
| `Image policy` | Zulassungsregel für image nach Quelle, Signatur oder Eigenschaften. | Ist kein scanner-Bericht. | [17](17/de.md) |
| `image registry` | Speicher für container images und zugehörige metadata. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [17](17/de.md) |
| `Image tag` | Menschenlesbare image-Kennzeichnung, die geändert werden kann. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [06](06/de.md) |
| `impersonate` | Klassische Kubernetes-Berechtigung zur impersonation einer anderen identity; in v1.36 gibt es zudem beta ConstrainedImpersonation mit engeren verbs. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [10](10/de.md) |
| `Incident response` | Vorbereitung und Maßnahmen zur Erkennung, Eindämmung und Wiederherstellung nach einem Vorfall. | Beschränkt sich nicht auf das Sammeln von Logs. | [14](14/de.md), [16](16/de.md) |
| `Ingress` | Eingehender Netzwerkverkehr zu einem ausgewählten Pod. | Ist nicht gleichbedeutend mit dem Objekt Ingress für HTTP-Routing. | [13](13/de.md), [18](18/de.md) |
| `Integrity` | Eigenschaft von Daten, ohne Berechtigung korrekt und unverändert zu bleiben. | Ist nicht gleichbedeutend mit confidentiality. | [02](02/de.md), [19](19/de.md) |
| `iptables` | Implementierungsmodus für die Traffic-Umleitung von `Service` in `kube-proxy`. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [08](08/de.md) |
| `IPVS` | Seit Kubernetes v1.35 veraltender Modus für `Service`-Lastverteilung in `kube-proxy`. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [08](08/de.md) |
| `Isolation` | Einschränkung der Auswirkungen eines Subjekts oder workload auf ein anderes. | Umfasst mehr als einzelne network segmentation. | [05](05/de.md), [13](13/de.md) |
| `KCNA` | Kubernetes and Cloud Native Associate, breite einführende Zertifizierung für cloud native. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [01](01/de.md) |
| `KCSA` | Kubernetes and Cloud Native Security Associate, konzeptionelle Zertifizierung für cloud native und Kubernetes-Sicherheit. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [01](01/de.md) |
| `kill chain` | Modell einer Abfolge von Angriffsphasen vom Erstzugriff bis zur Auswirkung. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [15](15/de.md), [19](19/de.md) |
| `KMS` | Dienst oder plugin zur Verwaltung von Verschlüsselungsschlüsseln. | Ist nicht selbst der encryption provider für Daten. | [12](12/de.md) |
| `KMS v2` | Aktuell empfohlene API-Integration von API Server mit KMS; KMS v1 ist seit v1.28 deprecated und seit v1.29 standardmäßig deaktiviert. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [12](12/de.md) |
| `kube-apiserver` | Vollständiger Prozessname von API Server als control-plane-Komponente. | Ist nicht gleichbedeutend mit kubelet API oder kube-proxy. | [07](07/de.md) |
| `kube-bench` | Werkzeug, das die Konfiguration von Kubernetes-Komponenten mit CIS-Benchmark-Prüfungen vergleicht. | Bewertet nicht die Geschäftslogik der Anwendung und ersetzt kein vollständiges Audit. | [05](05/de.md), [19](19/de.md) |
| `Kube-proxy` | Knotenkomponente, die Kernelregeln (`iptables`, `nftables`, IPVS) für das Routing zu `Service` konfiguriert; selbst kein userspace traffic proxy. | Wendet keine NetworkPolicy an und leitet Pakete nicht selbst weiter, das übernimmt der Kernel. | [08](08/de.md) |
| `Kubeconfig` | Datei mit Cluster-Adresse, vertrauenswürdiger CA und Client-Anmeldedaten. | Ist keine harmlose Konfiguration ohne Secrets. | [09](09/de.md) |
| `Kubelet` | Knotenagent, der Pod über container runtime startet. | Ist nicht gleichbedeutend mit scheduler. | [08](08/de.md) |
| `Kubelet API` | HTTPS-Schnittstelle von Kubelet für Vorgänge und Diagnose auf dem Knoten. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [08](08/de.md) |
| `Kubernetes API` | Schnittstelle zur Verwaltung von Cluster-Ressourcen über API Server. | Ist nicht gleichbedeutend mit kubelet API. | [07](07/de.md), [10](10/de.md) |
| `L3/L4/L7` | Ebenen der Kontrolle: IP-Netzwerk, Transportports und Anwendungsprotokoll. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [13](13/de.md) |
| `lateral movement` | Wechsel eines Angreifers von einer kompromittierten Ressource zu einer anderen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [15](15/de.md), [16](16/de.md) |
| `Least privilege` | Vergabe nur der minimal erforderlichen Rechte. | Bedeutet nicht null Rechte für alle. | [02](02/de.md), [10](10/de.md) |
| `level` | Datenumfang in einem Ereignis: `None`, `Metadata`, `Request` oder `RequestResponse`. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [14](14/de.md) |
| `LimitRange` | Begrenzungen und Standardwerte für Container in einem Namespace. | Legt kein gesamtes Namespace-Budget wie ResourceQuota fest. | [11](11/de.md), [16](16/de.md) |
| `Log backend` | Empfänger oder Speicher für Logs. | Ist nicht selbst die Quelle aller Ereignisse. | [14](14/de.md), [18](18/de.md) |
| `Logging` | Sammlung diskreter Ereigniseinträge. | Ist nicht gleichbedeutend mit monitoring oder vollständiger observability. | [14](14/de.md), [18](18/de.md) |
| `MCQ` | Multiple choice question - Frage mit mehreren Antwortmöglichkeiten, Format der KCSA-Prüfung. | Ist nicht dasselbe wie eine hands-on Aufgabe in CKS. | [01](01/de.md), [20](20/de.md) |
| `Metric` | Numerische Messung eines Zustands oder Verhaltens im Zeitverlauf. | Enthält nicht den vollständigen Kontext eines Logs. | [18](18/de.md) |
| `MITM` | Man-in-the-middle, Abfangen oder Manipulation eines Netzwerkaustauschs. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [16](16/de.md) |
| `MITRE ATT&CK` | Wissensbasis zu Taktiken und Techniken des Angreiferverhaltens. | Ist keine preventive control. | [15](15/de.md), [19](19/de.md) |
| `MITRE ATT&CK for Containers` | Wissensbasis zu Taktiken und Techniken, die Angreiferverhalten in Container-Umgebungen beschreiben. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [15](15/de.md) |
| `mock exam` | Übungsprüfung, die Format und Zeitbegrenzung nachbildet. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [20](20/de.md) |
| `Monitoring` | Beobachtung bekannter Systemindikatoren und Schwellenwerte. | Ist enger gefasst als observability. | [18](18/de.md) |
| `most appropriate` | Hinweis, unter den inhaltlich zulässigen Antworten die direkteste und passendste auszuwählen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [20](20/de.md) |
| `mTLS` | TLS mit gegenseitiger Überprüfung der Kommunikationsparteien. | Legt keine allowlist für Netzwerkflüsse fest. | [18](18/de.md) |
| `Multi-stage build` | Build mit einer separaten builder stage und einer minimalen final stage. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [06](06/de.md) |
| `multi-tenancy` | Nutzung einer Plattform durch mehrere Teams oder Organisationen mit getrenntem Zugriff und Ressourcen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [13](13/de.md) |
| `multiple choice` | Frage mit Antwortoptionen, bei der die korrekteste Option zu wählen ist. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [01](01/de.md) |
| `Mutating admission webhook` | Webhook, der ein Objekt vor dem Speichern ändern kann. | Ist nicht gleichbedeutend mit validating webhook, der nur zulässt oder ablehnt. | [17](17/de.md) |
| `MutatingAdmissionPolicy` | Integrierte deklarative admission policy auf CEL, die passende API-Objekte ohne separaten webhook verändert. | Ist nicht gleichbedeutend mit einem externen mutating admission webhook. | [17](17/de.md) |
| `Namespace` | Logischer Kubernetes-Bereich für Ressourcen, Rechte und Quotas. | Ist für sich allein keine Netzwerk-Firewall. | [05](05/de.md), [13](13/de.md) |
| `Network segmentation` | Trennung von Netzwerkpfaden zwischen Zonen oder workload. | Ist nicht gleichbedeutend mit allgemeiner isolation. | [13](13/de.md), [18](18/de.md) |
| `NetworkPolicy` | API-Ressource, die erlaubten ingress und egress für Pod beschreibt. | Ersetzt weder kube-proxy, RBAC noch TLS. | [13](13/de.md) |
| `nftables` | Modus von `kube-proxy`; unter unterstütztem Linux als Ersatz für deprecated IPVS empfohlen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [08](08/de.md) |
| `Node` | Kubernetes-Worker- oder control-plane-Maschine. | Ist nicht gleichbedeutend mit Pod. | [07](07/de.md), [08](08/de.md) |
| `Node authorization` | Autorisierungsmechanismus für API-Anfragen von kubelet. | Ist kein Node object. | [08](08/de.md), [10](10/de.md) |
| `Observability` | Fähigkeit, den Systemzustand anhand von Logs, Metriken und traces zu verstehen. | Beschränkt sich nicht auf ein einzelnes monitoring-Dashboard. | [18](18/de.md) |
| `OIDC` | Identitätsprotokoll, damit API Server einem externen issuer vertrauen kann. | Ist keine allgemeine OAuth-Autorisierung für Kubernetes. | [10](10/de.md) |
| `OPA` | Allgemeine policy engine, häufig über Gatekeeper eingesetzt. | Ist keine integrierte ValidatingAdmissionPolicy. | [17](17/de.md) |
| `OpenID Connect` | Vollständige Bezeichnung von OIDC als Identitätsschicht über OAuth 2.0. | Ersetzt keine RBAC-Entscheidung. | [10](10/de.md) |
| `OWASP Kubernetes Top 10` | Katalog verbreiteter Kubernetes-Risikoklassen von OWASP (Open Worldwide Application Security Project, offenes Projekt für Webanwendungssicherheit). | Ist keine Liste obligatorischer YAML-Felder. | [05](05/de.md) |
| `PeerAuthentication` | Istio-Ressource, die den mTLS-Annahmemodus für ein service mesh oder einen Teil davon festlegt. | `STRICT` erfordert mTLS, ersetzt aber weder authorization noch NetworkPolicy. | [18](18/de.md) |
| `performance-based` | Format, das eine ausgeführte praktische Aktion in einer Umgebung bewertet, nicht nur eine ausgewählte Antwort. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [01](01/de.md) |
| `persistence` | Fähigkeit eines Angreifers, nach Entfernung des ursprünglichen Einstiegspunkts Zugriff zu behalten. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [16](16/de.md) |
| `PKI` | Infrastruktur aus Schlüsseln, Zertifikaten und Vertrauenskapital. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [18](18/de.md) |
| `Pod` | Kleinste bereitstellbare Kubernetes-Einheit mit einem oder mehreren Containern. | Ist nicht gleichbedeutend mit einem einzelnen container. | [09](09/de.md), [11](11/de.md) |
| `Pod Security Admission` | Integrierter admission-Mechanismus zur Durchsetzung von Pod Security Standards. | Ist nicht das entfernte PSP. | [11](11/de.md) |
| `Pod Security Standards` | Satz der Stufen privileged, baseline und restricted für Pod-Einstellungen. | Ist nicht gleichbedeutend mit einem konkreten admission plugin. | [11](11/de.md) |
| `Policy` | Regel, die gewünschtes oder zulässiges Verhalten festlegt. | Nicht jede policy wird selbst technisch enforced. | [13](13/de.md), [17](17/de.md) |
| `policy engine` | Mechanismus, der Regeln auf API-Objekte anwendet, oft im admission path. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [05](05/de.md) |
| `Private key` | Geheimer kryptografischer Schlüssel zum Signieren oder zur Authentisierung. | Darf nicht zusammen mit dem certificate veröffentlicht werden. | [09](09/de.md), [18](18/de.md) |
| `privileged` | Container-Modus mit sehr weitreichenden Rechten gegenüber dem Host. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [09](09/de.md), [11](11/de.md) |
| `proctored` | Prüfung mit Überwachung der Regeleinhaltung durch einen Proktor. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [01](01/de.md) |
| `proctoring` | Kontrolliertes Prüfungsverfahren mit Beobachtung nach den Regeln des Anbieters. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [20](20/de.md) |
| `Prometheus` | System zum Sammeln und Speichern von Metriken. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [18](18/de.md) |
| `Provenance` | Aufzeichnung über die Herkunft eines Artefakts, seine Quellen und seinen Erstellungsprozess. | Ist nicht gleichbedeutend mit digest, signature oder SBOM. | [17](17/de.md), [19](19/de.md) |
| `PSA` | Pod Security Admission, integrierter admission controller zur Durchsetzung von PSS. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [11](11/de.md) |
| `PSP` | Seit Kubernetes v1.25 entfernter PodSecurityPolicy-Mechanismus. | Ist kein aktueller Ersatz für PSA. | [11](11/de.md) |
| `PSS` | Pod Security Standards, drei Standardsicherheitsprofile für `Pod`. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [11](11/de.md) |
| `Public key` | Öffentlicher Teil eines Schlüsselpaars zur Signaturprüfung oder Verschlüsselung. | Darf nicht als private key gespeichert werden. | [18](18/de.md) |
| `RBAC` | Autorisierung anhand von Rollen und Bindungen von Subjekten an Rechte. | Ist keine authentication. | [10](10/de.md) |
| `RCE` | Remote code execution, Ausführung von Code über eine Schwachstelle aus der Ferne. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [16](16/de.md) |
| `Registry` | Registry zum Speichern und Bereitstellen von container images. | Bestätigt die Sicherheit eines image nicht automatisch. | [06](06/de.md), [17](17/de.md) |
| `ResourceQuota` | Begrenzung des gesamten Ressourcenverbrauchs in einem Namespace. | Legt keine container bounds wie LimitRange fest. | [13](13/de.md), [16](16/de.md) |
| `restricted` | Strenges least-privilege-Profil für Anwendungs-workloads. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [11](11/de.md) |
| `Risk` | Kombination aus Wahrscheinlichkeit eines unerwünschten Ereignisses und seinen Folgen. | Ist nicht gleichbedeutend mit threat oder vulnerability. | [15](15/de.md), [19](19/de.md) |
| `Role` | Satz erlaubter API-Aktionen in einem Namespace. | Erteilt ohne RoleBinding keine Rechte. | [10](10/de.md) |
| `Role / ClusterRole` | Regelsatz in einem Namespace / auf Cluster-Ebene. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [10](10/de.md) |
| `RoleBinding` | Bindung eines subject an Role oder ClusterRole in einem Namespace. | Ist nicht die authentication selbst. | [10](10/de.md) |
| `RoleBinding / ClusterRoleBinding` | Bindung einer Rolle an Benutzer, Gruppe oder `ServiceAccount`. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [10](10/de.md) |
| `Runtime class` | Auswahl einer runtime class zum Starten eines Pod. | Ist keine runtime detection. | [05](05/de.md), [09](09/de.md) |
| `Runtime detection` | Erkennung des Prozessverhaltens nach Start eines workload. | Ersetzt audit logging von API-Anfragen nicht. | [16](16/de.md), [18](18/de.md) |
| `runtime socket` | Unix-Socket, über den ein Client container runtime steuert. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [08](08/de.md) |
| `Sandbox` | Verstärkte Ausführungsgrenze für nicht vertrauenswürdige workload. | Ersetzt least privilege nicht. | [05](05/de.md) |
| `SAST` | Statische Codeanalyse ohne Ausführung der Anwendung. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [06](06/de.md) |
| `SBOM` | Inventar der Komponenten und Abhängigkeiten eines Softwareartefakts. | Ist nicht gleichbedeutend mit signature oder provenance. | [06](06/de.md), [17](17/de.md) |
| `SCA` | Analyse von Abhängigkeiten und deren bekannten Risiken. | Ist kein runtime scanner. | [06](06/de.md) |
| `Scheduler` | Komponente, die einen Knoten für einen neuen Pod auswählt. | Startet keine Container auf dem Knoten. | [07](07/de.md) |
| `Secret` | Kubernetes-API-Objekt für kleine sensible Daten. | Base64 in `data` ist keine encryption. | [12](12/de.md) |
| `Secret scanning` | Suche nach credentials und anderen Secrets in Code, Historie und Artefakten. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [06](06/de.md) |
| `SecurityContext` | Einstellungen für Privilegien und Einschränkungen eines Prozesses oder Pod. | Ersetzt weder PSS, RBAC noch NetworkPolicy. | [09](09/de.md), [11](11/de.md) |
| `Segmentation` | Unterteilung eines Systems in Zonen mit eingeschränkten Interaktionen. | Ist eine Art von isolation, aber kein vollständiges Synonym dafür. | [13](13/de.md), [15](15/de.md) |
| `Service identity` | Dienstidentität: Konto einer Komponente oder eines workload, mit dem es die API anspricht. | Ist keine Identität eines menschlichen Operators. | [07](07/de.md) |
| `Service mesh` | Infrastrukturschicht für Dienst-connectivity, identity und oft mTLS. | Ersetzt NetworkPolicy nicht. | [18](18/de.md) |
| `ServiceAccount` | Kubernetes-Identität für Prozesse in Pod. | Erteilt ohne RBAC keine Rechte. | [10](10/de.md), [12](12/de.md) |
| `Shared responsibility` | Aufteilung der Schutzpflichten zwischen Anbieter und Kunde. | Bedeutet nicht, dass der Anbieter die workloads des Kunden schützt. | [04](04/de.md) |
| `SIEM` | System zur Zentralisierung und Korrelation von Sicherheitsereignissen. | Ist keine Quelle der audit-Ereignisse von API Server. | [14](14/de.md), [18](18/de.md) |
| `Signature` | Kryptografischer Nachweis, der Daten mit einem signierenden Schlüssel verknüpft. | Ist nicht gleichbedeutend mit digest, SBOM oder provenance. | [06](06/de.md), [17](17/de.md) |
| `SLSA` | Framework mit Anforderungen an die supply chain mit unabhängigen Tracks Build und Source. | Ist keine allgemeine Bezeichnung für reproducible build. | [17](17/de.md), [19](19/de.md) |
| `SLSA v1.2` | Rahmen von Anforderungen mit unabhängigen Tracks Build und Source; die Stufe wird zusammen mit dem Track angegeben. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [17](17/de.md), [19](19/de.md) |
| `snapshot` | Konsistentes Backup des Zustands von `etcd` zu einem bestimmten Zeitpunkt. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [07](07/de.md) |
| `SOC 2` | Prüfung der controls einer Dienstleistungsorganisation nach Trust Services Criteria. | Ist kein Kubernetes-Sicherheitsstandard. | [19](19/de.md) |
| `soft multi-tenancy` | Trennung vertrauenswürdiger Teams in einem gemeinsamen Cluster mit logischen controls. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [05](05/de.md) |
| `Software supply chain` | Weg von Code, Abhängigkeiten, Build und Bereitstellung bis zur runtime. | Beschränkt sich nicht auf container registry. | [06](06/de.md), [17](17/de.md) |
| `SPIFFE` | Standard für workload-Identitäten in verteilten Systemen. | Ist selbst kein TLS-Zertifikat. | [18](18/de.md) |
| `stage` | Zeitpunkt der Anfrageverarbeitung: `RequestReceived`, `ResponseStarted`, `ResponseComplete` oder `Panic`. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [14](14/de.md) |
| `STRIDE` | Framework für Bedrohungsmodellierung anhand von sechs Kategorien. | Ist kein Protokoll tatsächlicher Angriffe. | [15](15/de.md), [19](19/de.md) |
| `Subject` | Benutzer, Gruppe oder ServiceAccount, in dessen Namen eine Anfrage handelt. | Ist nicht gleichbedeutend mit Role oder permission. | [10](10/de.md) |
| `Supply chain` | Kette zur Erstellung und Bereitstellung eines Softwareartefakts. | Ist nicht gleichbedeutend mit einer einzelnen Build-Phase. | [17](17/de.md), [19](19/de.md) |
| `Syscall` | Systemaufruf eines Prozesses an den Betriebssystemkernel. | Ist kein Kubernetes-API-Aufruf. | [16](16/de.md), [18](18/de.md) |
| `Tag` | Menschenlesbare Referenz auf eine image-Version. | Kann mutable sein und ist nicht gleichbedeutend mit digest. | [06](06/de.md) |
| `Threat` | Mögliche Ursache oder Szenario eines unerwünschten Ereignisses. | Ist nicht gleichbedeutend mit vulnerability oder bewertetem risk. | [15](15/de.md), [16](16/de.md) |
| `Threat model` | Beschreibung der Assets, Grenzen, Flüsse und Bedrohungen eines Systems. | Ist keine CVE-Liste. | [15](15/de.md), [19](19/de.md) |
| `TLS` | Protokoll zur Verschlüsselung und Authentisierung einer Verbindung. | Ersetzt weder NetworkPolicy noch authorization. | [07](07/de.md), [18](18/de.md) |
| `TLS termination` | Punkt, an dem eine Komponente TLS beendet und die Verbindung entschlüsselt. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [18](18/de.md) |
| `Token` | Anmeldedaten, die zur authentication vorgelegt werden. | Führt nicht automatisch zu eingeschränktem RBAC-Zugriff. | [10](10/de.md) |
| `Trace` | Verknüpfter Weg einer Anfrage durch verteilte Dienste. | Ist nicht gleichbedeutend mit einem einzelnen Log-Eintrag. | [18](18/de.md) |
| `Trust boundary` | Stelle, an der sich Vertrauen, Rechte oder Datenkontrolle ändern. | Muss nicht mit einem Namespace übereinstimmen. | [15](15/de.md) |
| `Trusted image` | Image mit überprüfbarer Herkunft und einer Reihe von Vertrauenskontrollen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [06](06/de.md) |
| `Trusted registry` | Registry, aus der eine policy images beziehen darf. | Beweist nicht das Fehlen von CVE in einem image. | [06](06/de.md), [17](17/de.md) |
| `ValidatingAdmissionPolicy` | Integrierte deklarative admission policy auf CEL zur validation von API-Objekten; cluster-scoped, angewendet über separates `ValidatingAdmissionPolicyBinding`. | Befindet sich nicht „in einem namespace“ - der Namespace-Scope wird über binding/`matchResources` festgelegt. | [17](17/de.md) |
| `version-light` | Prüfungsmerkmal, bei dem zentrale Konzepte und nicht die Bindung an eine Kubernetes-Version zählen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [01](01/de.md) |
| `Vulnerability` | Schwäche, die eine threat oder ein exploit ausnutzen kann. | Ist nicht gleichbedeutend mit threat oder risk. | [06](06/de.md), [16](16/de.md) |
| `Vulnerability scanner` | Werkzeug zur Suche nach bekannten Schwachstellen anhand von Komponentendaten. | Verhindert kein runtime-Verhalten. | [06](06/de.md), [17](17/de.md) |
| `warn` | PSA-Modus, der dem Client eine Warnung anzeigt, ohne die Anfrage abzulehnen. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [11](11/de.md) |
| `Webhook` | HTTP-Handler, der von Kubernetes oder einer anderen Komponente aufgerufen wird. | Nicht jeder webhook gehört zu admission. | [10](10/de.md), [17](17/de.md) |
| `webhook backend` | Backend, das audit-Ereignisse an HTTPS collector oder SIEM sendet. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [14](14/de.md) |
| `Workload` | Ausgeführte Anwendung und die sie steuernde Kubernetes-Ressource. | Ist nicht gleichbedeutend mit einem einzelnen container image. | [03](03/de.md), [09](09/de.md) |
| `Zero trust` | Ansatz ohne implizites Vertrauen in Netzwerk, identity oder Standort. | Bedeutet nicht, alle Interaktionen zu verbieten. | [02](02/de.md), [18](18/de.md) |
| `Vertrauensgrenze` | Übergangspunkt zwischen Beteiligten oder Kontexten mit unterschiedlichem Vertrauensniveau. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [15](15/de.md) |
| `Bedrohungsmodell` | Beschreibung der Assets, Beteiligten, Flüsse, Vertrauensgrenzen, Bedrohungen und controls eines Systems. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [15](15/de.md) |
| `Datenfluss` | Übertragung einer Anfrage, eines Zustands oder von Daten zwischen Komponenten. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [15](15/de.md) |
| `Dienstidentität (service identity)` | Konto einer Komponente, mit dem sie die Kubernetes API anspricht. | Den Begriff im Kontext präzisieren, nicht durch ein ähnliches Konzept ersetzen. | [07](07/de.md) |
## Lexikalische Fallen

- [Authentication](10/de.md) stellt die identity fest, [authorization](10/de.md) prüft die Berechtigung, und [admission control](11/de.md) bewertet die Zulässigkeit des Objekts nach den ersten beiden Phasen.
- [Audit logging](14/de.md) ist für API-Ereignisse zuständig, [runtime detection](18/de.md) für Prozessverhalten nach dem Start.
- [Encryption](12/de.md) benötigt einen Schlüssel zum Schutz der Daten, [Base64](12/de.md) ist nur reversible encoding.
- [Digest](06/de.md) legt den Inhalt fest, [signature](17/de.md) verknüpft Daten mit einem Schlüssel, [SBOM](17/de.md) listet Komponenten auf und [provenance](17/de.md) beschreibt die Herkunft.
- [Isolation](13/de.md) umfasst mehrere Grenzen, [segmentation](13/de.md) unterteilt sie in Zonen und Wege.
- [Control](05/de.md) verringert das Risiko, [framework](19/de.md) hilft bei Auswahl und Bewertung von controls.
- [Vulnerability](16/de.md) ist eine Schwäche, [threat](15/de.md) ein mögliches Szenario, [risk](19/de.md) die Bewertung von Wahrscheinlichkeit und Folgen.
- [Logging](18/de.md) speichert Ereignisse, [monitoring](18/de.md) verfolgt bekannte Kennzahlen, [observability](18/de.md) ermöglicht die Erklärung des Zustands anhand verschiedener Signale.
- [CIA triad](02/de.md) vereint [confidentiality](12/de.md), [integrity](19/de.md) und [availability](16/de.md).

[Inhaltsverzeichnis und Lernpfad](README_DE.md)
