[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 115 - Cilium bootstrap, kube-proxy replacement და Mutual Authentication

> **Advanced / production track. ფორმალური CKS Core exam-ის მოთხოვნაში არ შედის.**
> ეს ლაბი CKS გამოცდის ფარგლებს სცილდება და სასარგებლოა როგორც production-უნარი: Cilium-ის
> დაყენება ნულიდან kube-proxy-ის სრული ჩამნაცვლებლის როლში, და Cilium Mutual Authentication
> SPIRE-ის საფუძველზე. თუ მხოლოდ გამოცდისთვის ემზადებით, პრიორიტეტია ლაბები 101-114.

## აღწერა

ამ ლაბის control-plane გაშლილია `kubeadm init --skip-phases=addon/kube-proxy`-ით - `kube-proxy`
DaemonSet-ის გარეშე და **დაყენებული CNI-ს გარეშე**. Node რჩება `NotReady`-ზე, სანამ თქვენ
Cilium-ს თავად არ დააყენებთ. ეს განზრახ არის ასე: ლაბი მთლიანად Cilium-ის ხელით დაყენებას ეხება kube-proxy-ის
სრული ჩამნაცვლებლის როლში (`kubeProxyReplacement`), WireGuard
transparent encryption-ის ინკრემენტულ ჩართვას და Cilium Mutual Authentication-ს SPIRE-ის საფუძველზე - ყოველი ნაბიჯი
ცალ-ცალკე ყენდება და მოწმდება, და მზა სახით არ გაიცემა.

`cilium`/`hubble` CLI უკვე დაყენებულია worker-ზე და რეალურ კლასტერზე მიუთითებს
(`~/.kube/config`), მაგრამ თავად Cilium-ის კლასტერში დაყენებას თქვენ თვითონ ასრულებთ.

## განთავსება

```bash
TASK=115 make run_cks_task
```

განთავსების შემდეგ დაუკავშირდით SSH-ით Terraform-ის გამოტანიდან ბრძანებით (`worker_pc_ssh`).
Node login-ის შემდეგ მაშინვე `NotReady` იქნება - ეს მოსალოდნელი baseline-ია, და არა შეცდომა.

## მიზანი

Cilium-ის დაყენება როგორც kube-proxy-ის სრული ჩამნაცვლებლისა უკვე გაშლილ kube-proxy-free
kubeadm-კლასტერზე, WireGuard encryption-ის ჩართვა, Cilium Mutual Authentication-ის ჩართვა
(SPIRE), და `CiliumNetworkPolicy`-ის დაწერა, რომელიც ორ namespace-ს შორის წარმატებულ mutual authentication-ს
მოითხოვს.

## ინფრასტრუქტურა

| კომპონენტი | დანიშნულება |
| --- | --- |
| control-plane EC2 | kubeadm-კლასტერი kube-proxy-ისა და CNI-ს გარეშე ლაბის გაცემის მომენტში |
| `ingress-115` | კლიენტის namespace, რომელმაც mutual authentication უნდა გაიაროს |
| `app-115` | backend-ის namespace, დაცული CiliumNetworkPolicy-თი `authentication.mode: required`-ით |
| worker EC2 | `cilium`/`hubble` CLI, გამართული kubeconfig |

## დავალებები

---

|           **1**           | **Baseline: kube-proxy-free, CNI-ს გარეშე** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       რას ვაკეთებთ       | • დაადასტურეთ კლასტერის მიმდინარე მდგომარეობა, სანამ რაიმეს დააყენებთ |
| მიღების კრიტერიუმები | • `kube-proxy` DaemonSet არ არსებობს<br/>• Cilium-ის დაყენებამდე ჩანს საწყისი `NotReady`<br/>• Checker ყველა დავალების შესრულების შემდეგ ადასტურებს kube-proxy-ის არარსებობასა და API-ს ხელმისაწვდომობას, და არა ისტორიულ `NotReady`-ს |
|        შემოწმება        | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`. `kubectl get nodes` -> `NotReady` (CNI არ არის). |

---

|           **2**           | **Cilium-ის დაყენება როგორც kube-proxy-ის ჩამნაცვლებლისა** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       რას ვაკეთებთ       | • დააყენეთ `1.20.1` ვერსიის Cilium agent/chart worker-ზე დაყენებული `cilium` CLI ვერსიით `v0.19.7`, `kubeProxyReplacement=true`-ით და ცხადად მითითებული `k8sServiceHost`/`k8sServicePort`-ით, რომლებიც ნამდვილ API server-ზე მიუთითებს (არა Service ClusterIP-ზე - kube-proxy-ის გარეშე ტრაფიკი ClusterIP `kubernetes.default`-ზე API server-მდე არ აღწევს, სანამ თავად Cilium არ ამუშავდება) |
| მიღების კრიტერიუმები | • `KubeProxyReplacement: True/Strict` (აგენტის `cilium-dbg status`-ში)<br/>• Node ხდება `Ready`<br/>• ClusterIP Service მისაწვდომია kube-proxy-ის გარეშე |
|        შემოწმება        | `cilium status --wait`, `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep KubeProxyReplacement`, შემდეგ `kubectl get nodes` -> `Ready`. სატესტო Pod-იდან: `curl https://kubernetes.default.svc.cluster.local/`-მა უნდა მიიღოს HTTP response (და არა connection error). |

---

|           **3**           | **WireGuard transparent encryption** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       რას ვაკეთებთ       | • ჩართეთ `encryption.enabled=true`, `encryption.type=wireguard` უკვე დაყენებულ Cilium-ზე (`cilium upgrade`, და არა ნულიდან ხელახლა დაყენება) |
| მიღების კრიტერიუმები | • `Encryption: Wireguard` `cilium-dbg status`-ში და `enable-wireguard: "true"` Cilium ConfigMap-ში<br/>• გზა დავალება 2-დან არ რეგრესირებულა<br/>• ერთკვანძიანი სტენდი ადასტურებს WireGuard-ის ჩართულ კონფიგურაციას, მაგრამ არ ამტკიცებს დაშიფრულ node-თაშორის ტრაფიკს (Peers: 0) |
|        შემოწმება        | `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep Encryption`. გაიმეორეთ curl დავალება 2-დან - უნდა კვლავ მიიღოს HTTP response. |

---

|           **4**           | **Cilium Mutual Authentication (SPIRE)** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       რას ვაკეთებთ       | • ჩართეთ SPIRE-ის ჩაშენებული დაყენება თავად Cilium helm chart-ის გავლით: `authentication.mutual.spire.enabled=true`, `authentication.mutual.spire.install.enabled=true` |
| მიღების კრიტერიუმები | • `spire-server` StatefulSet-სა და `spire-agent` DaemonSet-ს აქვთ ყველა მოთხოვნილი Ready-replica namespace `cilium-spire`-ში |
|        შემოწმება        | `kubectl get pods -A \| grep spire` - ორივე ტიპის Pod `Running` და Ready მდგომარეობაშია. |

> **სტენდის თავისებურებები.** კლასტერში StorageClass არ არის, ამიტომ SPIRE-სერვერს ეფემერული
> საცავი სჭირდება (`authentication.mutual.spire.install.server.dataStorage.enabled=false`). Image
> `spire-server` მუშაობს uid 1000-ით და ვერ ქმნის socket-ს hostPath-დირექტორიაში `root:755` -
> გაუშვით ის root-ით (`authentication.mutual.spire.install.server.securityContext.runAsUser=0`).
> ასევე chart მოითხოვს `authentication.enabled=true`-ს. დეტალები - ეტალონურ ამოხსნაში.

---

|           **5**           | **CiliumNetworkPolicy სავალდებულო mutual authentication-ით** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       რას ვაკეთებთ       | • შექმენით `ingress-115` (client) და `app-115` (backend, label `app=backend`, Service `backend`)<br/>• შექმენით `CiliumNetworkPolicy backend-auth-required` `app-115`-ში: `endpointSelector` `app=backend`-ზე, ingress მხოლოდ namespace `ingress-115`-დან და `authentication.mode: required` ამ ingress-წესზე |
| მიღების კრიტერიუმები | • Policy ზუსტად ირჩევს backend-ს, შეიცავს ერთ ingress-წესს `ingress-115`-დან TCP/80-ზე `authentication.mode: required`-ით<br/>• დამატებითი ingress-წესები და შემოვლის გზები არ არის<br/>• Lab 115-ის იზოლირებულ სტენდზე backend-ზე მოქმედი სხვა namespaced/global network policies არ არის<br/>• Service `backend` მიმართულია Ready Pod `backend`-ზე |
|        შემოწმება        | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml` - შეამოწმეთ `authentication.mode: required` `ingress[0]`-ის შიგნით. |

---

|           **6**           | **Positive/negative control: authenticated identity დაშვებულია, უცხო - არა** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       რას ვაკეთებთ       | • შეამოწმეთ policy-ის ეფექტი ცოცხალი ტრაფიკით: კლიენტმა `ingress-115`-დან უნდა მიაღწიოს `backend`-ს (წარმატებული SPIRE-based mutual auth handshake-ის შემდეგ)<br/>• ცალკე Pod „არასწორი“ namespace-იდან (`app-115`, და არა `ingress-115`; backend-ის ტრაფიკს საკუთარი თავისკენ Cilium ყოველთვის უშვებს) უნდა დაიბლოკოს |
| მიღების კრიტერიუმები | • იზოლირებულ სარკისებურ backend-ზე baseline უშვებს ორივე კლიენტს, policy-ის ასლის გამოყენების შემდეგ დაშვებულია მხოლოდ `ingress-115`<br/>• მოქმედი backend პასუხობს დაშვებულ კლიენტს, უარყოფს კლიენტებს `app-115`-დან და ახალი დამოუკიდებელი namespace-იდან<br/>• Cilium BPF auth map შეიცავს `spire`-ს კლიენტ/backend-ის identity-ების ზუსტი წყვილისთვის |
|        შემოწმება        | `curl` client-pod-იდან `ingress-115`-ში `http://backend.app-115.svc.cluster.local/`-ზე -> HTTP response. იგივე curl Pod-იდან `app-115`-ში კლიენტის label-ის გარეშე -> connection error. |

## შედეგის შემოწმება

```bash
check_result
```

Checker **არასდროს ხსნის მოქმედ** `app-115/backend-auth-required`-ს. baseline-ის შესამოწმებლად ის ქმნის დროებით სარკისებურ backend-სა და Service-ს ერთჯერად namespace `cks-115-*`-ში, ჯერ ამოწმებს დაშვებულ ტრაფიკს policy-ის გარეშე, შემდეგ იყენებს შემოწმებული CiliumNetworkPolicy-ის ასლს მხოლოდ სარკისებურ backend-ზე. ცალკე მოწმდება რეალური backend, EndpointSlice, SPIRE identity-ების ზუსტი წყვილები BPF auth map-ში და უცხო namespace-ებიდან კლიენტების აკრძალვა. ყველა შექმნილი Pod, Service, policy და დროებითი namespace იშლება cleanup-ის შემოწმებით.

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD).

## წაშლა

```bash
TASK=115 make delete_cks_task
```
