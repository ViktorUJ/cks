[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 103 - ეტალონური ამოხსნა

> ბრძანებები სრულდება worker-ზე, თუ აშკარად არ არის მითითებული `control-plane`. static Pod manifests-ის
> რედაქტირებამდე შეინახეთ ასლები. Kubelet თავად შეამჩნევს ფაილების ცვლილებას და თავიდან შექმნის
> შესაბამის static Pods; ნუ წაშლით მათ Kubernetes API-ს გავლით.
>
> გამოცდაზე `k` (`alias k=kubectl`) და bash-completion მისთვის უკვე გამართულია SSH-ჰოსტზე -
> დრო ნუ დაკარგავთ მათ გამართვაზე, უბრალოდ გამოიყენეთ `k` (იხ. თავი 33.6).

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
k config use-context "$CTX"
ssh control-plane hostname
```

## დავალება 1. kube-bench-ის ანგარიში

`kube-bench` `0.16.0` უკვე დაყენებულია `control-plane`-ზე (როგორც რეალურ გამოცდაზე, სადაც
CIS Benchmark tooling node-ებზე უკვე არის) - worker-იდან იქ მისი კოპირება არ არის საჭირო. Kubernetes
`1.36` kube-bench-ის ოფიციალურ support table-ში ჯერ არ არის; ამ ვერსიის ჩაშენებული version mapping
მთავრდება ჩანაწერით `"1.34": "cis-1.12"` - უფრო ახალი პროფილები (1.35/1.36-ის
რომელიმე პროფილის ჩათვლით) `0.16.0`-ში საერთოდ არ არის, ამიტომ ვიყენებთ სწორედ `cis-1.12`-ს
როგორც უახლოეს არსებულს. ჩვენ მას იძულებით ვუშვებთ როგორც approximate
hardening signal-ს, და არა როგორც authoritative CIS compliance assessment-ს.

```bash
mkdir -p /var/work/tests/artifacts/1
{
  printf 'kubernetes_version=%s\n' "$(k version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-1.12\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,node,controlplane,etcd,policies'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

grep '== Summary' /var/work/tests/artifacts/1/kube-bench.txt
# == Summary master ==
# == Summary node ==
# == Summary controlplane ==
# == Summary etcd ==
# == Summary policies ==
```

თვალით დარწმუნდით, რომ ხუთივე `== Summary <target> ==` არის - აშკარა
`--targets`-ის გარეშე მათგან ნაწილი (`etcd`, `policies`) ანგარიშში არ მოხვდება.

## დავალება 2. kubelet-ის hardening

ველების სახელებს მეხსიერებით ნუ იხსენებთ - გამოცდაზე უფრო სწრაფია მათი პირდაპირ უკვე მიღებული
kube-bench-ის ანგარიშიდან (დავალება 1) ამოღება. თითოეულ check-ს იქ აქვს სექცია `== Remediations <target> ==`
გასწორების მზა ტექსტით - `grep -A1` check-ის ნომრით მაშინვე იძლევა საჭირო ველს:

```bash
grep -A1 '^4.2.1 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.1 If using a Kubelet config file, edit the file to set `authentication: anonymous: enabled` to
# `false`.

grep '^4.2.4 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.4 If using a Kubelet config file, edit the file to set `readOnlyPort` to 0.
```

control-plane-ზე kubelet კითხულობს `/var/lib/kubelet/config.yaml`-ს. YAML-ში უნდა იყოს სწორედ
შემდეგი ველები (იგივე სახელის გასაღებებს მეორედ ნუ დაამატებთ):

```yaml
readOnlyPort: 0
authentication:
  anonymous:
    enabled: false
```

გამოცდაზე ყოველ ბრძანებას წინ `sudo`-ს ნუ მიუწერთ - ერთხელ გახდით root (`sudo -i`), ეს
უფრო სწრაფია:

```bash
ssh control-plane
sudo -i
cp /var/lib/kubelet/config.yaml ~/2-kubelet-config.yaml
vim /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet
exit   # root-shell-იდან გასვლა
exit   # control-plane-იდან გასვლა
```

ვამოწმებთ არა ფაილის სტატიკურ ტექსტს, არამედ მოქმედ კონფიგურაციას, რომელიც kubelet-მა
რეალურად გამოიყენა - API `configz`-ის გავლით (YAML-ის ტექსტური პარსინგის მოტყუება ადვილია
მსგავსი ველებით, როგორიცაა `webhook.enabled`, ხოლო `configz` ასახავს იმას, რასაც kubelet
თავად თვლის თავის კონფიგურაციად):

```bash
NODE=$(k get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}')

k get --raw="/api/v1/nodes/${NODE}/proxy/configz" \
  | jq -e '
      (.kubeletconfig.readOnlyPort // 0) == 0 and
      .kubeletconfig.authentication.anonymous.enabled == false
    '

k wait --for=condition=Ready "node/${NODE}" --timeout=120s
```

## დავალება 3. kube-apiserver-ის profiling-ის გამორთვა

იგივე ხერხი, რაც დავალება 2-ში - გამოიყენეთ kube-bench-ის ანგარიში დავალება 1-დან როგორც
ჭეშმარიტების წყარო, ფლაგს მეხსიერებით ნუ იხსენებთ:

```bash
grep -A2 '^1.2.15 ' /var/work/tests/artifacts/1/kube-bench.txt
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
# --profiling=false
```

დაამატეთ პარამეტრი `kube-apiserver` კონტეინერის `command` სიაში.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/3-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# command მასივში დაამატეთ სტრიქონი იმავე ჩაღრმავებით, რაც დანარჩენ არგუმენტებს აქვს:
# - --profiling=false
exit
exit

ssh control-plane "sudo grep -n -- '--profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
k get po -n kube-system -l component=kube-apiserver
# STATUS უნდა გახდეს Running - თუ ჯერ არა, დაელოდეთ რამდენიმე წამს და გაიმეორეთ
```

## დავალება 4. TLS Secret და Ingress

შექმენით მინიმალური აპლიკაცია და Service, დააგენერირეთ თვითხელმოწერილი სერტიფიკატი
ზუსტი DNS-სახელისთვის, შემდეგ შექმენით TLS Secret და Ingress. Controller `ingress-nginx` უკვე
დაყენებულია და Ready-ა ამ ლაბში (lab-owned fixture, ვერსია bootstrap-შია დაფიქსირებული) - ამაში დავრწმუნდებით
Ingress-ის შექმნამდე.

რესურსების მოკლე სახელები (`ns` = namespace, `deploy` = deployment, `svc` = service,
`ing` = ingress, `po` = pod) დროის წნეხის ქვეშ ტექსტის აკრეფას ზოგავს.

```bash
k get ingressclass
k -n ingress-nginx get deploy ingress-nginx-controller
k -n ingress-nginx get endpoints ingress-nginx-controller

k create ns cks-103
k -n cks-103 create deploy secure-app --image=viktoruj/ping_pong:alpine
k -n cks-103 set env deploy/secure-app SERVER_NAME=secure-app SRV_PORT=80
k -n cks-103 expose deploy secure-app --name=secure-app --port=80 --target-port=80
k -n cks-103 wait --for=condition=Available deploy/secure-app --timeout=60s

mkdir -p /tmp/cks-103-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/cks-103-tls/tls.key \
  -out /tmp/cks-103-tls/tls.crt \
  -subj '/CN=secure.cks.local' \
  -addext 'subjectAltName=DNS:secure.cks.local'

k -n cks-103 create secret tls secure-ingress-tls \
  --cert=/tmp/cks-103-tls/tls.crt --key=/tmp/cks-103-tls/tls.key

cat <<'EOF' | k apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: cks-103
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.cks.local
    secretName: secure-ingress-tls
  rules:
  - host: secure.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port:
              number: 80
EOF

k get secret,ing -n cks-103
k get ing secure-ingress -n cks-103 -o yaml
```

`k get ... -o yaml`-ზე არ ვჩერდებით - ვადასტურებთ, რომ TLS Ingress რეალურად
მუშაობს ნამდვილი controller-ის გავლით. `secure.cks.local` უკვე resolve-დება რეალურ node IP-ზე
(bootstrap-მა ჩანაწერი დაამატა `/etc/hosts`-ში), ხოლო `ingress-nginx-controller` - Service ტიპით
`NodePort`-ია, გახსნილი ყველა node-ზე, ამიტომ curl სრულდება პირდაპირ ამ მანქანიდან, კლასტერზე SSH-ის
გარეშე:

```bash
HTTPS_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -k "https://secure.cks.local:${HTTPS_NODEPORT}/"
# HTTPCODE 200, სხეული შეიცავს "Server Name: secure-app"-ს

HTTP_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
curl -v "http://secure.cks.local:${HTTP_NODEPORT}/"
# < HTTP/1.1 308 Permanent Redirect
# < Location: https://secure.cks.local
```

ეს HTTP→HTTPS redirect გამოცდის რეალური კითხვაა, და არა ლაბის ხელოვნური მოთხოვნა
(იხ. mock-გამოცდა `tasks/cks/mock/04`, დავალება 4).

## დავალება 5. kube-apiserver-ისა და etcd-ის TLS hardening

ფლაგის ზუსტ სახელს დოკუმენტაციაში ნუ ეძებთ - უფრო სწრაფია თავად binary-ს ჰკითხოთ უკვე
გაშვებული Pod-ის შიგნიდან (`--help` აქვს control plane-ის ნებისმიერ კომპონენტს) და საჭიროს grep გაუკეთოთ:

```bash
k exec -n kube-system $(k get po -n kube-system -l component=kube-apiserver -o name) -- kube-apiserver --help | grep -i tls
# --tls-min-version string   Minimum TLS version supported. Possible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13
# --tls-cipher-suites strings   Comma-separated list of cipher suites for the server. Preferred values: TLS_AES_128_GCM_SHA256, ...

k exec -n kube-system $(k get po -n kube-system -l component=etcd -o name) -- etcd --help | grep -i cipher
# --cipher-suites ''   Comma-separated list of supported TLS cipher suites between client/server and peers
```

ორივე static Pod manifest-ში დაამატეთ პარამეტრები `command`-ში. kube-apiserver-ზე დავალება მოითხოვს
ორივე ფლაგს, თუმცა `VersionTLS13`-ის დროს რეალურ დაცვას სწორედ `--tls-min-version` იძლევა
(Go TLS 1.3 cipher suites-ს თავად ირჩევს, `--tls-cipher-suites` მათზე გავლენას არ ახდენს - იხ. კითხვა
2 განყოფილებაში „შეამოწმეთ თავი სტარტამდე“). `--tls-cipher-suites` მაინც ცხადად უნდა იყოს მითითებული - ეს
defense-in-depth-ია: თუ მინიმალურ ვერსიას მოგვიანებით 1.2-მდე შეასუსტებენ, სუსტი შიფრების ნაკრებები
თავისთავად არ ჩაირთვება. etcd-ზე (იქ TLS 1.2 დაშვებულია) `--cipher-suites` ნაკრებს უკვე ახლა რეალურად
ზღუდავს, და არა მომავლისთვის.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
cp /etc/kubernetes/manifests/etcd.yaml ~/5-etcd.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# დაამატეთ command-ში:
# - --tls-min-version=VersionTLS13
# - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
vim /etc/kubernetes/manifests/etcd.yaml
# დაამატეთ command-ში:
# - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
exit
exit

k get po -n kube-system -l component=etcd
# STATUS უნდა გახდეს Running - თუ ჯერ არა, დაელოდეთ რამდენიმე წამს და გაიმეორეთ
ssh control-plane "sudo grep -E -- '--tls-min-version=VersionTLS13|--tls-cipher-suites=' /etc/kubernetes/manifests/kube-apiserver.yaml"
ssh control-plane "sudo grep -- '--cipher-suites=' /etc/kubernetes/manifests/etcd.yaml"

mkdir -p /var/work/tests/artifacts/5
ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_3 -brief </dev/null' \
  > /var/work/tests/artifacts/5/tls13.txt 2>&1
# Protocol version: TLSv1.3 - კავშირი დამყარდა

ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null' \
  >> /var/work/tests/artifacts/5/tls13.txt 2>&1
# ssl3_read_bytes:tlsv1 alert protocol version - handshake უნდა ჩავარდეს, სწორედ ეს არის საჭირო

echo 'TLS 1.2 correctly rejected (non-zero exit / handshake failure)' \
  >> /var/work/tests/artifacts/5/tls13.txt
cat /var/work/tests/artifacts/5/tls13.txt
```

მოსალოდნელია სტრიქონი ფორმით `Protocol version: TLSv1.3` ან `Protocol : TLSv1.3`, ხოლო
`openssl s_client -tls1_2`-ის დასრულება handshake-ის შეცდომით/non-zero exit-ით უნდა იყოს ჩაწერილი როგორც
`TLS 1.2 correctly rejected`.

## დავალება 6. kubelet-ისა და kubectl-ის SHA-256-ის შემოწმება

ეტალონი ლოკალური ფაილებიდან არ გამოითვლება. ჩამოტვირთეთ Kubernetes `v1.36.0`-ის ოფიციალურად გამოქვეყნებული
საკონტროლო ჯამები, ჩამოაყალიბეთ ფაილები `sha256sum -c`-ის ფორმატში და შეინახეთ შედეგები.

```bash
mkdir -p /var/work/tests/artifacts/6 /tmp/cks-103-sha
cd /tmp/cks-103-sha
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl.sha256
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubelet.sha256

printf '%s  %s\n' "$(cat kubectl.sha256)" "$(command -v kubectl)" > kubectl.check
scp kubelet.sha256 control-plane:/tmp/kubelet.sha256
ssh control-plane 'printf "%s  %s\\n" "$(cat /tmp/kubelet.sha256)" "$(command -v kubelet)" > /tmp/kubelet.check && sha256sum -c /tmp/kubelet.check' \
  | tee /var/work/tests/artifacts/6/binaries.sha256.txt
sha256sum -c kubectl.check | tee -a /var/work/tests/artifacts/6/binaries.sha256.txt

cat /var/work/tests/artifacts/6/binaries.sha256.txt
```

ორივე სტრიქონი უნდა მთავრდებოდეს `: OK`-ით. თუ binary-ის გზა `/usr/bin`-ისგან განსხვავდება,
`command -v` მაინც ქმნის სწორ შემავალ მონაცემებს `sha256sum -c`-ისთვის.

## დავალება 7. Remediation cycle: კონკრეტული kube-bench FAIL-იდან PASS-მდე

დავალება 1-ისგან განსხვავებით (მთელი ანგარიშის snapshot), აქ საჭიროა ერთი კონკრეტული check-ის
მის გასწორებასთან დაკავშირება. `kube-bench` მხარს უჭერს ცალკეული check-ის გაშვებას `--check`-ით, ამიტომ
მთელი ანგარიშის ხელით თავიდან წაკითხვა საჭირო არ არის:

```bash
mkdir -p /var/work/tests/artifacts/7

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/before.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/before.txt
# [FAIL] 1.1.1 Ensure that the API server pod specification file permissions ...
```

შეამოწმეთ ფაქტობრივი წვდომის უფლება node-ზე და გაასწორეთ `600`-მდე - ეს file-only
ცვლილებაა, kubelet static Pod-ს უფლებების შეცვლის გამო თავიდან არ ქმნის, მხოლოდ manifest-ის
შიგთავსის შეცვლის გამო:

```bash
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 644 /etc/kubernetes/manifests/kube-apiserver.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 600 /etc/kubernetes/manifests/kube-apiserver.yaml
```

იგივე check-ის განმეორებითმა წერტილოვანმა გაშვებამ უნდა აჩვენოს `PASS`:

```bash
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/after.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/after.txt
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions ...
```

დაადასტურეთ, რომ kube-apiserver ჯანსაღი დარჩა: ფაილის უფლებების შესწორება მის
შიგთავსს არ ცვლის, ამიტომ kubelet-მა static Pod თავიდან არ უნდა შექმნას.

```bash
k get --raw='/readyz'
k -n kube-system get pods -l component=kube-apiserver
```

## დავალება 8. Remediation cycle: kube-controller-manager

იგივე ხერხი, რაც დავალება 7-ში, სხვა კომპონენტისა და სხვა check ID-სთვის (`1.1.3` -
kube-controller-manager pod specification file permissions):

```bash
mkdir -p /var/work/tests/artifacts/8

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/before.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/before.txt
# [FAIL] 1.1.3 Ensure that the controller manager pod specification file permissions ...

ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 644 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-controller-manager.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 600 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/after.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/after.txt
# [PASS] 1.1.3 Ensure that the controller manager pod specification file permissions ...

k -n kube-system get pods -l component=kube-controller-manager
```

## დავალება 9. Remediation cycle: profiling kube-controller-manager-სა და kube-scheduler-ზე

იგივე ხერხი, რაც დავალებებში 7-8 (kube-bench-ით კონკრეტული `[FAIL]`-ის პოვნა, გასწორება,
`[PASS]`-ის დადასტურება), check-ებისთვის `1.3.2` (kube-controller-manager profiling) და `1.4.1`
(kube-scheduler profiling). ორივე, მთელი `1.x` განყოფილების მსგავსად, `cis-1.12`-ში მიეკუთვნება target `master`-ს,
ამიტომ აშკარა `--targets` საჭირო არ არის - ზუსტად ისე, როგორც დავალებებში 7-8. დავალება 3-მა
profiling მხოლოდ kube-apiserver-ზე გამორთო; kubeadm ნაგულისხმევად `--profiling=false`-ს
kube-controller-manager/kube-scheduler-ის manifest-ებში საერთოდ არ ამატებს.

```bash
mkdir -p /var/work/tests/artifacts/9

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-before.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-before.txt
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-before.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-before.txt
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false ...
```

ვასწორებთ ორივე static Pod manifest-ს - იგივე ხერხი, რაც დავალება 3-ში, მხოლოდ ორი
სხვა კომპონენტისთვის:

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-controller-manager.yaml ~/9-controller-manager.yaml
cp /etc/kubernetes/manifests/kube-scheduler.yaml ~/9-scheduler.yaml
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# command მასივში დაამატეთ სტრიქონი იმავე ჩაღრმავებით, რაც დანარჩენ არგუმენტებს აქვს:
# - --profiling=false
vim /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
exit
exit

k -n kube-system get pods -l component=kube-controller-manager
k -n kube-system get pods -l component=kube-scheduler
```

ვამოწმებთ არა ფაილის ტექსტს, არამედ რეალურად გაშვებულ Pod-ს (kubelet static Pod-ს manifest-ის ცვლილების
შემდეგ მყისიერად არ ქმნის თავიდან), და იგივე check-ის განმეორებითმა წერტილოვანმა გაშვებამ უნდა
აჩვენოს `PASS`:

```bash
k -n kube-system get pod -l component=kube-controller-manager -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

k -n kube-system get pod -l component=kube-scheduler -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-after.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-after.txt
# [PASS] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-after.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-after.txt
# [PASS] 1.4.1 Ensure that the --profiling argument is set to false ...
```

`jq -e` ორივე კომპონენტისთვის უნდა გამოიტანოს `true`, ხოლო ზემოთ მოცემულმა ორივე `k get pods` ბრძანებამ
უნდა აჩვენოს `Running`.

## დავალება 10. Remediation cycle: protect-kernel-defaults worker-node-ზე

იგივე ხერხი, რაც დავალებებში 7-9, ახლა რეალურ worker-node-ზე (და არა control-plane-ზე), მაგრამ
სხვა პროფილისთვის. დაფიქსირებული `kube-bench 0.16.0`/`cis-1.12` (გამოყენებული ამ ლაბის ყველა დანარჩენ
დავალებაში) check protect-kernel-defaults-ს საერთოდ არ შეიცავს - CIS-მა ის ამოიღო/
გადანომრა პროფილის ამ ვერსიიდან მოყოლებული; საკუთარი `4.2.6` `cis-1.12`-ში - ეს
სხვა check-ია (`--make-iptables-util-chains`, `PASS` ნაგულისხმევად, protect-kernel-defaults-თან
კავშირი არ აქვს). საჭირო check იმავე ID-ით `4.2.6` არსებობს იმავე binary-ის უფრო ძველ პროფილში
`cis-1.24` - გამოიყენეთ სწორედ ის, აშკარა `--benchmark cis-1.24`-ით, მხოლოდ
ამ ერთი დავალებისთვის.

control-plane-ისგან განსხვავებით, worker-node-ზე `kube-bench` წინასწარ დაყენებული არ არის - დააყენეთ ის
აქ თავად (რეალური install, და არა ასლი control-plane-იდან ან worker PC-დან): ჩამოტვირთეთ იგივე
დაფიქსირებული release GitHub-იდან, ამოაარქივეთ `binary` და `cfg` default `--config-dir`-ში
(`/etc/kube-bench/cfg`), რათა ეს ფლაგი თითოეულ ბრძანებაში აშკარად არ მიუთითოთ:

```bash
WORKER_NODE=$(k get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')

cat <<'EOF' > /tmp/install-kube-bench.sh
KUBE_BENCH_VERSION=0.16.0
arch=$(dpkg --print-architecture)
workdir=$(mktemp -d)
asset="kube-bench_${KUBE_BENCH_VERSION}_linux_${arch}.tar.gz"
base="https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}"
curl -fsSL -o "$workdir/$asset" "$base/$asset"
# იგივე ხერხი, რაც დავალება 6-ში: ვადარებთ დამოუკიდებლად გამოქვეყნებულ ჯამს, და არა
# თავად ფაილიდან გამოთვლილ ჯამს.
curl -fsSL -o "$workdir/checksums.txt" "$base/kube-bench_${KUBE_BENCH_VERSION}_checksums.txt"
(cd "$workdir" && grep -E "[[:space:]]${asset}\$" checksums.txt | sha256sum --check --strict -)
tar -xzf "$workdir/$asset" -C "$workdir"
sudo install -d -m 0755 /opt/kube-bench /etc/kube-bench
sudo cp -a "$workdir"/cfg /etc/kube-bench/cfg
sudo install -m 0755 "$workdir/kube-bench" /opt/kube-bench/kube-bench
sudo ln -sf /opt/kube-bench/kube-bench /usr/local/bin/kube-bench
rm -rf "$workdir"
EOF
scp /tmp/install-kube-bench.sh "$WORKER_NODE":/tmp/install-kube-bench.sh
ssh "$WORKER_NODE" 'bash /tmp/install-kube-bench.sh'
ssh "$WORKER_NODE" 'kube-bench version'

mkdir -p /var/work/tests/artifacts/10
ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/before.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/before.txt
# [FAIL] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```

`protectKernelDefaults` kubeadm-ის მიერ დაგენერირებულ `KubeletConfiguration`-ში საერთოდ არ შედის -
ველი ფიზიკურად არ არის (უსაფრთხოებისთვის სახიფათო default `false`-ის ექვივალენტია), ამიტომ უბრალოდ
დაამატეთ ის, და ჩასანაცვლებელ არსებულ სტრიქონს ნუ ეძებთ:

```bash
ssh "$WORKER_NODE" 'echo "protectKernelDefaults: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh "$WORKER_NODE" 'sudo systemctl restart kubelet'
k get node "$WORKER_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

დაადასტურეთ `/configz`-ით (რეალურად გამოყენებული კონფიგურაცია, და არა ფაილის ტექსტი) და
check-ის განმეორებითი წერტილოვანი გაშვებით:

```bash
k get --raw="/api/v1/nodes/$WORKER_NODE/proxy/configz" \
  | jq -e '.kubeletconfig.protectKernelDefaults == true'

ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/after.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/after.txt
# [PASS] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```
