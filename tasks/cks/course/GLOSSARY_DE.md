[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glossar zum CKS-Kurs

[← Kursinhalte](README_DE.md) · [Spickzettel](CHEATSHEET_DE.md) · [Fehlerbehebungsindex (RU)](TROUBLESHOOTING_INDEX_RU.md)

Alphabetisches Nachschlagewerk der CKS-Begriffe. Die Begriffe stehen auf Englisch, die Erläuterungen auf Deutsch. „Kapitel“ verlinkt die ausführlichen Erklärungen; „Lab/Aufgabe“ nennt bestätigte praktische Anwendungen und bleibt bei rein theoretischen Begriffen leer. Gebrauchsfertige Beispiele stehen im [Spickzettel](CHEATSHEET_DE.md).

| Begriff | Beschreibung | Kapitel | Lab/Aufgabe |
|--------|----------|-------|--------------|
| **4C** | Ein Modell der Cloud-, Cluster-, Container- und Codeebene zur Bewertung der Kubernetes-Sicherheit. | [02](02/de.md) | |
| **Admission control** | Eine API-Serveranforderungsverarbeitungsphase nach der Authentifizierung und Autorisierung, bevor das Objekt in etcd gespeichert wird. | [01](01/de.md), [20](20/de.md) | labs/107 (Aufgabe 6) |
| **Admission policy** | Eine Regel, die eine Kubernetes API-Anfrage zulässt, ändert oder ablehnt. | [01](01/de.md), [20](20/de.md) | labs/107 (Aufgabe 6), labs/108 |
| **Admission scan** | Eine Prüfung bei der Workload-Erstellung, die Scanergebnisse oder zugehörige Attestierungen verwendet. | [28](28/de.md) | |
| **Admission verification** | Obligatorische Überprüfung der Bildherkunft oder -signatur, bevor der API-Server einen Pod beibehält. | [26](26/de.md) | labs/111 (Aufgabe 9a) |
| **aescbc** | Ein Kubernetes API-Datenverschlüsselungsanbieter, der AES-CBC mit PKCS#7-Padding verwendet; Sein Schlüssel wird in einer geschützten Konfiguration gespeichert. Es verfügt über keine integrierte Chiffretext-Authentifizierung (kein HMAC/AEAD) und gilt im Vergleich zu `aesgcm` oder KMS v2 als schwache/ältere Option, da CBC anfällig für Padding-Oracle-Angriffe ist. | [21](21/de.md) | labs/109 (Aufgabe 2) |
| **aesgcm** | Ein AES-GCM AEAD-Anbieter für die API-Datenverschlüsselung; Schlüssel erfordern eine geplante Rotation. | [21](21/de.md) | |
| **allow-list / allowlist** | Eine explizite Liste zulässiger Aktionen, Quellen oder Ziele; Alles, was nicht aufgeführt ist, wird abgelehnt. | [12](12/de.md), [15](15/de.md), [17](17/de.md) | labs/112 (Aufgabe 9) |
| **anonymous authentication** | Zuordnen einer Anfrage ohne Anmeldeinformationen zu `system:anonymous`; normalerweise deaktiviert für API und kubelet. | [12](12/de.md) | labs/104 (Aufgabe 5) |
| **AppArmor** | Pfadbasierter Linux MAC, der Prozessvorgänge auf die von einem Profil zugelassenen beschränkt. | [03](03/de.md), [16](16/de.md) | labs/106 (Aufgaben 1-2) |
| **apparmor_parser** | Ein Dienstprogramm zum Überprüfen, Laden, Ersetzen und Entladen von AppArmor-Profilen. | [16](16/de.md) | labs/106 (Aufgabe 1) |
| **Artifact** | Ergebnis eines Builds, etwa ein OCI-Image, eine SBOM, ein Chart oder Provenance-Daten. | [25](25/de.md) | labs/111 |
| **Artifact repository** | Kontrollierter Artefaktspeicher: Registry, Paket-Repository oder Chart-Repository. | [25](25/de.md) | |
| **attack surface** | Alle Schnittstellen, Komponenten und Einstiegspunkte, über die ein Angriff oder eine Fehlkonfiguration möglich ist. | [02](02/de.md), [14](14/de.md), [24](24/de.md) | labs/105 |
| **Attribution** | Verknüpfen eines Ereignisses mit einem Prozess, Container, Pod, Identität, Knoten und Zeit. | [30](30/de.md) | labs/112 (Aufgabe 6) |
| **audience** | Der beabsichtigte Empfänger eines ServiceAccount-Tokens; Ein Dienst sollte nur Token mit seiner eigenen Zielgruppe akzeptieren. | [11](11/de.md) | labs/104 (Aufgabe 2) |
| **audit / enforce / warn** | Unabhängige PSA-Modi: Verstoß aufzeichnen, Pod ablehnen oder eine Warnung zurückgeben. | [19](19/de.md), [31](31/de.md) | labs/107 (Aufgaben 1, 3-4) |
| **audit backend** | Ein lokales Datei-Backend oder Webhook-Backend, das von einer Überwachungsrichtlinie ausgewählte Ereignisse empfängt. | [32](32/de.md) | labs/112 (Aufgaben 4, 8) |
| **audit event** | Ein API-Serverdatensatz einer Kubernetes API-Anfrage. | [32](32/de.md) | labs/112 (Aufgabe 4) |
| **audit policy** | Geordnete Regeln, die die Prüfebene und ausgeschlossene Ereignisphasen definieren. | [32](32/de.md) | labs/112 (Aufgabe 4) |
| **auditID** | Eine Kennung, die alle Prüfphasen einer einzelnen API-Anfrage verknüpft. | [32](32/de.md) | |
| **Base image** | Das Bild in einer `FROM`-Anweisung, das das anfängliche Dateisystem einer Build-Phase bereitstellt. | [24](24/de.md) | labs/111 (Aufgabe 3) |
| **Bound ServiceAccount token** | Ein kurzlebiger TokenRequest API-Token, der an einen ServiceAccount und einen Pod gebunden ist. | [11](11/de.md) | labs/104 (Aufgabe 2) |
| **BPF filter** | Ein Filterprogramm, das vom Kernel für einen Systemaufruf im Filtermodus seccomp ausgeführt wird. | [17](17/de.md) | labs/106 (Aufgaben 4-5) |
| **break-glass access** | Kontrollierter vorübergehender privilegierter Zugang für einen Notfall oder Vorfall. | [10](10/de.md), [15](15/de.md) | |
| **Build context** | Die an einen Builder gesendeten Dateien; `.dockerignore` reduziert diesen Satz. | [24](24/de.md) | |
| **CAP_SYS_ADMIN** | Eine übermäßig umfassende Linux-Funktion, die für normale Workloads gefährlich ist. | [03](03/de.md) | labs/106 (Aufgabe 5) |
| **capability** | Ein individuelles Linux-Privileg, das von Root-Berechtigungen bezogen wird; Eine sichere Baseline löscht `ALL` und stellt nur das wieder her, was benötigt wird. | [03](03/de.md), [18](18/de.md) | labs/107 (Aufgabe 2) |
| **CEL** | Common Expression Language, die vom integrierten ValidatingAdmissionPolicy verwendet wird. | [20](20/de.md) | labs/107 (Aufgabe 6), labs/108, labs/111 (Aufgabe 9a), labs/112 (Aufgabe 9) |
| **cgroup** | Eine Prozessgruppe mit Grenzwerten und Berücksichtigung von CPU, Speicher, PIDs und anderen Ressourcen. | [03](03/de.md) | |
| **CI gate** | Eine obligatorische Prüfung, die die nächste Pipeline-Stufe bei einem Exit-Code ungleich Null blockiert. | [27](27/de.md), [28](28/de.md) | |
| **Cilium** | Eine eBPF-basierte Kubernetes CNI und Sicherheitsplattform. | [06](06/de.md), [23](23/de.md) | labs/102, labs/110 (Aufgabe 4) |
| **CiliumClusterwideNetworkPolicy (CCNP)** | Eine Cluster-weite Cilium-Richtlinie; Sein breiter Anwendungsbereich erfordert eine besonders sorgfältige Einführung. | [06](06/de.md) | |
| **CiliumNetworkPolicy (CNP)** | Eine Cilium-Richtlinienressource mit Namensraum und L3/L4/L7-Regeln. | [06](06/de.md) | labs/102 (Aufgabe 3) |
| **cipher suite** | Eine Reihe von kryptografischen Algorithmen TLS, die mit dem Zertifikat und den Clients kompatibel sind. | [09](09/de.md) | labs/103 (Aufgabe 5) |
| **CIS Kubernetes Benchmark** | CIS Empfehlungen für die sichere Konfiguration von Kubernetes Komponenten und Knoten. | [01](01/de.md), [07](07/de.md) | labs/103 (Aufgaben 1, 7) |
| **CKS** | Zertifizierter Kubernetes-Sicherheitsspezialist, eine praktische Kubernetes-Sicherheitszertifizierung. | [01](01/de.md), [33](33/de.md) | |
| **Clair** | Ein dienstbasierter Schwachstellenscanner und Indexer für Container-Images. | [28](28/de.md) | |
| **complain** | Ein AppArmor-Modus, der Richtlinienverstöße protokolliert, ohne sie zu blockieren. | [16](16/de.md) | |
| **condition** | Ein boolescher Falco-Ausdruck über Ereignisfeldern, der bestimmt, ob eine Regel ausgelöst wird. | [29](29/de.md) | labs/112 (Aufgaben 3, 7, 9) |
| **Constraint** | Eine Gatekeeper-Vorlageninstanz mit Parametern, passendem Bereich und einer Aktion. | [20](20/de.md) | |
| **ConstraintTemplate** | Eine Rego-Vorlage und ein Parameterschema für einen neuen Gatekeeper-Einschränkungstyp. | [20](20/de.md) | |
| **container escape** | Entkommen der erwarteten Containerisolation, um auf Knoten oder andere Mandantenressourcen zuzugreifen. | [03](03/de.md) | |
| **Container runtime sandbox** | Eine Laufzeit, die eine Isolationsgrenze zwischen einer Arbeitslast und dem Hostkernel hinzufügt. | [22](22/de.md) | labs/110 (Aufgaben 1-3) |
| **Confidential computing / TEE** | Ein hardwareisolierter CPU-Bereich (Intel SGX, AMD SEV), der In-Memory-Daten sogar vor dem Hypervisor und dem Cloud-Anbieter schützt; Kubernetes macht es über einen speziellen `RuntimeClass` (vertrauliche Container) verfügbar, während die Hardware-Garantie außerhalb des Kubernetes API liegt. | [30](30/de.md) | |
| **context** | Eine benannte Kombination aus Cluster, Benutzer und Namespace in kubeconfig. | [33](33/de.md) | |
| **Correlation** | Verknüpfen von Ereignissen aus verschiedenen Quellen in einer einzigen Zeitleiste für Vorfälle. | [30](30/de.md) | labs/112 (Aufgabe 6) |
| **Cosign** | Ein Sigstore-Tool zum Signieren und Überprüfen von OCI-Artefakten. | [26](26/de.md) | labs/111 (Aufgaben 7, 9a, 9c) |
| **CRI** | Container-Laufzeitschnittstelle; `crictl` greift über einen CRI-Socket auf die Laufzeit zu. | [14](14/de.md), [30](30/de.md) | labs/112 (Aufgabe 6) |
| **CRI socket** | Der kubelet - Laufzeitkommunikationsendpunkt, z. B. `/run/containerd/containerd.sock`. | [14](14/de.md) | |
| **CVE** | Eine Kennung für eine öffentlich bekannte Schwachstelle. | [13](13/de.md), [28](28/de.md) | labs/111 (Aufgabe 1) |
| **CycloneDX** | Ein OWASP-Format für die Komponenteninventur und Sicherheitsanalyse in einem SBOM. | [25](25/de.md), [28](28/de.md) | labs/111 (Aufgabe 7) |
| **daemon.json** | Die Docker-Daemon-Konfigurationsdatei, normalerweise `/etc/docker/daemon.json`. | [14](14/de.md) | |
| **DaemonSet** | Eine Kubernetes-Workload, die einen Agenten Pod auf jedem ausgewählten Knoten verwaltet. | [29](29/de.md) | |
| **defense in depth** | Unabhängige Schutzschichten, die die Auswirkungen des Ausfalls einer Steuerung reduzieren. | [01](01/de.md), [02](02/de.md) | labs/104 (Aufgabe 3) |
| **deny-list** | Eine Richtlinie, deren Standardaktion Systemaufrufe zulässt, während bestimmte Systemaufrufe verweigert werden. | [17](17/de.md) | |
| **Digest** | Der unveränderliche SHA-256-Bezeichner eines bestimmten Bildmanifests oder Artefakts, im Gegensatz zu einem veränderlichen Tag. | [09](09/de.md), [24](24/de.md), [25](25/de.md), [26](26/de.md) | labs/111 (Aufgaben 3-5, 9c) |
| **distroless** | Ein minimales Laufzeitimage ohne Paketmanager und normalerweise ohne Shell. | [24](24/de.md), [31](31/de.md) | labs/111 (Aufgabe 7) |
| **docker group** | Eine Gruppe mit Docker-Socket-Zugriff, die als Root-Äquivalent behandelt werden sollte. | [14](14/de.md) | labs/105 (Aufgabe 6) |
| **Docker socket** | `/var/run/docker.sock`, der lokale Docker-Daemon API; Der Zugriff entspricht fast dem Root-Zugriff auf dem Host. | [14](14/de.md) | labs/105 (Aufgabe 6) |
| **drop-in** | Eine separate Konfigurationsdatei, die eine Basiskonfiguration erweitert, zum Beispiel systemd oder SSH. | [15](15/de.md) | |
| **eBPF** | Ein Linux-Kernelmechanismus für eingeschränkte Programme; Cilium verwendet es für den Datenpfad und Falco für Ereignisse. | [06](06/de.md), [29](29/de.md) | labs/112 (Aufgabe 1) |
| **egress policy** | Eine NetworkPolicy, die zulässige ausgehende Pod-Verbindungen angibt. | [04](04/de.md), [05](05/de.md) | labs/101 (Aufgaben 2, 4, 6) |
| **encryption at rest** | Verschlüsselung der in etcd, auf der Festplatte, in Snapshots und in Backups gespeicherten Daten. | [21](21/de.md) | labs/109 |
| **EncryptionConfiguration** | Die von kube-apiserver gelesene Verschlüsselungsanbieterkonfiguration. | [21](21/de.md) | labs/109 (Aufgabe 2) |
| **enforce** | Ein AppArmor- oder PSA-Modus, der tatsächlich Richtlinienverstöße blockiert. | [16](16/de.md), [19](19/de.md) | labs/106 (Aufgabe 1), labs/107 (Aufgabe 1) |
| **Entity** | Eine vordefinierte Cilium-Adressgruppe, z. B. `world`, `cluster` oder `host`. | [06](06/de.md) | |
| **envelope encryption** | Verschlüsseln eines Objekts mit einem DEK, das selbst durch ein externes KEK geschützt ist. | [21](21/de.md) | |
| **evidence** | Ein überprüfbares Artefakt, das ein Ergebnis bestätigt: ein API-Objekt, Protokoll, Profil, Scannerbericht oder Netzwerktest. | [33](33/de.md) | |
| **exemption** | Eine enge PSA-Umgehung für einen vertrauenswürdigen Namespace, Benutzernamen oder RuntimeClass; es gewährt keine RBAC-Berechtigungen. | [19](19/de.md) | |
| **Exfiltration** | Unbefugte Übertragung von Daten über eine Vertrauensgrenze hinweg. | [02](02/de.md), [30](30/de.md) | |
| **failurePolicy** | Die Serveraktion API, wenn ein Webhook/eine Richtlinie nicht verfügbar ist oder Fehler aufweist: normalerweise `Fail` oder `Ignore`. | [20](20/de.md) | labs/107 (Aufgabe 6) |
| **Falco** | Eine Laufzeit-Sicherheitsereignisregel-Engine, die Kernel-Ereignisse und Container/Kubernetes-Metadaten verwendet. | [29](29/de.md), [30](30/de.md) | labs/112 (Aufgaben 1-3, 6-7, 9) |
| **Falco rule override** | Eine lokale Änderung einer Falco-Regelbedingung oder Ausnahmen ohne Bearbeitung des Anbieterregelsatzes. | [29](29/de.md), [30](30/de.md) | labs/112 (Aufgabe 7) |
| **falco_rules.local.yaml** | Die bevorzugte Datei für lokale Außerkraftsetzungen und benutzerdefinierte Falco-Regeln. | [29](29/de.md), [30](30/de.md) | labs/112 (Aufgaben 3, 7, 9) |
| **False positive** | Eine Feststellung, die auf eine bestimmte Ressource nicht anwendbar ist; es erfordert eine enge, dokumentierte Ausnahme. | [27](27/de.md) | |
| **fixed version** | Die Komponentenversion, in der der Anbieter einen CVE behoben hat. | [13](13/de.md), [28](28/de.md) | |
| **footprint** | Die Pakete, Prozesse, Ports, Sockets und Konfigurationen, die die Angriffsfläche eines Knotens vergrößern. | [14](14/de.md) | labs/105 (Aufgaben 1-2) |
| **Gatekeeper** | Eine OPA-basierte Kubernetes-Richtlinien-Engine mit den Modellen `ConstraintTemplate` und `Constraint`. | [20](20/de.md), [26](26/de.md) | |
| **Grype** | Ein Anchore-Ökosystemscanner für Containerbilder und SBOMs. | [28](28/de.md) | |
| **gVisor** | Eine Sandbox-Laufzeit mit einem Userspace-Kernel; Die Laufzeit OCI und der Handler CRI werden häufig als `runsc` bezeichnet. | [03](03/de.md), [22](22/de.md) | labs/110 (Aufgaben 1-3) |
| **handler** | Der Laufzeitname in der CRI-Konfiguration; es muss mit `RuntimeClass.spec.handler` übereinstimmen. | [22](22/de.md) | labs/110 (Aufgabe 1) |
| **Hardware root of trust** | Eine kryptografische Vertrauenskette, die in einem physischen Gerät (TPM/vTPM) verwurzelt ist und zur Überprüfung der Integrität der Knoten-Bootkette verwendet wird (BIOS/UEFI → Bootloader → Kernel → Laufzeit); Die Verifizierung liegt außerhalb der Kubernetes API. | [30](30/de.md) | |
| **host endpoint** | Ein Knotennetzwerkendpunkt und nicht ein gewöhnlicher Pod in der CNI-Datenebene. | [05](05/de.md) | |
| **host firewall** | Verkehrsfilterung auf dem Knoten selbst, zum Beispiel mit `ufw`, `iptables` oder `nftables`. | [15](15/de.md) | labs/105 (Aufgabe 3) |
| **host namespace** | Ein Knoten-Namespace, der von einem Pod bis `hostPID`, `hostNetwork` oder `hostIPC` gemeinsam genutzt wird. | [18](18/de.md) | labs/101 (Aufgabe 7) |
| **Host PID** | Der Containerprozess PID im Namensraum des Knotens PID, benötigt für `/proc` und `strace`. | [30](30/de.md) | labs/112 (Aufgabe 6) |
| **HSM (Hardware Security Module)** | Ein physisches Speichergerät für kryptografische Schlüssel (z. B. für einen privaten CA-Schlüssel kube-apiserver oder einen KMS-Hauptschlüssel), das die Software-Extraktion des privaten Schlüssels verhindert. | [21](21/de.md), [30](30/de.md) | |
| **Hubble** | Beobachtbarkeit von Cilium Netzwerkflüssen. | [06](06/de.md) | labs/102 (Aufgabe 5) |
| **identity** | Eine vom Label abgeleitete Endpunktkennung Cilium; unterscheidet sich vom `identity`-Anbieter. | [06](06/de.md), [21](21/de.md) | labs/102 |
| **ImagePolicyWebhook** | Ein Zulassungs-Plugin, das Bildentscheidungen über `ImageReview` an ein externes Backend delegiert. | [26](26/de.md) | |
| **IMDS** | Instanzmetadaten Service, der Instanzmetadatenendpunkt des Cloud-Anbieters. | [05](05/de.md) | labs/101 (Aufgabe 5) |
| **IMDSv2** | Die AWS IMDS-Variante erfordert ein temporäres Token für Metadatenanfragen. | [05](05/de.md) | |
| **Immutable infrastructure** | Ein Ansatz, der ein Produktionsartefakt durch eine neue verifizierte Version ersetzt, anstatt es zur Laufzeit zu ändern. | [02](02/de.md), [31](31/de.md) | |
| **include** | Eine Anweisung, die eine externe Datei lädt: SSH `Include`, AppArmor `#include` oder `include:` in der Prüfkonfiguration. | [15](15/de.md), [16](16/de.md), [27](27/de.md) | labs/105 (Aufgabe 5) |
| **Ingress** | Datenverkehr, der in ein Pod oder das Kubernetes API-Objekt eintritt, leitet externes HTTP/HTTPS an ein Service weiter; Der Kontext bestimmt die Bedeutung. | [04](04/de.md), [08](08/de.md) | labs/101 (Aufgabe 2), labs/103 (Aufgabe 4) |
| **IngressClass** | Auswahl einer Ingress-Implementierung, z. B. NGINX Ingress Controller. | [08](08/de.md) | |
| **Inner packet** | Der ursprüngliche Pod-zu-Pod-Fluss ist vor der Verschlüsselung oder nach der Entschlüsselung sichtbar. | [23](23/de.md) | labs/110 (Aufgabe 5) |
| **ipBlock** | Eine Eingangs-/Ausgangsregel für ein CIDR oder eine einzelne IP; `except` schließt Adressen und Subnetze aus. | [04](04/de.md), [05](05/de.md) | labs/101 (Aufgabe 6) |
| **IPsec ESP** | Eine auf IP-Ebene geschützte Nutzlast, die Vertraulichkeit und Integrität zwischen Sicherheitszuordnungen gewährleistet. | [23](23/de.md) | |
| **Kata Containers** | Eine Laufzeit, die eine Pod-Sandbox in einer leichtgewichtigen VM mit einem Gastkernel startet. | [03](03/de.md), [22](22/de.md) | |
| **KEK/DEK** | Schlüsselverschlüsselungsschlüssel und Datenverschlüsselungsschlüssel bei der Umschlagverschlüsselung. | [21](21/de.md) | |
| **kernel module** | Ein ladbares Kernelmodul, ein Weg, Falco erfasst Ereignisse. | [29](29/de.md) | labs/105 (Aufgabe 7) |
| **Keyless signing** | Signieren mit einem kurzlebigen Zertifikat nach der OIDC-Authentifizierung anstelle eines dauerhaften lokalen Signaturschlüssels. | [26](26/de.md) | labs/111 (Aufgabe 7) |
| **Kill chain** | Die Abfolge der Angriffsphasen vom ersten Zugriff auf ein Ziel, beispielsweise die Exfiltration. | [02](02/de.md), [30](30/de.md) | labs/112 (Aufgabe 6) |
| **kube-bench** | Ein Tool zur Konfigurationsprüfung, das CIS Kubernetes Benchmark-Profile verwendet. | [07](07/de.md), [33](33/de.md) | labs/103 (Aufgaben 1, 7) |
| **kube-linter** | Ein Kubernetes YAML und Helm Karten-Linter mit Best-Practice-Prüfungen. | [27](27/de.md) | labs/111 (Aufgabe 2) |
| **kubelet** | Der Knotenagent Kubernetes; Sein gesicherter Endpunkt überwacht normalerweise den Port `10250`. | [05](05/de.md), [07](07/de.md) | labs/103 (Aufgabe 2), labs/105 (Aufgabe 8) |
| **kubesec** | Ein Kubernetes-Manifestscanner, der eine Sicherheitsbewertung und Kontrollen meldet. | [27](27/de.md) | labs/111 (Aufgaben 2, 4) |
| **Kyverno** | Eine Kubernetes-native Richtlinien-Engine mit YAML-Regeln: `validate`, `mutate`, `generate` und `verifyImages`. | [20](20/de.md), [26](26/de.md), [31](31/de.md) | labs/108, labs/111 (Aufgabe 9a), labs/112 (Aufgabe 9) |
| **L3/L4** | Die Netzwerkschicht und das Transportprotokoll/Port in einer Cilium-Richtlinie. | [06](06/de.md) | labs/102 (Aufgabe 2) |
| **L7** | Die Protokollschicht, z. B. HTTP Methode/Pfad oder DNS (Cilium Kafka-Filterung ist veraltet). | [06](06/de.md) | labs/102 (Aufgabe 3) |
| **lateral movement** | Ein Angreifer, der von einem kompromittierten Workload auf andere Systeme, Daten oder Identitäten übergeht. | [02](02/de.md), [04](04/de.md) | |
| **least privilege** | Einer Identität nur die minimal erforderlichen Berechtigungen, Umfang und Dauer gewähren. | [02](02/de.md), [10](10/de.md), [15](15/de.md) | labs/104 (Aufgabe 1) |
| **legacy annotation** | Eine veraltete Betaanmerkung AppArmor, die zur Migration gelesen, aber nicht für die neue Pods verwendet wird. | [16](16/de.md) | |
| **level** | Die Datendetails in einem Prüfereignis: `None`, `Metadata`, `Request` oder `RequestResponse`. | [32](32/de.md) | labs/112 (Aufgabe 4) |
| **Linkerd identity** | Eine Linkerd mTLS-Identität, normalerweise abgeleitet von einer ServiceAccount. | [23](23/de.md) | |
| **live-restore** | Ein Docker-Modus, der Container beim Neustart des Daemons am Laufen hält. | [14](14/de.md) | |
| **Localhost** | Der Kubernetes-Typ für ein AppArmor/seccomp-Profil, das auf einem Knoten vorinstalliert ist. | [16](16/de.md), [17](17/de.md) | labs/106 (Aufgaben 2, 4) |
| **localhostProfile** | Ein JSON-Profilpfad relativ zum kubelet seccomp-Stamm. | [17](17/de.md) | labs/106 (Aufgabe 4) |
| **MAC** | Obligatorische Zugriffskontrolle, eine Zugriffsrichtlinie, die zusätzlich zu UID/GID und Modusbits durchgesetzt wird. | [03](03/de.md), [16](16/de.md) | |
| **macro** | Ein wiederverwendbares benanntes Fragment einer Falco-Bedingung. | [29](29/de.md) | labs/112 (Aufgabe 7) |
| **mTLS** | TLS, in dem sowohl Client als auch Server Zertifikate präsentieren. | [23](23/de.md) | labs/110 (Aufgabe 6) |
| **Multi-stage build** | Eine Docker-Datei mit separaten Build- und Laufzeitphasen, die durch `COPY --from=` verbunden sind. | [24](24/de.md) | |
| **Mutating admission webhook** | Ein Webhook, der ein Objekt vor der Validierung ergänzt oder ändert. | [20](20/de.md) | labs/108 (Aufgabe 5) |
| **namespace** | Eine isolierte Ansicht einer Kernel-Ressource für eine Prozessgruppe; unterscheidet sich von einem Kubernetes-Namespace. | [03](03/de.md) | labs/106 (Aufgabe 6) |
| **namespaceSelector** | Auswählen von Kubernetes-Namespaces nach Bezeichnungen für eine namespaceübergreifende NetworkPolicy-Regel. | [04](04/de.md) | labs/101 (Aufgabe 6) |
| **network namespace** | Isolierung der Schnittstellen, Routen und des Netzwerkstapels eines Prozesses. | [03](03/de.md) | |
| **no_new_privs** | Ein Kernel-Flag, das zusätzliche Berechtigungen durch `exec` verhindert; aktiviert durch `allowPrivilegeEscalation: false`. | [18](18/de.md) | |
| **Node authorizer** | Ein Autorisierer für kubelet-Identitätsaktionen für die benötigten Node- und Pod-Objekte. | [12](12/de.md) | |
| **Node encryption** | Schutz des Verkehrs zwischen Knoten; entspricht nicht der Identität einer bestimmten Arbeitslast. | [23](23/de.md) | labs/110 (Aufgaben 4-5) |
| **NodeRestriction** | Ein Zulassungs-Plugin, das kubelet weiter auf seinen Knoten und den ihm zugewiesenen Pods beschränkt. | [12](12/de.md) | |
| **Notary Project / Notation** | Ein OCI-Signatur-Ökosystem mit X.509-Vertrauensrichtlinie; Die Durchsetzung von Kubernetes erfordert eine Zulassungsintegration. | [26](26/de.md) | |
| **OCI** | Ein offener Standard für Container-Image- und Artefaktformate, der von Registrierungsstellen und Signaturtools verwendet wird. | [25](25/de.md), [26](26/de.md) | labs/111 |
| **OPA** | Open Policy Agent, eine Richtlinien-Engine, die deklarative Rego-Regeln ausführt. | [20](20/de.md), [27](27/de.md) | |
| **Outer packet** | Ein verschlüsseltes Paket zwischen Knoten-IPs im physischen Netzwerk. | [23](23/de.md) | labs/110 (Aufgabe 5) |
| **partial credit** | Anerkennung für eigenständige, korrekt erledigte Teile einer Aufgabe. | [33](33/de.md) | |
| **PeerAuthentication** | Eine Istio eingehende mTLS-Richtlinie; `STRICT` lehnt Klartext ab. | [23](23/de.md) | labs/110 (Aufgabe 6) |
| **Performance-based** | Ein Prüfungsformat, das Ergebnisse in einer Arbeitsumgebung erfordert, anstatt Testantworten auszuwählen. | [01](01/de.md), [33](33/de.md) | |
| **PID namespace** | Isolierung der Prozessliste und des Prozesses PIDs. | [03](03/de.md) | |
| **Pod UID** | Das unveränderliche UID einer bestimmten Pod-Instanz, zuverlässiger als sein Name für die Korrelation. | [30](30/de.md) | |
| **podSelector** | Auswahl von Pods anhand von Bezeichnungen innerhalb des NetworkPolicy-Namespace. | [04](04/de.md) | labs/101 (Aufgaben 2, 6) |
| **PolicyReport** | Bericht über die Ergebnisse von Richtlinienprüfungen, sofern die Policy-Engine diese API installiert. | [31](31/de.md) | |
| **private key** | Der geheime Teil eines asymmetrischen Schlüsselpaares; Wird gemäß dem Protokoll/Tool für die TLS-Identität (Kapitel 07-08) oder einem Cosign-Signaturschlüssel (Labor 111) verwendet. Für beide ist ein eingeschränkter Zugriff erforderlich, normalerweise `0600`. | [07](07/de.md), [08](08/de.md) | labs/111 (Aufgabe 9a) |
| **profiling** | Endpunkte zur Prozessleistungsdiagnose; mit `--profiling=false` deaktivieren, sofern nicht erforderlich. | [07](07/de.md), [12](12/de.md) | labs/103 (Aufgabe 3) |
| **projected volume** | Ein Volume, das Token, ConfigMaps, abwärts gerichtete API und andere Quellen in Pod-Dateien kombiniert. | [11](11/de.md) | labs/104 (Aufgabe 2) |
| **provenance** | Metadaten über die Quelle, Eingaben, den Builder und den Build-Prozess (Bescheinigung) eines Artefakts. Der überprüfbare Ursprung ist von der einfachen Signaturüberprüfung getrennt: `cosign sign`/`verify` beweist eine Signatur/Identität, nicht den gesamten Build-Verlauf; Sigstore stellt `cosign attest`/`verify-attestation` für die Herkunft bereit. | [09](09/de.md), [25](25/de.md), [26](26/de.md) | |
| **provider** | Ein Mechanismus zum Verschlüsseln und Entschlüsseln bestimmter API-Ressourcen. | [21](21/de.md) | labs/109 (Aufgabe 2) |
| **PSA** | Pod Security Admission, der integrierte validierende Zulassungscontroller für PSS. | [19](19/de.md), [31](31/de.md) | labs/107 (Aufgaben 1, 3-4) |
| **PSP** | PodSecurityPolicy, der Vorgänger PSA, entfernt in Kubernetes 1.25. | [19](19/de.md) | |
| **PSS** | Pod-Sicherheitsstandards: die vordefinierten Profile `privileged`, `baseline` und `restricted`. | [19](19/de.md) | labs/107 |
| **purl** | Paket-URL, eine Paketkennung einschließlich seines Ökosystems und seiner Version. | [25](25/de.md) | |
| **re-encryption** | Umschreiben alter API-Objekte durch einen neuen Verschlüsselungsanbieter oder Schlüssel. | [21](21/de.md) | labs/109 (Aufgabe 2) |
| **read-only kubelet port** | Ein veralteter, nicht authentifizierter kubelet-Port, der mit `0` deaktiviert werden muss. | [07](07/de.md), [09](09/de.md), [12](12/de.md) | labs/103 (Aufgabe 2) |
| **read-only root filesystem** | Ein Modus, der Änderungen der Bildebene verhindert; Zulässige Schreibvorgänge gehen auf Volumes. | [18](18/de.md), [31](31/de.md), [33](33/de.md) | labs/107 (Aufgabe 5), labs/112 (Aufgabe 5) |
| **Registry allowlist** | Eine Richtlinie, die Bilder nur von explizit aufgeführten Registrierungs-/Repository-Identitäten zulässt. Spezifizieren Sie den exakten Vergleich mit dem Präfix-Matching: Labor 112 zeigt, dass prefix/`startsWith` Lookalikes zulassen kann (`library/busybox-evil` für `library/busybox`), daher wird das exakte Matching verwendet. | [26](26/de.md) | labs/112 (Aufgabe 9) |
| **release cadence** | Die Häufigkeit von Neben- und Patch-Releases. | [13](13/de.md) | |
| **remediation** | Beseitigen eines Risikos durch Aktualisieren eines Artefakts, einer Abhängigkeit oder eines Basisimages und Überprüfen des Ergebnisses. | [28](28/de.md) | |
| **Rendered manifest** | Der letzte YAML nach `helm template` oder `kustomize build`, der vor der Bereitstellung analysiert werden muss. | [27](27/de.md) | |
| **RoleBinding** | Eine Namespace-Bindung einer Rolle oder ClusterRole an ein Subjekt, z. B. ServiceAccount. | [10](10/de.md), [11](11/de.md) | labs/104 (Aufgabe 1) |
| **Rootless Podman** | Ein Podman-Modus, in dem ein normaler Benutzer die Erstellung/Ausführung durchführt und nicht ein Root-Daemon. | [24](24/de.md) | |
| **rotation** | Umbenennen und Löschen alter Protokolldateien nach Größe, Anzahl oder Alter. | [21](21/de.md), [32](32/de.md) | labs/112 (Aufgabe 4) |
| **rule** | Ein benannter Falco-Detektor mit einer Bedingung, einem Ausgang und einer Priorität. | [29](29/de.md) | labs/112 (Aufgaben 3, 7, 9) |
| **runtime detection** | Erkennen von verdächtigem Verhalten eines laufenden Prozesses mithilfe von Systemaufrufen/eBPF und Laufzeitmetadaten. | [01](01/de.md), [29](29/de.md), [30](30/de.md) | labs/112 |
| **Runtime mutation** | Ändern des Dateisystems oder der Konfiguration eines laufenden Containers. | [31](31/de.md) | labs/112 (Aufgabe 5) |
| **runtime overhead** | Zusätzlicher CPU/Speicher behoben, der vom Scheduler für Pods eines ausgewählten RuntimeClass berücksichtigt wurde. | [22](22/de.md) | |
| **RuntimeClass** | Eine Cluster-bezogene Kubernetes-Ressource, die einen CRI-Handler und optionale Overhead-/Planungseinschränkungen auswählt. | [19](19/de.md), [22](22/de.md) | labs/110 (Aufgabe 1) |
| **RuntimeDefault** | Ein Profil, das von der ausgewählten Containerlaufzeit für AppArmor oder seccomp bereitgestellt wird. | [16](16/de.md), [17](17/de.md), [18](18/de.md) | labs/106 (Aufgabe 3), labs/107 (Aufgabe 2) |
| **sandbox pool** | Dedizierte Knoten mit vorbereitetem Runtime, Label, Taint und ausreichender Kapazität. | [22](22/de.md) | labs/110 |
| **sandboxed runtime** | Eine Laufzeit mit einer stärkeren Isolationsgrenze, z. B. gVisor oder Kata Containers. | [03](03/de.md), [22](22/de.md) | labs/110 (Aufgaben 1-3) |
| **SCMP_ACT_ERRNO** | Eine seccomp-Aktion, die einen Fehler für einen Systemaufruf zurückgibt, ohne ihn auszuführen. | [17](17/de.md) | labs/106 (Aufgabe 4) |
| **SCMP_ACT_LOG** | Eine seccomp-Aktion, die einen Systemaufruf ermöglicht und die Kernel-Protokollierung anfordert. | [17](17/de.md) | |
| **seccomp** | Ein Linux-Mechanismus, der die Systemaufrufe eines Prozesses filtert. | [03](03/de.md), [17](17/de.md), [18](18/de.md) | labs/106 (Aufgaben 3-5, 7) |
| **SECCOMP audit record** | Ein Kernel-/Prüfdatensatz eines seccomp-bezogenen Ereignisses. | [17](17/de.md) | |
| **Secret mount** | Vorübergehendes Mounten eines Berechtigungsnachweises für einen Build-Befehl, ohne ihn in die letzte Ebene zu schreiben. | [24](24/de.md) | |
| **security advisory** | Die Hauptmitteilung eines Anbieters zu betroffenen Versionen, Exploit-Bedingungen, Schadensbegrenzung und einer korrigierten Version. | [13](13/de.md) | |
| **SecurityContext** | Kubernetes-Felder, die die Identität und Einschränkungen eines Prozesses definieren, oder Pod. | [18](18/de.md), [33](33/de.md) | labs/106, labs/107 (Aufgabe 2) |
| **self-signed certificate** | Ein Zertifikat, das mit einem eigenen Schlüssel und nicht mit einer vertrauenswürdigen Zertifizierungsstelle signiert ist. Für Tests geeignet, aber standardmäßig nicht vertrauenswürdig. | [08](08/de.md) | labs/103 (Aufgabe 4) |
| **SELinux** | Labelbasierter MAC mit Typerzwingung, der normale Zugriffsberechtigungen ergänzt. | [03](03/de.md) | |
| **ServiceAccount (SA)** | Eine Namensraumidentität für Pods und Prozesse im Kubernetes API. | [11](11/de.md), [23](23/de.md) | labs/104 (Aufgaben 2-3) |
| **severity** | Die Schweregradklasse eines Befundes: `LOW`, `MEDIUM`, `HIGH` oder `CRITICAL`. | [28](28/de.md) | labs/111 (Aufgabe 1) |
| **SHA-256 checksum** | Ein 256-Bit-Dateiauszug, der die Gleichheit Byte für Byte mit einem veröffentlichten Artefakt überprüft. | [09](09/de.md) | labs/103 (Aufgabe 6) |
| **shim** | Ein containerd-Prozess oder eine Binärdatei, die containerd mit einer bestimmten Laufzeit verbindet. | [22](22/de.md) | labs/110 (Aufgabe 1) |
| **Sidecar** | Ein Proxy oder ein anderer Hilfscontainer neben einer Anwendung, der Datenverkehr abfängt oder bereitstellt. | [23](23/de.md) | labs/110 (Aufgabe 6) |
| **SLSA** | Ein Reifegradmodell für Sicherheitspraktiken in der Software-Lieferkette. | [25](25/de.md) | |
| **Software supply chain** | Der Pfad von Quelle, Abhängigkeiten, Build-Systemen und Artefakten zu einer laufenden Arbeitslast. | [25](25/de.md) | labs/111 |
| **SPDX** | Ein offener Standard, der Pakete, Lizenzen und ihre Beziehungen in einem SBOM beschreibt. | [25](25/de.md), [28](28/de.md) | labs/111 (Aufgabe 6) |
| **SSRF** | Serverseitige Anforderungsfälschung, eine Schwachstelle, die dazu führt, dass ein Server eine vom Angreifer ausgewählte Adresse anfordert. | [05](05/de.md) | labs/101 (Aufgabe 5) |
| **stage** | Die Phase der Audit-Ereigniserstellung: `RequestReceived`, `ResponseStarted`, `ResponseComplete` oder `Panic`. | [32](32/de.md) | labs/112 (Aufgabe 4) |
| **static analysis** | Überprüfen von Docker-Dateien, Manifesten und Richtlinien, ohne eine Arbeitslast auszuführen. | [27](27/de.md) | labs/111 (Aufgabe 2) |
| **static Pod** | Ein Pod aus einem knotenlokalen Manifest, verwaltet von kubelet ohne Planung über Kubernetes API. | [07](07/de.md), [09](09/de.md), [12](12/de.md), [32](32/de.md), [33](33/de.md) | labs/103, labs/104 (Aufgabe 5), labs/112 (Aufgabe 4) |
| **sudoers** | Eine Richtlinie von Befehlen, die ein Benutzer als ein anderer Benutzer ausführen kann; Bearbeiten mit `visudo`. | [15](15/de.md) | |
| **SUID/SGID** | Spezielle Dateibits, die ein Programm mit dem effektiven UID des Besitzers oder dem effektiven GID der Gruppe ausführen. | [15](15/de.md) | |
| **support window** | Die unterstützten Versionszweige erhalten Sicherheitspatches. | [13](13/de.md) | |
| **Syft** | Ein Tool, das SBOMs aus Bildern, Dateisystemen oder Archiven generiert. | [25](25/de.md) | labs/111 (Aufgabe 7) |
| **syscall** | Ein Systemaufruf, über den ein Prozess eine Kerneloperation anfordert. | [03](03/de.md), [17](17/de.md), [29](29/de.md) | labs/106 (Aufgaben 4-5) |
| **system:unauthenticated** | Die Gruppe des anonymen Subjekts; Bindungen erfordern die gleiche Überprüfung wie die für `system:anonymous`. | [12](12/de.md) | |
| **systemd unit** | Eine Definition eines Dienstes, Sockets, Timers oder einer anderen von systemd verwalteten Entität. | [14](14/de.md) | labs/105 (Aufgabe 1) |
| **TLS minimum version** | Die Mindestversion TLS, die ein Server mit einem Client aushandelt. | [09](09/de.md) | labs/103 (Aufgabe 5) |
| **TLS Secret** | Ein `kubernetes.io/tls` Secret, der `tls.crt` und `tls.key` enthält. | [08](08/de.md) | labs/103 (Aufgabe 4) |
| **TLS termination** | Abschluss des TLS-Handshakes und Entschlüsseln des Datenverkehrs an einem Eingangscontroller. | [08](08/de.md) | labs/103 (Aufgabe 4) |
| **toFQDNs** | Eine Cilium-Ausgangsregel mit DNS-Namen und beobachteten DNS-Antworten. | [06](06/de.md) | labs/102 (Aufgabe 4) |
| **TokenRequest API** | Ein API, der kurzlebige ServiceAccount-Token ausgibt. | [11](11/de.md) | labs/104 (Aufgabe 2) |
| **Transparent encryption** | Datenpfadverschlüsselung ohne Anwendung, Service oder URL-Änderungen; Cilium wendet es auf Knoten an. | [23](23/de.md) | labs/110 (Aufgabe 4) |
| **triage** | Schnelle Klassifizierung eines Befundes oder Ereignisses nach Quelle, Risiko, Umfang und nächster Aktion. | [33](33/de.md) | |
| **Trivy** | Ein Scanner für Bilder, SBOMs, Dateisysteme, Geheimnisse und Konfiguration/IaC. | [28](28/de.md), [33](33/de.md) | labs/111 (Aufgaben 1, 5, 8) |
| **Unconfined** | Kein seccomp-Filter für einen Container; eine vorübergehende Ausnahme, keine Grundlinie. | [17](17/de.md) | labs/106 (Aufgabe 5) |
| **Unix socket** | Ein lokaler IPC-Endpunkt für das Dateisystem; Seine Berechtigungen bestimmen, wer auf einen Daemon API zugreifen kann. | [14](14/de.md) | labs/105 (Aufgabe 6) |
| **userns-remap** | Eine Docker-Daemon-Funktion (`dockerd --userns-remap`), die den Container UID/GID auf dem Host innerhalb von Docker selbst neu zuordnet; getrennt von Kubernetes Pod Benutzernamensräumen (`hostUsers: false`), getestet in Labor 106. | [14](14/de.md) | |
| **Validating admission webhook** | Ein Webhook, der ein Objekt zulässt oder ablehnt. | [20](20/de.md) | |
| **ValidatingAdmissionPolicy** | Integrierte CEL-Validierung im API-Server ohne externen Webhook; durch eine Bindung aufgebracht. | [20](20/de.md) | labs/107 (Aufgabe 6) |
| **version skew** | Der zulässige Versionsunterschied zwischen Kubernetes-Komponenten; kubelet darf nicht neuer sein als der API-Server. | [13](13/de.md) | |
| **webhook collector** | Ein HTTPS-Endpunkt, der Prüfereignisse zur zentralen Speicherung und Analyse empfängt. | [32](32/de.md) | labs/112 (Aufgabe 8) |
| **WireGuard** | Ein VPN-Protokoll mit Peer-Schlüsselpaaren; Der öffentliche Schlüssel identifiziert den zugelassenen Peer. | [23](23/de.md) | labs/110 (Aufgaben 4-5) |
| **Workload identity** | Eine kryptografisch überprüfbare Workload-Identität, normalerweise verknüpft mit ServiceAccount/Namespace in einem Mesh. | [23](23/de.md) | labs/110 (Aufgabe 6) |
| **Writable layer** | Eine veränderbare Ebene, die von der Laufzeit über schreibgeschützte Bildebenen hinzugefügt wird. | [31](31/de.md) | |
| **Zero trust** | Implizites Vertrauen basierend auf Netzwerk, Namespace oder Standort ablehnen. | [02](02/de.md) | |
