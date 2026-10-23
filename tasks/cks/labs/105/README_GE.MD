[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 105 - System Hardening ოპერაციული სისტემისა და Docker daemon-ის უსაფრთხოება

## მიზანი

ამ CKS-ლაბში თქვენ შეამცირებთ ორი Linux-ჰოსტის შეტევის ზედაპირს. Kubernetes
control-plane-ზე უნდა გამორთოთ ზედმეტი სერვისები, დახუროთ ღია პორტი, გამართოთ firewall,
დაიცვათ kubeconfig და აკრძალოთ root-ით პირდაპირი login SSH-ით. ცალკე `docker-host`-ზე
უნდა აღმოფხვრათ Docker daemon-ის სამი სახიფათო პარამეტრი: TCP API TLS-ის გარეშე, წვდომა
`docker.sock`-ზე ჯგუფ `docker`-ის გავლით და მომხმარებელ `developer`-ის წვდომა ამ სოკეტზე.

ეს სასწავლო გარემო განზრახ არის შექმნილი სახიფათოდ. საწყის პარამეტრებს
production-ში ნუ გადაიტანთ: Docker API TCP/2375-ზე TLS-ის გარეშე ნებისმიერს, ვისაც შეუძლია
პორტთან დაკავშირება, დისტანციურ root-წვდომას აძლევს.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რით განსხვავდება `systemctl disable` `systemctl stop`-ისგან, და რატომ არის დავალება 1-ისთვის საჭირო ორივე?</summary>

`stop` აჩერებს უკვე გაშვებულ პროცესს ახლავე, მაგრამ გავლენას არ ახდენს ავტოგაშვებაზე სისტემის შემდეგი ჩატვირთვისას. `disable` სერვისს ამოიღებს ავტოგაშვებიდან (unit-ფაილი target-ზე აღარ არის მიბმული), მაგრამ უკვე მომუშავე პროცესს არ აჩერებს. შეტევის ზედაპირის სრულად დასახურად საჭიროა ორივე - წინააღმდეგ შემთხვევაში სერვისი ან ახლა გააგრძელებს მუშაობას, ან reboot-ის შემდეგ ისევ გაეშვება.
</details>

<details>
<summary>2. რატომ არის TCP Docker API TLS-ის გარეშე (`-H tcp://0.0.0.0:2375`) დისტანციური root-წვდომის ექვივალენტი?</summary>

Docker daemon მუშაობს root-ის უფლებებით, ხოლო მის API-ს TLS client certificates-ის გარეშე built-in authentication არ აქვს. ნებისმიერს, ვისაც ამ პორტთან ქსელით დაკავშირება შეუძლია, შეუძლია გაუშვას თვითნებური container `--privileged`-ით და მიმაგრებული host filesystem-ით - და მიიღოს ჰოსტზე სრული კონტროლი, SSH-ისა და წვდომის კონტროლის ნებისმიერი სხვა მექანიზმის გვერდის ავლით.
</details>

<details>
<summary>3. რატომ არის `chmod 600` kubeconfig-ისთვის მნიშვნელოვანი, მაშინაც კი, თუ ფაილი ისედაც მხოლოდ root-ისთვისაა ხელმისაწვდომი ფაილური სისტემის გავლით?</summary>

`/etc/kubernetes/admin.conf` შეიცავს client certificate-ს `cluster-admin`-ის უფლებებით - თუ ფაილის რეჟიმი ძალიან ფართოა (მაგალითად, `644`, ყველას მიერ წასაკითხი), ამ node-ზე ნებისმიერ მომხმარებელს, sudo-ს გარეშეც კი, შეუძლია credential წაიკითხოს და მიიღოს კლასტერზე სრული ადმინისტრაციული წვდომა დისტანციურად, თავად node-ზე პრივილეგიების ესკალაციის საჭიროების გარეშე.
</details>

<details>
<summary>4. რატომ შეიძლება პროცესის core dump-მა secret გაჟონოს, თუნდაც თავად secret დისკზე არასდროს ჩაწერილა?</summary>

Core dump - ეს არის პროცესის მეხსიერების სურათი crash-ის მომენტში, რომელიც **შეიძლება** შეიცავდეს ცვლადების გაშიფრულ მნიშვნელობებს, პირად გასაღებებს და token-ებს, რომლებიც ღია სახით ინახება. ეს გარანტირებულად პროცესის მთელი მეხსიერება არ არის: mappings-ის ნაკრები დამოკიდებულია `/proc/<pid>/coredump_filter`-ზე, ხოლო ცალკეული უბნები შეიძლება გამოირიცხოს, მაგალითად `MADV_DONTDUMP`-ით. ამიტომ, თუნდაც აპლიკაცია secret-ს აშკარად არასდროს წერდეს ფაილში, crash dump-მა შეიძლება დისკზე წასაკითხ ფაილში შეინახოს ჩართულ mappings-ში მყოფი secrets.
</details>

## კავშირი კურსთან

- [თავი 14. ჰოსტის ოპერაციული სისტემის footprint-ის მინიმიზაცია და runtime-daemon-ის უსაფრთხოება](../../course/14/ge.md)
- [თავი 15. Least-privilege ჰოსტზე და გარე წვდომის მინიმიზაცია](../../course/15/ge.md)
- [CKA: systemd, სერვისები და Linux](../../../cka/course/00-5-linux/ge.md)
- [CKA: კონტეინერები და runtime](../../../cka/course/00-4-containers/ge.md)

## ინფრასტრუქტურა

გარემო განთავსდება Terragrunt-ით AWS `eu-central-1`-ში:

| კომპონენტი | დანიშნულება |
|---|---|
| `vpc` | VPC `10.10.0.0/16` ორი საჯარო ქვექსელით |
| `ssh-keys` | SSH-გასაღები შიდა კავშირებისთვის |
| `k8s-1` | ერთკვანძიანი kubeadm-კლასტერი Kubernetes `1.36.0`, containerd, Calico; ეს არის სამიზნე control-plane |
| `docker-host` | ცალკე Ubuntu 22.04 Docker-ით და განზრახ არაუსაფრთხო კონფიგურაციით |
| `worker` | სამუშაო მანქანა `kubectl`-ით, SSH-კონფიგურაციით და `check_result`-ით |

`worker`-ს აქვს SSH-წვდომა control-plane-ზე მისი Kubernetes node name-ით და ცალკე
ჰოსტზე სახელით `docker-host`. Docker არ არის Kubernetes-კლასტერის runtime: მისი
კონფიგურაცია დავალება 6-დან იზოლირებულია `docker-host`-ზე.

## განთავსება

```bash
TASK=105 make run_cks_task
```

დაუკავშირდით `worker`-ს (kubectl-ის კონტექსტი უკვე გამართულია), ნახეთ control-plane
node-ის სახელი და შედით ჰოსტებზე:

```bash
kubectl get no
ssh <node-ის-სახელი-გამოტანიდან>
ssh docker-host
```

სასარგებლო ბრძანებები:

```bash
time_left
check_result
```

შემოწმების artifacts შეინახეთ `/var/work/tests/artifacts/<ნომერი>/`-ში. ამ ლაბისთვის
Kubernetes-ის manifest-ების შექმნა საჭირო არ არის.

## დავალებები

---
| **1** | **ზედმეტი სერვისის გამორთვა** |
| :---: | :--- |
| რას ვაკეთებთ | control-plane-ზე გამორთეთ და შეაჩერეთ `cks-lab105-unused.service`. სერვისი Kubernetes-ის მუშაობისთვის არ არის საჭირო და reboot-ის შემდეგ არ უნდა გაეშვას. |
| მიღების კრიტერიუმები | `systemctl is-enabled cks-lab105-unused.service` აბრუნებს `disabled`-ს, `systemctl is-active` - `inactive`-ს; `/var/work/tests/artifacts/1/service.txt`-ში არის სტრიქონი `disabled inactive`. |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

ბრძანებების თანმიმდევრობა: `sudo systemctl stop cks-lab105-unused.service && sudo systemctl disable cks-lab105-unused.service` - ორივე ნაბიჯია საჭირო, არცერთი მეორეს არ ანაცვლებს (იხ. კითხვა 1 ზემოთ თვითშემოწმების განყოფილებაში). Artifact უნდა შეიცავდეს სწორედ სტრიქონს "disabled inactive" (ამ თანმიმდევრობით, ინტერვალით) - შენახვამდე შეამოწმეთ ფორმატი.
</details>

---
| **2** | **არასაჭირო ღია პორტის დახურვა** |
| :---: | :--- |
| რას ვაკეთებთ | control-plane-ზე აღმოფხვრეთ listener TCP/8080, რომელიც `cks-lab105-port.service`-მა შექმნა. გამორთეთ და შეაჩერეთ სერვისი (ორივე მოქმედება სავალდებულოა - იხ. კითხვა 1 თვითშემოწმების განყოფილებაში); ის არც control-plane-ს სჭირდება, არც kubelet-ს. |
| მიღების კრიტერიუმები | `ss -ltn` TCP/8080-ს არ აჩვენებს; `systemctl is-enabled cks-lab105-port.service` აბრუნებს `disabled`-ს, `systemctl is-active` - `inactive`-ს; `/var/work/tests/artifacts/2/service.txt` შეიცავს სტრიქონს `disabled inactive`; `/var/work/tests/artifacts/2/port-8080.txt` შეიცავს `tcp/8080: closed`-ს. |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

ჯერ იპოვეთ, რომელი პროცესი ფლობს პორტს (`sudo ss -ltnp | grep 8080`), რათა დარწმუნდეთ, რომ ეს მართლაც `cks-lab105-port.service`-ია და არა რაიმე სხვა. პორტის დახურვა firewall-ით (დავალება 3) ამ დავალებისთვის საკმარისი არ არის - ტესტი ამოწმებს, რომ listener თავად არ არსებობს, და არა უბრალოდ გარედან დაბლოკილია.
</details>

---
| **3** | **შემომავალი ტრაფიკის შეზღუდვა firewall-ით** |
| :---: | :--- |
| რას ვაკეთებთ | • UFW-ის ჩართვამდე დააფიქსირეთ node-ის როლი, worker source IP, node InternalIP და `spec.podCIDR`.<br/>• **სავალდებულო baseline firewall-მდე:** დააფიქსირეთ baseline-ცდა TCP/10250 (kubelet HTTPS endpoint) worker-იდან - `curl` რეალური `CURL_EXIT`/`HTTPCODE`-ით, რომელიც პორტის ქსელურ მისაწვდომობას ადასტურებს (ნებისმიერი 1xx-5xx, 401/403-ის ჩათვლით, ითვლება მისაწვდომობად - kubelet API-მ რეალურად უპასუხა). ამ ნაბიჯის გარეშე post-hardening „დაბლოკილია“ ვერ გაირჩევა გარეგანი ხარვეზისგან (security group, routing), რომელიც პორტს UFW-მდეც ბლოკავდა. თქვენი ჩანაწერის გარდა, checker დამოუკიდებლად ადარებს ამას თავის საკუთარ bootstrap-baseline-ს, დაფიქსირებულს ლაბის გაცემამდე დაცულ დირექტორიაში `/var/lib/cks-lab105-checker` (`0711 root:root`, `/var/work/tests`-ისგან ცალკე, რომელიც ნაგულისხმევად ყველასთვისაა ჩასაწერად ხელმისაწვდომი).<br/>• ტოპოლოგია: ერთკვანძიანი control-plane + workload node. საჭიროა ზუსტად ხუთი წესი: loopback, SSH recovery worker-იდან, API `6443/tcp` worker-იდან, თავად node-იდან და Pod CIDR-იდან. etcd/scheduler/controller-manager იყენებენ ლოკალურ flows-ს, ამ ტოპოლოგიაში node-თაშორისი CNI/kubelet flows არ არის.<br/>• firewall-ს მართეთ მხოლოდ ბრძანებით `ufw` (allow/deny/reject/limit/route, შემდეგ enable/reload). ხელით ნუ დაარედაქტირებთ `/etc/ufw/before*.rules`, `after*.rules`, `user.rules`, `user6.rules`: framework-ფაილები (before/after) hash-ით ექვემდებარება შედარებას bootstrap-baseline-თან, ხოლო `user.rules`/`user6.rules` (სადაც ufw თქვენს წესებს წერს) მოწმდება ბირთვის ფაქტობრივი მდგომარეობით (`ufw show user-rules`), და არა მხოლოდ ფაილით.<br/>• დაამატეთ source-scoped allow rules `ufw default deny incoming`-მდე. ფართო `ALLOW Anywhere`-ს ნუ გამოიყენებთ და ამ ხუთზე (loopback + 4 source-scoped) მეტ სხვა წესებს ნუ დაამატებთ, deny/reject/route-ის ჩათვლით.<br/>• ჩართეთ UFW და შეინახეთ `/var/work/tests/artifacts/3/`-ში: `ufw status`, `ufw show added` (დამატებული წესების ნორმალიზებული წარმოდგენა - სავალდებულო არ არის საწყისი სახით/ბრძანებების თანმიმდევრობით), preflight (baseline TCP/10250-ის ჩათვლით) და recovery-ბრძანებები.<br/>• **სავალდებულო retest `ufw reload`-ის შემდეგ:** შეასრულეთ `sudo ufw reload` და გაიმეორეთ ყველა იგივე შემოწმება (readyz, node Ready, calico-node Ready, Pod DNS, Pod→API, worker→kubelet:10250 deny, effective UFW rule count). წესი, რომელიც enable-ის შემდეგ მხოლოდ მეხსიერებაში მუშაობს, მაგრამ reload-ს ვერ უძლებს, სწორ ამოხსნად არ ითვლება. |
| მიღების კრიტერიუმები | • **Baseline TCP/10250:** checker-owned bootstrap-baseline (დაფიქსირებულია ლაბის გაცემამდე `/var/lib/cks-lab105-checker`-ში, დირექტორია `0711 root:root` `/var/work/tests`-ის გარეთ, ფაილი `0444 root:root`) ადასტურებს TCP/10250-ის საწყის მისაწვდომობას; თქვენი საკუთარი baseline-ცდა UFW-მდე შენახულია და აჩვენებს რეალურ ქსელურ მისაწვდომობას (`CURL_EXIT=0`, HTTP `1xx-5xx`). თუ პორტი baseline-ზე უკვე მიუწვდომელია, დავალების შედეგია `inconclusive`, და არა PASS.<br/>• **UFW და წესების ზუსტი სიმრავლე:** UFW active, default-deny; `ufw show added` შეიცავს ზუსტად ხუთ სტრიქონს: loopback + `worker_ip`→`22/tcp` + `worker_ip`→`6443/tcp` + `node_ip`→`6443/tcp` + `pod_cidr`→`6443/tcp`, ნებისმიერი მოქმედების (`allow`/`deny`/`reject`/`limit`/`route`) ერთი ზედმეტი წესის გარეშე და ხუთიდან არცერთის გამოტოვების გარეშე.<br/>• **Framework-ფაილები:** `/etc/ufw/before*.rules`/`after*.rules`-ის hash არ განსხვავდება checker-owned bootstrap-baseline-ისგან (წესები ემატება მხოლოდ `ufw`-ით, framework-ფაილები ხელით არ რედაქტირდება).<br/>• **ბირთვის ფაქტობრივი მდგომარეობა:** `sudo ufw show user-rules` (რეალური `ufw-user-*` chains `iptables -L`-ით) სემანტიკურად ემთხვევა მოსალოდნელ ხუთ წესს - მოწმდება არა მხოლოდ რაოდენობა, არამედ თითოეული წესის source/interface/protocol/port, როგორც `enable`-ის, ისე `reload`-ის შემდეგ. `ufw6-user-input` რჩება ზუსტად ერთი სტრიქონით - loopback ACCEPT-ის v6-ვერსიით (`ufw allow in on lo` ქმნის როგორც v4-, ისე v6-წესს ერთდროულად, რადგან ეს წესია ინტერფეისის მიხედვით აშკარა IP-ის გარეშე; არა „სრულიად ცარიელი“). ეს იჭერს `user.rules`/`user6.rules`-ის პირდაპირ რედაქტირებას tuple metadata-ს გარეშე (არც `ufw show added`-ში ირეკლება, არც `before/after`-ის hash-ში) და უკვე დეკლარირებული წესის გაფართოებას (მაგალითად, `node_ip`→`6443/tcp`, ფარულად ჩანაცვლებული `node_ip`→`any`-ით) სტრიქონების რაოდენობის შეცვლის გარეშე.<br/>• **კლასტერის ჯანმრთელობა:** `/readyz=ok`; მოსალოდნელი node და ყველა `calico-node` Pod რჩება `Ready`; `health-probe` რჩება Ready, resolve-ს უკეთებს DNS-ს და აღწევს Kubernetes Service-ს.<br/>• **kubelet-ის დაბლოკვა:** UFW-ის შემდეგ worker kubelet `10250`-ს ვერ აღწევს (`HTTPCODE=000`, ტრანსპორტული deny) - სწორედ როგორც რეგრესი დამტკიცებულ baseline-თან მიმართებით.<br/>• **Retest reload-ის შემდეგ:** **ყველა იგივე შემოწმება ხელახლა გადის აშკარა `sudo ufw reload`-ის შემდეგ**: readyz/node/calico-node/DNS/Pod→API რჩება ჯანსაღი, worker→kubelet:10250 რჩება დაბლოკილი იმავე deny-კონტრაქტით, რაც reload-მდე, და ბირთვში წესების ფაქტობრივი რაოდენობა კვლავ ემთხვევა დეკლარაციულს.<br/>• **Artifacts:** artifact შეიცავს recovery-ბრძანებებს (`ufw disable`, შემოწმება, გასწორება და ხელახლა ჩართვა). |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

ყველაზე სახიფათო შეცდომა აქ არის `ufw enable`-ის (default-deny) ჩართვა მანამდე, სანამ worker IP-დან SSH-ისთვის allow-წესს დაამატებთ. თანმიმდევრობა უნდა იყოს: ჯერ ყველა საჭირო `ufw allow from <IP> to any port <port>`, მხოლოდ შემდეგ `ufw --force enable`. firewall-თან მუშაობის მთელი დროის განმავლობაში მიმდინარე SSH-სესია ღია გქონდეთ - თუ წვდომას დაკარგავთ, recovery-სთვის მეორე სესია ვერ დაუკავშირდება (იხ. გაფრთხილება ქვემოთ). არ დაგავიწყდეთ baseline-ცდა TCP/10250-ზე UFW-ის ჩართვამდე - მის გარეშე post-hardening „დაბლოკილია“ არაფერს ამტკიცებს: პორტი შეიძლებოდა უფრო ადრეც მიუწვდომელი ყოფილიყო სრულიად სხვა მიზეზით (მაგალითად, AWS security group), და მაშინ UFW აქ საერთოდ არაფერ შუაშია; გარდა ამისა, checker-ს აქვს თავისი საკუთარი baseline, დაფიქსირებული ლაბის გაცემამდე ცალკე დაცულ დირექტორიაში, ამიტომ ამ ჩანაწერის უკანა რიცხვით გაყალბება არ გამოვა. allow-set შეამოწმეთ მკაცრად `sudo ufw show added`-ით (და არა მხოლოდ `ufw status`-ით) - იქ უნდა იყოს ზუსტად ხუთი სტრიქონი, არცერთი ზედმეტი (არანაირი ფართო `ALLOW Anywhere`, არანაირი დამატებითი პორტი, და ეს ეხება ნებისმიერ მოქმედებას - `allow`, `deny`, `reject`, `limit`, `route`, და არა მხოლოდ ახალ allow-ებს) და არცერთი ნაკლული. firewall-ს მართეთ მხოლოდ ბრძანებით `ufw` - ხელით ნუ დაარედაქტირებთ `/etc/ufw/before*.rules`/`after*.rules`/`user.rules`/`user6.rules`-ს: framework-ფაილები hash-ით მოწმდება, ხოლო `user.rules`/`user6.rules`-ის ფაქტობრივ მდგომარეობას checker პირდაპირ ამოწმებს `ufw-user-*` chains-ში რეალური iptables-წესებით (`sudo ufw show user-rules`), ამიტომ `user.rules`-ის რედაქტირებაც კი სწორი `### tuple ###` კომენტარების გარეშე `ufw reload`-ის შემდეგ აღმოჩნდება. და არ დაგავიწყდეთ ბოლოს `sudo ufw reload`-ის შესრულება და ყველა შემოწმების გამეორება - წესი, რომელიც მხოლოდ `enable`-ის მყისვე შემდეგ მუშაობს, მაგრამ `reload`-ს ვერ უძლებს, არ ითვლება.
</details>

> **ჯერ recovery.** მიმდინარე SSH-სესია ღია გქონდეთ სრულ შემოწმებამდე. თუ API
> გაქრა, მისგან შეასრულეთ `sudo ufw disable`, გაასწორეთ allow rules და მხოლოდ შემდეგ ისევ
> ჩართეთ firewall. თუ SSH უკვე დაკარგულია, გამოიყენეთ პროვაიდერის console/recovery channel;
> ნუ სცდით სიტუაციის „განკურნებას“ ფართო `allow from any`-ით.
>
> **გამოყენების საზღვარი.** ეს UFW allowlist გათვლილია მხოლოდ ერთკვანძიან fixture-ზე.
> მისი სიტყვასიტყვით გადატანა multi-node cluster-ში არ შეიძლება: default-deny-მდე საჭიროა
> kubelet-ისა და node-თაშორისი ნაკადების, CNI overlay-ის, BGP/VXLAN/WireGuard-ის, LoadBalancer/NodePort-ისა და
> provider firewall/security groups-ის ინვენტარიზაცია კონკრეტული ტოპოლოგიისთვის.
>
> **Lab-specific exception: UFW Calico node-ზე.** Calico-ს ოფიციალური დოკუმენტაცია
> მოთხოვნების შესახებ პირდაპირ გირჩევს firewalld-ისა და სხვა iptables managers-ის გამორთვას
> Calico-ს node-ებზე, რადგან მათ შეიძლება კონფლიქტი ჰქონდეთ წესებთან, რომლებსაც თავად
> Calico აწესებს. UFW - იმავე ტიპის iptables/nftables manager-ია. ეს ლაბი განზრახ ტოვებს UFW-ს
> control-plane-ზე host firewall hardening-ის პრაქტიკისთვის (ცალკე უნარი CKS გამოცდის
> პროგრამაში), და არა როგორც Calico-ს host firewall-თან production-ში შეთავსების რეკომენდებული გზა -
> ამისთვის Calico გვთავაზობს თავის `HostEndpoint`/`GlobalNetworkPolicy`-ს. სწორედ ამიტომ დავალება
> აშკარად მოითხოვს კონტროლირებად თანმიმდევრობას baseline → `ufw enable` → retest იმის
> შემოწმებით, რომ `calico-node` და Kubernetes-ის მთელი კავშირიანობა გამართული რჩება (იხ.
> `ADVERSARIAL_ACCEPTANCE_STANDARD.md`).

---
| **4** | **kubeconfig-ის უფლებების გასწორება** |
| :---: | :--- |
| რას ვაკეთებთ | control-plane-ზე დაიცავით `/etc/kubernetes/admin.conf`, რომელიც cluster-admin credential-ს შეიცავს: მფლობელი და ჯგუფი უნდა იყოს `root:root`, რეჟიმი - `600`. |
| მიღების კრიტერიუმები | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` აბრუნებს `root root 600`-ს; იგივე მნიშვნელობა შენახულია `/var/work/tests/artifacts/4/admin-conf.txt`-ში. |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

ერთი ბრძანება ყველაფერს წყვეტს: `sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf`. მაშინვე ამის შემდეგ შეამოწმეთ თავი - თუ თავად იყენებთ ამ ფაილს როგორც `ubuntu` მომხმარებელი `KUBECONFIG=/etc/kubernetes/admin.conf`-ით, კითხვის წვდომა გაქრება, და ეს მოსალოდნელია - ყოველდღიური მუშაობისთვის გამოიყენეთ ცალკე kubeconfig.
</details>

---
| **5** | **root login-ის აკრძალვა SSH-ით** |
| :---: | :--- |
| რას ვაკეთებთ | control-plane-ზე `/etc/ssh/sshd_config`-ში დააყენეთ `PermitRootLogin no`, შეამოწმეთ სინტაქსი `sshd -t`-ით და უსაფრთხოდ გადატვირთეთ SSH. ეფექტური მნიშვნელობა სწორედ root-კავშირისთვის შეამოწმეთ ბრძანებით `sshd -T -C "user=root,addr=<თქვენი IP>,laddr=<node-ის IP>,lport=22"`, და არა უბრალოდ `sshd -T`-ით connection context-ის გარეშე. |
| მიღების კრიტერიუმები | `permitrootlogin`-ის ეფექტური მნიშვნელობა root connection context-ისთვის უდრის `no`-ს; `/var/work/tests/artifacts/5/sshd.txt` შეიცავს `PermitRootLogin no`-ს. |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

`sshd -T` აჩვენებს ეფექტურ კონფიგურაციას, მაგრამ connection context-ის (`-C`) გარეშე ნებისმიერი `Match`-ბლოკი (`Match User`/`Match Address`/`Match Group` და მსგავსი) საერთოდ არ გამოიყენება - man-გვერდი `sshd(8)` აშკარად ამბობს, რომ `Match`-წესები test mode-ში გამოიყენება "only when the connection parameters are supplied via one or more `-C` options". ამიტომ `sshd -T` `-C`-ის გარეშე შეიძლება აჩვენებდეს `permitrootlogin no`-ს კონფიგურაციის ძირითადი ბლოკიდან, მაშინ როცა უფრო სპეციფიკური `Match`-ბლოკი (მაგალითად, `Match Address <ადმინისტრატორის IP>` ან `Match User root`) root login-ს სწორედ რეალური კავშირისთვის უშვებს. შეამოწმეთ `sshd -T -C "user=root,addr=<IP>,laddr=<node-ის IP>,lport=22"`-ით - ეს ახდენს რეალური შემომავალი root-კავშირის სიმულაციას და აიძულებს `sshd`-ს გამოიყენოს ყველა შესაბამისი `Match`-ბლოკი საბოლოო მნიშვნელობის ჩვენებამდე. ყოველთვის მიმდინარე SSH-სესია ღია გქონდეთ `systemctl reload sshd`-მდე და შეამოწმეთ ახალი სესიიდან - და არა იმ სესიიდან, რომელიც ცვლილებამდე უკვე იყო ავტენტიფიცირებული.
</details>

---
| **6** | **Docker daemon-ზე არაუსაფრთხო წვდომის დახურვა `docker-host`-ზე** |
| :---: | :--- |
| რას ვაკეთებთ | • ცალკე `docker-host`-ზე შეწყვიტეთ Docker API-ს გამოქვეყნება TCP/2375-ზე: წაშალეთ `-H tcp://...` სასწავლო systemd override-იდან, მაგრამ წვდომა შეინარჩუნეთ მხოლოდ unix-სოკეტით.<br/>• გამართეთ `/var/run/docker.sock` როგორც `root:root` რეჟიმით `660`; restart-ის შემდეგ მდგრადობისთვის ეს დააყენეთ `docker.socket`-ის override-ით.<br/>• წაშალეთ `developer` ჯგუფიდან `docker`.<br/>• შესწორებების შემდეგ აუცილებლად შეასრულეთ `sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service` - ეს ადასტურებს, რომ პარამეტრები daemon-ის გადატვირთვას უძლებს, და არა უბრალოდ დროებით ემთხვევა მოსალოდნელ მდგომარეობას.<br/>• restart-ის შემდეგ დაადასტურეთ, რომ Docker რეალურად მუშაობს (`sudo docker version`), და არა უბრალოდ გაჩერებულია. |
| მიღების კრიტერიუმები | • **Docker მუშაობს restart-ის შემდეგ:** `daemon-reload` + restart-ის შემდეგ `docker.service` და `docker.socket` მდგომარეობაში `active`-ა, ხოლო `sudo docker version`/`sudo docker info` წარმატებით სრულდება (positive control - Docker რეალურად მუშაობს, და არა უბრალოდ „გამორთულია და ამიტომ 2375 დახურულია“).<br/>• **TCP API არ არის:** TCP/2375-ზე listener არ არის. restart-ის შემდეგ Docker API-ს არ აქვს არც ერთი TCP listener არც ერთ პორტზე: effective `docker.service` არ შეიცავს TCP `-H/--host`-ს, ხოლო `docker.socket` არ შეიცავს TCP `ListenStream`-ს; ერთადერთი API endpoint - Unix socket `/var/run/docker.sock`-ია.<br/>• **სოკეტი:** `stat -c '%U %G %a' /var/run/docker.sock` აბრუნებს `root root 660`-ს; persistent override `docker.service`/`docker.socket` (`systemctl cat`-ით) არ შეიცავს `-H tcp://`-ს და ადგენს `SocketGroup=root`/`SocketMode=0660`-ს.<br/>• **მომხმარებელი `developer`:** არ არის ჯგუფ `docker`-ში, ხოლო `sudo -u developer docker ps` სრულდება წვდომის შეცდომით.<br/>• **Artifacts:** შექმენით `/var/work/tests/artifacts/6/docker-tcp.txt`, `/var/work/tests/artifacts/6/docker-socket.txt`, `/var/work/tests/artifacts/6/developer-access.txt` სტრიქონებით `tcp/2375: closed`, `root root 660`, `developer docker ps: denied`. |

<details>
<summary>💡 მინიშნება დავალება 6-ისთვის</summary>

ჯგუფში `docker` წევრობა ფაქტობრივად root-ის ექვივალენტია - ნებისმიერ პროცესს `docker.sock`-ზე წვდომით შეუძლია ჰოსტის ფაილური სისტემის მიმაგრება `--privileged` container-ით. იმის დასადასტურებლად, რომ `developer` ჯგუფიდან ამოღებულია, `groups developer`-ის შემოწმება საკმარისი არ არის - ჯგუფში წევრობის ცვლილებები ახალ login-სესიებზე გამოიყენება, ამიტომ შეამოწმეთ სწორედ `sudo -u developer docker ps`-ით ახალ ბრძანებაში, და არა `developer`-ის უკვე გახსნილ სესიაში. ნუ გაჩერდებით შემოწმების პირველ წარმატებულ გაშვებაზე - შეასრულეთ `daemon-reload` და `restart` ორივე unit-ისთვის (`docker.socket`, `docker.service`) და შემოწმებები ხელახლა გაიმეორეთ: ამ ნაბიჯის გარეშე შეიძლება შემთხვევით გაიაროთ დავალება უბრალოდ Docker-ის დროებით გაჩერებით (მაშინ 2375 დახურულია არა იმიტომ, რომ `-H tcp://` ამოღებულია, არამედ იმიტომ, რომ daemon საერთოდ არ მუშაობს) - დარწმუნდით ასევე, რომ `sudo docker version` restart-ის შემდეგ მუშაობს, ეს ადასტურებს, რომ Docker რეალურად ფუნქციონირებს, და არა უბრალოდ „გამორთულია“.
</details>

---
| **7** | **გამოუყენებელი ბირთვის მოდულის ჩატვირთვის აკრძალვა (`modprobe` blacklist)** |
| :---: | :--- |
| რას ვაკეთებთ | • control-plane-ზე მოდული `sctp` ჩატვირთულია, მაგრამ ამ ლაბში არც kubeadm-ს, არც containerd-ს, არც Calico-ს არ სჭირდება. სცადეთ მისი გამოტვირთვა (`sudo modprobe -r sctp`).<br/>• **გამოტვირთვა შეიძლება არ გამოვიდეს უკვე ცოცხალ კლასტერზე, და ეს შეცდომა არ არის:** ბირთვის პროტოკოლური მოდულები იღებენ persistent per-network-namespace მითითებას ყოველი netns-ისთვის, რომელიც მათი ჩატვირთვის მომენტში არსებობდა, ხოლო ამ node-ზე უკვე მუშაობს Pod-ები (calico, coredns და ა.შ.); მათი გაჩერება დავალებაში არ შედის.<br/>• აკრძალეთ განმეორებითი ჩატვირთვა `/etc/modprobe.d/60-cks-sctp.conf`-ით დირექტივებით `blacklist sctp` და `install sctp /bin/true`.<br/>• საფრთხის მოდელის შეზღუდვები: ორივე დირექტივა მოქმედებს `modprobe`-ის დონეზე (alias resolution და dependency loading) - ეს ბირთვის აბსოლუტური დაცვა არ არის. `insmod` მოდულს პირდაპირ ტვირთავს kernel syscall-ით და `modprobe.d`-ს არ კითხულობს, ხოლო `modprobe --ignore-install`-ს შეუძლია `install` override-ის გვერდის ავლა host-level წვდომის არსებობისას. node-ის root-მფლობელისთვის ეს მოსალოდნელია: მიზანია ჩატვირთვის ჩვეულებრივი გზის აღმოფხვრა (`modprobe sctp`, alias-ით ავტოჩატვირთვა protocol-ზე მიმართვისას), და არა მომხმარებლისგან დაცვა, რომელსაც node-ზე უკვე აქვს root.<br/>• დაადასტურეთ, რომ `modprobe --show-config` აჩვენებს ეფექტურ override-ს და რომ პირდაპირი `modprobe sctp` მოდულის მდგომარეობას არ ცვლის. |
| მიღების კრიტერიუმები | • **ფაილი:** `/etc/modprobe.d/60-cks-sctp.conf` შეიცავს ორივე სტრიქონს `blacklist sctp` და `install sctp /bin/true`.<br/>• **ეფექტური კონფიგი:** `modprobe --show-config \| grep sctp` აჩვენებს `install sctp /bin/true`-ს.<br/>• **მოდულის მდგომარეობა:** პირდაპირი განმეორებითი `modprobe sctp` მოდულის მდგომარეობას არ ცვლის (იყო ჩატვირთული - დარჩა ჩატვირთული, არ იყო ჩატვირთული - დარჩა ჩაუტვირთავი).<br/>• **Artifact:** `/var/work/tests/artifacts/7/sctp.txt` შეიცავს სტრიქონს `lsmod: absent` ან `lsmod: present` (ორიდან ნებისმიერი - რეალური მიმდინარე მდგომარეობა) და სტრიქონს `install sctp /bin/true`. |

<details>
<summary>💡 მინიშნება დავალება 7-ისთვის</summary>

მხოლოდ `blacklist sctp` ყველაფერს არ ბლოკავს - ის ხელს უშლის ავტოჩატვირთვას alias resolution-ით, მაგრამ პირდაპირი `modprobe sctp` `install`-override-ის გარეშე მაინც იმუშავებს. საჭიროა ორივე სტრიქონი: `blacklist` ავტოჩატვირთვისთვის, `install sctp /bin/true` `modprobe sctp`-ის აშკარა გამოძახებისთვის (ჩატვირთვის ბრძანებას no-op-ით ანაცვლებს). სცადეთ `sudo modprobe -r sctp` უკვე ჩატვირთული მოდულის გამოსატვირთად, მაგრამ თუ მიიღებთ `FATAL: Module sctp is in use`-ს ცარიელი `/sys/module/sctp/holders`-ით - ეს ცოცხალ კლასტერზე მოსალოდნელია (per-netns pinning უკვე გაშვებული Pod-ებისგან) და დავალების გავლას ხელს არ უშლის; კონფიგი მაინც ხელს უშლის მომავალ ჩატვირთვებს, რაც სწორედ მოწმდება.
</details>

---
| **8** | **`protectKernelDefaults` და უსაფრთხო sysctl kubelet-ისთვის** |
| :---: | :--- |
| რას ვაკეთებთ | • control-plane-ზე ახლა `kernel.unprivileged_bpf_disabled = 0` - არაპრივილეგირებულ პროცესებს შეუძლიათ eBPF პროგრამების ჩატვირთვა, რაც kernel attack surface-ს აფართოებს. გაასწორეთ ეს.<br/>• დაამატეთ `vm.overcommit_memory = 1` (ტიპური რეკომენდაცია kubelet/containerd-ის სტაბილურობისთვის memory pressure-ის ქვეშ).<br/>• ორივე პარამეტრი მიუთითეთ `/etc/sysctl.d/99-kubernetes.conf`-ით, შემდეგ გამოიყენეთ `sudo sysctl --system`.<br/>• ჩართეთ `protectKernelDefaults: true` `/var/lib/kubelet/config.yaml`-ში და გადატვირთეთ kubelet.<br/>• **თანმიმდევრობა მნიშვნელოვანია:** `true`-ს დროს kubelet გაშვებისას ამოწმებს, რომ მიმდინარე kernel/cgroup parameters შეესაბამება მოსალოდნელ defaults-ს და **არ გაეშვება**, თუ ისინი არ ემთხვევა - ამიტომ sysctl უნდა გამოყენებულ იქნას **kubelet-ის გადატვირთვამდე**, და არა შემდეგ. |
| მიღების კრიტერიუმები | • **Live-მნიშვნელობები:** `sysctl kernel.unprivileged_bpf_disabled` აბრუნებს `1`-ს; `sysctl vm.overcommit_memory` აბრუნებს `1`-ს.<br/>• **Persistent-კონფიგურაცია:** `/etc/sysctl.d/99-kubernetes.conf` შეიცავს ორივე პარამეტრს როგორც აქტიურ სტრიქონებს (`kernel.unprivileged_bpf_disabled = 1`, `vm.overcommit_memory = 1`); კომენტარი, `= 1 # comment` ან დროებითი `sysctl -w` არ ითვლება.<br/>• **kubelet:** kubelet-ის მოქმედი კონფიგურაცია (`/api/v1/nodes/<node>/proxy/configz`) შეიცავს `protectKernelDefaults: true`-ს.<br/>• **მდგომარეობა გადატვირთვის შემდეგ:** `systemctl is-active kubelet` აბრუნებს `active`-ს, ხოლო node რჩება `Ready`. |

<details>
<summary>💡 მინიშნება დავალება 8-ისთვის</summary>

თანმიმდევრობა აქ კრიტიკულია და განზრახ არის ხაზგასმული დავალების აღწერაში: ჯერ `sysctl --system` (მნიშვნელობების გამოყენება), მხოლოდ შემდეგ `protectKernelDefaults: true`-ის ჩართვა და kubelet-ის გადატვირთვა. თუ საპირისპირო თანმიმდევრობით გააკეთებთ, kubelet გაშვებისას აღმოაჩენს kernel parameters-ის შეუსაბამობას თავის მოლოდინებთან და გაშვებაზე უარს იტყვის - node დარჩება NotReady, და მიზეზს kubelet logs-ის წაკითხვის გარეშე ვერ გაიგებთ (`journalctl -u kubelet`). შემოწმება ეყრდნობა kubelet-ის რეალურად მოქმედ კონფიგურაციას `kubectl get --raw="/api/v1/nodes/<node>/proxy/configz"`-ით, და არა `config.yaml`-ის ტექსტს - თუ ფაილში სტრიქონი დაკომენტარებულია ან შეიცავს ბეჭდვის შეცდომას, `grep`-ს მაინც შეეძლო მისი პოვნა, მიუხედავად იმისა, რომ kubelet ძველი ნაგულისხმევი მნიშვნელობით აგრძელებს მუშაობას. ფაილის შესწორების შემდეგ აუცილებლად გადატვირთეთ kubelet და შეამოწმეთ სწორედ `configz`-ით.
</details>

---
| **9** | **ზედმეტი SUID-binary-ის პოვნა და განეიტრალება** |
| :---: | :--- |
| რას ვაკეთებთ | • control-plane-ზე შეასრულეთ `find / -xdev -perm -4000 -type f 2>/dev/null` და შედეგებს შორის იპოვეთ `/usr/local/bin/cks-lab105-suid-tool` - სასწავლო binary, სპეციალურად შექმნილი SUID-ბიტით და ამ node-ზე Kubernetes-ის არც ერთი კომპონენტისთვის არასაჭირო.<br/>• შეინახეთ ნაპოვნი SUID-ფაილების სრული სია **გასწორებამდე** `/var/work/tests/artifacts/9/suid-before.txt`-ში.<br/>• მოხსენით binary-ს SUID-ბიტი (`chmod u-s`).<br/>• შეინახეთ `cks-lab105-suid-tool`-ის რეჟიმი **გასწორების შემდეგ** `/var/work/tests/artifacts/9/suid-after.txt`-ში.<br/>• სისტემურ SUID-binary-ებს ნუ შეეხებით (`passwd`, `sudo`, `mount` და მსგავსი): მათი წაშლა არღვევს ოპერაციული სისტემის ნორმალურ მუშაობას და დავალების ფარგლებში არ შედის. |
| მიღების კრიტერიუმები | • **გასწორებამდე:** `suid-before.txt` შეიცავს გზას `/usr/local/bin/cks-lab105-suid-tool` ნაპოვნ SUID-ფაილებს შორის.<br/>• **გასწორების შემდეგ:** `stat -c '%a' /usr/local/bin/cks-lab105-suid-tool` აბრუნებს `755`-ს (SUID-ბიტის `4`-ის გარეშე); `suid-after.txt` შეიცავს `755`-ს.<br/>• **სისტემური binary-ები:** სტანდარტული SUID-binary-ები (მაგალითად, `/usr/bin/sudo` ან `/usr/bin/passwd`) რჩება SUID-ბიტით ხელუხლებელი. |

<details>
<summary>💡 მინიშნება დავალება 9-ისთვის</summary>

`chmod u-s` მოხსნის სწორედ SUID-ბიტს, დანარჩენ უფლებებს არ ეხება (`chmod 755`-ისგან განსხვავებით, რომელიც ასევე გადაწერს უფლებების ყველა სხვა ბიტს - ამ შემთხვევაში შედეგი ემთხვევა, მაგრამ `u-s` უფრო უსაფრთხოა როგორც ზოგადი ჩვევა). `find / -perm -4000`-ს `-xdev`-ის გარეშე ნუ გაუშვებთ აუცილებლობის გარეშე - მის გარეშე ბრძანება დაასკანერებს მიმაგრებულ ქსელურ/ვირტუალურ ფაილურ სისტემებს და შეიძლება ძალიან დიდხანს შესრულდეს ან გაიჭედოს. შემოწმება ადარებს სისტემური SUID-binary-ების მიმდინარე ნაკრებს baseline-თან, რომელიც ლაბის დაწყებამდე იყო დაფიქსირებული - ნებისმიერი სხვა სისტემური SUID-binary-ის შეხება (არა მხოლოდ `sudo`/`passwd`-ის) აკრძალულია, და უბრალოდ `sudo`-ზე SUID-ის დაბრუნება არ დაგეხმარებათ, თუ შემთხვევით (ან განზრახ) რაიმე სხვას მოუხსენით. გზები `/var/lib/containerd`-ის შიგნით (container image-ის ფენები overlayfs-ით) არც baseline-შია გათვალისწინებული, არც შემოწმებაში - ეს ჰოსტის ფაილები არ არის და მათი ნაკრები image-ების pull/extract-ისას ბუნებრივად იცვლება თქვენგან დამოუკიდებლად.
</details>

---
| **10** | **Core dumps-ის გამორთვა და SUID-პროცესების მეხსიერების დამპისგან დაცვა** |
| :---: | :--- |
| რას ვაკეთებთ | • პროცესის core dump შეიძლება შეიცავდეს გაშიფრულ secrets-ს, პირად გასაღებებს და token-ებს, რომლებიც crash-ის მომენტში მეხსიერებაში იყო.<br/>• control-plane-ზე დაამატეთ `/etc/security/limits.conf`-ში სტრიქონები `* hard core 0` და `* soft core 0` (core dump-ის ზომის შეზღუდვა).<br/>• აკრძალეთ dump SUID/privileged-პროცესებისთვის: `fs.suid_dumpable = 0` `/etc/sysctl.d/99-kubernetes.conf`-ში (იგივე ფაილი, რაც დავალება 8-ში - ცალკე კონფლიქტურ ფაილს ნუ შექმნით).<br/>• **Ubuntu-ზე ეს საკმარისი არ არის:** crash dump ნაგულისხმევად ფაილში პირდაპირ არ გადაეცემა, არამედ `kernel.core_pattern`-ით, რომელიც userspace pipe handler-ზე (Apport) მიუთითებს. Apport crash-ს `/var/lib/apport/coredump/`-ში იჭერს `ulimit -c`-ის მიუხედავად, რადგან `RLIMIT_CORE`-ს ბირთვი სწორედ pipe-handler-ებისთვის უგულებელყოფს (იხ. `man 5 core`: "RLIMIT_CORE will be ignored if the system is configured to pipe core dumps to a program").<br/>• ამიტომ დამატებით დააყენეთ `kernel.core_pattern = \|/bin/false` იმავე `/etc/sysctl.d/99-kubernetes.conf`-ში - ეს pipe-handler-ს განზრახ არამომუშავე handler-ით ანაცვლებს, და ბირთვი dump-ს არც ფაილში ქმნის, არც Apport-ით. გამოიყენეთ `sudo sysctl --system`.<br/>• დაადასტურეთ: `sysctl fs.suid_dumpable` აბრუნებს `0`-ს, ხოლო `cat /proc/sys/kernel/core_pattern` აბრუნებს `\|/bin/false`-ს.<br/>• დაადასტურეთ: ახალი login-shell (`bash -l` ან `sudo su - ubuntu -c 'ulimit -c'` - სწორედ `sudo`-ით, ჩვეულებრივი `su` საკუთარ თავზე მაინც პაროლს მოითხოვს) `ulimit -c`-ს აჩვენებს `0`-ის ტოლს.<br/>• დაადასტურეთ: საცდელი პროცესის რეალური crash-ის (`SIGSEGV`) შემდეგ ახალი core dump არც `/var/lib/apport/coredump/`-ში ჩნდება, არც სხვაგან. |
| მიღების კრიტერიუმები | • **Live-მნიშვნელობები:** `sysctl -n fs.suid_dumpable` აბრუნებს `0`-ს; `cat /proc/sys/kernel/core_pattern` აბრუნებს `\|/bin/false`-ს.<br/>• **Persistent sysctl:** `/etc/sysctl.d/99-kubernetes.conf` შეიცავს აქტიურ (დაუკომენტარებელ) სტრიქონებს `fs.suid_dumpable = 0` და `kernel.core_pattern = \|/bin/false`.<br/>• **ლიმიტები:** `/etc/security/limits.conf` შეიცავს ორივე სტრიქონს `* hard core 0` და `* soft core 0`; ახალი login-shell აჩვენებს `ulimit -c`-ს `0`-ის ტოლს.<br/>• **Crash probe:** საცდელი პროცესის controlled crash ახალ retained core dump-ს არ ქმნის.<br/>• **Artifact:** `/var/work/tests/artifacts/10/coredump.txt` შეიცავს ყველა დადასტურებას, controlled crash probe-ის შედეგის ჩათვლით. |

<details>
<summary>💡 მინიშნება დავალება 10-ისთვის</summary>

`ulimit -c` თქვენს მიმდინარე SSH-სესიაში `limits.conf`-ის რედაქტირების შემდეგ არ შეიცვლება - PAM-ლიმიტები გამოიყენება მხოლოდ ახალი სესიის/login-shell-ის შექმნისას. შეამოწმეთ `sudo su - ubuntu -c 'ulimit -c'`-ით (ახალი login; `sudo` სავალდებულოა - `su` საკუთარ თავზეც კი ყოველთვის პაროლს ითხოვს, თუ root-იდან არ არის გამოძახებული) ან გახსენით ახალი SSH-სესია, და `ulimit -c`-ს ნუ შეამოწმებთ იმავე shell-ში, სადაც ფაილი დაარედაქტირეთ. ორივე მნიშვნელობაა საჭირო: `hard` - აბსოლუტური ჭერია, `soft` - მოქმედი ნაგულისხმევი მნიშვნელობა; თუ მხოლოდ `soft`-ს დააყენებთ, პროცესს შეუძლია ლიმიტი თავად აიყვანოს `hard`-მდე. დავალების მთავარი ხაფანგი: `ulimit -c 0` და `fs.suid_dumpable=0` Ubuntu-ზე core dump-ს თავისთავად **არ თიშავს** - `man 5 core` პირდაპირ ამბობს, რომ `RLIMIT_CORE`-ს ბირთვი უგულებელყოფს, თუ `kernel.core_pattern` pipe-handler-ზე მიუთითებს (`|program`), ხოლო Ubuntu ნაგულისხმევად crash-ს სწორედ ასეთ handler-ში (Apport) მიმართავს, რომელიც dump-ს `ulimit`-ის მიუხედავად იჭერს. ერთადერთი საიმედო გზა - თავად `kernel.core_pattern`-ის გადაფარვაა (მაგალითად, `|/bin/false`-ზე), და არა მხოლოდ პროცესის ლიმიტებისა.
</details>

## დამატებით: kernel და containerd/CRI hardening

ეს მოკლე node-local პრაქტიკაა 7–9 დავალებაზე დამატებით, რომელიც fixture-ის ავტომატურ კრიტერიუმებში არ შედის.
ის აჩვენებს CRI-ის უფრო ფართო კონტექსტს, რომელიც ბირთვის კონკრეტული მოდულით არ შემოიფარგლება.

ამ ლაბში Kubernetes იყენებს **containerd**-ს, და არა Docker-ს. ამიტომ იგივე პრინციპები
CRI-ზეც უნდა გამოიყენოთ: შეამოწმეთ `/run/containerd/containerd.sock`-ისა და
`/etc/containerd/config.toml`-ის უფლებები, ჩვეულებრივ მომხმარებლებს ნუ დაამატებთ ჯგუფში, რომელიც სოკეტზე წვდომას აძლევს,
და `ctr`/`crictl`-ის ამ endpoint-თან გამოყენება მხოლოდ პრივილეგირებულ
ადმინისტრატორებს დაუშვით. მომუშავე CRI-სოკეტის მფლობელს ან რეჟიმს ბრმად ნუ შეცვლით: არასწორი
გამართვა kubelet-სა და workload-ს გააჩერებს.

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# მოსალოდნელია წვდომის უარყოფა არაპრივილეგირებული მომხმარებლისთვის
```

## შედეგის შემოწმება

`worker`-ზე შეასრულეთ:

```bash
check_result
```

შემოწმება შეიცავს `0 Init`-ს და ათ დამოუკიდებელ ტესტს. ის ამოწმებს ორივე
ჰოსტის მდგომარეობას SSH-ით და სავალდებულო artifacts-ს. `sshd_config`-ის ან systemd unit-ის შესწორების შემდეგ
დაელოდეთ `systemctl reload/restart`-ის დასრულებას, სანამ შემოწმებას ხელახლა გაუშვებთ.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD).

## წაშლა

```bash
TASK=105 make delete_cks_task
```
