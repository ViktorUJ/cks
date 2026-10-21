[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 106 - ეტალონური ამოხსნა: AppArmor და seccomp

> Kubernetes-ბრძანებები (`kubectl`) შეასრულეთ სამუშაო მანქანაზე (`worker`). ყველაფერი, რაც
> თავად node-ს ეხება (AppArmor, kubelet, `crictl`), გააკეთეთ **პირდაპირ node-ზე**: შედით `ssh`-ით ერთხელ
> და გახდით root (`sudo -i`) - ეს უფრო სწრაფია, ვიდრე თითოეული ბრძანების ცალკე
> `ssh control-plane '...'`-ით გაგზავნა, და გამოცდაზეც სწორედ ასე უნდა იმუშაოთ. Namespace
> `security-106` იქმნება დავალება 3-ში.
>
> ```bash
> ssh control-plane
> sudo -i
> # ... ბრძანებები node-ზე ...
> exit   # root-იდან
> exit   # node-იდან უკან worker-ზე
> ```
>
> Artifacts შემოწმება კითხულობს **სამუშაო მანქანიდან** (`/var/work/tests/artifacts/<ნომერი>/`), ისინი
> მხოლოდ ლაბისთვის არის საჭირო - გამოცდაზე მათ არ აქვთ ადგილი. ვინახავთ მათ მოკლე ბრძანებით `worker`-დან
> (`> ფაილი`), შიგთავსს ცალკე ვუყურებთ `cat <ფაილი>`-ით.

## 1. AppArmor profile-ის გადატანა და ჩატვირთვა

პროფილი მხოლოდ სამუშაო მანქანაზე დევს. ვაკოპირებთ მას node-ზე (`worker`-იდან), შემდეგ node-ზე
თავის ადგილზე ვდებთ და ბირთვში ვტვირთავთ. ფაილი უკვე შეიცავს ფლაგს `complain`, ამიტომ პირველადი ჩატვირთვისთვის
საკმარისია ერთი `apparmor_parser -r` (`aa-complain`-ის გარეშე, რომელიც, `aa-enforce`-ის მსგავსად,
პარსავს `/etc/apparmor.d/`-ის ყველა ფაილს და ჯერ კიდევ გატეხილ
`k8s-106-broken-profile`-ზე დავალება 9-იდან ჩავარდებოდა):

```bash
# worker-ზე
scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/k8s-106-deny-write

# node-ზე
ssh control-plane
sudo -i
mv /tmp/k8s-106-deny-write /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# მოსალოდნელია: "k8s-106-deny-write":	"complain",
```

## 2. AppArmor profile-ის enforce-ში გადაყვანა

Profile ახლა რეჟიმშია `complain` (ჩატვირთულია ამ ფლაგით დავალება 1-ში). ვრჩებით node-ზე
(root-ით) და სწორედ არსებულ profile-ს enforcing mode-ში გადავიყვანთ:

```bash
sed -i 's/, complain,/,/' /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# მოსალოდნელია: "k8s-106-deny-write":	"enforce",
# ჩვეულებრივი 'aa-status | grep ...' პროფილის რეჟიმს არ აჩვენებს: ტექსტურ გამოტანაში პროფილები
# დაჯგუფებულია სათაურებქვეშ ('N profiles are in enforce mode.'), სახელები სუფიქსის გარეშეა.
# კონკრეტული პროფილის შესამოწმებლად გამოიყენეთ 'aa-status --pretty-json' (ან '--json').
exit
exit
```

ამ პროფილისთვის `aa-enforce`/`aa-complain` და `apparmor-utils` პაკეტის პროფილების შეცვლის სხვა,
Python-ზე დაწერილი ინსტრუმენტები ნუ გამოიყენებთ, სანამ დავალება 9 არ შესრულებულა:
ისინი შიგნით იძახებენ `apparmor.read_profiles()`-ს, რომელიც გაშვებისას პარსავს
**ყველა** ფაილს `/etc/apparmor.d/`-ში, ჯერ ჩაუტვირთავი და ცნობილად
გატეხილი `/etc/apparmor.d/k8s-106-broken-profile`-ის ჩათვლით დავალება 9-იდან - და ვარდებიან
parser-ის შეცდომით სხვის ფაილზე, თქვენს პროფილამდე მისვლის ცდის გარეშეც. `apparmor_parser`
(binary, და არა Python-wrapper), პირდაპირ ერთი კონკრეტული ფაილით გამოძახებული, პარსავს
მხოლოდ მას და ამ პრობლემას არ განიცდის - სწორედ ამიტომ ვასწორებთ პროფილის ფლაგს
(ვშლით `complain`-ს `flags=(...)`-დან) ხელით `sed`-ით, შემდეგ კი სწორედ
ამ ფაილს ვტვირთავთ თავიდან `apparmor_parser -r`-ით.

`aa-status` - მდგომარეობის ნახვის ცალკე ინსტრუმენტია, და არა პროფილების შეცვლისა, და აქ ის
არ ეხება. კონკრეტული პროფილის რეჟიმს აჩვენებს `aa-status --pretty-json` (შემოწმებულია
ლაბის node-ზე, apparmor 3.0.4; `--json` იგივეს იძლევა ერთ სტრიქონში, მაგალითად
`aa-status --json | jq -r '.profiles["k8s-106-deny-write"]'`). ალტერნატივა - ბირთვის ფაილი
`grep -F 'k8s-106-deny-write' /sys/kernel/security/apparmor/profiles`: იქ ფორმატია
`name (enforce|complain)`.

## 3. Pod Localhost AppArmor-ით და ჩაწერის უარყოფით

შევქმნათ namespace და Pod. `emptyDir` უზრუნველყოფს `/work`-ის არსებობას; profile უშვებს
პროცესის გაშვებას, მაგრამ კრძალავს ჩაწერას ამ დირექტორიაში. Node selector აკავშირებს Pod-ს
node-თან, რომელზეც profile მართლაც ჩატვირთულია.

```yaml
# apparmor-writer.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security-106
---
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-writer
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-106-deny-write
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

```bash
# worker-ზე
kubectl apply -f apparmor-writer.yaml
kubectl get pod -n security-106 apparmor-writer
# დაელოდეთ STATUS Running-ს (გაიმეორეთ get), შემდეგ შეასრულეთ exec

# Evidence: პროფილი მართლაც მინიჭებულია PID 1 პროცესზე, და არა მხოლოდ Pod YAML-შია ჩაწერილი.
kubectl exec -n security-106 apparmor-writer -- cat /proc/1/attr/current
# k8s-106-deny-write (enforce)

# Positive control უარყოფამდე: დაშვებული read-ოპერაცია სწორედ იმავე /work-ზე,
# სადაც denial შემოწმდება - ამ ნაბიჯის გარეშე ჩაწერის უარყოფას ვერ გავარჩევდით
# სრულიად არამომუშავე mount/mountPath-ისგან (ამ შემთხვევაში წაკითხვაც მიუწვდომელი იქნებოდა).
kubectl exec -n security-106 apparmor-writer -- sh -c 'ls /work'

# Negative control: denial უნდა იყოს სწორედ AppArmor-ის მიერ ჩაწერის უარყოფა.
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# მოსალოდნელია არანულოვანი კოდი: Permission denied / Operation not permitted
```

არანულოვანი exit code და ტექსტი 'permission denied' თავისთავად **არ** ამტკიცებს, რომ სწორედ
AppArmor-ის ამ წესმა იმუშავა - ჩვეულებრივი DAC/filesystem შეცდომა shell-ის
თვალსაზრისით იდენტურად გამოიყურებოდა. უარყოფა სწორედ ამ profile-თან დააკავშირეთ kernel audit log-ის გავლით; მას
ვუყურებთ node-ზე ზემოთ ცდისთანავე:

```bash
# node-ზე
ssh control-plane
sudo -i
journalctl -k --no-pager -n 500 | grep -F 'apparmor="DENIED"' | grep -F 'profile="k8s-106-deny-write"' | grep -F 'cks-106-denied.txt'
# მოსალოდნელია ჩანაწერი ასეთი სახით: ... apparmor="DENIED" ... profile="k8s-106-deny-write" name=".../cks-106-denied.txt" ... denied_mask="c" ... (mknod: ფაილის შექმნა; არსებულ ფაილში ჩაწერისას იქნება "w")
exit
exit
```

თუ `/proc/1/attr/current` კონკრეტულ runtime-ში მიუწვდომელია, დააფიქსირეთ ეს და დაეყრდენით
Localhost profile-ის მინიჭებას kernel `apparmor="DENIED"`-თან ერთად ამ profile-ისთვის;
ერთი არანულოვანი კოდი ამ evidence-ის გარეშე არასაკმარისია, რადგან მას mount-მაც შეუძლია მისცეს ან ჩვეულებრივმა
Unix permission-მა.

## 4. RuntimeDefault ჩვეულებრივი Pod-ისთვის

`RuntimeDefault` - გადატანადი baseline-ია, რომელსაც containerd/runtime-ის სტანდარტული
პროფილი ირჩევს. ველი აშკარად არის მითითებული Pod-ის დონეზე.

```yaml
# runtime-default.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
# worker-ზე
kubectl apply -f runtime-default.yaml
kubectl get pod -n security-106 runtime-default
kubectl exec -n security-106 runtime-default -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2
```

## 5–6. Localhost seccomp და `unshare`-ის ბლოკირების დამტკიცება

ფაილი მხოლოდ სამუშაო მანქანაზე დევს, `/opt/lab106-fixtures/cks-106-deny-unshare.json`-ში.
ვაკოპირებთ მას node-ზე (`worker`-იდან) და ვდებთ kubelet seccomp root-ში (node-ზე):

```bash
# worker-ზე
scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/cks-106-deny-unshare.json

# node-ზე
ssh control-plane
sudo -i
mkdir -p /var/lib/kubelet/seccomp/profiles
mv /tmp/cks-106-deny-unshare.json /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json
jq empty /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json && echo valid
exit
exit
```

API-ში ვუთითებთ გზას seccomp root-ის მიმართ: `profiles/cks-106-deny-unshare.json`.

`SYS_ADMIN` აქ - განზრახ სახიფათო გამონაკლისია მხოლოდ ლაბისთვის (control-ს seccomp-ის გარეშე checker ამოწმებს). Custom
filter-ის გარეშე `unshare -n` ამ capability-ით შეიძლება იმუშაოს; seccomp-მა უნდა დააბრუნოს `EPERM`.
ეს არ არის hardened combination. `allowPrivilegeEscalation: false` რთავს `no_new_privs`-ს, მაგრამ
პროცესისთვის უკვე გაცემულ capabilities-ს არ ართმევს, ამიტომ ამ ველს `SYS_ADMIN`-ის
«კომპენსაციად» არ ვიყენებთ. Production-ში ასეთ capability-ს შლიან, თუ დამტკიცებული
აუცილებლობა არ არსებობს. Kubernetes-ში capability იწერება როგორც `SYS_ADMIN`, პრეფიქსის `CAP_` გარეშე.

ვიყენებთ `unshare -n` (network namespace, `CLONE_NEWNET`), და არა `unshare -m` (mount
namespace). ორივე ოპერაცია ერთსა და იმავე `CAP_SYS_ADMIN`-ს მოითხოვს, მაგრამ BusyBox `unshare -m`
წარმატებული `unshare(2)`-ის შემდეგ დამატებით ასრულებს დამოუკიდებელ `mount(2)` syscall-ს
forced private propagation-ისთვის - ხოლო containerd default AppArmor-პროფილი (`RuntimeDefault`,
რომელსაც ეს Pod იღებს, რადგან აშკარა `appArmorProfile` აქ მითითებული არ არის) შეიცავს
`deny mount,`-ს ფლაგებზე რაიმე პირობის გარეშე, capabilities/seccomp-ისგან დამოუკიდებლად. ამიტომ
`unshare -m true` შეიძლება `EPERM`-ით ჩავარდეს AppArmor-ის გამო, თუნდაც seccomp საერთოდ არ
ზღუდავდეს `unshare`-ს - ასეთი probe ორ განსხვავებულ security control-ს აერთიანებდა. `unshare -n`
იძახებს მხოლოდ თავად syscall-ს `unshare(2)`, გვერდითი `mount()`-ის გარეშე.

```yaml
# localhost-seccomp.yaml
apiVersion: v1
kind: Pod
metadata:
  name: localhost-seccomp
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/cks-106-deny-unshare.json
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      if unshare -n true 2>/tmp/unshare.err; then
        echo 'unshare unexpectedly succeeded' >/tmp/unshare-result
        exit 1
      fi
      grep -Eqi 'operation not permitted|permission denied' /tmp/unshare.err
      echo 'unshare denied by seccomp' >/tmp/unshare-result
      exec sleep 3600
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
```

```bash
# worker-ზე
kubectl apply -f localhost-seccomp.yaml
kubectl get pod -n security-106 localhost-seccomp
kubectl exec -n security-106 localhost-seccomp -- cat /tmp/unshare-result
# unshare denied by seccomp

kubectl exec -n security-106 localhost-seccomp -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2

kubectl exec -n security-106 localhost-seccomp -- unshare -n true
# მოსალოდნელია არანულოვანი კოდი: Operation not permitted / Permission denied
```

## 7. User namespaces: `hostUsers: false` და `uid_map`

`hostUsers: false` სთხოვს kubelet-ს, Pod-ს ცალკე user namespace გამოუყოს: root (UID 0)
კონტეინერის შიგნით აისახება host-ის არაპრივილეგირებულ UID-დიაპაზონზე. `runAsUser`-ს არ ვადგენთ,
რათა პროცესი რეალურად UID 0-ით გაეშვას namespace-ის **შიგნით** - სწორედ ეს
შემთხვევა აჩვენებს ტრანსლაციას, და არა პრივილეგიების თავიდანვე არარსებობას.

```yaml
# userns-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: userns-probe
  namespace: security-106
spec:
  hostUsers: false
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# worker-ზე
kubectl apply -f userns-probe.yaml
kubectl get pod -n security-106 userns-probe
mkdir -p /var/work/tests/artifacts/6

kubectl exec -n security-106 userns-probe -- id > /var/work/tests/artifacts/6/userns.txt
cat /var/work/tests/artifacts/6/userns.txt
# uid=0(root) gid=0(root) groups=0(root)
```

კონტეინერის host PID არ ემთხვევა კონტეინერის შიგნით PID-ს და `kubectl`-ით პირდაპირ არ ჩანს.
კონტეინერის ID-ს ვიღებთ worker-ზე, ხოლო PID-ს ვიღებთ `crictl inspect`-ით იმ node-ზე,
სადაც Pod რეალურად გაშვებულია:

```bash
# worker-ზე
kubectl get pod userns-probe -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}'
# containerd://<ID> - დააკოპირეთ <ID> პრეფიქსის containerd:// გარეშე

