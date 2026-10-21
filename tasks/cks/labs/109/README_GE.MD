[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 109 - Secret-ის დაშიფვრა etcd-ში და მინიმალური წვდომა

## მიზანი

ამ CKS-ლაბში თქვენ დაამტკიცებთ, რომ Kubernetes Secret encryption at rest-ის გარეშე etcd-ში
ინახება როგორც წასაკითხი bytes (base64 - დაშიფვრა არ არის), ჩართავთ `aescbc`-ს
`EncryptionConfiguration`-ით, მიაერთებთ მას static `kube-apiserver`-ს, გადაწერთ ძველ
Secret-ებს და შეზღუდავთ მონაცემებზე წვდომას RBAC-ით და `automountServiceAccountToken`-ით.

`aescbc` აქ არჩეულია მხოლოდ გამოცდის მექანიკის `EncryptionConfiguration`-ისა და re-encryption-ის
გასავარჯიშებლად. Kubernetes-ის მიმდინარე დოკუმენტაცია AES-CBC-ს სუსტად მიიჩნევს
და padding-oracle შეტევების რისკის გამო არ გირჩევთ მას; `aesgcm`-იც
გასაღების ავტომატიზებულ როტაციას მოითხოვს. production-ისთვის provider აირჩიეთ აქტუალური
დოკუმენტაციისა და threat model-ის მიხედვით; გარე key manager-ის დროს სასურველია KMS v2
(იხ. [თავი 21](../../course/21/ge.md)).

## Threat model

Encryption at rest იცავს storage compromise-ისგან: დავუშვათ, რომ თავდამსხმელმა მიიღო read-only წვდომა etcd snapshot-ზე ან storage layer-ზე, მაგალითად backup-ის ან volume snapshot-ის გავლით, მაგრამ ავტორიზებული API-წვდომა არ აქვს. დავალება 1 სწორედ ამ საწყის რისკს ამტკიცებს etcd-ის raw კითხვით.

encryption at rest-ის ჩართვის შემდეგ დავალებები 2–4 ამცირებენ ასეთი წვდომის blast radius-ს: პირდაპირ წაკითხულმა მონაცემებმა Secret არ უნდა გაამჟღავნონ. ეს უნივერსალური დაცვა არ არის და API-ზე წვდომის კონტროლის შემცვლელიც არ არის.

თუ თავდამსხმელს აქვს ლეგიტიმური API-წვდომა Secret-ის წაკითხვის უფლებებით, encryption at rest ამ საფრთხისგან არ იცავს: API დააბრუნებს მნიშვნელობას გაშიფვრის შემდეგ. ამიტომ დავალება 5 ცალკე ზღუდავს RBAC-სა და automount-ს, ამცირებს რა ასეთი უფლებების მქონე workload-identity-ის blast radius-ს.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რატომ არ არის base64 `Secret.data`-ში დაშიფვრა?</summary>

base64 - უბრალოდ კოდირებაა, გასაღების გარეშე შექცევადი: ნებისმიერს, ვისაც თავად bytes-ზე წვდომა აქვს (მაგალითად, etcd-ის raw კითხვით), შეუძლია მნიშვნელობა მყისიერად გაშიფროს, რაიმე კრიპტოგრაფიული ოპერაციის გარეშე. დაშიფვრა უკუქცევისთვის გასაღებს მოითხოვს - base64-ს ეს თვისება საერთოდ არ აქვს.
</details>

<details>
<summary>2. რატომ უნდა იდგეს `identity` provider providers-ის სიაში ბოლოს, და არა პირველად?</summary>

`EncryptionConfiguration`-ში providers იკითხება თანმიმდევრობით არსებული ჩანაწერების წასაკითხად, ხოლო პირველი provider გამოიყენება ახალი მონაცემების ჩასაწერად. თუ `identity` ("დაშიფვრის გარეშე") პირველია, ყველა ახალი ჩანაწერი დაუშიფრავად ჩაიწერება, მიუხედავად იმისა, რომ სიაში `aescbc` არის. `identity` ბოლოს საშუალებას იძლევა წავიკითხოთ ძველი (ჯერ არმიგრირებული) plaintext-ჩანაწერები, მაგრამ იძლევა გარანტიას, რომ ყველა ახალი ჩანაწერი პირველი provider-ით იშიფრება.
</details>

<details>
<summary>3. რატომ არ შეიძლება ძველი დაშიფვრის გასაღების წაშლა ახლის დამატებისთანავე?</summary>

etcd-ში არსებული ჩანაწერები ძველი გასაღებით დაშიფრული რჩება მანამ, სანამ მათ აშკარად არ გადაწერენ (re-encryption). თუ ძველ გასაღებს active `EncryptionConfiguration`-იდან ამოიღებთ უფრო ადრე, ვიდრე ყველა ჩანაწერი ახლით გადაიწერება, API server ვერ შეძლებს დარჩენილი ძველი ჩანაწერების გაშიფვრას მიმდინარე provider chain-ით - ისინი ხდება წაუკითხავი, სანამ ძველ გასაღებს კონფიგურაციაში არ დააბრუნებენ. კონფიგიდან გასაღების თავისთავად წაშლა key material-ს ფიზიკურად არ ანადგურებს: თუ შენახულ ძველ გასაღებს provider chain-ში ისევ დაამატებენ, წვდომა აღდგება. მონაცემების შეუქცევადი დაკარგვა წარმოიშობა მხოლოდ იმ შემთხვევაში, თუ თავად key material მართლაც დაიკარგა ან განადგურდა (მაგალითად, გასაღები წაშლამდე არსად შეუნახავთ). თანმიმდევრობა: ახალი გასაღების პირველად დამატება → ყველა Secret-ის გადაწერა → დადასტურება, რომ ყველა ჩანაწერი ახალ გასაღებს იყენებს → ძველი გასაღების შენახვა სანდო ადგილას rollback-ისთვის → მხოლოდ შემდეგ მისი კონფიგიდან ამოღება.
</details>

## ინფრასტრუქტურა

გარემო იშლება Terragrunt-ით AWS `eu-central-1`-ში:

| კომპონენტი | დანიშნულება |
|---|---|
| `vpc` | VPC `10.10.0.0/16` საჯარო ქვექსელებით |
| `ssh-keys` | SSH-გასაღებები worker-ისა და control-plane-ისთვის |
| `k8s-1` | ერთკვანძიანი kubeadm control-plane: Kubernetes **1.36.0**, containerd, **Calico** |
| `worker` | სამუშაო მანქანა `kubectl`-ით; control-plane-ზე (`ssh control-plane`) დაყენებულია სტანდარტული `etcdctl` 3.6.0, როგორც გამოცდაზე |

Control-plane განზრახ იღებს ჩვეულებრივ Pod-ებს - ცალკე Kubernetes worker არ იქმნება.
დავალებების დაწყებამდე bootstrap ქმნის namespace `encryption-109`-სა და უვნებელ
`legacy-secret`-ს. ეს Secret შექმნილია EncryptionConfiguration-ამდე, ამიტომ ემსახურება
plaintext მდგომარეობის კონტროლირებად დადასტურებას.

ოპერაციები node-ზე სრულდება თავად control-plane-ზე, როგორც გამოცდაზე: შედით მასზე
(`ssh control-plane`), იმუშავეთ იქ და გამოდით (`exit`); `kubectl` - სამუშაო მანქანიდან. etcd-ის raw-ჩანაწერი
იკითხება Kubernetes-ის დოკუმენტაციის სტანდარტული `etcdctl`-ით kubeadm-სერტიფიკატებით
`/etc/kubernetes/pki/etcd/`-დან (`ca.crt`, `server.crt`, `server.key`). ბრძანებების მზა მაგალითები -
ეტალონური ამოხსნის განყოფილებაში «სად ვიპოვოთ მაგალითები დოკუმენტაციაში».

## განთავსება

```bash
TASK=109 make run_cks_task
```

დაუკავშირდით სამუშაო მანქანას. კონტექსტი `cluster1-admin@cluster1` უკვე გამართულია.

```bash
time_left
check_result
```

## დავალებები

---
| **1** | **საწყისი plaintext Secret-ის დამტკიცება** |
| :---: | :--- |
| რას ვაკეთებთ | • დაშიფვრის ჩართვამდე მოითხოვეთ raw ჩანაწერი `/registry/secrets/encryption-109/legacy-secret` სტანდარტული `etcdctl get ... --print-value-only`-ით<br/>• შედით control-plane-ზე (`ssh control-plane`) და იმუშავეთ მასზე, როგორც გამოცდაზე: გამოტანა გაატარეთ `strings`-ში და შედეგი შეინახეთ ფაილში control-plane-ზე (`/tmp/plaintext-proof.txt`), შემდეგ დააკოპირეთ ის სამუშაო მანქანაზე ბრძანებით `scp` `/var/work/109/plaintext-proof.txt`-ში |
| მიღების კრიტერიუმები | • ფაილი შეიცავს საწყისი raw-ჩანაწერის `strings`-ის სრულ გამოტანას (ემთხვევა bootstrap-ის snapshot-ს, marker `cks-109-legacy-plaintext`-ის ჩათვლით) და არ შეიცავს `k8s:enc:`-ს<br/>• ხელით აკრეფილი სტრიქონი არ მიიღება<br/>• ეს საწყისი მდგომარეობის დადასტურებაა: `Secret.data` - base64-ია, და არა encryption at rest |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

ეს დავალება უნდა შესრულდეს პირველად, დავალება 2-მდე - როგორც კი EncryptionConfiguration-ს ჩართავთ და Secret-ს გადაწერთ, plaintext-დადასტურება გაქრება და მას post-hoc ვეღარ დააფიქსირებთ. ბრძანება `etcdctl` ფლაგებით `--cacert/--cert/--key` აღებულია Kubernetes-ის ოფიციალური დოკუმენტაციიდან (განყოფილება «Verify that newly written data is encrypted» გვერდზე Encrypting Confidential Data at Rest); kubeadm-ის სერტიფიკატების გზები: `/etc/kubernetes/pki/etcd/ca.crt`, `server.crt`, `server.key`. ზუსტი ბმულები - ეტალონური ამოხსნის განყოფილებაში «სად ვიპოვოთ მაგალითები დოკუმენტაციაში».
</details>

---
| **2** | **EncryptionConfiguration-ის შექმნა Secret-ისთვის** |
| :---: | :--- |
| რას ვაკეთებთ | • control-plane-ზე შექმენით `/etc/kubernetes/enc/encryption-config.yaml`, owner `root:root`, mode `0600`<br/>• ფორმატი: `apiserver.config.k8s.io/v1`, `EncryptionConfiguration`<br/>• `secrets`-ისთვის პირველ provider-ად მიუთითეთ `aescbc` დასახელებული base64-გასაღებით **32 შემთხვევითი bytes**-დან, შემდეგ `identity: {}` |
| მიღების კრიტერიუმები | • ფაილი `root:root` mode `0600` არის დირექტორიაში `root:root` mode `0700`<br/>• `secrets`-ის ძირითადი მოქმედი provider — **პირველი** `aescbc` სწორი named base64 key-ით 32 bytes-იდან<br/>• `identity` დასაშვებია მხოლოდ ბოლოს დროებით fallback-ად legacy plaintext-ისთვის<br/>• Symlink ფაილზე/დირექტორიაზე აკრძალულია |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

გასაღები დააგენერირეთ `head -c 32 /dev/urandom | base64`-ით - სწორედ 32 ბაიტი (და არა base64-სტრიქონის 32 სიმბოლო, რომელიც კოდირების გამო უფრო გრძელი იქნება). შეამოწმეთ თავი: `echo -n "<თქვენი-base64-გასაღები>" | base64 -d | wc -c` უნდა დააბრუნოს ზუსტად `32`.
</details>

---
| **3** | **config-ის მიერთება static kube-apiserver-თან** |
| :---: | :--- |
| რას ვაკეთებთ | • ფრთხილად შეცვალეთ `/etc/kubernetes/manifests/kube-apiserver.yaml`: დაამატეთ flag `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`, read-only `volumeMount` `/etc/kubernetes/enc` და შესაბამისი `hostPath` volume `/etc/kubernetes/enc`<br/>• შეინახეთ manifest-ის backup რედაქტირებამდე |
| მიღების კრიტერიუმები | • მოქმედი manifest შეიცავს flag-ს, mount-სა და hostPath-ს<br/>• static Pod-ის restart-ის შემდეგ `kubectl get --raw='/readyz'` აბრუნებს `ok`-ს |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

სამი ცალკე ცვლილებაა საჭირო ერთდროულად: თავად ფლაგი `--encryption-provider-config`, `volumeMounts` (კონტეინერის შიგნით) და `volumes` (hostPath Pod spec-ის დონეზე) - სამიდან ნებისმიერის დავიწყება ან CrashLoopBackOff-ს გამოიწვევს (ფლაგი ფაილზე მიუთითებს, რომელსაც კონტეინერი ვერ ხედავს), ან იმას, რომ ფლაგი უბრალოდ არ გადაიცემა. backup შეინახეთ `/etc/kubernetes/manifests`-ის **გარეთ**, მაგალითად `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109`. Kubelet static manifests-ის დირექტორიიდან კითხულობს დამატებით არაფარულ ფაილებს; მეზობელი `kube-apiserver.yaml.bak` შეიძლება მეორე static Pod-ად აღიქვან და ახალი კონფიგურაციის გამოყენება დაბლოკონ.
</details>

---
| **4** | **Re-encrypt და ciphertext-ის დამტკიცება** |
| :---: | :--- |
| რას ვაკეთებთ | • API server-ის მზადყოფნის შემდეგ შექმენით `encryption-109`-ში Secret `encrypted-secret` literal-ით `token=cks-109-fresh-ciphertext`<br/>• გადაწერეთ ყველა ადრე არსებული Secret API-ს გავლით (`kubectl get secrets --all-namespaces -o json | kubectl replace -f -`)<br/>• შეამოწმეთ ორივე Secret API-თი და raw etcd-ით<br/>• მხოლოდ ამ შემოწმების შემდეგ წაშალეთ დროებითი `identity` fallback, გადატვირთეთ static kube-apiserver და ხელახლა შეამოწმეთ `/readyz` და ორივე Secret-ის წაკითხვა |
| მიღების კრიტერიუმები | • `legacy-secret` და `encrypted-secret` იკითხება API-ით საწყისი მნიშვნელობებით<br/>• თითოეულის Raw value იწყება `k8s:enc:aescbc:v1:`-ით<br/>• Legacy marker raw etcd-ში აღარ ჩანს<br/>• bootstrap Secret corpus-ის მთელი საწყისი payload/UID შენარჩუნებულია, ყველა ჩანაწერი პირველი მოქმედი გასაღებით არის დაშიფრული<br/>• საბოლოო ფაილის გასაღებს შეუძლია ორივე canary Secret-ის ciphertext-ის გაშიფვრა<br/>• საბოლოო კონფიგურაციაში `identity` არ არის, API healthy-ა |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

თანმიმდევრობა კრიტიკულია: `encrypted-secret`-ის შექმნა → ყველა არსებული Secret-ის გადაწერა `kubectl replace`-ით → raw etcd-ის შემოწმება ორივესთვის (legacy და encrypted) → მხოლოდ შემდეგ `identity`-ის კონფიგიდან ამოღება. თუ `identity`-ს უფრო ადრე ამოიღებთ, ვიდრე `legacy-secret` გადაიწერება, API server provider chain-ით ძველ plaintext-ჩანაწერს აღარ წაიკითხავს, და `legacy-secret` მიუწვდომელი გახდება.
</details>

---
| **5** | **RBAC-ის მინიმიზაცია და automount-ის გამორთვა** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით ServiceAccount `secret-reader` `encryption-109`-ში `automountServiceAccountToken: false`-ით<br/>• Role `secret-reader-109` უნდა იძლეოდეს მხოლოდ `get`-ს მხოლოდ Secret `encrypted-secret`-ზე<br/>• მიაბით ის ამავე სახელის RoleBinding-ით<br/>• შექმენით Pod `secret-reader-109` ამ ServiceAccount-ით, `automountServiceAccountToken: false`-ით, image-ით `registry.k8s.io/pause:3.10` |
| მიღების კრიტერიუმები | • ServiceAccount-ის Effective RBAC მისი სტანდარტული ჯგუფებით უშვებს `get encrypted-secret`-ს `encryption-109`-ში და კრძალავს Secret-ის სხვა ოპერაციებს, მათ შორის სხვა namespace-ების Secret-ზე წვდომას<br/>• Role/RoleBinding ზუსტია<br/>• Pod Running-ია ერთი `pause:3.10`-ით, ავტომატურად ან ხელით მიმაგრებული ServiceAccount token-ებისა და სხვა credential-bearing sources-ის გარეშე (Secret/hostPath/CSI/PVC volumes, Secret env/envFrom)<br/>• უვნებელი emptyDir/ConfigMap volumes დასაშვებია<br/>• `automountServiceAccountToken: false` Pod-სა და ServiceAccount-ში |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

გამოიყენეთ `resourceNames: ["encrypted-secret"]` Role-ში - ამ ველის გარეშე `get`/`list` რესურსზე `secrets` წვდომას მისცემდა namespace-ის ყველა Secret-ზე, `legacy-secret`-ის ჩათვლით, რაც least-privilege-ის მოთხოვნას არღვევს. `pause:3.10` - image-გამშვებია, რომელსაც Kubernetes API საერთოდ არ სჭირდება, ამიტომ automount ორ დონეზე (SA და Pod) ფუნქციონალური შედეგების გარეშე ითიშება.
</details>

## შედეგის შემოწმება

```bash
check_result
```

შემოწმება შეიცავს Init-ს და ხუთ სავალდებულო ტესტს. ტესტი 4 ამოწმებს არა მხოლოდ
კონფიგურაციის ფაილის არსებობას, არამედ ახალი და ადრინდელი
etcd-ჩანაწერის რეალურ ciphertext-ს `k8s:enc:aescbc:v1:` და საბოლოო კონფიგურაციაში migration-only `identity`-ის არარსებობას. რეალურ გარემოში მასობრივ re-encryption-მდე საჭიროა snapshot, გასაღებების
როტაციის გეგმა და კონტროლირებადი ფანჯარა; ეს ლაბი production runbook არ არის.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD)

