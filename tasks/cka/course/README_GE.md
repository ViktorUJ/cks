[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# CKA + CKAD: პრაქტიკული თვითმასწავლებელი Kubernetes-ზე

ერთობლივი პრაქტიკული კურსი CNCF-ისა და Linux Foundation-ის ორი
სერტიფიკაციისთვის ერთდროულად მოსამზადებლად:

- **CKA** (Certified Kubernetes Administrator) - კლასტერის ადმინისტრირება:
  დაყენება, მომსახურება, ქსელი, საცავები, უსაფრთხოება, troubleshooting.
- **CKAD** (Certified Kubernetes Application Developer) - აპლიკაციების
  შემუშავება და გაშვება Kubernetes-ში: სამუშაო დატვირთვები, კონფიგურაცია,
  დაკვირვებადობა, სერვისები.

გამოცდები ძლიერ ჯვარედინდება (სამუშაო დატვირთვები, სერვისები, კონფიგურაცია,
საცავები, დაკვირვებადობა), ამიტომ მათი ერთად შესწავლა უფრო ეფექტურია, ვიდრე
ცალ-ცალკე. საერთო ბირთვი ერთხელ გაივლის, ხოლო თითოეული გამოცდის სპეციფიკა ცალკე ნაწილებშია გამოტანილი.
კურსი მიბმულია ლაბორატორიულ სამუშაოებზე `tasks/cka/labs`-ში.

> **Kubernetes-ის ვერსია.** კურსი ორიენტირებულია გამოცდების აქტუალურ ვერსიაზე -
> Kubernetes `v1.35` (CKA და CKAD პროგრამები 2025-2026). ორივე გამოცდა -
> პრაქტიკულია, ცოცხალ კლასტერში ბრძანების ხაზიდან: CKA - 2 საათი, CKAD - 2
> საათი, გამსვლელი ქულა 66%.

## როგორ არის აგებული კურსი

თითოეული თემა - საქაღალდე ნომრით. შიგნით განთავსებულია ლოკალიზებული ფაილები. ძირითადი ენა -
რუსული (`ru.md`), მისგან გაკეთებულია თარგმანები: ინგლისური (`README.md`), ესპანური
(`es.md`), ფრანგული (`fr.md`), გერმანული (`de.md`) და ქართული (`ge.md`).
ენების გადამრთველი - ყოველი ფაილის პირველ სტრიქონში.

თითოეული თავი მონიშნულია, რომელ გამოცდას ეხება:

- 🟦 **CKA** - მხოლოდ ადმინისტრატორისთვის
- 🟩 **CKAD** - მხოლოდ დეველოპერისთვის
- 🟪 **CKA + CKAD** - საერთო თემა ორივე გამოცდისთვის

კურსის ბოლოს არის ორი ცალკე გზამკვლევი, რომლებიც კრებს თავებსა და ლაბებს
კონკრეტული გამოცდისთვის:

- [CKA-ს პროგრამა და ლაბები](CKA_GE.md)
- [CKAD-ს პროგრამა და ლაბები](CKAD_GE.md)

კურსის ყველა ტერმინი შეკრებილია ერთიან ცნობარში:

- [კურსის გლოსარიუმი](GLOSSARY_GE.md) - ყველა ტერმინი თავების მიხედვით ბმულებით

## გამოცდების ოფიციალური პროგრამები

CKA (დომენები და წონა):

| დომენი | წონა |
|--------|------|
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Storage | 10% |
| Services & Networking | 20% |
| Troubleshooting | 30% |

CKAD (დომენები და წონა):

| დომენი | წონა |
|--------|------|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services and Networking | 20% |

## სარჩევი

### ნაწილი 0. საფუძველი დამწყებთათვის (არასავალდებულო) 🟪 CKA + CKAD

მოსამზადებელი ნაწილი მათთვის, ვინც მოდის ქსელების, DNS-ის, TLS-ის,
კონტეინერების, Linux-ისა და YAML-ის მყარი ბაზის გარეშე. თუ ამ თემებს თავდაჯერებულად ფლობთ - შეგიძლიათ პირდაპირ
გადახვიდეთ ნაწილ 1-ზე. ამ ნაწილს ცალკე ლაბები არ აქვს: ეს არის საფუძველი, რომელსაც
ეყრდნობა დანარჩენი თავები (0.5-0.7-ის უნარები პირდაპირ გამოიყენება კვანძების და ქსელის
ლაბებში).

- 0.1. [ქსელი ნულიდან: IP, პორტები, CIDR და NAT](00-1-net/ge.md)
- 0.2. [DNS ნულიდან: როგორ იქცევა სახელები მისამართებად](00-2-dns/ge.md)
- 0.3. [TLS და სერტიფიკატები ნულიდან: HTTPS, გასაღებები და სასერტიფიკაციო ცენტრები](00-3-tls/ge.md)
- 0.4. [კონტეინერები და Docker ნულიდან: იმიჯები, შრეები, რეესტრები და runtime](00-4-containers/ge.md)
- 0.5. [Linux და კვანძის ხელსაწყოები ნულიდან: SSH, sudo, systemd, ლოგები, ფაილები](00-5-linux/ge.md)
- 0.6. [YAML ნულიდან: აცილება, სიები, ლექსიკონები და მანიფესტები](00-6-yaml/ge.md)
- 0.7. [Linux-ქსელი კაპოტის ქვეშ: network namespaces, veth და მარშრუტიზაცია](00-7-netns/ge.md)
- 0.8. [vim 15 წუთში: გადარჩი და მოირგე YAML-ისთვის](00-8-vim/ge.md)

### ნაწილი 1. Kubernetes-ის საფუძვლები 🟪 CKA + CKAD

1. [შესავალი: Kubernetes, გამოცდები CKA და CKAD და კურსის აგებულება](01/ge.md)
2. [Kubernetes-ის არქიტექტურა: control plane და worker-კვანძები](02/ge.md)
3. [kubectl-თან მუშაობა: იმპერატიული და დეკლარაციული მიდგომები](03/ge.md)
4. [Pod-ები: სასიცოცხლო ციკლი, შექმნა და კონფიგურირება](04/ge.md)
5. [ReplicaSet და Deployment](05/ge.md)
6. [Namespaces, labels, selectors და annotations](06/ge.md)
7. [Services: ClusterIP, NodePort, LoadBalancer და Endpoints](07/ge.md)

### ნაწილი 2. სამუშაო დატვირთვები და დაგეგმვა 🟪 CKA + CKAD

8. [Deployment: rolling update და rollback](08/ge.md)
9. [გაშლის სტრატეგიები: blue/green და canary](09/ge.md) 🟩 CKAD
10. [Jobs და CronJobs](10/ge.md)
11. [DaemonSet და StatefulSet](11/ge.md)
12. [Pods-ის დაგეგმვა: nodeName, nodeSelector, affinity](12/ge.md)
13. [Taints და tolerations](13/ge.md)
14. [რესურსები: requests, limits, LimitRange და ResourceQuota](14/ge.md)
15. [Static Pods, PriorityClass და რამდენიმე დამგეგმავი](15/ge.md)
16. [დატვირთვების ავტომასშტაბირება: HPA](16/ge.md)

### ნაწილი 3. აპლიკაციების კონფიგურაცია და უსაფრთხოება 🟪 CKA + CKAD

17. [ბრძანებები, არგუმენტები და გარემოს ცვლადები](17/ge.md)
18. [ConfigMap](18/ge.md)
19. [Secret](19/ge.md)
20. [SecurityContext და capabilities](20/ge.md)
21. [ServiceAccount; ავთენტიფიკაცია, ავტორიზაცია, admission](21/ge.md)

### ნაწილი 4. აპლიკაციების დიზაინი და აწყობა 🟩 CKAD

22. [Multi-container Pod-ები: sidecar, adapter, ambassador, init](22/ge.md)
23. [კონტეინერების იმიჯები: აწყობა, Dockerfile, ოპტიმიზაცია](23/ge.md)
24. [ტომები აპლიკაციებისთვის: emptyDir და ეფემერული ტომები](24/ge.md)

### ნაწილი 5. მონაცემების შენახვა 🟪 CKA + CKAD

25. [Volumes, PersistentVolume და PersistentVolumeClaim](25/ge.md)
26. [StorageClass, დინამიკური პროვიზიონინგი და შენახვა StatefulSet-ში](26/ge.md)

### ნაწილი 6. დაკვირვებადობა და მომსახურება 🟪 CKA + CKAD

27. [მდგომარეობის შემოწმებები: liveness, readiness და startup probes](27/ge.md)
28. [ლოგირება და მონიტორინგი: logs, metrics-server, kubectl top](28/ge.md)
29. [აპლიკაციების გამართვა და API-ს მოძველება](29/ge.md)

### ნაწილი 7. სერვისები და ქსელი 🟪 CKA + CKAD

30. [Kubernetes-ის ქსელური მოდელი, Pod-ების ქსელი და CNI](30/ge.md)
31. [Service შიგნიდან, DNS და CoreDNS](31/ge.md)
32. [Ingress და Ingress-კონტროლერები](32/ge.md)
33. [Gateway API](33/ge.md)
34. [NetworkPolicy](34/ge.md)

### ნაწილი 8. კლასტერის არქიტექტურა, დაყენება და კონფიგურაცია 🟦 CKA

35. [კლასტერის დაყენება kubeadm-ის დახმარებით](35/ge.md)
- 35A. [მაღალი ხელმისაწვდომობა (HA): რამდენიმე control-plane ნოუდი, etcd-ტოპოლოგიები და ბალანსერი](35-2-ha/ge.md) 🟦 CKA
- 35B. [კლასტერის დაპროექტება და საიზინგი: ინფრასტრუქტურა, ტოპოლოგია, IaC](35-3-design/ge.md) 🟦 CKA
36. [კლასტერის განახლება (lifecycle)](36/ge.md)
37. [etcd-ს რეზერვული კოპირება და აღდგენა](37/ge.md)
38. [RBAC: Role, ClusterRole და binding-ები](38/ge.md)
39. [TLS-სერტიფიკატები, kubeconfig და CSR API](39/ge.md)
40. [გაფართოების ინტერფეისები: CNI, CSI, CRI](40/ge.md)
41. [CRD და ოპერატორები](41/ge.md)
42. [Helm](42/ge.md)
43. [Kustomize](43/ge.md)

### ნაწილი 9. Troubleshooting 🟦 CKA

44. [აპლიკაციების ავარიების გამართვა](44/ge.md)
45. [control plane-ისა და worker-ნოდების გამართვა](45/ge.md)
46. [სერვისებისა და ქსელის გამართვა](46/ge.md)

### ნაწილი 10. გამოცდებისთვის მომზადება

47. [CKAD გამოცდა: ფორმატი, დროის მართვა, JSONPath და kubectl-ის პროდუქტიულობა](47/ge.md) 🟩 CKAD
48. [CKA გამოცდა: ფორმატი, დროის მართვა და სტრატეგია](48/ge.md) 🟦 CKA

## პრაქტიკა

- 🧪 [ლაბორატორიული სამუშაოები](../labs) - 25 ლაბი გამოცდის სტილში ავტოშემოწმებით `check_result`
- 🧪 [CKA-ს მოკ-გამოცდები](../mock) - CKA-ს მოკ-გამოცდები ტაიმერით (მულტიკლასტერი, SSH, დავალებების წონები)
- 🧪 [CKAD-ს მოკ-გამოცდები](../../ckad/mock) - CKAD-ს მოკ-გამოცდები ტაიმერით
