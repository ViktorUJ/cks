[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 - ეტალონური ამოხსნა: Pod Security Admission და read-only root filesystem

> შეასრულეთ ბრძანებები სამუშაო მანქანაზე. კონტექსტი `cluster1-admin@cluster1` უკვე
> გამართულია. Namespace `psa-restricted-107`, `psa-observe-107` და `psa-controller-107` შექმნილია საწყისი
> სკრიპტით, მაგრამ განზრახ PSA labels არ აქვთ.

## 1. Enforce restricted და უარყოფის შემოწმება

PSA ამოქმედებს Pod Security Standards-ს namespace-ის labels-ით. დავაფიქსიროთ სტანდარტის
ვერსია, რათა ქცევა Kubernetes-ის მომავალი განახლებით არ შეიცვალოს:

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

ვამოწმებთ admission-ს სახიფათო ობიექტის შენახვის გარეშე. `hostNetwork` აკრძალულია დონით
`restricted`, ამიტომ ბრძანება აუცილებლად უნდა დასრულდეს შეცდომით `violates PodSecurity`:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-by-restricted
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
YAML
```

## 2 და 5. Hardened Pod და writable emptyDir

შექმენით Pod მაშინვე საბოლოო უსაფრთხო ფორმით. დონე `restricted` მოითხოვს
non-root-ს, seccomp-ს, escalation-ის აკრძალვას და capabilities-ის გადაგდებას. Read-only root filesystem
ამცირებს კონტეინერში ჩაწერის შედეგებს; აპლიკაციას მხოლოდ `/tmp` რჩება
`emptyDir`-ში.

```yaml
# restricted-app.yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-app
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir:
      medium: Memory
```

```bash
kubectl apply -f restricted-app.yaml
kubectl get pod restricted-app -n psa-restricted-107
```

დაამტკიცეთ ორივე შედეგი ცოცხალი გამოძახებით, და არა მხოლოდ YAML-ის კითხვით: კონტეინერი მუშაობს
`runAsUser: 1000`-ით read-only root-ით, ამიტომ `/tmp`-ის გარეთ ჩაწერა აუცილებლად უნდა დასრულდეს
ფაილური სისტემის შეცდომით, ხოლო მიმაგრებულ `emptyDir`-ში ჩაწერა - გავიდეს:

```bash
kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'touch /root-write-test.txt'
# touch: /root-write-test.txt: Read-only file system

kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'echo probe > /tmp/test.txt && cat /tmp/test.txt'
# probe
```

თუ `restricted-app` უკვე შექმნილია read-only filesystem-ის გარეშე, Pod-ის ველის შეცვლა არ შეიძლება;
წაშალეთ და თავიდან შექმენით (თუ ამას უკვე დავალება 6-ის შემდეგ აკეთებთ, დაამატეთ `spec`-ში
ველი `automountServiceAccountToken: false` - წინააღმდეგ შემთხვევაში დავალება 6-ის პოლიტიკა Pod-ს უარყოფს):

```bash
kubectl delete pod restricted-app -n psa-restricted-107
kubectl apply -f restricted-app.yaml
```

## 3. Audit და warn baseline-ისთვის

ეს რეჟიმები მოთხოვნას არ კრძალავენ. `warn` კლიენტს გაფრთხილებას უბრუნებს, ხოლო `audit`
API server-ის audit event-ში ამატებს annotation-ს
`pod-security.kubernetes.io/audit-violations`. ეტაპობრივი დანერგვისთვის
`enforce` დაკვირვების namespace-ში ნუ დააყენებთ:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36
```

> **ვერსიის შენიშვნა.** `v1.36` დაფიქსირებულია Kubernetes 1.36.0-ისთვის ამ სასწავლო
> ინფრასტრუქტურაში. 2026-09-06-ის მდგომარეობით ოფიციალური CKS ორიენტირებულია `v1.35`-ზე; ეს
> forward-looking მაგალითია, ხოლო გამოცდისთვის მომზადებისას გამოიყენეთ `*-version=v1.35`.

> **audit-დამტკიცების საზღვარი.** ლაბი audit-log sink-ს არ აწყობს, ამიტომ
> `pod-security.kubernetes.io/audit-violations`-ის ამოღება ბრძანებით `kubectl` შეუძლებელია.
> რეალურად შემოწმებად შედეგად ქვემოთ PSA Warning და წარმატებული admission გვევლინება; audit
> annotation განმარტებულია, მაგრამ ამ ინფრასტრუქტურის შემოწმებად artifact-ს არ წარმოადგენს.

## 4. იმის დადასტურება, რომ warn/audit Pod-ს არ ბლოკავს

ეს Pod baseline-ს არღვევს `hostNetwork`-ის გამო, მაგრამ მიიღება, რადგან namespace-ში
`enforce` არ არის. `kubectl apply` PSA-ს გაფრთხილებას გამოიტანს; production workload-ის
მიგრაციისას მას ყურადღების გარეშე ნუ დატოვებთ.

```yaml
# baseline-audit-sample.yaml
apiVersion: v1
kind: Pod
metadata:
  name: baseline-audit-sample
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f baseline-audit-sample.yaml
kubectl get pod baseline-audit-sample -n psa-observe-107
kubectl get namespace psa-restricted-107 --show-labels
kubectl get namespace psa-observe-107 --show-labels
```

## 6. Native ValidatingAdmissionPolicy Kyverno/Gatekeeper-ის გარეშე

PSA `restricted` უკვე მოითხოვს `allowPrivilegeEscalation: false`-ს და `capabilities.drop`-ს,
რომელიც შეიცავს `ALL`-ს - დავალება 2 სწორედ ამას აჩვენებს, და ეს Pod Security
Standard-ის ჩაშენებული ნაწილია, და არა ხარვეზი. მაგრამ PSS `restricted` `automountServiceAccountToken`-ს **არ ამოწმებს**:
Pod-მა შეიძლება ჩუმად მიიღოს მიმაგრებული ServiceAccount token და PSA სრულად გაიაროს. ამ
ცალკე, რეალურად დაუფარავი control-ისთვის სწორედ custom `ValidatingAdmissionPolicy` არის მისაღები.

```yaml
# require-no-automount-token.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-no-automount-token
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: >-
      has(object.spec.automountServiceAccountToken) &&
      object.spec.automountServiceAccountToken == false
    message: "spec.automountServiceAccountToken must be explicitly set to false"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-no-automount-token-binding
spec:
  policyName: require-no-automount-token
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: psa-restricted-107
```

```bash
kubectl apply -f require-no-automount-token.yaml
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
```

დაამტკიცეთ სამივე მდგომარეობა server-side dry-run-ით, მუდმივი Pod-ის შენახვის გარეშე. Pod-მა ველის
გარეშე უნდა მიიღოს DENY policy + binding-ის ზუსტი წყვილისგან, `false` უნდა გაიაროს, ხოლო
`true` უნდა მიიღოს DENY იმავე წყვილისგან. პირველი Pod
სრულად შეესაბამება PSA `restricted`-ს (non-root, seccomp, `allowPrivilegeEscalation:
false`, `capabilities.drop: ["ALL"]`) - PSA თავად მიიღებდა მას, ამიტომ უარყოფა
სწორედ ახალი policy-სგან უნდა მოვიდეს, და არა `violates PodSecurity`-სგან:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-unsafe-check
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
# Error from server: ... ValidatingAdmissionPolicy 'require-no-automount-token'
# with binding 'require-no-automount-token-binding' denied request: ...
```

იგივე Pod დამატებული `automountServiceAccountToken: false`-ით უნდა გაიაროს:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-safe-check
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
```

ცხადი მნიშვნელობა `true`-ც უნდა უარყოფილ იქნეს იმავე policy-ისა და binding-ის მიერ:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-explicit-true-check
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
# Error from server: ... ValidatingAdmissionPolicy 'require-no-automount-token'
# with binding 'require-no-automount-token-binding' denied request: ...
```

`Binding.matchResources.namespaceSelector` policy-ს მხოლოდ `psa-restricted-107`-ით ზღუდავს:
Pod-ები სხვა namespace-ებში (მაგალითად `psa-observe-107`) ამ წესით არ მოწმდება და
ზედმეტ Deny-ს არ იღებს.

## 7. Controller-driven admission denial

ჯერ მარტივი, hardening-ის გარეშე Deployment - PSA ჯერ enforce არ არის, ყველაფერი გადის:

```bash
kubectl -n psa-controller-107 create deployment controller-app --image=busybox:1.36 -- sh -c "sleep 3600"
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

ვრთავთ enforce-ს - არსებულ Pod-ს არაფერი ემართება:

```bash
kubectl label namespace psa-controller-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
kubectl -n psa-controller-107 get pod
# controller-app-xxxx ჯერ კიდევ Running-ია - PSA უკვე არსებულ ობიექტებზე არ მოქმედებს
```

ვშლით Pod-ს - ReplicaSet ცდილობს ჩანაცვლების შექმნას და უარს იღებს:

```bash
kubectl -n psa-controller-107 delete pod -l app=controller-app
kubectl -n psa-controller-107 get events --sort-by=.lastTimestamp | tail -5
# ... FailedCreate ... violates PodSecurity "restricted:v1.36": ...
kubectl -n psa-controller-107 get deploy controller-app
# controller-app   0/1     1            0           ...   <- READY 0/1, AVAILABLE 0
```

ვასწორებთ template-ს - ვამატებთ იგივე hardening ველებს, რაც დავალება 2-ში:

```bash
kubectl -n psa-controller-107 edit deployment controller-app
```

`spec.template.spec`-ში ჩაანაცვლეთ სტრიქონი `securityContext: {}` ქვემოთ მოცემული ბლოკით, ხოლო კონტეინერში `busybox`
(კონტეინერის სახელია `busybox`, შექმნილია `kubectl create deployment`-ით) დაამატეთ თქვენი `securityContext`:

```yaml
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: busybox
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
```

შეინახეთ და დაელოდეთ rollout-ს:

```bash
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

```
deployment "controller-app" successfully rolled out
```

```bash
check_result
```
