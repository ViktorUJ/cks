[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 108 - Admission policies Kyverno-ით

## მიზანი

ამ CKS-ლაბში თქვენ დააყენებთ Kyverno-ს და დაიცავთ namespace `policy-108`-ს policy-as-code
წესებით. პრაქტიკა მოიცავს validating admission-ს: ტეგ `latest`-ის აკრძალვა, სავალდებულო
`runAsNonRoot`, registry allowlist; ბოლო, არასავალდებულო ეტაპზე - Pod-ის mutation
admission-ისას. დავალება 6 ამ მიდგომას ადარებს სხვა მექანიზმს - ჩაშენებულ
`ImagePolicyWebhook`-ს, სადაც image-ის შესახებ გადაწყვეტილებას გარე HTTP(S)-backend იღებს API
`ImageReview`-ის გავლით, და არა CEL-გამოსახულება კლასტერის შიგნით. ფინალური დავალება 7 - მესამე, ცალკე admission
engine: **Gatekeeper (OPA/Rego)**, სადაც თქვენ ასწორებთ უკვე განთავსებულ, მაგრამ არასრულ
policy-ს, და არ წერთ CEL-ს Kyverno-ს შიგნით. იმუშავეთ მხოლოდ იმ ობიექტებთან და სახელებთან, რომლებიც მითითებულია
დავალებებში.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რატომ არ ხურავს მხოლოდ აშკარა ტეგ `:latest`-ის აკრძალვა mutable-tag-ის მთელ რისკს?</summary>

თუ image მითითებულია ტეგის გარეშე საერთოდ (მაგალითად, `nginx`), Docker/OCI მას ნაგულისხმევად resolve-ს უკეთებს როგორც `nginx:latest` - implicit latest. Policy, რომელიც ამოწმებს მხოლოდ სტრიქონ `:latest`-ის სიტყვასიტყვით დამთხვევას, ასეთ image-ს გაატარებს, თუმცა სემანტიკურად ეს იგივეა, რაც აშკარა `:latest`. სწორმა policy-მ უნდა უარყოს როგორც აშკარა, ისე implicit latest - ან მოითხოვოს აშკარა versioned tag/digest.
</details>

<details>
<summary>2. რატომ უნდა შეამოწმოს validating policy-მ `ephemeralContainers` `containers`/`initContainers`-ისგან ცალკე?</summary>

`kubectl debug` ამატებს ephemeral container-ს უკვე არსებულ Pod-ში ცალკე subresource API-ით (`pods/ephemeralcontainers`), და არა Pod-ის ჩვეულებრივი CREATE/UPDATE-ით. თუ policy ემთხვევა მხოლოდ რესურს `pods`-ს ამ subresource-ის აშკარა ჩართვის გარეშე, შეუმოწმებელი/untrusted ephemeral container-ის დამატების ცდამ შეიძლება ჩვეულებრივი containers-ისთვის დაწერილი ყველა validating policy-ის გვერდით ჩაუაროს.
</details>

<details>
<summary>3. რა პრინციპული განსხვავებაა `ValidatingPolicy`-სა და `MutatingPolicy`-ს შორის Kyverno-ში?</summary>

`ValidatingPolicy` მხოლოდ ამოწმებს მოთხოვნას და ან უშვებს, ან უარყოფს მას (Allow/Deny) - ობიექტი არ იცვლება. `MutatingPolicy` ობიექტს ცვლის შენახვამდე (ამატებს/ცვლის ველებს, მაგალითად label-ს) - მოთხოვნა მაინც გადის, მაგრამ შეცვლილი შიგთავსით. დავალება 5 იყენებს mutation-ს სწორედ იმიტომ, რომ მიზანია label-ის ავტომატურად დამატება, და არა Pod-ის უარყოფა.
</details>

## ინფრასტრუქტურა

გარემო განთავსდება Terragrunt-ით AWS `eu-central-1`-ში:

| კომპონენტი | დანიშნულება |
|---|---|
| `vpc` | VPC `10.10.0.0/16` საჯარო ქვექსელებით |
| `ssh-keys` | გასაღებები node-ებზე წვდომისთვის |
| `k8s-1` | ერთკვანძიანი kubeadm-კლასტერი Kubernetes `1.36.0`, containerd და **Calico** |
| `worker` | სამუშაო მანქანა `kubectl`-ით, Helm-ით და `/usr/local/bin/install-kyverno`-ით |

Control-plane ჩვეულებრივ Pod-ებს უშვებს, ამიტომ ცალკე Kubernetes worker არ იქმნება.
Kyverno საწყის მდგომარეობაში განზრახ **არ არის დაყენებული**: ეს დავალება 1-ის ნაწილია.
სამუშაო მანქანაზე მომზადებულია დაფიქსირებული installer, რომელიც chart-ის ხელით შერჩევას არ მოითხოვს.
ლაბი აფიქსირებს Kyverno `1.19`-ს (Helm chart `3.9.0`) და იყენებს სტაბილურ CEL-based API-ს
`policies.kyverno.io/v1`. Legacy `Policy`/`ClusterPolicy` `kyverno.io/v1`-ში ამ ვერსიიდან
deprecated-ია და განიხილება მხოლოდ როგორც migration material.

Kyverno-სგან განსხვავებით, **Gatekeeper (OPA) დავალება 7-ისთვის უკვე დაყენებულია** კლასტერის
bootstrap-ით, საწყისი (განზრახ არასრული) `ConstraintTemplate`-ისა და `Constraint`-ის ჩათვლით.
ეს სპეციალურად არის გაკეთებული: დავალება 7 ამოწმებს უნარს, იპოვოთ და დაამატოთ Rego უკვე
არსებულ `ConstraintTemplate`-ში, და არა admission engine-ის ნულიდან დაყენებას - ამ ნაწილს
უკვე დავალება 1 ავარჯიშებს Kyverno-სთვის. დავალება 7 მუშაობს ცალკე namespace-ში
`gatekeeper-108`, Kyverno-ს დავალებებისგან 1-5 (`policy-108`) იზოლირებულში, რათა Pod ერთდროულად ორი განსხვავებული admission engine-ის მიერ
ვერ იქნეს უარყოფილი.

## განთავსება

```bash
TASK=108 make run_cks_task
```

დაუკავშირდით სამუშაო მანქანას SSH-ით. კონტექსტი `cluster1-admin@cluster1` უკვე გამართულია.

```bash
time_left
check_result
```

## დავალებები

---
| **1** | **Kyverno-ს დაყენება** |
| :---: | :--- |
| რას ვაკეთებთ | • დააყენეთ Kyverno namespace `kyverno`-ში.<br/>• გამოიყენეთ worker-ზე მომზადებული ბრძანება `/usr/local/bin/install-kyverno`; ის დაფიქსირებულ Helm chart-ს იყენებს.<br/>• დაელოდეთ admission controller-ის ხელმისაწვდომობას. |
| მიღების კრიტერიუმები | • კლასტერში არის CRD `validatingpolicies.policies.kyverno.io`<br/>• Kyverno-ს ვერსია - `1.19.x`<br/>• namespace `kyverno`-ს მინიმუმ ერთ Deployment-ს აქვს ხელმისაწვდომი replica |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

`/usr/local/bin/install-kyverno` უკვე დაფიქსირებულ ვერსიაზეა გამართული - Kyverno-ს `helm install`-ით ხელით სხვა chart-ით დაყენებას ნუ ცდილობთ, ამან შეიძლება CRD-ის შეუთავსებელი ვერსია გამოიწვიოს. დაყენების შემდეგ დაელოდეთ: admission controller Pod უნდა გახდეს `Available`, ეს მყისიერად არ ხდება.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

```bash
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
kubectl get deployment -n kyverno -o wide
kubectl get deployment -n kyverno -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | grep kyverno
```

პირველმა ბრძანებამ უნდა დააბრუნოს თავად CRD (და არა შეცდომა `NotFound`); image-ის ვერსია უნდა
შეიცავდეს `v1.19.`-ს; სულ მცირე ერთ Deployment-ს უნდა ჰქონდეს `AVAILABLE` `0`-ზე მეტი.
</details>

---
| **2** | **ტეგ `latest`-ით image-ის აკრძალვა** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით CEL-based `ValidatingPolicy` `deny-latest-tag` (`policies.kyverno.io/v1`) `validationActions: [Deny]`-ით.<br/>• ის უნდა ვრცელდებოდეს Pod-ზე და subresource `pods/ephemeralcontainers`-ზე namespace `policy-108`-ში.<br/>• მან უნდა უარყოს ნებისმიერი image `containers`-ში, `initContainers`-ში ან `ephemeralContainers`-ში, რომელიც არის აშკარა `:latest` ან implicit latest (image ტეგისა და digest-ის გარეშე საერთოდ). |
| მიღების კრიტერიუმები | • Policy არსებობს და Deny-რეჟიმში მუშაობს<br/>• Admission უარყოფს როგორც აშკარა `:latest`-ს, ისე implicit latest-ს (untagged) კონტეინერების სამივე სიაში, registry-პორტიანი image-ის ჩათვლით ტეგის გარეშე (`registry.example:5000/app`), ხოლო versioned trusted images-სა და digest-pinned images-ს თითოეულ სიაში იღებს<br/>• არსებული Pod-ის UPDATE-ისას `spec.containers[*].image`-ის ან `spec.initContainers[*].image`-ის `:latest`-ზე შეცვლაც უარყოფილია ამ policy-ით (ჩვეულებრივი Pod image-ველები in-place UPDATE-ს უშვებს) |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

`matchConstraints.resourceRules` უნდა ფარავდეს როგორც `pods`-ს, ისე subresource
`pods/ephemeralcontainers`-ს ცალკე - წინააღმდეგ შემთხვევაში `kubectl debug` policy-ს ჩაუვლის. თავად
CEL-ლოგიკისთვის: დაშალეთ image-ის სტრიქონი `registry/path`-ად და `tag`-ად ბოლო `:`-ით
ბოლო `/`-ის შემდეგ (`:`-ის არსებობა ბოლო `/`-მდე შეიძლება registry-ის პორტის ნაწილი იყოს, და არა
ტეგის); თუ დაშლის შემდეგ ტეგი საერთოდ არ არის - ეს implicit latest-ია; თუ ტეგი არის, მაგრამ
უდრის `latest`-ს - ესეც აკრძალული შემთხვევაა; digest (`@sha256:...`) - ცალკე, ყოველთვის
დაშვებული შემთხვევაა, ტეგს საერთოდ არ ექვემდებარება.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

Policy-ის გამოყენებამდე დარწმუნდით, რომ დამრღვევი Pod admission-ს საერთოდ გადის
(baseline) - წინააღმდეგ შემთხვევაში გაუგებარია, denial თქვენმა policy-მ გამოიწვია თუ სხვა რამემ:

```bash
# baseline: policy-ის გამოყენებამდე - უნდა გაიაროს (exit 0)
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "baseline exit: $?"
```

გამოიყენეთ policy, შემდეგ გაიმეორეთ იგივე manifest - ახლა უნდა დასრულდეს admission-ის
შეცდომით (exit არა 0), ხოლო შეტყობინება თქვენს policy-ზე უნდა მიუთითებდეს:

```bash
kubectl apply -f deny-latest-tag.yaml   # თქვენი policy-ფაილი
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "after-policy exit: $?"
```

გაიმეორეთ იგივე baseline→apply→probe→compare ციკლი: image ტეგის გარეშე საერთოდ
(`registry.k8s.io/pause`), `registry.example:5000/app` (ორწერტილი ბოლო `/`-მდე - ეს registry-ის პორტია, და არა ტეგი), `:latest` `initContainers`-ში, და `:latest`/untagged
`kubectl debug --image=...`-ით უკვე გაშვებულ დაშვებულ Pod-ზე (`pods/ephemeralcontainers`
subresource). და ბოლოს, შეამოწმეთ positive control - versioned tag უნდა გადიოდეს
policy-ის გამოყენების შემდეგაც, და არა მხოლოდ მანამდე.
</details>

---
| **3** | **root-ის გარეშე გაშვების მოთხოვნა** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით CEL-based `ValidatingPolicy` `require-run-as-non-root` Deny-რეჟიმში.<br/>• `policy-108`-ში ყოველი Pod-ისთვის ველი `spec.securityContext.runAsNonRoot` აშკარად უნდა უდრიდეს `true`-ს.<br/>• Pod-ისა და ყველა კონტეინერის დონეზე აკრძალულია `runAsUser: 0` და container-level `runAsNonRoot: false`: კონტეინერის პარამეტრებს Pod-level securityContext-ის გადაფარვა შეუძლიათ. |
| მიღების კრიტერიუმები | • Policy არსებობს და Deny-ა<br/>• Pod `runAsNonRoot: false`-ით ან ამ ველის გარეშე, Pod-level `runAsUser: 0`, ასევე კონტეინერი `runAsNonRoot: false` / `runAsUser: 0`-ით `containers`-ში, `initContainers`-ში, `ephemeralContainers`-ში უარყოფილია სწორედ ამ policy-ით<br/>• უსაფრთხო explicit container-level `runAsNonRoot: true`, `runAsUser: 1000` მიიღება |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

შეამოწმეთ სწორედ აშკარა მნიშვნელობა `true`, და არა "`false`-ის არარსებობა" - CEL-გამოსახულება `object.spec.securityContext.runAsNonRoot == true` არ გაივლის, თუ ველი საერთოდ არ არის მითითებული (`null != true`), და ეს აქ საჭიროა: დავალება უარყოფს როგორც აშკარა `false`-ს, ისე არარსებულ ველს - უნდა იყოს denied ორივე შემთხვევა, და არა მხოლოდ აშკარა `false`.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

```bash
# baseline: policy-ის გამოყენებამდე ორივე ვარიანტი უნდა გაიაროს
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-false
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-unset
  namespace: policy-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

გამოიყენეთ policy და გაიმეორეთ ორივე manifest - ორივე ახლა admission-ის შეცდომით უნდა დასრულდეს.
შემდეგ შეამოწმეთ positive control: იგივე Pod, მაგრამ
`runAsNonRoot: true`-თ აშკარად, უნდა გადიოდეს policy-ის გამოყენების შემდეგაც.
</details>

---
| **4** | **Container registry allowlist** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით CEL-based `ValidatingPolicy` `allow-approved-registries` Deny-რეჟიმში.<br/>• თითოეული კონტეინერისთვის (`containers`, `initContainers`, `ephemeralContainers`) დაუშვით მხოლოდ `registry.k8s.io/*` ან `ghcr.io/cks-lab/*`.<br/>• დანარჩენი image registry აკრძალეთ. |
| მიღების კრიტერიუმები | • Policy არსებობს და Deny-ა<br/>• Untrusted image უარყოფილია სამივე სიაში<br/>• ორივე approved prefixes (`registry.k8s.io/` და `ghcr.io/cks-lab/`) დაშვებულია სამივე სიიდან თითოეულში<br/>• ჩვეულებრივი Pod UPDATE, რომელიც image-ს unapproved registry-ზე ცვლის, უარყოფილია თავად policy-ით<br/>• მოწმდება ასევე სხვა unapproved registry და host/path-lookalikes init/ephemeral სიებში |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

`startsWith('registry.k8s.io/')` - პრეფიქსის ყველაზე საიმედო შემოწმებაა, მაგრამ დარწმუნდით, რომ ორივე დაშვებული registry მოწმდება OR-ით (ორიდან ნებისმიერი გამოდგება), და არა AND-ით (ორივე ერთდროულად, რაც ერთი image-ისთვის შეუძლებელია). შეამოწმეთ სწორედ ALLOWLIST (image დაიშვება მხოლოდ იმ შემთხვევაში, თუ ორიდან ერთ-ერთ პრეფიქსს დაემთხვა), და არა კონკრეტულად `docker.io`-ს denylist - policy, დაწერილი როგორც "თუ `docker.io` - deny, სხვა შემთხვევაში allow", გაატარებს `quay.io`-ს, unqualified images-სა და ნებისმიერ სხვა მესამე მხარის registry-ს. დარწმუნდით ასევე, რომ პრეფიქსი შედარებულია დამასრულებელ `/`-თან ერთად (`registry.k8s.io/`, და არა უბრალოდ `registry.k8s.io`), წინააღმდეგ შემთხვევაში მსგავსი დაწერილობის host (`registry.k8s.io.evil.example`) შეიძლება case-insensitive ან არასრული დამთხვევით გაიაროს. როგორც დავალება 2-ში, არ დაგავიწყდეთ `ephemeralContainers` - ეს კონტეინერების სამი სიის შემოწმების იგივე პატერნია.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

```bash
# baseline: policy-ის გამოყენებამდე - untrusted registry უნდა გაიაროს
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF
```

გამოიყენეთ policy, გაიმეორეთ იგივე manifest - ახლა უნდა იყოს denied. ეს ერთი
კონკრეტული untrusted-მნიშვნელობაა (`docker.io`), და არა სრულფასოვანი
allowlist-ის დამტკიცება - policy, რომელიც უბრალოდ სიტყვასიტყვით კრძალავს `docker.io`-ს, მაგრამ გაატარებს,
მაგალითად, unqualified image-ს (implicit Docker Hub აშკარა host-ის გარეშე), `quay.io`-ს ან
მსგავსი დაწერილობის host-ს (`registry.k8s.io.evil.example`), ამ ერთ
შემოწმებასაც გაივლის. გაიმეორეთ იგივე baseline→apply→probe→compare მინიმუმ: unqualified
image-ისთვის (`busybox:1.36` host-ის გარეშე საერთოდ), სხვა აშკარა მესამე მხარის registry-სთვის
(`quay.io/...`), მსგავსი დაწერილობის host/path-ისთვის (`registry.k8s.io.evil.example/...`,
`ghcr.io/cks-lab.evil/...`), untrusted image-ისთვის `initContainers`-ში, და untrusted/trusted
image-ისთვის `kubectl debug`-ით უკვე გაშვებულ დაშვებულ Pod-ზე. და ბოლოს, positive control: Pod ორივე კონტეინერით (main + init)
`registry.k8s.io`/`ghcr.io/cks-lab`-დან უნდა გადიოდეს; შეამოწმეთ ასევე `ghcr.io/cks-lab/*`
init- და ephemeral-კონტეინერებში, და არა მხოლოდ `containers`-ში.
</details>

---
| **5** | **არასავალდებულო: label-ის mutate Kyverno-ით** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით CEL-based `MutatingPolicy` `add-kyverno-managed-label` (`policies.kyverno.io/v1`), რომელიც namespace `policy-108`-ის Pod-ებს უმატებს label-ს `security.cks.io/managed-by: kyverno`, თუ ის არ არის.<br/>• გამოიყენეთ mutation, და არა validation.<br/>• სხვა namespace-ების Pod-ებს ნუ მუტირებთ. |
| მიღების კრიტერიუმები | • Server-side dry-run-ისას Pod, დაშვებული registry-თი და `runAsNonRoot: true`-ით, რომელსაც ეს label ჯერ არ აქვს, mutation-ის შემდეგ იღებს მას მნიშვნელობით `kyverno`<br/>• Pod, რომელსაც label უკვე სხვა მნიშვნელობით აქვს მითითებული, საწყის მნიშვნელობას ინარჩუნებს<br/>• Pod `default`-ში ამ label-ის გარეშე რჩება<br/>• ეს ეტაპი `check_result`-ში ჩანს, მაგრამ მისი გამოტოვება დასაშვებია |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

ეს ეტაპი არასავალდებულოა - თუ დრო ამოგეწურათ, შეგიძლიათ ის გამოტოვოთ ლაბის დანარჩენი ნაწილისთვის რისკის გარეშე. Mutation-ის შესამოწმებელი სატესტო Pod უკვე უნდა გადიოდეს დავალებების 2-4 policies-ს (trusted registry, non-root) - თუ ის თავად წინა policy-ებიდან ერთ-ერთით უარყოფილი იქნება, mutation-ის შედეგს საერთოდ ვერ დაინახავთ. «თუ ის არ არის» დავალებაში - უბრალოდ სურვილი არ არის: mutation-მა აშკარად უნდა შეამოწმოს label-ის არსებობა და ობიექტს არ შეეხოს, თუ ის უკვე არსებობს, წინააღმდეგ შემთხვევაში დავალება შესრულებული არ არის, თუნდაც label-ის გარეშე Pod სწორ მნიშვნელობას იღებდეს.
</details>

---
| **6** | **ImagePolicyWebhook: გარე backend CEL policy-ის ნაცვლად** |
| :---: | :--- |
| რას ვაკეთებთ | • სამუშაო მანქანაზე უკვე მომზადებულია `/opt/image-policy-backend/server.py` - მინიმალური HTTPS-სერვერი, რომელიც `ImageReview` API-ს ახორციელებს (უარყოფს image-ს ტეგით `:latest` ან ტეგის გარეშე საერთოდ).<br/>• განათავსეთ ის როგორც Deployment namespace `image-policy`-ში, Service `image-policy-backend`-ის უკან პორტზე `8443`. Backend-მა უნდა მიიღოს კავშირები TLS-ით (upstream `ImagePolicyWebhook` კონტრაქტი HTTPS-ს მოითხოვს, plain HTTP არ არის მხარდაჭერილი).<br/>• `control-plane`-ზე (`ssh`, შემდეგ `sudo -i`) გამართეთ `AdmissionConfiguration` plugin `ImagePolicyWebhook`-ისთვის (`defaultAllow: false`) და kubeconfig, რომელიც თქვენს backend-ზე მიუთითებს.<br/>• static manifest `kube-apiserver.yaml`-ში **დაამატეთ** `ImagePolicyWebhook` უკვე არსებულ სიაზე `--enable-admission-plugins` (სიას მთლიანად ნუ ჩაანაცვლებთ - წინააღმდეგ შემთხვევაში რისკავთ, გამორთოთ უკვე ჩართული plugins) და ჩართეთ `--runtime-config=imagepolicy.k8s.io/v1alpha1=true`.<br/>• API-ს აღდგენის შემდეგ შექმენით Pod `:latest`-ით - უნდა იყოს უარყოფილი; შემდეგ Pod დაფიქსირებული ტეგით - უნდა შეიქმნას. |
| მიღების კრიტერიუმები | • `image-policy-backend` Available-ა<br/>• Kube-apiserver healthy-ა დამატებული (და არა ჩანაცვლებული) plugin-ით და `--runtime-config`-ით<br/>• Backend-ის kubeconfig იყენებს HTTPS `https://<ClusterIP Service image-policy-backend>:8443/imagepolicy`<br/>• Pod `:latest`-ით და implicit latest-ით (მათ შორის registry-port ტეგის გარეშე) უარყოფილია სწორედ ImagePolicyWebhook-ით namespace `default`-ში - როგორც ჩვეულებრივ Pod-ში, ისე init/ephemeral container-ში<br/>• მომხმარებლის annotation `alpha.image-policy.k8s.io/break-glass: "true"` გამონაკლისს არ იძლევა<br/>• Namespace `policy-108` გამოყოფილია დავალებების 2–4 Kyverno-სთვის, რათა ორმა დამოუკიდებელმა admission-მექანიზმმა ერთმანეთის უარყოფა არ დაფაროს<br/>• ამისთვის backend `ImageReview.spec.namespace == policy-108`-ის მიხედვით გადაწყვეტილებას Kyverno-ს გადასცემს, ხოლო ყველა დანარჩენ namespace-ში ImagePolicyWebhook აგრძელებს მუშაობას<br/>• Pod დაფიქსირებული ტეგით შექმნილია და Running-ია<br/>• Service backend outage-ის დროს მართლაც კარგავს Endpoints-ს, API უარს ამბობს ამ endpoint-ის მიუწვდომლობის გამო (`defaultAllow: false`), შემდეგ Service selector და admission ზუსტად საწყის მდგომარეობაში აღდგება |

<details>
<summary>💡 მინიშნება დავალება 6-ისთვის</summary>

`ImagePolicyWebhook` - პრინციპულად სხვა მექანიზმია, ვიდრე Kyverno დავალებებიდან 1-5: გადაწყვეტილებას გარე HTTPS-backend იღებს API `ImageReview`-ის გავლით, და არა CEL-გამოსახულება კლასტერის შიგნით. გამოიყენეთ მზა `/opt/image-policy-backend/server.py` სამუშაო მანქანიდან (მაგალითად, ჩაწყვეთ ის ConfigMap-ში backend-ის Deployment-ისთვის; `control-plane`-ზე მხოლოდ CA-სერტიფიკატის დაკოპირებაა საჭირო webhook-ის kubeconfig-ისთვის) - დავალება ამოწმებს admission plugin-ის wiring-ის, TLS-კონტრაქტისა და ImageReview API-ის გაგებას, და არა HTTP-სერვერის ნულიდან წერის უნარს. TLS-ისთვის: ჯერ შექმენით Service (რომ გაიგოთ `ClusterIP`), შემდეგ თვითხელმოწერილი სერტიფიკატი ამ IP-ით SAN-ში (`openssl req -x509 -newkey ... -addext "subjectAltName=IP:<ClusterIP>"`), შემდეგ Deployment, რომელიც ამაგრებს როგორც კოდს, ისე სერტიფიკატს. არსებულ `--enable-admission-plugins`-ს ახალი მნიშვნელობით მთლიანად ნუ ჩაანაცვლებთ - მიუწერეთ `ImagePolicyWebhook` მძიმით უკვე ჩართულ plugins-ს (ჩვეულებრივ იქ უკვე არის `NodeRestriction`). ასევე არ დაგავიწყდეთ `--runtime-config=imagepolicy.k8s.io/v1alpha1=true` - ამ API-ს აშკარა ჩართვის გარეშე backend საერთოდ არ გამოიძახება. Namespace `image-policy` წინასწარ შექმნილი არ არის - შექმენით ის თავად Deployment/Service-მდე. თუ რესურსების/გზების/ფლაგების დეტალურ თანმიმდევრობაში გაიჭედეთ - ეტალონური მოქმედებების თანმიმდევრობა ამოხსნაშია მოცემული.
</details>

---
| **7** | **Gatekeeper ConstraintTemplate: Rego blocklist-ის დაწერა** |
| :---: | :--- |
| რას ვაკეთებთ | • კლასტერში უკვე დაყენებულია **Gatekeeper** (OPA), ასევე `ConstraintTemplate` `k8sblockedregistries` და `Constraint` `K8sBlockedRegistries/deny-bad-registries`, შეზღუდული ცალკე namespace `gatekeeper-108`-ით (და არა `policy-108`-ით - ეს Kyverno-ს დავალებებისგან 1-5 ცალკე პოლიგონია, რათა Kyverno და Gatekeeper ერთსა და იმავე Pod-ს ერთდროულად არ უარყოფდნენ).<br/>• Rego `ConstraintTemplate`-ის შიგნით უკვე შეიცავს რამდენიმე დაბლოკილ registry-ს (`untrusted-registry.example`, `docker-fake.test`), მაგრამ **განზრახ არ შეიცავს** `very-bad-registry.test`-ს.<br/>• იპოვეთ `ConstraintTemplate.spec.targets[].rego` და დაამატეთ მასში წესი `very-bad-registry.test`-ისთვის - სწორედ Rego-ში, და არა `Constraint`-ის პარამეტრებში.<br/>• `deny-bad-registries` უკვე სრულიად სწორია და `spec.parameters`-ს საერთოდ არ იყენებს - მისი შეხება საჭირო არ არის. |
| მიღების კრიტერიუმები | • `ConstraintTemplate k8sblockedregistries` და საწყისი Constraint `K8sBlockedRegistries/deny-bad-registries` არსებობს<br/>• Rego ინარჩუნებს ორივე საწყის აქტიურ წესს (`untrusted-registry.example`, `docker-fake.test`) და შეიცავს ახალ აქტიურ წესს `very-bad-registry.test`-ისთვის<br/>• Pod ამ სამი registry-დან თითოეულით `gatekeeper-108`-ში უარყოფილია სწორედ Constraint `deny-bad-registries`-ით<br/>• Pod image-ით სანდო `registry.k8s.io`-დან გადის<br/>• Constraint რჩება Pod-only, შეზღუდულია `gatekeeper-108`-ით, parameters/selectors/exclusions-ის გარეშე<br/>• ამ ტიპის დამატებითი Constraint არ იქმნება |

<details>
<summary>💡 მინიშნება დავალება 7-ისთვის</summary>

იპოვეთ ConstraintTemplate `kubectl get constrainttemplate k8sblockedregistries -o yaml`-ით. Rego დევს `spec.targets[].rego`-ში როგორც მრავალსტრიქონიანი სტრიქონი - სწორედ ის უნდა დაარედაქტიროთ (`kubectl edit constrainttemplate k8sblockedregistries`, ან `get -o yaml` → შესწორება → `apply`). არსებული Rego დაბლოკილ registry-ს აცხადებს ცალკე ფაქტებით ფორმით `blocked_registry("untrusted-registry.example")` - დაამატეთ კიდევ ერთი ასეთი სტრიქონი `very-bad-registry.test`-ისთვის, უკვე არსებულის წაშლისა და ჩანაცვლების გარეშე. ამას ნუ აგრევთ `Constraint.spec.parameters`-თან - policy-ის ამ ვერსიაში Constraint parameters-ს საერთოდ არ იყენებს, იქ დასარედაქტირებელი არაფერია.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

Baseline - გასწორებამდე: Pod `very-bad-registry.test`-იდან უნდა გაიაროს (Rego მას ჯერ არ ფარავს),
ხოლო უკვე დაბლოკილი `untrusted-registry.example` - უარყოფილი იყოს:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad baseline exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad baseline exit: $?"
```

დაამატეთ Rego, გაიმეორეთ იგივე manifest (ახალი სახელით, ძველი Pod უკვე
"შექმნილია" dry-run-ით და არ ინახება) - ახლა მოსალოდნელია admission-ის შეცდომა
Gatekeeper-ისგან, სწორედ `k8sblockedregistries`-ზე მითითებით, ორივე registry-სთვის:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad after-fix exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad after-fix exit: $?"
```

შეამოწმეთ positive control - სანდო registry უნდა გადიოდეს გასწორების შემდეგაც:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-trusted-registry
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
echo "trusted exit: $?"
```
</details>

## შედეგის შემოწმება

სამუშაო მანქანაზე შეასრულეთ:

```bash
check_result
```

შემოწმება შეიცავს Init-ს და შვიდ ტესტს. პირველი ოთხი, მეექვსე და მეშვიდე სავალდებულოა. მეხუთე
ტესტი ასრულებს mutation-ის შემოწმებას, მაგრამ ლაბორატორიას წარუმატებლად არ ხდის, თუ optional
policy არ არის შექმნილი. დავალებები 2-4 და 7 იყენებენ `--dry-run=server`-ს, ამიტომ image-ები
არ იტვირთება და Pod-ები namespace-ში არ რჩება; დავალება 6 ამოწმებს რეალურ (არა dry-run)
admission-ს ImagePolicyWebhook-ით, ამიტომ Pod `webhook-pinned-ok` მართლაც
იქმნება.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD)

## წაშლა

```bash
TASK=108 make delete_cks_task
```

## თავსებადობა და image-ების აკრძალვის ზუსტი სემანტიკა

ლაბი აფიქსირებს Kubernetes 1.36.0-სა და Kyverno 1.19-ს ახალ
`policies.kyverno.io/v1` API-სთან გასაცნობად. ეს არის **forward-looking / unsupported combination**: Kyverno
1.19 ოფიციალურად ტესტირდება Kubernetes 1.33–1.35-თან, და არა 1.36-თან. ლაბორატორიის გარეთ გამოყენებამდე
აირჩიეთ მხარდაჭერილი ვერსიების მატრიცა და შეადარეთ release notes.

დავალება 2-ში «`latest`-ის აკრძალვის» ქვეშ იგულისხმება ასევე implicit `latest`-ის აკრძალვა: `nginx`
ტეგისა და digest-ის გარეშე ისევე დაუშვებელია, როგორც `nginx:latest`. დაშვებულია მხოლოდ image აშკარა
ტეგით, რომელიც `latest`-ისგან განსხვავდება, ან digest-ით (`@sha256:...`). ამ
კრიტერიუმის ზუსტ CEL-ლოგიკას დავალება მზა სახით არ იძლევა - იხ. მინიშნება დავალება 2-ისთვის, თუ დამატებითი
საყრდენი გჭირდებათ.
