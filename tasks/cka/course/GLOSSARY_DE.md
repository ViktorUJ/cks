[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glossar des Kurses CKA + CKAD

[← Kursinhalt](README_DE.md) · [CKA](CKA_DE.md) · [CKAD](CKAD_DE.md)

Ein einheitliches alphabetisches Nachschlagewerk der Begriffe des Kurses. Der Begriff -
auf Englisch (wie in Kubernetes), die Beschreibung - auf Deutsch, in der Spalte "Kapitel" -
wo der Begriff behandelt wird (mit Links zu den Kapiteln). Suche auf der Seite - Ctrl+F.

| Begriff | Beschreibung | Kapitel |
|--------|----------|-------|
| **A record / AAAA record** | DNS-Eintrag Name → IPv4 / Name → IPv6. | [0.2](00-2-dns/de.md) |
| **accessModes** | Zugriffsmodi: RWO, ROX, RWX, RWOP. | [25](25/de.md) |
| **activeDeadlineSeconds** | maximale Laufzeit der Aufgabe. | [10](10/de.md) |
| **Adapter** | Container, der die Ausgabe der Anwendung in das benötigte Format umwandelt. | [22](22/de.md) |
| **admin.conf** | kubeconfig des Administrators nach init. | [35](35/de.md) |
| **Admission control** | Prüfung/Änderung der Anfrage nach authn+authz. | [21](21/de.md) |
| **aggregation layer** | Erweiterung der API über einen eigenen extension-apiserver (z. B. metrics-server). | [41](41/de.md) |
| **APIService** | Objekt, das eine aggregierte API registriert (`metrics.k8s.io` u. a.). | [41](41/de.md) |
| **allow logic** | Policies erlauben nur; ein Verbot als eigene Regel gibt es nicht. | [34](34/de.md) |
| **allowPrivilegeEscalation** | Erlauben/Verbieten der Rechteerhöhung. | [20](20/de.md) |
| **allowVolumeExpansion** | ob das Volume erweitert werden darf. | [25](25/de.md), [26](26/de.md) |
| **Ambassador** | Vermittler-Container für ausgehende Verbindungen der Anwendung. | [22](22/de.md) |
| **Annotation** | Schlüssel-Wert-Paar für zusätzliche Daten, nicht für die Auswahl. | [06](06/de.md) |
| **API deprecation** | Erklärung einer API-Version als veraltet mit anschließender Entfernung. | [29](29/de.md) |
| **apiVersion** | Version der API-Gruppe des Objekts (alpha/beta/stabil). | [29](29/de.md) |
| **Application container** | Hauptcontainer des Pods mit der Nutzlast. | [04](04/de.md) |
| **apply** | Objekt nach Manifest erstellen oder aktualisieren (idempotent, 3-way merge). | [03](03/de.md) |
| **args** | überschreibt CMD des Images (Argumente). | [17](17/de.md) |
| **Authn** | Feststellung, wer der Absender der Anfrage ist. | [21](21/de.md) |
| **Authz** | Prüfung, dass der Absender berechtigt ist (RBAC). | [21](21/de.md) |
| **automountServiceAccountToken** | ob das Token des SA in den Pod gemountet wird. | [21](21/de.md) |
| **averageUtilization** | Ziel-Durchschnittsauslastung der Ressource in Prozent. | [16](16/de.md) |
| **backendRefs** | Zielservices (mit Gewichten für canary). | [33](33/de.md) |
| **backoffLimit** | Anzahl der Wiederholungen bei Fehlschlag. | [10](10/de.md) |
| **Bare pod** | direkt erstellter Pod, ohne Controller; wird nicht wiederhergestellt. | [04](04/de.md) |
| **base** | gemeinsame Ausgangsmanifeste. | [43](43/de.md) |
| **Base image** | Basisimage (`FROM`), mit dem der Build beginnt. | [23](23/de.md) |
| **base64** | Kodierung der Werte eines Secret; KEINE Verschlüsselung. | [19](19/de.md) |
| **behavior** | Feinjustierung der Geschwindigkeit von scale up/down. | [16](16/de.md) |
| **Binding** | Verbinden eines passenden PV mit einem PVC (eins zu eins). | [25](25/de.md) |
| **Blue** | aktuelle laufende Version; **Green** - die neue, die zur Umschaltung vorbereitet wird. | [09](09/de.md) |
| **Blue/Green** | zwei vollständige Umgebungen (die aktuelle und die neue) mit sofortigem Umschalten des Traffics. | [09](09/de.md) |
| **bootstrap token** | temporäres Token für den join von Nodes (lebt ~24 Stunden). | [35](35/de.md) |
| **bridge (cni0)** | Software-Switch der Node, der die Pods auf ihr verbindet. | [0.7](00-7-netns/de.md), [30](30/de.md) |
| **CA** | Zertifizierungsstelle; Vertrauensanker, unterschreibt Zertifikate. | [0.3](00-3-tls/de.md), [39](39/de.md) |
| **Calico / Cilium / Flannel** | populäre CNI-Plugins. | [30](30/de.md), [40](40/de.md) |
| **Canary** | Ausrollen einer neuen Version für einen kleinen Teil des Traffics mit allmählicher Steigerung. | [09](09/de.md) |
| **CIDR** | Notation `Adresse/N`, wobei `N` - die Anzahl der Bits für das Netz; größeres N - kleineres Netz. | [0.1](00-1-net/de.md), [30](30/de.md) |
| **CNAME** | DNS-Eintrag: Alias, der auf einen anderen Namen zeigt. | [0.2](00-2-dns/de.md) |
| **capabilities** | einzelne Rechte aus der "Allmacht von root" (drop/add). | [20](20/de.md) |
| **cgroups** | Kernel-Controller, die die Ressourcen eines Containers begrenzen (cpu, memory, pids, io); Grundlage von requests/limits. | [0.4](00-4-containers/de.md), [14](14/de.md) |
| **cgroup v1 / v2** | alte (Hierarchie pro Controller) / moderne (einheitliche Hierarchie) Version von cgroups; v2 standardmäßig ab Fedora 31, Ubuntu 22.04, Debian 11, RHEL 9 (K8s cgroup v2 GA ab 1.25). | [0.4](00-4-containers/de.md) |
| **cgroup driver** | wer die cgroups konfiguriert (`systemd` oder `cgroupfs`); kubelet und runtime müssen übereinstimmen (`SystemdCgroup=true`). | [0.4](00-4-containers/de.md), [35](35/de.md) |
| **cert-manager** | Operator für die automatische Ausstellung und Erneuerung von Zertifikaten. | [32](32/de.md) |
| **cert-manager / Prometheus Operator** | populäre Operatoren. | [41](41/de.md) |
| **change-cause** | Annotation mit dem Grund der Änderung für die Historie. | [08](08/de.md) |
| **Chart** | Paket: Manifest-Templates + values + Metadaten. | [42](42/de.md) |
| **CKA** | Certified Kubernetes Administrator, Prüfung zur Administration des Clusters. | [01](01/de.md) |
| **CKAD** | Certified Kubernetes Application Developer, Prüfung zum Betrieb von Anwendungen. | [01](01/de.md) |
| **Client certificate** | Ausweis des Benutzers; CN → Name, O → Gruppe. | [39](39/de.md) |
| **Cluster Autoscaler** | ändert die Anzahl der Nodes im Cluster. | [16](16/de.md) |
| **Karpenter** | wählt und startet Nodes des passenden Typs für Pending-Pods (flexibler als Cluster Autoscaler). | [16](16/de.md) |
| **Cluster API** | deklarative Verwaltung des Lebenszyklus von Clustern. | [35](35/de.md), [35B](35-3-design/de.md) |
| **managed / self-managed** | die control plane betreibt der Provider (EKS/GKE/AKS) / Sie selbst. | [35B](35-3-design/de.md) |
| **node pool** | Gruppe gleichartiger Nodes (Profil, Zone, spot/on-demand). | [35B](35-3-design/de.md) |
| **IaC** | Infrastruktur als Code (Terraform/OpenTofu, Ansible). | [35B](35-3-design/de.md) |
| **GitOps** | git als Quelle der Wahrheit für den Zustand des Clusters (Argo CD/Flux). | [35B](35-3-design/de.md) |
| **cluster-admin / admin / edit / view** | eingebaute ClusterRole. | [38](38/de.md) |
| **Cluster-scoped object** | auf Cluster-Ebene (Node, PV, StorageClass, ClusterRole). | [06](06/de.md) |
| **ClusterIP** | Standardtyp: interne virtuelle IP, nur im Cluster erreichbar. | [07](07/de.md) |
| **ClusterRole** | Berechtigungen für den Cluster / cluster-scoped Ressourcen / zur Wiederverwendung. | [38](38/de.md) |
| **ClusterRoleBinding** | Bindung einer Rolle an ein Subjekt für den gesamten Cluster. | [38](38/de.md) |
| **CNCF** | Cloud Native Computing Foundation, die Organisation hinter Kubernetes und diesen Zertifizierungen. | [01](01/de.md) |
| **CNI** | Schnittstelle und Plugin für das Pod-Netz (Calico, Cilium u. a.). | [02](02/de.md), [30](30/de.md), [40](40/de.md) |
| **command** | überschreibt ENTRYPOINT des Images (was gestartet wird). | [17](17/de.md) |
| **completions** | wie viele erfolgreiche Abschlüsse nötig sind. | [10](10/de.md) |
| **componentstatuses** | Überblicksstatus der Komponenten (veraltet). | [45](45/de.md) |
| **concurrencyPolicy** | Policy bei Überlappung von CronJob-Starts (Allow/Forbid/Replace). | [10](10/de.md) |
| **Conditions** | Zustände der Node (Ready, MemoryPressure, DiskPressure, PIDPressure). | [45](45/de.md) |
| **ConfigMap** | Objekt mit nicht geheimer Konfiguration (Schlüssel-Werte oder Dateien). | [18](18/de.md) |
| **configMapGenerator / secretGenerator** | Generierung von ConfigMap/Secret (mit Hash im Namen). | [43](43/de.md) |
| **configMapKeyRef** | einen Schlüssel einer ConfigMap in eine Umgebungsvariable übernehmen. | [18](18/de.md) |
| **container runtime** | Laufzeitumgebung für Container (containerd), kommuniziert über CRI. | [02](02/de.md) |
| **containerd / CRI-O** | Implementierungen von CRI (Runtimes). | [40](40/de.md) |
| **context** | Bündel aus cluster + user + namespace. | [39](39/de.md) |
| **Context (kubeconfig)** | Bündel aus Cluster + Benutzer + Namespace; wird mit `use-context` gewechselt. | [03](03/de.md) |
| **Control plane** | Steuerungsschicht des Clusters (das Gehirn): apiserver, etcd, scheduler, controller-manager. | [02](02/de.md) |
| **Controller** | Programm mit Abgleichschleife (bringt die Realität zur spec). | [41](41/de.md) |
| **cordon** | Node als unschedulable markieren (neue Pods kommen nicht hierher). | [36](36/de.md) |
| **cordon / drain** | Node als unschedulable markieren / Pods von ihr verdrängen (Kapitel 36). | [13](13/de.md), [36](36/de.md) |
| **CoreDNS** | DNS-Server des Clusters (Deployment in kube-system hinter dem Service kube-dns). | [31](31/de.md) |
| **Corefile** | Konfiguration von CoreDNS (in der ConfigMap `coredns`). | [31](31/de.md) |
| **CrashLoopBackOff** | Container stürzt zyklisch ab und wird neu gestartet. | [04](04/de.md), [44](44/de.md) |
| **containerd / CRI-O** | high-level container runtime, mit denen kubelet arbeitet. | [0.4](00-4-containers/de.md), [40](40/de.md) |
| **CRD** | Definition eines neuen Objekttyps in der API. | [41](41/de.md) |
| **CreateContainerConfigError** | die ConfigMap/das Secret, auf die der Pod verweist, fehlt. | [44](44/de.md) |
| **CRI** | Schnittstelle kubelet ↔ Laufzeitumgebung. | [0.4](00-4-containers/de.md), [40](40/de.md) |
| **crictl** | CLI für die Arbeit mit Containern über CRI auf der Node. | [40](40/de.md), [45](45/de.md) |
| **CronJob** | erstellt Jobs nach einem cron-Zeitplan. | [10](10/de.md) |
| **CSI** | Standard zum Anbinden von Storage an Kubernetes. | [26](26/de.md), [40](40/de.md) |
| **CSI driver** | Implementierung von CSI (provisioner in der StorageClass). | [40](40/de.md) |
| **CSR** | Anfrage zur Unterschrift eines Zertifikats über die API des Clusters. | [39](39/de.md) |
| **certSANs** | zusätzliche Namen/Adressen im Zertifikat des apiserver (z. B. DNS des Load Balancers für HA). | [35](35/de.md) |
| **certificatesDir** | Verzeichnis der PKI des Clusters (standardmäßig `/etc/kubernetes/pki`). | [35](35/de.md) |
| **Custom Resource** | Instanz eines durch CRD definierten Typs. | [41](41/de.md) |
| **custom-columns** | eigene Ausgabetabelle. | [47](47/de.md) |
| **DaemonSet** | Controller, der auf jeder (passenden) Node genau einen Pod hält. | [11](11/de.md) |
| **data / binaryData** | Text- / Binärdaten einer ConfigMap. | [18](18/de.md) |
| **Declarative approach** | Verwaltung über Manifeste (`kubectl apply -f`). | [01](01/de.md), [03](03/de.md) |
| **default / kube-system / kube-public / kube-node-lease** | System-Namespaces. | [06](06/de.md) |
| **default deny** | Policy, die alles in einer Richtung blockiert (keine erlaubenden Regeln). | [34](34/de.md) |
| **default SA** | Standard-ServiceAccount in jedem namespace. | [21](21/de.md) |
| **Default StorageClass** | Standardklasse für PVC ohne explizite Klasse. | [26](26/de.md) |
| **default-deny + DNS** | Falle: eine egress-Policy schneidet das Resolving ab (Kapitel 34). | [34](34/de.md), [46](46/de.md) |
| **Deployment** | Controller über ReplicaSet: Replikas + Updates + Rollbacks + Historie. | [05](05/de.md) |
| **Desired state** | das, was Sie im Manifest beschrieben haben. | [01](01/de.md) |
| **Destructive operations** | etcd restore, drain: besonders sorgfältig prüfen. | [48](48/de.md) |
| **distroless / scratch** | minimale Basisimages ohne Überflüssiges / leeres Image. | [23](23/de.md) |
| **dnsConfig** | punktuelle DNS-Einstellung des Pods (u. a. `options ndots`), funktioniert bei jeder dnsPolicy. | [31](31/de.md) |
| **dnsPolicy** | wie der Pod DNS erhält (ClusterFirst u. a.). | [31](31/de.md) |
| **Dockerfile** | Anweisungen für den Build des Images. | [0.4](00-4-containers/de.md), [23](23/de.md) |
| **Downward API** | Zugriff des Pods auf Informationen über sich selbst (`fieldRef`, `resourceFieldRef`). | [17](17/de.md) |
| **drain** | Pods von der Node verdrängen (gracefully), auf andere verlagern. | [36](36/de.md) |
| **Dynamic provisioning** | automatisches Erstellen eines PV für eine PVC-Anfrage. | [26](26/de.md) |
| **eBPF** | Technologie im Linux-Kernel, auf der Cilium aufbaut. | [30](30/de.md) |
| **EmptyDir** | Volume des Pods zum Dateiaustausch zwischen Containern. | [22](22/de.md), [24](24/de.md) |
| **encryption at rest** | Verschlüsselung von Secret in etcd. | [19](19/de.md) |
| **External CA mode** | in `pki/` liegt nur `ca.crt` ohne Schlüssel: kubeadm erstellt den CSR, Unterschrift und Erneuerung liegen bei Ihnen. | [35](35/de.md) |
| **endpoint 2379** | Client-Port von etcd. | [37](37/de.md) |
| **Endpoints** | Liste der Adressen der Pods hinter einem Service; leer = nicht verbunden (Kapitel 7). | [07](07/de.md), [46](46/de.md) |
| **Endpoints / EndpointSlice** | Liste der IPs der bereiten Pods hinter einem Service. | [07](07/de.md) |
| **ENTRYPOINT/CMD** | was und mit welchen Argumenten gestartet wird, festgelegt im Image. | [17](17/de.md) |
| **env** | Umgebungsvariablen des Containers. | [17](17/de.md) |
| **envFrom + configMapRef** | alle Schlüssel einer ConfigMap als Umgebungsvariablen. | [18](18/de.md) |
| **Ephemeral volume** | lebt genauso lange wie der Pod (übersteht den Neustart des Containers, aber nicht das Löschen des Pods). | [24](24/de.md) |
| **ephemeral container** | temporärer Container zum Debuggen eines laufenden Pods (`kubectl debug`). | [04](04/de.md), [29](29/de.md) |
| **etcd** | verteilter key-value-Speicher für den gesamten Zustand des Clusters. | [02](02/de.md), [37](37/de.md) |
| **etcdctl** | CLI für die Arbeit mit etcd; für Snapshots wird `ETCDCTL_API=3` benötigt. | [37](37/de.md) |
| **Events** | Chronologie der Aktionen mit einem Objekt in der Ausgabe von `describe`/`get events`. | [29](29/de.md), [44](44/de.md) |
| **eviction** | Verdrängen von Pods durch kubelet bei Ressourcenmangel der Node. | [14](14/de.md) |
| **exec** | einen Befehl/eine Shell im Container ausführen. | [29](29/de.md) |
| **exec form** | Befehl als Liste, ohne Shell (richtig für Signale). | [17](17/de.md) |
| **expandtab** | Einstellung von vim (Leerzeichen statt Tabs) für YAML. | [0.8](00-8-vim/de.md), [47](47/de.md) |
| **External Secrets / Vault / SOPS / Sealed Secrets** | Werkzeuge für echten Schutz von Secrets. | [19](19/de.md) |
| **ExternalName** | DNS-Alias (CNAME) auf eine externe Domain. | [07](07/de.md) |
| **FailedScheduling** | Event des Schedulers bei Pending. | [44](44/de.md) |
| **failureThreshold / successThreshold** | Anzahl der Fehlschläge/Erfolge für den Zustandswechsel. | [27](27/de.md) |
| **filters** | Transformationen (rewrite, redirect, Header). | [33](33/de.md) |
| **Flat network** | jeder Pod sieht jeden anderen direkt per IP, ohne NAT. | [30](30/de.md) |
| **Fluent Bit/Fluentd** | Agenten zum Sammeln von Logs (üblicherweise DaemonSet). | [28](28/de.md) |
| **Service FQDN** | `<service>.<namespace>.svc.cluster.local`. | [31](31/de.md) |
| **fsGroup** | Eigentümergruppe der gemounteten Volumes (Ebene des Pods). | [20](20/de.md) |
| **Gateway** | Eintrittspunkt: Listener (Ports, Protokolle, TLS); gehört dem Cluster-Operator. | [33](33/de.md) |
| **Gateway API** | moderner Standard für das Routing von Traffic in Kubernetes. | [33](33/de.md) |
| **FQDN** | vollständiger Domainname mit allen Ebenen (z. B. `backend.default.svc.cluster.local`). | [0.2](00-2-dns/de.md), [31](31/de.md) |
| **GatewayClass** | Implementierung (Controller) der Gateway API, Analogon zur StorageClass. | [33](33/de.md) |
| **globalDefault** | PriorityClass, die auf Pods ohne explizite Priorität angewendet wird. | [15](15/de.md) |
| **HA (high availability)** | Ausfallsicherheit der control plane: mehrere Nodes, der Ausfall einer legt die Steuerung nicht lahm. | [35A](35-2-ha/de.md) |
| **--control-plane-endpoint** | stabile Adresse der control plane (Load Balancer) für HA; wird bei `kubeadm init` gesetzt. | [35A](35-2-ha/de.md), [35](35/de.md) |
| **stacked / external etcd** | etcd auf den control-plane-Nodes selbst (Standard) / auf separaten Nodes. | [35A](35-2-ha/de.md) |
| **quorum (etcd)** | Mehrheit der etcd-Knoten für das Schreiben (raft); daher eine ungerade Anzahl (3/5). | [35A](35-2-ha/de.md), [37](37/de.md) |
| **leader election** | Wahl der aktiven Instanz von scheduler/controller-manager im HA (die übrigen in Reserve). | [35A](35-2-ha/de.md) |
| **SPOF** | einzelner Ausfallpunkt; HA beseitigt ihn. | [35A](35-2-ha/de.md) |
| **--upload-certs / certificate-key** | Übertragung der Zertifikate der control plane beim join von HA-Nodes. | [35A](35-2-ha/de.md) |
| **Handshake (TLS)** | Prozedur zum Aufbau einer TLS-Verbindung (Prüfung des Zertifikats, Aushandeln des Schlüssels). | [0.3](00-3-tls/de.md) |
| **Headless Service** | `clusterIP: None`, DNS liefert die IPs der Pods direkt. | [07](07/de.md), [11](11/de.md) |
| **Helm** | Paketmanager für Kubernetes. | [42](42/de.md) |
| **helm install/upgrade/rollback/uninstall** | Lebenszyklus eines Release. | [42](42/de.md) |
| **helm template** | lokales Rendern des Chart zu Manifesten (zur Prüfung). | [42](42/de.md) |
| **hostPath** | Mounten eines Verzeichnisses der Node in den Pod (riskant, für Systemaufgaben). | [24](24/de.md) |
| **HPA** | ändert die Anzahl der Replikas anhand von Metriken. | [16](16/de.md) |
| **httpGet / tcpSocket / exec / grpc** | Arten der Prüfung. | [27](27/de.md) |
| **HTTPRoute** | Regeln des HTTP-Routings auf Services; gehört dem Entwickler. | [33](33/de.md) |
| **IgnoredDuringExecution** | die Regel wird beim Scheduling geprüft, verdrängt aber keinen bereits laufenden Pod. | [12](12/de.md) |
| **Image** | verpacktes Dateisystem der Anwendung + Abhängigkeiten + Startmetadaten. | [23](23/de.md) |
| **ImagePullBackOff/ErrImagePull** | das Image kann nicht heruntergeladen werden. | [44](44/de.md) |
| **imagePullPolicy** | wann das Image geholt wird (IfNotPresent/Always/Never). | [23](23/de.md) |
| **imagePullSecrets** | Secret für den Zugriff auf eine private Image-Registry. | [19](19/de.md) |
| **immutable** | unveränderliche ConfigMap (nur Neuerstellung). | [18](18/de.md) |
| **Imperative approach** | Verwaltung von Objekten über Befehle (`kubectl run`, `create`). | [01](01/de.md), [03](03/de.md) |
| **Ingress controller** | Anwendung, die die Ingress-Regeln ausführt (nginx, Traefik, ALB). | [32](32/de.md) |
| **Ingress resource** | Deklaration der Regeln des L7-Routings (Hosts, Pfade, TLS). | [32](32/de.md) |
| **ingress2gateway** | Werkzeug zur automatischen Konvertierung von Ingress in Ressourcen der Gateway API (liefert einen Entwurf, Review nötig). | [33](33/de.md) |
| **IngressClass** | welcher Controller diesen Ingress bedient (`ingressClassName`). | [32](32/de.md) |
| **Init container** | Container, der vor den Hauptcontainern läuft und beendet werden muss. | [22](22/de.md) |
| **initialDelaySeconds** | Verzögerung vor der ersten Prüfung. | [27](27/de.md) |
| **IP address** | numerische Adresse eines Geräts im Netz (IPv4 - 32 Bit, vier Oktette). | [0.1](00-1-net/de.md) |
| **ipBlock** | Erlaubnis nach IP-Bereich (externer Traffic). | [34](34/de.md) |
| **iptables / IPVS modes** | Arten der Umsetzung von Services; IPVS skaliert besser. | [31](31/de.md) |
| **Job** | Controller für eine einmalige Aufgabe; achtet auf den erfolgreichen Abschluss der Pods. | [10](10/de.md) |
| **journalctl -u kubelet** | Logs von kubelet, die wichtigste Quelle für die Ursachen von NotReady. | [45](45/de.md) |
| **JSONPath** | Sprache zur Auswahl von Feldern aus der Antwort der API (`-o jsonpath=...`). | [03](03/de.md), [47](47/de.md) |
| **KEDA** | event-driven Autoscaling nach externen Events (auch auf null). | [16](16/de.md) |
| **kube-apiserver** | einheitlicher Eintrittspunkt, über den alle Anfragen laufen; der einzige, der in etcd schreibt. | [02](02/de.md) |
| **list-watch** | Beobachtung von Änderungen: LIST + Stream WATCH (ohne Polling der API). | [02](02/de.md) |
| **informer** | lokaler Objekt-Cache eines Controllers, synchronisiert über watch. | [02](02/de.md) |
| **resourceVersion** | Version des Objekts; Fortsetzung von watch und Grundlage der optimistischen Sperre. | [02](02/de.md) |
| **optimistic concurrency** | ein Schreibvorgang mit veralteter Version wird abgelehnt (409 Conflict) → Wiederholung. | [02](02/de.md) |
| **kube-controller-manager** | Sammlung von Controllern (Abgleichschleifen). | [02](02/de.md) |
| **kube-proxy** | setzt Services über iptables/IPVS auf der Node um. | [02](02/de.md), [07](07/de.md), [31](31/de.md) |
| **kube-scheduler** | weist Pods den Nodes zu. | [02](02/de.md), [12](12/de.md) |
| **kubeadm** | offizielles Werkzeug zur Installation des Clusters (init/join/upgrade). | [35](35/de.md) |
| **kubeadm certs renew** | Zertifikate des Clusters erneuern. | [39](39/de.md) |
| **kubeadm init** | Initialisierung der control plane. | [35](35/de.md) |
| **kubeadm join** | Aufnahme einer Node in den Cluster. | [35](35/de.md) |
| **kubeadm reset** | Aufräumen des kubeadm-Zustands auf der Node. | [36](36/de.md) |
| **kubeadm upgrade plan / apply / node** | Plan / Anwendung (erste CP) / Update der Node. | [36](36/de.md) |
| **kubeconfig** | Datei (`~/.kube/config`) mit Clustern, Benutzern und Kontexten. | [03](03/de.md), [39](39/de.md) |
| **kubectl** | wichtigstes Kommandozeilenwerkzeug für die Arbeit mit dem Cluster. | [01](01/de.md), [03](03/de.md) |
| **kubectl apply -k** | ein Kustomize-Verzeichnis anwenden. | [43](43/de.md) |
| **kubectl certificate approve** | einen CSR genehmigen (von der CA unterschreiben lassen). | [39](39/de.md) |
| **kubectl debug** | einen Debug-Container einsetzen / einen Pod kopieren / eine Node debuggen. | [29](29/de.md) |
| **kubectl explain** | eingebaute Dokumentation zu den Feldern der Objekte. | [03](03/de.md) |
| **kubectl kustomize / kustomize build** | Rendern ohne Anwenden. | [43](43/de.md) |
| **kubectl logs** | Ansehen der Logs eines Pods/Containers. | [28](28/de.md) |
| **kubectl top** | den Ressourcenverbrauch anzeigen (metrics-server nötig). | [28](28/de.md) |
| **kubelet** | Agent der Node, startet und überwacht die Pods; Systemdienst. | [02](02/de.md) |
| **Kubernetes** | System zur Orchestrierung von Containern: bringt den realen Zustand des Clusters zum gewünschten. | [01](01/de.md) |
| **kustomization.yaml** | Datei, die Ressourcen und Transformationen beschreibt. | [43](43/de.md) |
| **Kustomize** | Werkzeug zur Anpassung von Manifesten durch Überlagern von Patches, ohne Templates. | [43](43/de.md) |
| **Label** | Schlüssel-Wert-Paar zur Auswahl und Verknüpfung von Objekten. | [06](06/de.md) |
| **Labels** | Schlüssel-Wert-Paare an Objekten, über die Selektoren arbeiten. | [05](05/de.md) |
| **Layer** | Satz von Änderungen am Dateisystem; Layer werden gecacht und wiederverwendet. | [23](23/de.md) |
| **Layered troubleshooting** | Analyse des Netzes von unten nach oben: CNI → DNS → Endpoints → Policy → Eingang. | [46](46/de.md) |
| **LimitRange** | Standardwerte und Grenzen der Ressourcen für ein einzelnes Objekt im namespace. | [14](14/de.md) |
| **limits** | Obergrenze des Verbrauchs; wird zur Laufzeit geprüft. | [14](14/de.md) |
| **liveness** | ob der Container lebt; Fehlschlag → Neustart. | [27](27/de.md) |
| **LoadBalancer** | externer Cloud-Balancer vor dem Service. | [07](07/de.md) |
| **localhost** | gemeinsames Netz des Pods, über das die Container einander sehen. | [22](22/de.md) |
| **Manifest** | YAML-Datei mit der Beschreibung eines Kubernetes-Objekts. | [01](01/de.md) |
| **matchLabels / matchExpressions** | zwei Formen des Selektors. | [06](06/de.md) |
| **maxSurge** | wie viele Pods über den gewünschten Stand hinaus während des Rollouts erstellt werden dürfen. | [08](08/de.md) |
| **maxUnavailable** | wie viele Pods während des Rollouts zeitweise fehlen dürfen. | [08](08/de.md) |
| **medium: Memory** | Ablage von emptyDir im RAM (tmpfs). | [24](24/de.md) |
| **metrics-server** | sammelt CPU/Speicher der Pods; nötig für HPA und `kubectl top`. | [16](16/de.md), [28](28/de.md) |
| **Mi/Gi vs M/G** | binäre (1024) gegen dezimale (1000) Einheiten des Speichers. | [14](14/de.md) |
| **Microsegmentation** | feine Abgrenzung des Traffics zwischen Pods/Services. | [34](34/de.md) |
| **milli-CPU** | tausendster Teil eines Kerns (`500m` = halber Kern). | [14](14/de.md) |
| **minReplicas/maxReplicas** | untere und obere Grenze der Anzahl der Replikas. | [16](16/de.md) |
| **Mirror Pod** | Abbild eines static pod in der API; sichtbar, aber nicht über kubectl löschbar. | [15](15/de.md) |
| **Mock exam** | Probelauf unter Zeitdruck mit automatischer Prüfung. | [48](48/de.md) |
| **mTLS** | gegenseitiges TLS: beide Seiten legen Zertifikate vor. | [0.3](00-3-tls/de.md), [39](39/de.md) |
| **Multi-stage build** | Build in einem Image, im Ergebnis - nur das Resultat. | [23](23/de.md) |
| **Mutating / Validating admission** | ändernde / prüfende Controller. | [21](21/de.md) |
| **Namespace** | Abschnitt des Clusters; Objektnamen sind darin eindeutig. | [06](06/de.md) |
| **Namespaced object** | lebt in einem namespace (Pod, Deployment, Service, ...). | [06](06/de.md) |
| **namespaceSelector** | Auswahl von Pods nach den Labels des namespace. | [34](34/de.md) |
| **NAT** | Austausch der Adressen am Gateway, damit privater Traffic nach außen gelangt. | [0.1](00-1-net/de.md) |
| **netshoot** | Image mit Netzwerkwerkzeugen zum Debuggen. | [46](46/de.md) |
| **NetworkPolicy** | Regeln, welcher Pod mit welchem kommunizieren darf (Firewall auf Pod-Ebene). | [34](34/de.md) |
| **Node** | Maschine (VM oder physisch) im Bestand des Clusters. | [02](02/de.md) |
| **Node-level work** | SSH + systemctl/journalctl/crictl/etcdctl (Besonderheit von CKA). | [48](48/de.md) |
| **nodeAffinity** | flexible Auswahl der Nodes; `required` (hart) und `preferred` (weich). | [12](12/de.md) |
| **NodeLocal DNSCache** | lokaler DNS-Cache auf jeder Node. | [31](31/de.md) |
| **nodeName** | harte Zuweisung der Node unter Umgehung des Schedulers. | [12](12/de.md) |
| **NodePort** | öffnet einen Port (30000-32767) auf allen Nodes für externen Zugriff. | [07](07/de.md) |
| **nodeSelector** | einfache harte Auswahl der Node nach ihren Labels. | [12](12/de.md) |
| **NoExecute** | nicht schedulen und bereits laufende Pods ohne toleration verdrängen. | [13](13/de.md) |
| **NoSchedule** | keine neuen Pods ohne toleration schedulen (die alten bleiben). | [13](13/de.md) |
| **NotReady** | Status der Node, wenn kubelet keine Bereitschaft meldet. | [45](45/de.md) |
| **ndots** | Schwelle der Punkte im Namen: darunter wird der Name zuerst mit den search-Suffixen probiert (Standard `ndots:5` → zusätzliche Anfragen für externe Namen). | [31](31/de.md) |
| **namespaces (Linux)** | Isolation dessen, was ein Prozess sieht: PID, NET, MNT, UTS, IPC, USER (nicht mit dem namespace von Kubernetes verwechseln). | [0.4](00-4-containers/de.md) |
| **network namespace** | isolierter Netzwerkstack eines Prozesses/Containers (eigene Interfaces, IPs, Routen). | [0.7](00-7-netns/de.md), [40](40/de.md) |
| **nslookup/dig** | Prüfung des DNS-Resolvings von innerhalb eines Pods. | [46](46/de.md) |
| **OCI** | offener Standard für das Format von Images und Containern (Kompatibilität Docker ↔ containerd). | [0.4](00-4-containers/de.md) |
| **OLM** | Operator Lifecycle Manager, Mechanismus zur Installation/Aktualisierung von Operatoren. | [41](41/de.md) |
| **OOMKilled** | Container wurde wegen Überschreitung des Speicherlimits beendet. | [04](04/de.md), [14](14/de.md), [44](44/de.md) |
| **Operator** | Controller + Domänenwissen über die Verwaltung einer Anwendung. | [41](41/de.md) |
| **operator Equal/Exists** | Übereinstimmung nach Wert / nur nach Schlüssel. | [13](13/de.md) |
| **Orchestration** | automatische Verwaltung des Lebenszyklus von Containern (Start, Neustart, Skalierung, Platzierung). | [01](01/de.md) |
| **overlay** | Satz von Änderungen über dem base für eine konkrete Umgebung. | [43](43/de.md) |
| **Overlay network** | Netz mit Kapselung der Pakete zwischen den Nodes (VXLAN). | [30](30/de.md) |
| **parallelism** | wie viele Pods ein Job gleichzeitig startet. | [10](10/de.md) |
| **parentRefs** | Bindung einer Route an ein Gateway. | [33](33/de.md) |
| **Partial credit** | teilweise erledigte Arbeit wird angerechnet. | [47](47/de.md) |
| **patches** | punktuelle Änderungen an Feldern (strategic merge / JSON6902). | [43](43/de.md) |
| **pathType** | Art des Abgleichs des Pfads: Prefix / Exact / ImplementationSpecific. | [32](32/de.md) |
| **pause container** | Hilfscontainer, der den network namespace des Pods hält. | [40](40/de.md) |
| **Pending** | der Pod ist nicht gescheduled (Ressourcen/taints/affinity/PVC). | [44](44/de.md) |
| **periodSeconds** | Intervall der Prüfungen. | [27](27/de.md) |
| **PersistentVolume** | Objekt, das ein "Stück Storage" im Cluster darstellt. | [25](25/de.md) |
| **PersistentVolumeClaim** | Anforderung der Anwendung an Storage (Größe, Modus). | [25](25/de.md) |
| **Phase** | große Phase im Leben eines Pods: Pending, Running, Succeeded, Failed, Unknown. | [04](04/de.md) |
| **cluster PKI** | Satz von CAs und Zertifikaten in `/etc/kubernetes/pki/`, wird bei `kubeadm init` erstellt. | [35](35/de.md), [39](39/de.md) |
| **front-proxy-ca** | CA für den aggregation layer (Erweiterungen des API-Servers). | [35](35/de.md) |
| **sa.key / sa.pub** | Schlüsselpaar zum Unterschreiben der Tokens von ServiceAccount. | [35](35/de.md), [21](21/de.md) |
| **pluto / kubent** | Werkzeuge zum Auffinden veralteter APIs in Manifesten/im Cluster. | [29](29/de.md), [36](36/de.md) |
| **kubepug (kubectl deprecations)** | Prüfung der APIs gegen eine Zielversion von K8s (Cluster und Dateien). | [29](29/de.md) |
| **kubeconform** | Validator für Manifeste anhand der Schemata einer Zielversion von K8s (CI). | [29](29/de.md) |
| **Popeye** | Sanitizer des Clusters; findet unter anderem veraltete APIs. | [29](29/de.md) |
| **Pod** | kleinste Starteinheit: Hülle um einen/mehrere Container mit gemeinsamem Netz und Volumes. | [04](04/de.md) |
| **Pod CIDR / Service CIDR** | Adressbereiche der Pods / der virtuellen IPs der Services; dürfen sich nicht überschneiden. | [0.1](00-1-net/de.md), [30](30/de.md) |
| **Pod connectivity** | ob die Pods per IP kommunizieren können (Ebene des CNI, Kapitel 30). | [30](30/de.md), [46](46/de.md) |
| **Pod Security Admission** | eingebaute Policy der Stufen privileged/baseline/restricted. | [20](20/de.md) |
| **podAffinity** | den Pod neben Pods mit bestimmten Labels platzieren. | [12](12/de.md) |
| **podAntiAffinity** | den Pod weiter weg von Pods mit bestimmten Labels platzieren. | [12](12/de.md) |
| **PodDisruptionBudget** | Minimum verfügbarer Pods bei freiwilliger Verdrängung. | [36](36/de.md) |
| **podSelector** | auf welche Pods die Policy angewendet wird / wen sie erlaubt. | [34](34/de.md) |
| **policyTypes** | Richtungen: Ingress (eingehend) und/oder Egress (ausgehend). | [34](34/de.md) |
| **port / targetPort / nodePort** | Port des Service / Port an den Pods / Port an den Nodes. | [07](07/de.md) |
| **port-forward** | Weiterleitung eines Ports eines Pods/Service auf die lokale Maschine. | [29](29/de.md), [46](46/de.md) |
| **Preemption** | Löschen von Pods niedrigerer Priorität, um einen Pod höherer Priorität zu platzieren. | [15](15/de.md) |
| **PreferNoSchedule** | Scheduling hierher weich vermeiden. | [13](13/de.md) |
| **pressure-taints** | automatische taints bei Ressourcenmangel der Node (Kapitel 13). | [13](13/de.md), [45](45/de.md) |
| **PriorityClass** | Objekt mit numerischer Priorität der Pods. | [15](15/de.md) |
| **privileged** | privilegierter Container (≈ root auf der Node); gefährlich. | [20](20/de.md) |
| **Probe** | Gesundheitsprüfung des Containers, ausgeführt von kubelet. | [27](27/de.md) |
| **Progressive delivery** | automatisierte canary/blue-green anhand von Metriken (Argo Rollouts, Flagger). | [09](09/de.md) |
| **projected** | Volume, das mehrere Quellen zusammenfasst (secret/configMap/downwardAPI). | [24](24/de.md) |
| **Prometheus / Grafana** | Sammeln/Speichern von Metriken und Visualisierung (echtes Monitoring). | [28](28/de.md) |
| **provisioner** | CSI-Treiber, der die realen Volumes erstellt. | [26](26/de.md) |
| **PTR** | umgekehrter DNS-Eintrag: IP → Name. | [0.2](00-2-dns/de.md) |
| **QoS class** | Guaranteed / Burstable / BestEffort; Reihenfolge der Verdrängung bei Speichermangel. | [14](14/de.md) |
| **Quorum** | Mehrheit der etcd-Knoten, die für den Betrieb nötig ist (HA). | [37](37/de.md) |
| **raft** | Konsensprotokoll, über das sich die Knoten von etcd verständigen. | [02](02/de.md) |
| **RBAC** | Zugriffssteuerung auf Basis von Rollen (Kapitel 38). | [21](21/de.md), [38](38/de.md) |
| **readiness** | ob bereit für Traffic; Fehlschlag → Entfernen aus den Endpoints (ohne Neustart). | [27](27/de.md) |
| **readOnlyRootFilesystem** | Root-Dateisystem nur lesbar. | [20](20/de.md) |
| **ReadWriteMany** | Lesen und Schreiben von vielen Nodes (ein Netzwerk-Dateisystem nötig). | [25](25/de.md) |
| **ReadWriteOnce** | Lesen und Schreiben von einer Node (nicht von einem Pod!). | [25](25/de.md) |
| **reclaimPolicy** | Schicksal des PV nach dem Löschen des PVC: Retain / Delete. | [25](25/de.md) |
| **Reconciliation loop** | fortlaufender Zyklus, in dem die Controller die Differenz zwischen gewünschtem und realem Zustand beseitigen. | [01](01/de.md) |
| **Recreate** | Strategie "alle beenden, dann erstellen"; mit Ausfallzeit. | [08](08/de.md) |
| **Registry** | Speicher für Images (standardmäßig Docker Hub); ein privater braucht imagePullSecret. | [0.4](00-4-containers/de.md), [23](23/de.md) |
| **Release** | installierte Instanz eines chart (mit Historie der Revisionen). | [42](42/de.md) |
| **replicas** | gewünschte Anzahl der Pods. | [05](05/de.md) |
| **ReplicaSet** | Controller, der die vorgegebene Anzahl von Pods nach Selektor hält. | [05](05/de.md) |
| **ReplicationController** | veralteter Vorgänger des ReplicaSet. | [05](05/de.md) |
| **Repository** | Speicher für Charts. | [42](42/de.md) |
| **requests** | garantiertes Minimum an Ressourcen; wird beim Scheduling verwendet. | [14](14/de.md) |
| **required vs preferred** | strenge (verpflichtende) gegen weiche (nach Möglichkeit) Platzierungsregel bei affinity. | [12](12/de.md) |
| **ResourceQuota** | Gesamtlimit für Ressourcen und Anzahl der Objekte pro namespace. | [14](14/de.md) |
| **restartPolicy** | Neustart-Policy der Container: Always, OnFailure, Never. | [04](04/de.md) |
| **Return to context** | nach der Arbeit auf der Node auf der Ausgangsmaschine weiterarbeiten. | [48](48/de.md) |
| **Revision** | festgehaltene Version des Templates eines Deployment in der Historie. | [08](08/de.md) |
| **revisionHistoryLimit** | wie viele alte ReplicaSet für den Rollback behalten werden. | [08](08/de.md) |
| **Role** | Berechtigungen in einem namespace. | [38](38/de.md) |
| **RoleBinding** | Bindung einer Rolle an ein Subjekt im namespace. | [38](38/de.md) |
| **roleRef** | auf welche Rolle das binding verweist. | [38](38/de.md) |
| **rollback** | Rückkehr zur vorherigen Revision (`rollout undo`). | [08](08/de.md) |
| **RollingUpdate** | Strategie des allmählichen Austauschs der Pods ohne Ausfallzeit (Standard). | [08](08/de.md) |
| **rollout** | Prozess des Ausrollens einer neuen Version eines Deployment. | [08](08/de.md) |
| **Routed network** | Netz, das die Routen zu den Pods direkt kennt (BGP). | [30](30/de.md) |
| **rules** | was und worüber erlaubt ist. | [38](38/de.md) |
| **runAsNonRoot** | Verbot des Starts als root. | [20](20/de.md) |
| **runAsUser / runAsGroup** | UID/GID des Prozesses im Container. | [20](20/de.md) |
| **runc** | low-level Werkzeug zum Starten von Containern über den Kernel. | [0.4](00-4-containers/de.md), [40](40/de.md) |
| **Scheduler Profiles** | mehrere Konfigurationen innerhalb eines Schedulers. | [15](15/de.md) |
| **schedulerName** | welcher Scheduler den Pod platziert. | [15](15/de.md) |
| **scope** | Bereich einer CRD: im namespace oder für den gesamten Cluster. | [41](41/de.md) |
| **search domains** | Suffixe in der resolv.conf, die kurze Namen vervollständigen. | [0.2](00-2-dns/de.md), [31](31/de.md) |
| **Secret** | Objekt für sensible Daten (Passwörter, Tokens, Schlüssel, Zertifikate). | [19](19/de.md) |
| **secretKeyRef / secretRef** | Einbinden eines Schlüssels/des gesamten Secret in env. | [19](19/de.md) |
| **SecurityContext** | Sicherheitseinstellungen auf Ebene des Pods/Containers. | [20](20/de.md) |
| **selector** | wie ein Controller "seine" Pods findet (über Labels). | [05](05/de.md), [06](06/de.md) |
| **Selector switch** | Wechsel des `selector` eines Service, um den Traffic sofort auf eine andere Version zu leiten (Grundlage von blue/green). | [09](09/de.md) |
| **SSH** | geschützte Anmeldung an einer Node über das Netz; `exit` - zurückkehren. | [0.5](00-5-linux/de.md) |
| **sudo** | einen Befehl als root ausführen; `sudo -i` - für die Sitzung root werden. | [0.5](00-5-linux/de.md) |
| **systemd / systemctl** | System zur Verwaltung von Diensten (kubelet, containerd) und der Befehl dazu. | [0.5](00-5-linux/de.md), [45](45/de.md) |
| **Service** | stabile Adresse und Lastverteilung vor einer Gruppe von Pods, die per Selektor ausgewählt werden. | [07](07/de.md) |
| **ServiceAccount** | Identität eines Pods/Prozesses für den Zugriff auf die API. | [21](21/de.md) |
| **shell form** | Befehl über `sh -c` (nötig für Variablen, Pipes). | [17](17/de.md) |
| **Sidecar** | Hilfscontainer im selben Pod (Kapitel 22). | [04](04/de.md), [22](22/de.md) |
| **snapshot restore** | Entpacken eines Snapshots in ein neues Datenverzeichnis. | [37](37/de.md) |
| **snapshot save** | Erstellen einer Sicherungskopie von etcd in eine Datei. | [37](37/de.md) |
| **stabilization window** | Wartefenster vor dem Reduzieren der Replikas. | [16](16/de.md) |
| **Stable identity** | vorhersagbare Namen der Pods (`db-0`, `db-1`), die eine Neuerstellung überstehen. | [11](11/de.md) |
| **startup** | ob der Start abgeschlossen ist; blockiert die übrigen Probes, bis sie durchläuft. | [27](27/de.md) |
| **Stateful** | Anwendung mit Zustand; braucht Identität und eigenen Storage. | [05](05/de.md) |
| **StatefulSet** | Controller für Anwendungen mit Zustand: stabile Namen, Reihenfolge, eigener Storage pro Pod. | [11](11/de.md) |
| **Stateless** | Anwendung ohne eigenen Zustand; die Pods sind austauschbar. | [05](05/de.md) |
| **Static Pod** | Pod, den kubelet direkt aus einem Manifest in `/etc/kubernetes/manifests/` startet, ohne Beteiligung des Schedulers. | [02](02/de.md), [15](15/de.md), [45](45/de.md) |
| **staticPodPath** | Ordner, den kubelet beobachtet (üblicherweise `/etc/kubernetes/manifests/`). | [15](15/de.md) |
| **stdout/stderr** | Standardausgabe des Containers, von der Kubernetes die Logs nimmt. | [28](28/de.md) |
| **StorageClass** | Vorlage zum Erstellen von Volumes: provisioner, Parameter, reclaim-Policy. | [26](26/de.md) |
| **stringData** | Feld für Werte im Klartext (werden automatisch kodiert). | [19](19/de.md) |
| **subjects** | wem die Rechte gegeben werden: User, Group, ServiceAccount. | [38](38/de.md) |
| **suspend** | zeitweises Anhalten eines CronJob. | [10](10/de.md) |
| **swapoff** | Abschalten des swap (Anforderung von Kubernetes). | [35](35/de.md) |
| **Taint** | einschränkende Markierung an einer Node (`Schlüssel=Wert:Effekt`), die Pods abstößt. | [13](13/de.md) |
| **Task weight** | Anteil an den Punkten, Hinweis auf die Priorität. | [47](47/de.md) |
| **TCPRoute / gRPCRoute / TLSRoute** | Routing für andere Protokolle. | [33](33/de.md) |
| **template** | Template des Pods, nach dem die Replikas erstellt werden. | [05](05/de.md) |
| **Three pillars of observability** | Logs, Metriken, Traces. | [28](28/de.md) |
| **Three-pass strategy** | Zeitstrategie: leichte → schwere → Prüfung. | [47](47/de.md), [48](48/de.md) |
| **throttling** | Bremsen des Containers bei Überschreitung des CPU-Limits. | [14](14/de.md) |
| **TLS** | Protokoll zur Verschlüsselung und Authentifizierung des Traffics (das "S" in HTTPS). | [0.3](00-3-tls/de.md) |
| **TLS termination** | Entschlüsselung von HTTPS am Ingress; das Zertifikat kommt aus einem Secret des Typs tls. | [0.3](00-3-tls/de.md), [32](32/de.md) |
| **Toleration** | "Passierschein" eines Pods, der ihm erlaubt, auf einer Node mit taint zu bleiben. | [13](13/de.md) |
| **tolerationSeconds** | wie lange ein Pod auf einer Node mit NoExecute bleibt, bevor er verdrängt wird. | [13](13/de.md) |
| **topologyKey** | Label der Node, das die "Nachbarschaftszone" bestimmt (hostname, zone). | [12](12/de.md) |
| **topologySpreadConstraints** | gleichmäßige Verteilung der Pods über die Topologie (`maxSkew`). | [12](12/de.md) |
| **troubleshooting domain** | 30% von CKA, die gewichtigste; Anwendungen/Cluster/Netz reparieren. | [48](48/de.md) |
| **TTL** | Lebensdauer eines DNS-Eintrags im Cache (in Sekunden). | [0.2](00-2-dns/de.md) |
| **ttlSecondsAfterFinished** | automatisches Löschen eines abgeschlossenen Job nach der angegebenen Zeit. | [10](10/de.md) |
| **type** | Zweck eines Secret (Opaque, tls, dockerconfigjson u. a.). | [19](19/de.md) |
| **uncordon** | die Node in den Scheduling-Pool zurückholen. | [36](36/de.md) |
| **updateStrategy** | Update-Strategie von DaemonSet/StatefulSet (rolling). | [11](11/de.md) |
| **valueFrom** | Füllen einer Variablen aus einer Quelle (Feld des Pods, Ressourcen, CM/Secret). | [17](17/de.md) |
| **Values** | Parameter zum Einsetzen in die Templates. | [42](42/de.md) |
| **VAR** | Verweis auf eine zuvor deklarierte Variable innerhalb des Manifests. | [17](17/de.md) |
| **veth pair** | zwei verbundene virtuelle Interfaces - das "Kabel" zwischen dem network namespace des Pods und der Node. | [0.7](00-7-netns/de.md), [30](30/de.md) |
| **Version skew** | zulässige Differenz der Versionen der Komponenten; kubelet nicht neuer als apiserver. | [36](36/de.md) |
| **Volume** | Storage, der auf Ebene des Pods deklariert und in die Container gemountet wird. | [24](24/de.md) |
| **Volume mount** | die Schlüssel einer ConfigMap werden zu Dateien in einem Verzeichnis. | [18](18/de.md) |
| **volumeBindingMode** | wann das Volume erstellt/gebunden wird (Immediate / WaitForFirstConsumer). | [26](26/de.md) |
| **volumeClaimTemplates** | Template eines StatefulSet, das für jeden Pod ein PVC erstellt. | [11](11/de.md), [26](26/de.md) |
| **volumes / volumeMounts** | Deklaration eines Volumes / dessen Mounten in den Container. | [24](24/de.md) |
| **VPA** | ändert requests/limits der Pods. | [16](16/de.md) |
| **webhook** | externe Prüfung/Änderung von Objekten (Kyverno, OPA, mesh). | [21](21/de.md) |
| **YAML** | menschenlesbares Format der Manifeste; die Verschachtelung wird durch Einrückungen gesetzt (nur Leerzeichen). | [0.6](00-6-yaml/de.md), [03](03/de.md) |
| **whenUnsatisfiable** | Modus von topologySpread: `DoNotSchedule` (streng, → Pending) oder `ScheduleAnyway` (weich, mit Toleranz gegenüber Schieflage). | [12](12/de.md) |
| **Worker node** | Arbeitsknoten, auf dem die Pods der Anwendungen laufen. | [02](02/de.md) |
| **Ingress annotations** | controllerspezifische Einstellungen (rewrite, timeout u. a.). | [32](32/de.md) |
| **Asymmetric cryptography** | Paar verbundener Schlüssel: privater (geheim) und öffentlicher (offen). | [0.3](00-3-tls/de.md) |
| **Subnet mask** | welcher Teil der Adresse zum Netz gehört und welcher zum Host. | [0.1](00-1-net/de.md) |
| **Octet** | eine der vier Zahlen einer IPv4-Adresse (8 Bit, 0-255). | [0.1](00-1-net/de.md) |
| **Port** | Zahl 0-65535, die die Anwendung auf einem Gerät bezeichnet; das Paar "IP + Port" = Service. | [0.1](00-1-net/de.md) |
| **Private / public key** | geheimer Schlüssel des Besitzers (wird nicht weitergegeben) / öffentlicher Schlüssel (wird an alle verteilt). | [0.3](00-3-tls/de.md) |
| **Resolver** | Komponente, die DNS-Anfragen für die Anwendung ausführt (im Cluster - CoreDNS). | [0.2](00-2-dns/de.md), [31](31/de.md) |
| **Certificate** | öffentlicher Schlüssel + Daten des Besitzers + Unterschrift der CA. | [0.3](00-3-tls/de.md), [39](39/de.md) |
| **Ingress → Gateway API migration** | Aufteilen eines Ingress in Gateway (Eingang) + HTTPRoute (Regeln). | [33](33/de.md) |
| **Native sidecar** | init-Container mit `restartPolicy: Always`. | [22](22/de.md) |
| **etcd certificates** | CA/cert/key in `/etc/kubernetes/pki/etcd/`. | [37](37/de.md) |
| **Kubernetes network model** | Anforderungen an das Netz: eigene IP für den Pod, Verbindung ohne NAT, flaches Netz. | [30](30/de.md) |
| **PV/PVC statuses** | Available, Bound, Pending, Released. | [25](25/de.md) |
| **Tag / digest** | Version des Images / unveränderlicher Hash des Inhalts. | [23](23/de.md) |

## Parameter, Flags und Codes

Flags von Befehlen, Alias-Helfer und Antwortcodes - getrennt von der eigentlichen
alphabetischen Liste der Begriffe.

| Parameter / Code | Beschreibung | Kapitel |
|----------------|----------|-------|
| **$do / $now** | Helfer `--dry-run=client -o yaml` / schnelles Löschen. | [47](47/de.md) |
| **--control-plane-endpoint** | gemeinsame Adresse der control plane (für HA). | [35](35/de.md) |
| **--data-dir** | Datenverzeichnis von etcd (beim restore - ein neues). | [37](37/de.md) |
| **--from-file / --from-env-file** | ganze Datei in einen Schlüssel / zeilenweise in Schlüssel. | [18](18/de.md) |
| **--ignore-daemonsets** | beim drain die Pods von DaemonSet nicht anfassen (sie sind an die Node gebunden). | [36](36/de.md) |
| **--pod-network-cidr** | Adressbereich der Pods (wird mit dem CNI abgestimmt). | [35](35/de.md) |
| **--previous** | Logs des vorherigen (abgestürzten) Containers. | [28](28/de.md) |
| **--set / -f** | Überschreiben von values in der CLI / per Datei. | [42](42/de.md) |
| **401 vs 403** | nicht authentifiziert (Zertifikat) vs keine Rechte (RBAC). | [39](39/de.md) |
| **`--dry-run=client -o yaml`** | YAML generieren, ohne etwas zu erstellen. | [03](03/de.md) |
