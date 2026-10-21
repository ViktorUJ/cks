[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 112 - Runtime: Falco, audit-ლოგები და უცვლელი root filesystem

## მიზანი

ამ CKS-ლაბში თქვენ გაამართავთ runtime-მოვლენების კონტროლს node-ზე და control plane-ის API-ის audit-ლოგირებას,
შემდეგ კი workload-ს რანტაიმში უცვლელს გახდით. მუშაობა ერთ node-ზე მიდის:
`control-plane` ერთდროულად workload-node-ია, ამიტომ Falco ხედავს მოვლენებს
სატესტო Pod-ებიდან, ხოლო kube-apiserver static Pod manifest-შია.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რატომ არ შეიძლება Kubernetes-ის audit log Falco-ს შემცვლელი იყოს runtime-აღმოჩენისთვის?</summary>

Audit log წერს REQUEST-დონის მოვლენებს API server-ისკენ (ვინ, რა და როდის მოითხოვა `kubectl`-ით/API-ით) - ეს evidence-ია control plane-ის დონეზე. Falco კი აკვირდება სისტემურ გამოძახებებს (syscalls) node-ზე მომუშავე კონტეინერების შიგნით - მაგალითად, shell-ის გახსნას, პროცესის spawn-ს, ფაილში ჩაწერას. მოქმედება ტიპის `docker exec`/`crictl exec` ან პირდაპირი გაშვება `ctr`-ით node-ზე Kubernetes API-ს საერთოდ არ გაივლის და audit log-ში არ მოხვდება, მაგრამ Falco-ს syscall-მოვლენის სახით დაუნახავს.
</details>

<details>
<summary>2. რა განსხვავებაა audit-პოლიტიკის `RequestResponse` და `Metadata` დონეებს შორის, და რატომ არის Secret-ისთვის საჭირო სწორედ `Metadata`?</summary>

`RequestResponse` წერს მოთხოვნისა და პასუხის სრულ სხეულს, რესურსის შიგთავსის ჩათვლით. `Metadata` წერს მხოლოდ მოთხოვნის მეტამონაცემებს (ვინ, როდის, რომელი რესურსი, რომელი verb) სხეულის გარეშე. `secrets`-ისთვის ეს კრიტიკულია: `RequestResponse` ჩაწერდა თავად secret-ის მნიშვნელობას (base64-encoded, მაგრამ მაინც მგრძნობიარე მონაცემები) audit log-ში დისკზე წასაკითხი ფაილის სახით - ეს ქმნის გაჟონვის ახალ ზედაპირს. `Metadata` იძლევა forensic-კვალს ("ვინ წაიკითხა ეს Secret და როდის") თავად secret-ის ლოგში კოპირების გარეშე.
</details>

<details>
<summary>3. რატომ არ არის `readOnlyRootFilesystem: true` ტოლფასი კონტეინერის რანტაიმში კომპრომეტაციისგან სრული დაცვისა?</summary>

`readOnlyRootFilesystem` ბლოკავს კონტეინერის root ფაილურ სისტემაში ჩაწერას, რაც აფერხებს თავდამსხმელს აპლიკაციის binary-ების შეცვლაში ან კონტეინერის დისკზე persistence-ის დაყენებაში. მაგრამ ეს ხელს **არ** უშლის: (ა) writable volumes/emptyDir-ს, რომლებსაც Pod თავად აშკარად ამაგრებს (მაგალითად `/tmp`), (ბ) პროცესის მეხსიერებაში მოქმედებების შესრულებას (RCE დისკზე ჩაწერის გარეშე), (გ) ქსელურ შეტევებს კონტეინერის შიგნიდან, (დ) უკვე მიმაგრებული Secret/ConfigMap-ების წაკითხვას. rootfs-ის იმუტაბელობა - დაცვის ერთი ფენაა, და არა სრული იზოლაცია.
</details>

## კავშირი კურსთან

- [თავი 29. ქცევითი ანალიზი შესრულების დროს: Falco](../../course/29/ge.md)
- [თავი 30. საფრთხეების აღმოჩენა და შეტევის ფაზების გამოძიება](../../course/30/ge.md)
- [თავი 31. კონტეინერების იმუტაბელობა runtime-ში](../../course/31/ge.md)
- [თავი 32. Kubernetes-ის audit-ლოგები](../../course/32/ge.md)
- [თავი 26. რეესტრები, ხელმოწერა და artifacts-ის ვალიდაცია](../../course/26/ge.md) - დავალება 9 აკავშირებს registry allowlist-ის admission-კონტროლს runtime-აღმოჩენასთან შემოვლისას (და არა signature verification-თან - მას ლაბ 111 ამოწმებს).

## ინფრასტრუქტურა

| კომპონენტი | დანიშნულება |
|---|---|
| `k8s-1` | ერთკვანძიანი Kubernetes `1.36.0`, containerd და Calico; node-ის სახელი `control-plane` |
| `worker` | სამუშაო მანქანა `kubectl`-ით, `check_result`-ით და SSH-წვდომით `ssh control-plane` |
| `runtime-112` | მომზადებული namespace; მასში უკვე არის Secret `audit-secret` |

Bootstrap განზრახ **არ** აყენებს Falco-ს და **არ** რთავს audit backend-ს. ის მხოლოდ
ამზადებს დირექტორიას `/etc/kubernetes/audit`, ლოგების დირექტორიას
`/var/log/kubernetes/audit` და Secret-ს კონტროლირებადი API-მოთხოვნისთვის. CNI-ს,
კლასტერის ვერსიას, Secret-ს ან Kubernetes-manifest-ებს დავალება 4-ის გარეთ ნუ შეცვლით.

## განთავსება

```bash
TASK=112 make run_cks_task
```

სამუშაო მანქანაზე:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## როგორ ვიმუშაოთ node-თან

გახსენით ორი ტერმინალი: **ტერმინალი 1** - `ssh control-plane`, შემდეგ `sudo -i` (ოპერაციები node-ზე:
Falco, audit, `crictl`, `/proc`), **ტერმინალი 2** - სამუშაო მანქანა (`kubectl`, `scp`, შემოწმებები).
Artifacts, node-ზე მიღებული, შეინახეთ ფაილში `control-plane`-ზე და დააკოპირეთ სამუშაო მანქანაზე
ბრძანებით `scp` `/var/work/tests/artifacts/<დავალების ნომერი>/`-ში.

## დავალებები

containment-მდე სასარგებლოა blast radius-ის გონებრივად შეფასება: შეუძლია თუ არა კომპრომეტირებული Pod-ის ServiceAccount-ს
Secrets-ის წაკითხვა, workload-ის შექმნა ან სხვა namespace-ებამდე მიღწევა. ამის სწრაფად შემოწმება შეიძლება და ღირს
`kubectl auth can-i`-ით ServiceAccount `falco-shell`-ის სახელით, როგორც დამატებითი ნაბიჯი; ის არ არის სავალდებულო, გავლენას არ ახდენს
მიღების კრიტერიუმებზე და არ ტესტირდება.

---
| **1** | **Falco-ს დაყენება და გაშვება workload-node-ზე** |
| :---: | :--- |
| რას ვაკეთებთ | • `control-plane`-ზე დააყენეთ Falco-ს პაკეტი Falco-ს ოფიციალური repository-დან და გაუშვით სერვისი.<br/>• გამოიყენეთ modern eBPF engine; kernel module ხელით ნუ დააყენებთ.<br/>• ჩართეთ სერვისი systemd-ით. |
| მიღების კრიტერიუმები | • `falco --version` სრულდება<br/>• `systemctl is-active falco` აბრუნებს `active`-ს<br/>• კონფიგურაცია შეიცავს `engine.kind: modern_ebpf`-ს |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

Modern eBPF engine გამოიყენება `engine.kind: modern_ebpf`-ით `/etc/falco/falco.yaml`-ში (და არა ცალკე kernel module driver-ით, რომელიც legacy engine-ს სჭირდება) - თუ დაყენების შემდეგ Falco არ ეშვება ან გაშვებისას ვარდება, შეამოწმეთ `journalctl -u falco-modern-bpf` (პაკეტი აყენებს unit `falco-modern-bpf.service`-ს, ხოლო `falco.service` მხოლოდ alias-ია მასზე: `systemctl status/restart falco` მუშაობს, მაგრამ `journalctl -u falco` ცარიელია) eBPF program-ის ჩატვირთვის შეცდომებისთვის, რაც შეიძლება შეუთავსებელ ბირთვზე მიუთითებდეს.
</details>

---
| **2** | **კონტეინერში სტანდარტული shell-მოვლენის დაფიქსირება** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით `runtime-112`-ში Pod `falco-shell` `busybox:1.36`-დან, დატოვეთ ის Running (`sleep 3600`) და ჩართეთ `stdin: true`, `tty: true`.<br/>• გახსენით მასში ინტერაქტიული `/bin/sh` და დაელოდეთ Falco-ს წესს **Terminal shell in container**.<br/>• შეინახეთ შესაფერისი სტრიქონი Falco-ს journal-იდან (ის იკითხება `control-plane`-ზე) ფაილში node-ზე და დააკოპირეთ `scp`-ით `/var/work/tests/artifacts/2/falco-shell.log`-ში სამუშაო მანქანაზე. |
| მიღების კრიტერიუმები | • Pod `falco-shell` Running-ია<br/>• Artifact არაცარიელია და შეიცავს alert-ის სტრიქონს `A shell was spawned in a container with an attached terminal` (ასე ბეჭდავს წესი **Terminal shell in container** მოვლენას Falco 0.45-ის ტექსტურ გამოტანაში; წესის სახელი მხოლოდ JSON-გამოტანაშია)<br/>• მოვლენა უნდა მიიღოს Falco-მ, და არა ხელით ჩაიწეროს |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

უბრალოდ Pod-ის შექმნა `stdin: true, tty: true`-ით საკმარისი არ არის - საჭიროა ინტერაქტიული სესიის რეალურად გახსნა (`kubectl exec -it falco-shell -- /bin/sh`), რომ Falco-მ სწორედ კონტეინერის შიგნით shell-პროცესის spawn დააფიქსიროს. მოვლენა მოძებნეთ `journalctl -u falco-modern-bpf --no-pager | grep "shell was spawned"`-ით `control-plane`-ზე (worker-იდან SSH-ით), და სტრიქონს ფაილში ხელით ჩაწერას ნუ ცდილობთ - ტესტი ელოდება journal-იდან რეალურ timestamp-ს/ფორმატს.
</details>

---
| **3** | **custom Falco rule-ის დამატება და გამოძახება** |
| :---: | :--- |
| რას ვაკეთებთ | • `control-plane`-ზე დაამატეთ `/etc/falco/falco_rules.local.yaml`-ში წესი სახელით `CKS112 Custom Shell Marker`.<br/>• ის უნდა იჭერდეს spawned process-ს კონტეინერში, რომლის `proc.cmdline` შეიცავს `CKS112_CUSTOM_EVENT`-ს.<br/>• მან უნდა გამოიტანოს ზუსტი ფრაზა `CKS112 custom shell marker` `container=%container.id`, `pid=%proc.pid`, `ppid=%proc.ppid`, `user=%user.name` და `command=%proc.cmdline`-თან ერთად.<br/>• გადატვირთეთ Falco.<br/>• გაუშვით `falco-shell`-ში ნებისმიერი მოკლე ბრძანება, რომლის ბრძანების ხაზში marker არის, მაგალითად: `kubectl exec -n runtime-112 falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT'`.<br/>• იპოვეთ Falco-ს journal-ში `control-plane`-ზე ამ გააქტიურების სტრიქონი (მასში არის `CKS112 custom shell marker`), შეინახეთ ის ფაილში node-ზე და დააკოპირეთ `scp`-ით `/var/work/tests/artifacts/3/falco-custom.log`-ში. სტრიქონი უნდა იყოს journal-ის ნამდვილი სტრიქონი, ხელით დაწერილი არ მიიღება. |
| მიღების კრიტერიუმები | • ლოკალური rules-ფაილი არსებობს, შეიცავს წესის სახელს, marker-ის პირობას და გამოძიების იდენტიფიკატორებს<br/>• Falco-ს სერვისი აქტიურია<br/>• ნამდვილი journal-artifact შეიცავს marker-ს, container ID-სა და PID-ს |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

Custom rule `falco_rules.local.yaml`-ში მოითხოვს `condition`-ს, რომელიც იყენებს `spawned_process`-ს (ან `evt.type=execve`-ს) `proc.cmdline contains "CKS112_CUSTOM_EVENT"`-თან ერთად - მოვლენის ტიპის საბაზო პირობის გარეშე წესი შეიძლება საერთოდ არ გააქტიურდეს ან არასწორ მოვლენებზე გააქტიურდეს. ფაილის შესწორების შემდეგ შეასრულეთ `systemctl restart falco` წესების გამოყენების დეტერმინირებული დადასტურებისთვის. აქტუალურ Falco-შიც შესაძლებელია ავტომატური reload ჩართული `watch_config_files: true`-ის დროს, მაგრამ ამ ლაბში აშკარა restart გამოიყენება.
</details>

---
| **4** | **audit-ლოგირების ჩართვა: RequestResponse ConfigMap-ისთვის, Metadata Secret-ისთვის** |
| :---: | :--- |
| რას ვაკეთებთ | • `control-plane`-ზე შექმენით `/etc/kubernetes/audit/policy.yaml`. Policy-მ უნდა ჩაწეროს `RequestResponse` **მხოლოდ namespace `runtime-112`-ში** core resource `configmaps`-ისთვის (კონტროლირებადი forensic-მაგალითი არამგრძნობიარე რესურსზე).<br/>• core resource `secrets`-ისთვის გამოიყენეთ მხოლოდ `Metadata`, **რათა Secret-ის სხეული ჟურნალში არ მოხვდეს**.<br/>• რეალურად შეამცირეთ ხმაური აშკარა `None` rules-ით high-volume/low-risk ტრაფიკისთვის და `omitStages: [RequestReceived]`-ით.<br/>• policy დაასრულეთ უსაფრთხო catch-all `Metadata`-თი როგორც *fallback logging*, და არა როგორც ხმაურის ჩახშობით.<br/>• static manifest-ში `/etc/kubernetes/manifests/kube-apiserver.yaml` დაამატეთ `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` და როტაცია (`--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`).<br/>• დაამატეთ საჭირო hostPath volume/volumeMount policy-დირექტორიისა და ლოგების დირექტორიისთვის. დაელოდეთ API-ს აღდგენას.<br/>• შექმენით ConfigMap `audit-config` `runtime-112`-ში, წაიკითხეთ ის (`kubectl get configmap audit-config -n runtime-112 -o json`) და შეინახეთ RequestResponse event `/var/work/tests/artifacts/4/configmap-request-response.json`-ში.<br/>• შემდეგ წაიკითხეთ `kubectl get secret audit-secret -n runtime-112 -o json` და შეინახეთ მისი Metadata event `/var/work/tests/artifacts/4/secret-metadata.json`-ში. Events მიიღება audit log-იდან `control-plane`-ზე: შეინახეთ ისინი node-ზე და დააკოპირეთ `scp`-ით. |
| მიღების კრიტერიუმები | • Kube-apiserver healthy-ა<br/>• Static manifest შეიცავს ორივე audit-ფლაგს და მიმაგრებებს<br/>• Policy ადგენს `RequestResponse`-ს `configmaps`-ისთვის და `Metadata`-ს `secrets`-ისთვის<br/>• `/var/work/tests/artifacts/4/configmap-request-response.json`-ში - RequestResponse event-ია ConfigMap-ისთვის<br/>• `/var/work/tests/artifacts/4/secret-metadata.json`-ში - Secret-ის მოვლენა დონით `Metadata` **ველების `requestObject`/`responseObject`-ის გარეშე** (Secret-ის სხეული არ არის დალოგილი) |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

წესების თანმიმდევრობას audit policy-ში მნიშვნელობა აქვს: Kubernetes იყენებს პირველ შესაფერის წესს ზემოდან ქვემოთ, ამიტომ სპეციფიკური წესი `configmaps`/`secrets`-ისთვის `runtime-112`-ში უნდა იდგეს ფაილის ბოლოს ზოგადი catch-all `Metadata`-ს ადრე - თუ catch-all პირველია, ის სპეციფიკურ წესებზე ადრე "დაიჭერს" ყველა მოთხოვნას. static manifest-ის რედაქტირების შემდეგ kubelet თავად აიღებს ცვლილებებს (`kubectl apply`/restart არ არის საჭირო) - მაგრამ გაგრძელებამდე დაელოდეთ, სანამ `kubectl get --raw=/readyz` ისევ წარმატებას დააბრუნებს.
</details>

---
| **5** | **Pod-ის შექმნა root filesystem-ით მხოლოდ წასაკითხად** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით `runtime-112`-ში Pod `immutable-app`: კონტეინერი `app`, image `busybox:1.36`, `sleep 3600`.<br/>• კონტეინერზე ჩართეთ `securityContext.readOnlyRootFilesystem: true`.<br/>• შექმენით `emptyDir` `writable-tmp` და მიამაგრეთ ის `/tmp`-ზე `readOnly: true`-ის გარეშე. `hostPath` ნუ გამოიყენებთ.<br/>• დაამტკიცეთ, რომ `touch /cks-112-write-denied` წარუმატებელია, ხოლო `touch /tmp/allowed` - წარმატებული; უარის შედეგი შეინახეთ `/var/work/tests/artifacts/5/rootfs-write-denied.log`-ში. |
| მიღების კრიტერიუმები | • Pod Running-ია<br/>• Root filesystem read-only-ა<br/>• `/tmp` - writable `emptyDir`-ია<br/>• Pod-ში `hostPath` არ არის<br/>• rootfs-ში ჩაწერა იბლოკება, `/tmp`-ში დაშვებულია<br/>• Artifact არაცარიელია |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

შეინახეთ სწორედ ბრძანების `touch /cks-112-write-denied` შეცდომის გამოტანა (`Read-only file system` stderr-ში), და არა უბრალოდ ის ფაქტი, რომ ბრძანება არანულოვანი კოდით დასრულდა - ტესტი ამოწმებს ლოგის შიგთავსს. `emptyDir` (ეფემერული, Pod-თან ერთად ცოცხლობს) `hostPath`-თან (node-ზე მუდმივი, ამ დავალებაში აკრძალული) ნუ აგრევთ - ორივე ტექნიკურად "წყვეტს" writable-დირექტორიის ამოცანას, მაგრამ აქ მხოლოდ პირველია დაშვებული.
</details>

---
| **6** | **containment-ის მინიმალური ჯაჭვი alert-იდან იზოლაციამდე** |
| :---: | :--- |
| რას ვაკეთებთ | • audit backend-ის ჩართვის შემდეგ გაუშვით `falco-shell`-ში კონტროლირებადი დიდხანს მცხოვრები პროცესი, რომლის ბრძანების ხაზში არის `CKS112_CUSTOM_EVENT`, მაგალითად: `kubectl exec -n runtime-112 falco-shell -- sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT &`. პროცესი 10 წუთი ცოცხლობს: სანამ ცოცხალია, შეიძლება მისი `/proc/<PID>`-ის გადაღება.<br/>• **გამოძიება დაიწყეთ ახალი Falco alert-ით**, და არა Pod manifest-ით. alert-იდან ამოიღეთ short container ID და host PID.<br/>• `control-plane`-ზე `crictl ps/inspect/inspectp`-ით შეადარეთ container → Pod sandbox → namespace/Pod; Kubernetes API-ით განსაზღვრეთ node. შეინახეთ `crictl inspect` და `inspectp`.<br/>• სანამ პროცესი ცოცხალია, შეინახეთ `/proc/<PID>/status`, `cmdline`, `cgroup` და PID/PPID/user-ის ხე.<br/>• audit log-ში იპოვეთ `pods/exec` event `runtime-112/falco-shell`-ისთვის და შეინახეთ ის request/response body-ის გარეშე.<br/>• კლასიფიცირება გაუკეთეთ ფაზას როგორც `Execution`, ტექნიკას როგორც `Container Administration Command`, შეადგინეთ `evidence-summary.txt`. `control-plane`-ზე გადაღებული ფაილები დააკოპირეთ `scp`-ით `/var/work/tests/artifacts/6/`-ში.<br/>• შემდეგ გამოიყენეთ default-deny ingress+egress `NetworkPolicy` `incident-quarantine`, წაშალეთ კომპრომეტირებული Pod და შეინახეთ უარყოფითი შემოწმება: განმეორებითი `kubectl exec` არ გადის.<br/>• ეს containment-ის მინიმალური ჯაჭვია: credential revocation/rotation და სრული remediation ცალკე incident-response პროცესს მოითხოვს. |
| მიღების კრიტერიუმები | • `/var/work/tests/artifacts/6/`-ში არის ნამდვილი Falco alert, CRI inspect/inspectp, სამი `/proc`-artifact, process lineage, Metadata audit event `pods/exec`-ისთვის, საბოლოო შეჯამება და containment-ის შედეგი<br/>• Pod `falco-shell` არ არსებობს<br/>• `incident-quarantine` ირჩევს ყველა Pod-ს და ხურავს ingress+egress-ს<br/>• განმეორებით exec-ს აქვს non-zero exit code |

<details>
<summary>💡 მინიშნება დავალება 6-ისთვის</summary>

მოქმედებების მკაცრი თანმიმდევრობა გამოძიების სანდოობისთვის მნიშვნელოვანია: დაიწყეთ Falco alert-ით (ეს არის ის, რაც რეალურად დაიწყებდა incident response-ს), და არა უკვე ცნობილი Pod-ის სახელით - წინააღმდეგ შემთხვევაში უბრალოდ ადასტურებთ იმას, რაც უკვე იცით, და არა ატარებთ რეალურ correlation-ს. `/proc/<PID>/*` artifacts შეაგროვეთ, სანამ პროცესი ცოცხალია - როგორც კი Pod-ს წაშლით (ბოლო ნაბიჯი), `/proc` ამ PID-ისთვის სამუდამოდ გაქრება, ამიტომ თანმიმდევრობა "ჯერ evidence, შემდეგ containment" შეუქცევადია არევისას.
</details>

---
| **7** | **upstream Falco macro-ს override, Pod/namespace evidence-ის დამატება output-ში, JSON ფაილში** |
| :---: | :--- |
| რას ვაკეთებთ | • Falco-ს სტანდარტული წესი **Terminal shell in container** გააქტიურდებოდა ლეგიტიმურ CI/CD-ინსტრუმენტზეც, რომელიც კონტეინერში shell-ს რეგულარულად ხსნის (მაგალითად, `kubectl debug` ან sidecar მომსახურების სკრიპტით). თავად წესის რედაქტირების ნაცვლად override გაუკეთეთ upstream-მაკროს, განკუთვნილს სწორედ ამ წესისთვის.<br/>• `/etc/falco/falco_rules.local.yaml`-ში გადაფარეთ `user_expected_terminal_shell_in_container_conditions` (ნაგულისხმევად `(never_true)` თავად წესში **Terminal shell in container** - არ აურიოთ `user_shell_container_exclusions`-თან, რომელიც ცალკე წესს ეხება **Run shell untrusted**/"Shell spawned by untrusted binary"), რათა მან დაუშვას კონკრეტული Pod `ci-runner` namespace `runtime-112`-ში.<br/>• გამოიყენეთ `k8s.pod.name` და `k8s.ns.name`, და არა `container.name`: `container.name` - **კონტეინერის** სახელია (ამ დავალებაში `app`), და არა Pod-ის, და კონტეინერის სახელით დამთხვევა თითქმის ყოველთვის არასწორ ან ძალიან ფართო allowlist-ს მისცემს.<br/>• წესის **Terminal shell in container** სტანდარტული output არ შეიცავს `k8s.pod.name`/`k8s.ns.name`-ს (თავად შეამოწმეთ upstream `falco_rules.yaml` - იქ ისინი არ არის); ამ ველის გარეშე კონკრეტული alert-ის კონკრეტულ Pod-თან correlation საიმედოდ შეუძლებელია. იმავე `override` მექანიზმით დაამატეთ (`output: append`) წესს `k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name` output-ის ბოლოს.<br/>• შექმენით `runtime-112`-ში Pod `ci-runner` `busybox:1.36`-დან ინტერაქტიული `sh`-ით (`stdin: true`, `tty: true`) და დაადასტურეთ, რომ მისთვის alert `Terminal shell in container` **არ** ფორმირდება, მაშინ როცა `immutable-app`-ისთვის დავალება 5-დან (გამონაკლისის გარეშე) alert კვლავ გააქტიურდება.<br/>• ცალკე `/etc/falco/config.d/cks112-output.yaml`-ით ჩართეთ `json_output: true` და `file_output.enabled: true` `file_output.filename: /var/log/falco/events.log`-ით; გადატვირთეთ Falco.<br/>• დაადასტურეთ სტრუქტურირებული JSON-ით (`jq .output_fields`), და არა ტექსტური `grep`-ით, რომ `immutable-app`-ისთვის ჩაწერილი alert შეიცავს `k8s.pod.name == "immutable-app"` და `k8s.ns.name == "runtime-112"`-ს. |
| მიღების კრიტერიუმები | • `falco_rules.local.yaml` შეიცავს `macro: user_expected_terminal_shell_in_container_conditions`-ს პირობით, რომელიც მიუთითებს `k8s.pod.name = "ci-runner"`-ზე და `k8s.ns.name = "runtime-112"`-ზე (არა `never_true`, არა `container.name`), და ცალკე `override: output: append`-ს, რომელიც წესს `Terminal shell in container` უმატებს `%k8s.ns.name`/`%k8s.pod.name`-ს<br/>• Shell `ci-runner`-ში დაკვირვების დროის განმავლობაში alert-ს არ ქმნის, ხოლო shell `immutable-app`-ში ქმნის<br/>• `config.d/cks112-output.yaml` შეიცავს `json_output: true`-ს და `file_output: {enabled: true, filename: /var/log/falco/events.log}`-ს<br/>• `/var/log/falco/events.log` შეიცავს ვალიდურ JSON-სტრიქონს `rule == "Terminal shell in container"`-ით და `output_fields["k8s.pod.name"] == "immutable-app"`-ით, `output_fields["k8s.ns.name"] == "runtime-112"`-ით<br/>• Pod `falco-shell` დავალება 2-დან ამ მომენტისთვის უკვე წაშლილია (დავალება 6) და აქ არ გამოიყენება |

<details>
<summary>💡 მინიშნება დავალება 7-ისთვის</summary>

ორი განსხვავებული override-მექანიზმის არევა ადვილია: `macro` override ცვლის წესის გააქტიურების პირობას (ვის გამოვრიცხოთ), ხოლო `output` override `append`-ით ცვლის მხოლოდ გამოტანის ფორმატს (რა დაიბეჭდოს) - ამ დავალებისთვის საჭიროა ორივე, ცალკე ბლოკებით `- macro: ...` და `- rule: ... / override: / output: append`. სიტყვასიტყვით შეამოწმეთ `user_expected_terminal_shell_in_container_conditions`-ის დაწერილობა - Falco-ს აქვს რამდენიმე სახელით მსგავსი მაკრო სხვადასხვა წესისთვის (დავალებაში ნახსენები `user_shell_container_exclusions` სხვა წესს ეკუთვნის), არასწორი მაკროს გამოყენება ჩატვირთვის შეცდომას არ მოგცემთ, მაგრამ allowlist უბრალოდ არ იმუშავებს.
</details>

---
| **8** | **Audit webhook backend ლოკალური ფაილის ნაცვლად/მასთან ერთად** |
| :---: | :--- |
| რას ვაკეთებთ | • გამოიყენეთ bootstrap-ით უკვე მომზადებული HTTP-მიმღები `audit-receiver` (Deployment + Service პორტზე `8080`, image `ghcr.io/mendhak/http-https-echo:40`), რომელიც audit-მოვლენებს იღებს.<br/>• `control-plane`-ზე შექმენით `/etc/kubernetes/audit/webhook-config.yaml` kubeconfig-ის ფორმატში `server: http://<მიმღების ClusterIP>:8080/audit`-ით (ლაბისთვის HTTP დასაშვებია; production-ში webhook მოითხოვს HTTPS-სა და client certificate-ს - იხ. თავი 32).<br/>• static manifest `kube-apiserver.yaml`-ში დაამატეთ `--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml` და `--audit-webhook-batch-max-wait=1s` (შემცირებული batch-დაყოვნება ლაბში დაკვირვებადობისთვის), დავალება 4-იდან უკვე გამართული `--audit-policy-file` და `--audit-log-path` შენარჩუნებით - webhook ავსებს და არ ანაცვლებს local file backend-ს.<br/>• API-ს აღდგენის შემდეგ შეასრულეთ ნებისმიერი აუდირებადი მოთხოვნა (მაგალითად, `kubectl get configmap audit-config -n runtime-112`) და `audit-receiver`-ის ლოგებში დაადასტურეთ, რომ მოვლენა მიწოდებულია. |
| მიღების კრიტერიუმები | • `audit-receiver` Running-ია Service-ით<br/>• `webhook-config.yaml` - ვალიდური kubeconfig-ია `server`-ით ამ Service-ზე<br/>• Kube-apiserver-ის static manifest შეიცავს `--audit-webhook-config-file`-სა და `--audit-webhook-batch-max-wait`-ს, ასევე file backend-ის შენარჩუნებულ ფლაგებს დავალება 4-დან<br/>• Kube-apiserver healthy-ა ცვლილების შემდეგ<br/>• `audit-receiver`-ის ლოგები შეიცავს სულ მცირე ერთ JSON audit event-ს მოთხოვნის სხეულით ველით `objectRef` |

<details>
<summary>💡 მინიშნება დავალება 8-ისთვის</summary>

`webhook-config.yaml` - ეს KUBECONFIG-ის ფორმატია (`clusters`/`users`/`contexts`-ით), და არა თვითნებური YAML ველით `server` - თუ ფაილის სტრუქტურა kubeconfig schema-ს არ შეესაბამება, kube-apiserver მას ვერ დააპარსავს და საერთოდ არ გაეშვება. არ დაგავიწყდეთ, რომ webhook file backend-ს ავსებს და არ ანაცვლებს - თუ დავალება 4-იდან `--audit-policy-file`/`--audit-log-path` ფლაგებს წაშლით, დავალება 4-ის ტესტები აღარ გაივლის.
</details>

---
| **9** | **ინტეგრაციული დავალება: admission allowlist-ის შემოვლა containerd-ით პირდაპირ და მცდელობის აღმოჩენა Falco-ით** |
| :---: | :--- |
| რას ვაკეთებთ | • ეს დავალება აკავშირებს Supply Chain Security-ს (იხ. [ლაბ 111](../111/README_GE.MD) და [თავი 26](../../course/26/ge.md)) ამ ლაბის Runtime Security-სთან. **მნიშვნელოვანი განსხვავება ლაბ 111-ისგან**: იქ `ImageValidatingPolicy` ამოწმებს **კრიპტოგრაფიულ ხელმოწერას** (Cosign). აქ policy ამოწმებს მხოლოდ **registry/repository allowlist-ს** (permitted registry, signature/attestor-ის გარეშე) - უფრო მარტივი, მაგრამ ისეთივე რეალური admission control, იმავე პრინციპით: ის მუშაობს მხოლოდ API admission path-ზე და ვერ ხედავს მოქმედებებს, რომლებიც მას არ მიმართავენ.<br/>• ამ დავალების Controlled abuse fixture - lab-owned local registry-ა, და არა საჯარო Docker Hub: bootstrap-მა უკვე მოამზადა `control-plane`-ზე სამი image სხვადასხვა digest-ით ლოკალურ containerd content store-ში და შეინახა მათი სახელები `/etc/cks112/registry.env`-ში (`CKS112_REGISTRY=cks112.local:5000`, `CKS112_TRUSTED_REPO=cks112/trusted`, `CKS112_UNTRUSTED_REPO=cks112/untrusted`, `CKS112_TRUSTED_IMAGE`, `CKS112_UNTRUSTED_IMAGE`, `CKS112_PREFIX_IMAGE`) - დაუკავშირეთ (`source`) ეს ფაილი დავალების დასაწყისში და გამოიყენეთ მხოლოდ ეს მნიშვნელობები.<br/>• დააყენეთ Kyverno (`install-kyverno`, როგორც ლაბ 111-ში) და შექმენით `ValidatingPolicy` `require-trusted-registry-runtime-112` (native CEL, `apiVersion: policies.kyverno.io/v1`), რომელიც `image(c.image).registry()`/`.repository()`-ით (Kyverno CEL Image library) **უარყოფს** `runtime-112`-ში ნებისმიერ Pod-ს, რომლის image არ უდრის ზუსტად `registry: $CKS112_REGISTRY` და `repository: $CKS112_TRUSTED_REPO`-ს - არა `startsWith`-ით, რომ არ გაგვეპაროს მსგავსი სახელები, როგორიცაა `cks112/trusted-evil`. policy-ს მიეცით უარყოფის უნიკალური შეტყობინება, მაგალითად `CKS112_TRUSTED_REPO_POLICY: only $CKS112_TRUSTED_IMAGE is allowed`.<br/>• დაადასტურეთ ეს გზა: გამოიყენეთ Pod `blocked-attempt` image-ით `$CKS112_UNTRUSTED_IMAGE` (allowlist-ში არ არის) და შეინახეთ admission denial-ის გამოტანა `9/admission-deny.txt`-ში.<br/>• შემდეგ `control-plane`-ზე `cks112-run $CKS112_UNTRUSTED_IMAGE cks112-bypass-1 'echo CKS112_CTR_BYPASS; sleep 5'`-ით (image bootstrap-იდან ლოკალურად უკვე არსებობს, განმეორებითი pull საჭირო არ არის) მოახდინეთ იმ გზის სიმულაცია, რომელიც API server-ს არ გაივლის და admission controller-ისთვის უხილავია (helper CRI-ით detached-რეჟიმში თავად უშვებს; განმეორებითი შემოწმებისთვის გამოიყენეთ უნიკალური ID და შემდეგ წაშალეთ კონტეინერი `cks112-rm <id>`-ით).<br/>• **Falco-წესის დაწერამდე განსაზღვრეთ ველის `%container.image.repository` რეალური observed-მნიშვნელობა სანდო `$CKS112_TRUSTED_IMAGE`-სთვის თქვენს containerd/Falco სტეკზე** - ეს ველი სხვადასხვა ვერსიაში სხვადასხვაგვარად ყალიბდება (შესაძლოა registry hostname-ით, შესაძლოა მის გარეშე), ამიტომ ფორმატს წინასწარ ნუ დაუშვებთ: დროებითი წესით უსაფრთხო marker-ით გამოიტანეთ მნიშვნელობა ლოგში და შეინახეთ ის როგორც `$TRUSTED_REPO` (შეინახეთ evidence `9/observed-trusted-repo.txt`-ში).<br/>• დაამატეთ `falco_rules.local.yaml`-ში custom rule `CKS112 Runtime Bypass of Admission`, რომელიც იჭერს spawned process-ს `proc.cmdline`-ით, რომელიც შეიცავს `CKS112_CTR_BYPASS`-ს **და** `container.image.repository`-ით, რომელიც allowlist-ში არ შედის, და გამოაქვს `container.image.repository` პროცესის იდენტიფიკატორებთან ერთად. გამოიყენეთ **ზუსტი** შედარება `container.image.repository != "$TRUSTED_REPO"` დაკვირვებული მნიშვნელობით (არა `startswith`/prefix-შემოწმება: `not container.image.repository startswith "$TRUSTED_REPO"` გამოტოვებდა, ანუ ვერ შეამჩნევდა, repository-ს ტიპის `<observed-value>-evil`, რადგან მისი სახელი უბრალოდ დაშვებული ქვესტრიქონით იწყება - იგივე შეცდომა, რომელსაც ზემოთ Kyverno policy თავს არიდებს `==`-ით, და არა `startsWith`-ით).<br/>• დამატებით შეამოწმეთ ორივე კონტროლირებადი შემთხვევა: სანდო `$CKS112_TRUSTED_IMAGE` არ უნდა იწვევდეს წესის გააქტიურებას (მხოლოდ repository-ს ნიშნით - თავად marker `CKS112_CTR_BYPASS` ამასთან მაინც შეიძლება ცალკე შემოწმდეს), ხოლო image repository-ით `<observed-value>-evil` უნდა იწვევდეს გააქტიურებას - სწორედ ეს ამტკიცებს, რომ შედარება ზუსტია, და არა prefix-based.<br/>• შეინახეთ გააქტიურება `9/falco-bypass-attempt.log`-ში (`control-plane`-ზე გადაღებული ფაილები `scp`-ით კოპირდება `/var/work/tests/artifacts/9/`-ში). |
| მიღების კრიტერიუმები | • Kyverno დაყენებულია და Available-ა<br/>• `ValidatingPolicy require-trusted-registry-runtime-112` არსებობს `apiVersion: policies.kyverno.io/v1`-ით, validation action `Deny`-ით, იყენებს `image(...).registry()`/`.repository()`-ს ზუსტი (არა `startsWith`) შედარებისთვის, და მისი `message`/`messageExpression` შეიცავს უნიკალურ marker-ს `CKS112_TRUSTED_REPO_POLICY`<br/>• Pod `blocked-attempt` არ არის შექმნილი (admission denial), `9/admission-deny.txt` შეიცავს სწორედ ამ marker-ს (და არა ნებისმიერ generic admission-შეცდომას)<br/>• `9/observed-trusted-repo.txt` შეიცავს ველის `%container.image.repository` რეალურად დაკვირვებულ მნიშვნელობას სანდო image-ისთვის<br/>• `falco_rules.local.yaml` შეიცავს წესს `CKS112 Runtime Bypass of Admission` **ზუსტი** (არა `startswith`/prefix) პირობით `container.image.repository`-ზე, რომელიც იყენებს სწორედ ამ დაკვირვებულ მნიშვნელობას<br/>• `9/falco-bypass-attempt.log` შეიცავს არაცარიელ გააქტიურებას `CKS112_CTR_BYPASS`-ით და image repository-ით allowlist-ის გარეთ (სუფიქსი `-evil` დაკვირვებულ მნიშვნელობაზე) - ეს repository სპეციალურად არის არჩეული როგორც prefix-trap: ის უნდა აღმოჩნდეს, მიუხედავად იმისა, რომ დაშვებული სტრიქონით იწყება |

<details>
<summary>💡 მინიშნება დავალება 9-ისთვის</summary>

დავალების ძირითადი აზრი: `cks112-run` (`crictl`-ის wrapper, რომელიც კონტეინერს CRI-ით პირდაპირ ქმნის) მიმართავს containerd-ს, kube-apiserver-ის გვერდის ავლით და, შესაბამისად, ნებისმიერი admission controller-ის (Kyverno-ს ჩათვლით) გვერდის ავლით - ეს იმის დემონსტრაციაა, რომ admission control იცავს მხოლოდ გზას Kubernetes API-ით, და არა მთელ node-ს. თქვენმა Falco-წესმა ერთ `condition`-ში `and`-ით უნდა შეამოწმოს: კონტეინერული პროცესი (`container.id != host` - node-ზე გაშვების თავად ბრძანებაც შეიცავს marker-ს), marker `CKS112_CTR_BYPASS` და repository allowlist-ის გარეთ - თუ მხოლოდ marker-ს შეამოწმებთ, წესი ლეგიტიმურ სატესტო პროცესებზეც გააქტიურდება მსგავსი cmdline-ით.
</details>

---
| **10** | **`/dev/mem`-ზე წვდომის აღმოჩენა Falco-პირობის ცალკე კლასით და workload-ის გაჩერება** |
| :---: | :--- |
| რას ვაკეთებთ | • დავალებები 3, 7 და 9 იყენებდნენ პირობას `spawned_process`/`proc.cmdline`-ზე - აღმოჩენა პროცესის გაშვებით. აქ საჭიროა Falco condition-ის პრინციპულად სხვა კლასი: აღმოჩენა **ფაილის/მოწყობილობის გახსნით**.<br/>• `runtime-112`-ში უკვე არის Deployment `mem-scanner` (2 replica), რომლის ორივე replica პერიოდულად ხსნის `/dev/mem`-ს კონტეინერის შიგნიდან - ჩვეულებრივ application workload-ს ამის მიზეზი არ აქვს, და ასეთი წვდომა სახიფათო კონფიგურაციის ან კონტეინერის იზოლაციის შემოვლის მცდელობის ძლიერი ინდიკატორია. გზა `/dev/mem` კონტეინერის შიგნით - synthetic safe fixture-ია (backing device სინამდვილეში host-ის `/dev/null`-ია, და არა ჰოსტის რეალური ფიზიკური მეხსიერება); Falco-სთვის ამას მნიშვნელობა არ აქვს - წესი აღმოაჩენს თავად syscall-ს `open`/`openat`/`openat2` ფაილის სახელით `fd.name = /dev/mem`, იმის მიუხედავად, რა მოწყობილობა დგას რეალურად მის უკან.<br/>• `control-plane`-ზე დაამატეთ `/etc/falco/falco_rules.local.yaml`-ში წესი `CKS112 Container access to /dev/mem` პირობით `evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host`, priority `CRITICAL`, output უნდა შეიცავდეს `container_id=%container.id`, `k8s_pod=%k8s.pod.name` და `k8s_ns=%k8s.ns.name`-ს. გადატვირთეთ Falco.<br/>• იპოვეთ გააქტიურება journal-ში და მისი მეშვეობით განსაზღვრეთ **კონკრეტული** Pod (სახელით ნუ გამოიცნობთ - გამოიყენეთ `k8s_pod` თავად alert-იდან); კონკრეტული alert-ით განსაზღვრეთ, რომელმა replica-მ შექმნა დაფიქსირებული მოვლენა. შეინახეთ alert-ის სტრიქონი node-ზე და დააკოპირეთ `scp`-ით `/var/work/tests/artifacts/10/falco-devmem.log`-ში.<br/>• შეასრულეთ `kubectl scale deployment mem-scanner -n runtime-112 --replicas=0` და შეინახეთ საბოლოო მდგომარეობა (`kubectl get deployment mem-scanner -n runtime-112 -o json`) `/var/work/tests/artifacts/10/scaled-down.json`-ში. |
| მიღების კრიტერიუმები | • `falco_rules.local.yaml` შეიცავს წესს სახელით `CKS112 Container access to /dev/mem`, პირობით `fd.name = /dev/mem`-ზე (და არა `proc.cmdline`/spawned_process-ზე) და `container.id != host`, priority `CRITICAL`<br/>• Falco აქტიურია<br/>• `10/detected-pod.json` აფიქსირებს რეალურ Pod-სა და owner chain-ს containment-მდე<br/>• `10/falco-devmem.log` - journal-იდან ამ წესის ნამდვილი სტრიქონია არაცარიელი `k8s_pod`-ით<br/>• Deployment `mem-scanner` დამასშტაბებულია `replicas: 0`-მდე<br/>• `10/scaled-down.json` ადასტურებს `spec.replicas == 0`-ს |

<details>
<summary>💡 მინიშნება დავალება 10-ისთვის</summary>

ეს პირობა დავალებებ 3/7/9-თან ნუ აგრევთ - იქ `spawned_process`/`execve` იჭერს პროცესის გაშვებას ბრძანების ხაზით, ხოლო აქ `open`/`openat`/`openat2` იჭერს კონკრეტული ფაილის/მოწყობილობის გახსნას იმის მიუხედავად, რომელი პროცესი აკეთებს ამას და რა არგუმენტებით. `container.id != host` გამოარჩევს ლეგიტიმურ სისტემურ პროცესებს თავად node-ზე (არა კონტეინერში), რომლებსაც `/dev/mem`-ზე წვდომა სხვა მიზეზებით შეიძლება სჭირდებოდეთ. Deployment-ს alert-ის პოვნამდე ნუ დაამასშტაბებთ - ჯერ აღმოჩენა Falco-ით, შემდეგ containment, წინააღმდეგ შემთხვევაში ვერ დაამტკიცებთ, რომ Pod მონიტორინგით იპოვეთ, და არა წინასწარ სახელით აირჩიეთ. ჯერ მიიღეთ Falco alert და მხოლოდ მისი `k8s_pod`-იდან განსაზღვრეთ ამ მოვლენის შემქმნელი კონკრეტული replica.
</details>

## შედეგის შემოწმება

```bash
check_result
```

შემოწმება შეიცავს Init-სა და ათ დამოუკიდებელ ტესტს. ის ამოწმებს Falco-ისა და
kube-apiserver-ის მდგომარეობას SSH-ით, API-ობიექტებს, CRI/`/proc` evidence-ს, audit correlation-ს, containment-ს
და rootfs-ში ჩაწერის ფაქტობრივ უარყოფას. static Pod manifest-ის
შეცვლის შემდეგ kubelet-ს აუცილებლობის გარეშე ნუ გადატვირთავთ: kubelet თავად
შეამჩნევს ცვლილებას. თუ API დროებით მიუწვდომელია, დაელოდეთ `kubectl get --raw=/readyz`-ს.
ფაილის `kube-apiserver.yaml` backup შეინახეთ მხოლოდ `/etc/kubernetes/manifests`-ის გარეთ: kubelet ამ დირექტორიაში კითხულობს ნებისმიერ ფაილს დასაწყისში წერტილის გარეშე.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD).

## წაშლა

```bash
TASK=112 make delete_cks_task
```
