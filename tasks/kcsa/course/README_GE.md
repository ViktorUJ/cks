[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: cloud native და Kubernetes უსაფრთხოების პრაქტიკული თვითსასწავლო კურსი

KCSA (Kubernetes and Cloud Native Security Associate) არის CNCF-ისა და Linux Foundation-ის ასოცირებული დონის, პრე-პროფესიული და კონცეპტუალური სერტიფიკაცია cloud native და Kubernetes უსაფრთხოებაში. კურსი იკავებს ადგილს სასწავლო ტრაექტორიაში KCNA (optional) → KCSA → CKA → CKS: KCSA განმარტავს საფუძვლებსა და საფრთხეების მოდელებს, CKA უზრუნველყოფს CKS-ისთვის აუცილებელ პრაქტიკულ საფუძველს, ხოლო CKS ავითარებს security skills hands-on. ფორმალური წინაპირობები არ არსებობს; საკმარისია საბაზისო წარმოდგენა გქონდეთ, რა არის `Pod`, `Deployment`, `Service` და `kubectl`.

> **CKA-სა და CKS-ის ბმულების შესახებ.** KCSA-ს დამოუკიდებელი არქივი CKA-სა და CKS-ის კატალოგებს არ შეიცავს. ამიტომ standalone-distribution-ში თავად KCSA-ს შიდა ბმულები დაკლიკებადი რჩება, ხოლო CKA/CKS-ზე cross-course references ქვეყნდება ჩვეულებრივ ტექსტად, ფარდობითი URL-ების გარეშე. monorepo-build-ში მათი გენერირება შესაძლებელია როგორც მეზობელი კურსების მოქმედი ბმულები ან როგორც სტაბილური absolute URLs.

> **გამოცდის ფორმატი და მაგალითების ვერსია.** KCSA არის პასუხის არჩევით გამოცდა. Linux Foundation-ის წესების თანახმად, რომლებიც 2026 წლის 1 სექტემბერს გადამოწმდა, სტანდარტული MCQ გამოცდა (multiple choice question, კითხვა პასუხის არჩევით) შეიცავს 60 კითხვას, გრძელდება 90 წუთი და ჩასაბარებლად 75%-ს მოითხოვს; hands-on დავალებები არ არის. რეგისტრაციამდე აუცილებლად ხელახლა გადაამოწმეთ LF-ის აქტუალური მოთხოვნები, რადგან ეს პარამეტრები შეიძლება შეიცვალოს. კურსის მაგალითები ორიენტირებულია Kubernetes `v1.36`-ზე. აქტუალური წონები, წყაროები და პროგრამის ცვლილებები დაფიქსირებულია [ვერსიების პოლიტიკაში](../VERSION_POLICY.md).

## როგორ არის მოწყობილი კურსი

თითოეული თემა წარმოადგენს დანომრილ კატალოგს, რომლის კანონიკური რუსული ვერსიაა `ru.md`. ყველა თავისთვის გამოქვეყნებულია ინგლისური `README.md`, ესპანური `es.md`, ფრანგული `fr.md`, გერმანული `de.md`, ქართული `ge.md`, ტრადიციული ჩინური `tw.md` და იაპონური `jp.md` ვერსიები. თავები დაჯგუფებულია KCSA-ს დომენების მიხედვით და ფერებით არის მონიშნული:

- 🟦 Overview of Cloud Native Security - 14%
- 🟥 Kubernetes Cluster Component Security - 22%
- 🟩 Kubernetes Security Fundamentals - 22%
- 🟪 Kubernetes Threat Model - 16%
- 🟨 Platform Security - 16%
- 🟫 Compliance and Security Frameworks - 10%
- ⬜ შესავალი, საფუძვლები და გამოცდისთვის მომზადება

KCSA-ს პრაქტიკა მოიცავს პასუხის არჩევით კითხვებსა და mock გამოცდებს და არა ლაბორატორიულ სამუშაოებს. ეს ფაილი შეიცავს მომზადების ერთიან მარშრუტსა და გამოცდის ნავიგაციას. ტერმინები თავმოყრილია [ლექსიკონში](GLOSSARY_GE.md).

## გამოცდის ოფიციალური პროგრამა

| დომენი | წონა |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

## შინაარსი

### ნაწილი 0. შესავალი და საფუძვლები ⬜

1. [შესავალი: KCSA გამოცდა, ფორმატი, სერტიფიკაციების საფეხურები და ვერსიები](01/ge.md)
2. [Cloud native და რატომ არის უსაფრთხოება მნიშვნელოვანი](02/ge.md)

### ნაწილი 1. Overview of Cloud Native Security - 14% 🟦

3. [Cloud უსაფრთხოების 4C: Cloud, Cluster, Container, Code](03/ge.md)
4. [ღრუბლოვანი პროვაიდერისა და ინფრასტრუქტურის უსაფრთხოება](04/ge.md)
5. [კონტროლის საშუალებები, ფრეიმვორკები და იზოლაციის ტექნიკები](05/ge.md)
6. [არტეფაქტების, იმიჯებისა და კოდის უსაფრთხოება](06/ge.md)

### ნაწილი 2. Kubernetes Cluster Component Security - 22% 🟥

7. [control plane-ის უსაფრთხოება: API Server, Controller Manager, Scheduler, Etcd](07/ge.md)
8. [კვანძის უსაფრთხოება: Kubelet, Container Runtime, KubeProxy](08/ge.md)
9. [Pod, კონტეინერების ქსელი, storage და კლიენტის უსაფრთხოება](09/ge.md)

### ნაწილი 3. Kubernetes Security Fundamentals - 22% 🟩

10. [ავთენტიფიკაცია და ავტორიზაცია](10/ge.md)
11. [Pod Security Standards და Pod Security Admission](11/ge.md)
12. [Secrets](12/ge.md)
13. [Network Policy, იზოლაცია და სეგმენტაცია](13/ge.md)
14. [Audit Logging](14/ge.md)

### ნაწილი 4. Kubernetes Threat Model - 16% 🟪

15. [ნდობის საზღვრები, მონაცემთა ნაკადები და საფრთხეების მოდელი](15/ge.md)
16. [Kubernetes-ის საფრთხეების კატეგორიები](16/ge.md)

### ნაწილი 5. Platform Security - 16% 🟨

17. [Supply chain, image registry-ები და admission control](17/ge.md)
18. [Observability, PKI, connectivity და service mesh](18/ge.md)

### ნაწილი 6. Compliance and Security Frameworks - 10% 🟫

19. [კომპლაიენსი და უსაფრთხოების ფრეიმვორკები](19/ge.md)

### ნაწილი 7. გამოცდისთვის მომზადება ⬜

20. [KCSA გამოცდა: სტრატეგია, დროის მართვა და საკონტროლო სია](20/ge.md)

## პრაქტიკა

- 📝 [KCSA mock გამოცდები](../mock) - ხელმისაწვდომია ინგლისურენოვანი Mock 01 და Mock 02 MCQ ფორმატში დამოუკიდებელი ვარჯიშისთვის. კითხვები განაწილებულია დომენების წონების მიხედვით; KCSA-სთვის terragrunt/bats ლაბორატორიები არ იქმნება.

დაიწყეთ 01-02 თავებით, შემდეგ კი დომენები თანმიმდევრობით გაიარეთ. საბოლოო ტაქტიკა და საკონტროლო სია თავმოყრილია [მე-20 თავში](20/ge.md).

## რა წავიკითხოთ შემდეგ

- [Kubernetes-ის ოფიციალური დოკუმენტაცია: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- CKS კურსი არის შემდეგი ნაბიჯი პრაქტიკული hardening-ისა და გამოძიების გასაღრმავებლად.
