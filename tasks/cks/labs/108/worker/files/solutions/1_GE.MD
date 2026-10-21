[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 - ეტალონური ამოხსნა: Kyverno admission policies

> ყველა ბრძანება სრულდება სამუშაო მანქანაზე. კონტექსტი უკვე გამართულია; namespace
> `policy-108` შექმნილია საწყისი სკრიპტით. ჯერ დააყენეთ Kyverno და დაელოდეთ
> webhook-ს: წინააღმდეგ შემთხვევაში შემდგომი CEL-based policies admission-მოთხოვნებს არ შეამოწმებენ.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
```

## 1. Kyverno-ს დაყენება

worker-ზე მომზადებულია დაფიქსირებული installer: ის აყენებს Kyverno-ს Helm chart-ს
`3.9.0` (Kyverno `1.19`) namespace `kyverno`-ში. გაშვებამდე მისი დათვალიერება შეიძლება.

```bash
cat /usr/local/bin/install-kyverno
install-kyverno
kubectl get pods -n kyverno
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
```

დაელოდეთ, სანამ `kyverno`-ში სულ მცირე ერთ Deployment-ს არ ექნება `AVAILABLE > 0`.

> **Migration note.** `kyverno.io/v1` `Policy`/`ClusterPolicy` ძველი მაგალითები სასარგებლოა
> მხოლოდ არსებული კლასტერების მხარდაჭერისას. Kyverno `1.19`-ში ისინი deprecated-ია,
> ხოლო `1.20`-ში დაგეგმილია წაშლა. ამ ლაბის ახალი policy-ები იყენებენ
> `policies.kyverno.io/v1`-ს.

## 2. ტეგ `latest`-ის აკრძალვა

შექმენით `ValidatingPolicy` რეჟიმში `Deny`. წესი ამოწმებს კონტეინერების სამივე სიას -
`containers`, `initContainers` და `ephemeralContainers`: წინააღმდეგ შემთხვევაში აკრძალული image-ის
init- ან ephemeral-კონტეინერით გატარება ადვილია, ხოლო თავად Pod მაინც გაივლის admission-ს.

```yaml
# deny-latest-tag.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: deny-latest-tag
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must use an explicit non-latest tag or a digest.
    expression: >-
      variables.images.all(image,
        image.contains('@') ||
        (image.matches('^(?:.*/)?[^/:]+:[^/]+$') && !image.endsWith(':latest')))
```

```bash
kubectl apply -f deny-latest-tag.yaml
```

დავალება უშვებს image reference-ის ორ ფორმას - non-latest tag ან digest. აშკარად შეამოწმეთ,
რომ digest-ფორმა გადის (და არა მხოლოდ versioned tag გადის) - წინააღმდეგ შემთხვევაში ადვილია
policy-ის დაწერა, რომელიც შემთხვევით ყველა digest reference-ს უარყოფს:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: digest-pinned-ok
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause@sha256:5a92cb1de40c9c50e1c72e83bf35b9b32ce88e0d1b93f5e2727d97a44c176f56
EOF
# მოსალოდნელია: წარმატება (admission-ის არანაირი შეცდომა)
```

დარწმუნდით, რომ ტეგის დამუშავება registry-პორტში ორწერტილს ითვალისწინებს: `registry.example:5000/app`
image tag-ს არ შეიცავს და implicit latest-ად უნდა იყოს უარყოფილი. Digest უნდა
მიიღებოდეს კონტეინერების სხვა სიებშიც - მაგალითად, `initContainers`-ში და
`kubectl debug --image=...`-ით `ephemeralContainers`-ისთვის.

## 3. `runAsNonRoot`-ის მოთხოვნა

პოლიტიკა მოითხოვს სწორედ `true` მნიშვნელობას Pod-level `securityContext`-ში; არაპირდაპირი
მნიშვნელობა და `false` არ გადის. დამატებით აკრძალულია `runAsUser: 0` Pod-ის დონეზე
და container-level overrides `runAsNonRoot: false` / `runAsUser: 0` სამივე
container list-ში, წინააღმდეგ შემთხვევაში container-level securityContext შეძლებს Pod-level
`runAsNonRoot: true`-ის გადაფარვას და root-პროცესის გაშვებას.

```yaml
# require-run-as-non-root.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  validations:
  - message: Pod and every container must have an effective non-root security context.
    expression: >-
      has(object.spec.securityContext) &&
      object.spec.securityContext.?runAsNonRoot.orValue(false) &&
      object.spec.securityContext.?runAsUser.orValue(1) != 0 &&
      object.spec.containers.all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0)) &&
      object.spec.?initContainers.orValue([]).all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0)) &&
      object.spec.?ephemeralContainers.orValue([]).all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0))
```

```bash
kubectl apply -f require-run-as-non-root.yaml
```

## 4. მხოლოდ დამტკიცებული registry-ების დაშვება

დაშვებულია `registry.k8s.io` და გამოყოფილი ორგანიზაციული გზა `ghcr.io/cks-lab`. CEL
აერთიანებს container lists-ის სამივეს და ყოველ image-ზე ერთ allowlist-ს იყენებს.

```yaml
# allow-approved-registries.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: allow-approved-registries
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must come from registry.k8s.io or ghcr.io/cks-lab.
    expression: >-
      variables.images.all(image,
        image.startsWith('registry.k8s.io/') ||
        image.startsWith('ghcr.io/cks-lab/'))
```

```bash
kubectl apply -f allow-approved-registries.yaml
```

შემოწმება Pod-ის შექმნისა და image pull-ის გარეშე. `docker.io` - მხოლოდ ერთი კონკრეტული
untrusted-მნიშვნელობაა; შეამოწმეთ, რომ policy მართლაც ALLOWLIST-ია (კრძალავს ნებისმიერ
registry-ს ორი დაშვებულის გარდა), და არა უბრალოდ `docker.io`-ს denylist სიტყვასიტყვითი სტრიქონით -
წინააღმდეგ შემთხვევაში unqualified image, სხვა მესამე მხარის registry ან მსგავსი დაწერილობის host ადვილად
გაიპარება.

Positive controls უნდა ფარავდეს ორივე დაშვებულ prefix-ს (`registry.k8s.io/` და
`ghcr.io/cks-lab/`) `containers`-ში, `initContainers`-სა და `ephemeralContainers`-ში; ნუ შემოფარგლავთ registry-ებიდან ერთ-ერთს
მხოლოდ ჩვეულებრივი კონტეინერებით:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-unqualified-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-quay-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: quay.io/prometheus/busybox:v0.24.0
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-lookalike-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io.evil.example/pause:3.10
EOF
```

ოთხივე უნდა იყოს უარყოფილი. ქვემოთ პირველი Pod წესს არღვევს მთავარი
კონტეინერით, მეორე - მხოლოდ `initContainers`-ით; ორივე უარყოფილი უნდა იყოს:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry-main
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-init-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: docker.io/library/busybox:1.36
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

ორივე ბრძანება admission policy-ის შეცდომით უნდა დასრულდეს. `ephemeralContainers`-ით
შემოვლის აშკარა ცდისთვის შექმენით დაშვებული Pod, შემდეგ შეასრულეთ `kubectl debug` ჯერ
`docker.io/library/busybox:1.36`-ით (მოსალოდნელია denial), შემდეგ
`registry.k8s.io/e2e-test-images/busybox:1.36-1`-ით (მოსალოდნელია წარმატება). სწორედ
`pods/ephemeralcontainers` `matchConstraints`-ში იცავს subresource update-ს.

## 5. არასავალდებულო: mutation label

ეს `MutatingPolicy` Pod-ს არ უარყოფს, არამედ label-ს ამატებს CEL
`ApplyConfiguration`-ით - მაგრამ მხოლოდ იმ შემთხვევაში, თუ label ჯერ არ არის მითითებული. დავალება მოითხოვს სწორედ
defaulting-სემანტიკას («თუ ის არ არის»): Pod, რომელსაც ეს label უკვე სხვა
მნიშვნელობით აქვს (მაგალითად, სხვა მფლობელისგან/ინსტრუმენტისგან), არ უნდა მიიღოს ის
იძულებით გადაწერილი.

```yaml
# add-kyverno-managed-label.yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: add-kyverno-managed-label
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE]
      resources: [pods]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  mutations:
  - patchType: ApplyConfiguration
    applyConfiguration:
      expression: >-
        has(object.metadata.labels) &&
        'security.cks.io/managed-by' in object.metadata.labels
        ? Object{}
        : Object{
            metadata: Object.metadata{
              labels: {"security.cks.io/managed-by": "kyverno"}
            }
          }
