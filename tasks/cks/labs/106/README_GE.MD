[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 106 - AppArmor და seccomp: node-local policy და შემოწმებადი უარყოფები

## მიზანი

ამ CKS-ლაბში თქვენ გამოიყენებთ კონტეინერის პროცესის დაცვის ორ დამოუკიდებელ მექანიზმს
Linux-ის ბირთვის დონეზე. ჯერ წინასწარ მიწოდებულ **AppArmor**-პროფილს
`complain`-დან `enforce`-ში გადაიყვანთ, მიანიჭებთ მას Pod-ს თანამედროვე ველით
`securityContext.appArmorProfile` და დაადასტურებთ ჩაწერის უარყოფას. შემდეგ მიანიჭებთ უსაფრთხო
baseline-ს `RuntimeDefault` და custom **seccomp Localhost**-პროფილს, რომელიც ბლოკავს
სისტემურ გამოძახებას `unshare(2)`.

ეს CKA-ლაბ 106-ის ბაზისური `SecurityContext`-ის გაგრძელებაა: აქ YAML-ის დაწერა საკმარისი არ არის.
Localhost-პროფილები Kubernetes-node-ზე ცხოვრობს, ამიტომ უნდა შეამოწმოთ node,
Pod-ის placement და პროცესის ფაქტობრივი ქცევა.

## Threat model

დავუშვათ RCE კონტეინერში. კითხვა compromise-ის შემდეგ არის არა «შეეძლო თუ არა თავდამსხმელს shell-ის მიღება», არამედ «რისი გაკეთება შეუძლია ამ shell-ს შემდეგ» და რამდენად დიდია მისი blast radius.

AppArmor დავალებებში 1–2 ზღუდავს ობიექტებსა და ოპერაციებს: პროფილი გადადის enforce-ში და შემდეგ მტკიცდება ჩაწერის უარყოფა. ასე უკვე კომპრომეტირებული პროცესი შეუზღუდავ მოქმედებას არ იღებს მხოლოდ იმიტომ, რომ ის კონტეინერში სრულდება.

seccomp დავალებებში 3–5 ზღუდავს ხელმისაწვდომ სისტემურ გამოძახებას: ჯერ გამოიყენება baseline, შემდეგ custom profile, ხოლო შემდეგ მოწმდება `unshare(2)`-ის რეალური უარყოფა. დავალება 5 უკვე შეიცავს negative control-ს Pod-ით `sysadmin-control`: იმავე capability-ის დროს seccomp filter-ის გარეშე გამოძახება გადის, ამიტომ შედარება სწორედ compromise-ის შემდგომ საზღვარს აჩვენებს.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რით განსხვავდება `complain` `enforce`-გან AppArmor-ში, და რატომ არ შეიძლება `complain`-ის დაცვის დადასტურებად ჩვენება?</summary>

`complain` რეჟიმში AppArmor მხოლოდ ლოგავს პროფილის დარღვევებს, მაგრამ არ ბლოკავს მათ - ოპერაცია, რომელიც უნდა იყოს აკრძალული, მაინც შესრულდება, უბრალოდ ჟურნალში ჩანაწერი გაჩნდება. `enforce`-ში ოპერაცია რეალურად იბლოკება. დავალება 1 აშკარად მოითხოვს პროფილის `enforce`-ში გადაყვანას, რადგან დემონსტრაცია "აი დარღვევა ლოგში" `complain`-ის დროს დაცვას არ ამტკიცებს - პროცესმა მაინც შეძლო მოქმედების შესრულება.
</details>

<details>
<summary>2. რატომ არ აქრობს `allowPrivilegeEscalation: false` უკვე გაცემულ capability `SYS_ADMIN`-ს?</summary>

`allowPrivilegeEscalation: false` რთავს kernel-ფლაგს `no_new_privs`, რომელიც პროცესს უკრძალავს ახალი უფლებების მიღებას `execve`-ით (მაგალითად, setuid-binary-ით ან file capabilities-ით). ეს გავლენას არ ახდენს უფლებებზე, რომლებიც პროცესს უკვე აქვს თავის effective/bounding set-ში - თუ კონტეინერი manifest-ში აშკარად მითითებული capability `SYS_ADMIN`-ით არის გაშვებული, ეს capability ხელმისაწვდომი რჩება `allowPrivilegeEscalation`-ის მნიშვნელობის მიუხედავად.
</details>

<details>
<summary>3. რატომ მიეთითება `localhostProfile` Pod-ის manifest-ში როგორც ფარდობითი გზა, და არა აბსოლუტური?</summary>

Kubelet თავად ანაწილებს ფარდობით გზას თავისი seccomp root-ის მიმართ (ნაგულისხმევად `/var/lib/kubelet/seccomp/`). თუ აბსოლუტურ გზას მიუთითებთ, kubelet ფაილს ეძებს ამ აბსოლუტური გზით seccomp root-ის შიგნით, რაც თითქმის ყოველთვის ფაილის რეალურ მდებარეობას არ ემთხვევა - Pod მიიღებს `CreateContainerError`-ს.
</details>

## კავშირი კურსთან

- [თავი 16. AppArmor](../../course/16/ge.md)
- [თავი 17. seccomp](../../course/17/ge.md)
- [თავი 03. Container Runtime Security](../../course/03/ge.md)

## ინფრასტრუქტურა

გარემო იშლება Terragrunt-ით AWS `eu-central-1`-ში.

| კომპონენტი | დანიშნულება |
|---|---|
| `vpc` | VPC `10.10.0.0/16` საჯარო ქვექსელებით |
| `ssh-keys` | გასაღებები node-ზე წვდომისთვის |
| `k8s-1` | ერთკვანძიანი kubeadm-კლასტერი Kubernetes `1.36.0`, containerd და **Calico** |
| `worker` | სამუშაო მანქანა `kubectl`-ით, `check_result`-ით და SSH-წვდომით node-ზე როგორც `control-plane` |

რესურსების დასაზოგად control-plane ერთადერთი workload-node-ია: მასზე მოხსნილია
`NoSchedule` taint. ის მონიშნულია label-ით
`security.cks.io/localhost-profiles-106=true`. ამ ლაბის ყველა Pod უნდა ირჩევდეს სწორედ
ამ node-ს - plan-პროფილი scheduler-ის მიერ სხვა node-ზე არ გადადის.

Bootstrap-მა მოამზადა **მხოლოდ**:

- node-ის label `security.cks.io/localhost-profiles-106=true` უსაფრთხო placement-ისთვის;
- სამუშაო მანქანაზე (worker), `/opt/lab106-fixtures/`-ში: საწყისი ფაილები `k8s-106-deny-write`
  (AppArmor profile) და `cks-106-deny-unshare.json` (custom seccomp profile).

არც AppArmor profile და არც seccomp profile **არ** არის წინასწარ დაყენებული workload-node-ზე და არ
არის ჩატვირთული მის ბირთვში - თითოეულის გადატანა და პირველადი ჩატვირთვა დავალებების 1 და 5 ნაწილია.
seccomp profile-ის გზას ნუ შეცვლით და profile-ს ჩვეულებრივი Pod-ის შიგნით ნუ შექმნით: ფაილების
node-ზე გადატანას თქვენ ასრულებთ როგორც node-ის ადმინისტრატორი SSH-ით, და არა workload-ის შიგნიდან.

## განთავსება

```bash
TASK=106 make run_cks_task
```

დაუკავშირდით სამუშაო მანქანას SSH-ით. კონტექსტი უკვე გამართულია:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

სამუშაოს დაწყებამდე შეამოწმეთ node-წვდომა და worker-side fixtures:

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ls -la /opt/lab106-fixtures/
```

## დავალებები

---
| **1** | **AppArmor profile-ის გადატანა და ჩატვირთვა** |
| :---: | :--- |
| რას ვაკეთებთ | Profile `k8s-106-deny-write`-ის საწყისი ფაილი მხოლოდ სამუშაო მანქანაზე დევს, `/opt/lab106-fixtures/k8s-106-deny-write`-ში. დააკოპირეთ ის node `control-plane`-ზე `/etc/apparmor.d/k8s-106-deny-write`-ში (მაგალითად, `scp`-ით) და ჩატვირთეთ ბირთვში `sudo apparmor_parser -r`-ით. Profile უკვე შეიცავს ფლაგს `complain` - მისი მეორედ ჩართვა საჭირო არ არის, ეს დავალება 2-ის ამოცანაა. |
| მიღების კრიტერიუმები | `/etc/apparmor.d/k8s-106-deny-write` node-ზე არსებობს; `/sys/kernel/security/apparmor/profiles` შეიცავს სტრიქონს სახელით `k8s-106-deny-write` (ნებისმიერ რეჟიმში - `complain` ან `enforce`), ანუ profile რეალურად ჩატვირთულია ბირთვში, და არა უბრალოდ დისკზეა დაკოპირებული. |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

`scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/` აკოპირებს ფაილს node-ზე
დროებით დირექტორიაში; გადაიტანეთ ის იქიდან `sudo`-თი `/etc/apparmor.d/`-ში (ჩვეულებრივ
მომხმარებელს იქ პირდაპირ ჩაწერის უფლება არ აქვს). შემდეგ `sudo apparmor_parser -r
/etc/apparmor.d/k8s-106-deny-write` აკომპილირებს და ტვირთავს profile-ს ბირთვში - ამ
ნაბიჯის გარეშე დისკზე ფაილი საერთოდ არანაირ დაცვას არ იძლევა და
`/sys/kernel/security/apparmor/profiles`-ში არ გამოჩნდება.
</details>

---
| **2** | **AppArmor profile-ის enforce-ში გადაყვანა** |
| :---: | :--- |
| რას ვაკეთებთ | node `control-plane`-ზე გადაიყვანეთ დავალება 1-ში ჩატვირთული profile `k8s-106-deny-write` რეჟიმში `enforce`. საწყისი რეჟიმი `complain` დარღვევებს წერს, მაგრამ დაცვა არ არის. Profile-ს ნუ წაშლით და მის სახელს ნუ შეცვლით. |
| მიღების კრიტერიუმები | node label-ით `security.cks.io/localhost-profiles-106=true` არსებობს; `/etc/apparmor.d/k8s-106-deny-write` ხელმისაწვდომია; `/sys/kernel/security/apparmor/profiles` შეიცავს სტრიქონს `k8s-106-deny-write (enforce)`. Checker-owned bootstrap-baseline (დაფიქსირებულია ლაბის გაცემამდე, ამავე profile-ის სატრანზიტო ასლზე, სანამ ის ჯერ კიდევ `complain`-ში იყო) ადასტურებს, რომ ჩაწერა, რომელიც ამ profile-ის პატერნს `/work/**` შეესაბამება, მაშინ მართლაც გადიოდა - ამის გარეშე ვერ დამტკიცდება, რომ სწორედ `enforce`-ში გადასვლამ გამოიწვია შემდგომი უარყოფა. |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

ბრძანება `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` უკვე არსებულ პროფილს ხელახლა ტვირთავს - თუ ის `complain`-ში იყო, ხოლო დისკზე ფაილი უკვე `enforce`-ს აღწერს, ამ ბრძანება საკმარისია. შეამოწმეთ თავი `sudo cat /sys/kernel/security/apparmor/profiles | grep k8s-106-deny-write`-ით - გამოტანამ აშკარად უნდა აჩვენოს `(enforce)`. ამას `aa-status`-ით ნუ შეამოწმებთ: ეს ბრძანება პროფილებს ჯგუფავს სექციების სათაურებქვეშ (`N profiles are in enforce mode.`) და მათ ქვეშ ბეჭდავს მხოლოდ პროფილების შიშველ სახელებს, თითოეულ სტრიქონზე `(enforce)`/`(complain)` სუფიქსის გარეშე - ასეთი სუფიქსი არის მხოლოდ `/proc/<pid>/attr/current`-ში და ბირთვის ფაილში `/sys/kernel/security/apparmor/profiles`, და არა `aa-status`-ის პროფილების სიაში.

`aa-enforce`/`aa-complain` ამ პროფილისთვის ნუ გამოიყენებთ, სანამ დავალება 9 არ შესრულებულა:
`apparmor-utils`-ის ეს Python-ინსტრუმენტები თავისი ძირითადი სამუშაოს წინ პარსავენ
**ყველა** ფაილს `/etc/apparmor.d/`-ში, ჯერ კიდევ გატეხილი `k8s-106-broken-profile`-ის ჩათვლით
დავალება 8-დან, და სხვის ფაილზე parser-ის შეცდომით ვარდებიან. ფლაგი `complain` პროფილის ფაილში
პირდაპირ შეასწორეთ (`sed`) და სწორედ ეს ფაილი ხელახლა ჩატვირთეთ `apparmor_parser -r`-ით -
ეს binary, `aa-enforce`-ისგან განსხვავებით, პარსავს მხოლოდ მისთვის გადაცემულ ფაილს.
</details>

---
| **3** | **Localhost AppArmor Pod და ჩაწერის ბლოკირება** |
| :---: | :--- |
| რას ვაკეთებთ | შექმენით namespace `security-106` და Pod `apparmor-writer`. Pod-მა უნდა აირჩიოს ინფრასტრუქტურიდან node-ის label, გამორთოს ServiceAccount token-ის automount და Pod-ის დონეზე დააყენოს `appArmorProfile.type: Localhost`, `localhostProfile: k8s-106-deny-write`. გამოიყენეთ `busybox:1.36`, კონტეინერი `app`, ძილის ბრძანება `sleep 3600` და `emptyDir`, მიმაგრებული `/work`-ზე. გაშვების შემდეგ დაადასტურეთ ეფექტური profile ბრძანებით `cat /proc/1/attr/current` (თუ ინტერფეისი ხელმისაწვდომია), შეასრულეთ დაშვებული წაკითხვის ოპერაცია, მაგალითად `cat /etc/hostname >/dev/null`, და შემდეგ სცადეთ ფაილის ჩაწერა `/work`-ში; ოპერაცია აუცილებლად უარით უნდა დასრულდეს. node-ზე დააფიქსირეთ AppArmor denial profile/process-ისთვის `journalctl -k | grep -i apparmor`-დან ან `dmesg | grep -i apparmor`-დან. |
| მიღების კრიტერიუმები | Pod გაშვებულია, იყენებს სწორედ Localhost profile-ს და სწორ nodeSelector-ს; პროცესის effective profile აჩვენებს `k8s-106-deny-write`-ს enforce mode-ში (როცა `/proc/.../attr/current` ხელმისაწვდომია); დაშვებული წაკითხვის ოპერაცია `/work`-ში გადის, ხოლო checker independently წერს თავის საკუთარ უნიკალურ (per-run) ფაილს `/work`-ში და იღებს AppArmor-უარს. kernel journal/audit log-ში არის სწორედ ამ მცდელობასთან დაკავშირებული (ფაილის უნიკალური სახელით) მოვლენა `apparmor="DENIED"` ამ profile-ით - ეს გამორიცხავს false pass-ს ჟურნალში მოძველებული denial-მოვლენისგან. |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

`appArmorProfile` ტიპის `Localhost` პროფილისთვის მიეთითება ორი ცალკე ველით: `type: Localhost` და `localhostProfile: k8s-106-deny-write` (პროფილის სახელი `/etc/apparmor.d/` გზის გარეშე) - ეს იგივე სახელია, რომლითაც პროფილი დავალება 1-ში ჩაიტვირთა. თუ Pod არ ეშვება (CreateContainerError), შეამოწმეთ, რომ profile უკვე ჩატვირთულია სწორედ საჭირო node-ზე nodeSelector-ის გავლით - AppArmor-პროფილები node-local-ია, ისინი ავტომატურად არ გადადიან.
</details>

---
| **4** | **seccomp RuntimeDefault-ის უსაფრთხო baseline** |
| :---: | :--- |
| რას ვაკეთებთ | შექმენით `security-106`-ში Pod `runtime-default` `busybox:1.36`-ით და `sleep 3600`-ით. Pod-ის დონეზე აშკარად მიუთითეთ `securityContext.seccompProfile.type: RuntimeDefault`; Pod-მა ასევე უნდა აირჩიოს მომზადებული node. კონტეინერში შეამოწმეთ `/proc/1/status`: მოსალოდნელია `Seccomp: 2`. |
| მიღების კრიტერიუმები | Pod `Running`-ია, მის Pod-level securityContext-ში არჩეულია `RuntimeDefault`, ხოლო პროცესი seccomp filter mode-შია. |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

`Seccomp: 2` `/proc/1/status`-ში ნიშნავს "filter mode აქტიურია" (SECCOMP_MODE_FILTER) - სწორედ ეს უნდა დაინახოთ. `Seccomp: 0` ნიშნავდა seccomp filter-ის საერთოდ არარსებობას (`Unconfined`). ეს ამ ჯგუფის ხუთიდან ყველაზე მარტივი დავალებაა - თუ არ გადის, სავარაუდოდ პრობლემა nodeSelector-შია და არა თავად seccompProfile-ში.
</details>

---
| **5** | **custom Localhost seccomp profile-ის გადატანა და გამოყენება** |
| :---: | :--- |
| რას ვაკეთებთ | საწყისი `cks-106-deny-unshare.json` მხოლოდ სამუშაო მანქანაზე დევს, `/opt/lab106-fixtures/cks-106-deny-unshare.json`-ში. განსაზღვრეთ node label-ით `security.cks.io/localhost-profiles-106=true`, შექმენით მასზე დირექტორია `/var/lib/kubelet/seccomp/profiles/` (თუ ჯერ არ არსებობს) და დააკოპირეთ იქ JSON იმავე სახელით. შემდეგ შექმენით Pod `localhost-seccomp` `security-106`-ში ამ node-ზე. Pod-ის დონეზე მიუთითეთ `seccompProfile.type: Localhost` და ფარდობითი გზა `profiles/cks-106-deny-unshare.json` - `/var/lib/kubelet/seccomp/`-ის გარეშე. კონტეინერმა `app` უნდა გამოიყენოს `busybox:1.36`, მიიღოს capability `SYS_ADMIN` და შემოწმების შემდეგ გაშვებული დარჩეს. **ამ კომბინაციას hardened baseline-ად ნუ გასცემთ:** `SYS_ADMIN` რჩება ერთ-ერთ ყველაზე სახიფათო capability-დ, ხოლო `allowPrivilegeEscalation: false` უკვე გაცემულ უფლებებს არ ართმევს. ეს capability-focused ექსპერიმენტია, სადაც უსაფრთხოებას კონკრეტული seccomp deny აჩვენებს. |
| მიღების კრიტერიუმები | JSON profile გადატანილია და node-ზე სწორ გზაზე არსებობს; Pod სწორი nodeSelector-ით იყენებს profile-ს `Localhost:profiles/cks-106-deny-unshare.json`; JSON profile შეიცავს `SCMP_ACT_ERRNO`/`errnoRet: 1`-ს `unshare`-სთვის; კონტეინერში დამატებულია მხოლოდ ექსპერიმენტისთვის საჭირო `SYS_ADMIN`. |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

გზა `profiles/cks-106-deny-unshare.json` kubelet-ის seccomp root-ის `/var/lib/kubelet/seccomp/`-ის მიმართ ფარდობითია, ანუ node-ზე რეალური ფაილი უნდა იდოს მისამართზე `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json` - სწორედ იქ უნდა დააკოპიროთ ის სამუშაო მანქანიდან (მაგალითად, `scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/`, შემდეგ `sudo mkdir -p` და `sudo mv` node-ზე). manifest-ში სრულ აბსოლუტურ გზას ნუ დაწერთ - kubelet root-ს თავად დაამატებს. `SYS_ADMIN` აქ გაიცემა სწორედ ექსპერიმენტისთვის (საჭიროა capability, რომელიც `unshare`-ის პრინციპულად გამოძახების საშუალებას იძლევა), და არა როგორც რეკომენდებული პრაქტიკა - სასწავლო სცენარს production baseline-თან ნუ აგრევთ.
</details>

---
| **6** | **syscall `unshare(2)`-ის უარყოფის დამტკიცება** |
| :---: | :--- |
| რას ვაკეთებთ | `localhost-seccomp` კონტეინერის ბრძანებაში შეასრულეთ `unshare -n true`, შეინახეთ მოსალოდნელი უარყოფის წარმატებული დადასტურება `/tmp/unshare-result`-ში როგორც სტრიქონი `unshare denied by seccomp`, შემდეგ კონტეინერი `sleep 3600`-ით შეინარჩუნეთ. განმეორებითმა ბრძანებამ `kubectl exec ... -- unshare -n true` უნდა დააბრუნოს არანულოვანი კოდი. attack-minded negative control-ისთვის შექმენით Pod `sysadmin-control` იმავე node-ზე `seccompProfile.type: Unconfined`-ით და იმავე ერთადერთი capability `SYS_ADMIN`-ით; მისმა `unshare -n true`-მ წარმატებით უნდა დასრულდეს. შემოწმების შემდეგ control Pod წაშალეთ. |
| მიღების კრიტერიუმები | Localhost Pod გაშვებულია; `Seccomp: 2`; `unshare` იბლოკება custom profile-ით. control Pod-ში იგივე syscall იმავე capability-ით და seccomp filter-ის გარეშე გადის. ეს ამტკიცებს kernel behavior-ს, და არა მხოლოდ YAML-ის არსებობას. |

<details>
<summary>💡 მინიშნება დავალება 6-ისთვის</summary>

გამოიყენეთ სწორედ `unshare -n true` (unshare network namespace, `CLONE_NEWNET`), და არა
`unshare -m true`. `-m` (mount namespace) მოითხოვს `CAP_SYS_ADMIN`-ს ისევე, როგორც `-n`, მაგრამ
BusyBox `unshare -m` წარმატებული `unshare(2)`-ის შემდეგ დამატებით ასრულებს მეორე,
დამოუკიდებელ `mount(2)` syscall-ს (`mount("none", "/", NULL, MS_REC|MS_PRIVATE, NULL)`
private propagation-ის იძულებისთვის - ეს unshare-ის ქცევაა, ნაგულისხმევად აქტიური,
თუ აშკარად არ არის გადაცემული `--propagation unchanged`, და მაშინაც კი `mount()` მაინც
გამოიძახება, უბრალოდ ნულოვანი ფლაგებით). containerd's default AppArmor-პროფილი (`RuntimeDefault`,
რომელსაც Pod იღებს აშკარა `securityContext.appArmorProfile`-ის გარეშე) შეიცავს `deny mount,`-ს
ფლაგებზე რაიმე პირობის გარეშე - ეს აკრძალვა capabilities-სა და seccomp-ისგან დამოუკიდებლად მოქმედებს.
ამიტომ `unshare -m true` შეიძლება `EPERM`-ით ჩავარდეს AppArmor-ის გამო, თუნდაც
seccomp `unshare`-ს საერთოდ არ ზღუდავდეს, რაც ასეთ probe-ს seccomp-უარყოფის არასაიმედო
დადასტურებად აქცევს. `unshare -n` (`CLONE_NEWNET`) იძახებს მხოლოდ თავად syscall-ს
`unshare(2)` რაიმე შემდგომი `mount()`-ის გარეშე - და `localhost-seccomp`-ც და
`sysadmin-control`-ც ერთსა და იმავე `SYS_ADMIN`-ს იყენებენ, ამიტომ შედეგში განსხვავება
ცალსახად სწორედ seccomp filter-ით აიხსნება, და არა AppArmor-ის გვერდითი ეფექტით.

ბრძანებების თანმიმდევრობა დამტკიცებადობისთვის მნიშვნელოვანია: ჯერ შეასრულეთ `unshare -n true` და დარწმუნდით, რომ ის შეცდომით ვარდება (არანულოვანი exit code), მხოლოდ შემდეგ ჩაწერეთ სტრიქონი `unshare denied by seccomp` `/tmp/unshare-result`-ში - სტრიქონს წინასწარ ნუ ჩაწერთ, შედეგის "დაშვებით". Negative control (`sysadmin-control`) უნდა იყენებდეს იმავე capability `SYS_ADMIN`-ს, მაგრამ `seccompProfile.type: Unconfined`-ს - თუ `Unconfined`-ის აშკარა მითითებას დაივიწყებთ, Pod-მა შეიძლება ნაგულისხმევად `RuntimeDefault` მიიღოს (თუ `seccompDefault` დავალება 8-დან ჩართულია) და ტესტი განსხვავებას ვერ აჩვენებს.
</details>

Linux capabilities და privilege escalation - სხვადასხვა ღერძია. `allowPrivilegeEscalation: false`
რთავს `no_new_privs`-ს და კრძალავს **ახალი** უფლებების მიღებას `execve`-ით (setuid/setgid და
file capabilities), მაგრამ არ შლის `SYS_ADMIN`-ს, რომელიც უკვე დამატებულია bounding/effective set-ში.
ჩვეულებრივი სამუშაო დატვირთვისთვის გამოიყენეთ `capabilities.drop: ["ALL"]` და ცალკე
`allowPrivilegeEscalation: false`; ზემოთ მოცემული ექსპერიმენტი განზრახ არ არის ასეთი baseline.

---
| **7** | **User namespaces: `hostUsers: false` და UID-ის ტრანსლაცია `uid_map`-ით** |
| :---: | :--- |
| რას ვაკეთებთ | User namespaces GA Kubernetes v1.36-ში (იხ. [თავი 03](../../course/03/ge.md), [თავი 18](../../course/18/ge.md) და Security Delta v1.36). თეორია განმარტავს, რომ `hostUsers: false` კონტეინერის root-ს არაპრივილეგირებულ host UID-ად თარგმნის; აქ ეს ცოცხალ პროცესზე უნდა დაამტკიცოთ. შექმენით `security-106`-ში Pod `userns-probe` მომზადებულ node-ზე `spec.hostUsers: false`-ით, image-ით `busybox:1.36`, ბრძანებით `sleep 3600`; Pod-level `runAsUser` ნუ მიუთითებთ, რათა პროცესი UID 0-ით გაეშვას კონტეინერის **შიგნით**. დაადასტურეთ `id` კონტეინერის შიგნით (`uid=0`). განსაზღვრეთ კონტეინერის პროცესის host PID `crictl inspect`-ით (ლაბ 112-ის ანალოგიით) ან `kubectl get pod -o jsonpath` + `crictl ps`-ით, შემდეგ node-ზე წაიკითხეთ `/proc/<host PID>/uid_map`. შეინახეთ ორივე გამოტანა (`id` კონტეინერის შიგნით და `uid_map`-ის შიგთავსი) `/var/work/tests/artifacts/6/userns.txt`-ში. |
| მიღების კრიტერიუმები | Pod `Running`-ია, `spec.hostUsers == false`, ირჩევს მომზადებულ node-ს; `id` კონტეინერის შიგნით აჩვენებს `uid=0(root)`-ს; `/proc/<host PID>/uid_map` node-ზე შეიცავს სტრიქონს ფორმით `0 <host-uid> <length>`, სადაც `<host-uid>` **არ უდრის 0-ს** (კონტეინერის root გადათარგმნილია არაპრივილეგირებულ host UID-ად) და `<length>` უდრის სულ მცირე `65536`-ს (სტანდარტული per-Pod UID-დიაპაზონი); artifact შეიცავს evidence-ის ორივე ნაწილს. |

<details>
<summary>💡 მინიშნება დავალება 7-ისთვის</summary>

`id` კონტეინერის შიგნით აჩვენებს `uid=0(root)`-ს `hostUsers`-ის მიუხედავად - ეს მოსალოდნელია, კონტეინერი ხედავს თავის საკუთარ namespace-ს, სადაც მისი root ნამდვილად UID 0-ია ამ namespace-ში. რეალური დაცვა ჩანს მხოლოდ გარედან: თავად node-ზე, `/proc/<host PID>/uid_map`-ში, სადაც UID 0 კონტეინერის შიგნით ჰოსტზე რაღაც დიდ არაპრივილეგირებულ UID-ად ითარგმნება. host PID-ის საპოვნელად გამოიყენეთ `crictl inspect <container-id>` - სწორედ იქიდან, და არა `kubectl get pod`-იდან, რომელმაც მხოლოდ Kubernetes-ობიექტი იცის, და არა პროცესის host-level PID.
</details>

---
| **8** | **`seccompDefault: true` kubelet-ის დონეზე: baseline აშკარა პროფილის გარეშე** |
| :---: | :--- |
| რას ვაკეთებთ | დავალებებში 4–6 ყველა Pod აშკარად მიუთითებს `seccompProfile`-ს manifest-ში. რეალობაში დეველოპერმა შეიძლება ეს ველი დაივიწყოს - მაშინ node-level baseline-ის გარეშე Pod იღებს `Unconfined`-ს. node-ზე ჩართეთ `seccompDefault: true` `/var/lib/kubelet/config.yaml`-ში და გადატვირთეთ kubelet (`systemctl restart kubelet`). შექმენით Pod `no-seccomp-field` `security-106`-ში მომზადებულ node-ზე `busybox:1.36`-დან (`sleep 3600`), **securityContext.seccompProfile-ს საერთოდ არ მიუთითებთ** არც Pod-ის დონეზე, არც კონტეინერის დონეზე. `/proc/1/status`-ით კონტეინერის შიგნით დაადასტურეთ, რომ kubelet-მა `RuntimeDefault` ავტომატურად გამოიყენა (`Seccomp: 2`), და არა `Unconfined` (`Seccomp: 0`) დატოვა. |
| მიღების კრიტერიუმები | kubelet-ის ეფექტური (გამოყენებული) კონფიგურაცია - `/api/v1/nodes/<node>/proxy/configz`-ით, ველი `.kubeletconfig.seccompDefault` - უდრის `true`-ს; `systemctl is-active kubelet` აბრუნებს `active`-ს, node რჩება `Ready`; Pod `no-seccomp-field`-ს არ აქვს `seccompProfile` არც ერთ დონეზე თავის სპეციფიკაციაში; `/proc/1/status` კონტეინერის შიგნით აჩვენებს `Seccomp: 2`-ს. |

<details>
<summary>💡 მინიშნება დავალება 8-ისთვის</summary>

მთავარი მოთხოვნა - Pod-მა მართლაც საერთოდ არ უნდა ახსენოს `seccompProfile`, არც Pod-ის დონეზე, არც კონტეინერის დონეზე. თუ manifest-ს დავალება 3-დან დააკოპირებთ და ამ ველის წაშლას უბრალოდ დაივიწყებთ - ტესტი ვერ დაამტკიცებს იმას, რაც უნდა: რომ სწორედ node-level `seccompDefault`-მა (და არა manifest-ში აშკარა მითითებამ) უზრუნველყო `Seccomp: 2`.

შემოწმება ეყრდნობა kubelet-ის რეალურად გამოყენებულ კონფიგურაციას, და არა დისკზე ფაილის ტექსტს:
`curl`/`kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq .kubeletconfig.seccompDefault`.
უბრალო grep `/var/lib/kubelet/config.yaml`-ზე არ ამტკიცებს, რომ გაშვებული kubelet სწორედ ამ ფაილს
იყენებს - ბრძანების ფლაგს ან drop-in-ს შეეძლო მნიშვნელობის გადაფარვა თავად ფაილის შეცვლის გარეშე.
აუცილებლად გადატვირთეთ kubelet ფაილის შესწორების შემდეგ - კონფიგურაცია ფრენისას არ აიღება.
</details>

---
| **9** | **გატეხილი AppArmor-პროფილის დებაგი და ხელახალი აწყობა (`apparmor_parser -r -v`)** |
| :---: | :--- |
| რას ვაკეთებთ | დისკზე უკვე დევს `/etc/apparmor.d/k8s-106-broken-profile` - პროფილი სინტაქსური შეცდომით, რომელიც **არასდროს ჩატვირთულა** ბირთვში. შეცდომა თავად იპოვეთ `sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile`-ით (`-Q`/`--skip-kernel-load`: სრულად ასრულებს პროფილის შემოწმებას/კომპილაციას, მაგრამ ბირთვში არ ტვირთავს) ან `sudo apparmor_parser -d /etc/apparmor.d/k8s-106-broken-profile`-ით (`-d`/`--debug`, ერთხელ - მხოლოდ სინტაქსური სისწორის შემოწმება), გაასწორეთ ფაილი და ჩატვირთეთ პროფილი ბირთვში `sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile`-ით. დაადასტურეთ ჩატვირთვა `aa-status \| grep k8s-106-broken-profile`-ით. შეინახეთ შეცდომის გამოტანა **გასწორებამდე** და ჩატვირთვის დადასტურება **შემდეგ** `/var/work/tests/artifacts/8/apparmor-debug.txt`-ში. |
| მიღების კრიტერიუმები | `apparmor-debug.txt` შეიცავს parser-ის შეცდომის ტექსტს (მაგალითად, `syntax error`) მცდელობიდან **გასწორებამდე**; checker-owned bootstrap-baseline (დაფიქსირებულია ლაბის გაცემამდე, თქვენი artifact-ისგან დამოუკიდებლად) დამოუკიდებლად ადასტურებს, რომ საწყისი პროფილი მართლაც შეიცავდა syntax error-ს; `/etc/apparmor.d/k8s-106-broken-profile` დისკზე აღარ შეიცავს საწყის სინტაქსურ შეცდომას; `aa-status` აჩვენებს `k8s-106-broken-profile`-ს ჩატვირთულ პროფილებს შორის (ნებისმიერ რეჟიმში - `enforce` ან `complain`); განმეორებითი `apparmor_parser -Q` გასწორებულ ფაილზე შეცდომის გარეშე სრულდება. |

<details>
<summary>💡 მინიშნება დავალება 9-ისთვის</summary>

`apparmor_parser -p` (`--preprocess`) safe dry-run/syntax-check რეჟიმი **არ არის** - ეს
მხოლოდ preprocessing-ია: ხსნის `#include` დირექტივებს და მიღებულ
პროფილს stdout-ში ბეჭდავს, თავისთავად გვერდითი ეფექტების არარსებობას არ გარანტირებს და
სინტაქსის შესამოწმებლად არ არის განკუთვნილი. გამოიყენეთ `-Q`/`--skip-kernel-load`
(ასრულებს სრულ კომპილაციას/შემოწმებას, მაგრამ ბირთვში არ ტვირთავს) ან `-d`/`--debug`
(ერთხელ - მხოლოდ სინტაქსური სისწორის შემოწმება), რათა უსაფრთხოდ იპოვოთ
სინტაქსური შეცდომა გვერდითი ეფექტების გარეშე. მხოლოდ ფაილის გასწორების შემდეგ გამოიყენეთ
`-r` (reload/load) ბირთვში რეალური ჩატვირთვისთვის. AppArmor-სინტაქსი მოითხოვს მძიმეს, როგორც
წესების გამყოფს ბლოკის შიგნით - შეისწავლეთ parser-ის გამოტანა, რათა იპოვოთ, რომელი სიმბოლო
აკლია და სად ზუსტად.

`apparmor_parser`-ს `sudo`-თი გაუშვით, `-Q`/`-d`-ითაც კი: ლაბის node-ზე (apparmor 3.0.4,
Ubuntu) პრივილეგიების გარეშე parser ყოველი გაშვებისას ცდილობს policy cache-ის გამართვას
`/var/cache/apparmor`-ში და ვარდება "Failed setting up policy cache: Permission denied"-ით სინტაქსის
შემოწმებამდე - პროფილის რეალური სინტაქსური შეცდომის ნაცვლად მიიღებთ მატყუარა შეცდომას უფლებების შესახებ.
ეს შემოწმებულია თავად node-ზე (ცნობილად გატეხილ პროფილზეც).
თუ `sudo`-ს გარეშე გაშვება გჭირდებათ, დაამატეთ `-K` (`--skip-cache`: არანაირი ქეშირება) -
`apparmor_parser -Q -K` პრივილეგიების გარეშე პროფილის გარჩევამდე აღწევს და რეალურ
შეცდომას აჩვენებს. ჩატვირთვა და reload (`-r`) ნებისმიერ შემთხვევაში პრივილეგიებს მოითხოვს.
</details>

## შედეგის შემოწმება

სამუშაო მანქანაზე შეასრულეთ:

```bash
check_result
```

შემოწმება შეიცავს Init-ს და ცხრა დამოუკიდებელ ტესტს. ის კითხულობს Pod-ის state-ს API-ს გავლით, ამოწმებს
profile-ს node-ზე SSH-ით და ასრულებს კონტროლირებად უარყოფით სცენარებს. თუ Localhost
Pod არ იქმნება, ჯერ ნახეთ `kubectl describe pod`: ჩვეულებრივი მიზეზია აბსოლუტური
გზა ფარდობითის ნაცვლად ან Pod-ის მინიჭება node-ზე profile-ის გარეშე.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD).

## წაშლა

```bash
TASK=106 make delete_cks_task
```
