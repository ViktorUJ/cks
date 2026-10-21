[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 - Kubeconfig contexts, client certificates და API exposure

## აღწერა

სტუდენტისთვის გაცემული kubeconfig შეიცავს რამდენიმე contexts-ს: სამუშაო `cluster1-admin@cluster1`-ს
და ორ ცნობილად არამუშას (`staging-admin@staging`, `legacy-admin@legacy`), რომლებიც არარსებულ
API server-ებზე მიუთითებს. `current-context` login-ის შემდეგ მაშინვე არამუშა `staging-admin@staging`-ზეა დაყენებული - ეს
განზრახ ასახავს გამოცდაზე რეალურ სიტუაციას, როცა კანდიდატს აძლევენ kubeconfig-ს რამდენიმე
context-ით და მას თავად უნდა გაარკვიოს, რომელია მათგან სამუშაო.

ცალკე იმავე kubeconfig-ში არის მომხმარებელი `cluster9-admin` სრულფასოვანი, რეალურად დაგენერირებული
თვითხელმოწერილი client certificate-ით (`client-certificate-data`/`client-key-data`). ეს სერტიფიკატი კლასტერში
არანაირ უფლებებს არ იძლევა (მისი CA-ს apiserver არავის ენდობა) - დავალება გასწავლით kubeconfig-იდან
client certificate-ის წაკითხვასა და გარჩევას, და არა მისით ავტენტიფიკაციას.

ასევე ლაბი ფარავს Service-ის შეტევის ზედაპირის შემცირების კლასიკურ სცენარს: ჯერ თქვენ შეგნებულად
ქმნით `NodePort` Service-ს (გარედან მისაღწევი control-plane node-ის IP-ზე), შემდეგ ამცირებთ მას
`ClusterIP`-მდე, ეფექტს ცოცხლად ამტკიცებთ ორივე მიმართულებით.

## განთავსება

მართვის მანქანაზე გაუშვით გარემო:

```bash
TASK=114 make run_cks_task
```

წარმატებული განთავსების შემდეგ Terraform გამოიტანს SSH-ბრძანებას worker-თან დასაკავშირებლად:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

დაუკავშირდით მხოლოდ Terraform-ის გამოტანიდან მისამართით:

```bash
ssh ubuntu@<IP>
```

იმუშავეთ worker-ზე. თითოეული ეტაპი თვითონ შეამოწმეთ; `check_result` გაუშვით დავალებების
შესრულების შემდეგ, ეტალონური ამოხსნა გახსენით მხოლოდ საკუთარი მცდელობის შემდეგ ან სირთულის შემთხვევაში.

## მიზანი

ისწავლოთ რამდენიმე კონტექსტის შემცველ kubeconfig-თან უსაფრთხოდ მუშაობა, client certificate-ის ამოღება და შემოწმება
მისი ავტენტიფიკაციისთვის გამოყენების გარეშე, და Service-ის exposure-ის შეგნებული მართვა
`NodePort` -> `ClusterIP` გადართვით.

## ინფრასტრუქტურა

| კომპონენტი | დანიშნულება |
| --- | --- |
| kubeconfig (`~/.kube/config`) | 4 context: 1 სამუშაო (`cluster1-admin@cluster1`), 2 decoy (`staging-admin@staging`, `legacy-admin@legacy`), 1 რეალური client certificate-ით (`cluster9-admin@cluster1`) |
| `cks-114` | თქვენი backend აპლიკაციისა და Service-ის namespace |
| control-plane EC2 | ერთკვანძიანი kubeadm-კლასტერი, CNI Calico |

## დავალებები

---

|           **1**           | **Kubeconfig context inventory** |
| :-----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       რას ვაკეთებთ       | • შეასრულეთ `kubectl config get-contexts`, განსაზღვრეთ მიმდინარე (არამუშა) `current-context`.<br/>• იპოვეთ რეალურად სამუშაო context და გადადით მასზე: `kubectl config use-context <name>`. |
| მიღების კრიტერიუმები | • `current-context` == `cluster1-admin@cluster1`.<br/>• ამ context-იდან API server-ზე მოთხოვნა რეალურად გადის (და არა უბრალოდ არსებობს ფაილში). |
|        შემოწმება        | `kubectl config current-context`, შემდეგ `kubectl get nodes` - უნდა დააბრუნოს node-ების რეალური სია, და არა connection error. |

---

|           **2**           | **Client certificate extraction** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       რას ვაკეთებთ       | • ამოიღეთ მომხმარებლის `cluster9-admin`-ის `client-certificate-data` kubeconfig-იდან, გაშიფრეთ base64 და გარჩიეთ სერტიფიკატი `openssl x509`-ით.<br/>• შეინახეთ შედეგი `/var/work/tests/artifacts/task2-cert.txt`-ში ფორმატით `KEY=VALUE`, თითო მნიშვნელობა თითო სტრიქონზე: `SHA256_FP`, `SUBJECT`, `ISSUER`, `NOTBEFORE`, `NOTAFTER`. |
| მიღების კრიტერიუმები | • ხუთივე მნიშვნელობა artifact-ში ემთხვევა იმას, რაც ამოღებულია `cluster9-admin`-ის საწყისი bootstrap-სერტიფიკატიდან.<br/>• Checker ადარებს საწყის fingerprint-ს, სერტიფიკატის უცვლელობას kubeconfig-ში და ყველა ხუთ ველს. |
|        შემოწმება        | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` გამოიტანს `sha256 Fingerprint=AA:BB:...` - artifact-ში ჩაწერეთ hex ორწერტილების გარეშე (რეგისტრს მნიშვნელობა არ აქვს). |

---

|           **3**           | **Baseline: NodePort exposure** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       რას ვაკეთებთ       | • შექმენით namespace `cks-114`.<br/>• შექმენით Deployment `backend` (მაგალითად `viktoruj/ping_pong:alpine` `SRV_PORT=80`-ით, label `app=backend`).<br/>• შექმენით Service `kubernetes-public` ტიპით `NodePort` პორტზე 80, აშკარა `nodePort: 30114`-ით.<br/>• **ნუ შეეხებით** `default/kubernetes` Service-ს. |
| მიღების კრიტერიუმები | • Backend რეალურად მისაწვდომია როგორც თავად node-იდან `<node-internal-ip>:30114`-ით, ისე კლასტერის შიგნით `kubernetes-public.cks-114.svc.cluster.local`-ით.<br/>• `default/kubernetes` რჩება `ClusterIP`.<br/>• დავალება 4 შემდეგ ამავე Service-ს `ClusterIP`-ად აქცევს, ამიტომ ლაბის ბოლოსთვის NodePort-მდგომარეობა უკვე აღარ ჩანს: ისტორიული NodePort-ფაზა მტკიცდება ორი HTTP 200 ცდით (worker-იდან და DNS-ით Pod-იდან), backend/EndpointSlice-ის შემოწმებითა და მონიტორით, რომელიც Service-ისა და Deployment-ის UID-ს ინახავს.<br/>• ჯერ დავალება 3 სრულად შეასრულეთ და დაელოდეთ ფაილს `/var/lib/cks-lab114-checker/nodeport-phase-seen`, რომელსაც მონიტორი ქმნის ორივე წარმატებული live-ცდის შემდეგ; მხოლოდ ამის შემდეგ შეასრულეთ დავალება 4. ფაილი ისტორიული ფაზის დადასტურებაა იმავე Service/Deployment-ისთვის. |
|        შემოწმება        | worker-იდან (კლასტერის გარედან): `curl http://<node-internal-ip>:30114/` -> HTTP 200.<br/>კლასტერის შიგნიდან (დროებითი Pod curl-ით): `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200. node-ის IP: `kubectl get nodes -o wide`. |

---

|           **4**           | **Reduce exposure: NodePort -> ClusterIP** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       რას ვაკეთებთ       | • შეცვალეთ `kubernetes-public` ტიპზე `ClusterIP`.<br/>• გახსოვდეთ: API server არ მოგცემთ `nodePort`-ის დატოვების საშუალებას ტიპის `ClusterIP`-ის დროს - ველი აშკარად უნდა მოიხსნას (`kubectl edit svc kubernetes-public` და წაშალეთ სტრიქონი `nodePort`, ან `kubectl patch` `$patch: replace`-ით მასივზე `ports`). |
| მიღების კრიტერიუმები | • გარე გზა `<node-internal-ip>:30114` ახლა ტრანსპორტულად დაბლოკილია (connection refused/timeout).<br/>• კლასტერის შიდა გზა ისევ მუშაობს.<br/>• Backend Pod რჩება Ready. |
|        შემოწმება        | worker-იდან: `curl -m5 http://<node-internal-ip>:30114/` -> კავშირის შეცდომა (და არა HTTP-კოდი).<br/>კლასტერის შიგნიდან: `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200 როგორც ადრე.<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`, არც ერთ პორტს `nodePort` არ აქვს. |

## შედეგის შემოწმება

```bash
check_result
```

Checker ამოწმებს `current-context`-სა და მისი მეშვეობით ცოცხალ მოთხოვნას API-ზე, დამოუკიდებლად იღებს და არჩევს
სერტიფიკატს `cluster9-admin`, ამოწმებს მას საწყის bootstrap fingerprint-თან მიმართებით და ადარებს თქვენს artifact-ს, ასევე ასრულებს გარე და კლასტერის შიდა HTTP 200 probe-ს, ამოწმებს Deployment-ს, EndpointSlice-სა და `default/kubernetes`-ის უცვლელობას. ისტორიულ NodePort-ფაზას ადასტურებს root-owned მონიტორი ორი live-ცდით Service-ის გადართვამდე; ClusterIP-ის მდგომარეობაში checker ამოწმებს live DNS-სა და NodePort-ის ტრანსპორტულ უარყოფას.

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD).

## წაშლა

```bash
TASK=114 make delete_cks_task
```