```

```bash
kubectl apply -f add-kyverno-managed-label.yaml
kubectl apply --dry-run=server -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# მოსალოდნელია: kyverno

kubectl apply --dry-run=server -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check-existing-label
  namespace: policy-108
  labels:
    security.cks.io/managed-by: external
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# მოსალოდნელია: external (mutation უკვე მითითებულ მნიშვნელობას არ გადაწერს)
```

გაუშვით `check_result`. დავალება 5 ნაჩვენებია შემოწმებაში, მაგრამ ის არასავალდებულოა: mutation
policy-ის არარსებობა გავლენას არ ახდენს დავალებების 1–4, 6 და 7-ის ჩათვლაზე.

## 6. ImagePolicyWebhook: გარე backend

დავალებებისგან 1-5 განსხვავებით, აქ image-ის შესახებ გადაწყვეტილებას გარე HTTPS-backend იღებს
API `ImageReview`-ის გავლით, და არა CEL-გამოსახულება Kyverno-ს შიგნით. Upstream-დოკუმენტაცია
ImagePolicyWebhook-ის შესახებ აშკარად მოითხოვს, რომ backend connection TLS-ს იყენებდეს ("It is
required that the backend communicate over TLS"), ამიტომ ვიყენებთ თვითხელმოწერილ
სერტიფიკატს, და არა HTTP-ს.

Backend უკვე მომზადებულია სამუშაო მანქანაზე:

```bash
cat /opt/image-policy-backend/server.py
```

შექმენით namespace და ConfigMap backend-ის კოდით:

```bash
kubectl create namespace image-policy --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap image-policy-backend-src -n image-policy \
  --from-file=server.py=/opt/image-policy-backend/server.py \
  --dry-run=client -o yaml | kubectl apply -f -
