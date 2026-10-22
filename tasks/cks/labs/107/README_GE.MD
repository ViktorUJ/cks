[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 107 - Pod Security Admission: restricted, audit/warn და read-only root filesystem

## მიზანი

ამ CKS-ლაბში თქვენ გაამართავთ ჩაშენებულ **Pod Security Admission (PSA)**-ს
namespace-ის labels-ით. production namespace-ისთვის ჩაირთვება `restricted`
`enforce` რეჟიმში, შემოწმდება სახიფათო Pod-ის უარყოფა და განთავსდება hardened Pod, რომელიც შემოწმებას გადის.
ცალკე namespace-ისთვის ჩართავთ დამკვირვებელ რეჟიმებს `audit` და `warn` დონით
`baseline`. ბოლოს კონტეინერის root filesystem გახდება read-only, ხოლო ერთადერთი
საჭირო ჩაწერა `emptyDir`-ში დაიშვება.

იმუშავეთ მხოლოდ დავალებების ობიექტებთან. კლასტერში წინასწარ შექმნილია ცარიელი namespace-ები
`psa-restricted-107`, `psa-observe-107` და `psa-controller-107`; PSA-labels და workload მათში არ არის.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რით განსხვავდება `enforce` `audit`/`warn`-ისგან Pod Security Admission-ში?</summary>

`enforce` რეალურად ბლოკავს არჩეული PSS-დონის დამრღვევი Pod-ის შექმნას - admission request შეცდომით სრულდება. `audit`/`warn` მოთხოვნას არ ბლოკავს: Pod მაინც იქმნება, მაგრამ `audit` kube-apiserver-ის audit log-ში annotation-ს ამატებს, ხოლო `warn` მომხმარებელს `kubectl apply`-ისას ტექსტურ გაფრთხილებას აჩვენებს. ეს პასუხისმგებლობის განსხვავებული დონეებია: `audit`/`warn` - დაკვირვებისთვის რეალური ბლოკირების ჩართვამდე, `enforce` - თავად დაცვა.
</details>

<details>
<summary>2. რატომ არის namespace-ისთვის საჭირო `*-version` label-ის დაფიქსირება PSS-დონესთან ერთად?</summary>

დაფიქსირებული ვერსიის (`enforce-version`) გარეშე PSA ყოველი შემოწმებისას Kubernetes-ის მიმდინარე ვერსიას გამოიყენებს - თუ კლასტერი განახლდება, `restricted`/`baseline`-ის წესების ნაკრები შეიძლება თქვენთვის შეუმჩნევლად შეიცვალოს, და Pod, რომელიც გუშინ გადიოდა, დღეს თქვენი მოქმედებების გარეშე შეიძლება უარყოფილი გახდეს. ვერსიის დაფიქსირება ქცევას პროგნოზირებადს და რეპროდუცირებადს ხდის კლასტერის მომავალი განახლებებისგან დამოუკიდებლად.
</details>

<details>
<summary>3. რატომ არ ადუბლირებს `ValidatingAdmissionPolicy` დავალება 6-დან PSA-ს, არამედ ავსებს მას?</summary>

PSS `restricted` განსაზღვრავს security-ველების ფიქსირებულ, სტანდარტიზებულ ნაკრებს (non-root, capabilities, seccomp, escalation). `automountServiceAccountToken` ამ ნაკრებში არ შედის - PSA მას საერთოდ არ ამოწმებს. ესე იგი, Pod შეიძლება სრულად თავსებადი იყოს `restricted`-თან და მაინც ჩუმად მიიღოს მიმაგრებული API-ტოკენი, რომელიც მას არ სჭირდება. Custom `ValidatingAdmissionPolicy` ხურავს სწორედ ამ ხარვეზს, იმის ჩანაცვლების ან დუბლირების ცდის გარეშე, რასაც PSA უკვე აკეთებს.
</details>

## ინფრასტრუქტურა

გარემო განთავსდება Terragrunt-ით AWS `eu-central-1`-ში:

| კომპონენტი | დანიშნულება |
|---|---|
| `vpc` | VPC `10.10.0.0/16` საჯარო ქვექსელებით |
| `ssh-keys` | SSH-გასაღებები მანქანებზე წვდომისთვის |
| `k8s-1` | ერთკვანძიანი kubeadm-კლასტერი Kubernetes `1.36.0`, containerd და **Calico** |
| `worker` | სამუშაო მანქანა `kubectl`-ით, კონტექსტით `cluster1-admin@cluster1` და `check_result`-ით |

Control-plane ჩვეულებრივ Pod-ებს იღებს, ამიტომ ცალკე Kubernetes worker-node
არ არის საჭირო. ყველა დავალება სრულდება სამუშაო მანქანაზე.

## განთავსება

```bash
TASK=107 make run_cks_task
```

დაუკავშირდით სამუშაო მანქანას SSH-ით და შეამოწმეთ წვდომა კლასტერზე:

```bash
time_left
kubectl get nodes
check_result
```

## დავალებები

---
| **1** | **Enforce restricted დაფიქსირებული ვერსიით** |
| :---: | :--- |
| რას ვაკეთებთ | namespace `psa-restricted-107`-ზე დააყენეთ `pod-security.kubernetes.io/enforce=restricted` და `pod-security.kubernetes.io/enforce-version=v1.36`. დარწმუნდით, რომ PSA მართლაც უარყოფს სახიფათო Pod-ს: Pod-ის server-side dry-run `hostNetwork: true`-ით ამ namespace-ში უნდა დასრულდეს `violates PodSecurity` შეცდომით. სისტემური namespace-ების labels ნუ შეცვლით. |
| მიღების კრიტერიუმები | ორივე enforce-label-ს აქვს ზუსტი მნიშვნელობები; სახიფათო Pod `psa-restricted-107`-ში admission-ს ვერ გადის; სისტემური namespace-ები `kube-system`, `kube-public` და `kube-node-lease` ამ ლაბორატორიის ფარგლებში არ იღებენ `pod-security.kubernetes.io/*` labels-ს. |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36` - ორივე label მყისიერად გამოიყენება, PSA-ს არაფრის გადატვირთვა არ სჭირდება. შეამოწმეთ თავი `kubectl apply --dry-run=server`-ით `hostNetwork: true`-ით - სწორედ `--dry-run=server` (და არა `client`), რადგან admission controllers, PSA-ს ჩათვლით, მხოლოდ server-side მუშაობენ.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

ჯერ baseline - labels-ის დაყენებამდე დარწმუნდით, რომ იგივე სახიფათო manifest
გადის (სხვაგვარად გაუგებარია, denial თქვენმა enforce label-მა გამოიწვია თუ რაიმე სხვამ):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "baseline exit: $?"
```

დააყენეთ ორივე label, შემდეგ გაიმეორეთ იგივე manifest - ახლა უნდა იყოს admission-ის
შეცდომა ტექსტით `violates PodSecurity`:

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "after-label exit: $?"
```
</details>

---
| **2** | **Hardened Pod, რომელიც restricted-ს გადის** |
| :---: | :--- |
| რას ვაკეთებთ | შექმენით Pod `restricted-app` `psa-restricted-107`-ში `busybox:1.36`-დან, რომელიც root-ით არ მუშაობს და მაშინვე არ სრულდება. დააყენეთ pod-level `runAsNonRoot: true`, `runAsUser: 1000` და `seccompProfile: RuntimeDefault`. container securityContext-ში აკრძალეთ privilege escalation, გადააგდეთ capability `ALL`, ცხადად დატოვეთ `privileged: false` და დააყენეთ `seccompProfile: RuntimeDefault`. |
| მიღების კრიტერიუმები | Pod მიღებულია PSA-ს მიერ და გაშვებულია; მუშაობს როგორც UID 1000/non-root, და არც ერთი container/init/ephemeral container არ გადაფარავს pod-level `runAsUser: 1000`-ს; seccomp - `RuntimeDefault`; escalation და privileged აკრძალულია; capabilities `ALL` გადაგდებულია. |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

თუ Pod admission rejection-ს იღებს - შეცდომის შეტყობინება ყურადღებით წაიკითხეთ, ის ჩვეულებრივ ასახელებს ზუსტ ნაკლულ ველს (მაგალითად, "container has no capabilities.drop"). მნიშვნელოვანი დეტალი PSS `restricted`-ის სემანტიკის შესახებ Kubernetes 1.36-ში: ის მოითხოვს ეფექტურ (არა აუცილებლად სიტყვასიტყვით გამეორებულ) დასაშვებ `seccompProfile`-ს - pod-level პროფილი (`spec.securityContext.seccompProfile.type`) შეიძლება მემკვიდრეობით გადაეცეს კონტეინერებს, რომლებსაც საკუთარი ველი არ აქვთ მითითებული, და პირიქით, container-level ველი საკმარისია, თუ ის ცხადად მითითებულია ყველა კონტეინერზე, pod-level პროფილის გარეშეც. ანუ თავად PSS სიტყვასიტყვით ორივე დონეს ერთდროულად არ მოითხოვს. **ამ ლაბში ჩვენ განზრახ გთხოვთ `RuntimeDefault` ცხადად მიუთითოთ როგორც Pod-ზე, ისე კონტეინერზე** - არა იმიტომ, რომ ამას PSS მოითხოვს, არამედ იმისთვის, რომ კონფიგურაციის ორივე დონეზე ივარჯიშოთ. ანალოგიურად `runAsUser: 1000` - ეს სწორედ ამ ლაბის explicit hardening-გადაწყვეტილებაა: PSS `restricted` კრძალავს UID `0`-ს, მაგრამ კონკრეტულად `1000`-ს არ მოითხოვს (ნებისმიერი არანულოვანი მნიშვნელობა ან ველის სრული არარსებობა თავად PSS-ისთვის დასაშვებია).
</details>

---
| **3** | **baseline-ის დამკვირვებელი რეჟიმები** |
| :---: | :--- |
| რას ვაკეთებთ | namespace `psa-observe-107`-ზე ჩართეთ PSA-ს ორივე რეჟიმი: `pod-security.kubernetes.io/audit=baseline`, `pod-security.kubernetes.io/audit-version=v1.36`, `pod-security.kubernetes.io/warn=baseline`, `pod-security.kubernetes.io/warn-version=v1.36`. `enforce` ნუ დაამატებთ: ეს namespace ბლოკირებამდე ეტაპობრივი დაკვირვებისთვისაა. |
| მიღების კრიტერიუმები | არის ოთხი audit/warn labels დონით `baseline` და ვერსიით `v1.36`; enforce-label არ არის. |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

ოთხი ცალკე label - ერთ-ერთის დავიწყება ადვილია (განსაკუთრებით `-version` ერთ-ერთი რეჟიმისთვის). შეამოწმეთ ოთხივე ერთდროულად: `kubectl get namespace psa-observe-107 -o jsonpath='{.metadata.labels}' | jq`.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

Baseline - labels-ის დაყენებამდე დამრღვევი manifest PSA-ს გაფრთხილების გარეშე უნდა გაიაროს
(namespace-ს ჯერ არ აკვირდებიან):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
```

დააყენეთ ოთხივე label, შემდეგ გაიმეორეთ იგივე manifest - ახლა `kubectl apply`
უნდა გამოიტანოს `Warning: ... would violate PodSecurity "baseline:v1.36"`, ხოლო ბრძანება
მაინც წარმატებით უნდა დასრულდეს (exit 0), და არა შეცდომით:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "exit code: $?"
```
</details>

---
| **4** | **Warn/audit legacy workload-ს არ ბლოკავს** |
| :---: | :--- |
| რას ვაკეთებთ | შექმენით `psa-observe-107`-ში Pod `baseline-audit-sample` `busybox:1.36`-დან, რომელიც მუშაობს `hostNetwork: true`-ით და ასრულებს `sleep 3600`-ს. `kubectl apply`-ისას დააფიქსირეთ PSA-ს გაფრთხილება baseline-ის დარღვევის შესახებ: Pod უნდა შეიქმნას, რადგან `warn` და `audit` თავისთავად მოთხოვნას არ კრძალავენ. |
| მიღების კრიტერიუმები | `baseline-audit-sample` არსებობს, აქვს `hostNetwork: true` და API-მ დაუშვა; namespace-ში კვლავ არ არის enforce-რეჟიმი. |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

თუ Pod არ შეიქმნა - შეამოწმეთ, შემთხვევით ხომ არ დააყენეთ `enforce` label დავალება 3-ში მხოლოდ `audit`/`warn`-ის ნაცვლად. PSA-ს Warning პირდაპირ `kubectl apply`-ის გამოტანაში ჩნდება (`Warning: would violate PodSecurity "baseline:v1.36"`), მისი ძებნა ცალკე ლოგში საჭირო არ არის.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

ეს დავალება ფაქტობრივად იმეორებს დავალება 3-ის self-check-ს, მაგრამ მუდმივი Pod-ით. `baseline-audit-sample`-ის
შექმნის შემდეგ დარწმუნდით, რომ ის მართლაც არსებობს და
`Running`/`Pending`-ია (არ უარყოფილა):

```bash
kubectl get pod baseline-audit-sample -n psa-observe-107 -o jsonpath='{.status.phase}{"\n"}{.spec.hostNetwork}'
```

შეადარეთ namespace `psa-restricted-107`-ს (დავალება 1): იგივე სახიფათო manifest იქ
უნდა იქნეს უარყოფილი, ხოლო აქ - მიღებული. განსხვავება სწორედ `enforce` label-შია, რომელიც
ერთ namespace-ს აქვს და მეორეს არ აქვს:

```bash
kubectl get namespace psa-restricted-107 psa-observe-107 --show-labels
```
</details>

---
| **5** | **Read-only root filesystem writable emptyDir-ით** |
| :---: | :--- |
| რას ვაკეთებთ | დახვეწეთ `restricted-app`: კონტეინერზე ჩართეთ `readOnlyRootFilesystem: true`. შექმენით volume `writable-tmp` ტიპით `emptyDir` (რეკომენდებულია `medium: Memory`, რათა დროებითი ფაილები node-ის დისკზე არ მოხვდეს) და მიამაგრეთ ის `/tmp`-ზე `readOnly: true`-ის გარეშე. კონტეინერს მხოლოდ ამ დროებით ტომში ჩაწერა აქვს დაშვებული; `hostPath` ნუ გამოიყენებთ. დაამტკიცეთ ორივე შედეგი Pod-ის შიგნით ცოცხალი გამოძახებით: კონტეინერის root-ში ჩაწერის ცდა (მაგალითად, `touch /root-write-test.txt`) უნდა დასრულდეს შეცდომით `Read-only file system`, ხოლო `/tmp/test.txt`-ში ჩაწერა - წარმატებით გავიდეს. Pod-ის შეუცვლელი (immutable) ველების შეცვლისას წაშალეთ და თავიდან შექმენით `restricted-app` იმავე სახელით. |
| მიღების კრიტერიუმები | კონტეინერს აქვს read-only root filesystem; `emptyDir` სახელით `writable-tmp` მიმაგრებულია `/tmp`-ზე როგორც writable; regular containers-ისთვის ეს ერთადერთი writable declarative `volumeMount`-ია, ხოლო ყველა დამატებითი `volumeMounts` read-only-ა; hardened-პარამეტრები დავალება 2-დან შენარჩუნებულია; კონტეინერის root-ში ჩაწერის ცოცხალი ცდა აბრუნებს `Read-only file system`-ს, ხოლო `/tmp/test.txt`-ში ჩაწერა წარმატებით და წასაკითხი შიგთავსით სრულდება. |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

`readOnlyRootFilesystem` იმ ველებს მიეკუთვნება, რომლებიც უკვე არსებულ Pod-ზე შეუცვლელია (immutable field) - `kubectl apply` შეცვლილი securityContext-ით შეცდომას დააბრუნებს. წაშალეთ Pod (`kubectl delete pod restricted-app`) და შექმენით თავიდან იმავე სახელით, და არსებულის ადგილზე განახლებას ნუ ცდილობთ.
</details>

---
| **6** | **Native ValidatingAdmissionPolicy: `automountServiceAccountToken: false`-ის მოთხოვნა** |
| :---: | :--- |
| რას ვაკეთებთ | • PSA `restricted` უკვე მოითხოვს `allowPrivilegeEscalation: false`-ს, `capabilities.drop`-ს, რომელიც `ALL`-ს შეიცავს, non-root-ს და seccomp-ს - დავალება 2 სწორედ ამას აჩვენებს.<br/>• მაგრამ PSS `restricted` `automountServiceAccountToken`-ს **არ ამოწმებს**: Pod-მა, რომელსაც Kubernetes API არ სჭირდება, შეიძლება ჩუმად მიიღოს მიმაგრებული ServiceAccount token და PSA სრულად გაიაროს. ეს ცალკე, PSS-ით დაუფარავი control-ია, ამიტომ აქ სწორედ custom `ValidatingAdmissionPolicy` არის მისაღები, და არა ჩაშენებული PSA-ს დუბლირება.<br/>• შექმენით `ValidatingAdmissionPolicy` `require-no-automount-token` CEL-გამოსახულებით, რომელიც Pod-ის დონეზე მოითხოვს `automountServiceAccountToken == false`-ს.<br/>• გამოიყენეთ `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding`, შეზღუდული `matchResources.namespaceSelector`-ით `psa-restricted-107`-ზე, `validationActions: [Deny]`-ით.<br/>• დაამტკიცეთ სამივე მდგომარეობა server-side dry-run-ით: სრულად PSA-თავსებადი Pod (დავალება 2-ის ყველა ველით - non-root, seccomp, drop ALL, escalation false) ველის გარეშე უნდა მიიღოს DENY policy+binding-ის ზუსტი წყვილისგან; `automountServiceAccountToken: false` უნდა მიიღოს ALLOW; `automountServiceAccountToken: true` უნდა კვლავ მიიღოს DENY იმავე წყვილისგან.<br/>• policy-ის შექმნის შემდეგ `psa-restricted-107`-ში ახალი Pod-ები (მათ შორის თავიდან შექმნილი `restricted-app`) თავად უნდა შეიცავდნენ `automountServiceAccountToken: false`-ს, წინააღმდეგ შემთხვევაში პოლიტიკა მათ უარყოფს. |
| მიღების კრიტერიუმები | • **ობიექტები:** `ValidatingAdmissionPolicy require-no-automount-token` და მისი `ValidatingAdmissionPolicyBinding` არსებობს, `validationActions` შეიცავს `Deny`-ს, Binding ემთხვევა მხოლოდ `psa-restricted-107`-ს. ლაბორატორიაში არსებობს ზუსტად ერთი Binding ამ policy-სთვის - `require-no-automount-token-binding`; ამ policy-ის დამატებითი Binding სხვა namespace-ებისთვის არ იქმნება.<br/>• **სამი მდგომარეობა:** PSA-თავსებადი Pod-ის server-side dry-run `automountServiceAccountToken: false`-ის გარეშე უარყოფილია სწორედ წყვილით `ValidatingAdmissionPolicy 'require-no-automount-token'` და `ValidatingAdmissionPolicyBinding 'require-no-automount-token-binding'` (და არა PSA-შეტყობინებით `violates PodSecurity` ან სხვა policy-ით); Pod `automountServiceAccountToken: false`-ით მიღებულია, ხოლო Pod `automountServiceAccountToken: true`-ით უარყოფილია იმავე ზუსტი წყვილით.<br/>• **ყველა Pod-ის დაფარვა:** policy ფარავს ყველა Pod-ს, რომელიც მისმა `resourceRules`-მა აირჩია, `psa-restricted-107`-ის შიგნით. `ValidatingAdmissionPolicy`-ში ნუ დაამატებთ `spec.matchConditions`-ს, `matchConstraints.objectSelector`-ს ან `matchConstraints.namespaceSelector`-ს, ასევე Binding `matchResources`-ში `objectSelector`-ს - ისინი coverage-ს Pod-ების ნაწილამდე ავიწროებენ, და workload შეიძლება label-ით ან მოთხოვნის პირობით შემოწმებიდან ამოვარდეს.<br/>• **Namespace scope:** განისაზღვრება მხოლოდ Binding `matchResources.namespaceSelector`-ით, ზუსტად მიბმულით `psa-restricted-107`-ზე; selector არ შეიცავს პირობებს სხვა namespace-label keys-ზე და თავისთავად ცალსახად ზღუდავს scope-ს ამ namespace-ით.<br/>• **CEL:** validation არ შეიცავს გამონაკლისებს Pod-ის სახელით/labels-ით/annotations-ით, user/request-ით, `namespaceObject`-ით, `params`-ით, `variables`-ით ან სხვა ველებით: გადაწყვეტილება დამოკიდებულია მხოლოდ `object.spec.automountServiceAccountToken`-ზე (დასაშვებია ნებისმიერი სწორი CEL-ფორმა, მათ შორის optional-სინტაქსი `object.spec.?automountServiceAccountToken.orValue(true) == false`). `spec.auditAnnotations` არ არის ან ცარიელია: მის ცალკეულ CEL expressions-ს `failurePolicy`-ის მეშვეობით შეუძლია admission-ზე გავლენის მოხდენა, ამიტომ admission control მიეთითება მხოლოდ `spec.validations`-ით. `variables` და `paramKind` არ გამოიყენება.<br/>• **Resource scope:** `matchConstraints.resourceRules` policy-ს ზუსტად `core/v1 pods`-ით ზღუდავს ოპერაციებისთვის `CREATE` და `UPDATE`, `resourceNames`-ის გარეშე; `scope` არ არის, უდრის `*`-ს ან `Namespaced`-ს, მაგრამ არა `Cluster`-ს; `excludeResourceRules` არ გამოიყენება. Binding resource/operation scope-ს თავისი `resourceRules`/`excludeResourceRules`-ით არ ავიწროებს.<br/>• ეს საშუალებას იძლევა სრული boolean contract სამი მდგომარეობით `missing / false / true` დამტკიცდეს, და არა რამდენიმე არჩეული workload-მაგალითით. |

<details>
<summary>💡 მინიშნება დავალება 6-ისთვის</summary>

ამ დავალების სატესტო Pod სრულად PSA-თავსებადი უნდა იყოს (დავალება 2-ის ყველა ველი), გარდა არარსებული `automountServiceAccountToken: false`-ისა - თუ სატესტო Pod ერთდროულად PSS-ს და თქვენს ახალ policy-ს არღვევს, ვერ დაამტკიცებთ, რომ სწორედ თქვენმა policy-მ იმუშავა, და არა ჩაშენებულმა PSA-მ. `ValidatingAdmissionPolicyBinding` `matchResources.namespaceSelector`-ის გარეშე მთელ კლასტერზე გავრცელდება - აუცილებლად შეზღუდეთ scope ზუსტად ერთი namespace `psa-restricted-107`-ით (მაგალითად `matchLabels: {kubernetes.io/metadata.name: psa-restricted-107}`-ით), და არა `matchExpressions`-ით რამდენიმე მნიშვნელობით, სადაც `psa-restricted-107` რამდენიმე დამთხვევადი namespace-იდან მხოლოდ ერთია: თუ თქვენი selector შემთხვევით `psa-observe-107`-საც ემთხვევა, იგივე წესი იქაც მოულოდნელად დაიწყებს მოქმედებას.
</details>

<details>
<summary>🔍 შეამოწმეთ თავი `check_result`-მდე</summary>

Baseline - VAP/Binding-ის შექმნამდე იგივე PSA-თავსებადი, მაგრამ automount opt-out-ის გარეშე
Pod უნდა გაიაროს (PSA თავად მას არ უარყოფს, `automountServiceAccountToken` PSS-ში არ შედის):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
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
EOF
echo "baseline exit: $?"
```

შექმენით VAP + Binding და გაიმეორეთ manifest ველის გარეშე - ახლა მოთხოვნამ უნდა მიიღოს
DENY სწორედ `ValidatingAdmissionPolicy 'require-no-automount-token'`-ისგან binding-ით
`require-no-automount-token-binding`, და არა PSA-სგან. შემდეგ შეამოწმეთ ორივე ცხადი მნიშვნელობა:
`false` უნდა გაიაროს, ხოლო `true` უნდა მიიღოს DENY იმავე ზუსტი წყვილისგან.

```bash
kubectl apply -f require-no-automount-token.yaml   # თქვენი VAP + Binding

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
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
EOF
# მოსალოდნელია: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

იმავე PSA-თავსებადი manifest-ით დააყენეთ `automountServiceAccountToken: false` - მოთხოვნა
უნდა გაიაროს:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-false
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
EOF
# მოსალოდნელია: pod/self-check-automount-false created (ან server-side dry-run success)
```

ახლა დააყენეთ `automountServiceAccountToken: true` - მოთხოვნა კვლავ უნდა უარყოფილ იქნეს
ზუსტად იმავე policy-ისა და binding-ის მიერ:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-true
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
EOF
# მოსალოდნელია: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

და ბოლოს, ყველაზე მნიშვნელოვანი - შეამოწმეთ scope-ის საზღვარი, და არა მხოლოდ denial-ის ფაქტი: იგივე
manifest (automount opt-out-ის გარეშე), მაგრამ namespace `psa-observe-107`-ში, უნდა გაიაროს - თუ
ისიც უარყოფილია, ესე იგი თქვენი `namespaceSelector` ერთზე მეტ namespace-ს ემთხვევა:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-other-ns
  namespace: psa-observe-107
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
EOF
echo "exit code in psa-observe-107: $?"
# მოსალოდნელია: 0 (არ არის denied) - წინააღმდეგ შემთხვევაში binding-ის scope ძალიან ფართოა
```
</details>

---

| **7** | **Controller-driven admission denial: დიაგნოსტიკა ReplicaSet events-ით** |
| :---: | :--- |
| რას ვაკეთებთ | ცარიელ namespace `psa-controller-107`-ში შექმენით Deployment `controller-app` (label `app=controller-app`, replicas=1) მარტივი Pod template-ით hardening-ის გარეშე (მაგალითად `busybox:1.36`, `sleep 3600`, `securityContext`-ის გარეშე) - ის წარმატებით უნდა გაეშვას, PSA ჯერ ხელს არ უშლის. შემდეგ ჩართეთ `pod-security.kubernetes.io/enforce=restricted` და `enforce-version=v1.36` ამ namespace-ზე (უკვე არსებული Pod აგრძელებს მუშაობას - PSA უკვე შექმნილ ობიექტებს არ ეხება). წაშალეთ მიმდინარე Pod: ReplicaSet შეეცდება ჩანაცვლების შექმნას, და ახლა admission მას უარყოფს. შეამოწმეთ მიზეზი `kubectl -n psa-controller-107 describe rs`-ით და `kubectl -n psa-controller-107 get events`-ით - იქ იქნება `FailedCreate` ტექსტით `violates PodSecurity "restricted:v1.36"`. გაასწორეთ Deployment-ის Pod template (დაამატეთ იგივე hardening ველები, რაც დავალება 2-ში: non-root, `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`) და დაელოდეთ, სანამ ReplicaSet წარმატებით შექმნის ახალ Pod-ს, რომელიც admission-ს გადის. |
| მიღების კრიტერიუმები | Namespace-ში მოქმედებს enforce `restricted:v1.36`; Pod template Deployment-ში სრულად შეესაბამება PSS `restricted`-ს; მიმდინარე Pod-ის წაშლის შემდეგ ReplicaSet რეალურად ქმნის ახალ Ready Pod-ს მოქმედი enforce-რეჟიმის ქვეშ (არა უბრალოდ "ობიექტი არსებობს" - მოწმდება ცოცხალი წაშლითა და ხელახალი შექმნით). |

<details>
<summary>💡 მინიშნება დავალება 7-ისთვის</summary>

თანმიმდევრობა მნიშვნელოვანია: ჯერ Deployment hardening-ის გარეშე (გადის, PSA ჯერ enforce არ არის), შემდეგ
label enforce=restricted namespace-ზე (არსებული Pod არ დაზარალდება), შემდეგ `kubectl
delete pod -l app=controller-app` - სწორედ აქ წააწყდება ReplicaSet admission deny-ს.
თუ Pod-ს ხელით არ წაშლით, უარყოფას საერთოდ ვერ დაინახავთ, სანამ ბუნებრივად რაიმე reschedule
არ მოხდება. გასასწორებელია სწორედ `spec.template` Deployment-ში (`kubectl
edit deployment controller-app` ან `kubectl apply` გასწორებული manifest-ით), და არა
namespace label - enforce-ის უკან დაბრუნება ამ დავალების გადაწყვეტა არ არის.
</details>

---

## შედეგის შემოწმება

სამუშაო მანქანაზე შეასრულეთ:

```bash
check_result
```

შემოწმება შეიცავს Init-ს და შვიდ დამოუკიდებელ დავალებას. ის დამატებით ასრულებს
სახიფათო Pod-ის server-side dry-run-ს, ამიტომ მუდმივი „ცუდი“ Pod-ის არარსებობა
restricted namespace-ში - მოსალოდნელი და სწორი შედეგია. დავალება 7-ში checker თავად შლის
მიმდინარე Pod `controller-app`-ს და ამოწმებს, რომ ReplicaSet რეალურად ხელახლა ქმნის Ready Pod-ს -
events-ის ტექსტს დამტკიცებად არ იღებს.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD)

## წაშლა

```bash
TASK=107 make delete_cks_task
```

## შენიშვნა PSA-ს ვერსიისა და audit-ის დაკვირვებადობის შესახებ

ლაბი განზრახ ამაგრებს PSA labels-ს `v1.36`-ზე, რადგან თავად სასწავლო კლასტერი მუშაობს
Kubernetes 1.36.0-ზე. 2026-09-06-ის მდგომარეობით ოფიციალური CKS blueprint Kubernetes
`v1.35`-ზეა ორიენტირებული; ამიტომ ეს **forward-looking** სასწავლო კონფიგურაციაა, და არა განცხადება გამოცდის
ვერსიის შესახებ. მიმდინარე გამოცდისთვის მოსამზადებლად შეცვალეთ სუფიქსები `*-version` `v1.35`-ით და
შეადარეთ ქცევა ამ ვერსიის დოკუმენტაციას.

რეჟიმი `audit` ამატებს **kube-apiserver-ის audit event**-ში annotation-ს
`pod-security.kubernetes.io/audit-violations` დამრღვევი Pod-ისთვის. სასწავლო ინფრასტრუქტურა
audit-log sink-ს არ აწყობს და არ გვთავაზობს, ამიტომ ამ annotation-ის წაკითხვა აქ `kubectl`-ით შეუძლებელია. დაკვირვებადი
დადასტურება დავალება 4-ში - PSA-ს გაფრთხილებაა
(`Warning: ... would violate PodSecurity "baseline"`) server-side admission-ისას და Pod-ის
წარმატებული შექმნა `enforce`-ის გარეშე; audit mode განმარტებულია, მაგრამ მისი log annotation ამ ლაბით
არ მოწმდება.
