[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 127 - ეტალონური გადაწყვეტა (ValidatingAdmissionPolicy CEL-ზე)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე (kubeconfig შედგენილია `aws eks update-kubeconfig`-ის
მეშვეობით მანქანის ჩატვირთვისას).

## დავალება 1. Namespace `eks-127`

```bash
kubectl create namespace eks-127
```

## დავალება 2. CEL-პოლიტიკა Audit რეჟიმში ატარებს პოდს `:latest`-ით

ვქმნით `ValidatingAdmissionPolicy`-ს და `ValidatingAdmissionPolicyBinding`-ს
`validationActions: ["Audit"]`-ით. პოლიტიკა ვრცელდება მხოლოდ namespace `eks-127`-ზე
`namespaceSelector`-ის მეშვეობით (ლეიბლი `kubernetes.io/metadata.name`, რომელსაც k8s
ავტომატურად აყენებს namespace-ზე):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: disallow-latest-tag
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, !c.image.endsWith(':latest'))"
      message: ":latest ტეგი forbidden, მიუთითეთ image-ის კონკრეტული ვერსია"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Audit"]
EOF
```

ვამოწმებთ, რომ ორივე ობიექტი ადგილზეა:

```bash
kubectl get validatingadmissionpolicy disallow-latest-tag
kubectl get validatingadmissionpolicybinding disallow-latest-tag-binding
```

ახლა ვქმნით პოდს image-ით `:latest` `Audit` რეჟიმში - ის უნდა შეიქმნას, რადგან `Audit`
მხოლოდ ჩაწერს დარღვევას audit-ლოგში, ხოლო არ ბლოკავს მოთხოვნას:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: latest-audit-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get pod latest-audit-pod -n eks-127
```

პოდი შექმნილია, თუმცა ის ხდის წესის დარღვევას - ეს არის `Audit`-ის აზრი: პოლიტიკის
გამოცდა არსებული დატვირთვის დაზიანების რისკის გარეშე.

## დავალება 3. გადავრთავთ Deny-ზე - პოდი `:latest`-ით უარყოფილია

ვანახლებთ Binding-ს, ვცვლით მხოლოდ `validationActions`-ს:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Deny"]
EOF
```

ვცდილობთ შევქმნათ კიდევ ერთი პოდი `:latest`-ით - ახლა apiserver-მა უნდა უარყოს
მოთხოვნა:

```bash
mkdir -p /var/work/tests/artifacts/3
cat <<'EOF' | kubectl apply -f - 2> /var/work/tests/artifacts/3/denied.txt
apiVersion: v1
kind: Pod
metadata:
  name: latest-deny-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

cat /var/work/tests/artifacts/3/denied.txt
```

ფაილში `denied.txt` უნდა იყოს apiserver-ის შეცდომის შესახებ შეტყობინება პოლიტიკის
ტექსტით (სიტყვები `latest` და `forbidden`). პოდი `latest-deny-pod` ამასთანავე არ არის
შექმნილი - `kubectl get pod latest-deny-pod -n eks-127` დააბრუნებს `NotFound`-ს.

## დავალება 4. ლეგიტიმური პოდი ცალსახა ტეგით გადის Deny-ის დროსაც

პოლიტიკა ამოწმებს მხოლოდ `:latest`-ს, ამიტომ პოდი კონკრეტული image-ის ვერსიით
პრობლემების გარეშე გადის. ტეგი `53833ea` არის რეალური commit-ტეგი
`viktoruj/ping_pong`-ში, ის არსებობს და აწყობილია amd64-ისთვის და arm64-ისთვის. მნიშვნელოვანია
არსებული ტეგის აღება: დაშვება ხედავს მხოლოდ image-ის სტრიქონს, ამიტომ პოდი
გამოგონილი ტეგით ასევე შეიქმნება და დამოკლდება `ErrImagePull`-ში - პოლიტიკამ
ფორმალურად "არ დაბრკოლა", მაგრამ ეს განცხადება ვერაფრით შემოწმდება:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tagged-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF

kubectl get pod tagged-pod -n eks-127
```