# node-ზე
ssh control-plane
sudo -i
crictl inspect <ID> | jq -r '.info.pid'
# მაგალითად: 15205 - ეს არის <host PID>
```

`/proc/<host PID>/uid_map` node-ზე აღწერს ტრანსლაციას: სამი რიცხვი - `<container-uid-start>
<host-uid-start> <length>`. `hostUsers: false`-ისთვის პირველი სტრიქონი უნდა იწყებოდეს `0`-ით
(container UID 0), მაგრამ host-uid-start უნდა იყოს **არანულოვანი** - სწორედ ეს არის
host-ის არაპრივილეგირებული დიაპაზონი, ხოლო `length` - სტანდარტული per-Pod ბლოკი `65536` UID.

```bash
# node-ზე (root-ით)
cat /proc/<host PID>/uid_map
# 0 1349844992 65536   (host-uid-start ყოველ Pod-ზე თავისია, მთავარია - არა 0)
exit
exit
```

ვინახავთ `uid_map` სტრიქონს artifact-ში (`worker`-ზე):

```bash
ssh control-plane "sudo cat /proc/<host PID>/uid_map" >> /var/work/tests/artifacts/6/userns.txt
```

თუ `host-uid-start` უდრის `0`-ს - user namespace არ გამოყენებულა (მაგალითად,
შეუთავსებელი containerd/runc-ის ან რეალურად გამოყენებულ Pod-ში `hostUsers: false`-ის
არარსებობის გამო) - ეს hardening არ არის, არამედ ჩვეულებრივი root ჰოსტზე. შედარებისთვის: ჩვეულებრივ Pod-ს
`hostUsers: false`-ის გარეშე ფაილი `/proc/<host-PID>/uid_map` ასევე აქვს, მაგრამ პროცესი რჩება
host (initial) user namespace-ში. ამიტომ mapping იწყება UID 0 -> host UID 0-ით (ჩვეულებრივ
სტრიქონი ასეთი სახით `0 0 4294967295`, მაგალითად `cat /proc/1/uid_map` node-ზე), და არა
არაპრივილეგირებული per-Pod host UID-ით. `userns-probe`-ს `hostUsers: false`-ით ველით
საპირისპიროს: `0 <არანულოვანი-host-uid> <დიაპაზონი-per-pod>`.

## 8. `seccompDefault: true` kubelet-ზე

ყველა წინა Pod აშკარად ადგენდა `seccompProfile`-ს. აქ ვამოწმებთ node-level baseline-ს:
თუ დეველოპერი ამ ველს დაივიწყებს, kubelet-მა თავად უნდა გამოიყენოს `RuntimeDefault`, და არა
პროცესი `Unconfined` დატოვოს. ვასწორებთ kubelet-ის კონფიგურაციას node-ზე:

```bash
# node-ზე
ssh control-plane
sudo -i
grep -q '^seccompDefault:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^seccompDefault:.*/seccompDefault: true/' /var/lib/kubelet/config.yaml \
  || echo 'seccompDefault: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

