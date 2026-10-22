[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 110 - gVisor RuntimeClass, Cilium WireGuard და Istio mTLS

## მიზანი

ამ CKS-ლაბში თქვენ ააწყობთ workload-ის დაცვის სამ დამოუკიდებელ ფენას: sandboxed runtime
**gVisor** `runsc`-ის გავლით, Cilium WireGuard-ის node-თაშორისი დაშიფვრა და Istio-ს service-to-service
mTLS. ბოლოს თქვენ არა მხოლოდ პარამეტრებს ნახავთ, არამედ დაამტკიცებთ მათ დაკვირვებადი
შედეგებით: gVisor-ის kernel view-ის სხვაობით, WireGuard-პაკეტებით HTTP marker-ის გარეშე და mesh-იდან და mesh-ის გარეთ plaintext-კლიენტიდან გამოძახების განსხვავებული
შედეგით.

## შეამოწმეთ თავი სტარტამდე

<details>
<summary>1. რით განსხვავდება პრინციპულად gVisor-ის userspace kernel ვირტუალური მანქანის guest kernel-ისგან?</summary>

gVisor (`runsc`) ახორციელებს Linux syscalls-ის საკუთარ ქვესიმრავლეს USERSPACE-ში, იჭერს კონტეინერის სისტემურ გამოძახებებს და თავად ამუშავებს მათ, პირდაპირ host-ის ბირთვს კი არ გადასცემს - კონტეინერის პროცესი ხედავს განსხვავებულ "ბირთვს" (სხვა `uname -r`, ზოგიერთი syscalls-ის სხვა ქცევა). Guest kernel (მაგალითად, Kata Containers) უშვებს სრულფასოვან Linux-ბირთვს მსუბუქ VM-ში - უფრო ძლიერი იზოლაცია, მაგრამ სრულფასოვანი ვირტუალიზაციის overhead-ით, რომელიც gVisor-ს არ აქვს.
</details>

<details>
<summary>2. რას ავტენტიფიცირებს ზუსტად WireGuard peer და რატომ არ არის ეს იგივე, რაც ServiceAccount-ის identity?</summary>

WireGuard ავტენტიფიცირებს კლასტერის node-ებს (nodes) კრიპტოგრაფიული გასაღებებით, რომლებიც Cilium-მა თითოეული node-ისთვის დააგენერირა - დაშიფვრა node-to-node-ის გვირაბის დონეზე ხდება. ეს იცავს ტრაფიკს node-ებს შორის ქსელის დონეზე მოსმენისგან, მაგრამ არანაირი კავშირი არ აქვს ამ ტრაფიკის შიგნით კონკრეტული Pod/ServiceAccount-ის identity-სთან - Cilium WireGuard არ ამოწმებს, "ვინ" არის გამგზავნი აპლიკაციის დონეზე, მხოლოდ "რომელი node".
</details>

<details>
<summary>3. რატომ არ ამტკიცებს mesh-ის შიგნით წარმატებული `curl` კოდით 200 იმას, რომ plaintext client მართლაც დაიბლოკა?</summary>

წარმატებული პასუხი mesh-ის შიგნით ამტკიცებს მხოლოდ იმას, რომ mTLS-კავშირი ორ sidecar-ს შორის მუშაობს - ეს positive control-ია. იმის დასამტკიცებლად, რომ STRICT რეალურად ბლოკავს არა-mesh ტრაფიკს, საჭიროა ცალკე negative control: კლიენტი sidecar-ის გარეშე, რომელიც იმავე სერვისს მიმართავს და უარს იღებს. ერთი წარმატებული ტესტი საკმარისი არ არის - საჭიროა ორივე: allowed mesh identity-სთვის, denied plaintext-ისთვის.
</details>

## კავშირი კურსთან

- [თავი 22. Container Runtime Sandbox](../../course/22/ge.md)
- [თავი 23. Pod-to-Pod დაშიფვრა და mTLS](../../course/23/ge.md)

## ინფრასტრუქტურა

Terragrunt ქმნის Kubernetes `1.36.0`-ს `eu-central-1`-ში:

| კომპონენტი | დანიშნულება |
|---|---|
| `k8s-1` control-plane | ჩვეულებრივი containerd workload node, Cilium და `tcpdump` node-თაშორისი პაკეტის დასაჭერად |
| `k8s-1` worker `gvisor` | ცალკე node containerd-ით, დაყენებული `runsc`-ითა და CRI handler `runsc`-ით |
| CNI | **Cilium** (დაყენებულია Cilium CLI-ით Helm release `cilium`-ით); WireGuard განზრახ გამორთულია დავალება 4-მდე |
| `worker` | სამუშაო მანქანა `kubectl`-ით, `cilium`-ით, `istioctl`-ით, `check_result`-ით და SSH aliases-ით node-ებზე |

2026-08-31-ს შემოწმებული მატრიცა (გადაამოწმეთ ყოველი აწყობის წინ): Kubernetes ლაბში -
`1.36.0`; Cilium data plane - მხარდაჭერილი lab-აწყობა, რომლის თავსებადობა
Kubernetes `1.36`-თან აქტუალური requirements matrix-ით უნდა დადასტურდეს; Cilium CLI `0.19.7`
(თავსებადია Cilium `1.17+`-თან); Istio `1.30.4` (ტოტი `1.30` ოფიციალურად უჭერს მხარს Kubernetes
`1.32–1.36`-ს). გამოცდის ვერსია აქ lab tooling-ის თავსებადობას არ განსაზღვრავს; LF-ის მონაცემებით
ის ახლა `v1.34`-ია და გამოცდამდე ცალკე მოწმდება.

bootstrap-ის შემდეგ ხელმისაწვდომია ორი workload placement label:

```text
lab.cks.io/role=control-plane
sandbox.runtime/gvisor=true,lab.cks.io/role=gvisor
```

Control-plane ხელმისაწვდომია ჩვეულებრივი Pod-ებისთვის tolerations-ის გარეშე. gVisor-node დამატებით მონიშნულია taint-ით
`sandbox.runtime/gvisor=true:NoSchedule`: მასზე ხვდება მხოლოდ Pod-ები, რომლებიც ამ taint-ს toleration-ით იტანენ
(Pod-ები `RuntimeClass gvisor`-ით საჭირო toleration-ს იღებენ კლასის `scheduling.tolerations`-იდან).

Namespace-ები `sandbox-110` და `market` უკვე არსებობს. `market`-ს წინასწარ დაყენებული აქვს
label `istio-injection=enabled`; Istio control plane დაყენებული არ არის. worker-იდან
sandbox-node-ზე წვდომისთვის გამოიყენეთ alias `k8s110_node_gvisor`, control-plane-ზე -
`k8s110_controlPlane_1`.

## განთავსება

```bash
TASK=110 make run_cks_task
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
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## დავალებები

---
| **1** | **containerd runtime-ის გამართვა და RuntimeClass-ის შექმნა runsc-ისთვის** |
| :---: | :--- |
| რას ვაკეთებთ | • `k8s110_node_gvisor`-ზე binary `runsc` უკვე დაყენებულია, მაგრამ bootstrap-მა განზრახ ამოიღო `/etc/containerd/config.toml`-იდან სექცია `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` `runtime_type = "io.containerd.runsc.v1"`-ით - ეს გამოცდის ტიპური სიტუაციაა დაზიანებული config.toml-ით.<br/>• დააბრუნეთ ეს სექცია (სარეზერვო ასლი დევს `/etc/containerd/config.toml.bak`-ში, ან დაამატეთ ხელით) და შეასრულეთ `sudo systemctl restart containerd`.<br/>• შექმენით `RuntimeClass` `gvisor` ზუსტი `handler: runsc`-ით.<br/>• `scheduling`-ში მიუთითეთ `nodeSelector` `sandbox.runtime/gvisor: "true"`, რათა ამ კლასის Pod არასდროს მოხვდეს ჩვეულებრივ node-ზე, და `tolerations` gVisor-node-ის taint-ისთვის (`sandbox.runtime/gvisor=true:NoSchedule`), წინააღმდეგ შემთხვევაში Pod იქ ვერ მოხვდება. |
| მიღების კრიტერიუმები | • node-ზე `containerd` აქტიურია და `config.toml` შეიცავს მუშა სექციას `runtimes.runsc` `runtime_type = "io.containerd.runsc.v1"`-ით<br/>• `kubectl get runtimeclass gvisor` არსებობს, handler უდრის `runsc`-ს, `scheduling`-ში არის `nodeSelector` და `tolerations` gVisor-node-ის taint-ისთვის<br/>• `/var/work/tests/artifacts/1/runsc-runtime.txt`-ში არის ზუსტი სტრიქონი `RuntimeClass gvisor: handler runsc` |

<details>
<summary>💡 მინიშნება დავალება 1-ისთვის</summary>

სარეზერვო ასლი `/etc/containerd/config.toml.bak` აღდგენის ყველაზე სწრაფი გზაა, მაგრამ უკან დაკოპირებამდე შეამოწმეთ მისი შიგთავსი (`diff` მიმდინარე ფაილთან), რომ გაიგოთ, რა ზუსტად აკლია. სექციის `runtimes.runsc` აღდგენის შემდეგ აუცილებლად შეასრულეთ `systemctl restart containerd` - ფაილის უბრალო რედაქტირება ცვლილებებს უკვე მომუშავე პროცესზე არ ამოქმედებს.
</details>

---
| **2** | **Pod gVisor-ის sandbox-ში** |
| :---: | :--- |
| რას ვაკეთებთ | • `sandbox-110`-ში შექმენით Pod `gvisor-sandbox` `runtimeClassName: gvisor`-ით, კონტეინერით `app` და image-ით `busybox:1.36`.<br/>• Pod-ში ცხადად მიუთითეთ `nodeSelector` `sandbox.runtime/gvisor: "true"` და `tolerations` gVisor-node-ის taint-ისთვის (იგივე, რაც RuntimeClass-ის `scheduling`-ში; მათ გარეშე Kubernetes მათ RuntimeClass-იდან თავად დაამატებს, მაგრამ manifest-ში ეს არ ჩანს).<br/>• გაუშვით კონტეინერში HTTP server `8080`-ზე, რომელიც აბრუნებს სტრიქონს `CKS110-WIREGUARD-MARKER`.<br/>• შექმენით Service `gvisor-echo` `8080`-ზე, რომელიც ამ Pod-ს ირჩევს.<br/>• გამორთეთ ServiceAccount token-ის automount.<br/>• Pod-იდან artifact-ში ჩაწერეთ `uname -r` და `dmesg`: `dmesg` gVisor sandbox-ის შიგნით იწყება სტრიქონით `Starting gVisor...` node-ის ბირთვის რეალური ლოგის ნაცვლად - ეს იზოლაციის პირდაპირი დადასტურებაა, `uname -r`-ის განსხვავებისგან ცალკე. |
| მიღების კრიტერიუმები | • Pod `Running`-ია node-ზე `sandbox.runtime/gvisor=true`, Service მას ირჩევს, ხოლო `/var/work/tests/artifacts/2/gvisor-kernel.txt` შეიცავს სტრიქონს `gvisor uname -r: <ფაქტობრივი მნიშვნელობა>` და სტრიქონს `Starting gVisor` `dmesg`-ის გამოტანიდან |

<details>
<summary>💡 მინიშნება დავალება 2-ისთვის</summary>

თუ Pod არ ეშვება (რჩება `ContainerCreating`-ში მოვლენით `FailedCreatePodSandBox`, მაგალითად `no runtime for "runsc" is configured`), სავარაუდოდ დავალება 1 სრულად დასრულებული არ არის - RuntimeClass რეალურად მუშა containerd handler-ზე უნდა მიუთითებდეს. გამოყენებულ `busybox:1.36`-ში არის applet `httpd` - გამოიყენეთ `httpd -f -p 8080 -h /www` მინიმალური HTTP server-ისთვის (applet-ის არსებობა შეიძლება შემოწმდეს `busybox --list | grep '^httpd$'`-ით).
</details>

---
| **3** | **ჩვეულებრივ runc Pod-თან შედარება** |
| :---: | :--- |
| რას ვაკეთებთ | • შექმენით `runc-baseline` `sandbox-110`-ში: `busybox:1.36`, კონტეინერი `app`, `sleep 3600`.<br/>• `runtimeClassName`-ის გარეშე, nodeSelector-ით `lab.cks.io/role: control-plane` და SA token-ის გარეშე.<br/>• შეადარეთ მისი `uname -r` gVisor Pod-ის `uname -r`-ს და შეინახეთ ორივე შედეგი `/var/work/tests/artifacts/3/runtime-comparison.txt`-ში. |
| მიღების კრიტერიუმები | • Baseline Pod `Running`-ია control-plane-ზე, არ აქვს `runtimeClassName`<br/>• მისი release gVisor release-ისგან განსხვავდება<br/>• artifact-ში არის ორივე სტრიქონი `gvisor uname -r:` და `runc uname -r:` ფაქტობრივი მნიშვნელობებით |

<details>
<summary>💡 მინიშნება დავალება 3-ისთვის</summary>

ეს Pod სპეციალურად სხვა node-ზე (control-plane, და არა gvisor-node) თავსდება nodeSelector-ით `lab.cks.io/role: control-plane` - ეს უბრალოდ "ნებისმიერი ჩვეულებრივი Pod" არ არის, არამედ კონტროლირებადი შედარება განთავსების ცნობილ ადგილთან. თუ `uname -r` ორივე Pod-ისთვის ერთნაირი აღმოჩნდა - შეამოწმეთ, მართლაც იყენებს თუ არა `gvisor-sandbox` `runtimeClassName: gvisor`-ს.
</details>

---
| **4** | **Cilium transparent encryption-ის ჩართვა** |
| :---: | :--- |
| რას ვაკეთებთ | • ჯერ დააფიქსირეთ Kubernetes-ის, Cilium agent-ისა და Cilium CLI-ის ვერსიები `/var/work/tests/artifacts/4/tool-versions.txt`-ში და დარწმუნდით, რომ data plane Kubernetes `1.36`-ს უჭერს მხარს.<br/>• ჩართეთ WireGuard არსებულ Helm release-ში, რომელიც `cilium install`-მა შექმნა: `cilium upgrade --version 1.20.1 --set encryption.enabled=true --set encryption.type=wireguard --wait`.<br/>• გადატვირთეთ აგენტები (`kubectl -n kube-system rollout restart daemonset/cilium`): Helm მხოლოდ ConfigMap-ს ცვლის, ხოლო DaemonSet-ის შაბლონი უცვლელი რჩება.<br/>• შეამოწმეთ `cilium-config` (`enable-wireguard: "true"`) და ორივე Cilium agent-ის მზადყოფნა.<br/>• ConfigMap-ის პირდაპირი patch დასაშვებია მხოლოდ როგორც მოკლევადიანი სასწავლო baseline-ცდა სავალდებულო დადასტურებული rollback-ით. ნუ ეძებთ ბრძანებას `cilium encrypt enable`: კლიენტურ `cilium` CLI-ს ასეთი ქვებრძანება არ აქვს.<br/>• შეინახეთ agent-side `cilium-dbg encrypt status` და `cilium-dbg debuginfo --output json` `/var/work/tests/artifacts/4/cilium-encrypt-status.txt`-ში (`cilium-dbg status`-ს ფლაგი `--all-encryption` არ აქვს). |
| მიღების კრიტერიუმები | • Version evidence არსებობს და ემთხვევა DaemonSet `kube-system/cilium`-ის რეალურ image-ს<br/>• Cilium agents (DaemonSet) სრულად Ready-ა<br/>• Status აჩვენებს WireGuard-ს და ერთდროულად IPsec-ს არ აჩვენებს<br/>• Debuginfo JSON შეიცავს peer/allowed-IP (ან remote-node) evidence-ს node-თაშორისი მდგომარეობისთვის<br/>• ConfigMap `kube-system/cilium-config` შეიცავს `enable-wireguard: "true"`-ს როგორც Helm values-იდან გამოყენებულ effective-კონფიგურაციას<br/>• პარამეტრი უძლებს ერთი agent Pod-ის restart-ს (checker Pod-ს გადატვირთავს და სტატუსს ხელახლა ამოწმებს) |

<details>
<summary>💡 მინიშნება დავალება 4-ისთვის</summary>

გამოიყენეთ არსებული release `cilium`-ის Helm values როგორც WireGuard-ის ჩასართავად გრძელვადიანი source-of-truth, და არა ეფემერული ბრძანებები - Helm values-ის გარეთ გაკეთებულმა ცვლილებამ შეიძლება აგენტის restart-ს ან Helm release-ის განახლებას არ გაუძლოს, ხოლო ტესტი სპეციალურად ამოწმებს, რომ პარამეტრი restart-ს უძლებს. `cilium-dbg` გამოიძახება აგენტის Pod-ის შიგნით `kubectl exec`-ით, და არა როგორც ცალკე ლოკალური binary worker-ზე. `cilium-dbg status`-ს ფლაგი `--all-encryption` არ აქვს - peer/allowed-IP-ის დეტალური evidence-ისთვის გამოიყენეთ `cilium-dbg debuginfo --output json`.
</details>

---
| **5** | **plaintext-ის არარსებობის დამტკიცება node-ებს შორის** |
| :---: | :--- |
| რას ვაკეთებთ | • ააგეთ baseline-დადასტურება მანამდე/შემდეგ ერთსა და იმავე node-თაშორის flow-ზე.<br/>• **Baseline (WireGuard გამორთულია):** control-plane-ზე გაუშვით `tcpdump` დისტანციური node-ის IP-ით (`host <remote-node-ip>`, `udp port 51871`-ით წინასწარი ფილტრის გარეშე); დროებით გამორთეთ WireGuard (`enable-wireguard: "false"` `cilium-config`-ში, `rollout restart daemonset/cilium`); შეასრულეთ მოთხოვნა `runc-baseline -> gvisor-echo`; შეინახეთ ეს baseline-capture და დარწმუნდით, რომ მასში ჩანს plaintext `CKS110-WIREGUARD-MARKER`.<br/>• **შემდეგ (WireGuard ჩართულია):** აღადგინეთ `enable-wireguard: "true"`, დაელოდეთ Ready-ს და გაიმეორეთ იგივე მოთხოვნა იმავე capture scope-ით (`host <remote-node-ip>`, პორტის ფილტრის გარეშე).<br/>• Capture იღება control-plane-ზე (ფაილში node-ზე), შემდეგ `scp`-ით კოპირდება სამუშაო მანქანაზე `/var/work/tests/artifacts/5/wireguard-tcpdump.txt`-ში: მასში ახლა უნდა ჩანდეს მხოლოდ WireGuard UDP/`51871`, plaintext marker-ის გარეშე. |
| მიღების კრიტერიუმები | • საბოლოო (post-change) capture იმავე peer/interface scope-ით შეიცავს UDP/`51871`-ს, მაგრამ **არ** შეიცავს `CKS110-WIREGUARD-MARKER`-ს<br/>• გამოძახება სხვადასხვა node-ს შორის წარმატებით იღებს marker-ს HTTP-პასუხში<br/>• Checker დამოუკიდებლად იმეორებს post-change capture-ს იმავე peer/interface scope-ით (წინასწარ მხოლოდ `udp port 51871`-ით არ შემოიფარგლება), ასევე დამოუკიდებლად დროებით თიშავს და აღადგენს WireGuard-ს იმის საკუთარი baseline-დადასტურების მისაღებად, რომ იგივე flow plaintext-მდგომარეობაში wire-ზე marker-ს მართლაც ამჟღავნებს |

<details>
<summary>💡 მინიშნება დავალება 5-ისთვის</summary>

ტრაფიკი დაიჭირეთ node-ის რეალურ ფიზიკურ ქსელურ ინტერფეისზე (მაგალითად `eth0`), და არა Pod-ის ვირტუალურ ინტერფეისზე/veth-ზე ან Cilium-ის შიდა ინტერფეისზე `cilium_wg0` - `cilium_wg0` WireGuard-გვირაბის კონსტრუქციით უკვე გაშიფრულ ტრაფიკს ატარებს (ეს არის მისი დანიშნულება), ამიტომ `any`-ზე capture marker-ს იქ დაინახავს, მაშინაც კი, როცა ფიზიკურ NIC-ზე დაშიფვრა გამართულად მუშაობს. კონკრეტული ფიზიკური ინტერფეისი განსაზღვრეთ `ip route get <remote-node-ip>`-ით და გამოიყენეთ სწორედ ის. თუ capture Pod-ის გზის "შიგნით" მიდის WireGuard-ით დაშიფვრამდე, plaintext HTTP-ს დაინახავთ იმის მიუხედავად, ჩართულია თუ არა node-to-node დაშიფვრა. `tcpdump` გაუშვით ფონში HTTP-მოთხოვნის შესრულებამდე, და არა მის შემდეგ. Capture-ის ფილტრი მხოლოდ `udp port 51871`-ით წინასწარ გამორიცხავს plaintext TCP-ს შედეგიდან და ამიტომ მის არარსებობას არ ამტკიცებს - გამოიყენეთ `host <remote-node-ip>` პორტის ფილტრის გარეშე, რათა იმავე scope-მა WireGuard-ის ჩართვამდე/შემდეგ განსხვავება რეალურად აჩვენოს. Checker ასრულებს საკუთარ `tcpdump`-ს თავისი მოთხოვნის პარალელურად (baseline-ცდის ჩათვლით WireGuard-ის დროებითი გამორთვითა და დამოწმებული შემდგომი აღდგენით) - თქვენი artifact სასწავლო თვალსაზრისით სასარგებლოა, მაგრამ ერთადერთი დადასტურება არ არის: თუ დაშიფვრა შემოწმების მომენტში რეალურად არ მუშაობს, checker-ის live capture ამას თქვენი ფაილის შიგთავსისგან დამოუკიდებლად აღმოაჩენს.
</details>

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| რას ვაკეთებთ | • დააყენეთ დაფიქსირებული Istio `1.30.4` მომზადებული `istioctl`-იდან (საკმარისია minimal profile) და დააფიქსირეთ control plane-ის ვერსია.<br/>• `market`-ში შექმენით `market-api` Deployment და Service `market-api`: აპლიკაცია უსმენს `8080`-ს, service port დაარქვით `http`. `market-api` უნდა მუშაობდეს gVisor-node-ზე: `nodeSelector` `lab.cks.io/role: gvisor` და toleration მისი taint-ისთვის (`sandbox.runtime/gvisor=true:NoSchedule`).<br/>• შექმენით injected Deployment `market-client` `market`-ში და plaintext Pod `mesh-outside` `default`-ში; სამივე workload უნდა იყოს Running - `PeerAuthentication` STRICT-ის **გარეშე**.<br/>• **Baseline:** იმავე outside plaintext-მოთხოვნამ `market-api`-ზე უნდა მიიღოს HTTP 200 (mTLS ჯერ არ მოითხოვება); შეინახეთ ეს baseline-პასუხი ცალკე.<br/>• გამოიყენეთ `PeerAuthentication` `market-strict` namespace `market`-ში `mtls.mode: STRICT`-ით და გაიმეორეთ იგივე outside-მოთხოვნა: plaintext client sidecar-ის გარეშე არ უნდა მიიღოს წარმატებული application response, ხოლო in-mesh მოთხოვნამ უნდა მიიღოს HTTP 200.<br/>• შეინახეთ status/headers/exit code `artifacts/6/market-inside.txt`-სა და `market-outside.txt`-ში (ორივე ფაილის ბოლოში ჩაამატეთ სტრიქონი `exit_code=<curl-ის დასრულების კოდი>`); კონკრეტულ socket error-ის სტრიქონს ნუ შეადარებთ. |
| მიღების კრიტერიუმები | • Namespace ინარჩუნებს `istio-injection=enabled`-ს<br/>• `PeerAuthentication market-strict`-ს აქვს `STRICT`<br/>• mesh-ის შიგნით არის HTTP 200, ხოლო plaintext-გამოძახება mesh-ის გარეთ წარმატებულ HTTP-პასუხს არ იღებს (curl ვარდება, 2xx არ არის, `exit_code` ფაილში non-zero) - შეცდომის ზუსტი ტექსტის მიუხედავად<br/>• ორივე დადასტურება შენახულია, `market-inside.txt` შეიცავს `exit_code=0`-ს<br/>• plaintext client-ს sidecar-ით ნუ ჩაანაცვლებთ: სწორედ sidecar-ის არარსებობა ამტკიცებს STRICT-ის უარს.<br/>• Checker დამატებით დამოუკიდებლად იმეორებს მანამდე/შემდეგ: დროებით გადართავს იმავე policy-ს `PERMISSIVE`-ზე, იმეორებს იმავე plaintext-მოთხოვნას და მოითხოვს 200-ს - ეს ამტკიცებს, რომ წინა უარი გამოიწვია სწორედ STRICT mTLS-მა, და არა დამოუკიდებელმა DNS/network-პრობლემამ<br/>• შემდეგ checker აღადგენს `STRICT`-ს |

<details>
<summary>💡 მინიშნება დავალება 6-ისთვის</summary>

Service port უნდა ერქვას სწორედ `http` (და არა `market-api` ან სხვა რამ) - Istio იყენებს named port convention-ს პროტოკოლის განსაზღვრისა და ტრაფიკის sidecar-ით სწორად დამუშავებისთვის. `market-client` იქმნება მას შემდეგ, რაც namespace-მა `istio-injection=enabled` მიიღო, - თუ Deployment ამ label-მდე შეიქმნა, sidecar ავტომატურად არ დაემატება, და injection-ისთვის Pod-ის (და არა Deployment-ის) ხელახლა შექმნა მოგიწევთ.
</details>

## შედეგის შემოწმება

```bash
check_result
```

შემოწმება შეიცავს `0 Init`-ს და ექვს სავალდებულო ტესტს. ტესტები 1-3 ამოწმებენ
`RuntimeClass`-ს, placement-სა და `uname`-ის რეალურ განსხვავებას; ტესტები 4-5 ამოწმებენ WireGuard
status-ს, node-თაშორის მოთხოვნას და marker-ის არარსებობას tcpdump-ში; ტესტი 6 თავიდან ასრულებს ორივე
mTLS-გამოძახებას და ამოწმებს artifacts-ს. თუ Istio Pods ჯერ იქმნება, დაელოდეთ
`kubectl get pods -n market` `2/2 Running`-ს injected workload-ზე.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD).

## წაშლა

```bash
TASK=110 make delete_cks_task
```