## წაშლა

```bash
TASK=109 make delete_cks_task
```

## დამატებით: KMS v2 და როტაციის სრული სასიცოცხლო ციკლი

**KMS v2 (არასავალდებულო walkthrough).** გარე KMS-plugin API server-ს უერთდება როგორც
provider `kms` `EncryptionConfiguration`-ში; მისი endpoint - ლოკალური Unix socket-ია, ხოლო provider-ის გასაღები
სტაბილურ სახელს იღებს, მაგალითად `kms-v2-primary`. KMS v2-ში API server plugin-ის გავლით იღებს დაშიფრულ seed-ს (გარე
**KEK**-ით wrapped) და მის საფუძველზე გამოიყვანს გასაღებებს ცალკეული ობიექტების დასაშიფრად. KMS v2
იყენებს seed/DEK-ს API server-ის დონეზე, და არა KMS-ის ცალკე გამოძახებას ყოველი Secret-ისთვის.
etcd-ში ინახება Secret-ის ciphertext და გასაღების აღსადგენად საჭირო მონაცემები. ამრიგად, KEK etcd-ში არ დევს; KMS-ის availability, ACL და backup
უსაფრთხოების მოდელის ნაწილი ხდება. მინიმალური **საილუსტრაციო** provider (endpoint უნდა
შეესაბამებოდეს დაყენებულ plugin-ს) ასე გამოიყურება:

```yaml
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: kms-v2-primary
      endpoint: unix:///var/run/kms-plugin/socket.sock
```

დაამატეთ provider პირველად ახალი ჩანაწერებისთვის, მიამაგრეთ socket static `kube-apiserver`-ში
და დაელოდეთ plugin-ის health-ს re-encryption-მდე. რეალური კონფიგურაციისთვის გამოიყენეთ
მხარდაჭერილი plugin და `kms` v2-ის აქტუალური ფორმატი გამოყენებული ვერსიის დოკუმენტაციიდან
Kubernetes; ეს ლაბი KMS-plugin-ს არ ამაღლებს და მუშა socket-ს არ გასცემს.

**provider-ის გასაღების სრული როტაცია.** დავალება 4-ში შესრულებული plaintext-ის მიგრაცია პირველ
`aescbc`-გასაღებზე - გასაღების სრული როტაცია არ არის. მისთვის: (1) გააკეთეთ დაცული etcd snapshot და
შეამოწმეთ, რომ ძველი გასაღები შენახულია და rollback-ისთვის ხელმისაწვდომია; (2) დაამატეთ ახალი გასაღები
პირველად `aescbc.keys`-ში, ძველი მეორედ დატოვეთ, შემდეგ გადატვირთეთ API server; (3)
გადაწერეთ არსებული Secret-ები API-ს გავლით, რათა ისინი ახალი პირველი გასაღებით დაიშიფროს;
(4) არჩევითი და შემდეგ ყველა raw etcd ჩანაწერისთვის დაადასტურეთ პრეფიქსი
`k8s:enc:aescbc:v1:<ახალი-გასაღების-სახელი>:`; (5) მხოლოდ სრული მიგრაციის, backup-ისა და
წაკითხვის შემოწმების შემდეგ წაშალეთ ძველი გასაღები, გადატვირთეთ API server და ხელახლა შეამოწმეთ `/readyz`
და Secret-ები. KMS v2-სთვის ექვივალენტურად ჯერ primary KEK/plugin გადართავენ, ატარებენ
re-encryption-ს და მხოლოდ შემდეგ გამოიყვანენ ძველ KEK-ს გამოყენებიდან KMS-ის პროცედურით.
