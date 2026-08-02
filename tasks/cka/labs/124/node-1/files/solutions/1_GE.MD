[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 124 — ეტალონური ამოხსნა (HA control plane 3 node-იდან)

მოცემულია კლასტერი ერთი control plane `cp1`-ით, რომელიც ინიციალიზებულია
`--control-plane-endpoint`-ითა და `--upload-certs`-ით, დაყენებული CNI-ით. საჭიროა **ორი**
control-plane node `cp2` და `cp3` მიაერთოთ (prerequisites და პაკეტები მათზე უკვე
დაყენებულია), რომ მიიღოთ etcd-ის კენტი კვორუმი (3 კვანძი).

ოფიციალური დოკუმენტაცია:
[Creating Highly Available clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/),
[kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/).

## ნაბიჯი 1. certificate-key-ისა და join-ბრძანების მიღება (`cp1`-ზე)

```bash
# 1. control plane-ის სერტიფიკატების ატვირთვა secret-ში და certificate-key-ის მიღება
sudo kubeadm init phase upload-certs --upload-certs
# ... ბეჭდავს: <certificate-key>

# 2. ბაზისური join-ბრძანების მიღება (token + discovery-hash)
sudo kubeadm token create --print-join-command
# kubeadm join <endpoint>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

შეადგინეთ ბრძანება control-plane node-ისთვის, დაამატეთ `--control-plane` და
`--certificate-key`.

## ნაბიჯი 2. cp2-ის მიერთება (დავალება 1)

```bash
ssh cp2
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

## ნაბიჯი 3. cp3-ის მიერთება (დავალება 2)

იმავე გზით. თუ ნაბიჯი 1-იდან ~2 საათზე მეტი გავიდა, `certificate-key` ვადაგასულია —
გაიმეორეთ `upload-certs`; თუ token ვადაგასულია (~24 სთ) — ხელახლა `kubeadm token create`.

```bash
ssh cp3
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

შემოწმება `cp1`-ზე:

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane   # 3 node
kubectl get nodes                                            # ყველა Ready
```

## ნაბიჯი 4. etcd-ის კვორუმის შემოწმება (დავალება 3)

stacked-ტოპოლოგიისას ყოველ control-plane node-ზე აიწევს საკუთარი static pod `etcd-*`:

```bash
kubectl -n kube-system get pods -l component=etcd -o wide
# etcd-cp1   Running
# etcd-cp2   Running
# etcd-cp3   Running

# etcd-ის წევრების რაოდენობა პირდაპირ (სერტიფიკატებით, თავი 37):
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
# 3 სტრიქონი — etcd-ის კლასტერის სამი წევრი
```

## რატომ სწორედ 3

etcd-ის 3 წევრს აქვს კვორუმი 2 და უძლებს **ერთი** კვანძის მწყობრიდან გამოსვლას. 2 წევრი
უძლებს **ნულ** ავარიას (კვორუმი 2 2-დან) — ეს უარესია, ვიდრე ერთი კვანძი. ამიტომ HA-ს კენტ
რიცხვზე აწყობენ: 3 (სტანდარტი) ან 5 (უძლებს ორ ავარიას). ლუწი რიცხვი მომგებიანი არ არის
(თავი 35A).

## შემოწმება

```bash
check_result
```