```

შექმენით Service **Deployment-მდე** - სერტიფიკატში სწორი SAN-ისთვის საჭიროა `ClusterIP`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: image-policy-backend
  namespace: image-policy
spec:
  selector:
    app: image-policy-backend
  ports:
  - port: 8443
    targetPort: 8443
EOF

BACKEND_IP=$(kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.clusterIP}')
echo "$BACKEND_IP"
```

გასცით თვითხელმოწერილი სერტიფიკატი ამ `ClusterIP`-ით SAN-ში და შეინახეთ Secret-ში:

```bash
workdir=$(mktemp -d)
openssl req -x509 -nodes -newkey rsa:2048 -days 3 \
  -keyout "$workdir/tls.key" -out "$workdir/tls.crt" \
  -subj "/CN=image-policy-backend" \
  -addext "subjectAltName=IP:${BACKEND_IP}"

kubectl create secret tls image-policy-backend-tls -n image-policy \
  --cert="$workdir/tls.crt" --key="$workdir/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
```

განათავსეთ Deployment, როგორც კოდის, ისე სერტიფიკატის მიმაგრებით:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-policy-backend
  namespace: image-policy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-policy-backend
  template:
    metadata:
      labels:
        app: image-policy-backend
    spec:
      containers:
      - name: backend
        image: python:3.12-slim
        command: ["python3", "/opt/image-policy/server.py"]
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: src
          mountPath: /opt/image-policy
        - name: tls
          mountPath: /opt/image-policy/tls
          readOnly: true
      volumes:
      - name: src
        configMap:
          name: image-policy-backend-src
      - name: tls
        secret:
          secretName: image-policy-backend-tls
EOF

kubectl rollout status deployment/image-policy-backend -n image-policy --timeout=90s
```

დააკოპირეთ CA-სერტიფიკატი (აქ self-signed, ამიტომ სერვერის სერტიფიკატი თავად არის მისი
საკუთარი CA) `control-plane`-ზე, რათა kube-apiserver-მა backend-თან დაკავშირებისას ჯაჭვი შეამოწმოს,
და შედით node-ზე:

```bash
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
scp "$workdir/tls.crt" "$CP":/tmp/image-policy-ca.crt
rm -rf "$workdir"
echo "$BACKEND_IP"     # დაგჭირდებათ node-ზე
ssh "$CP"
sudo -i
```

`control-plane`-ზე შექმენით admission config და kubeconfig backend-ისთვის. გზები - **თავად
control-plane-ის** დისკზეა:

```bash
# control-plane-ზე (root)
mkdir /etc/kubernetes/image-policy
mv /tmp/image-policy-ca.crt /etc/kubernetes/image-policy/ca.crt

cat > /etc/kubernetes/image-policy/admission-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/image-policy/kubeconfig
      allowTTL: 30
      denyTTL: 30
      retryBackoff: 500
      defaultAllow: false
EOF

