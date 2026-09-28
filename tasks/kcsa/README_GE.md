[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: Kubernetes and Cloud Native Security Associate - სასწავლო მასალები

სრული მომზადება **Kubernetes and Cloud Native Security Associate (KCSA)** სერტიფიკაციისთვის: თვითსასწავლო კურსი და სრული mock გამოცდები - ყველაფერი ერთ ადგილას.

KCSA არის CNCF-ისა და Linux Foundation-ის ასოცირებული დონის, პრე-პროფესიული და კონცეპტუალური სერტიფიკაცია cloud native და Kubernetes უსაფრთხოებაში. კურსი იკავებს ადგილს სასწავლო ტრაექტორიაში KCNA (optional) → KCSA → CKA → CKS: KCSA განმარტავს საფუძვლებსა და საფრთხეების მოდელებს, CKA უზრუნველყოფს CKS-ისთვის აუცილებელ პრაქტიკულ საფუძველს, ხოლო CKS ავითარებს security skills hands-on. ფორმალური წინაპირობები არ არსებობს; საკმარისია საბაზისო წარმოდგენა გქონდეთ, რა არის `Pod`, `Deployment`, `Service` და `kubectl`.

## რა არის ამ დირექტორიაში

| ნაწილი | გზა | რა არის |
|------|------|-----------|
| **კურსი** | [`course/`](course/README_GE.md) | თვითსასწავლო 20 თავი, რომელიც მოიცავს KCSA-ს ყველა 6 ოფიციალურ დომენს |
| **Mock გამოცდები** | [`mock/`](mock/README.md) | 2 სრული mock გამოცდა, თითოეული 60 კითხვით, MCQ ფორმატში |

KCSA-ს პრაქტიკა მოიცავს პასუხის არჩევით კითხვებსა და mock გამოცდებს და არა ლაბორატორიულ სამუშაოებს. რეკომენდებული მარშრუტი: წაიკითხეთ კურსის თავები თანმიმდევრობით, შემდეგ ჩააბარეთ ორივე mock გამოცდა რეალურ გამოცდასთან მიახლოებული დროის ზეწოლის პირობებში.

## კურსი

კურსი ([`course/README_GE.md`](course/README_GE.md)) შედგება 20 თავისგან, თითოეული გამოქვეყნებულია 8 ენაზე: ინგლისური (`README.md`), რუსული (`ru.md`, კანონიკური წყარო), ესპანური (`es.md`), ფრანგული (`fr.md`), გერმანული (`de.md`), ქართული (`ge.md`), ტრადიციული ჩინური (`tw.md`) და იაპონური (`jp.md`). თავები დაჯგუფებულია KCSA-ს ოფიციალური დომენების მიხედვით:

| დომენი | წონა |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

ტერმინები თავმოყრილია [ლექსიკონში](course/GLOSSARY_GE.md). თავები 1-2 აცნობს გამოცდასა და cloud native უსაფრთხოებას; მე-20 თავი შეიცავს საბოლოო სტრატეგიას, დროის მართვასა და საკონტროლო სიას.

## Mock გამოცდები

ორი სრული mock გამოცდა ([`mock/`](mock/README.md)) ასახავს რეალურ KCSA გამოცდას:

- **Mock 01** ([`mock/01`](mock/01/README.md)) - 60 კითხვა, განაწილებული დომენების მიხედვით.
- **Mock 02** ([`mock/02`](mock/02/README.md)) - დამოუკიდებელი ნაკრები 60 კითხვისგან, იმავე განაწილებით.

თითოეული mock ჩააბარეთ closed-book რეჟიმში, 90 წუთში: დოკუმენტაციის, ძიების, ჩანაწერების, ხელსაწყოებისა და გარე საიტების გარეშე. ბოლო გადამოწმებისას LF Multiple Choice FAQ მიუთითებდა 75%-იან ან უფრო მაღალ ჩასაბარების ზღვარზე; რეგისტრაციამდე გადაამოწმეთ KCSA-ს მიმდინარე მოთხოვნები Linux Foundation-თან.

## გამოცდის ფორმატი და კურსის ვერსია

KCSA არის პასუხის არჩევით გამოცდა: 60 კითხვა, 90 წუთი, ჩასაბარებლად 75%, hands-on დავალებების გარეშე (რეგისტრაციამდე გადაამოწმეთ მიმდინარე პარამეტრები Linux Foundation-თან, რადგან ისინი შეიძლება შეიცვალოს). კურსის მაგალითები ორიენტირებულია Kubernetes `v1.36`-ზე. აქტუალური წონები, წყაროები და პროგრამის ცვლილებები დაფიქსირებულია [ვერსიების პოლიტიკაში](VERSION_POLICY.md).

## რა წავიკითხოთ შემდეგ

- [Kubernetes-ის ოფიციალური დოკუმენტაცია: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- CKS კურსი არის შემდეგი ნაბიჯი პრაქტიკული hardening-ისა და გამოძიების გასაღრმავებლად.
