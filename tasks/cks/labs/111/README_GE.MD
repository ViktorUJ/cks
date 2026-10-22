[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 111 - image-ების ანალიზი, სტატიკური შესწორებები და supply-chain evidence

## მიზანი

ამ CKS-ლაბში თქვენ შეკრებთ რეპროდუცირებად evidence-artifacts-ს კონტეინერული
აპლიკაციისთვის: მოწყვლადობებისა და სტატიკური ანალიზატორების ანგარიშებს, `Dockerfile`-ისა და workload-ის manifest-ის
უსაფრთხო შესწორებებს, ორ SBOM-ს, დამოკიდებულებების ვერსიების ძიებას და image-ის
ხელმოწერის შემოწმებას. შედეგი - არა უბრალოდ ტერმინალის გამოტანა: ყოველი ანგარიში უნდა
იყოს შენახული მითითებულ ადგილას და აუდიტისთვის ვარგისი.

ეს CKS-ამოცანაა security tooling-სა და supply chain-ზე, და არა CKA-ს სავარჯიშო. Artifacts-ის უმეტესობა
ლოკალურად ანალიზდება worker-ზე; კლასტერთან დამატებით მუშაობს დავალებები 1c, 4, 5b და 9a-9c
(live Deployments, hardened Deployment Ready/Available-ის შემოწმებითა და HTTP smoke test-ით, Kyverno policy და Pod).

## Threat model

ლაბი ახდენს supply chain-ის ნდობის მოდელირებას რამდენიმე დამოუკიდებელი საფრთხით. მავნე
კოდი ან ცნობილი სისუსტეები image-ში გამოვლინდება სკანერებით Trivy, kubesec,
kube-linter და Hadolint image-ის, Dockerfile-ისა და manifest-ების შესაბამის დონეებზე.

Secrets და token-ები, რომლებიც შემთხვევით დარჩა layer-ში, ცალკე შემოწმებას მოითხოვს: secret
scanning (მაგალითად Trivy secret scanning) და image-ის history-ის დათვალიერება (`docker history`,
ფენების ამოღება). SBOM სხვა ამოცანას წყვეტს - კომპონენტებისა და პაკეტების ვერსიების ინვენტარიზაციას;
ის ეხმარება supply-chain investigation-ს (მაგალითად, მოწყვლადი ბიბლიოთეკის პოვნაში),
მაგრამ არ წარმოადგენს ფენების history-ში secrets-ის ძიების საიმედო მექანიზმს და secret
scanning-ს არ ანაცვლებს. მაშინაც კი, თუ მუშა კონფიგურაცია უკვე აღარ შეიცავს secret-ს, ის შეიძლება დარჩეს
ხელმისაწვდომი ფენების history-ში.

mutable-tag tampering-ის საფრთხე იმაში მდგომარეობს, რომ დეპლოის შემდეგ იმავე, უცვლელი ტეგიანი მითითებით
შეიძლება სხვა, მავნე image-ის ჩანაცვლება. სწორედ ამიტომ არის digest pinning მნიშვნელოვანი
დავალებებში 3–5: ის აფიქსირებს image-ის კონკრეტულ შიგთავსს, და არა მხოლოდ მის სახელსა და ტეგს.

ხელმოწერის შემოწმება დავალება 7-ში ამტკიცებს, რომ კონკრეტული digest ხელმოწერილია სანდო
key/identity-ით (signature integrity), მაშინ როცა Trivy scan დავალება 1-ში მხოლოდ აჩვენებს, რომ
მის detection coverage-ში შემავალი ცნობილი მოწყვლადობები მიმდინარე vulnerability DB-ის პირობებში ვერ მოიძებნა
(თავად Trivy დოკუმენტაციაში აღწერს trade-off-ს precision-ის სასარგებლოდ, რომლის დროსაც false
negatives შესაძლებელია - "0 findings" არ ნიშნავს მოწყვლადობების არარსებობის formal proof-ს). ეს დაცვის განსხვავებული
ღერძებია: არც ერთი მათგანი მეორეს არ ანაცვლებს, რადგან vulnerability != signature. ხელმოწერა -
ეს არ არის იგივე, რაც provenance/attestation
(მაგალითად SLSA-style build metadata იმის შესახებ, რისგან და როგორ არის აწყობილი artifact): `cosign
verify` ადასტურებს ხელმოწერის ავთენტურობას, და არა აწყობის სრულ ისტორიას - attestation-ისთვის
Sigstore გვთავაზობს ცალკე ბრძანებებს `cosign attest`/`cosign verify-attestation`, ამ ლაბში
გამოუყენებელს.

ლოკალური `cosign verify` (დავალება 7) თავისთავად enforcement არ არის: ის ამტკიცებს
კონკრეტული image reference-ის ხელმოწერას შემოწმების მომენტში, მაგრამ ვინმეს ხელს არ უშლის გაუშვას
ხელმოუწერელი ან სხვაგვარად ხელმოწერილი image პირდაპირი `kubectl apply`-ით, CI-ის გვერდის ავლით. მხოლოდ
admission-time შემოწმება (დავალება 9a-9c) ხდის ხელმოწერას Pod-ის კლასტერში დაშვების სავალდებულო პირობად -
ეს არის განსხვავება «ხელმოწერა შევამოწმეთ» და «კლასტერი ხელმოუწერელ image-ს არ გაუშვებს» შორის.

ამ თვისების დამტკიცებას სიფრთხილე სჭირდება: უკვე არსებული Deployment-ის განმეორებითი `kubectl apply` არ ქმნის ახალ Pod-ს, თუ template არ შეცვლილა, ამიტომ
`Running` შეიძლება ნიშნავდეს «ძველი Pod, policy-მდე შექმნილი», და არა «policy-მ დაუშვა
სწორედ ეს image» (დავალება 9b აშკარად ამოწმებს `creationTimestamp`-ს). ანალოგიურად unsigned
DENY ამტკიცებს თვისებას მხოლოდ იმ შემთხვევაში, თუ შესამოწმებელი digest რეალურად არსებობს და pullable-ია
იმავე repository-ში, რაც ხელმოწერილი image (დავალება 9c) - წინააღმდეგ შემთხვევაში admission შეიძლება უარს ამბობდეს
registry-ში არარსებული manifest-ის გამო, და არა ხელმოწერის არარსებობის გამო.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რატომ არ არის SBOM image layer-ში დარჩენილი secrets-ის ძიების საიმედო მექანიზმი?</summary>

SBOM წყვეტს კომპონენტებისა და პაკეტების ვერსიების ინვენტარიზაციის ამოცანას (რა არის დაყენებული, რა ვერსიისაა) - ეს პაკეტების მენეჯერის მეტამონაცემების სტრუქტურული ანალიზია, და არა ფენების ფაილების შიგთავსში თვითნებური სტრიქონების/secrets-ის ძიება. Secret, დარჩენილი, მაგალითად, გარემოს ცვლადში ENV ან დროებით ფაილში აწყობისას, შეიძლება დარჩეს ფენების history-ში იმის შემდეგაც, რაც საბოლოო ფენა მას აღარ შეიცავს - ამისთვის საჭიროა ცალკე ინსტრუმენტი (secret scanning, `docker history`, ფენების ამოღება), და არა SBOM.
</details>

<details>
<summary>2. რა განსხვავებაა იმას შორის, რასაც ამტკიცებს Trivy scan (დავალება 1), და იმას შორის, რასაც ამტკიცებს Cosign-ის ხელმოწერა (დავალება 9a-9c)?</summary>

შემოწმების მომენტში, vulnerability DB-ისა და Trivy-ის დეტექტირების ლოგიკის მიმდინარე მდგომარეობით, სკანმა ვერ აღმოაჩინა ცნობილი მოწყვლადობები, რომლებიც მის detection coverage-ში ხვდება - ეს image-ის შიგთავსის ხარისხს/უსაფრთხოებას ეხება იმ ზომით, რა ზომითაც Trivy-ს მისი დანახვა შეუძლია. თავად Trivy-ის დოკუმენტაცია პირდაპირ აღწერს trade-off-ს precision-ის სასარგებლოდ (false positives-ის მინიმიზაცია), რომლის დროსაც false negatives შესაძლებელია - ანუ "0 findings" არ არის მოწყვლადობების სრული არარსებობის ფორმალური დამტკიცების ექვივალენტი. Cosign-ის ხელმოწერა ამტკიცებს SIGNATURE INTEGRITY-ს - რომ კონკრეტული digest ხელმოწერილია სანდო გასაღებით/identity-ით, ანუ ვიღაც უფლებამოსილმა დაადასტურა, რომ სწორედ ეს არის artifact, რომელიც უნდა განთავსდეს. ეს არ არის იგივე, რაც provenance/attestation (აწყობის სრული ისტორია - რისგან, ვის მიერ და როგორ არის აწყობილი artifact): attestation-ისთვის Sigstore-ში არის ცალკე ბრძანებები (`cosign attest`/`cosign verify-attestation`), ამ ლაბში გამოუყენებელი. Image შეიძლება სრულიად უსაფრთხო იყოს (0 CVE) და ამავდროულად ხელმოუწერელი - ან ხელმოწერილი, მაგრამ უცნობი მოწყვლადობა შეიცავდეს. ეს დაცვის ორი დამოუკიდებელი ღერძია.
</details>

<details>
<summary>3. რატომ არ უშლის ხელს ლოკალური `cosign verify` CI-ში ვინმეს ხელმოუწერელი image-ის განთავსებას `kubectl apply`-ით?</summary>

`cosign verify`, ლოკალურად შესრულებული (მაგალითად, CI pipeline-ში), - უბრალოდ ერთი ბრძანებაა, რომელიც ამოწმებს ხელმოწერას და შედეგს უბრუნებს მას, ვინც ის გამოიძახა. ის Kubernetes API-ის admission-ის გზაში ჩაშენებული არ არის - არაფერი უშლის ხელს კლასტერზე წვდომის მქონე ვინმეს, უბრალოდ შეასრულოს `kubectl apply` ნებისმიერი image-ით, CI-ს მთლიანად გვერდის ავლით. მხოლოდ admission-time შემოწმება (დავალება 9a-9c), კლასტერში policy-ად ჩაშენებული, ხდის ხელმოწერას დაშვების სავალდებულო პირობად - ეს არის განსხვავება "ჩვენ შევამოწმეთ" და "კლასტერი ფიზიკურად არ გაატარებს" შორის.
</details>

## ინფრასტრუქტურა

გარემო იქმნება Terragrunt-ით AWS `eu-central-1`-ში.

| კომპონენტი | დანიშნულება |
|---|---|
| `vpc` | VPC `10.111.0.0/16` საჯარო ქვექსელებით |
| `ssh-keys` | node-ზე წვდომა |
| `k8s-1` | ერთკვანძიანი kubeadm Kubernetes `1.36.0`, containerd და **Calico** |
| `worker` | სამუშაო სადგური ანალიზისთვის, `kubectl`, `check_result` და security tools |

ინფრასტრუქტურა CKA-style-ია: ერთადერთი control-plane-node დაშვებულია workload-ისთვის და
მონიშნულია `cks.io/lab=111`-ით. ძირითადი ბრძანებები და security tools worker-ზე გაიშვება.
Kubernetes-კლასტერი გამოიყენება როგორც target environment hardened workload-ისა და
admission-time signature policy-ის შესამოწმებლად: დავალება 4 ანთავსებს `catalog`-ს, ხოლო დავალებები 9b/9c
ასრულებენ positive/negative admission probes-ს.

worker-ზე წინასწარ ხელმისაწვდომია ზუსტად ეს ფიქსირებული ვერსიები:

| ინსტრუმენტი | ვერსია | დანიშნულება |
|---|---:|---|
| Trivy | `0.74.0` | CVE და image-ის პაკეტების სია |
| kubesec | `2.14.0` | Kubernetes YAML-ის security score |
| kube-linter | `0.8.3` | Kubernetes YAML-ის policy lint |
| Hadolint | `2.12.0` | Dockerfile-ის lint |
| Syft | `1.51.0` | SBOM CycloneDX JSON |
| bom | `0.8.0` | SBOM SPDX JSON (`bom`-ის ნატიური ფორმატი) |
| Cosign | `3.1.3` | OCI-image-ის ხელმოწერის signing და verification |

Helm და `install-kyverno` ასევე ხელმისაწვდომია worker-ზე, მაგრამ Kyverno განზრახ **არ არის დაყენებული**:
მისი დაყენება დავალება 9-ის ნაწილია, როგორც ლაბ 108-ში. `install-kyverno` ამაგრებს Kyverno-ს
`1.19`/chart `3.9.0`-ს; ამ ვერსიისთვის upstream-ის ოფიციალური support matrix - Kubernetes
`1.33-1.35`, ხოლო ეს კლასტერი `1.36`-ზეა. ეს შეგნებული lab-specific გამონაკლისია
გატესტილი დიაპაზონის გარეთ (ლაბ 108-ის პრეცედენტის ანალოგიურად), და არა გარანტირებული
ოფიციალური მხარდაჭერა - Kyverno-ს განახლებისას მოხსენით ეს გამონაკლისი.

## წინასწარი პირობები და შეზღუდვები

**podman და registry სტენდზე უკვე გამართულია.** image-ების აწყობისა და გამოქვეყნებისთვის გამოიყენეთ `podman`
(გამოცდის სიიდან ინსტრუმენტი; rootless, მომხმარებლით `ubuntu`). დავალებები 3 და 9c მოითხოვს image-ის აწყობასა და
**გამოქვეყნებას** registry-ში, რომელიც worker-იდანაც და კლასტერიდანაც ხელმისაწვდომია (immutable-მითითება
`repo@sha256:...` registry-იდან მიიღება, ლოკალური image ID არ გამოდგება). ასეთი registry -
`registry:2` control-plane-ზე - bootstrap-მა გაუშვა:

- მისამართი: `<IP control-plane>:5000`, ის ჩაწერილია `/etc/cks111/registry`-ში worker-ზე;
- პროტოკოლი - ჩვეულებრივი HTTP VPC-ის შიგნით: podman worker-ზე და containerd node-ზე მასზე გამართულია როგორც
  insecure registry-ზე (ფლაგი `--tls-verify=false` საჭირო არ არის), ხოლო Kyverno-ს `ImageValidatingPolicy`-ში საჭიროა
  `credentials.allowInsecureRegistry: true`;
- მონაცემები ინახება node-ის ლოკალურ PV-ზე (`/var/lib/cks111-registry`), ამიტომ გადაიტანს
  registry-ის Pod-ის გადატვირთვას;
- გამოქვეყნებული image-ის digest-ს იღებთ `podman push --digestfile`-დან, ხოლო manifest-ის არსებობას
  ამოწმებთ მოთხოვნით `/v2/`-ზე (ამ registry-სთვის HTTPS-only ინსტრუმენტები, როგორიცაა `docker buildx imagetools`, არ გამოდგება);
- ბრძანებების დეტალური თანმიმდევრობა - [ამოხსნის](worker/files/solutions/1_GE.MD) ნაბიჯში «0. მომზადება».

**Docker Hub-ის ლიმიტი.** ერთი IP-დან ანონიმურ pull-ებს აქვთ ლიმიტი (დაახლოებით 100 მოთხოვნა 6 საათში).
რომ `check_result` მას არ დაეჯახოს, bootstrap ერთხელ ჩამოტვირთავს ლაბის image-ებს ლოკალურ ქეშში
(`nginx:1.27.3-alpine` და კანდიდატები დავალებებისთვის 1b/1c), ხოლო Trivy და Syft განმეორებითი სკანებისას
image-ს ამ ქეშიდან იღებენ იმავე მითითებით `სახელი@sha256:...`, Docker Hub-ს არ მიმართავენ. `bom` image-ის წაკითხვას
მხოლოდ registry-იდან ახერხებს, ამიტომ ის ისევ აკეთებს რამდენიმე მოთხოვნას გაშვებაზე.
თუ Docker Hub მაინც დააბრუნებს `TOOMANYREQUESTS`-ს, დაელოდეთ (ლიმიტის ფანჯარა მოძრავია) ან შეასრულეთ
`podman login docker.io` თქვენი ანგარიშით.

**Cosign და გასაღების პაროლი.** `cosign generate-key-pair` და `cosign sign --key` გასაღების პაროლს
ითხოვენ; სასწავლო წყვილისთვის შეგიძლიათ ის ცარიელი დატოვოთ (`export COSIGN_PASSWORD=""`), რომ ბრძანებები
შეყვანას არ ელოდონ.

**`trivy sbom` და SBOM OS-ის გარეშე (დავალება 8).** `bom`-ის SPDX multi-arch image-ისთვის OS-ის შესახებ
მონაცემებს არ შეიცავს: Trivy წერს `Detected OS family="none"` და მოწყვლადობებს ვერ პოულობს (`Results` ცარიელია).
ამიტომ დავალება 8-ში სკანირდება CycloneDX დავალება 7-დან - მასში არის კომპონენტი `operating-system`,
და `trivy sbom` იძლევა არაცარიელ `Results`-ს.

## განთავსება

```bash
TASK=111 make run_cks_task
```

დაუკავშირდით worker-ს და აირჩიეთ კონტექსტი:

```bash
kubectl config use-context cluster1-admin@cluster1
cd /home/ubuntu/cks-111
check_result
```

თავდაპირველად `Dockerfile` და `deployment.yaml` განზრახ არაუსაფრთხოა. სამუშაო artifacts
შექმენით მხოლოდ `/var/work/tests/artifacts/<ნომერი>/`-ში.

## დავალებები

`nginx:1.27.3-alpine` - mutable tag-ია, და არა დაფიქსირებული მითითება. ჯერ მიიღეთ registry manifest digest-ის კანონიკური მნიშვნელობა Trivy JSON-ის `Metadata.RepoDigests[0]`-დან და გამოიყენეთ immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` (შემდგომში `$IMAGE`). საკუთარი hardened image-ისთვის ჯერ ააგეთ და გამოაქვეყნეთ image კლასტერისთვის ხელმისაწვდომ registry-ში, შემდეგ გამოიყენეთ მისი manifest digest; ლოკალური image ID და layer DiffID registry manifest digest არ არის.

---
| **1** | **Trivy: image-ის მოწყვლადობების ანგარიში** |
| :---: | :--- |
| რას ვაკეთებთ | • დაასკანერეთ immutable `$IMAGE` Trivy-ით, OS და library vulnerabilities-ის ჩათვლით.<br/>• შეინახეთ სტრუქტურირებული JSON `/var/work/tests/artifacts/1/trivy-report.json`-ში. |
| მიღების კრიტერიუმები | • **ფაილი:** არაცარიელია, JSON წარმატებით პარსირდება `jq`-ით, შეიცავს `Results`-სა და გაანალიზებული image-ის immutable reference-ს.<br/>• **ახალი შემოწმება:** checker დამოუკიდებლად იმეორებს `trivy image`-ს იმავე image-ისთვის და მოითხოვს, რომ ეს ახალი სკანი წარმატებით დაემთხვეს `ArtifactName`-ით.<br/>• ხელით დაწერილი, მაგრამ სინტაქსურად ვალიდური JSON არ გადის. |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

`$IMAGE` აიგება ორ ნაბიჯად: ჯერ ასკანერებთ `nginx:1.27.3-alpine`-ს (ჩვეულებრივი tag) და იღებთ `Metadata.RepoDigests[0]`-ს ამ პირველი JSON-ანგარიშიდან, შემდეგ ხელახლა აგებთ ბრძანებას `nginx:1.27.3-alpine@sha256:<digest>`-ით და ასკანერებთ უკვე immutable-მითითებას - სწორედ ეს მეორე ანგარიში უნდა შეინახოთ როგორც საბოლოო. Trivy-ის გამოტანიდან `ImageID`/`DiffID` registry digest-ის ჩანაცვლებად ნუ გამოიყენებთ - ეს ლოკალური იდენტიფიკატორებია, რომლებიც registry-ში manifest digest-ს არ ემთხვევა.
</details>

---
| **1b** | **Multi-image CVE triage: image-ის პოვნა, რომელიც კონკრეტულ CVE-ს შეიცავს** |
| :---: | :--- |
| რას ვაკეთებთ | • გახსენით `~/cks-111/candidates.txt` - იქ სამი immutable image reference (`CANDIDATE_1/2/3`) და მიზნობრივი `TARGET_CVE` არის, თქვენი ლაბის ინსტანსისთვის ინდივიდუალურად განსაზღვრული bootstrap-ის დროს.<br/>• დაასკანერეთ **სამივე** image Trivy-ით და გაარკვიეთ, რომელი მათგანი შეიცავს რეალურად `TARGET_CVE`-ს.<br/>• შეინახეთ სწორედ ამ image-ის JSON-ანგარიში `/var/work/tests/artifacts/1b/target-scan.json`-ში.<br/>• სტრიქონი `OFFENDING_IMAGE=<ამ image-ის სრული მითითება>` შეინახეთ `/var/work/tests/artifacts/1b/answer.txt`-ში. |
| მიღების კრიტერიუმები | • **პასუხი:** `answer.txt` მიუთითებს სწორედ იმ `CANDIDATE_N`-ზე, რომლის რეალური Trivy-სკანი შეიცავს `TARGET_CVE`-ს.<br/>• **ანგარიში:** `target-scan.json` - ამავე image-ის Trivy-ის ნამდვილი გამოტანაა (checker თავად იმეორებს სკანირებას და ადარებს). |

<details>
<summary>💡 მინიშნება დავალება 1b-ისთვის</summary>

`TARGET_CVE` ლაბის ყოველ ინსტანსს თავისი აქვს - ის გამოითვლება provisioning-ის დროს ცოცხალი Trivy vulnerability DB-დან, და წინასწარ ჩაწერილი არ არის, ამიტომ ამ ფაილში თქვენი საკუთარი პასუხია. ტეგის სახელით ნუ გამოიცნობთ ("ყველაზე ძველი - ალბათ მოწყვლადია") - რეალურად დაასკანერეთ სამივე და იპოვეთ `VulnerabilityID`-ის ზუსტი დამთხვევა JSON-ის შიგნით. ერთი ბრძანება image-ზე: `trivy image --format json "$ref" | tee scan.json`, შემდეგ `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | index("<TARGET_CVE>")' scan.json` - `null` ნიშნავს, რომ ეს კონკრეტული CVE სწორედ ამ image-ში არ არის (მასში სრულიად შეიძლება სხვა CVE იყოს - ეს არ მოწმდება).
</details>

---
| **1c** | **Workload image-ების გარჩევა CRITICAL დონის მიხედვით** |
| :---: | :--- |
| რას ვაკეთებთ | • namespace `cks-111`-ში უკვე განთავსებულია 4 Deployment (label `cks.io/task=1c`), თითოეული ერთი immutable digest-pinned image-ით.<br/>• მიიღეთ image references ამ LIVE Deployments-იდან (ტეგის სახელით ნუ გამოიცნობთ), დაასკანერეთ **ყველა 4** image Trivy-ით `--severity CRITICAL`-ით და თითოეულისთვის დათვალეთ უნიკალური CRITICAL `VulnerabilityID`-ების რაოდენობა.<br/>• განსაზღვრეთ Deployment CRITICAL-ების ყველაზე დიდი რაოდენობით ("ყველაზე მოწყვლადი") და ორი Deployment ყველაზე მცირე რაოდენობით ("ორი ყველაზე ნაკლებად მოწყვლადი"). ჩაწერეთ მათი სახელები `/var/work/tests/artifacts/1c/ranking.txt`-ში როგორც `MOST_VULNERABLE=<deployment-name>`, `LEAST_VULNERABLE_1=<deployment-name>`, `LEAST_VULNERABLE_2=<deployment-name>`.<br/>• ყველაზე მოწყვლადი Deployment-ის image-ისთვის დააგენერირეთ CycloneDX SBOM **სწორედ Trivy-ით** (`trivy image --format cyclonedx`) `1c/cyclonedx.json`-ში.<br/>• შემდეგ remediate: `replicas > 0` დატოვეთ მხოლოდ ორ ყველაზე ნაკლებად მოწყვლად Deployment-ზე, დანარჩენი ორი (ყველაზე მოწყვლადის ჩათვლით) დაამასშტაბეთ `replicas: 0`-მდე. |
| მიღების კრიტერიუმები | • **Ranking:** checker თავად იმეორებს ყველა 4 live image-ის Trivy CRITICAL-სკანს და ranking-ს თავიდან ითვლის - `ranking.txt` უნდა ემთხვეოდეს ამ ახალ სკანირებას, და არა მოძველებულს/გამოცნობილს.<br/>• **SBOM:** `cyclonedx.json` - ვალიდური CycloneDX-დოკუმენტია სწორედ Trivy-სგან, რომელიც რეალურად ყველაზე მოწყვლადი Deployment-ის image-ს ეხება.<br/>• **Remediation:** ზუსტად 2 Deployment-ს (ახალი სკანით ყველაზე ნაკლებად მოწყვლადები) აქვს `replicas > 0`, დანარჩენ 2-ს - `replicas: 0`. |

<details>
<summary>💡 მინიშნება დავალება 1c-სთვის</summary>

image references მიიღეთ ასეთი სახის ბრძანებით `kubectl -n cks-111 get deployment -l cks.io/task=1c -o jsonpath=...` - Deployment-ის სახელით გამოცნობას ნუ ცდილობთ, რომელი image არის "უფრო ახალი" ან "უფრო უსაფრთხო". დასათვლელი ბრძანება: `trivy image --scanners vuln --severity CRITICAL --format json <ref>`, შემდეგ `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length'`. CycloneDX-ისთვის გამოიყენეთ სწორედ `trivy image --format cyclonedx --output <file> <ref>` - და არა Syft (Syft უკვე გამოიყენება დავალება 7-ში სხვა image-ისთვის, აქ აშკარად Trivy მოითხოვება). დამასშტაბება კეთდება `kubectl scale deployment/<name> -n cks-111 --replicas=0`-ით (ან `--replicas=1`-ით დასატოვებლებისთვის).
</details>

---
| **2** | **სტატიკური ანალიზის საწყისი ანგარიშები** |
| :---: | :--- |
| რას ვაკეთებთ | • შესწორებებამდე (ამ სამი ფაილიდან არცერთს შეხების გარეშე დავალება 3-ის დაწყების შემდეგ) შეინახეთ შედეგები: Hadolint `2/hadolint-before.txt`-ში, kubesec JSON `2/kubesec-before.json`-ში, kube-linter JSON `2/kube-linter-before.json`-ში.<br/>• გაუშვით ისინი უშუალოდ საწყის სასტარტო `Dockerfile`/`deployment.yaml`-ზე.<br/>• ანგარიშების ფაილებში შეცდომებს `\|\| true`-თი ნუ დამალავთ: linter-ის არანულოვანი exit code მოსალოდნელია. |
| მიღების კრიტერიუმები | • **Artifacts:** სამივე არსებობს; Hadolint შეიცავს findings-ს, kubesec შეიცავს `scoring`-ს, kube-linter - ვალიდურ KubeLinter JSON-ობიექტს ველებით `Reports` და `Summary`; შესწორებებამდე `Reports` შეიცავს findings-ს.<br/>• **baseline-თან შედარება:** checker ადარებს სამივე artifact-ის შიგთავსს თავის baseline-თან, რომელიც provisioning-ის დროს, სტუდენტისთვის ფაილების გაცემამდე, საწყის სასტარტო ფაილებზე იქნა მიღებული.<br/>• ხელით დაწერილი, მაგრამ სინტაქსურად ვალიდური ანგარიში არ გადის. |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

linter-ის არანულოვანი exit code პრობლემების აღმოჩენისას - მოსალოდნელი ქცევაა, და არა თქვენი ბრძანების შეცდომა. თუ გამოძახებას `|| true`-ში ახვევთ მხოლოდ იმიტომ, რომ სკრიპტი `set -e`-ით არ გაჩერდეს, დარწმუნდით, რომ ამასთან ბრძანების გამოტანა მაინც ინახება ფაილში (`tee`-ით ან გადამისამართებით `|| true`-მდე), და არ იკარგება.
</details>

---
| **3** | **Dockerfile-ის შესწორება findings-ის მიხედვით** |
| :---: | :--- |
| რას ვაკეთებთ | • შეასწორეთ `/home/ubuntu/cks-111/Dockerfile`: დააფიქსირეთ საბაზო image immutable reference-ით `nginx:1.27.3-alpine@sha256:<manifest-digest>`.<br/>• ნუ გამოიყენებთ `ADD`-ს URL-ით, token-ს ნუ შეინახავთ `ENV`-ში, `sudo`-ს ნუ დააყენებთ.<br/>• დაამატეთ არაპრივილეგირებული `USER` (uid არა `0`). გამოიყენეთ `COPY` და პაკეტების რეპროდუცირებადი დაყენება მხოლოდ აუცილებლობის შემთხვევაში.<br/>• დაამატეთ `ARG CKS_SIGNATURE_TEST=signed` და `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` დანარჩენი ინსტრუქციების გვერდით - ეს image-ის კონტროლირებადი განსხვავების ერთადერთი წერტილია, რომელიც დავალება 9c-ში დაგჭირდებათ, რათა სხვა digest-ის გარანტია იყოს აქ შემოწმებული security-თვისებების შეუცვლელად.<br/>• შესწორების შემდეგ შეინახეთ Hadolint-ის წარმატებული გამოტანა `3/hadolint-after.txt`-ში. |
| მიღების კრიტერიუმები | • **Dockerfile:** არ არის `latest`, წაშლილია remote `ADD`, არ დარჩენილა `API_TOKEN`/`TOKEN`, არის non-root `USER`, არის `ARG CKS_SIGNATURE_TEST` და `LABEL cks.signature-test`.<br/>• **Hadolint:** საბოლოო report არ შეიცავს `DL3007`, `DL3013`, `DL3020`, `DL3045`-ს. |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

`ARG`/`LABEL` `CKS_SIGNATURE_TEST`-ისთვის შეიძლება Hadolint-ის მიმდინარე findings-თან კავშირის არმქონედ მოგეჩვენოთ - ეს სპეციალურად აქ წინასწარ ემატება, რათა დავალება 9c-მ (გაცილებით მოგვიანებით) ფიზიკურად განსხვავებული image `--build-arg`-ით ააწყოს, Dockerfile-ის ხელახლა გადაწერის გარეშე. დაამატეთ ეს ორი სტრიქონი ახლავე, თუნდაც მათი სარგებლობა მხოლოდ 9c-ში გახდეს გასაგები.
</details>

---
| **4** | **workload YAML-ის შესწორება kubesec-ისა და kube-linter-ის მიხედვით** |
| :---: | :--- |
| რას ვაკეთებთ | • ჯერ ააგეთ და გამოაქვეყნეთ hardened image დავალება 3-იდან, შემდეგ მიუთითეთ `deployment.yaml`-ში მისი immutable manifest reference `registry/.../catalog@sha256:<manifest-digest>` (და არა upstream nginx).<br/>• Pod-ის დონეზე დაამატეთ `automountServiceAccountToken: false`, `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`.<br/>• კონტეინერში დააყენეთ `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, requests/limits CPU-სა და memory-სთვის.<br/>• nginx-ისთვის მიამაგრეთ writable `emptyDir`/tmpfs temp, pid/run, cache და config paths-ზე და მოამზადეთ config გაშვებამდე.<br/>• წაშალეთ `privileged`, გამოიყენეთ Deployment, დაადასტურეთ Ready/Available და წარმატებული HTTP request.<br/>• შეინახეთ ახალი ანგარიშები `4/kubesec-after.json` და `4/kube-linter-after.json`. |
| მიღების კრიტერიუმები | • **Image:** YAML იყენებს digest-pinned hardened image-ს `USER 101`-ით, და არა upstream nginx-ს.<br/>• **Manifest:** საჭირო ველები, init container `prepare-nginx-config` და writable mounts არსებობს; `privileged` არ არის.<br/>• **ფუნქციონირება:** Deployment Available-ა და HTTP request წარმატებულია.<br/>• **ანგარიშები:** ორივე საბოლოო ანგარიში - ვალიდური JSON-ია. |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

`readOnlyRootFilesystem: true` მოითხოვს writable გზებს ყოველი დირექტორიისთვის, რომელშიც nginx ჩვეულებრივ წერს: `/tmp`, `/var/run` (PID-ფაილი), `/var/cache/nginx` (ქეში) და `/etc/nginx/conf.d` (თუ config გაშვებისას გენერირდება). თუ ერთ-ერთსაც გამოტოვებთ - კონტეინერი გაეშვება, მაგრამ ჩავარდება, როცა nginx პირველად ცდის იქ რაიმეს ჩაწერას. Init container `prepare-nginx-config` საჭიროა ნაგულისხმევი config-ის ცალკე writable volume-ში გადასაკოპირებლად მთავარი კონტეინერის გაშვებამდე - სწორედ ამიტომ არის ის ცალკე ნახსენები მიღების კრიტერიუმებში.
</details>

---
| **5** | **პაკეტების ვერსიების ძიება** |
| :---: | :--- |
| რას ვაკეთებთ | • გამოიყენეთ Trivy ყველა პაკეტის სიის რეჟიმში `$IMAGE`-ისთვის.<br/>• შეინახეთ ბრძანება, immutable image reference, კანონიკური `nginx@sha256:<manifest-digest>` `Metadata.RepoDigests[0]`-დან და სულ მცირე სამი სტრიქონი `სახელი=ვერსია` `/var/work/tests/artifacts/5/version-search.txt`-ში.<br/>• ძიებას ხელით სიით ნუ ჩაანაცვლებთ: evidence-ში უნდა იყოს ბრძანების სტრიქონი `trivy image --list-all-pkgs`-ით. |
| მიღების კრიტერიუმები | • **Artifact:** შეიცავს ბრძანებას, immutable `nginx:1.27.3-alpine@sha256:...`-ს, `repo_digest=nginx@sha256:...`-ს Trivy-დან და მინიმუმ სამ წყვილს package/version.<br/>• **ახალი შემოწმება:** checker დამოუკიდებლად იმეორებს `trivy image --list-all-pkgs`-ს იმავე image-ისთვის და მოითხოვს, რომ `repo_digest=` და მინიმუმ სამი შენახული წყვილი `name=version` ამ ახალ სკანს დაემთხვეს.<br/>• ხელით დაწერილი, მაგრამ სინტაქსურად დამაჯერებელი სია არ გადის. |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

ფლაგი იწოდება სწორედ `--list-all-pkgs`, და არა `--list-packages` ან მსგავსი ვარიანტი - შეამოწმეთ ფლაგის ზუსტი სახელი `trivy image --help`-ში, თუ ბრძანება არ მუშაობს. ბრძანების რეალური გამოტანა შეინახეთ ფაილში (მაგალითად `tee`-ით), რამდენიმე სტრიქონს package=version ხელით "მეხსიერებიდან" ნუ გადაწერთ - ტესტი ეძებს თავად ბრძანების სტრიქონს როგორც დადასტურებას, რომ მონაცემები ინსტრუმენტიდან მოვიდა.
</details>

---
| **5b** | **პაკეტის ვერსიის პოვნა workload image-ებში და დამრღვევი კონტეინერების წაშლა** |
| :---: | :--- |
| რას ვაკეთებთ | • namespace `cks-111`-ში უკვე განთავსებულია Deployment `pkg-audit-app` სამი კონტეინერით (`c1`, `c2`, `c3`), თითოეული თავის immutable digest-pinned image-ზე.<br/>• ზუსტად სამი image-იდან ორში არის ერთი და იგივე პაკეტი კონკრეტული ვერსიისა - თქვენი ლაბის ინსტანსისთვის მოცემული `TARGET_PACKAGE`/`TARGET_VERSION` დინამიკურად არის განსაზღვრული provisioning-ის დროს, ჩაფიქსირებული მნიშვნელობები არ არის.<br/>• მიიღეთ სამივე image reference live Deployment-იდან, თითოეულისთვის შეასრულეთ `bom generate` (თითოეული SBOM ცალკე შეინახეთ `/var/work/tests/artifacts/5b/bom/`-ში).<br/>• განსაზღვრეთ, რომელი ორი კონტეინერი შეიცავს რეალურად ერთსა და იმავე package/version-ს, და ჩაწერეთ ნაპოვნი წყვილი `5b/answer.txt`-ში როგორც `TARGET_PACKAGE=<name>` და `TARGET_VERSION=<version>`.<br/>• წაშალეთ სწორედ ეს ორი დამრღვევი კონტეინერი Deployment-იდან (`kubectl edit`-ით/გასწორებული manifest-ის `kubectl apply`-ით) ისე, რომ დარჩეს მხოლოდ "სუფთა" კონტეინერი, ხოლო Deployment დარჩეს `Available`. |
| მიღების კრიტერიუმები | • **პასუხი:** `answer.txt` ასახელებს რეალურ package/version-ს, რომელიც არის სწორედ სამი საწყისი image-იდან ორში (და არა გამოცნობილს). ამ ორ image-ს ბევრი საერთო პაკეტი აქვს: გამოდგება ნებისმიერი ერთი წყვილი `name=version`, რომელიც მესამე image-ში არ არის.<br/>• **SBOM:** `5b/bom/`-ში არის სულ მცირე ერთი ნამდვილი გამოტანა `bom generate`-დან, რომელიც ამ აღმოჩენას ადასტურებს.<br/>• **დამოუკიდებელი შემოწმება:** checker დამოუკიდებლად ასრულებს `bom generate`-ს საწყისი candidate images-ისთვის (provisioning-ის დროს შენახული) და ადარებს თქვენს პასუხს ამ დამოუკიდებელ გაშვებასთან.<br/>• **Deployment:** საბოლოო Deployment შეიცავს მხოლოდ "სუფთა" კონტეინერს და რჩება `Available`. |

<details>
<summary>💡 მინიშნება დავალება 5b-ისთვის</summary>

ბრძანება - `bom generate --format json --output <file> --image <ref>` სამი image reference-იდან თითოეულისთვის ცალ-ცალკე. SBOM-ები შეადარეთ წყვილ-წყვილად: პაკეტი ითვლება "offending"-ად, თუ ერთი და იგივე წყვილი `name`/`versionInfo` ორი კონტეინერის SBOM-ში გვხვდება, მაგრამ მესამეში არ არის (ან სხვა ვერსიისაა). image-ის სახელით/ტეგით გამოცნობას ნუ ცდილობთ - image-ების ზოგი წყვილი შეიძლება "მსგავსი" ჩანდეს, მაგრამ პაკეტის ფაქტობრივი დამთხვევა განისაზღვრება მხოლოდ რეალური SBOM-ების შედარებით. Deployment-ის რედაქტირებისას კონტეინერი მთლიანად წაშალეთ `spec.template.spec.containers`-იდან, და არა უბრალოდ მისი image შეცვალეთ.
</details>

---
| **6** | **SPDX SBOM bom-ით** |
| :---: | :--- |
| რას ვაკეთებთ | • დააგენერირეთ SPDX JSON SBOM ინსტრუმენტით `bom` სწორედ immutable `$IMAGE`-ისთვის (იგივე `tag@digest`, რაც დავალება 1-ში გამოიყენეთ, და არა bare tag `nginx:1.27.3-alpine`); შეინახეთ `/var/work/tests/artifacts/6/bom.spdx.json`-ში.<br/>• ფაილში `6/bom-command.txt` ჩაწერეთ შესრულებული ბრძანება ზუსტი `--image $IMAGE`-ით. |
| მიღების კრიტერიუმები | • **SBOM:** ვალიდური JSON, აქვს `spdxVersion`, შეიცავს მასივს `packages`; ერთ-ერთი top-level პაკეტი, რომელზეც `documentDescribes` მიუთითებს, იდენტიფიცირებს იმავე manifest digest-ს, რაც `$IMAGE` დავალება 1-იდან (`versionInfo`/`name`-ით).<br/>• **ბრძანება:** `bom-command.txt` შეიცავს ზუსტ immutable `$IMAGE`-ს და იყენებს `bom generate`-ს.<br/>• SBOM სხვა image-ისთვის (დავალება 1-ის `$IMAGE`-თან დაუკავშირებელი) არ გადის, თუნდაც `bom-command.txt` გაყალბებული იყოს.<br/>• **ახალი შემოწმება:** checker დამატებით დამოუკიდებლად აგენერირებს SBOM-ს იმავე `bom`-ით იმავე image-ისთვის და მოითხოვს, რომ პაკეტების ნაკრები (`name`/`versionInfo`) თქვენს SBOM-ში ამ ახალ გაშვებას დაემთხვეს - მინიმალური ხელით დაწერილი SPDX-დოკუმენტი ერთი top-level პაკეტით არ გადის. |

<details>
<summary>💡 მინიშნება დავალება 6-ისთვის</summary>

ბრძანება `bom generate -o <output.json> -i <image>` - აუცილებლად ფლაგით `-o` გამოტანის ფაილის მისათითებლად, წინააღმდეგ შემთხვევაში გამოტანა stdout-ში წავა. `bom`-ის გამოტანის ფორმატი - მისი საკუთარი SPDX JSON-ია, დეტალებში განსხვავებული იმ SPDX-ისგან, რომლის გენერირებაც Syft-ს შეუძლია - ამ ორ სხვადასხვა ინსტრუმენტს ნუ აურევთ ერთმანეთში სტანდარტის ერთი და იგივე ფორმატის გენერირებისას.
</details>

---
| **7** | **CycloneDX SBOM Syft-ით და Cosign-ის შემოწმება** |
| :---: | :--- |
| რას ვაკეთებთ | • დააგენერირეთ Syft-ის CycloneDX JSON SBOM იმავე immutable `$IMAGE`-ისთვის (`nginx:1.27.3-alpine@sha256:<manifest-digest>`) დავალება 1-დან და შეინახეთ `7/syft.cdx.json`-ში.<br/>• შემდეგ შეამოწმეთ საჯარო image-ის `gcr.io/distroless/static-debian13:nonroot` ხელმოწერა keyless Cosign-ით და შეინახეთ სრული წარმატებული გამოტანა `7/cosign-verify.txt`-ში.<br/>• Distroless-ისთვის გამოიყენეთ issuer `https://accounts.google.com` და identity `keyless@distroless.iam.gserviceaccount.com`. |
| მიღების კრიტერიუმები | • **Syft SBOM:** `bomFormat: CycloneDX`, არაცარიელი `components`, `metadata.component.type == "container"` და `metadata.component.version`, რომელიც უდრის იმავე `$IMAGE`-ის manifest digest-ს დავალება 1-დან - SBOM სხვა image-ისთვის (bare tag, alpine, busybox და ა.შ.) არ გადის.<br/>• **Cosign:** რეალური ბრძანება `cosign verify` `gcr.io/distroless/static-debian13:nonroot`-ისთვის (ეს აქტუალური მხარდაჭერილი ტეგია; `gcr.io/distroless/static:nonroot` სუფიქსის `-debian13` გარეშე deprecated-ად ითვლება Distroless-ის ოფიციალური README-ის მიხედვით და აღარ განახლდება) მითითებული issuer/identity-ით სრულდება exit code `0`-ით, ხოლო სრული გამოტანა შენახულია `7/cosign-verify.txt`-ში.<br/>• **ახალი შემოწმება:** checker დამატებით დამოუკიდებლად აგენერირებს SBOM-ს იმავე Syft-ით იმავე image-ისთვის და მოითხოვს, რომ კომპონენტების ნაკრები (`name`/`version`) თქვენს SBOM-ში ამ ახალ გაშვებას დაემთხვეს - მინიმალური ხელით დაწერილი CycloneDX-დოკუმენტი ერთი top-level კომპონენტით არ გადის. |

<details>
<summary>💡 მინიშნება დავალება 7-ისთვის</summary>

Syft აგენერირებს CycloneDX-ს ფლაგით `-o cyclonedx-json` (არ აურიოთ ამავე ინსტრუმენტის SPDX-გამოტანასთან). Distroless-ის keyless verification-ისთვის არც გასაღებია საჭირო და არც `cosign generate-key-pair` - გამოიყენეთ `cosign verify --certificate-identity <identity> --certificate-oidc-issuer <issuer>` დავალებაში მითითებული issuer/identity სტრიქონებით ზუსტად - რომელიმე მათგანში დაშვებული ბეჭდვითი შეცდომა ვერიფიკაციის წარუმატებლობას გამოიწვევს.
</details>

---
| **8** | **`trivy sbom`: მზა SBOM-ფაილის სკანირება მოწყვლადობებზე** |
| :---: | :--- |
| რას ვაკეთებთ | • CycloneDX SBOM დავალება 7-დან (`7/syft.cdx.json`) აღწერს image-ისა და მისი OS-ის შემადგენლობას, მაგრამ თავისთავად მოწყვლადობების შესახებ დასკვნას არ შეიცავს.<br/>• დაასკანერეთ სწორედ ეს SBOM-ფაილი (და არა image პირდაპირ) ინსტრუმენტით `trivy sbom` და შეინახეთ სტრუქტურირებული JSON `/var/work/tests/artifacts/8/sbom-scan.json`-ში.<br/>• ბრძანებამ აშკარად უნდა მიიღოს SBOM-ფაილი შემავალ მონაცემად, და არ უნდა გადაასკანეროს `$IMAGE`; შეინახეთ მისი ტექსტი `/var/work/tests/artifacts/8/sbom-scan-command.txt`-ში. |
| მიღების კრიტერიუმები | • **ფაილი:** არაცარიელია, JSON წარმატებით პარსირდება `jq`-ით, `ArtifactType` = `cyclonedx`, `Results` არაცარიელია და შეიცავს ნაპოვნ მოწყვლადობებს.<br/>• **ბრძანება:** `sbom-scan-command.txt` შეიცავს `trivy sbom` ბრძანებას `7/syft.cdx.json` ფაილის გზით.<br/>• **ახალი შემოწმება:** checker თავად იმეორებს `trivy sbom`-ს ამ ფაილზე. |

<details>
<summary>💡 მინიშნება დავალება 8-ისთვის</summary>

ბრძანება - `trivy sbom <sbom-ფაილის-გზა>`, და არა `trivy image <ფაილის-გზა>` - ეს სხვადასხვა ქვებრძანებებია შეყვანის სხვადასხვა ლოგიკით. თუ SBOM-ფაილის გზას შემთხვევით `trivy image`-ს გადასცემთ, Trivy ცდის მის ინტერპრეტაციას როგორც image reference-ის სახელს და შეცდომით ან მოულოდნელი ქცევით დასრულდება.
</details>

---
| **9a** | **Kyverno: დაყენება და `ImageValidatingPolicy`-ის შექმნა trusted signature-ზე** |
| :---: | :--- |
| რას ვაკეთებთ | • დააყენეთ Kyverno `install-kyverno`-ით და დაელოდეთ `admission controller`-ის მზადყოფნას.<br/>• დააგენერირეთ გასაღებების ლოკალური წყვილი `cosign generate-key-pair` (სასწავლო წყვილი, და არა production key).<br/>• ხელი მოაწერეთ **საკუთარ** hardened image-ს დავალება 4-დან (`$HARDENED_IMAGE`, და არა upstream nginx) თქვენი private key-ით და შეინახეთ `cosign sign`-ის გამოტანა `9a/cosign-sign.txt`-ში.<br/>• შექმენით `ImageValidatingPolicy` `require-signed-catalog-images`, რომელიც ამოწმებს `verifyImageSignatures`-ს თქვენი public key-ით ყველა Pod-ისთვის image-ით თქვენი `$HARDENED_IMAGE`-ის repository-ში, `pods/ephemeralcontainers` UPDATE-ისა და კონტეინერების ყველა სიის ჩათვლით, და **უარყოფს** (`validationActions: [Deny]`) unsigned/არავალიდურად ხელმოწერილ image-ებს. |
| მიღების კრიტერიუმები | • **Kyverno:** დაყენებულია, მისი admission controller `Available`-ა.<br/>• **ხელმოწერა:** `9a/cosign-sign.txt` შეიცავს სწორედ `$HARDENED_IMAGE`-ის ხელმოწერის წარმატებულ გამოტანას; რეალური ბრძანება `cosign verify --key cosign.pub "$HARDENED_IMAGE"` წარმატებით სრულდება.<br/>• **Policy:** გამოყენებული `ImageValidatingPolicy require-signed-catalog-images` არსებობს, აქვს `apiVersion: policies.kyverno.io/v1`, `validationActions: [Deny]`, public key და `verifyImageSignatures`.<br/>• **მოქმედების არეალი:** მისი `matchImageReferences` შეზღუდულია სწორედ `$HARDENED_REPO:*`-ით და `$HARDENED_REPO@*`-ით, და არა არაუსაფრთხო პრეფიქსით `$HARDENED_REPO*`. |

<details>
<summary>💡 მინიშნება დავალება 9a-სთვის</summary>

`cosign generate-key-pair` ქმნის `cosign.key`/`cosign.pub`-ს მიმდინარე დირექტორიაში - სასწავლო წყვილი, რომელიც არც ერთ OIDC issuer-ზე არ არის მიბმული, დავალება 7-ის keyless verification-ისგან განსხვავებით. Private key შეინახეთ `/home/ubuntu/cks-111`-ის გარეთ, რადგან ეს დირექტორია ხელახლა გამოიყენება როგორც Docker build context დავალება 9c-ში - `cosign.key`, მის შიგნით დარჩენილი, პირდაპირ გამოქვეყნებული image-ის ფაილურ სისტემაში მოხვდება `COPY . /usr/share/nginx/html`-ით. `matchImageReferences` policy-ში უნდა ზღუდავდეს მის მოქმედებას სწორედ თქვენი repository-ით (`$HARDENED_REPO`), და არა მთელი კლასტერით - წინააღმდეგ შემთხვევაში policy დაბლოკავს ყველა ხელმოუწერელ Pod-ს, Kubernetes-ის სისტემური კომპონენტების ჩათვლით.
</details>

---
| **9b** | **Fresh signed ALLOW: ახალი Pod policy-ის შექმნის შემდეგ** |
| :---: | :--- |
| რას ვაკეთებთ | • policy დავალება 9a-დან უნდა დაუშვას ხელმოწერილი `$HARDENED_IMAGE` - მაგრამ უკვე არსებული Deployment-ის განმეორებითი `kubectl apply` ამას **არ ამტკიცებს**: თუ template არ შეცვლილა, ახალი ReplicaSet/Pod შეიძლება არ შეიქმნას, და `Running` უბრალოდ policy-მდე შექმნილი ძველი Pod აღმოჩნდება.<br/>• შექმენით **ახალი**, ადრე არარსებული ობიექტი: `kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" --restart=Never --command -- sleep 3600`.<br/>• შეინახეთ ამ Pod-ის `creationTimestamp`, policy-ის `creationTimestamp` 9a-დან და საბოლოო `status.phase`/`Ready` condition `9b/signed-admission-check.json`-ში. |
| მიღების კრიტერიუმები | • **Pod:** `signed-admission-check` არსებობს, იყენებს სწორედ `$HARDENED_IMAGE`-ს; მისთვის წარმატებით სრულდება `cosign verify --key cosign.pub "$HARDENED_IMAGE"`, `status.phase` არა `Failed`, ხოლო `Ready` condition აღწევს `True`-ს.<br/>• **Artifact:** `9b/signed-admission-check.json` შეიცავს ამ image-ს და Pod-ის `creationTimestamp`-ს **არა უფრო ადრე**, ვიდრე `ImageValidatingPolicy require-signed-catalog-images`-ის `creationTimestamp`.<br/>• ეს ამტკიცებს სწორედ ვერიფიცირებადად ხელმოწერილი image-ის fresh post-policy admission-ს, და არა policy-მდე შექმნილ და შემორჩენილ ძველ Pod-ს. |

<details>
<summary>💡 მინიშნება დავალება 9b-სთვის</summary>

ამ შემოწმებისთვის Deployment `catalog`-ს დავალება 4-დან ნუ გამოიყენებთ - გამოიყენეთ სიტყვასიტყვით ახალი `kubectl run` Pod-ის ახალი სახელით, როგორც დავალებაშია მითითებული. ორივე timestamp (Pod-ისა და policy-ის) - UTC-ში ISO8601 სტრიქონებია, მათი შედარება შეიძლება ლექსიკოგრაფიულად როგორც ჩვეულებრივი სტრიქონები (`[[ "2026-09-06T10:05:00Z" > "2026-09-06T10:00:00Z" ]]` bash-ში ამ ფორმატისთვის სწორად მუშაობს).
</details>

---
| **9c** | **Signature-specific DENY: unsigned digest, რეალურად არსებული იმავე repository-ში** |
| :---: | :--- |
| რას ვაკეთებთ | • ააგეთ და გამოაქვეყნეთ **მეორე** tag იმავე repository-ში, რაც `$HARDENED_IMAGE` (მაგალითად, `${HARDENED_TAG%:*}:unsigned-1.0`), მისი ხელმოწერის გარეშე.<br/>• ეს image უნდა იყოს **ფიზიკურად სხვა artifact**, და არა იგივე digest, რაც უკვე ხელმოწერილ `$HARDENED_IMAGE`-ს აქვს: თუ იმავე `Dockerfile`/context-ს ცვლილებების გარეშე ააგებთ, reproducible/cached build-მა შეიძლება იდენტური digest მოგცეთ, და მაშინ "unsigned" ტეგი სინამდვილეში უკვე ხელმოწერილ artifact-ზე მიუთითებს, ხოლო `cosign verify` მოულოდნელად გაივლის.<br/>• შეიტანეთ კონტროლირებადი განსხვავება build-arg-ით (მაგალითად `--build-arg CKS_SIGNATURE_TEST=unsigned-1` Dockerfile-ში შესაბამისი `ARG`/`LABEL`-ით) და აშკარად შეინახეთ დადასტურება `$UNSIGNED_DIGEST != $HARDENED_DIGEST` `9c/digest-comparison.txt`-ში.<br/>• მიიღეთ registry manifest digest იმავე გზით, რაც დავალება 3-ში (`podman push --digestfile`), ჩამოაყალიბეთ `$UNSIGNED_IMAGE` იმავე repository-ში.<br/>• აშკარად დაამტკიცეთ, რომ ეს digest **არსებობს და pullable-ია** (`HEAD` ან `GET` მოთხოვნა `/v2/catalog/manifests/<digest>`-ზე registry-ში წარმატებულია) და **არ აქვს** თქვენი გასაღებით ვალიდური ხელმოწერა (`cosign verify --key cosign.pub "$UNSIGNED_IMAGE"` შეცდომით სრულდება) - შეინახეთ ორივე გამოტანა `9c/unsigned-exists.txt`-სა და `9c/unsigned-not-signed.txt`-ში.<br/>• შემდეგ შექმენით Pod `catalog-unsigned-probe` ამ `$UNSIGNED_IMAGE`-ით და შეინახეთ admission denial `9c/admission-deny.txt`-ში. |
| მიღების კრიტერიუმები | • **Artifact:** `9c/digest-comparison.txt` შეიცავს `hardened_digest=`-ს, `unsigned_digest=`-ს და `unsigned_image=`-ს (სრული `tag@digest`-მითითება იმავე repository-ში, რაც `$HARDENED_IMAGE`, genuinely სხვა digest-ით).<br/>• **checker-ის შემოწმება:** თავად resolve-ს უკეთებს `unsigned_image`-ს registry-ში, ადასტურებს ვალიდური ხელმოწერის არარსებობას საკუთარი `cosign verify`-ით, ქმნის თავის ახალ Pod-ს ამ image-ით და მოითხოვს საკუთარი policy-ის უნიკალურ validation message-ს: `catalog image must have a valid release signature`.<br/>• ითვლება მხოლოდ ეს შეტყობინება, და არა ნებისმიერი admission-შეცდომა: სხვა policy-ის generic admission/signature error PASS-ს არ იძლევა, `manifest unknown`/registry lookup-ის შეცდომებიც საკმარისი არ არის.<br/>• ხელით დაწერილი evidence-ფაილები რეალური admission control-ის გარეშე PASS-ს არ იძლევა - checker არც ერთ ტექსტურ ფაილს არ ენდობა, გარდა `unsigned_image=`-ისა, როგორც რეალურ image-ზე მითითებისა შესამოწმებლად. |

<details>
<summary>💡 მინიშნება დავალება 9c-სთვის</summary>

დადასტურებების თანმიმდევრობა აქ მათი სანდოობისთვის მნიშვნელოვანია: ჯერ დაამტკიცეთ, რომ `$UNSIGNED_IMAGE` არსებობს და PULLABLE-ია (წინააღმდეგ შემთხვევაში შემდგომი denial შეიძლება უბრალოდ "manifest unknown" იყოს, და არა ხელმოწერის შესახებ), შემდეგ დაამტკიცეთ ხელმოწერის არარსებობა, და მხოლოდ ამის შემდეგ სცადეთ Pod-ის შექმნა. თუ digest-ის შედარება `digest-comparison.txt`-ში დამთხვევას აჩვენებს - მიაღწიეთ content-ის რეალურ განსხვავებას (მაგალითად, შეცვალეთ `CKS_SIGNATURE_TEST` build-arg სხვა მნიშვნელობაზე და ხელახლა ააგეთ).
</details>

## შედეგის შემოწმება

```bash
check_result
```

შემოწმება შეიცავს `Init`-სა და თოთხმეტ დამოუკიდებელ შეფასების ტესტს (დავალება 9 დაყოფილია 9a/9b/9c-ად). ის ამოწმებს ფაილებისა და
JSON-ის შიგთავსს, და არა მხოლოდ სახელების არსებობას. გარე registry-მოთხოვნები საჭიროა Trivy-ისთვის, SBOM-ისთვის და
Cosign-ისთვის; თუ registry დროებით მიუწვდომელია, გაიმეორეთ სწორედ შესაბამისი ბრძანება.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD).

## წაშლა

```bash
TASK=111 make delete_cks_task
```