BACKEND_IP=10.111.15.20     # ჩაწერეთ ClusterIP, რომელიც გამოიტანა "echo $BACKEND_IP"-მ
cat > /etc/kubernetes/image-policy/kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: image-policy-backend
  cluster:
    certificate-authority: /etc/kubernetes/image-policy/ca.crt
    server: https://${BACKEND_IP}:8443/imagepolicy
users:
- name: kube-apiserver
contexts:
- name: image-policy
  context:
    cluster: image-policy-backend
    user: kube-apiserver
current-context: image-policy
EOF
```

დაარედაქტირეთ static manifest **`control-plane`-ზე** (თქვენ უკვე root-სესიაში ხართ). არსებულ
`--enable-admission-plugins`-ს მთლიანად ნუ ჩაანაცვლებთ - მიუწერეთ `ImagePolicyWebhook` მიმდინარე
მნიშვნელობას (ჩვეულებრივ იქ უკვე არის `NodeRestriction`), დაამატეთ `--admission-control-config-file` და
`--runtime-config`, მიამაგრეთ ახალი დირექტორია როგორც hostPath:

```bash
# control-plane-ზე (root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml-ის ფრაგმენტი control-plane-ზე
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook   # მიუწერეთ არსებულ სიას
    - --admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml
    - --runtime-config=imagepolicy.k8s.io/v1alpha1=true               # მიუწერეთ, თუ runtime-config უკვე იყო მითითებული
    volumeMounts:
    - name: image-policy
      mountPath: /etc/kubernetes/image-policy
      readOnly: true
  volumes:
  - name: image-policy
    hostPath:
      path: /etc/kubernetes/image-policy
      type: DirectoryOrCreate
```

შენახვის შემდეგ გამოდით node-იდან; kubelet თავად აიღებს static Pod-ის ცვლილებას:

```bash
exit   # root-იდან
exit   # control-plane-იდან
```

დაელოდეთ API-ს აღდგენას:

```bash
until kubectl get --raw=/readyz 2>/dev/null | grep -q '^ok$'; do sleep 5; done
```

შეამოწმეთ ორივე შემთხვევა:

```bash
kubectl run webhook-latest-must-fail --image=nginx:latest
# Error from server (Forbidden): pods "webhook-latest-must-fail" is forbidden:
# image policy webhook backend denied one or more images: Images using latest tag are not allowed

kubectl run webhook-pinned-ok --image=nginx:1.27.3
kubectl get pod webhook-pinned-ok
# STATUS: Running
```

`ImagePolicyWebhook` იყენებს backend-ს `/opt/image-policy-backend/server.py`-დან:
`default`-სა და დანარჩენ namespace-ებში (`policy-108`-ის გარდა) ის კრძალავს explicit/implicit
latest-ს; `policy-108`-ს მთლიანად აკონტროლებს სამი Kyverno-პოლიტიკა დავალებებიდან 2–4.
ეს მექანიზმების ლაბორატორიული იზოლაციაა, და არა უნივერსალური production pattern.
მომხმარებლის annotation `alpha.image-policy.k8s.io/break-glass` ნებართვას არ იძლევა:
ImageReview forwarding annotations ავთენტურობის შემოწმება არ არის.

`defaultAllow: false` ნიშნავს fail-closed-ს: თუ backend მიუწვდომელია, ახალი Pod/image
იკრძალება, და არა დაიშვება. შეამოწმეთ ეს აშკარად - მაგრამ `image-policy-backend`-ს
0 replica-მდე ნუ დაამასშტაბებთ: `ImagePolicyWebhook` - cluster-wide admission
plugin-ია namespace-ის მიხედვით გამონაკლისის გარეშე ჩვენს კონფიგურაციაში, ამიტომ ის თავად backend-ის Pod-საც ამოწმებს.
თუ ყველა replica დროებით მოიხსნება, შემდეგ კი მათ უკან დაბრუნებას შეეცდებით, ახალი backend Pod-ის შექმნა თავად
გაივლის იმავე (ამ მომენტში მიუწვდომელ) ImagePolicyWebhook-ს და სწორი `defaultAllow: false`-ის დროს უარყოფილი იქნება -
მიიღებთ deadlock-ს, საიდანაც `kubectl rollout status` ვერ გამოვა. ამის ნაცვლად
Service backend-ისგან გათიშეთ, `selector`-ის არარსებულ მნიშვნელობაზე შეცვლით - ეს
არც ერთ Pod-ს არ ქმნის და არ შლის, მხოლოდ დროებით აქრობს `Endpoints`-ს:

```bash
kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.selector}'
# შეინახეთ ეს მნიშვნელობა, რათა მოგვიანებით აღადგინოთ

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend-detached-for-probe"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# Ctrl+C, როცა ENDPOINTS დაცარიელდება

