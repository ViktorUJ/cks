[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 113 - Kubernetes-კლასტერის upgrade kubeadm-ით (minor upgrade)

## მიზანი

ამ CKS-ლაბში თქვენ თავად შეასრულებთ თვითმართული კლასტერის რეალურ minor-upgrade-ს
`kubeadm`-ით: ჯერ control-plane, შემდეგ worker-node, სწორი
თანმიმდევრობით და უკვე მომუშავე დატვირთვის დაუგეგმავი downtime-ის გარეშე. კლასტერი იწყებს
Kubernetes `1.35.x`-ზე; თქვენი ამოცანაა ორივე node `1.36.x`-ზე გადაიყვანოთ, დაიცვათ რა
ოფიციალური პროცედურა `kubeadm upgrade` და პაკეტების repository-ის `pkgs.k8s.io` გადართვა ახალ minor-ზე.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რატომ მოითხოვს `kubeadm upgrade` control-plane-ის upgrade-ს მკაცრად worker-node-ებამდე, და არა ნებისმიერი თანმიმდევრობით?</summary>

`kubeadm upgrade apply` control-plane-ზე ანახლებს API server-ისა და control-plane-ის სხვა კომპონენტების ვერსიას; სწორედ ამ ვერსიიდან ითვლება კლასტერის version skew policy. Worker-node, API server-თან შედარებით ძალიან ახალი kubelet-ით, შეიძლება დაარღვიოს მხარდაჭერილი skew (kubelet არ უნდა იყოს kube-apiserver-ზე ახალი). control-plane-ის პირველ რიგში განახლება იძლევა გარანტიას, რომ API server უკვე მიზნობრივ ვერსიაზეა, როცა worker მასზევე გადადის - ეს თვითნებური რეკომენდაცია არ არის, არამედ Kubernetes-ის version skew policy-ის მოთხოვნაა.
</details>

<details>
<summary>2. რატომ არის apt-repository `pkgs.k8s.io`-ის გადართვა სავალდებულო ახალ minor-ზე გადასვლისას, მაშინ როცა patch-განახლებები მის გარეშე მუშაობს?</summary>

`packages.cloud.google.com`/`apt.kubernetes.io`-დან მიგრაციის შემდეგ, `pkgs.k8s.io` ორგანიზებულია როგორც **ცალკე repository ყოველი minor-ვერსიისთვის** (`core:/stable:/v1.35`, `core:/stable:/v1.36` და ა.შ.), და არა ერთიანი repository ყველა ვერსიით. უკვე მიერთებული repo `v1.35`-ის შიგნით ხელმისაწვდომია მხოლოდ `1.35.x` patch-რელიზები. რომ `apt install kubeadm=1.36.x-*`-მა `1.36` ვერსიები დაინახოს, ჯერ უნდა მიაერთოთ `sources.list.d/kubernetes.list`-ში სწორედ repo `core:/stable:/v1.36` (იცვლება მხოლოდ ვერსია URL-ში; keyring ხელმოწერის გასაღებით `Release.key` უცვლელი რჩება).
</details>

<details>
<summary>3. რატომ არის `kubectl drain` კლასტერის upgrade-მდე არა უბრალოდ "კარგი პრაქტიკა", არამედ კონკრეტულად რისგან დაცვა?</summary>

`kubeadm upgrade` control-plane-ზე თავიდან ქმნის კომპონენტების static Pod-manifest-ებს (kube-apiserver, controller-manager, scheduler), ხოლო ნებისმიერ node-ზე kubelet-ის upgrade მოითხოვს მის restart-ს - ამ მომენტში node დროებით კარგავს Pod-ების სტატუსის სწორად რეპორტინგისა და ახლების მიღების უნარს. `drain` წინასწარ გადაასახლებს ჩვეულებრივ workload-Pod-ებს სხვა node-ებზე (ან მონიშნავს მათ evicted-ად), რომ node-ის ეს დროებითი ჩავარდნა აპლიკაციის downtime-ად არ იქცეს. `drain`-ის გარეშე განახლების პროცესში მყოფ node-ზე Pod-ები restart-ის დროს მიუწვდომელი შეიძლება აღმოჩნდეს სხვა node-ზე კომპენსაციური გადასვლის გარეშე.
</details>

## კავშირი კურსთან

- [თავი 13. Kubernetes-ის განახლება მოწყვლადობების აღმოსაფხვრელად](../../course/13/ge.md)

## ინფრასტრუქტურა

Terragrunt ქმნის self-managed Kubernetes `1.35.4`-ს `eu-central-1`-ში, containerd,
Calico CNI:

| კომპონენტი | დანიშნულება |
|---|---|
| `k8s-1` control-plane | ჩვეულებრივი control-plane node, რომელიც ჩვეულებრივ Pod-ებს უშვებს (single control-plane, ცალკე მეორე control-plane node-ის გარეშე) |
| `k8s-1` worker `worker1` | ჩვეულებრივი worker-node იმავე საწყის ვერსიაზე |
| `worker` | სამუშაო მანქანა `kubectl`-ით, `check_result`-ით და SSH-წვდომით კლასტერის ორივე node-ზე |

upgrade-ის მიზნობრივი ვერსია - `1.36.x` (ლაბის დროს ბოლო ხელმისაწვდომი patch), ანუ
დავალებების შესრულების შემდეგ კლასტერი იმავე training baseline ვერსიაზე აღმოჩნდება, რაზეც
დანარჩენი core ლაბები 101-112. minor-ვერსიების გამოტოვებას (მაგალითად პირდაპირი გადასვლა `1.35` → `1.37`)
kubeadm მხარს არ უჭერს - ამ ლაბში ასეთი გადასვლა არც არის საჭირო.

node-ებზე წვდომისთვის გამოიყენეთ alias-ები `k8s113_controlPlane_1` და `k8s113_node_worker1`.

Namespace `upgrade-113` Deployment-ით `canary` (2 replica) უკვე განთავსებულია - ეს თქვენი
downtime-ის არარსებობის ინდიკატორია. მთელი upgrade-ის განმავლობაში სულ მცირე ერთი replica უნდა
რჩებოდეს `Available`; თითოეული node-ის `uncordon`-ის შემდეგ და ფინალში Deployment უნდა
აღდგეს `2/2`-მდე. Bootstrap წინასწარ ანაწილებს ორივე replica-ს სხვადასხვა
node-ებზე (required `podAntiAffinity`) და ქმნის `PodDisruptionBudget`-ს `minAvailable: 1`-ით.

## განთავსება

```bash
TASK=113 make run_cks_task
```

დაუკავშირდით სამუშაო მანქანას და აირჩიეთ მზა კონტექსტი:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

შექმენით დადასტურებების დირექტორია სამუშაოს დაწყებამდე:

```bash
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## დავალებები

---
| **1** | **control-plane-ის upgrade მიზნობრივ minor-მდე** |
| :---: | :--- |
| რას ვაკეთებთ | • შედით `k8s113_controlPlane_1`-ზე (`ssh`, შემდეგ `sudo -i`).<br/>• გადართეთ apt-repository `pkgs.k8s.io` `core:/stable:/v1.35`-დან `core:/stable:/v1.36`-ზე: `/etc/apt/sources.list.d/kubernetes.list`-ში იცვლება მხოლოდ ვერსია URL-ში (ასე არის აღწერილი Kubernetes-ის დოკუმენტაციაში, keyring იგივე რჩება).<br/>• განაახლეთ პაკეტი `kubeadm` `1.36.x`-მდე, შეასრულეთ `kubeadm upgrade plan`, შემდეგ `kubeadm upgrade apply v1.36.x`.<br/>• მხოლოდ წარმატებული `apply`-ის შემდეგ შეასრულეთ `kubectl drain` ამ node-ისთვის.<br/>• განაახლეთ პაკეტები `kubelet`/`kubectl` `1.36.x`-მდე, გადატვირთეთ `kubelet`, შემდეგ შეასრულეთ `kubectl uncordon`. |
| მიღების კრიტერიუმები | • `kubeadm version`, `kubelet --version`, ლოკალური `kubectl version --client` და API server-ის ვერსია (`kubectl version`) control-plane-ზე აცხადებს `v1.36.x`-ს.<br/>• control-plane node (`<cp-სახელი>` `kubectl get no`-დან) სტატუსშია `Ready`.<br/>• ბრძანების `kubeadm upgrade apply` სრული გამოტანა (სტრიქონით `SUCCESS` და მიზნობრივი ვერსიით) სიტყვასიტყვით შენახულია `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt`-ში სამუშაო მანქანაზე (ბრძანება სრულდება node-ზე, გამოტანა იწერება ფაილში node-ზე, შემდეგ კოპირდება `scp`-ით). |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

თანმიმდევრობა პრინციპულია: ჯერ `apt-mark unhold kubeadm` → პაკეტის განახლება → `apt-mark hold kubeadm` → `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z`, და მხოლოდ წარმატებული `apply`-ის შემდეგ - `drain` და `kubelet`/`kubectl`-ის განახლება. `kubelet`-ის განახლება `kubeadm upgrade apply`-ის გამოძახებამდე საჭირო არ არის და ოფიციალური პროცედურით რეკომენდებული არ არის. `kubeadm upgrade apply`-ის გამოტანა შეინახეთ ფაილში node-ზე (`> /tmp/kubeadm-upgrade-apply.txt 2>&1`), და შემდეგ მეხსიერებით ნუ აღადგენთ - ტესტი ეძებს სიტყვასიტყვით ტექსტს სიტყვით `SUCCESS`.
</details>

---
| **2** | **worker-node-ის upgrade მიზნობრივ minor-მდე** |
| :---: | :--- |
| რას ვაკეთებთ | • `k8s113_node_worker1`-ზე (`ssh`, `sudo -i`) ანალოგიურად გადართეთ `pkgs.k8s.io` `core:/stable:/v1.36`-ზე და განაახლეთ `kubeadm`.<br/>• შეასრულეთ `kubeadm upgrade node` (არა `apply` - ეს ბრძანება მხოლოდ control-plane-ისთვისაა).<br/>• შეასრულეთ `kubectl drain` ამ node-ისთვის (სამუშაო მანქანიდან, და არა თავად node-იდან).<br/>• განაახლეთ `kubelet`/`kubectl`, გადატვირთეთ `kubelet`, შეასრულეთ `kubectl uncordon`. |
| მიღების კრიტერიუმები | • `kubeadm version`, `kubelet --version` და ლოკალური `kubectl version --client` worker-node-ზე აცხადებს `v1.36.x`-ს.<br/>• `kubectl get nodes` worker-node-ისთვის აჩვენებს `v1.36.x`-ს `kubeletVersion`-ში და სტატუსს `Ready`.<br/>• `kubeadm upgrade node`-ის გამოტანა შენახულია ფაილში node-ზე და დაკოპირებულია `scp`-ით `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt`-ში სამუშაო მანქანაზე. |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

`kubeadm upgrade node` - სწორედ ის ბრძანებაა worker-node-ებისთვის (და დამატებითი control-plane node-ებისთვის), `kubeadm upgrade apply` განკუთვნილია მხოლოდ პირველი/ერთადერთი control-plane node-ისთვის. დაიწყეთ ეს დავალება მხოლოდ მას შემდეგ, რაც დავალება 1 სრულად დასრულებულია და control-plane უკვე `Ready`-ა `1.36.x`-ზე - წინააღმდეგ შემთხვევაში დაარღვევთ version skew policy-ს.
</details>

---
| **3** | **upgrade-ის სწორი თანმიმდევრობის დაცვა** |
| :---: | :--- |
| რას ვაკეთებთ | • შეასრულეთ control-plane-ის upgrade (დავალება 1) სრულად, uncordon-ის ჩათვლით, მანამდე, სანამ worker-node-ის upgrade-ს დაიწყებთ (დავალება 2).<br/>• ცალკე მოქმედება კლასტერში ეს დავალება არ მოითხოვს: თანმიმდევრობას ავტომატურად ამოწმებს checker-owned მონიტორი კლასტერის მდგომარეობისა და ვერსიების. |
| მიღების კრიტერიუმები | • Checker-owned monitor აფიქსირებს საწყის `1.35.x` baseline-ს.<br/>• შემდეგ ფიქსირდება control-plane-ის სრული გადასვლა `1.36.x`-ზე (`Ready`-სა და schedulable-ის ჩათვლით) worker-ის `1.35.x`-ზე ყოფნისას, და მხოლოდ ამის შემდეგ worker-node-ის upgrade-ის დაწყება.<br/>• მდგომარეობა უძლებს მონიტორის გადატვირთვას; baseline-ის არარსებობა ან დაკვირვების გაწყვეტა 60 წამზე მეტით არ ითვლება. |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

თუ worker-node-ის upgrade უკვე დაიწყეთ (ან მით უმეტეს დაასრულეთ) control-plane-მდე - გაჩერდით, worker-ის უკან დაბრუნება `1.35.x` პაკეტების ჩამოტვირთვაზე მარტივი გზით შეუძლებელია, მაგრამ სწორი გზა - control-plane-ის upgrade-ის დასრულებაა, შემდეგ worker-node-ის upgrade-ის გაგრძელება/გამეორება. მთავარია - worker-node-ის შემდეგი upgrade (როდესაც არ უნდა იყოს დაწყებული) უნდა მოხდეს control-plane-ის სრულად დასრულებული upgrade-ის შემდეგ. დავალება 2-ს ნუ დაიწყებთ, სანამ `kubectl get node <cp-სახელი>` არ აჩვენებს `v1.36.x`-სა და `Ready`-ს.
</details>

---
| **4** | **არსებული დატვირთვისთვის downtime-ის არარსებობის დამტკიცება** |
| :---: | :--- |
| რას ვაკეთებთ | • სანამ დავალებებს 1-2 ასრულებთ, სამუშაო მანქანაზე ცალკე სესიაში გაუშვით ციკლი, რომელიც Deployment `canary`-ის ხელმისაწვდომობას namespace `upgrade-113`-ში რამდენიმე წამში ერთხელ ამოწმებს.<br/>• ჩაამატეთ ყოველი გამოკითხვის სტრიქონი `/var/work/tests/artifacts/4/canary-availability.log`-ში ფორმატით, რომელიც შეიცავს `available=N`-ს (მაგალითად `available=2`).<br/>• გააგრძელეთ გამოკითხვა ორივე node-ის მთელი upgrade-ის განმავლობაში. |
| მიღების კრიტერიუმები | • Deployment `canary`-ს ბოლოს აქვს `2/2` ხელმისაწვდომი replica, საწყისი Deployment/PDB და required Pod anti-affinity შენარჩუნებულია.<br/>• downtime-ის არარსებობას ამოწმებს checker-owned monitor Pod Ready-ითა და CRI-კონტეინერებით სწორედ `upgrade-113`-დან; API/SSH/CRI-ის შეცდომები ითვლება UNKNOWN-ად, და არა ნულად.<br/>• Student-ფაილი `/var/work/tests/artifacts/4/canary-availability.log` შეიცავს მინიმუმ ორ სტრიქონს ფორმატით `<unix_timestamp> available=N` ან `<unix_timestamp> available=api-unreachable`, დაკვირვებებით control-plane-ის upgrade-მდე და worker-ის upgrade-ის დაწყების შემდეგ. |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

გამოკითხვის ციკლის მაგალითი, რომელიც შეიძლება გაშვებული დატოვოთ ცალკე ტერმინალში/`screen`/`tmux`-ში დავალებების 1-2 შესრულების მთელი დროის განმავლობაში: `while true; do if available=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then echo "$(date +%s) available=${available:-0}"; else echo "$(date +%s) available=api-unreachable"; fi >> /var/work/tests/artifacts/4/canary-availability.log; sleep 5; done`. თუ Deployment მოკლე დროით ყველა replica-ს კარგავდა - შეამოწმეთ `kubectl get pods -n upgrade-113 -o wide` და რომ თანმიმდევრული drain-ები PDB-სა და required anti-affinity-ს იცავს.
</details>

## შედეგის შემოწმება

```bash
check_result
```

შემოწმება შეიცავს `0 Init`-სა და ხუთ სავალდებულო ტესტს. ტესტები 1-2 ამოწმებს
`kubeadm`/`kubelet`/ლოკალური `kubectl`-ის ვერსიებსა და სტატუსს `Ready` control-plane-ზე და worker-node-ზე
შესაბამისად, ასევე სიტყვასიტყვით evidence-ფაილს `kubeadm upgrade`-ის გამოტანით. ტესტი 3
ამოწმებს upgrade-ის თანმიმდევრობას checker-owned მონიტორით კლასტერის მდგომარეობის, და არა
ფაილების მოდიფიკაციის დროით. ტესტი 4 ამოწმებს, რომ დატვირთვას `canary` არ ჰქონია downtime,
ჭეშმარიტების წყაროდ იმავე checker-owned monitor-ის გამოყენებით. ტესტი 5 - საბოლოო
შემოწმებაა, რომ ორივე node მართლაც მიზნობრივ ვერსიაზეა და არ არის დატოვებული მდგომარეობაში
`cordon`.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD).

## წაშლა

```bash
TASK=113 make delete_cks_task
```
