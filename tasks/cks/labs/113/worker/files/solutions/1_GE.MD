[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 113 - ეტალონური ამოხსნა: kubeadm minor upgrade

> ვმუშაობთ როგორც გამოცდაზე: `kubectl` - სამუშაო მანქანაზე, ხოლო ოპერაციები node-ზე (apt, kubeadm,
> kubelet) - თავად node-ზე: შედით მასზე `ssh <node>`-ით, გადადით root-ზე (`sudo -i`),
> შეასრულეთ ბრძანებები და გამოდით (`exit`, `exit`). კლასტერის საწყისი ვერსია `1.35.x`, მიზნობრივი -
> `1.36.x`. node-ების სახელებს (`<cp-სახელი>`, `<worker-სახელი>`) ვიღებთ `kubectl get no`-დან; გამოცდაზე ისინი სხვაა, ამ ლაბში ssh-alias-ები: `k8s113_controlPlane_1` და `k8s113_node_worker1`.

## სად ვიპოვოთ ბრძანებები დოკუმენტაციაში

| რა არის საჭირო | გვერდი და განყოფილება |
| :--- | :--- |
| apt-repository-ის გადართვა შემდეგ minor-ზე (მხოლოდ ვერსია URL-ში სწორდება ფაილში `/etc/apt/sources.list.d/kubernetes.list`, keyring იგივე რჩება) | [Changing the Kubernetes package repository - Switching to another Kubernetes package repository](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/#switching-to-another-kubernetes-package-repository) |
| ვერსიის არჩევა (`apt-cache madison kubeadm`) | [Upgrading kubeadm clusters - Determine which version to upgrade to](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#determine-which-version-to-upgrade-to) |
| `kubeadm`-ის განახლება, `kubeadm upgrade plan`, `kubeadm upgrade apply v1.xx.x` პირველ control-plane-ზე | [Upgrading kubeadm clusters - Upgrading control plane nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrading-control-plane-nodes) |
| `kubectl drain <node> --ignore-daemonsets` | [Upgrading kubeadm clusters - Drain the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#drain-the-node) |
| `kubelet`-ისა და `kubectl`-ის განახლება, `systemctl daemon-reload`, `restart kubelet` | [Upgrading kubeadm clusters - Upgrade kubelet and kubectl](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrade-kubelet-and-kubectl) |
| `kubectl uncordon <node>` | [Upgrading kubeadm clusters - Uncordon the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#uncordon-the-node) |
| Worker-node: `kubeadm upgrade node` | [Upgrading Linux nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/) |

Ubuntu-ს node-ებზე `needrestart` გამართულია რეჟიმში «მხოლოდ სია» (OK/Cancel დიალოგის გარეშე), ამიტომ
`apt-get install` კითხვებზე არ ჩერდება.

`1.36.x`-ის ნაცვლად ბრძანებებში ჩასვით რეალური patch `apt-cache madison kubeadm`-იდან და
`kubeadm upgrade plan`-ის გამოტანიდან.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
mkdir -p /var/work/tests/artifacts/{1,2,4}
kubectl get no
```

`kubectl get no`-ში დაიმახსოვრეთ node-ების სახელები (`ip-10-...`): ისინი დაგჭირდებათ `drain`-ისა და `uncordon`-ისთვის. ქვემოთ
`<cp-სახელი>` - control-plane-ის სახელია, `<worker-სახელი>` - worker-node-ის სახელი.

## ნაბიჯი 0. პარალელურად გაუშვით availability-პოლინგი (დავალება 4)

upgrade-მდე გახსენით ცალკე სესია (`tmux`) სამუშაო მანქანაზე და დატოვეთ Deployment `canary`-ის გამოკითხვის ციკლი
გაშვებული შემდეგი ნაბიჯების მთელი დროის განმავლობაში:

```bash
while true; do
  if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then
    echo "$(date +%s) available=${available:-0}"
  else
    echo "$(date +%s) available=api-unreachable"
  fi >> /var/work/tests/artifacts/4/canary-availability.log
  sleep 5
done
```

## 1. control-plane-ის upgrade

```bash
ssh <cp-სახელი>
sudo -i
```

```bash
# control-plane-ზე (root): მიმდინარე ვერსიები
kubeadm version -o short; kubelet --version

# გადართეთ repository შემდეგ minor-ზე: ფაილში შეცვალეთ v1.35 v1.36-ით
vim /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /

apt update
apt-cache madison kubeadm | head -3
```

განაახლეთ kubeadm (რეალური patch `x`-ის ნაცვლად). **ეს ბრძანება ცალკე შეასრულეთ:** `apt-get`
ასუფთავებს ტერმინალის შეყვანის ბუფერს, ამიტომ მის უშუალოდ შემდეგ ჩასმული სტრიქონები იკარგება.

```bash
# control-plane-ზე (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# control-plane-ზე (root)
kubeadm version -o short
kubeadm upgrade plan
```

აიღეთ კონკრეტული ვერსია `plan`-ის გამოტანიდან და შეასრულეთ upgrade, **სრული** გამოტანის შენახვით:

```bash
# control-plane-ზე (root)
kubeadm upgrade apply v1.36.x -y > /tmp/kubeadm-upgrade-apply.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-apply.txt
# [upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.x".
exit   # root-იდან
exit   # control-plane-იდან
```

```bash
# სამუშაო მანქანაზე: გამოტანის აღება შესამოწმებლად
scp <cp-სახელი>:/tmp/kubeadm-upgrade-apply.txt /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
```

მხოლოდ ახლა, წარმატებული `kubeadm upgrade apply`-ის შემდეგ, node-ის drain და kubelet/kubectl-ის განახლება:

```bash
# სამუშაო მანქანაზე
kubectl drain <cp-სახელი> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <cp-სახელი>
sudo -i
```

```bash
# control-plane-ზე (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# control-plane-ზე (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # root-იდან
exit   # control-plane-იდან
```

```bash
# სამუშაო მანქანაზე
kubectl uncordon <cp-სახელი>
kubectl get nodes
```

## 2. worker-node-ის upgrade

დაიწყეთ მხოლოდ მას შემდეგ, რაც control-plane `Ready`-ა `1.36.x`-ზე (version skew policy:
worker-node-ის kubelet არ შეიძლება control-plane-ზე ახალი იყოს). დაელოდეთ, სანამ `canary` ისევ `2/2` გახდება:

```bash
# სამუშაო მანქანაზე: გაიმეორეთ, სანამ AVAILABLE არ გახდება 2
kubectl get deployment canary -n upgrade-113
```

```bash
ssh <worker-სახელი>
sudo -i
```

```bash
# worker-ზე (root): იგივე repository, რაც control-plane-ზე
vim /etc/apt/sources.list.d/kubernetes.list     # v1.35 -> v1.36
apt update
```

```bash
# worker-ზე (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# worker-ზე (root)
# worker-node-ზე (და დამატებით control-plane-ებზე) apply-ის ნაცვლად სრულდება upgrade node
kubeadm upgrade node > /tmp/kubeadm-upgrade-node.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-node.txt
exit   # root-იდან
exit   # worker-იდან
```

```bash
# სამუშაო მანქანაზე
scp <worker-სახელი>:/tmp/kubeadm-upgrade-node.txt /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
kubectl drain <worker-სახელი> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <worker-სახელი>
sudo -i
```

```bash
# worker-ზე (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# worker-ზე (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # root-იდან
exit   # worker-იდან
```

```bash
# სამუშაო მანქანაზე
kubectl uncordon <worker-სახელი>
kubectl get nodes
```

## 3. upgrade-ის თანმიმდევრობის შემოწმება

დავალება 3 ცალკე ბრძანებებს არ მოითხოვს: თანმიმდევრობას ამტკიცებს checker-owned მონიტორი
(`/var/lib/cks-lab113-checker/upgrade-monitor.log` სამუშაო მანქანაზე), რომელიც bootstrap-იდან მთელი დროის განმავლობაში
იწერებოდა. თუ ნაბიჯებს თანმიმდევრობით მიჰყევით (ჯერ მთლიანად განყოფილება 1, შემდეგ განყოფილება 2),
ლოგში არის სტრიქონი, სადაც control-plane უკვე `v1.36.x`-ზეა, `Ready` და schedulable, ხოლო worker ჯერ
`v1.35.x`-ზეა.

## 4. downtime-ის არარსებობის შემოწმება

> `kubeadm upgrade apply`-ის დროს ერთადერთ control-plane-ზე API server რამდენიმე წამით
> გადაიტვირთება, და `kubectl` გამოკითხვის ციკლში არ პასუხობს. ასეთი სტრიქონები ჩაწერილია როგორც
> `available=api-unreachable` და მინიმუმის დათვლაში არ შედის: API-ის მიუწვდომლობა `canary`-ს
> downtime არ არის. Downtime-ის არსებობას ან არარსებობას აფიქსირებს checker-ის დამოუკიდებელი მონიტორი (Pod Ready და კონტეინერები `crictl`-ით).

შეაჩერეთ გამოკითხვის ციკლი ნაბიჯ 0-დან (`Ctrl+C` მის სესიაში) და შეამოწმეთ, რომ გაშვების განმავლობაში `available`-ის მინიმუმი
0-მდე არ დაცემულა:

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | sort -u
kubectl get deployment canary -n upgrade-113
```

`canary`-ის ორივე replica სხვადასხვა node-ზეა განაწილებული (required `podAntiAffinity`) და დაცულია
`minAvailable: 1`-ის მქონე `PodDisruptionBudget`-ით, ამიტომ სწორი მიმდევრობითი drain (ჯერ
ერთი node, შემდეგ მეორე, uncordon-ის შემდეგ) `available`-ს `1`-ზე დაბლა არ ჩამოიყვანს.

## საბოლოო შემოწმება

```bash
kubectl get nodes
check_result
```

ორივე node უნდა იყოს `Ready` `v1.36.x`-ზე, არცერთი `SchedulingDisabled` არ უნდა იყოს.
