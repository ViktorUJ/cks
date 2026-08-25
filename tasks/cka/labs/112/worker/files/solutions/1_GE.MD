[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 112 — ეტალონური ამოხსნა (etcd: snapshot-ები და აღდგენა)

etcd-თან ყველა მოქმედება — control plane node-ზე (`ssh k8s1_controlPlane_1`, `sudo -i`).
`etcdctl` უკვე დაყენებულია; სერტიფიკატები — `/etc/kubernetes/pki/etcd/`-ში.

მოსახერხებელია ერთხელ დავაყენოთ etcd-თან დაკავშირების საერთო პარამეტრები:

```bash
# control plane-ზე, root-ის ქვეშ
export ETCDCTL_API=3
export EP="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"
```

## დავალება 1. S1 snapshot-ის აღება (ბაზისური მდგომარეობა) და worker-ზე კოპირება

```bash
# control plane-ზე
etcdctl $EP snapshot save /root/etcd-snapshot-1.db
etcdctl snapshot status /root/etcd-snapshot-1.db --write-out=table
```

snapshot-ის კოპირება სამუშაო მანქანაზე (შემოწმებისთვის):

```bash
# worker PC-დან
scp k8s1_controlPlane_1:/root/etcd-snapshot-1.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-1.db
```

(თუ `scp` ვერ იღებს ფაილს `/root`-იდან, control plane-ზე დააკოპირეთ ის `/tmp`-ში და მიეცით
უფლებები: `cp /root/etcd-snapshot-1.db /tmp/ && chmod 644 /tmp/etcd-snapshot-1.db`, შემდეგ
`scp` `/tmp`-იდან.)

## დავალება 2. კლასტერში ცვლილებების შეტანა

ვქმნით „მარკერ-რესურსებს“ — მათით შემდეგ დავინახავთ განსხვავებას snapshot-ებს შორის.
ბრძანებები ეშვება სამუშაო მანქანაზე (სადაც `kubectl` არის კონფიგურირებული).

```bash
# worker PC-ზე
kubectl create namespace snapshot-demo
kubectl -n snapshot-demo create configmap demo-config --from-literal=app=v1
kubectl -n snapshot-demo create deployment demo-web \
  --image=viktoruj/ping_pong --replicas=2

kubectl get ns snapshot-demo
kubectl -n snapshot-demo get cm,deploy
```

## დავალება 3. S2 snapshot-ის აღება (ცვლილებების შემდეგ)

```bash
# control plane-ზე
etcdctl $EP snapshot save /root/etcd-snapshot-2.db
etcdctl snapshot status /root/etcd-snapshot-2.db --write-out=table
```

```bash
# worker PC-დან
scp k8s1_controlPlane_1:/root/etcd-snapshot-2.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-2.db
```

განსხვავება: `etcd-snapshot-1.db` აღებულია `snapshot-demo`-ს შექმნის **წინ**, ხოლო
`etcd-snapshot-2.db` — შექმნის **შემდეგ**. ანუ S2 შეიცავს namespace `snapshot-demo`-ს და მის
რესურსებს, S1 კი — არა.

## დავალება 4. S1-ის აღდგენა და დარწმუნება, რომ ზედმეტი რესურსები არ არის

აღვადგენთ ყველაზე პირველ snapshot-ს — კლასტერი უნდა დაბრუნდეს `snapshot-demo`-ს შექმნამდე
მდგომარეობაში.

აღდგენის თანმიმდევრობა (მეთოდი „სტატიკური pod-ების გაჩერება → აღდგენა `/var/lib/etcd`-ში →
სტატიკური pod-ების ამაღლება“):

```bash
# control plane-ზე, root-ის ქვეშ
# 1. ვნახოთ node-ის სახელი და მისამართები etcd-ის მიმდინარე მანიფესტიდან — დაგჭირდება restore-ისას
grep -E -- '--name=|--initial-cluster=|--initial-advertise-peer-urls=' \
  /etc/kubernetes/manifests/etcd.yaml
# გამოტანის მაგალითი:
#   - --name=ip-10-10-1-17
#   - --initial-advertise-peer-urls=https://10.10.1.17:2380
#   - --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380

# 2. გავაჩეროთ control plane-ის ყველა სტატიკური pod (kubelet ჩააქრობს მათ კონტეინერებს)
mkdir -p /etc/kubernetes/manifests-stopped
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
# დაველოდოთ, სანამ etcd/apiserver-ის კონტეინერები გაქრება
crictl ps

# 3. მოვაშოროთ მიმდინარე მონაცემები და აღვადგინოთ snapshot S1 /var/lib/etcd-ში
mv /var/lib/etcd /var/lib/etcd.bak
etcdctl snapshot restore /root/etcd-snapshot-1.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

# 4. დავაბრუნოთ მანიფესტები — kubelet აამაღლებს control plane-ს აღდგენილ მონაცემებზე
mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

> **მნიშვნელოვანია `--name`-ის შესახებ (etcd 3.6+).** restore-ისას საჭიროა `--name`,
> `--initial-cluster` და `--initial-advertise-peer-urls` მიეთითოს **ზუსტად ისე**, როგორც
> etcd-ის მანიფესტშია. წინააღმდეგ შემთხვევაში აღდგენილი member არ დაემთხვევა იმას, რომლითაც
> სტატიკური pod იშვება, და etcd დაეცემა პანიკით `member unknown`. მნიშვნელობებს ვიღებთ
> ნაბიჯი 1-იდან.

ვამოწმებთ, რომ კლასტერი ამაღლდა და `snapshot-demo` **გაქრა**:

```bash
# worker PC-დან (დაელოდეთ ~1 წუთი, სანამ API ამაღლდება)
kubectl get --raw='/healthz'          # ok
kubectl get ns snapshot-demo          # NotFound — ზედმეტი რესურსები არ არის
kubectl get pods -n kube-system
```

## დავალება 5. კლასტერის აღდგენა S2-იდან

ახლა აღვადგენთ მეორე snapshot-ს — `snapshot-demo` და მისი რესურსები უნდა დაბრუნდეს.
პროცედურა იგივეა, snapshot — `/root/etcd-snapshot-2.db`.

```bash
# control plane-ზე, root-ის ქვეშ
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
crictl ps                                    # დაელოდეთ კონტეინერების გაჩერებას

rm -rf /var/lib/etcd
etcdctl snapshot restore /root/etcd-snapshot-2.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

ვამოწმებთ, რომ კლასტერი ჯანმრთელია და `snapshot-demo` **დაბრუნდა**:

```bash
# worker PC-დან
kubectl get --raw='/healthz'                 # ok
kubectl get ns snapshot-demo                 # Active
kubectl -n snapshot-demo get cm,deploy       # demo-config და demo-web ადგილზეა
kubectl get pods -n kube-system
```

შედეგი: snapshot — ეს კლასტერის მდგომარეობის სრული ანაბეჭდია აღების მომენტისთვის. S1-იდან
აღდგენა კლასტერს „ცარიელ“ მდგომარეობაში აბრუნებს, S2-იდან — აბრუნებს შექმნილ რესურსებს.
