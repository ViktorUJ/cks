[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 105 - ეტალონური ამოხსნა: System Hardening ოპერაციული სისტემის და Docker-ის

> როგორ ვიმუშაოთ: ერთხელ ვუერთდებით node-ს `ssh`-ით და ბრძანებებს პირდაპირ მასზე ვასრულებთ (
> `sudo -i`-ით, რომ ყოველ ბრძანებამდე `sudo` არ დავწეროთ) - ეს უფრო სწრაფია, ვიდრე
> თითოეული ბრძანების ცალკე `ssh`-ით გაგზავნა, და გამოცდაზეც სწორედ ასე ღირს მუშაობა.
> control-plane node-ის სახელს ვხედავთ `kubectl get no`-თი:
>
> ```bash
> kubectl get no
> ssh <node-ის-სახელი-გამოტანიდან>
> sudo -i
> ```
>
> შემოწმებები და artifacts: checker კითხულობს artifacts-ს **სამუშაო მანქანიდან** (`worker`),
> `/var/work/tests/artifacts/<ნომერი>/`-ში, ამიტომ node-ზე შესწორებების შემდეგ გამოვდივართ (`exit`, `exit`) და
> artifact-ს ვინახავთ მოკლე ბრძანებით `worker`-დან. ამისთვის ერთხელ მიუთითეთ node-ის სახელი:
>
> ```bash
> CP=<node-ის-სახელი-გამოტანიდან>
> mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,9,10}
> ```
>
> Artifacts მხოლოდ ლაბის შესამოწმებლად არის საჭირო: გამოცდაზე მათ არ აქვთ ადგილი, იქ საკმარისია ბრძანებები
> node-ზე და შედეგის სწრაფი შემოწმება. ბრძანებები გამოტანას ფაილში ინახავენ (`>`), შიგთავსს ვუყურებთ
> ცალკე `cat <ფაილი>`-ით - მოსალოდნელი შედეგი მითითებულია კომენტარებში `# ...` ბლოკის ქვემოთ.
>
> Docker-ჰოსტზე შედიან ანალოგიურად: `ssh docker-host`, შემდეგ `sudo -i`.

## 1. არასაჭირო systemd-სერვისის გამორთვა

სერვისი `cks-lab105-unused.service` Kubernetes-ს არ სჭირდება და შეტევის ზედაპირს
ზრდის. შევაჩეროთ ის და ავკრძალოთ ავტოგაშვება.

control-plane-ზე:

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-unused.service
systemctl is-enabled cks-lab105-unused.service   # disabled
systemctl is-active cks-lab105-unused.service    # inactive
exit
exit
```

Artifact (`worker`-ზე):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-unused.service; systemctl is-active cks-lab105-unused.service' \
  | xargs > /var/work/tests/artifacts/1/service.txt
# disabled inactive
```

## 2. არასაჭირო TCP/8080-ის დახურვა

პორტი 8080 განზრახ არის გახსნილი სერვისით `cks-lab105-port.service`; ის არც
control-plane-ს სჭირდება, არც kubelet-ს. ვაჩერებთ და ვთიშავთ სერვისს - ორივე მოქმედება სავალდებულოა,
წინააღმდეგ შემთხვევაში listener reboot-ის შემდეგ დაბრუნდება, თუნდაც ახლა პორტი დახურული იყოს.

control-plane-ზე:

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-port.service
ss -ltn | grep 8080     # ცარიელი გამოტანა - პორტი დახურულია
exit
exit
```

Artifacts (`worker`-ზე):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-port.service; systemctl is-active cks-lab105-port.service' \
  | xargs > /var/work/tests/artifacts/2/service.txt
# disabled inactive
# პორტი უკვე შემოწმებულია node-ზე (`ss -ltn | grep 8080` - ცარიელია), ვაფიქსირებთ შედეგს:
echo 'tcp/8080: closed' > /var/work/tests/artifacts/2/port-8080.txt
```

## 3. შემომავალი ტრაფიკის შეზღუდვა UFW-ით

ჯერ ვადგენთ ტოპოლოგიას და საჭირო წყაროებს. ეს ერთკვანძიანი control-plane-ია,
რომელიც ასევე workload-ს უშვებს. Worker-ს უნდა ჰქონდეს SSH და API access; Pod CIDR-ს და თავად
node-ს - API access. node-თაშორისი kubelet/CNI flows აქ არ არის. `22`/`6443`-ს
`Anywhere`-ისთვის არ ვხსნით.

`worker`-ზე საჭირო მნიშვნელობებს თვალით ვუყურებთ:

```bash
kubectl get no -o wide                                      # node-ის INTERNAL-IP
kubectl get no "$CP" -o jsonpath='{.spec.podCIDR}{"\n"}'    # Pod CIDR
hostname -I                                                 # worker-ის IP
```

ვწერთ მათ preflight-ში (ჩასვით თქვენი მნიშვნელობები; სტრიქონი `role=` სავალდებულოა):

```bash
WORKER_IP=<worker-ის-ip>; NODE_IP=<node-ის-internal-ip>; POD_CIDR=<pod-cidr>
printf 'role=control-plane,workload\nworker_ip=%s\nnode_ip=%s\npod_cidr=%s\n' \
  "$WORKER_IP" "$NODE_IP" "$POD_CIDR" > /var/work/tests/artifacts/3/preflight.txt
```

Baseline UFW-მდე: ვამოწმებთ, რომ TCP/10250 (kubelet HTTPS) ახლა რეალურად მისაწვდომია - ამის გარეშე
"დაბლოკილია" UFW-ის შემდეგ არაფერს ამტკიცებს, პორტი შეიძლებოდა სხვა მიზეზით ყოფილიყო მიუწვდომელი
(security group, routing). Checker ცალკე ადარებს თავის baseline-ს, მაგრამ თქვენი
ჩანაწერიც საჭიროა:

```bash
curl -ks -o /dev/null -w '%{http_code}\n' --max-time 3 "https://$NODE_IP:10250/healthz"
# 401 - პორტი მისაწვდომია (ნებისმიერი 1xx-5xx, 401/403-ის ჩათვლით, გამოდგება)
echo 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=401' >> /var/work/tests/artifacts/3/preflight.txt
```

თუ baseline მიუწვდომელია (curl-მა დააბრუნა `000`) - ჯერ გაასწორეთ კავშირი, წინააღმდეგ შემთხვევაში შედეგი
UFW-ის შემდეგ დამაჯერებელი არ იქნება.

UFW-ის წესებს ვადგენთ node-ზე. ჯერ recovery-ს და საჭირო წყაროებს ვუშვებთ, და მხოლოდ
შემდეგ ვცვლით default-ს. მნიშვნელობებს `WORKER_IP`/`NODE_IP`/`POD_CIDR` ვიღებთ `preflight.txt`-დან
(ჩასვით თქვენი):

```bash
ssh "$CP"
sudo -i
WORKER_IP=<worker_ip>; NODE_IP=<node_ip>; POD_CIDR=<pod_cidr>
ufw allow from "$WORKER_IP" to any port 22 proto tcp comment 'CKS105 worker SSH recovery'
ufw allow from "$WORKER_IP" to any port 6443 proto tcp comment 'CKS105 worker API'
ufw allow from "$NODE_IP" to any port 6443 proto tcp comment 'CKS105 node API'
ufw allow from "$POD_CIDR" to any port 6443 proto tcp comment 'CKS105 Pod API'
ufw allow in on lo comment 'CKS105 loopback'
ufw default allow outgoing
ufw default deny incoming
ufw --force enable
ufw status verbose
exit
exit
```

Artifacts (`worker`-ზე). `ufw show added` - იმ წესების ნორმალიზებული წარმოდგენაა, რომლებიც
თქვენ რეალურად დაამატეთ (ბრძანებების საწყისი სახე/თანმიმდევრობა გარანტირებული არ არის - UFW მათ ნორმალიზებას უკეთებს
ჩვენებისას). შემოწმება ადარებს სწორედ ამ სიას მოსალოდნელ allowlist-თან - შეინახეთ ის
ასევე, ეს exact allow-set-ის ყველაზე საიმედო evidence-ია. firewall-ს მართეთ მხოლოდ `ufw`-ით -
`/etc/ufw/before*.rules` ან `/etc/ufw/after*.rules` ხელით ნუ დაარედაქტირებთ, ეს
framework-ფაილებია საერთო default-წესებით, და არა source-scoped rules-ის ადგილი; checker
ადარებს მათ hash-ს checker-owned bootstrap-baseline-თან და პირდაპირ რედაქტირებას შეამჩნევს.

```bash
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  > /var/work/tests/artifacts/3/ufw.txt
ssh "$CP" 'sudo ufw show added' \
  >> /var/work/tests/artifacts/3/ufw.txt

cat > /var/work/tests/artifacts/3/recovery.txt <<'EOF'
# შეასრულეთ ჯერ კიდევ ღია SSH/console session-იდან API-ს დაკარგვისას:
sudo ufw disable
sudo ufw status verbose
# გაასწორეთ ვიწრო allow rules, შეამოწმეთ source IP/CIDR
sudo ufw --force enable
# თუ წესები მთლიანად დაზიანებულია, მხოლოდ console/recovery channel-ით:
sudo ufw --force reset
EOF
```

ვამოწმებთ, რომ კლასტერი ჯანსაღია (`worker`-იდან):

```bash
kubectl get --raw=/readyz
kubectl get nodes
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=60s
# Workload-ს კლასტერის შიგნით ისევ უნდა შეეძლოს DNS-ის resolve და API server-ის მიღწევა
# (UFW-მ არ უნდა დაარღვიოს ტრაფიკი Pod -> CoreDNS და Pod -> API):
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default   # უნდა დააბრუნოს kubernetes სერვისის Address
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz   # ნებისმიერი კოდი, გარდა 000-ისა

# არასასურველმა worker -> kubelet flow-მ HTTP response არ უნდა მისცეს.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000 - ტრანსპორტული deny
```

სავალდებულო სრული E2E retest `ufw reload`-ის შემდეგ - ამტკიცებს, რომ ruleset reload-ს
უძლებს, და არა მხოლოდ `ufw enable`-ის მყისვე შემდეგ მუშაობს მეხსიერებაში. ამ ნაბიჯის გარეშე შეიძლება
შემთხვევით მიიღოთ ცრუ PASS enable-ის შემდეგვე:

```bash
ssh "$CP" 'sudo ufw reload'
sleep 2
kubectl get --raw=/readyz
kubectl get nodes
kubectl get pods -n kube-system -l k8s-app=calico-node
# Workload-ის იგივე ორ შემოწმებას reload-ის შემდეგაც ვიმეორებთ:
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz
# იგივე კონტრაქტი, რაც reload-მდე: worker კვლავ ვერ აღწევს kubelet-ს.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000
```

declared vs effective შემოწმება: `ufw show added` - დეკლარაციული სიაა, აღდგენილი
`### tuple ###` მეტამონაცემებიდან, რომლებსაც ufw თავად წერს `user.rules`-ში წესის CLI-ით
დამატებისას. ბირთვის რეალური მდგომარეობა `ufw reload`-ის შემდეგ კი ის არის, რასაც აჩვენებს
`ufw show user-rules`. შეადარეთ არა მხოლოდ სტრიქონების რაოდენობა, არამედ მათი შიგთავსიც
(source/port/proto): `ufw-user-input` უნდა აჩვენებდეს loopback-ს (all, lo) და სამ tcp
dpt:22/6443 წესს ზუსტი source-მისამართებით, ხოლო `ufw6-user-input` - ზუსტად ერთ სტრიქონს, იგივე
loopback ACCEPT-ს v6-ისთვის (`ufw allow in on lo` - წესია ინტერფეისის მიხედვით აშკარა IP-ის გარეშე,
ამიტომ ufw ყოველთვის ქმნის როგორც v4-, ისე v6-ვერსიას). ნებისმიერი სხვა/დამატებითი სტრიქონი იქ -
გარეშე bypass-ია:

```bash
ssh "$CP" 'sudo ufw show user-rules'
```

გამოტანაში უნდა იყოს `Status: active`, `Default: deny (incoming)` და source-scoped rules -
როგორც `ufw status verbose`-ში, ისე დეკლარაციულ სიაში `ufw show added`. საწყის SSH session-ს ნუ დახურავთ,
სანამ `/readyz`, nodes, calico-node, workload (Pod DNS-ის ჩათვლით reload-მდე და
შემდეგ) და `10250`-ის ორივე უარყოფითი შემოწმება (`ufw reload`-მდე და შემდეგ, იმავე
CURL_EXIT/HTTPCODE კონტრაქტით) მოსალოდნელ შედეგს არ მისცემს.

## 4. ადმინისტრატორის kubeconfig-ის დაცვა

`/etc/kubernetes/admin.conf` შეიცავს cluster-admin credential-ს. მისი წაკითხვა უნდა შეეძლოს
მხოლოდ root-ს.

control-plane-ზე:

```bash
ssh "$CP"
sudo -i
chown root:root /etc/kubernetes/admin.conf && chmod 600 /etc/kubernetes/admin.conf
stat -c '%U %G %a' /etc/kubernetes/admin.conf   # root root 600
exit
exit
```

Artifact (`worker`-ზე):

```bash
ssh "$CP" "stat -c '%U %G %a' /etc/kubernetes/admin.conf" \
  > /var/work/tests/artifacts/4/admin-conf.txt
# root root 600
```

## 5. root login-ის პირდაპირი აკრძალვა SSH-ით

ვცვლით კონფიგურაციას, reload-მდე ვამოწმებთ სინტაქსს და ვიყენებთ მიმდინარე
სესიის გაწყვეტის გარეშე.

control-plane-ზე:

```bash
ssh "$CP"
sudo -i
sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
sshd -t && systemctl reload ssh
```

მიმდინარე სესია `reload ssh`-ისას არ წყდება. მაგრამ sshd-ის გადატვირთვის დროს control-plane-ზე ახალმა
დაკავშირებამ შეიძლება 1-2 წამით მიიღოს `Connection refused` - ეს
ნორმალურია და არ ნიშნავს, რომ კონფიგურაცია გაფუჭებულია (მას უკვე `sshd -t` ამოწმებდა), უბრალოდ
გაიმეორეთ ბრძანება.

`sshd -T` connection context-ის გარეშე `Match`-ბლოკებს საერთოდ არ იყენებს - man `sshd(8)`
პირდაპირ ამბობს, რომ `Match` test mode-ში გამოიყენება მხოლოდ მაშინ, როცა `-C` არის გადაცემული. ამიტომ
ვამოწმებთ `-C`-ით, worker-იდან რეალური root-კავშირის სიმულაციით (მისამართებს ვიღებთ
`preflight.txt`-დან დავალება 3-იდან):

```bash
sshd -T -C 'user=root,addr=<worker_ip>,laddr=<node_ip>,lport=22' | grep -i permitrootlogin
# permitrootlogin no
exit
exit
```

Artifact (`worker`-ზე, რამდენიმე წამიანი პაუზის შემდეგ):

```bash
# WORKER_IP და NODE_IP - იგივე მნიშვნელობებია, რაც დავალება 3-ში
ssh "$CP" "sudo sshd -T -C 'user=root,addr=${WORKER_IP},laddr=${NODE_IP},lport=22' | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
  > /var/work/tests/artifacts/5/sshd.txt
# PermitRootLogin no
```

## 6. Docker daemon-ზე არაუსაფრთხო წვდომის დახურვა `docker-host`-ზე

TCP/2375-ს არ აქვს TLS და ავტენტიფიკაცია: მასზე წვდომა პრაქტიკულად root-წვდომის ტოლფასია
ჰოსტზე. ვშლით სასწავლო systemd override-ს TCP listener-ით, unix-სოკეტის მფლობელს ვადგენთ
socket override-ით და ვშლით `developer`-ს ჯგუფიდან `docker`.

ცვლილებებს ვიყენებთ სრული `daemon-reload` + **ორივე** unit-ის restart-ით - ეს
სავალდებულო ნაბიჯია, და არა უბრალოდ "კონფიგის ხელახლა წაკითხვა": რეალური restart-ის გარეშე შეიძლება შემთხვევით
"გაიაროთ" შემოწმება, თუ Docker უბრალოდ პასუხს შეწყვეტს (მაშინ TCP/2375 დახურულია არა იმიტომ,
რომ `-H tcp://` ამოღებულია, არამედ იმიტომ, რომ daemon საერთოდ არ მუშაობს).

`docker-host`-ზე:

```bash
ssh docker-host
sudo -i
rm -f /etc/systemd/system/docker.service.d/10-cks-lab105-tcp.conf
install -d -m 0755 /etc/systemd/system/docker.socket.d
printf '[Socket]\nSocketGroup=root\nSocketMode=0660\n' > /etc/systemd/system/docker.socket.d/10-cks-lab105-socket.conf
gpasswd -d developer docker || true
systemctl daemon-reload
systemctl restart docker.socket
systemctl restart docker.service
chown root:root /var/run/docker.sock && chmod 660 /var/run/docker.sock
```

Positive control: Docker restart-ის შემდეგ რეალურად მუშაობს (არა უბრალოდ 2375-ს არ უსმენს - ის
სრულფასოვნად უნდა ფუნქციონირებდეს unix-სოკეტით):

```bash
systemctl is-active docker.service docker.socket   # active / active
docker version && docker info >/dev/null
```

Persistent config check - effective unit არ შეიცავს `-H tcp://`-ს, ხოლო socket override რეალურად
ადგენს საჭირო მნიშვნელობებს (და არა უბრალოდ დროებით ემთხვევა მათ):

```bash
systemctl cat docker.service | grep -c "H tcp://"   # 0
systemctl cat docker.socket                          # ... SocketGroup=root ... SocketMode=0660 ...
```

დავალების კონტრაქტი 2375 პორტზე ფართოა: Docker API არც ერთ პორტზე არ უნდა უსმენდეს TCP-ს, ხოლო
`docker.socket` არ უნდა შეიცავდეს TCP `ListenStream`-ს:

```bash
ss -ltnp | grep -E 'dockerd|docker\.socket'    # ცარიელი გამოტანა
systemctl cat docker.socket | grep ListenStream # მხოლოდ /run/docker.sock (და ცარიელი reset)
stat -c '%U %G %a' /var/run/docker.sock         # root root 660
sudo -u developer docker ps                     # permission denied
exit
exit
```

Artifacts (`worker`-ზე):

```bash
# პორტი 2375 უკვე შემოწმებულია docker-host-ზე (`ss -ltnp | grep dockerd` - ცარიელია), ვაფიქსირებთ შედეგს:
echo 'tcp/2375: closed' > /var/work/tests/artifacts/6/docker-tcp.txt
ssh docker-host "sudo stat -c '%U %G %a' /var/run/docker.sock" \
  > /var/work/tests/artifacts/6/docker-socket.txt
ssh docker-host 'if sudo -u developer docker ps >/dev/null 2>&1; then echo "developer docker ps: allowed"; else echo "developer docker ps: denied"; fi' \
  > /var/work/tests/artifacts/6/developer-access.txt
# tcp/2375: closed
# root root 660
# developer docker ps: denied
```

ყველა ნაბიჯის შესრულების შემდეგ გაუშვით `check_result`.

## 7. მოდულ `sctp`-ის ჩატვირთვის აკრძალვა

`sctp` ჩატვირთულია, მაგრამ ამ node-ზე არც kubeadm-ს, არც containerd-ს, არც Calico-ს არ სჭირდება. ვცდილობთ
უკვე ჩატვირთული მოდულის გამოტვირთვას, შემდეგ ნებისმიერ შემთხვევაში განმეორებით ჩატვირთვას ვბლოკავთ
როგორც `blacklist`-ით, ისე `install` override-ით. ორივე დირექტივა მოქმედებს
`modprobe`-ის დონეზე (alias resolution და აშკარა `modprobe sctp`) და ჩატვირთვის ჩვეულებრივ გზას აღმოფხვრის;
ისინი kernel-level enforcement-ს არ ანაცვლებენ (`insmod` ჩადებს მოდულს პირდაპირ syscall-ით
და `modprobe.d`-ს არ კითხულობს, ხოლო `modprobe --ignore-install`-ს შეუძლია `install`-ის გვერდის ავლა თანაბარი
root-წვდომის დროს) - ამ ლაბისთვის მნიშვნელოვანია სწორედ მოსალოდნელი ავტოჩატვირთვის გზის აღმოფხვრა, და არა
იმ მომხმარებლისგან დაცვის მოდელირება, რომელსაც node-ზე უკვე აქვს root.

**`modprobe -r sctp` შეიძლება არ შესრულდეს უკვე ცოცხალ კლასტერზე** - ეს მოსალოდნელია და
სტუდენტის შეცდომა არ არის. ბირთვის პროტოკოლური მოდულები (მათ შორის `sctp`) იღებენ persistent
per-network-namespace მითითებას (`try_module_get` pernet-ინიციალიზაციაში) ყოველი netns-ისთვის,
რომელიც მოდულის ჩატვირთვის მომენტში უკვე არსებობდა - ამ node-ზე უკვე მუშაობს Pod-ები
(calico, coredns, kube-system), ამიტომ `sctp` შეიძლება დარჩეს მდგომარეობაში `in use`
არანულოვანი refcount-ით და ცარიელი `/sys/module/sctp/holders`-ით (ანუ არ ფლობს სხვა მოდული -
რეკურსიულად გამოსატვირთი არაფერია). ამის გასწორება ყველა ამ Pod-ის გაჩერების გარეშე შეუძლებელია, რაც
დავალებაში არ შედის. მნიშვნელოვანია და სწორედ მოწმდება ის, რაც სტუდენტის კონტროლის ქვეშაა:
მოდული ხელახლა ვეღარ ჩაიტვირთება.

control-plane-ზე:

```bash
ssh "$CP"
sudo -i
modprobe -r sctp || true
printf 'blacklist sctp\ninstall sctp /bin/true\n' > /etc/modprobe.d/60-cks-sctp.conf
lsmod | grep sctp                       # შეიძლება ცარიელიც იყოს და არაცარიელიც - ორივე ვარიანტი დასაშვებია
modprobe --show-config | grep sctp      # install sctp /bin/true და blacklist sctp
exit
exit
```

Artifact (`worker`-ზე): მიმდინარე მდგომარეობა (`absent` ან `present`) და override ეფექტურ
modprobe config-ში:

```bash
ssh "$CP" '
{
  if lsmod | grep -q sctp; then echo "lsmod: present"; else echo "lsmod: absent"; fi
  modprobe --show-config | grep sctp
}' > /var/work/tests/artifacts/7/sctp.txt
# lsmod: absent   (ან lsmod: present - ორივე ვარიანტი დასაშვებია, იხ. ზემოთ)
# install sctp /bin/true
```

## 8. `protectKernelDefaults` და უსაფრთხო sysctl

ჯერ ვასწორებთ sysctl-ს - `protectKernelDefaults: true` აიძულებს kubelet-ს **გაშვებისას ჩავარდეს**,
თუ ბირთვის მიმდინარე მნიშვნელობები მის მოლოდინებს არ ემთხვევა, ამიტომ sysctl
უნდა გამოყენებულ იქნას kubelet-ის გადატვირთვამდე.

control-plane-ზე:

```bash
ssh "$CP"
sudo -i
printf 'kernel.unprivileged_bpf_disabled = 1\nvm.overcommit_memory = 1\n' > /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl kernel.unprivileged_bpf_disabled vm.overcommit_memory
```

ახლა kubelet-ის კონფიგურაციაში ვრთავთ `protectKernelDefaults`-ს და სერვისს ვტვირთავთ თავიდან:

```bash
grep -q '^protectKernelDefaults:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^protectKernelDefaults:.*/protectKernelDefaults: true/' /var/lib/kubelet/config.yaml \
  || echo 'protectKernelDefaults: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

Node უნდა დარჩეს `Ready` (`worker`-იდან):

```bash
kubectl get no
```

თუ kubelet ამ ნაბიჯის შემდეგ არ ადგება - შეამოწმეთ სწორედ თანმიმდევრობა: sysctl
უნდა იყოს გამოყენებული (`sysctl --system`), და არა მხოლოდ ფაილში ჩაწერილი, სანამ kubelet
გაშვებისას მათ შეამოწმებს.

## 9. ზედმეტი SUID-binary-ის პოვნა და განეიტრალება

`find` აჩვენებს როგორც სისტემურ SUID-binary-ებს (`sudo`, `passwd`, `mount` - მათ არ ვეხებით), ისე
სასწავლო `/usr/local/bin/cks-lab105-suid-tool`-ს, რომელიც ამ node-ზე Kubernetes-ის არც ერთ
კომპონენტს არ სჭირდება.

`/var/lib/containerd` გამოტანიდან გამორიცხულია: მისი overlayfs snapshot-გზები - ეს
container image-ის ფენების შიგთავსია, და არა ჰოსტზე დაყენებული binary-ები, და ისინი იცვლება ლაბის დროს
image-ის ნებისმიერი pull/extract-ისას, სტუდენტის მოქმედებებისგან დამოუკიდებლად.

Artifact `suid-before.txt` უნდა შეინახოთ **გასწორებამდე** (`worker`-ზე):

```bash
ssh "$CP" "sudo find / -xdev -perm -4000 -type f 2>/dev/null | grep -v '^/var/lib/containerd/'" \
  > /var/work/tests/artifacts/9/suid-before.txt
grep cks-lab105-suid-tool /var/work/tests/artifacts/9/suid-before.txt
```

SUID-ბიტს ვუხსნით მხოლოდ სასწავლო ფაილს (control-plane-ზე) და ვრწმუნდებით, რომ სისტემური
SUID-binary-ები არ შეხებია - `sudo`/`passwd` უნდა დარჩეს SUID-ბიტით, წინააღმდეგ შემთხვევაში ოპერაციული სისტემის ბაზისური
ფუნქციონალობა ირღვევა:

```bash
ssh "$CP"
sudo -i
chmod u-s /usr/local/bin/cks-lab105-suid-tool
stat -c '%a' /usr/local/bin/cks-lab105-suid-tool   # 755
stat -c '%a %n' /usr/bin/sudo /usr/bin/passwd      # 4755 ...
exit
exit
```

Artifact `suid-after.txt` (`worker`-ზე):

```bash
ssh "$CP" "stat -c '%a' /usr/local/bin/cks-lab105-suid-tool" \
  > /var/work/tests/artifacts/9/suid-after.txt
# 755
```

ყველა ნაბიჯის შესრულების შემდეგ გაუშვით `check_result`.

## 10. Core dumps-ის გამორთვა და SUID-პროცესების დაცვა

Core dump-ს შეუძლია შეიცავდეს secrets-სა და გასაღებებს პროცესის მეხსიერებიდან crash-ის მომენტში - მისი
აკრძალვა საჭიროა როგორც ჩვეულებრივი, ისე SUID-პროცესებისთვის. `fs.suid_dumpable`-ს ვამატებთ იმავე
ფაილში `/etc/sysctl.d/99-kubernetes.conf`, რომელიც დავალება 8-ში უკვე შეიქმნა - ცალკე
კონფლიქტურ კონფიგს არ ვქმნით.

Ubuntu-ზე `ulimit -c 0` და `fs.suid_dumpable=0` core dump-ის არარსებობას **არ გარანტირებენ**:
`man 5 core` პირდაპირ აფიქსირებს, რომ `RLIMIT_CORE` ბირთვის მიერ უგულებელყოფილია, თუ
`kernel.core_pattern` dump-ს userspace-handler-ზე pipe-ით მიმართავს (`|program`).
Ubuntu ნაგულისხმევად სწორედ ასეა გამართული - crash-ს Apport იჭერს და ინახავს
`/var/lib/apport/coredump/`-ში პროცესის `ulimit -c`-ის მიუხედავად. ერთადერთი საიმედო
გზა - თავად `kernel.core_pattern`-ის გადაფარვა ცნობილად არამომუშავე handler-ით.

Core dump-ის ზომას ასევე ვზღუდავთ პროცესების ლიმიტების დონეზე - ეს `suid_dumpable`/`core_pattern`-ისგან
ცალკე მექანიზმია (soft limit ჩვეულებრივი crash-ებისთვის კლასიკური
file-based ჩაწერისას, თუ ის ოდესმე აღდგება).

control-plane-ზე:

```bash
ssh "$CP"
sudo -i
printf 'fs.suid_dumpable = 0\nkernel.core_pattern = |/bin/false\n' >> /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern   # 0 / |/bin/false
printf '* hard core 0\n* soft core 0\n' >> /etc/security/limits.conf
```

`limits.conf` ვრცელდება ახალ login-სესიებზე PAM-ით, და არა უკვე გახსნილ shell-ზე -
ვამოწმებთ სწორედ ახალ სესიაში:

```bash
su - ubuntu -c 'ulimit -c'      # 0
exit
exit
```

Artifact `coredump.txt` (`worker`-ზე). მოიცავს controlled crash probe-ს: ვადასტურებთ, რომ
რეალური `SIGSEGV`-ის შემდეგ არ ჩნდება ახალი retained core dump - არც სტანდარტულ
მიმდინარე დირექტორიაში, არც Apport-ით:

```bash
ssh "$CP" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; sudo su - ubuntu -c 'ulimit -c'" \
  > /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" "cat /etc/sysctl.d/99-kubernetes.conf; cat /etc/security/limits.conf" \
  >> /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" '
before_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
sh -c "kill -SEGV \$\$" || true
sleep 2
after_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
if [ "$after_count" -le "$before_count" ]; then
  echo "crash-probe: no new retained core dump"
else
  echo "crash-probe: NEW core dump appeared after SIGSEGV"
fi
' >> /var/work/tests/artifacts/10/coredump.txt
# crash-probe: no new retained core dump
```

ყველა ნაბიჯის შესრულების შემდეგ გაუშვით `check_result`.
