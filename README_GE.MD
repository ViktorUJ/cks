[Русский](README_RU.MD) · [English](README.MD) · [Español](README_ES.MD) · [Français](README_FR.MD) · [Deutsch](README_DE.MD) · ქართული · [繁體中文](README_TW.MD) · [日本語](README_JP.MD)

# SRE Learning Platform

<p align="center">
  <a href="https://github.com/ViktorUJ/cks"><img src="https://raw.githubusercontent.com/ViktorUJ/terraform-aws-vpc/master/img/logo_192x192.png" width="192" height="192" alt="SRE Learning Platform"/></a>
</p>

**SRE Learning Platform ღია კოდის საგანმანათლებლო პროექტია, რომლის ფარგლებში ვქმნით კურსებს, პრაქტიკულ ლაბორატორიულ სამუშაოებსა და საცდელ გამოცდებს, რათა საზოგადოებას საინჟინრო უნარების განვითარებასა და აქტუალური ცოდნის გაზიარებაში დავეხმაროთ.** უკვე ხელმისაწვდომია მასალები Kubernetes-ის, უსაფრთხოების, Istio-ს, Amazon EKS-ისა და ქვემოთ მოცემული კატალოგის სხვა მიმართულებების შესახებ. პლატფორმას ეტაპობრივად ვაფართოებთ: დაგეგმილია კურსები Prometheus-ის, Elastic Stack-ის, მონაცემთა ბაზებისა და სხვა ტექნოლოგიების შესახებ, რომლებსაც ინჟინრები ყოველდღიურად იყენებენ.

კურსი და წიგნი ბევრია, თუმცა ტექნოლოგიები სწრაფად იცვლება და კარგი მასალაც დროთა განმავლობაში ძველდება. ჩვენი იდეაა, სასწავლო მასალები ღია კოდის პროექტის მსგავსად განვავითაროთ: ტექნოლოგიებთან ერთად განვაახლოთ, პრაქტიკაში შევამოწმოთ, შეცდომები გავასწოროთ და საზოგადოების გამოცდილებით შევავსოთ.

გვინდა, სწავლის შესაძლებლობა ყველას ჰქონდეს. ფასიანი კურსებისა და წიგნების შეძენა ყველას არ შეუძლია, განსაკუთრებით სტუდენტებს, ამიტომ ჩვენი სასწავლო მასალები უფასოა. კურსებს რვა ენაზე ვთარგმნით, რათა უცხო ენა სწავლის დაბრკოლებად არ იქცეს.

**საზოგადოებისთვის და საზოგადოებასთან ერთად.** დაამატეთ ახალი თემები და ლაბორატორიული სამუშაოები, დაგვეხმარეთ თარგმანში და გამოგვიგზავნეთ შესწორებები pull request-ით. გაგვიზიარეთ თქვენი შეფასება კურსებისა და ლაბორატორიული სამუშაოების შესახებ: რა იყო სასარგებლო, რა შეიძლება გაუმჯობესდეს და რამდენად დაგეხმარათ პლატფორმა გამოცდებისთვის მომზადებასა და რეალური სამუშაო ამოცანების გადაწყვეტაში. თქვენი გამოცდილება მასალების გაუმჯობესებასა და სწავლის უფრო სასარგებლოდ ქცევაში გვეხმარება.