```bash
# worker-ზე: Node-ის სახელი API-ში არ არის alias 'control-plane' /etc/hosts-იდან, არამედ node-ის რეალური სახელია (ip-10-...)
kubectl get nodes     # Ready
```

ვქმნით Pod-ს `seccompProfile`-ის ერთი ხსენების გარეშე - არც Pod-ზე, არც container level-ზე:

```yaml
# no-seccomp-field.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-seccomp-field
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# worker-ზე
kubectl apply -f no-seccomp-field.yaml
kubectl get pod -n security-106 no-seccomp-field
kubectl exec -n security-106 no-seccomp-field -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2  -- kubelet-მა RuntimeDefault თავად გამოიყენა, manifest-ში ველის გარეშე

# შეამოწმეთ თავი kubelet-ის რეალურად გამოყენებული კონფიგურაციით, და არა დისკზე ფაილის ტექსტით -
# drop-in-მა ან ბრძანების ხაზის ფლაგმა შეიძლებოდა მნიშვნელობა გადაეფარათ
# თავად config.yaml-ის შეცვლის გარეშე:
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" | jq '.kubeletconfig.seccompDefault'
# true
```

`seccompDefault: true`-ის გარეშე იგივე manifest მისცემდა `Seccomp: 0` (`Unconfined`) - ამის შემოწმება მარტივია,
ფლაგის უკან დაბრუნებით და Pod-ის ხელახლა შექმნით, თუ განსხვავებაში დარწმუნება გჭირდებათ.

