[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 118 — ეტალონური ამოხსნა (სერტიფიკატები, CoreDNS, კლასტერის ქსელი)

ანგარიშებს ვინახავთ სამუშაო მანქანაზე კატალოგში `/home/ubuntu/answers/`. control plane-ს
ვუკავშირდებით SSH-ით: `ssh k8s1_controlPlane_1`.

## დავალება 1. სერტიფიკატების health-check → `certs.txt`

კლასტერის სერტიფიკატები control plane-ზეა, `/etc/kubernetes/pki/`-ში. ვკითხულობთ მათ
`openssl`-ით ([ოფიციალური დოკუმენტაცია: Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)).

```bash
ssh k8s1_controlPlane_1

# API-სერვერის სერტიფიკატის ვადა
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate
# notAfter=Jul 20 10:00:00 2026 GMT   <- მნიშვნელობა "notAfter="-ის შემდეგ

# კლასტერის სერტიფიკაციის ცენტრის CN
sudo openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -subject
# subject=CN = kubernetes   <- CN = kubernetes

# მოსახერხებელი ზოგადი მიმოხილვა ვადებზე:
sudo kubeadm certs check-expiration
```

სამუშაო მანქანაზე ჩაწერეთ ანგარიში (`notAfter`-ის მნიშვნელობა — ზუსტად სტრიქონი ნიშნის `=`
შემდეგ):

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/certs.txt <<EOF
apiserver_notafter=Jul 20 10:00:00 2026 GMT
ca_cn=kubernetes
EOF
```

> ჩასვით თქვენი `notAfter` მნიშვნელობა `openssl`-ის გამოტანიდან.

## დავალება 2. CoreDNS-ის შეკეთება

CoreDNS არის Deployment `kube-system`-ში
([ოფიციალური დოკუმენტაცია: DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)).

```bash
kubectl -n kube-system get deploy coredns          # READY 0/0 — რეპლიკები განულებულია
kubectl -n kube-system scale deployment coredns --replicas=2
kubectl -n kube-system rollout status deploy coredns

# რეზოლვინგის შემოწმება:
kubectl run dnstest --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup kubernetes.default
```

## დავალება 3. ფაქტები კლასტერის ქსელის შესახებ → `net.txt`

```bash
# კლასტერის Pod CIDR (kube-controller-manager-ის --cluster-cidr)
ssh k8s1_controlPlane_1 \
  "sudo grep -o 'cluster-cidr=[^ ]*' /etc/kubernetes/manifests/kube-controller-manager.yaml"
# cluster-cidr=10.0.0.0/16

# CNI: ქსელის აგენტის DaemonSet `kube-system`-ში
kubectl -n kube-system get ds | grep calico
# calico-node ...
```

დოკუმენტაცია: [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[kubeadm: pod-network-cidr](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/).

სამუშაო მანქანაზე ჩაწერეთ ანგარიში:

```bash
cat > /home/ubuntu/answers/net.txt <<EOF
pod_cidr=10.0.0.0/16
cni_daemonset=calico-node
EOF
```

## დავალება 4. ndots-ის დაწევა pod-ისთვის (dnsConfig)

kubelet pod-ებს უწერს `/etc/resolv.conf`-ს `options ndots:5`-ით: სახელები, სადაც 5-ზე ნაკლები
წერტილია, თავიდან search-სუფიქსებით გადაირჩევა. გარე სახელებისთვის (`api.github.com` — 2
წერტილი) ეს ზედმეტი NXDOMAIN-მოთხოვნებია. ზღვრის დაწევა pod-ისთვის შესაძლებელია `dnsConfig`-ით
([ოფიციალური დოკუმენტაცია: DNS for Services and Pods — Pod DNS Config](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config)).

პირველად pod დეფოლტური DNS-ით:

```bash
kubectl run dns-default --image=viktoruj/ping_pong:alpine --restart=Never

# ვნახოთ მისი resolv.conf: იქ იქნება "options ndots:5"
kubectl exec dns-default -- cat /etc/resolv.conf
```

შემდეგ pod დაწეული `ndots`-ით (დეკლარაციულად, ვინაიდან `--dry-run` dnsConfig-ს ვერ აკეთებს):

```yaml
# dns-tuned.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-tuned
spec:
  dnsConfig:
    options:
    - name: ndots
      value: "2"
  containers:
  - name: c
    image: viktoruj/ping_pong:alpine
```

```bash
kubectl apply -f dns-tuned.yaml
kubectl get po dns-tuned -o jsonpath='{.spec.dnsConfig.options}'; echo
```

> კომპრომისი: `ndots:2` აჩქარებს გარე სახელებს, მაგრამ **სხვა** namespace-ში სერვისთან
> მიმართვა მოკლე `backend.prod`-ით (2 წერტილი → უკვე აბსოლუტური) აღარ დაშენდება
> search-ის მეშვეობით. გარე სახელებისთვის უფრო საიმედოა FQDN ბოლოში წერტილით:
> `api.github.com.`.

## დავალება 5. ანგარიში ndots-ზე → `dns.txt`

```bash
# ndots-ის მნიშვნელობა დეფოლტური pod-იდან
kubectl exec dns-default -- cat /etc/resolv.conf | grep -oE 'ndots:[0-9]+'
# ndots:5

cat > /home/ubuntu/answers/dns.txt <<EOF
default_ndots=5
tuned_ndots=2
EOF
```

## შემოწმება

```bash
check_result
```

## დავალება 6. Pod-ის DNS-სახელის მოძებნა

ყოველი Pod იღებს A-ჩანაწერს ფორმულით:
`<pod-ip-დეფისებით>.<namespace>.pod.cluster.local`
([ოფიციალური დოკუმენტაცია: DNS for Services and Pods — Pod's A/AAAA record](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pods)).

```bash
# გავიგოთ pod dns-test-ის IP
kubectl get pod dns-test -n dns-lab -o wide
# NAME       READY   STATUS    IP           ...
# dns-test   1/1     Running   10.0.1.23    ...

# შევადგინოთ DNS-სახელი: IP-ში წერტილებს ვცვლით დეფისებით
# 10.0.1.23 → 10-0-1-23.dns-lab.pod.cluster.local

# შევამოწმოთ რეზოლვი (ნებისმიერი pod-იდან nslookup/dig-ით)
kubectl exec dns-default -- nslookup 10-0-1-23.dns-lab.pod.cluster.local

# ჩავწეროთ პასუხი
echo "10-0-1-23.dns-lab.pod.cluster.local" > /home/ubuntu/answers/pod-dns-name.txt
```

> ჩასვით თქვენი pod-ის რეალური IP.
