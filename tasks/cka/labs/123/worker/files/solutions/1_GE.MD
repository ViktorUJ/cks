[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 123 — ეტალონური ამოხსნა (CNI-ის ინსტალაცია ნულიდან + დაბალი დონის ქსელი)

კლასტერი აწყობილია **CNI-ის გარეშე**: `kubectl get nodes` → ყველა node `NotReady`, `netlab`-ის
pod-ები `Pending`/`ContainerCreating`-ში ეკიდა, CoreDNS არ ეშვება. სანამ ქსელური პლაგინი არ არის —
pod-ების ქსელიც არ არის.

node-ებთან დაკავშირება: `ssh k8s1_controlPlane_1`, `ssh k8s1_node_node_1`.

## დავალება 1. CNI-ის ხელით დაყენება

kubeadm-ის ოფიციალური ნაბიჯია „Installing a Pod network add-on“
([kubeadm-ის დოკუმენტაცია](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network),
[addon-ების სია](https://kubernetes.io/docs/concepts/cluster-administration/addons/)).
ვაყენებთ Calico-ს ([Calico quickstart](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)):

```bash
# მანიფესტის ვერსია აიღეთ k8s 1.35-თან თავსებადი (იხ. docs.tigera.io)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml

# ვაკვირდებით, როგორ ეშვება ქსელი
kubectl -n kube-system get pods -l k8s-app=calico-node -w
kubectl get nodes -w        # node-ები Ready-ში გადადიან
```

CNI-ის დაყენების შემდეგ:
- node-ები ხდება `Ready`;
- CoreDNS ეშვება (`kubectl -n kube-system get deploy coredns`);
- `netlab`-ის `netprobe` pod-ები ორ node-ზე ნაწილდება და `Running`-ში გადადის.

> თუ გსურთ, რომ Calico-ს მისამართების პული დაემთხვეს `--pod-network-cidr=10.0.0.0/16`-ს,
> მიუთითეთ `CALICO_IPV4POOL_CIDR=10.0.0.0/16` მანიფესტში `apply`-მდე (ლაბორატორიის ჩაბარებაზე
> ეს არ მოქმედებს).

## დავალება 2-3 (მოწმდება ავტომატურად)

როგორც კი CNI ამუშავდება, CoreDNS და `netprobe` (2 pod სხვადასხვა node-ზე) თავისით ეშვება — ესაა
სწორედ დადასტურება, რომ pod-ების ქსელი მუშაობს, მათ შორის **node-ებს შორისაც**.

## დავალება 4. ანგარიში დაბალი დონის ქსელზე → `net-lowlevel.txt`

ფაქტებს control plane node-ზე ვაგროვებთ:

```bash
ssh k8s1_controlPlane_1

# CNI-ის კონფიგი, რომელიც პლაგინმა დადო
sudo ls /etc/cni/net.d
# მაგ.: 10-calico.conflist

# ნაგულისხმევი მარშრუტის მოწყობილობა
ip route show default
# default via 10.10.1.1 dev ens5 ...   -> dev = ens5
```

სამუშაო მანქანაზე:

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/net-lowlevel.txt <<EOF
cni_conf=10-calico.conflist
default_route_dev=ens5
EOF
```

> ჩასვით თქვენი მნიშვნელობები ზემოთ მიღებული გამონატანებიდან.

## network namespace-ებისა და მარშრუტების გარჩევა (დაბალ დონეზე)

სასარგებლოა გავიგოთ, როგორ აკავშირებს CNI pod-ს node-ის ქსელთან. node-ზე, სადაც pod არის:

```bash
# კონტეინერებისა და მათი ქსელური namespace-ების მოძიება
sudo crictl ps
sudo crictl inspectp <pod-id> | grep -i netns    # pod-ის ქსელური namespace-ის გზა

# ქსელური namespace-ების სია
ip netns list
# pod-ის პროცესის netns-ში შესვლა და მისი ქსელის ნახვა
PID=$(sudo crictl inspect <container-id> | jq '.info.pid')
sudo nsenter -t $PID -n ip addr        # pod-ის eth0 ინტერფეისი და მისი IP
sudo nsenter -t $PID -n ip route       # pod-ის ნაგულისხმევი მარშრუტი

# veth-წყვილები ჰოსტზე (ერთი ბოლო pod-ში, მეორე node-ზე)
ip -o link | grep -E 'cali|veth'
# მარშრუტები pod-ების ქსელებისკენ (Calico ამატებს მარშრუტებს სხვა node-ებზე)
ip route | grep -E '10\.|192\.168'
```

იდეა: CNI pod-ისთვის ქმნის ცალკე **network namespace**-ს, აკავშირებს მას ჰოსტთან veth-წყვილით,
გამოყოფს IP-ს პულიდან და აწერს **მარშრუტებს** სხვა node-ებზე არსებული pod-ების ქსელებისკენ —
ასე მუშაობს Kubernetes-ის „ბრტყელი ქსელი“.

დოკუმენტაცია: [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[Network Plugins (CNI)](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/).

## შემოწმება

```bash
check_result
```
