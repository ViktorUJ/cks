[Русская версия](APPENDIX_K8S_136_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_136_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_136_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_136_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_136_SECURITY_DELTA_DE.md) · [繁體中文版](APPENDIX_K8S_136_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_136_SECURITY_DELTA_JP.md)

# დანართი. Kubernetes v1.36 უსაფრთხოების დელტა

> მარკერი: PRODUCTION / VERSION-SENSITIVE. ამ დანართში პუნქტის არსებობა არ ნიშნავს, რომ ის მიმდინარე CKS გამოცდაში შედის. კურსის ოფიციალური exam snapshot ([`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) იყენებს Kubernetes v1.35-ს, ხოლო სასწავლო baseline არის v1.36. თითოეული პუნქტი გადაამოწმეთ, სანამ მას საგამოცდო ფაქტად გამოიყენებთ: ცვლილება შეიძლება production-ისთვის მნიშვნელოვანი იყოს, თუმცა curriculum minor-რელიზს ჩამორჩებოდეს.

ეს დანართი კურსის ძირითად თავებს არ ანაცვლებს. იგი Kubernetes v1.36-ის უსაფრთხოებასთან დაკავშირებულ ცვლილებებს ერთ ადგილას აერთიანებს, რათა მათი აღწერა 33-ვე თავში არ გაიფანტოს და production-ის აქტუალურობა გამოცდასთან შესაბამისობაში არ აგვერიოს.

## 1. User Namespaces GA

**CKS შესაბამისობა:** Deep Dive / წარმოება.

- `spec.hostUsers: false` Pod-ს user namespace-ში ათავსებს: კონტეინერის root ჰოსტზე არაპრივილეგირებულ UID-ზე აისახება.
- ეს defense-in-depth-ის დამატებითი საზღვარია და არსებულ controls-ს (capabilities, seccomp, AppArmor, RBAC) არ ანაცვლებს. იხილეთ [თავი 03](03/ge.md).
- მხოლოდ Linux-ისთვის; კონკრეტული შეზღუდვები (raw block volumes, NFS) აღწერილია თავში 03.

## 2. Fine-Grained Kubelet API Authorization GA

**CKS შესაბამისობა:** Core (გამოიყენება [თავში 05](05/ge.md)).

- ამ ცვლილებამდე `nodes/proxy` თითქმის ყველა kubelet API ბილიკის ერთადერთი subresource იყო, მათ შორის ერთი შეხედვით უსაფრთხო `/metrics`-ისა და სახიფათო `/exec`-ის.
- GA ცალკეულ subresource-ებს ამატებს: `nodes/stats`, `nodes/metrics`, `nodes/log`, `nodes/pods`, `nodes/healthz`, `nodes/configz`, `nodes/spec`, `nodes/checkpoint`.
- `/pods`, `/runningPods/`, `/healthz` და `/configz` ბილიკებისთვის kubelet ჯერ კონკრეტულ subresource-ს ამოწმებს, უარისას კი უკუთავსებადობისთვის `nodes/proxy`-ზე გადადის.
- **რატომ არის ეს security review-სთვის მნიშვნელოვანი:** `nodes/proxy GET` უფლების მქონე monitoring agent-ის ბოროტად გამოყენება შესაძლებელია kubelet API-ის WebSocket სემანტიკის მეშვეობით ნოდაზე ნებისმიერ კონტეინერში RCE-სთვის. `GET` RBAC-ის `get`-ს შეესაბამება, თუმცა `kubelet` შემდგომი ჩაწერის ოპერაციისთვის `create` უფლებას ცალკე არ ამოწმებს. იხილეთ თავი 05 და ბლოკი „თავდამსხმელის ხედვა“.
- წყარო: [Kubernetes v1.36 ბლოგი - Fine-Grained Kubelet API Authorization Graduates to GA](https://kubernetes.io/blog/2026/04/24/kubernetes-v1-36-fine-grained-kubelet-authorization-ga/).

## 3. GA და Manifest-Based Admission Control (ალფა) დაშვების პოლიტიკის მუტაცია/გადამოწმება

**CKS შესაბამისობა:** Core VAP-ისთვის (გამოიყენება [თავში 20](20/ge.md)); Manifest-Based Admission Control არის Deep Dive (ალფა, ნაგულისხმევად გამორთულია).

- CEL-ზე დაფუძნებული native policy layer მრავალი სტანდარტული წესისთვის დამატებითი admission webhook-ის საჭიროებას ამცირებს, მაგრამ Kyverno/Gatekeeper-ს არ ანაცვლებს იქ, სადაც საჭიროა generation, რთული ობიექტების mutation ან supply chain-ის image verification (თავები 20 და 26).
- Manifest-Based Admission Control (v1.36, alpha) მხარს უჭერს სტატიკურ admission ობიექტებს: ყველა ობიექტის სახელი უნდა სრულდებოდეს `.static.k8s.io` სუფიქსით; binding-ებში `paramRef` აკრძალულია; static webhook-ისთვის ნებადართულია მხოლოდ `clientConfig.url` და არა `clientConfig.service`. არავალიდურმა static manifest-მა შეიძლება API server-ის მზადყოფნას ხელი შეუშალოს.

## 4. Service.spec.externalIP-ები ოფიციალურად მოძველებულია

**CKS შესაბამისობა:** წარმოება/Deep Dive.

- `externalIPs` Kubernetes v1.36-ში ოფიციალურად deprecated გახდა. მოსალოდნელია, რომ მომავალი minor-რელიზი ამ ქცევას kube-proxy-დან და მისი მხარდაჭერის მოთხოვნას conformance criteria-დან ამოიღებს.
- **უსაფრთხოების მიზეზი:** ეს ველი დიდი ხანია რისკად ითვლება: არაპრივილეგირებულ მომხმარებელს, რომელსაც Service-ის შექმნა ან შეცვლა შეუძლია, ნებისმიერი IP-ის მითითება შეუძლია მფლობელობის გადამოწმების გარეშე. ეს multitenant კლასტერებში MITM რისკს ქმნის და პირდაპირ უკავშირდება **CVE-2020-8554**-ს (Man in the middle using LoadBalancer or ExternalIPs).
- **თანამედროვე ალტერნატივა:** LoadBalancer Service ღრუბლოვანი ან on-prem controller-ით, ან Gateway API `externalIPs`-ის პირდაპირი გამოყენების ნაცვლად.
- წყაროები: [Kubernetes v1.36 ბლოგი - Service ExternalIP-ების გაუქმება და წაშლა](https://v1-36.docs.kubernetes.io/blog/2026/05/14/kubernetes-v1-36-deprecation-and-removal-of-service-externalips/), [CVE-2020-8554 საკონსულტაციო](https://discuss.kubernetes.io/t/security-advisory-cve-2020-8554-man-in-the-middle-using-loadbalancer-or-externalips/14003).

## 5. gitRepo მოცულობა სამუდამოდ გამორთულია

**CKS შესაბამისობა:** წარმოება/Deep Dive (მომარაგების ჯაჭვი/ცვალებადი წყაროს გაკვეთილი).

- `gitRepo` volume type Kubernetes v1.36-ში **სამუდამოდ გამორთულია** და feature gate-ით ხელახლა ვერ ჩაირთვება. Kubernetes API კვლავ იღებს `gitRepo` volume-ის მქონე Pod-ს, თუმცა kubelet მის გაშვებაზე უარს ამბობს და შეცდომას აბრუნებს.
- **უსაფრთხოების მიზეზი:** `gitRepo` volume driver ნოდაზე kubelet-ის მიერ მართულ პროცესში `git clone`-ს საკმარისი იზოლაციის გარეშე ასრულებდა. სპეციალურად მომზადებული Git repository-ის საშუალებით შესაძლებელი იყო RCE, კერძოდ `git clone`-ისას write hook-ის გამოყენებით.
- **Supply chain-ის გაკვეთილი:** volume type, რომელიც provisioning-ისას თვითნებურ გარე კოდს ასრულებს (თუნდაც „უბრალოდ“ `git clone`-ს), იმავე კლასის რისკია, რაც mutable image tag digest pinning-ის გარეშე. ნდობა შესრულების მომენტში გარე, არასრულად კონტროლირებად წყაროს გადაეცემა და წინასწარ არ მოწმდება.
- წყაროები: [AWS EKS გამოშვების შენიშვნები - gitRepo Volume Removal](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html), [kubernetes/kubernetes#125983 - ამოიღეთ gitRepo ხმის ტიპი](https://github.com/kubernetes/kubernetes/issues/125983).

## 6. SELinux მოცულობის ეტიკეტის ცვლილებები (დამონტაჟების დროში ხელახლა მარკირება)

**CKS შესაბამისობა:** Deep Dive (გამოყენებულია [თავში 18](18/ge.md)).

- რეკურსიულ SELinux relabel-ს container runtime ასრულებს და არა kubelet.
- თუ PVC-ის access mode არ არის `ReadWriteOncePod`, mount-ზე დაფუძნებული relabel (`-o context=`) მოითხოვს ჩართულ `SELinuxMount` feature gate-ს (v1.36-ში ნაგულისხმევად გამორთულია) და კონკრეტული CSI დრაივერისთვის `CSIDriver.spec.seLinuxMount: true` პარამეტრს. წინააღმდეგ შემთხვევაში გამოიყენება უფრო ნელი რეკურსიული relabel.
- რეკურსიული relabel-ისა და `MountOption`-ის განსხვავება იხილეთ თავში 18.

## როგორ გამოვიყენოთ ეს დანართი

თითოეულ პუნქტზე, სანამ მას ლექციაში ან გამოცდისთვის მომზადებისას „მიმდინარე ფაქტად“ მოიყვანთ:

1. შეამოწმეთ `checked_at` ფაილებში [`metadata/tool-compatibility.yaml`](../metadata/tool-compatibility.yaml) და [`metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml).
2. გადაამოწმეთ, შედის თუ არა ფუნქცია მიმდინარე curriculum-ში (`CKS_Curriculum` PDF). Production-ისთვის აქტუალურობა ავტომატურად არ ნიშნავს გამოცდისთვის აქტუალურობას.
3. თუ პუნქტი ლაბაში ან თავში *core* მასალად გამოიყენება (იხ. [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml)), ამ დანართისა და შესაბამისი თავის ფორმულირებები სინქრონულად შეინარჩუნეთ.

---
[შინაარსი](README_GE.md)