kubectl run webhook-should-fail-closed --image="nginx:fail-closed-check-$(date +%s%N)"
# მოსალოდნელია: Forbidden - backend მიუწვდომელია, defaultAllow:false კრძალავს admission-ს
# (ვიყენებთ ჯერ არნახულ ტეგს, და არა უბრალოდ თარიღს წამებში, რათა არ შევეჯახოთ
# backend-ის პასუხის TTL-ქეშს იმავე ტეგზე წინა ცდიდან)

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# Ctrl+C, როცა ENDPOINTS ისევ გამოჩნდება - ეს იგივე Pod-ია, რაც probe-მდე იყო, არანაირი
# ხელახალი აწყობა/ხელახალი შექმნა საჭირო არ გამხდარა
```

ეს იგივე პრინციპული fail-closed გადაწყვეტილებაა, რაც [კურსის თავში 26](../../../../../course/26/ge.md) არის აღწერილი
ImagePolicyWebhook-ის production-კონფიგურაციისთვის.

## 7. Gatekeeper: Rego blocklist-ის დამატება ConstraintTemplate-ში

Gatekeeper და საწყისი (არასრული) `ConstraintTemplate`/`Constraint` უკვე განთავსებულია
კლასტერის bootstrap-ით ცალკე namespace `gatekeeper-108`-ში - ეს ცალკე, მესამე
admission engine-ია ამ ლაბში (Kyverno-სა და ImagePolicyWebhook-ის შემდეგ), რომელიც სწორედ
OPA/Rego-უნარს ამოწმებს. `gatekeeper-108` Kyverno-ს დავალებებისგან 1-5 (`policy-108`) იზოლირებულია
სპეციალურად: წინააღმდეგ შემთხვევაში ერთი და იგივე სატესტო Pod ერთდროულად შეიძლებოდა Kyverno-მაც და
Gatekeeper-მაც უარეყო, და denial-ის წყარო ორაზროვანი იქნებოდა. ნახეთ მიმდინარე Rego:

```bash
kubectl get constrainttemplate k8sblockedregistries -o yaml
```

`spec.targets[].rego` დაბლოკილ registry-ს აცხადებს ცალკე ფაქტებით:

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
```

`very-bad-registry.test` მათ შორის არ არის - სწორედ ეს სტრიქონი უნდა დაემატოს. `Constraint
deny-bad-registries` უკვე სრულიად სწორია და `spec.parameters`-ს საერთოდ არ იყენებს -
მისი რედაქტირება საჭირო არ არის; შესწორება სწორედ Rego-შია `ConstraintTemplate`-ის შიგნით,
და არა Constraint-ში. დაარედაქტირეთ template (მაგალითად `kubectl edit
constrainttemplate k8sblockedregistries`, ან `get -o yaml` → შესწორება → `apply -f -`),
ახალი სტრიქონის დამატებით არსებულების წაშლის გარეშე:

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
blocked_registry("very-bad-registry.test")
```

შეამოწმეთ სამივე შედეგი server-side dry-run-ით, მუდმივი Pod-ის შექმნის გარეშე: ახალი
registry უნდა იყოს denied, ძველი (უკვე დაბლოკილი) - denied დარჩეს (რეგრესია
არ არის), სანდო - გადიოდეს:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-new-bad-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
# მოსალოდნელია: Error from server ... admission webhook "validation.gatekeeper.sh" denied
# the request: [deny-bad-registries] image registry very-bad-registry.test is blocked
# by k8sblockedregistries

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-old-bad-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
# მოსალოდნელია: ასევე Error from server ... - ძველი წესი არ უნდა დაიკარგოს

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-trusted-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# მოსალოდნელია: წარმატება (admission-ის არანაირი შეცდომა)
```

დარწმუნდით, რომ უარყოფა მართლაც Gatekeeper-ისგან (`validation.gatekeeper.sh`) მოვიდა, და
არა დავალებებიდან 2-4 Kyverno `ValidatingPolicy`-ებიდან ერთ-ერთისგან - შეცდომის შეტყობინება აშკარად
ასახელებს webhook-სა და თქვენი Constraint-ის სახელს. დავალებას `Constraint.spec.parameters`-ით ნუ ამოხსნით -
policy-ის ამ ვერსიაში Constraint მათ საერთოდ არ იყენებს.

გაუშვით `check_result`.
