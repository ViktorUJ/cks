[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 130 - Referenzlösung (ECR und supply chain)

Alle Befehle werden auf der Worker-Maschine (worker) per SSH ausgeführt. Die AWS CLI ist
bereits über die Instanzrolle auf das richtige Konto konfiguriert (ein zusätzliches
`aws configure` ist nicht nötig), kubectl - auf den Cluster der Lab. Statt `docker`
verwenden wir `podman` (bereits auf dem Worker installiert).

Bestimmen wir einmal die Account-ID und die Adresse der privaten Registry:

```bash
export AWS_REGION=eu-central-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "$ECR_HOST"
```

## Aufgabe 1. Repository mit IMMUTABLE-Tags und scanOnPush

```bash
aws ecr create-repository \
  --repository-name eks-lab130/app \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --region "$AWS_REGION"

aws ecr describe-repositories --repository-names eks-lab130/app --region "$AWS_REGION"
```

Stellen Sie sicher, dass in der Ausgabe `imageTagMutability: IMMUTABLE` und
`imageScanningConfiguration.scanOnPush: true` stehen.

## Aufgabe 2. Push eines Images mit Tag v1

Wir melden uns mit einem 12-Stunden-Token in der Registry an und taggen ein öffentliches
Image um:

```bash
aws ecr get-login-password --region "$AWS_REGION" \
  | podman login --username AWS --password-stdin "$ECR_HOST"

podman pull docker.io/library/alpine:3.19
podman tag docker.io/library/alpine:3.19 "$ECR_HOST/eks-lab130/app:v1"
podman push "$ECR_HOST/eks-lab130/app:v1"

aws ecr describe-images --repository-name eks-lab130/app --region "$AWS_REGION"
```

In der Ausgabe von `describe-images` muss genau ein Image mit dem Tag `v1` stehen.

Zwei praktische Punkte. Erstens: `alpine` ist hier nicht wegen der geringeren Größe
gewählt, sondern weil das Basic Scanning von ECR seine Paketbasis auswerten kann - in
Aufgabe 4 gibt es echte Findings (geprüft: HIGH 1, MEDIUM 1, LOW 2 bei `alpine:3.19`).
Zweitens: Erledigen Sie die Aufgaben 2-6 in derselben SSH-Sitzung. `podman login`
schreibt das Token nach `$XDG_RUNTIME_DIR/containers/auth.json`, und dieses Verzeichnis
wird zusammen mit der Benutzersitzung gelöscht, daher antwortet push nach dem erneuten
Verbinden mit `unauthorized: authentication required`, obwohl das 12-Stunden-Token von
ECR noch gültig ist.

## Aufgabe 3. Symptom: erneuter Push des Tags v1 wird abgelehnt

Wir nehmen ein anderes Image, taggen es mit demselben `v1` und versuchen, es zu
überschreiben:

```bash
podman pull docker.io/library/busybox:1.36
podman tag docker.io/library/busybox:1.36 "$ECR_HOST/eks-lab130/app:v1"

mkdir -p /var/work/tests/artifacts/3
podman push "$ECR_HOST/eks-lab130/app:v1" 2>&1 \
  | tee /var/work/tests/artifacts/3/denied.txt
```

Der Push endet mit einer Ablehnung durch die Registry (auf der Umgebung geprüft):

```
tag invalid: The image tag 'v1' already exists in the 'eks-lab130/app' repository
and cannot be overwritten because the tag is immutable.
```

Genau so funktioniert IMMUTABLE: Der Tag `v1` ist schon vom ersten Image belegt und kann
nicht überschrieben werden. Die Ausgabe wird lang sein - `podman` probiert der Reihe nach
mehrere Manifest-Formate durch (OCI, docker v2, docker v1) und erhält bei jedem dieselbe
Ablehnung; im Artefakt `denied.txt` steht die gesuchte Zeile bei jedem Versuch. Beachten
Sie, dass die Layer dabei schon hochgeladen wurden: IMMUTABLE schützt genau die
TAG-BINDUNG, nicht den blob-Speicher.

## Aufgabe 4. Findings des Scans (scan on push)

Das Scannen startet automatisch beim Push (Aufgabe 2). Wir warten den Abschluss über
eine Retry-Schleife ab (in dieser CLI-Version gibt es einen fertigen Wartebefehl):

```bash
aws ecr wait image-scan-complete \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION"

mkdir -p /var/work/tests/artifacts/4
aws ecr describe-image-scan-findings \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
  --query '{status: imageScanStatus.status, bySeverity: imageScanFindings.findingSeverityCounts}' \
  > /var/work/tests/artifacts/4/scan-summary.txt

cat /var/work/tests/artifacts/4/scan-summary.txt
```

Falls `aws ecr wait image-scan-complete` in Ihrer CLI-Version nicht verfügbar ist,
ersetzen Sie es durch eine manuelle Retry-Schleife:

```bash
for i in $(seq 1 30); do
  status=$(aws ecr describe-image-scan-findings \
    --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
    --query 'imageScanStatus.status' --output text 2>/dev/null)
  [[ "$status" == "COMPLETE" ]] && break
  sleep 5
done
```

`findingSeverityCounts` zeigt die Anzahl der Findings nach severity - bei
`alpine:3.19` war das `{"HIGH": 1, "MEDIUM": 1, "LOW": 2}` (auf der Umgebung geprüft, die
konkreten Zahlen hängen vom Datum des Scans und der Schwachstellendatenbank ab).

Eine wichtige Grenze der Anwendbarkeit, die man selbst prüfen sollte. Das Basic Scanning
von ECR liest die Paketbasis bekannter Distributionen, daher kann es ein Image, das mit
`FROM scratch` (zum Beispiel ein statisches Go-Binary) oder distroless gebaut wurde,
NICHT scannen:

```bash
aws ecr describe-image-scan-findings --repository-name eks-lab130/app \
  --image-id imageTag=<Tag des scratch-Images> --region "$AWS_REGION" \
  --query 'imageScanStatus' --output json
# {
#   "status": "FAILED",
#   "description": "UnsupportedImageError: The operating system and/or package manager
#                   are not supported."
# }
```

Daraus folgt praktisch: „der Scanner hat keine Schwachstellen gefunden“ und „der Scanner
konnte nicht hinsehen“ sind zwei unterschiedliche Dinge, die in Sammelberichten leicht zu
„keine Anmerkungen“ verschmelzen. Wenn die Gate-Policy einen sauberen Scan verlangt,
prüfen Sie genau den Status und nicht nur die Anzahl der Findings.

## Aufgabe 5. Deploy per digest

Den digest des Images `v1` kann man aus ECR holen (zuverlässiger als `podman inspect`,
da es genau der digest des Manifests ist, das in der Registry liegt):

```bash
DIGEST=$(aws ecr describe-images --repository-name eks-lab130/app --image-ids imageTag=v1 \
  --region "$AWS_REGION" --query 'imageDetails[0].imageDigest' --output text)
echo "$DIGEST"

kubectl create namespace eks-130 --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: digest-app
  namespace: eks-130
  labels:
    app: digest-app
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
  - name: app
    image: ${ECR_HOST}/eks-lab130/app@${DIGEST}
    command: ["sh", "-c", "sleep 86400"]
EOF

kubectl wait --for=condition=Ready pod/digest-app -n eks-130 --timeout=600s
kubectl get po -n eks-130 digest-app -o wide
```

`nodeSelector` ist hier verpflichtend, und das ist eine Falle, in die man leicht tappen
kann. Die Worker-Maschine ist x86_64, daher hat `podman push` ein
EINZELARCHITEKTUR-Manifest (nur `amd64`) an ECR gesendet, während der NodePool der Lab
auch `arm64` erlaubt. Auf der Umgebung geprüft: Ohne Selector startete Karpenter ein
`t4g.small`, das Image wurde problemlos geladen, aber der Container starb mit
`exitCode 255` und leeren Logs - `CrashLoopBackOff` ohne verständlichen Grund. Dieselbe
Art von Problem wird in Lab 124 behandelt (das Image `polinux/stress` war nur `amd64`).
Fazit für den Produktionsbetrieb: Entweder Sie bauen multiarch-Manifeste, oder Sie
binden die Workload explizit an eine Architektur.

Die Node-Rolle von Karpenter trägt bereits die Managed Policy
`AmazonEC2ContainerRegistryReadOnly` (konfiguriert im Modul `eks_v2_karpenter`), daher
zieht der Pod das Image erfolgreich und wechselt ohne `imagePullSecrets` in den Zustand
`Running`. Die Referenz per `@sha256:` fixiert genau den Bytesatz, den Sie in den
Aufgaben 2-4 gescannt und geprüft haben - der Tag könnte sich ändern, der digest nicht.

## Aufgabe 6. pull through cache für registry.k8s.io

Regel ohne Authentifizierung - der Upstream ist öffentlich:

```bash
aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix k8s-cache \
  --upstream-registry-url registry.k8s.io \
  --region "$AWS_REGION"
```

Beim Anlegen der ERSTEN Regel im ECR-Konto legt ECR die service-linked role
`AWSServiceRoleForECRPullThroughCache` an, daher braucht der Aufrufer das Recht
`iam:CreateServiceLinkedRole` (in der Policy der Worker-Maschine ist es vorhanden, mit der
Bedingung `iam:AWSServiceName = pullthroughcache.ecr.amazonaws.com`). Ohne dieses Recht
antwortet ECR nicht direkt zum IAM-Benutzer, sondern mit einer Verpackung, die man leicht
für einen Parameterfehler halten kann:
`ValidationException ... The Amazon ECR action failed due to an IAM exception: ... is not
authorized to perform: iam:CreateServiceLinkedRole` (auf der Umgebung reproduziert).

Der erste Pull über den Cache erstellt in Ihrem ECR das Repository `k8s-cache/pause` und
cacht das Image:

```bash
podman pull "${ECR_HOST}/k8s-cache/pause:3.9"

aws ecr describe-repositories --region "$AWS_REGION" \
  --query "repositories[?starts_with(repositoryName,'k8s-cache/pause')].repositoryName"
```

## Aufgabe 7. Docker Hub pull through cache mit Secret (ohne echten Pull)

Das Thema der Lab verlangt genau ein Secret, daher legen wir es wirklich an, aber mit
einem Platzhalter statt einem echten Docker Hub-Token: Ein echter Pull mit diesen
Credentials wird nicht durchgehen, die Konfiguration (Secret plus cache rule) leidet
darunter aber nicht und wird vollständig geprüft.

```bash
aws secretsmanager create-secret \
  --name ecr-pullthroughcache/dockerhub-creds \
  --description "Docker Hub creds for ECR pull through cache (lab placeholder)" \
  --secret-string '{"username":"lab-placeholder-user","accessToken":"lab-placeholder-token"}' \
  --region "$AWS_REGION"

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id ecr-pullthroughcache/dockerhub-creds --region "$AWS_REGION" \
  --query 'ARN' --output text)
echo "$SECRET_ARN"

aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix docker-hub \
  --upstream-registry-url registry-1.docker.io \
  --credential-arn "$SECRET_ARN" \
  --region "$AWS_REGION"

aws ecr describe-pull-through-cache-rules --region "$AWS_REGION"
```

Das Secret muss unbedingt das Präfix `ecr-pullthroughcache/` tragen - sonst akzeptiert
ECR es nicht für die cache rule. Ein echter `podman pull` über `docker-hub/...` mit
diesem Platzhalter schlägt erwartungsgemäß fehl (die Credentials sind nicht echt) - die
Aufgabe prüft die Konfiguration (Secret und Regel existieren), nicht die Tatsache eines
erfolgreichen Pulls. Für den Nachweis eines erfolgreichen Pulls über den Cache dient
Aufgabe 6 (registry.k8s.io, ohne Authentifizierung).

Wichtig: Verwenden Sie hier keine echten Docker Hub-Credentials. Das Secret dient nur
zur Prüfung der Konfiguration dieser Lab selbst.

## Aufgabe 8. Lifecycle policy

Regel: nicht mehr als 5 Images mit dem Tag `v.*` aufbewahren, den Rest nach Alter des
Tags löschen:

```bash
cat <<'EOF' > /tmp/lifecycle.json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "keep last 5 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": { "type": "expire" }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name eks-lab130/app \
  --lifecycle-policy-text file:///tmp/lifecycle.json \
  --region "$AWS_REGION"

aws ecr get-lifecycle-policy --repository-name eks-lab130/app --region "$AWS_REGION"
aws ecr start-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION" >/dev/null
sleep 5
aws ecr get-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION"
```

`get-lifecycle-policy-preview` liefert das Ergebnis vielleicht nicht sofort (die Vorschau
wird asynchron berechnet) - falls der Status noch `IN_PROGRESS` ist, wiederholen Sie die
Anfrage nach ein paar Sekunden.

## Schnelle Prüfung

```bash
check_result
```