## 9. გატეხილი AppArmor-პროფილის დებაგი

`/etc/apparmor.d/k8s-106-broken-profile` უკვე დისკზეა, მაგრამ არასდროს ჩატვირთულა: მასში მძიმე
აკლია წესის `deny /work/** w` შემდეგ. ჯერ შეცდომას ვპოულობთ ბირთვში ჩატვირთვის გარეშე.
`-p`/`--preprocess` აქ არ გამოდგება - ეს preprocessing-ია (ხსნის
`#include`-ს stdout-ში), და არა safe dry-run/syntax-check. ვიყენებთ `-Q`/`--skip-kernel-load`
(სრული კომპილაცია/შემოწმება ბირთვში ჩატვირთვის გარეშე) ან `-d`/`--debug`
(ერთხელ - მხოლოდ syntax check).

Artifact `apparmor-debug.txt` უნდა შეიცავდეს parser-ის **საწყის** შეცდომას, ამიტომ
ვინახავთ მას გასწორებამდე (`worker`-ზე):

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile' \
  > /var/work/tests/artifacts/8/apparmor-debug.txt 2>&1
cat /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

ვიყენებთ `sudo`-ს compile-only შემოწმებისთვისაც `-Q`: ლაბის node-ზე (apparmor 3.0.4, Ubuntu)
პრივილეგიების გარეშე parser ყოველი გაშვებისას ცდილობს policy cache-ის გამართვას
`/var/cache/apparmor`-ში და ვარდება "Failed setting up policy cache (/var/cache/apparmor):
Permission denied"-ით სინტაქსის შემოწმებამდე - რეალური სინტაქსური შეცდომის ნაცვლად
მიიღებთ მატყუარა შეცდომას უფლებების შესახებ, ხოლო `apparmor-debug.txt` არ შეიცავს საჭირო ტექსტს
"syntax error". შემოწმებულია თავად node-ზე, ცნობილად გატეხილ პროფილზეც.
ალტერნატივა `sudo`-ს გარეშე - დაამატეთ `-K`/`--skip-cache` (`apparmor_parser -Q -K ...`): ქეშირების გარეშე
parser პროფილის გარჩევამდე აღწევს. `sudo` ამ ლაბში არჩეულია შემდგომ `-r`-თან ერთიანი
workflow-სთვის, რომელიც ნებისმიერ შემთხვევაში პრივილეგიებს მოითხოვს.

