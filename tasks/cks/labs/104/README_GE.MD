[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 104 - Kubernetes API-ზე წვდომის შეზღუდვა: RBAC, ServiceAccount და anonymous-auth

## მიზანი

ამ CKS-ლაბში თქვენ შეზღუდავთ Kubernetes API-ზე წვდომას უმცირესი
პრივილეგიების პრინციპით. პრაქტიკა მოიცავს მინიმალურ namespaced RBAC-ს, თანამედროვე
ხანმოკლე ServiceAccount-token-ებს, Pod-ს API-token-ის გარეშე, მოძველებული
ჭარბი უფლებების წაშლას და API server-ზე ანონიმური წვდომის გამორთვას.

იმუშავეთ მხოლოდ იმ ობიექტებთან, რომლებიც დავალებებშია მითითებული. Namespace `security-104` და
განზრახ სახიფათო მიბმა `legacy-operator-admin` უკვე მომზადებულია საწყისი სკრიპტით, ისევე როგორც
fixtures დავალებებისთვის 10-12: Secret `legacy-config`, namespace `rbac-a`/`rbac-b` და
namespace `development`. ეს სასწავლო კონფიგურაციაა და არა production-ის მაგალითი.

## Threat model

დავუშვათ, რომ თავდამსხმელი უკვე ასრულებს კოდს Pod-ში და ცდილობს workload-ის identity-ის ან authentication-ის არარსებობის გამოყენებას Kubernetes API-სკენ გასავლელად. ასეთ შემთხვევაში მნიშვნელოვანია არა მხოლოდ საწყისი წვდომა, არამედ blast radius compromise-ის შემდეგ.

დავალება 1 ხურავს ჭარბ RBAC scope-ს, დავალება 2 - დიდხანს მოქმედ token-ს, ხოლო დავალება 3 - Pod-იდან არასაჭირო API-წვდომას. ეს ამცირებს workload-ის identity-ის გამოყენების შესაძლებლობებს compromise-ის შემდეგ.

დავალება 4 აღმოფხვრის wildcard cluster-wide უფლებებს, ხოლო დავალება 5 - anonymous access-ს. ამ გზებიდან თითოეულს ცალ-ცალკე შეუძლია blast radius-ის Kubernetes API-მდე გაფართოება.

დავალება 6 ხურავს გაჟონვის ცალკე გზას: secret, რომელიც environment variable-ით არის გადაცემული, ხდება პროცესის გარემოს ნაწილი და მისი წაკითხვა შეუძლია `/proc/1/environ`-იდან ნებისმიერ პროცესს, რომელსაც კონტეინერში `exec`-ის წვდომა აქვს, ასევე ის შეიძლება მოხვდეს application logs-ში, crash dump-ში ან სხვა diagnostic გამოტანაში, თუ თავად პროგრამა ან დიაგნოსტიკის ინსტრუმენტი environment-ს ბეჭდავს. `kubectl describe pod` `env`-ისთვის `secretKeyRef`-ით აჩვენებს მხოლოდ მითითებას Secret-ზე და მის გასაღებზე (`<set to the key ... in secret ...>`), ხოლო `envFrom`-ისთვის `secretRef`-ით - მხოლოდ Secret-ის სახელს, და არა resolved მნიშვნელობას - ნუ აგრევთ ამ მითითებას თავად მნიშვნელობის გაჟონვასთან. Volume mount `defaultMode: 0400`-ით არ აქრობს კონტეინერის უფლებამოსილი პროცესის წვდომას მნიშვნელობაზე, მაგრამ secret-ს ამოიღებს პროცესის გარემოდან და კითხვის ფაილურ უფლებებს მხოლოდ მფლობელით ზღუდავს.

დავალება 7 ხურავს RBAC privilege escalation-ის ფარულ გზებს: `impersonate`, `bind`/`escalate` და CSR approval პირდაპირ არ აფართოებს ხელმისაწვდომი რესურსების სიას, არამედ იძლევა სხვისი სახელით მოქმედების ან საკუთარი თავისთვის უფრო ფართო უფლებების თავად გაცემის შესაძლებლობას - ეს რისკის ცალკე კატეგორიაა დავალება 4-ის wildcard `*`-სგან. დავალება 8 უზრუნველყოფს სისტემურ და არა წერტილოვან დაცვას: automount namespace/default SA დონეზე მუშაობს იმ Pod-ისთვისაც კი, რომელშიც დეველოპერმა token-ის აშკარად გამორთვა დაივიწყა.

დავალება 9 აჩვენებს, რომ პრევენცია (დავალებები 1-8) და აღმოჩენა - განსხვავებული, ურთიერთშემავსებელი ფენებია. მაშინაც კი, თუ ესკალაციის კონკრეტული გზები დავალება 7-ში დაკეტილია, სამომავლო ინციდენტისთვის საჭიროა გზა, რომ დავინახოთ **სახიფათო RBAC-ცვლილება** (მაგალითად, `cluster-admin`-ის შეცდომით ან ბოროტი განზრახვით ვინმესთვის გაცემა) მუდმივი ხელით `kubectl get`-ის გარეშე: audit log იძლევა რეპროდუცირებად forensic evidence-ს იმის შესახებ, ვინ დააინიცირა ცვლილება, და არა უბრალოდ RBAC-მდგომარეობის მიმდინარე snapshot-ს.

ATT&CK T1528 (Steal Application Access Token) და T1613 ამ სცენარს კონტექსტს აძლევს: დავალებები არ მოდელირებს ცალკე შეტევას, არამედ ზღუდავს უკვე კომპრომეტირებული workload-ის შედეგებს.

დავალებები 10-12 ხურავს სამ ბაზისურ, გამოცდაზე ხშირად შემხვედრ workflow-ს, და არა ახალ საფრთხეებს: დავალება 10 - არსებული secret-ის უსაფრთხო ხელახალი გამოყენება მნიშვნელობების manifest-ებში case-by-case hardcoding-ის გარეშე; დავალება 11 - ჭარბი Role-ის წერტილოვანი შეკეთება და სწორი cross-namespace RBAC-მიბმა, სადაც scope-თან შეცდომის დაშვება ადვილია; დავალება 12 - ახალი მომხმარებლის სრული onboarding სერტიფიკატით, private key-დან შემოწმებად წვდომამდე, და არა უბრალოდ უკვე მზა kubeconfig-ის გარჩევა.

## შეამოწმეთ თავი სტარტამდე

სანამ `check_result`-ს გახსნით, დარწმუნდით, რომ ამ კითხვებს დარწმუნებით უპასუხებთ. თუ არა - დაუბრუნდით [თავი 10](../../course/10/ge.md)-ს (RBAC), [თავი 11](../../course/11/ge.md)-ს (ServiceAccounts) და [თავი 12](../../course/12/ge.md)-ს (API-ზე წვდომის შეზღუდვა).

<details>
<summary>1. რით განსხვავდება `Role`+`RoleBinding` `ClusterRole`+`ClusterRoleBinding`-ისგან დავალება 1-ის კონტექსტში?</summary>

`Role` მოქმედებს მხოლოდ ერთ namespace-ში, მაგრამ მის `RoleBinding`-ს **შეუძლია** მიუთითოს subject-ზე (მაგალითად, ServiceAccount-ზე) **ნებისმიერი** სხვა namespace-იდან - Kubernetes ოფიციალურად უჭერს მხარს `subjects[].namespace`-ს, რომელიც `RoleBinding`-ის საკუთარი namespace-ისგან განსხვავდება. რაც ფიქსირებული რჩება - ეს არის გაცემული უფლებების SCOPE: უფლებები მოქმედებს მხოლოდ იმ namespace-ში, სადაც `RoleBinding` შეიქმნა, იმის მიუხედავად, საიდან არის subject. `RoleBinding`-საც შეუძლია მიუთითოს `ClusterRole`-ზე (და არა მხოლოდ `Role`-ზე) - ამ შემთხვევაში მიიღება უფლებები cluster-wide შაბლონიდან, მაგრამ გაცემული მხოლოდ კონკრეტული `RoleBinding`-ის namespace-ში. `ClusterRole`+`ClusterRoleBinding` იძლევა წვდომას მთელ კლასტერზე. დავალება 1 მოითხოვს მინიმალურ **namespaced** წვდომას, ამიტომ `Role`, და არა `ClusterRole`, - წინააღმდეგ შემთხვევაში scope უფრო ფართოა, ვიდრე საჭიროა.
</details>

<details>
<summary>2. რატომ ითვლება bound projected token (დავალება 2) უფრო უსაფრთხოდ, ვიდრე legacy Secret-based token?</summary>

Bound projected token ხანმოკლეა (მოცემულია `expirationSeconds`-ით), ავტომატურად იწურება და kubelet-ის მიერ როტირდება (rotation), და მიბმულია კონკრეტულ Pod-ზე - Pod-ის წაშლისას token ბათილდება. Legacy Secret-token-ს expiration არ აქვს, ინახება როგორც ჩვეულებრივი `Secret` etcd-ში და უსასრულოდ ვალიდური რჩება, მაშინაც კი, თუ Pod უკვე აღარ არსებობს.
</details>

<details>
<summary>3. რა განსხვავებაა იმას შორის, რასაც `automountServiceAccountToken: false` იძლევა Pod-ის დონეზე და ServiceAccount-ის დონეზე?</summary>

ServiceAccount-ის დონეზე - ეს არის baseline: მნიშვნელობა გამოიყენება ყველა Pod-ზე, რომელიც ამ SA-ს იყენებს, თუ Pod მას აშკარად არ გადაფარავს. Pod-ის დონეზე - ეს არის override: აშკარა ველს Pod spec-ში პრიორიტეტი აქვს SA-ის მნიშვნელობასთან შედარებით. დავალება 8 განზრახ ამოწმებს baseline-ს SA/namespace დონეზე, ხოლო დავალებები 2-3 - აშკარა პარამეტრს კონკრეტული Pod-ის დონეზე.
</details>

<details>
<summary>4. რატომ არ შედის `impersonate`/`bind`/`escalate` (დავალება 7) რისკის იმავე კლასში, რაც wildcard `*` (დავალება 4)?</summary>

Wildcard `*` `resources`/`verbs`-ში პირდაპირ აფართოებს **ხელმისაწვდომი ოპერაციებისა და რესურსების სიას**. `impersonate`/`bind`/`escalate` ახალ რესურსებზე წვდომას თავისთავად არ იძლევა - ისინი იძლევა **სხვისი სახელით მოქმედების** (`impersonate`) ან **საკუთარი თავისთვის ისეთი უფლებების თავად გაცემის, რომლებიც თავდაპირველად არ გქონდათ** (`bind`/`escalate`) შესაძლებლობას. ეს privilege escalation-ის ცალკე კატეგორიაა, რომლის გამოტოვებაც RBAC-ის აუდიტისას ადვილია, თუ მხოლოდ `verbs`/`resources`-ს უყურებთ ამ სამი განსაკუთრებული ზმნის გათვალისწინების გარეშე.
</details>

## ინფრასტრუქტურა

გარემო განთავსდება Terragrunt-ით AWS `eu-central-1`-ში:

| კომპონენტი | დანიშნულება |
|---|---|
| `vpc` | VPC `10.10.0.0/16` საჯარო ქვექსელებით |
| `ssh-keys` | გასაღებები node-ებზე წვდომისთვის |
| `k8s-1` | ერთკვანძიანი kubeadm-კლასტერი Kubernetes `1.36.0`, containerd და **Calico** |
| `worker` | სამუშაო მანქანა გამართული `kubectl`-ით და `check_result`-ით |

Control-plane-ზე ჩვეულებრივი Pod-ების გაშვება დაშვებულია, ამიტომ ცალკე worker-node არ არის საჭირო.
დავალება 5-სთვის დაგჭირდებათ SSH-წვდომა control-plane-ზე: სწორედ იქ არის განთავსებული
API server-ის static Pod-ის manifest.

## განთავსება

```bash
TASK=104 make run_cks_task
```

დაუკავშირდით სამუშაო მანქანას SSH-ით. კონტექსტი `cluster1-admin@cluster1` უკვე გამართულია.

```bash
time_left
check_result
```

## დავალებები

---
| **1** | **მინიმალური RBAC Pod-ების წასაკითხად** |
| :---: | :--- |
| რას ვაკეთებთ | namespace `security-104`-ში შექმენით ServiceAccount `auditor`, Role `pod-observer` და RoleBinding `auditor-pod-observer`. Role უნდა უშვებდეს **მხოლოდ** `get`, `list`, `watch` core API-ის რესურსზე `pods`. დაუკავშირეთ ის მხოლოდ ServiceAccount `auditor`-ს. |
| მიღების კრიტერიუმები | Role შეიცავს ზუსტად ერთ წესს `pods`-ისთვის ზმნებით `get`, `list`, `watch`; RoleBinding მიუთითებს ამ Role-ზე და ServiceAccount `auditor`-ზე; `auditor`-ის სახელით `secrets`-ის წაშლა შეუძლებელია. |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

ხშირი შეცდომაა ზედმეტი ზმნების დამატება (მაგალითად, `create` "ყოველი შემთხვევისთვის") ან `ClusterRole`-ის გამოყენება `Role`-ის ნაცვლად. შეამოწმეთ თავი: `kubectl auth can-i list pods -n security-104 --as=system:serviceaccount:security-104:auditor` უნდა დააბრუნოს `yes`, ხოლო `kubectl auth can-i delete secrets -n security-104 --as=system:serviceaccount:security-104:auditor` - `no`. თუ Role და RoleBinding სხვადასხვა namespace-შია, მიბმა არ იმოქმედებს - `RoleBinding` უნდა იყოს იმავე namespace-ში, რაც `Role`, და მასში subject უნდა ზუსტად ემთხვეოდეს `name`/`namespace`-ით.
</details>

---
| **2** | **ხანმოკლე projected ServiceAccount token** |
| :---: | :--- |
| რას ვაკეთებთ | შექმენით ServiceAccount `api-client` და Pod `token-client` `security-104`-ში. ნუ გამოიყენებთ legacy Secret-token-ს. გამორთეთ token-ის ჩვეულებრივი ავტომონტაჟი, ხოლო საჭირო token მიამაგრეთ **ზუსტად ერთი** projected `serviceAccountToken` source-ით `/var/run/secrets/tokens/api-token`-ზე `path: api-token`-ით და `expirationSeconds`-ით `600`-დან `3600`-მდე ჩათვლით - ნუ დაამატებთ რაიმე დამატებით `serviceAccountToken` source-ს იმავე (ან სხვა) projected volume-ში. **ნუ მიუთითებთ `audience`-ს**, რათა kubelet-მა API server-ის identifier ნაგულისხმევად მოითხოვოს. თუ აპლიკაციას ცალკე audience სჭირდება, ჯერ შეადარეთ ის API server-ზე `--api-audiences`-ს (ან default-ს `--service-account-issuer`-იდან) და მხოლოდ შემდეგ მიუთითეთ აშკარად. |
| მიღების კრიტერიუმები | Pod იყენებს `api-client`-ს, აქვს `automountServiceAccountToken: false` და შეიცავს **ზუსტად ერთ** projected `serviceAccountToken` source-ს Pod-ის მთელ სპეციფიკაციაში - მკაცრად დაფიქსირებული audience-ის გარეშე, მითითებული path-ით და `expirationSeconds`-ით დიაპაზონში `600`-`3600` (ორივე საზღვარი ჩათვლით). TokenReview, შესრულებული admin-კონტექსტიდან მიმაგრებული token-ისთვის, აბრუნებს `authenticated: true`-ს და სახელს `system:serviceaccount:security-104:api-client`; ცალკე RBAC-შემოწმება ადასტურებს, რომ ამ ServiceAccount-ს `secrets`-ის წაშლა არ შეუძლია. |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

`projected.sources[].serviceAccountToken`-ის ზუსტი სინტაქსი ზეპირად არ გჭირდებათ - `kubernetes.io/docs`-ზე არის მზა მაგალითი: Concepts → Storage → [Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), განყოფილება **"serviceAccountToken projected volumes"**. ყველაზე ხშირი შეცდომაა აშკარად `audience: kubernetes.default.svc`-ის მითითება იმ ვარაუდით, რომ ეს სტანდარტული მნიშვნელობაა. kubeadm-კლასტერისთვის ეს გარანტირებული default **არ არის** - თუ audience-ს მიუთითებთ, რომელსაც API server `--api-audiences`-ით არ იღებს, TokenReview დააბრუნებს `authenticated: false`-ს. უბრალოდ საერთოდ ნუ მიუთითებთ `audience` ველს - მაშინ kubelet მოითხოვს API server-ის identifier-ს ნაგულისხმევად, რომელსაც სერვერი აუცილებლად იღებს. ასევე არ დაგავიწყდეთ `automountServiceAccountToken: false` თავად Pod-ზე - წინააღმდეგ შემთხვევაში Kubernetes დაამატებს ჩვეულებრივ (legacy-სტილის) token volume-საც თქვენი projected volume-ის გარდა. კიდევ ერთი ხშირი შეცდომაა ძალიან პატარა `expirationSeconds`-ის არჩევა (მაგალითად `300`): Kubernetes API `serviceAccountToken` projected volume-ისთვის მოითხოვს მინიმუმ `600` წამს - უფრო მცირე მნიშვნელობას API server `kubectl apply`-ისას invalid-ად უარყოფს (`must be at least 10 minutes`).
</details>

---
| **3** | **Pod Kubernetes API-ს token-ის გარეშე** |
| :---: | :--- |
| რას ვაკეთებთ | შექმენით ServiceAccount `no-token-sa` `automountServiceAccountToken: false`-ით და Pod `no-token` `security-104`-ში ამ ServiceAccount-ით. თავად Pod-ზეც აშკარად დააყენეთ `automountServiceAccountToken: false`. გამოიყენეთ ნებისმიერი უსაფრთხო დიდხანს მომუშავე image, მაგალითად `busybox:1.36` `sleep 3600`-ით. ხელით ცალკე ნუ მიამაგრებთ ServiceAccount-ის token-ის შემცველ არც ერთ Secret-ს - Pod-ს საერთოდ არ უნდა ჰქონდეს არანაირი API-token, არც automount-ით, არც აშკარად მიმაგრებული legacy Secret-ით. |
| მიღების კრიტერიუმები | ServiceAccount-სა და Pod-ს გამორთული აქვს ავტომონტაჟი; Pod იყენებს `no-token-sa`-ს; მის სპეციფიკაციაში არ არის ავტომატურად დამატებული ServiceAccount-ის token-ის volume და არ არის ხელით მიმაგრებული Secret ტიპით `kubernetes.io/service-account-token`; `/var/run/secrets/kubernetes.io/serviceaccount/token`-ის წაკითხვის მცდელობა კონტეინერის შიგნით შეცდომით სრულდება (ფაილი არ არსებობს), ამასთან თავად `kubectl exec` უნდა შესრულდეს წარმატებით. |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

განსხვავება დავალება 8-ისგან: ტექნიკურად საკმარისი იქნებოდა automount-ის გამორთვა ერთ დონეზე (SA ან Pod), მაგრამ დავალება მოითხოვს **ორივე** დონეს ერთდროულად (defence in depth). შეამოწმეთ თავი: `kubectl get pod no-token -o jsonpath='{.spec.volumes}'` არ უნდა შეიცავდეს `kube-api-access-*`-ის მსგავს არაფერს. თუ volume მაინც გაჩნდა - შეამოწმეთ, რომ automount გამორთეთ Pod-ის შექმნამდე, და არა შემდეგ (SA-ს შეცვლა უკვე შექმნილ Pod-ებზე გავლენას არ ახდენს). გამორთული automount ხელს არ უშლის ძველი (legacy) `Secret`-ის `type: kubernetes.io/service-account-token`-ით ხელით მიმაგრებას `volumes[].secret`-ის გავლით - თუ ამას გააკეთებთ, Pod-ს ფორმალურად automounted-volume არ ექნება, მაგრამ ფაქტობრივად მაინც მიიღებს ვალიდურ API-token-ს. დავალება მოითხოვს token-ის სრულ არარსებობას, და არა მხოლოდ automount-ის არარსებობას.
</details>

---
| **4** | **ჭარბი cluster-wide უფლებების წაშლა** |
| :---: | :--- |
| რას ვაკეთებთ | კლასტერში განზრახ დარჩენილია ClusterRole `legacy-operator-admin` wildcard-უფლებებით და ClusterRoleBinding იმავე სახელით ServiceAccount `legacy-operator`-ისთვის `security-104`-იდან. წაშალეთ **ორივე** ობიექტი. wildcard-წვდომას სხვა ფართო ClusterRole-ით ნუ ჩაანაცვლებთ. |
| მიღების კრიტერიუმები | `legacy-operator-admin` არ არსებობს არც როგორც ClusterRole, არც როგორც ClusterRoleBinding; ServiceAccount `legacy-operator`-ს აღარ შეუძლია `secrets`-ის წაკითხვა `security-104`-ში. |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

მხოლოდ `ClusterRoleBinding`-ის წაშლა `ClusterRole`-ის წაშლის გარეშე სახიფათო შაბლონს ტოვებს კლასტერში - ვიღაცამ შეიძლება მოგვიანებით ახალი მიბმა შექმნას მასზე. წაშალეთ ორივე ობიექტი. შეამოწმეთ თავი ორი ცალკე ბრძანებით: `kubectl get clusterrole legacy-operator-admin` და `kubectl get clusterrolebinding legacy-operator-admin` - ორივემ უნდა დააბრუნოს `NotFound`.
</details>

---
| **5** | **API server-ზე anonymous access-ის გამორთვა** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით control-plane-ზე ფაილი `/etc/kubernetes/authentication-config.yaml` `AuthenticationConfiguration`-ით, რომელიც თიშავს anonymous access-ს ყველა endpoint-ზე, გარდა `/livez`, `/readyz` და `/healthz`-ისა - `/livez`-სა და `/readyz`-ს იყენებს kubeadm API server-ის static Pod-ის HTTPS liveness/readiness/startup probes-ისთვის (`/healthz` თავსებადობისთვის არის დატოვებული), და სრული `--anonymous-auth=false` თავად probes-ს არღვევს, და არა მხოლოდ თავდამსხმელის წვდომას.<br/>• მიაერთეთ ფაილი `hostPath` volume-ით და არგუმენტით `--authentication-config=<გზა-კონტეინერში>` `/etc/kubernetes/manifests/kube-apiserver.yaml`-ში, და **წაშალეთ** არსებული `--anonymous-auth=true` - anonymous access-ის გამართვის ორივე ხერხი ერთმანეთს გამორიცხავს, და kube-apiserver არ გაიშვება, თუ ორივეა მითითებული. Kubelet static Pod-ს ავტომატურად გადატვირთავს.<br/>• დაელოდეთ API server-ის მზადყოფნას (Pod რჩება Running/Ready) და დარწმუნდით, რომ არაავტენტიფიცირებული მოთხოვნა `/version`-ზე იღებს `401`-ს, ხოლო `/livez`-სა და `/readyz`-ზე - `200`-ს.<br/>• დამატებით შეამოწმეთ, რომ effective `--authorization-mode` შეიცავს `Node,RBAC`-ს და **არ** შეიცავს `AlwaysAllow`-ს (ავტენტიფიკაცია შემზღუდავი ავტორიზაციის გარეშე უაზროა).<br/>• გააკეთეთ ClusterRoleBinding-ების აუდიტი, რომელთა subjects არის `system:anonymous`/ჯგუფი `system:unauthenticated`: კლასტერში განზრახ დარჩენილია ერთი სახიფათო (lab-owned) ასეთი მიბმა, `lab104-unintended-anonymous-access`, წაშალეთ ის მისი ClusterRole-ითურთ. **ნუ შეეხებით** სტანდარტულ kubeadm-მიბმას `system:public-info-viewer` - ისიც `system:unauthenticated`-ზეა მიბმული, მაგრამ წვდომას იძლევა მხოლოდ non-resource URL-ებზე `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`, ეს bootstrap-ის ნორმალური ნაწილია (default Kubernetes RBAC), და არა ამ დავალების აღმოჩენა.<br/>• ეს ცალკე ფენაა იმავე დავალების `AuthenticationConfiguration`-ისგან: `anonymous.conditions` იქ განზრახ უშვებს ანონიმურ identity-ს მხოლოდ `/livez`/`/readyz`/`/healthz`-ზე - `/version` ანონიმურად მიუწვდომელია სწორედ იმიტომ, რომ მასზე მოთხოვნა authentication-ის ეტაპზე საერთოდ არ იღებს anonymous identity-ს, და `system:public-info-viewer`-ით ავტორიზაციამდე საქმე არ მიდის, ამ უფრო ფართო non-resource URL სიის მიუხედავადაც. |
| მიღების კრიტერიუმები | • API server-ის static Pod იყენებს `--authentication-config`-ს, რომელიც მიუთითებს `AuthenticationConfiguration`-ზე `anonymous.enabled: true`-თი და `conditions`-ით, რომელიც მოიცავს ზუსტად `/livez`, `/readyz`, `/healthz`-ს.<br/>• არგუმენტი `--anonymous-auth` არ არის.<br/>• kube-apiserver Pod რჩება `Running`/`Ready` გადატვირთვის შემდეგ.<br/>• არაავტენტიფიცირებული `GET /version` აბრუნებს `401`-ს.<br/>• არაავტენტიფიცირებული `GET /livez` და `GET /readyz` აბრუნებს `200`-ს.<br/>• ავტენტიფიცირებული მოთხოვნა `/readyz`-ზე (ვალიდური credentials-ით) ასევე მუშაობს.<br/>• Effective `--authorization-mode` შეიცავს `Node,RBAC`-ს და არ შეიცავს `AlwaysAllow`-ს.<br/>• ClusterRole/ClusterRoleBinding `lab104-anonymous-debug-access`/`lab104-unintended-anonymous-access` წაშლილია.<br/>• სტანდარტული `system:public-info-viewer` ხელუხლებელი დარჩა.<br/>• ჯგუფს `system:unauthenticated` არც ერთ namespace-ში არ შეუძლია `pods`/`secrets`/`configmaps`-ის წაკითხვა. |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

Pod ობიექტს ნუ დაარედაქტირებთ `kubectl edit pod`-ით - kubelet manifest-ფაილს აკვირდება და API-ს გავლით გაკეთებულ ნებისმიერ ცვლილებას საწყის მდგომარეობაში უკან გადაწერს. დაარედაქტირეთ სწორედ ფაილი `/etc/kubernetes/manifests/kube-apiserver.yaml` node-ის დისკზე. შენახვის შემდეგ დაელოდეთ: kubelet ფაილის ცვლილებას მყისიერად არ აღმოაჩენს, და API server რამდენიმე წამით მიუწვდომელი იქნება static Pod-ის გადატვირთვისას - არ ინერვიულოთ, თუ `curl` ფაილის შენახვისთანავე არაფერს აბრუნებს.

მარტივი `--anonymous-auth=false` აქ **არ გამოდგება**: kubeadm `release-1.36` აგენერირებს kube-apiserver static Pod-ს HTTPS liveness/readiness/startup probes-ით სწორედ `/livez` და `/readyz`-ზე, ხოლო kubelet HTTP probes client credentials-ს არ გადასცემენ - anonymous access-ის სრული გამორთვისას ეს მოთხოვნები იღებენ `401`-ს, kubelet კონტეინერს არაჯანსაღად მიიჩნევს და kube-apiserver-ს შეიძლება ციკლურად გადატვირთავდეს, რაც არღვევს არა მხოლოდ ამ დავალებას, არამედ შემდგომ დავალება 9-საც. სწორი გზაა `AuthenticationConfiguration` `anonymous.enabled: true`-თი და `anonymous.conditions`-ით, რომლებიც anonymous access-ს მხოლოდ საჭირო health-გზებით ზღუდავს:

```yaml
# /etc/kubernetes/authentication-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
```

`--authentication-config` და `--anonymous-auth` ერთდროულად მითითება არ შეიძლება - kube-apiserver არ გაიშვება, თუ ორივე არგუმენტი manifest-შია. დარწმუნდით, რომ `--anonymous-auth=true` მთლიანად წაშალეთ, და არა უბრალოდ მნიშვნელობა `false`-ზე შეცვალეთ.

ანონიმური ClusterRoleBinding-ების აუდიტისთვის: `kubectl get clusterrolebinding -o json | jq -r
'.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name ==
"system:unauthenticated")] | length > 0) | .metadata.name'`. დაინახავთ სულ მცირე ორ
მიბმას - სტანდარტულ `system:public-info-viewer`-ს (ნუ შეეხებით) და lab-owned
`lab104-unintended-anonymous-access`-ს (წაშალეთ მისი ClusterRole
`lab104-anonymous-debug-access`-ითურთ). მათი გარჩევა შეიძლება ClusterRole-ის სახელით, რომელზეც ისინი
მიუთითებენ: `kubectl get clusterrolebinding system:public-info-viewer -o
jsonpath='{.roleRef.name}'` აჩვენებს `system:public-info-viewer`-ს - ეს ClusterRole-ია,
შეზღუდული non-resource URL-ებით, და არა ჩვეულებრივი resources-ით.
</details>

---
| **6** | **Secret-ის გაჟონვა env-ით `/proc/1/environ`-ში: გადასვლა volume-ზე** |
| :---: | :--- |
| რას ვაკეთებთ | • Pod `app-vulnerable` `security-104`-ში იღებს `db-creds`-ს `envFrom.secretRef`-ით - მნიშვნელობა ხელმისაწვდომია ნებისმიერისთვის, ვისაც შეუძლია `kubectl exec` კონტეინერში (`cat /proc/1/environ`) ან წაიკითხოს logs/describe env-ის შემთხვევითი გამოტანისას.<br/>• დაადასტურეთ ეს გაჟონვა: შეასრულეთ `kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ` და შეინახეთ გამოტანა (`DB_PASSWORD`-ით) `/var/work/tests/artifacts/6/env-leak-before.txt`-ში.<br/>• თავიდან შექმენით Pod იმავე სახელით `app-vulnerable`: წაშალეთ `envFrom`/`env` ამ secret-ით, მიამაგრეთ `db-creds` როგორც volume `db-creds-vol` `/etc/secrets`-ზე **read-only**, `defaultMode: 0400`-ით.<br/>• დაადასტურეთ ცვლადის `DB_PASSWORD` არარსებობა ახალ `/proc/1/environ`-ში და შეინახეთ მიმაგრებული ფაილის `stat -L -c '%a'` `/var/work/tests/artifacts/6/secret-file-mode.txt`-ში (ფლაგი `-L` სავალდებულოა - secret მიმაგრდება სიმლინკების ჯაჭვით `..data`, `-L`-ის გარეშე `stat` აჩვენებს თავად სიმლინკის რეჟიმს და არა რეალური ფაილისას). |
| მიღების კრიტერიუმები | `env-leak-before.txt` შეიცავს `DB_PASSWORD`-ის რეალურ მნიშვნელობას Secret `db-creds`-იდან (და არა უბრალოდ სიტყვა `DB_PASSWORD`-ს); საბოლოო Pod `app-vulnerable`-ს არ აქვს `env`/`envFrom`, რომლებიც `db-creds`-ზე მიუთითებს, და არ აქვს იმავე Secret-ის მიმაგრების მეორე ხერხი; volume `db-creds-vol` მიმაგრებულია `/etc/secrets`-ზე როგორც `readOnly: true` `defaultMode: 0400`-ით (`256` decimal) - checker თავად ამოწმებს `stat -L -c %a`-ს კონტეინერის შიგნით და ზუსტად `400`-ს მოითხოვს; `DB_PASSWORD` არ არის საბოლოო Pod-ის `/proc/1/environ`-ში (წარმატებით შესრულებული `exec`-ის დროს - წარუმატებელი `exec` მტკიცებულებად არ ითვლება); აპლიკაციის პროცესს ამასთან მაინც რეალურად შეუძლია secret-ის მნიშვნელობის წაკითხვა `/etc/secrets/DB_PASSWORD`-იდან (positive control). |

<details>
<summary>💡 მინიშნება დავალება 6-ისთვის</summary>

`/proc/1/environ` გაჟონვის დადასტურების ნაბიჯში - მნიშვნელობის დანახვის ერთადერთი გზა არ არის
(იგივე შედეგს მისცემს `kubectl exec ... -- env` ან `echo $DB_PASSWORD`, რადგან
container runtime ნაგულისხმევად exec-ით გაშვებულ პროცესს აძლევს იმავე გარემოს, რაც PID 1-ს).
`/proc/1/environ` კითხულობს სწორედ PID 1-ის გარემოს პირდაპირ `/proc`-ის გავლით, და არ ეყრდნობა
იმას, რაც თქვენმა კონკრეტულმა exec-shell-მა მემკვიდრეობით მიიღო - ეს იგივე ხერხია, რომელსაც რეალურად იყენებენ
security-ანალიზისას, რათა ნებისმიერი პროცესის გარემო ნახონ, და არა მხოლოდ საკუთარი.

Volume mount **არ წაართმევს წვდომას მას, ვისაც უკვე აქვს `kubectl exec`** - `cat
/etc/secrets/DB_PASSWORD` ფიქსის შემდეგ მნიშვნელობას ისევე მარტივად კითხულობს, როგორც `cat
/proc/1/environ` კითხულობდა ფიქსამდე, და ეს მოსალოდნელია (positive control დავალებაში სწორედ
ამას ამოწმებს). დავალება exec-წვდომის დაკეტვას არ ეხება - ეს შეუძლებელია არც ფაილისთვის, არც
ცვლადისთვის, თუ პროცესს მნიშვნელობის წაკითხვის უფლება აქვს. რეალური განსხვავება - გაჟონვის გზებშია,
რომლებიც ამოქმედდება აშკარა `exec`-ის გარეშე:
- გარემოს ცვლადებს ავტომატურად მემკვიდრეობით იღებს **ნებისმიერი** შვილობილი პროცესი (`fork()`
  აკოპირებს მთელ env-ს) - მესამე მხარის ბიბლიოთეკა, plugin-ი ან შემთხვევითი subprocess აპლიკაციის შიგნით
  მიიღებს `DB_PASSWORD`-ს, თუნდაც დეველოპერს ამაზე არ უფიქრია; ფაილი ასე არ
  გადაეცემა - შვილობილმა პროცესმა აშკარად უნდა იცოდეს გზა და გახსნას ის;
- crash handler-ები და error-logger-ები ხშირად ბეჭდავენ პროცესის მთელ `environ`-ს
  ჩავარდნისას - ეს logs-ში ავტომატურად მოხვდება; ფაილის შიგთავსი logs-ში თავისით
  არ მოხვდება, სანამ კოდი მას აშკარად არ წაიკითხავს და არ დალოგავს;
- გარემოს ცვლადებს წვდომის უფლებების მოდელი არ აქვს - მათ ხედავს ნებისმიერი პროცესი კონტეინერის
  namespace-ში; ფაილს `defaultMode: 0400`-ით აქვს - კითხულობს მხოლოდ პროცესი სწორი UID-ით.

```text
[FAIL] defaultMode Secret Volume-ისთვის არასწორად არის მითითებული.
💡 თქვენ მიუთითეთ defaultMode: 400 (ათობითი 400).
   YAML მხარს უჭერს რვაობით ლიტერალს წინა ნულით (0400), რომელსაც Kubernetes
   განმარტავს როგორც ჩვეულებრივ Unix-უფლებებს; წინა ნულის გარეშე 400 იკითხება როგორც ათობითი
   რიცხვი 400, და არა როგორც უფლებები 0400 (ეს ათობითი 256-ია).
```

ეს ამ დავალების ყველაზე ხშირი შეცდომაა: `defaultMode` - რიცხვითი ველია POSIX mode bits-ით, და
Kubernetes YAML მისთვის მხარს უჭერს როგორც რვაობით, ისე ათობით ჩანაწერს - JSON-ისგან განსხვავებით,
სადაც დასაშვებია მხოლოდ ათობითი. თუ დაწერთ `defaultMode: 400` (წინა
ნულის გარეშე), Kubernetes ამას აღიქვამს როგორც **ათობით** 400-ს, და არა როგორც ჩვეულებრივ Unix-უფლებებს
`0400`. სწორი გზაა ან დაწეროთ `defaultMode: 0400` (წინა ნულით, YAML
ამოიცნობს რვაობით ლიტერალს), ან აშკარად მიუთითოთ ათობითი ექვივალენტი `256`. შეამოწმეთ
თავი: `kubectl get pod app-vulnerable -o jsonpath='{.spec.volumes[0].secret.defaultMode}'`
უნდა დააბრუნოს `256`, ხოლო `stat -L -c '%a' /etc/secrets/DB_PASSWORD` კონტეინერის შიგნით - `400`.
</details>

---
| **7** | **ფარული RBAC privilege escalation-ის გზების აუდიტი და გაუქმება (`impersonate`, `bind`, `escalate`, CSR approval)** |
| :---: | :--- |
| რას ვაკეთებთ | • ClusterRole `build-agent-hidden-privesc` არ შეიცავს wildcard `*`-ს (ეს ცალკე, დავალება 4-ში უკვე აღმოფხვრილი გზაა), მაგრამ ServiceAccount `build-agent`-ს `security-104`-იდან აძლევს პრივილეგიების ამაღლების სამ რეალურად ექსპლუატირებად გზას:<br/>• `impersonate` `users`/`groups`/`serviceaccounts`-ზე - პირის ჩანაცვლება, cluster-admin-ის ჩათვლით, თუ ასეთი მომხმარებელი თავდამსხმელისთვის ცნობილია.<br/>• `create`/`update`/`bind`/`escalate` `clusterroles`-ზე და `create`/`update` `clusterrolebindings`-ზე - საბაზისო verbs იძლევა თავად ობიექტების შექმნის/შეცვლის საშუალებას, ხოლო `bind`/`escalate` გვერდს უვლის ჩაშენებულ RBAC-შემოწმებას, რომელიც სხვა შემთხვევაში აკრძალავდა საკუთარზე უფრო ფართო უფლებების გაცემას/მიბმას (საბაზისო `create`/`update`-ის გარეშე მხოლოდ `bind`/`escalate` რეალური ესკალაციისთვის საკმარისი არ არის).<br/>• `update` `certificatesigningrequests/approval`-ზე + `approve` signer-ზე `kubernetes.io/kube-apiserver-client` - თვითნებური identity-ის მქონე CSR-ის დამტკიცების შესაძლებლობა (მაგრამ ეს ClusterRole თავისთავად `create certificatesigningrequests`-ს არ იძლევა: შეტევის სერტიფიკატის გაცემამდე მისაყვანად identity-საც ცალკე CSR-ის შექმნის შესაძლებლობა სჭირდება, მაგალითად სხვა კომპრომეტირებული როლით ან compromised automation-ით, რომელსაც CSR-ის გაგზავნა უკვე შეუძლია).<br/>• იპოვეთ **ყველა** ClusterRoleBinding, რომელთა ClusterRole-ები უშვებს `impersonate`-ს, `bind`-ს ან `escalate`-ს (მაგალითად, `kubectl get clusterrole -o json \| jq`-ით `rules[].verbs`-ის მიხედვით), ჩაწერეთ ისინი `/var/work/tests/artifacts/7/dangerous-bindings-before.txt`-ში.<br/>• წაშალეთ ClusterRoleBinding `build-agent-hidden-privesc` **და** ClusterRole `build-agent-hidden-privesc` (და, თუ სხვა უნებლიედ დარჩენილებს იპოვით - მათაც, მაგრამ არა სისტემურ `system:*` ClusterRoleBinding-ებს).<br/>• დაადასტურეთ გაუქმება `kubectl auth can-i`-ით ყველა ნაპოვნი უფლებისთვის: `impersonate users`, `bind clusterroles`, `escalate clusterroles`, `update certificatesigningrequests/approval`, ასევე `approve` signer-ზე `kubernetes.io/kube-apiserver-client` - ყველამ უნდა დააბრუნოს `no`. |
| მიღების კრიტერიუმები | • `dangerous-bindings-before.txt` შეიცავს `build-agent-hidden-privesc`-ს ნაპოვნებს შორის როგორც ClusterRoleBinding (და არა ClusterRole-ის სახელს, თუ ისინი არ ემთხვევა).<br/>• ClusterRoleBinding **და** ClusterRole `build-agent-hidden-privesc` არ არსებობს გასწორების შემდეგ.<br/>• `build-agent`-ს არ შეუძლია `impersonate`, `bind`, `escalate`, `update certificatesigningrequests/approval`.<br/>• `build-agent`-ს არ შეუძლია `approve`-ის შესრულება signer-ზე `kubernetes.io/kube-apiserver-client`.<br/>• სისტემური `system:*` ClusterRoleBinding-ები ხელუხლებელია. |

<details>
<summary>💡 მინიშნება დავალება 7-ისთვის</summary>

CSR approval - ცალკე კატეგორიაა `impersonate`/`bind`/`escalate`-სგან: ის არ შედის იმავე `jq`-ფილტრში `verbs`-ის მიხედვით, რადგან წარმოადგენს ცალკე წესს რესურსზე `certificatesigningrequests/approval` verb-ით `update`, პლუს `approve` კონკრეტულ `signer`-ზე. თუ მხოლოდ `impersonate`/`bind`/`escalate`-ით გაფილტრავთ, ერთ გზას იპოვით, მაგრამ CSR-ს გამოტოვებთ - ეძებეთ ორივე ცალკე, და თითოეულისთვის შეინახეთ სწორედ **ClusterRoleBinding**-ის სახელი, და არა ClusterRole-ისა, რომელზეც ის მიუთითებს (ამ ლაბში სახელები ემთხვევა, მაგრამ ზოგად შემთხვევაში ეს გარანტირებული არ არის). ნუ წაშლით სისტემურ `ClusterRoleBinding`-ებს პრეფიქსით `system:` - ისინი Kubernetes-ის core-კომპონენტებს სჭირდებათ ლეგიტიმური `impersonate`-ისთვის (მაგალითად, `system:kube-controller-manager`).
</details>

---
| **8** | **Namespace-level baseline: `default` ServiceAccount automount-ის გარეშე** |
| :---: | :--- |
| რას ვაკეთებთ | • დავალება 3 automount-ს თიშავდა წერტილოვნად, კონკრეტული Pod-ისა და მისი საკუთარი ServiceAccount-ის შიგნით. აქ საჭიროა baseline **namespace**-ის დონეზე.<br/>• შექმენით namespace `security-104-baseline`, დაელოდეთ მასში ავტომატურად შექმნილი ServiceAccount `default`-ის გამოჩენას (ServiceAccount-ის შექმნა ხდება ასინქრონულად ცალკე controller-ის მიერ, და არა თავად namespace-თან ერთდროულად).<br/>• მხოლოდ შემდეგ დააყენეთ `automountServiceAccountToken: false` ამ ServiceAccount-ზე: `kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`.<br/>• შექმენით ამ namespace-ში Pod `implicit-default-sa` `busybox:1.36`-დან (`sleep 3600`) ისე, რომ **არ მიუთითოთ** არც `serviceAccountName`, არც `automountServiceAccountToken` აშკარად - ის უნდა იყენებდეს `default` SA-ს არაცხადად და მემკვიდრეობით იღებდეს მის მნიშვნელობას.<br/>• დაადასტურეთ, რომ საბოლოო Pod-ის სპეციფიკაციაში ველი `automountServiceAccountToken` არ არის (და არა უდრის `false`-ს), token-ის volume არ არის, და token-ფაილის წაკითხვის ცდა კონტეინერის შიგნით სრულდება სწორედ ფაილის არარსებობის შეცდომით (თავად `kubectl exec` ამასთან წარმატებით უნდა შესრულდეს). |
| მიღების კრიტერიუმები | • ServiceAccount `default`-ს `security-104-baseline`-ში აქვს `automountServiceAccountToken: false`.<br/>• Pod `implicit-default-sa` იყენებს `serviceAccountName: default`-ს (არაცხადად ან ცხადად).<br/>• მის სპეციფიკაციაში **არ არის** ველი `automountServiceAccountToken` (აშკარად არ არის დაყენებული არც `true`-ზე, არც `false`-ზე).<br/>• არ არის ავტომატურად დამატებული `projected`/`secret` volume ServiceAccount-ის token-ით და არ არის ხელით მიმაგრებული legacy `Secret` ტიპით `kubernetes.io/service-account-token`.<br/>• `kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token` სრულდება წარმატებით (exit code `0`), რაც ადასტურებს ფაილის არარსებობას სწორედ წარმატებული exec-ით, და არა თვითნებური შეცდომით. |

<details>
<summary>💡 მინიშნება დავალება 8-ისთვის</summary>

ოპერაციების თანმიმდევრობა კრიტიკულია: თუ Pod-ს შექმნით მანამდე, სანამ `patch` namespace-ის `default` SA-ზე გამოიყენება, Pod token-ს მიიღებს ძველი (default `true`) მნიშვნელობით. ასევე `default` SA-ს ნუ დაპატჩავთ `kubectl create namespace`-ის შემდეგ მაშინვე შემოწმების გარეშე - ServiceAccount `default` იქმნება ცალკე controller-ის მიერ და namespace-ის შექმნიდან წამის პირველ ნაწილებში შეიძლება ჯერ არ არსებობდეს; დაელოდეთ მის გამოჩენას (`kubectl get serviceaccount default -n security-104-baseline`), მხოლოდ შემდეგ დაპატჩეთ. დავალება განზრახ არ მიუთითებს `serviceAccountName`-ს Pod-ში - ეს მოდელირებს რეალურ სიტუაციას, როცა დეველოპერმა უბრალოდ ServiceAccount-ის შესახებ დაივიწყა, და baseline-მა ის ნაგულისხმევად უნდა დაიცვას. აშკარა `automountServiceAccountToken: false` თავად Pod-ზე დაამტკიცებდა მხოლოდ წერტილოვან პარამეტრს (როგორც დავალება 3-ში) - აქ ველი მთლიანად მიუთითებლად უნდა დარჩეს, რათა დამტკიცდეს სწორედ SA/namespace-იდან მემკვიდრეობა.
</details>

---
| **9** | **ინტეგრაციული დავალება: RBAC-ესკალაციის აღმოჩენა audit log-ით და მისი ლოკალიზაცია** |
| :---: | :--- |
| რას ვაკეთებთ | • ეს დავალება აერთიანებს RBAC-ს (ეს ლაბი) audit-ლოგირებასთან (იხ. [თავი 32](../../course/32/ge.md)) - audit log-ის გარეშე სახიფათო RBAC-ცვლილების ფაქტი მხოლოდ post-hoc გამოჩნდებოდა `kubectl get`-ით, და არა როგორც რეპროდუცირებადი forensic evidence.<br/>• control-plane-ზე ჩართეთ მინიმალური audit backend: შექმენით `/etc/kubernetes/audit/policy.yaml` წესით `RequestResponse` `apiGroups: ["rbac.authorization.k8s.io"]`-ისთვის, რესურსებისთვის `clusterroles` და `clusterrolebindings`, და catch-all `Metadata` როგორც fallback.<br/>• static manifest-ში `/etc/kubernetes/manifests/kube-apiserver.yaml` დაამატეთ `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` და საჭირო hostPath volume/volumeMount (დირექტორიები წინასწარ შექმენით). დაელოდეთ API-ის აღდგენას.<br/>• ადმინისტრატორის სახელით (`cluster1-admin`) შექმენით ClusterRoleBinding `incident-simulated-escalation`, რომელიც ClusterRole `cluster-admin`-ს აკავშირებს ServiceAccount `build-agent`-თან `security-104`-იდან - ეს **არ** არის თავად `build-agent`-ის მხრიდან ესკალაციის მცდელობა (დავალება 7-მა მას პრივილეგიების ამაღლების რეალური გზები უკვე ჩამოართვა), არამედ ადმინისტრატორის მიერ მოდელირებული სახიფათო RBAC-ცვლილება: რეალური სცენარი, როცა ვინმე (ადამიანი-ოპერატორი, სკრიპტი, კომპრომეტირებული CI/CD) შეცდომით ან ბოროტი განზრახვით აძლევს `cluster-admin`-ს ServiceAccount-ს, და SOC/security-ინჟინრის ამოცანაა სწორედ ასეთი მოვლენის აღმოჩენა audit log-ით, და არა მუდმივი ხელით `kubectl get`-ით.<br/>• იპოვეთ audit log-ში მოვლენა `create` `clusterrolebindings`-ისთვის ამ სახელით, `requestObject.roleRef`-ით `cluster-admin`-ზე და `system:serviceaccount:security-104:build-agent`-ით `requestObject.subjects`-ში, შეინახეთ მოვლენა მთლიანად (`user.username`-ის ჩათვლით - იმისა, ვინც რეალურად დააინიცირა მოთხოვნა) `/var/work/tests/artifacts/9/audit-escalation-event.json`-ში. ეს არ არის უბრალოდ «დარწმუნება, რომ audit-წესი მუშაობს» - SOC-ინჟინრის რეალური ამოცანა აქ არის სწორედ კონკრეტული ჩანაწერის **ამოღება და შენახვა** როგორც forensic evidence (checker თავად დამოუკიდებლად კითხულობს `audit.log`-ს control-plane-ზე და ადარებს თქვენი artifact-ის `auditID`-ს რეალურ ჩანაწერს - გამოგონილი, თუნდაც მსგავსი JSON არ გაივლის).<br/>• შეასრულეთ containment: წაშალეთ `incident-simulated-escalation` და დაადასტურეთ `kubectl auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent`-ით, რომ წვდომა გაუქმებულია; შეინახეთ საბოლოო `no` `/var/work/tests/artifacts/9/containment-result.txt`-ში (`can-i` `-n`/`-A`-ის გარეშე ამოწმებს მხოლოდ თქვენი kubeconfig-კონტექსტის მიმდინარე namespace-ს, და არა მთელ კლასტერს - namespace აშკარად მიუთითეთ). |
| მიღების კრიტერიუმები | • kube-apiserver-ის static manifest შეიცავს `--audit-policy-file`-სა და `--audit-log-path`-ს, API server healthy-ა.<br/>• `/var/work/tests/artifacts/9/audit-escalation-event.json` - ვალიდური JSON audit event-ია `verb: create`-ით, `objectRef.resource: clusterrolebindings`-ით, `objectRef.name: incident-simulated-escalation`-ით, `requestObject.roleRef.name: cluster-admin`-ით და ServiceAccount `build-agent`-ით `security-104`-იდან `requestObject.subjects`-ს შორის.<br/>• ClusterRoleBinding `incident-simulated-escalation` არ არსებობს containment-ის შემდეგ.<br/>• `containment-result.txt` შეიცავს `no`-ს. |

<details>
<summary>💡 მინიშნება დავალება 9-ისთვის</summary>

წესი `RequestResponse` `rbac.authorization.k8s.io`-ისთვის policy-ის წესების სიაში პირველი უნდა იდგეს - უფრო სპეციფიკური წესი ზოგად `Metadata`-catch-all-ს უნდა უსწრებდეს, წინააღმდეგ შემთხვევაში catch-all მოვლენას ადრე ჩაიგდებს ხელში და მიიღებთ მხოლოდ `Metadata`-დონეს `RequestResponse`-ის ნაცვლად მოთხოვნის სხეულით. დაამატეთ `omitStages: [RequestReceived]` მთელი policy-ის დონეზე - ამ სტადიას ჯერ არ აქვს `requestObject`/`responseStatus`, ხოლო `Metadata`-catch-all გამოიყენება საერთოდ კლასტერის ყველა მოთხოვნაზე, ამიტომ `omitStages`-ის გარეშე `audit.log` ორჯერ უფრო სწრაფად იზრდება ამ დავალებისთვის რაიმე დამატებითი სარგებლის გარეშე. შექმენით `incident-simulated-escalation` მას შემდეგ, რაც API server ახალი audit backend-ით გადაიტვირთება - წინააღმდეგ შემთხვევაში მოვლენა უბრალოდ ლოგში ვერ მოხვდება. ეს დავალება ამოწმებს სახიფათო RBAC-ცვლილების აღმოჩენას per se, და არა იმას, რომ სწორედ `build-agent`-მა ჩაიდინა ის - audit log-ში ველი `user.username` აჩვენებს რეალურ ინიციატორს (ადმინისტრატორს), და არა `build-agent`-ს; `build-agent` ამ მოვლენაში ფიგურირებს მხოლოდ უფლებების მიმღებად (`requestObject.subjects`). `audit-escalation-event.json` უნდა იყოს **რეალური** ჩანაწერი, `/var/log/kubernetes/audit/audit.log`-იდან გადაწერილი (მისი `auditID`-ის ჩათვლით) - ხელით აწყობილი JSON რამდენიმე დამთხვევადი სტრიქონით შემოწმებას ვერ გაივლის, რადგან self-check თავად კითხულობს ლოგს control-plane-ზე და ადარებს `auditID`-ს. არ დაგავიწყდეთ containment: `ClusterRoleBinding`-ის წაშლა თავისთავად - ამოცანის ნახევარია, მეორე ნახევარი - `kubectl auth can-i`-ით დამტკიცებაა, რომ წვდომა რეალურად გაუქმებულია, და არა უბრალოდ ობიექტი გახდა წაკითხვისთვის მიუწვდომელი.
</details>

---
| **10** | **Secret-ის დეკოდირება, შექმნა და მიმაგრება** |
| :---: | :--- |
| რას ვაკეთებთ | • `security-104`-ში უკვე არსებობს Opaque Secret `legacy-config` ორი გასაღებით: `SERVICE_USER` და `SERVICE_TOKEN`. წაიკითხეთ ის API-ს გავლით და ორივე მნიშვნელობა base64-დან დეკოდირეთ.<br/>• შექმენით ახალი generic Secret `rehydrated-config` literal-მნიშვნელობებიდან (`kubectl create secret generic ... --from-literal=...`), იმავე გასაღებების სახელებით და იმავე დეკოდირებული მნიშვნელობებით.<br/>• შექმენით Pod `secret-workflow` `busybox:1.36`-დან (`sleep 3600`), რომელიც `rehydrated-config`-ს ამაგრებს როგორც **read-only** volume-ს `/etc/rehydrated`-ზე.<br/>• დაადასტურეთ, რომ ორივე ფაილი კონტეინერის შიგნით რეალურად იკითხება და შეიცავს მოსალოდნელ მნიშვნელობებს. |
| მიღების კრიტერიუმები | • `rehydrated-config` არსებობს და მისი დეკოდირებული `SERVICE_USER`/`SERVICE_TOKEN` ემთხვევა საწყის `legacy-config`-ს.<br/>• Pod `secret-workflow` ამაგრებს სწორედ ამ Secret-ს `/etc/rehydrated`-ზე `readOnly: true`-ით.<br/>• `kubectl exec` კონტეინერის შიგნით კითხულობს ორივე ფაილს სწორი შიგთავსით. |

<details>
<summary>💡 მინიშნება დავალება 10-ისთვის</summary>

`kubectl get secret legacy-config -o jsonpath='{.data.SERVICE_USER}' | base64 -d` გაძლევთ
რეალურ მნიშვნელობას - ახალ Secret-ში თვითნებურ სტრიქონს ნუ ჩაწერთ, checker თავად თავიდან
დეკოდირებს ორიგინალს და ადარებს. `kubectl create secret generic rehydrated-config
--from-literal=SERVICE_USER=... --from-literal=SERVICE_TOKEN=...` მნიშვნელობებს
ავტომატურად აკოდირებს - `--from-literal`-ით შექმნისას base64-encode თავად არ გჭირდებათ.
არ დაგავიწყდეთ `readOnly: true` volumeMount-ზე - მიმაგრებული, მაგრამ writable Secret
მიღების კრიტერიუმს სიტყვასიტყვით ფლაგის გამო ვერ გაივლის, თუნდაც თავად Pod სწორად მუშაობდეს.
</details>

---
| **11** | **არსებული Role-ის გასწორება და მისი მიბმა სხვა namespace-ის SA-სთან** |
| :---: | :--- |
| რას ვაკეთებთ | • namespace `rbac-a`-ში უკვე არსებობს ServiceAccount `dev`, Role `pod-role` და RoleBinding `pod-role-binding`. Role ახლა უშვებს `get`, `list`, `delete` `pods`-ზე - `delete` აქ ზედმეტია (მოაცილეთ), ხოლო `watch` არ არის, თუმცა საჭიროა (დაამატეთ). გაასწორეთ სწორედ არსებული Role, ახალს ნუ შექმნით.<br/>• ცალკე, namespace `rbac-b`-ში უკვე არსებობს ConfigMap `shared-config`. შექმენით `rbac-b`-ში ახალი Role და RoleBinding, რომლებიც ServiceAccount `dev`-ს **namespace `rbac-a`-იდან** აძლევს წვდომას `get`/`list` (და მხოლოდ მას) `configmaps`-ზე `rbac-b`-ში.<br/>• შექმენით Pod `rbac-a`-ში `serviceAccountName: dev`-ით. |
| მიღების კრიტერიუმები | • Role `pod-role` `rbac-a`-ში უშვებს ზუსტად `get`, `list`, `watch` `pods`-ზე.<br/>• `dev`-ს არ შეუძლია `delete pods` `rbac-a`-ში.<br/>• `dev`-ს შეუძლია `get`/`list configmaps` `rbac-b`-ში, მაგრამ არ შეუძლია `delete configmaps` და არ შეუძლია `secrets`-ის წაკითხვა იქვე.<br/>• `rbac-a`-ში არსებობს Pod, რომელიც იყენებს ServiceAccount `dev`-ს. |

<details>
<summary>💡 მინიშნება დავალება 11-ისთვის</summary>

`RoleBinding`-ს შეუძლია subject-ზე (`ServiceAccount`) მიუთითოს ნებისმიერი სხვა namespace-იდან -
Kubernetes ამას ოფიციალურად უჭერს მხარს `subjects[].namespace`-ით. მაგრამ თავად `RoleBinding`,
და მასთან დაკავშირებული უფლებები, ყოველთვის მოქმედებს მხოლოდ იმ namespace-ში, სადაც ის თვითონ შეიქმნა -
ამიტომ ახალი Role+RoleBinding სწორედ `rbac-b`-ში უნდა შეიქმნას, და არა `rbac-a`-ში. შეამოწმეთ თავი:
`kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev` უნდა
დააბრუნოს `yes`, ხოლო `kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev` -
`no`.
</details>

---
| **12** | **მომხმარებელი კლიენტის სერტიფიკატით CSR-ის გავლით + namespaced RBAC** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით ახალი Kubernetes-მომხმარებელი `john`, რომელიც ავტენტიფიცირდება client-სერტიფიკატით: დააგენერირეთ private key, შემდეგ CSR (`openssl req -new`) `CN=john`-ით.<br/>• გაგზავნეთ ის როგორც Kubernetes `CertificateSigningRequest` `john-csr` `signerName: kubernetes.io/kube-apiserver-client`-ით; დაამტკიცეთ CSR (`kubectl certificate approve`).<br/>• ამოიღეთ გაცემული სერტიფიკატი `status.certificate`-დან (base64-decode) და შეინახეთ ის private key-თან ერთად `/var/work/tests/artifacts/12/john.crt`-სა და `.../john.key`-ში.<br/>• namespace `development`-ში (უკვე შექმნილია) შექმენით Role, რომელიც უშვებს `create`/`list`/`get` `pods`-ზე, და RoleBinding subject-ზე `{kind: User, name: john}`.<br/>• ააწყვეთ John-ისთვის ცალკე kubeconfig (`kubectl config set-cluster`/`set-credentials --client-certificate/--client-key`/`set-context`) და შეინახეთ ის როგორც `/var/work/tests/artifacts/12/john.kubeconfig`; დარწმუნდით, რომ `kubectl --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development` რეალურად მუშაობს, ხოლო იგივე მოთხოვნა სხვა namespace-ში იღებს `Forbidden`-ს - ეს ამტკიცებს მუშა სერტიფიკატს ისევე, როგორც პირდაპირი TLS-მოთხოვნა, მაგრამ ჩვეული `kubectl`-ით, და არა `curl`-ით.<br/>• დაადასტურეთ ცოცხალი `kubectl auth can-i --as=john` შემოწმებებით: John-ს შეუძლია `create`/`list`/`get` pods `development`-ში, არ შეუძლია მათი `delete` იქვე და არ აქვს იგივე უფლებები სხვა namespace-ში. |
| მიღების კრიტერიუმები | • `john-csr` იყენებს სწორ signer-ს და `Approved`-ია.<br/>• გაცემულ სერტიფიკატს აქვს `CN=john` და რეალურად მოწმდება ამ კლასტერის CA-ით.<br/>• Role+RoleBinding `development`-ში John-ს აძლევს ზუსტად `create`/`list`/`get`-ს `pods`-ზე.<br/>• John-ს არ შეუძლია `delete` pods იქვე და არ აქვს წვდომა სხვა namespace-ებში.<br/>• შენახული `john.crt`/`john.key` რეალურად მიიღება API server-ის მიერ პირდაპირი TLS-მოთხოვნისას (და არა მხოლოდ `--as=john` impersonation-ით).<br/>• აწყობილი kubeconfig არსებობს გზაზე `/var/work/tests/artifacts/12/john.kubeconfig`, და `kubectl --kubeconfig=<ეს ფაილი> get pods -n development` რეალურად მუშაობს, ხოლო იგივე მოთხოვნა სხვა namespace-ში სრულდება `Forbidden`-ით. |

<details>
<summary>💡 მინიშნება დავალება 12-ისთვის</summary>

ამ დავალებას ნუ აგრევთ ლაბ 114-თან: იქ თქვენ აანალიზებთ უკვე არსებულ სერტიფიკატს
kubeconfig-იდან, ხოლო აქ საჭიროა სრულიად ახალი, რეალურად მუშა identity-ის გამოშვება ნულიდან.
RBAC სერტიფიკატზე დაფუძნებული მომხმარებლისთვის უკავშირდება `subjects: [{kind: User, name:
john}]`-ით, და არა `ServiceAccount`-ით - `User`-ს Kubernetes-ში ცალკე API-ობიექტი არ აქვს, მისი
"არსებობა" მთლიანად განისაზღვრება იმით, რომ CN client-სერტიფიკატში ემთხვევა
`name`-ს binding-ში. `--as=john` `kubectl auth can-i`-ში ამოწმებს მხოლოდ RBAC-ლოგიკას
(impersonation), მაგრამ არ ამტკიცებს, რომ სერტიფიკატი რეალურად ვალიდურია - ცალკე დარწმუნდით,
რომ `openssl verify` `/etc/kubernetes/pki/ca.crt`-ით control-plane-ზე აბრუნებს `OK`-ს.
</details>

## შედეგის შემოწმება

სამუშაო მანქანაზე შეასრულეთ:

```bash
check_result
```

შემოწმება შეიცავს Init-ს და თორმეტ დამოუკიდებელ დავალებას. API server-ის შეცვლის შემდეგ
ზოგიერთმა ტესტმა შეიძლება მოკლედ დაელოდოს static Pod-ის გადატვირთვას.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD)

## წაშლა

```bash
TASK=104 make delete_cks_task
```
