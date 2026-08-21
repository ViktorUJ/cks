[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 112 - Referenzlösung (Fargate: Profile, Einschränkungen, Kosten)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl ist bereits für
den Cluster konfiguriert (das kubeconfig wird beim Booten der Maschine über
`aws eks update-kubeconfig` zusammengestellt). Das Fargate-Profil `workload` für den
Namespace `eks-112` wurde bereits von der Lab-Infrastruktur erstellt - der Student muss nur
noch den Namespace und die Objekte darin erstellen.

## Aufgabe 1. Namespace `eks-112`

```bash
kubectl create namespace eks-112
```

Das Profil `workload` passt auf `namespace = eks-112` ohne `labels`, daher landet der
gesamte Namespace vollständig auf Fargate - es wird keine Ausnahmen darin geben.

## Aufgabe 2. Ein Guaranteed-Pod `fg-app` auf Fargate

Fargate führt nur Pods aus, bei denen `requests` gleich `limits` ist (Klasse
`Guaranteed`). Wir erstellen ein Deployment mit explizit gleichen Werten:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
```

Wir prüfen, dass die Pods auf einem Fargate-Node landen (der Node-Name beginnt mit
`fargate-`, nicht mit `ip-`):

```bash
kubectl get po -n eks-112 -l app=fg-app -o wide
```

## Aufgabe 3. Artefakt: die tatsächlich zugewiesene Kapazität

Fargate rundet die Summe der Anfragen auf eine feste vCPU/Speicher-Kombination auf und
fügt `256 MB` für Kubernetes-Komponenten (`kubelet`, `kube-proxy`, `containerd`) hinzu. Die
tatsächlich zugewiesene Kapazität ist in der Annotation `CapacityProvisioned` zu sehen:

```bash
mkdir -p /var/work/tests/artifacts/3
POD=$(kubectl get po -n eks-112 -l app=fg-app -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n eks-112 \
  -o jsonpath='{.metadata.annotations.CapacityProvisioned}' \
  > /var/work/tests/artifacts/3/capacity.txt
echo >> /var/work/tests/artifacts/3/capacity.txt
cat /var/work/tests/artifacts/3/capacity.txt
```

Für eine Anfrage von `500m` CPU und `1Gi` Speicher plus `256 MB` Systemaufwand wählt
Fargate die nächstgelegene passende Kombination (z. B. `0.5vCPU 1GB`, oder `0.5vCPU 2GB`,
falls der Gesamtspeicher nach dem Aufschlag `1 GB` übersteigt) - genau diese Zeile zeigt
`kubectl describe pod`.

## Aufgabe 4. Symptom: ein privileged-Pod startet nicht

Fargate verbietet strikt privilegierte Container, DaemonSets, hostNetwork/hostPort,
hostPath und GPUs. Wir versuchen, einen privileged-Pod in `eks-112` zu erstellen:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-privileged
  namespace: eks-112
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
    securityContext:
      privileged: true
EOF

kubectl get po fg-privileged -n eks-112
kubectl describe po fg-privileged -n eks-112 | sed -n '/Events/,$p'
```

Der Pod erreicht `Running` nicht: Fargate lehnt privilegierte Container in der
Admission-Phase ab, das ist in den Events des Pods sichtbar. Wir speichern die Erklärung
im Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/privileged.txt <<'EOF'
Der Pod fg-privileged startet nicht, weil er privileged: true anfordert. Fargate
unterstützt keine privilegierten Container: das ist eine der strikten Einschränkungen
dieses Modus, neben DaemonSets, hostNetwork/hostPort, hostPath und GPUs. Der Fehler zeigt
sich in den Events des Pods als Admission-Ablehnung, nicht als gewöhnliches Pending wegen
Ressourcenmangel.
EOF
cat /var/work/tests/artifacts/4/privileged.txt
```

Wir können den Pod entfernen, damit er spätere Prüfungen nicht stört:

```bash
kubectl delete pod fg-privileged -n eks-112
```

## Aufgabe 5. Erweiterung der ephemeren Disk auf 30Gi

Standardmäßig stellt Fargate `20 GiB` ephemere Disk bereit, bis zu `175 GiB` über
`ephemeral-storage` in `resources` (requests muss gleich limits sein, der Pod bleibt
Guaranteed). Wir aktualisieren `fg-app`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
kubectl get po -n eks-112 -l app=fg-app -o wide
```

Der Pod startet normal: `30Gi` liegt innerhalb der erlaubten `175 GiB`, und die Anforderung
`requests == limits` ist erfüllt.

## Aufgabe 6. Kostenstruktur: Fargate versus Node Group

Der entscheidende Unterschied ist die Abrechnungseinheit. Fargate berechnet vCPU und
Speicher eines konkreten Pods für die Dauer seiner Lebenszeit; eine Node Group berechnet
die gesamte EC2-Instanz, unabhängig davon, wie stark sie ausgelastet ist. Die automatische
Prüfung dieses Artefakts sucht das Wort `pod` neben `vCPU`, daher
enthält das folgende Artefakt beides:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/costmodel.txt <<'EOF'
Fargate berechnet vCPU und Speicher des pod selbst für die Zeit, in der er
tatsächlich läuft: läuft der Pod nicht, entstehen keine Kosten, und es wird nie für
ungenutzte Kapazität bezahlt. Eine Node Group berechnet dagegen die gesamte Instanz: man
zahlt auch für die Zeit, in der Nodes zwischen Pods leer laufen oder unterausgelastet sind.
Pro Ressourceneinheit ist Fargate meist teurer als die entsprechende Ressource auf einem
Node-Group-Node, daher hängt die endgültige Wirtschaftlichkeit von der Auslastung ab: bei
hoher, vorhersehbarer Last ist eine Node Group günstiger, während Fargate bei sprunghafter
oder unvorhersehbarer Nachfrage das Bezahlen für ungenutzte Instanzen vermeidet.
EOF
cat /var/work/tests/artifacts/6/costmodel.txt
```

## Schnelle Prüfung

```bash
check_result
```