ვასწორებთ node-ზე: AppArmor-წესი აუცილებლად მძიმით უნდა მთავრდებოდეს. შემდეგ ვტვირთავთ
გასწორებულ პროფილს ბირთვში - სწორედ `-r -v` (reload + verbose), და არა `-Q`/`-p`, რომლებიც
არაფერს ტვირთავენ:

```bash
# node-ზე
ssh control-plane
sudo -i
sed -i 's/^\(\s*deny \/work\/\*\* w\)$/\1,/' /etc/apparmor.d/k8s-106-broken-profile
tail -5 /etc/apparmor.d/k8s-106-broken-profile
apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile
aa-status --pretty-json | grep k8s-106-broken-profile
# მოსალოდნელია: "k8s-106-broken-profile":	"enforce",
```

საბოლოო შემოწმება, რომ ფაილი ახლა შეცდომების გარეშე ვალიდურია:

```bash
apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile
echo "exit: $?"
# exit: 0
exit
exit
```

ახლა `worker`-ზე ჩაამატეთ ჩატვირთვის დადასტურება გასწორების შემდეგ იმავე artifact-ში:

```bash
ssh control-plane 'sudo aa-status --pretty-json' | grep k8s-106-broken-profile >> /var/work/tests/artifacts/8/apparmor-debug.txt
cat /var/work/tests/artifacts/8/apparmor-debug.txt
```

ბოლოს გაუშვით (`worker`-ზე):

```bash
check_result
```