## დავალება 5. მეორე CEL-პოლიტიკა: სავალდებულო `resources.requests`

კიდევ ერთი `ValidatingAdmissionPolicy` პირდაპირ `Deny` რეჟიმში - მოვითხოვთ, რომ
ყოველ კონტეინერს ჰქონდეს დაყენებული `resources.requests`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resources-requests
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, has(c.resources) && has(c.resources.requests))"
      message: "ყოველ კონტეინერს უნდა ჰქონდეს დაყენებული resources.requests"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-resources-requests-binding
spec:
  policyName: require-resources-requests
  validationActions: ["Deny"]
EOF
```

პოდი `requests`-ის გარეშე უარყოფილია:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-requests-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF
```

ბრძანება დააბრუნებს დაშვების შეცდომას, და `kubectl get pod no-requests-pod -n
eks-127` გამოაჩენს `NotFound`-ს. პოდი დაყენებული `requests`-ით ჩვეულებრივად გადის:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: requests-ok-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
EOF

kubectl get pod requests-ok-pod -n eks-127
```

## დავალება 6. `failurePolicy: Fail` და განსხვავება გარეშე webhook-სგან

ცალსახად ვაყენებთ `failurePolicy: Fail`-ს პირველ პოლიტიკაზე (ეს ნაგულისხმევია, მაგრამ
ცალსახად ვცხადებთ):

```bash
kubectl patch validatingadmissionpolicy disallow-latest-tag --type merge \
  -p '{"spec":{"failurePolicy":"Fail"}}'

kubectl get validatingadmissionpolicy disallow-latest-tag -o jsonpath='{.spec.failurePolicy}'
```

`failurePolicy` რეაგირებს CEL-გამოსახულების გამოთვლის შეცდომაზე (მაგალითად,
მინაბლისთვის ველისადმი მიმართვას, რომელიც არ არსებობს ობიექტში API-ს ძველ ვერსიაზე),
ხოლო არა გარეშე სერვისის მიუწვდომლობაზე. ჩაშენებულ `ValidatingAdmissionPolicy`-ს
გარეშე webhook სულ არ აქვს - CEL ითვლება პირდაპირ apiserver-ის შიგნით, ამიტომ მას არ
აქვს "webhook-მა არ უპასუხა და admission გაჩერდა" რისკი, დამახასიათებელი
Kyverno-სთვის და Gatekeeper-ისთვის (მათთან წესებს ასრულებს ცალკე სერვისი webhook-ის
მიღმა, და თუ ის მიუწვდომელია, `failurePolicy: Fail` მოთხოვნებს ჩერდება ან ბლოკავს).

ვინახავთ განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/failurepolicy.txt <<'EOF'
failurePolicy ValidatingAdmissionPolicy-ში რეაგირებს მხოლოდ CEL-გამოსახულების
გამოთვლის შეცდომაზე (მაგალითად, ობიექტში არარსებული ველისადმი მიმართვას), ხოლო არა
გარეშე სერვისის მიუწვდომლობაზე.

ჩაშენებულ ValidatingAdmissionPolicy-ს გარეშე webhook სულ არ აქვს: CEL-გამოსახულება
ითვლება პირდაპირ apiserver-ის შიგნით, გარეშე ქსელური გამოძახების გარეშე. ამიტომ აქ არ
არსებობს "webhook-მა არ უპასუხა" რისკი, დამახასიათებელი
Kyverno-სთვის და Gatekeeper-ისთვის, სადაც წესებს ასრულებს ცალკე სერვისი webhook-ის
მიღმა, ხოლო apiserver ელოდება მის პასუხს.
EOF
cat /var/work/tests/artifacts/6/failurepolicy.txt
```

## სწრაფი შემოწმება

```bash
check_result
```

სასარგებლო ბრძანებები პოლიტიკების მდგომარეობის გასარკვევად:

```bash
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding
kubectl get validatingadmissionpolicy disallow-latest-tag -o yaml
```