მოუყევით სხვებს პლატფორმის შესახებ და გააზიარეთ მისი ბმულები **LinkedIn-ზე, Reddit-ზე, HackerNoon-ზე**, პირად ბლოგებში, სასწავლო საზოგადოებებსა და ნებისმიერ სხვა სივრცეში. ასეთი პუბლიკაციები გვახარებს: ისინი მეტ ადამიანს ეხმარება მასალების პოვნაში, საზოგადოებას კი ზრდასა და ცოდნის გაცვლაში. [შეფასებები და წინადადებები](https://github.com/ViktorUJ/cks/issues) · [კონტაქტები](#contacts).

თუ პლატფორმა თქვენთვის სასარგებლო აღმოჩნდა, [მიანიჭეთ რეპოზიტორიას ვარსკვლავი](https://github.com/ViktorUJ/cks). ჩვენი გუნდისთვის ეს მხარდაჭერის სასიამოვნო ნიშანია და პროექტის განვითარების გაგრძელების მოტივაცია.

## [სწრაფი დაწყება Docker-ით](docs/run_from_docker_GE.MD)

## კურსები, ლაბორატორიული სამუშაოები და საცდელი გამოცდები

| მიმართულება | კურსი | ლაბორატორიული სამუშაოები | საცდელი გამოცდები |
|---|---|---|---|
| [CKA](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) | [CKA + CKAD-ის საერთო კურსი](tasks/cka/course/README_GE.md) | [ლაბორატორიული სამუშაოები](docs/labs.MD#cka-labs) | [01](tasks/cka/mock/01/README.MD) · [02](tasks/cka/mock/02/README.MD) |
| [CKAD](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/) | [CKA + CKAD-ის საერთო კურსი](tasks/cka/course/README_GE.md) | [ლაბორატორიული სამუშაოები](docs/labs.MD#cka-labs) | [01](tasks/ckad/mock/01/README.md) · [02](tasks/ckad/mock/02/README.md) |
| [CKS](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) | [კურსი](tasks/cks/course/README_GE.md) | [ლაბორატორიული სამუშაოები](docs/labs.MD#cks-labs) | [01](tasks/cks/mock/01/README.MD) · [02](tasks/cks/mock/02/README.MD) · [03](tasks/cks/mock/03/README.MD) · [04](tasks/cks/mock/04/README.MD) |
| Amazon EKS | [კურსი](tasks/eks/course/README_GE.md) | [ლაბორატორიული სამუშაოები](docs/labs.MD#eks-labs) | - |
| [Istio / ICA](https://training.linuxfoundation.org/certification/istio-certified-associate-ica/) | [კურსი](tasks/ica/course/README_GE.md) | [ლაბორატორიული სამუშაოები](docs/labs.MD#ica-labs-istio-certified-associate) | [01](tasks/ica/mock/01/README.MD) · [02](tasks/ica/mock/02/README.MD) |
| [KCSA](https://training.linuxfoundation.org/certification/kubernetes-and-cloud-native-security-associate-kcsa/) | [კურსი](tasks/kcsa/course/README_GE.md) | - | [01](tasks/kcsa/mock/01/README.md) · [02](tasks/kcsa/mock/02/README.md) |
| [KCNA](https://training.linuxfoundation.org/certification/kubernetes-cloud-native-associate/) | - | - | [01](tasks/kcna/mock/01/README.MD) |
| [LFCS](https://training.linuxfoundation.org/certification/linux-foundation-certified-sysadmin-lfcs/) | - | - | [01](tasks/lfcs/mock/01/README.md) · [02](tasks/lfcs/mock/02/README.md) |
| [AWS Certified AI Practitioner](https://aws.amazon.com/certification/certified-ai-practitioner/) | - | - | [01](tasks/aws_AI_practitioner/mock/01/README.MD) |
| შერჩევის პრაქტიკული სცენარები | - | - | [01](tasks/hr/mock/01/README.md) |

ლაბორატორიული სამუშაოების კატალოგი საერთოა: თითოეულ ნათარგმნ სამუშაოსთან აირჩიეთ სასურველი ენა. საცდელი გამოცდები თავდაპირველ ენაზე რჩება.

## მასალები და დახმარება

[დოკუმენტაცია და ინსტრუქციები](docs/README_GE.md) · [პროექტში მონაწილეობა](docs/contributing_GE.md) · [ცვლილებების ისტორია](CHANGELOG/CHANGELOG.MD)

<a id="contacts"></a>

## ერთობლივი მომზადება და თანამშრომლობა

Telegram-არხები ერთობლივი მომზადებისთვის: [CKA](https://t.me/sre_platform_cka) · [CKS](https://t.me/sre_platform_cks) · [CKAD](https://t.me/sre_platform_ckad).

კითხვები, წინადადებები და თანამშრომლობა: [Email](mailto:viktoruj@gmail.com) · [Telegram](https://t.me/viktor_uj) · [LinkedIn](https://www.linkedin.com/in/viktar-mikalayeu-mns).

## ლიცენზია

პროექტი ვრცელდება [Apache License 2.0](LICENSE) ლიცენზიით.
