[Русская версия](APPENDIX_K8S_137_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_137_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_137_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_137_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_137_SECURITY_DELTA_DE.md) · [繁體中文版](APPENDIX_K8S_137_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_137_SECURITY_DELTA_JP.md)

# დანართი. Kubernetes v1.37 უსაფრთხოების დელტა

> მარკერი: PRODUCTION / VERSION-SENSITIVE. ამ დანართში პუნქტის არსებობა არ ნიშნავს, რომ ის მიმდინარე CKS გამოცდაში შედის. კურსის ოფიციალური exam snapshot ([`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) იყენებს Kubernetes v1.35-ს, ხოლო სასწავლო baseline არის v1.36. Upstream-ის უახლესი სტაბილური ვერსიაა Kubernetes v1.37. ამ დანართის ფუნქცია 🎯 CKS Core-ში მხოლოდ გამოცდასთან და curriculum-თან შესაბამისობის ცალკე დადასტურების შემდეგ გადაიტანეთ.

ეს დანართი აერთიანებს Kubernetes v1.37-ის უსაფრთხოებასთან დაკავშირებულ ცვლილებებს. ძირითადი თავები და ლაბები კვლავ შემოწმებულ exam/training კონტექსტს ეყრდნობა; აქ აღწერილია production-ის მიმდინარე ცვლილებები.

## 1. Manifest-Based Admission Control: ბეტა და ჩართულია ნაგულისხმევად

**CKS შესაბამისობა:** Deep Dive / წარმოება / ვერსიის მგრძნობიარე.

v1.36 სასწავლო baseline-ში Manifest-Based Admission Control კვლავ alpha სტატუსშია და ნაგულისხმევად გამორთულია. v1.37-ში ფუნქცია Beta გახდა და `ManifestBasedAdmissionControlConfig` feature gate ნაგულისხმევად ჩაირთო. API server webhook-ებსა და CEL-ზე დაფუძნებულ admission policy-ებს სტატიკური ფაილებიდან კითხულობს: ისინი API server-ის გაშვებისთანავე აქტიურია, admission-ის კონფიგურაციის შესანახად etcd-ს არ ეყრდნობა და შეუძლია API-ით მართული admission რესურსების ცვლილებისგან დაცვა.

ეს ავსებს bootstrap-ისა და თვითდაცვის ხარვეზს, თუმცა ზრდის ოპერაციულ რისკს: საწყისი ჩატვირთვისას არავალიდური manifest API server-ს Ready მდგომარეობაში გადასვლაში შეუშლის ხელს. HA გარემოში თითოეული API server საკუთარ ფაილებს კითხულობს, ამიტომ საჭიროა მათი შეთანხმებული და ატომური მიწოდება.

წყარო: [Manifest-Based Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/manifest-admission-control/).

## 2. SELinuxMount: GA და ჩართულია ნაგულისხმევად

**CKS შესაბამისობა:** Deep Dive / წარმოება / ვერსიის მგრძნობიარე.

v1.36-ში `SELinuxMount` ნაგულისხმევად გამორთულია; v1.37-ში ის GA გახდა და ნაგულისხმევად ჩართულია. შესაბამისი CSI PVC-ებისთვის Kubernetes ნელი რეკურსიული relabel-ის ნაცვლად SELinux label-ის mount option-ს იყენებს მხოლოდ მაშინ, როცა მითითებულია `CSIDriver.spec.seLinuxMount: true` და შესრულებულია დანარჩენი პირობები. ეს ქცევას ცვლის: ერთ ნოდაზე საერთო volume-ის გამოყენებისას შეუთავსებელი SELinux label-ის მქონე Pod შეიძლება `ContainerCreating` მდგომარეობაში დარჩეს.

SELinux-ის მქონე კლასტერის განახლებამდე ჩართეთ `SELinuxWarningController`, აღმოფხვერით აღმოჩენილი კონფლიქტები და დააკვირდით მის მეტრიკას. თუ workload განზრახ იყენებს საერთო volume-ს სხვადასხვა label-ით, ძველი ქცევის შენარჩუნება შეუძლია შემდეგი პარამეტრით:

```yaml
spec:
  securityContext:
    seLinuxChangePolicy: Recursive
```

წყარო: [უსაფრთხოების კონტექსტის კონფიგურაცია Pod ან კონტეინერისთვის](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).

## 3. Pod Certificates და ClusterTrustBundles: სტაბილური

**CKS შესაბამისობა:** Deep Dive / წარმოება.

ServiceAccount JWT კვლავ bearer credential-ია: token შეზღუდულია ვადით, ობიექტთან მიბმითა და audience-ით, თუმცა ის მეორე მხარეს წარედგინება. Pod Certificates ამატებს X.509 workload credential-ს private key-ითა და ამ გასაღების ფლობის დამადასტურებელი მოდელით. Kubelet ქმნის `PodCertificateRequest`-ს, signer-ისგან იღებს სერტიფიკატების ჯაჭვს და credential-ს როტაციას უკეთებს. სერტიფიკატი და trust bundle workload-ს projected volume-ების საშუალებით გადაეცემა; `ClusterTrustBundle` აწვდის trust anchor-ებს.

Signer-ის იმპლემენტაცია ცვლადია. Kubernetes v1.37 არ მოიცავს მზა უნივერსალურ core signer-ს SPIFFE-სთვის ან ყველა workload-ისთვის. ამიტომ Pod Certificates ავტომატურად არ ანაცვლებს ServiceAccount JWT-ს და არსებულ Istio/SPIFFE identity მექანიზმებს ზედმეტად არ აქცევს.

წყარო: [Kubernetes v1.37: Pod Certificates და Cluster Trust Bundles](https://kubernetes.io/blog/2026/08/28/kubernetes-v1-37-pod-certificates-and-cluster-trust-bundles/).

## 4. KubeletInUserNamespace: ბეტა rootless კვანძის გზა

**CKS შესაბამისობა:** Deep Dive / წარმოება.

`KubeletInUserNamespace` v1.37-ში Beta სტატუსშია. ჩართვისას kubelet-ს, CRI/OCI runtime-ს, CNI-სა და kube-proxy-ს შეუძლია Linux user namespace-ში ჰოსტის არაპრივილეგირებული მომხმარებლის სახელით მუშაობა. ასეთი rootless ნოდის არქიტექტურა ამცირებს ნოდის კომპონენტების კომპრომეტაციის შედეგებს და შეიძლება CNI/CSI თავსებადობის შემოწმება მოითხოვოს.

არ აურიოთ ეს `spec.hostUsers: false`-ში: ეს უკანასკნელი user namespace-ს Pod-ისთვის ქმნის, თუმცა ნოდის კომპონენტები შესაძლოა კვლავ ჰოსტის root-ით მუშაობდეს. ეს განსხვავებული, თავსებადი უსაფრთხოების საზღვრებია. Feature gate-ის ჩართვა არსებულ rootful ნოდებს rootless რეჟიმში ავტომატურად არ გადაიყვანს.

წყარო: [Kubernetes v1.37: KubeletInUserNamespace Graduates to Beta](https://kubernetes.io/blog/2026/09/04/kubernetes-v1-37-rootless-beta/).

## 5. წაუკითხავი/დაზიანებული რესურსების წაშლა: აღდგენის სახიფათო გზა

**CKS შესაბამისობა:** წარმოება / აღდგენა / საშიში ოპერაცია.

v1.37-ში Beta სტატუსის მქონე, ნაგულისხმევად ჩართული `AllowUnsafeMalformedObjectDeletion` feature gate იძლევა ისეთი ობიექტის unsafe delete-ის საშუალებას, რომლის storage-დან წაკითხვა გაშიფვრის ან დეკოდირების შეცდომის გამო შეუძლებელია. Delete request იყენებს `ignoreStoreReadErrorWithClusterBreakingPotential` პარამეტრს; საჭიროა როგორც `delete`, ისე `unsafe-delete-ignore-read-errors` უფლება.

> ⚠️ ეს აღდგენის ბოლო საშუალებაა და კლასტერის დაზიანება შეუძლია. ის გვერდს უვლის finalizer-ებისა და precondition-ების შემოწმებას, არ ცვლის ძველი დაშიფვრის გასაღებების შენარჩუნებას ან backup/restore-ს და EncryptionConfiguration-ის შეცდომის გასწორების ჩვეულებრივი გზა არ არის.

წყარო: [Kubernetes API ცნებები: იძულებითი წაშლა](https://kubernetes.io/docs/reference/using-api/api-concepts/#force-deletion).

## 6. StorageVersionMigration: GA და ჩართულია ნაგულისხმევად

**CKS შესაბამისობა:** წარმოება / Deep Dive.

v1.37-ში ჩაშენებული `storagemigration.k8s.io/v1` API და controller GA გახდა და ნაგულისხმევად ჩაირთო. Storage Version Migration შენახულ API ობიექტებს დეკლარაციულად გადაწერს storage-ის მიმდინარე ვერსიაში. ეს სასარგებლოა API storage-version migration-ისთვის და შეიძლება encryption provider-ის ან გასაღების შეცვლის შემდეგ კონტროლირებადი ხელახალი დაშიფვრის ნაწილი იყოს.

SVM არ უდრის encryption provider-ის როტაციას: provider-ების თანმიმდევრობა, ძველი მონაცემების გაშიფვრა, backup და restore სტრატეგია ოპერატორის ცალკე პასუხისმგებლობად რჩება.

წყარო: [Kubernetes v1.37: Storage Version Migration ჩართულია ნაგულისხმევად](https://kubernetes.io/blog/2026/08/31/kubernetes-v1-37-storage-version-migration-ga/).

---
[შინაარსი](README_GE.md)
