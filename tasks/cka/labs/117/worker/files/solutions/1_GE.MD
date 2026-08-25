[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 117 — ეტალონური ამოხსნა (control plane-ისა და node-ების troubleshooting)

node-ებთან დაკავშირება სამუშაო მანქანიდან:

```bash
ssh k8s1_controlPlane_1     # control plane
ssh k8s1_node_node_1        # worker (სახელი იხილეთ /etc/hosts-ში)
```

## დავალება 1. kube-apiserver-ის შეკეთება (დებაგი crictl-ით)

`kubectl` არ მუშაობს (`connection refused`) — API-სერვერი ჩავარდა. გარკვევის ერთადერთი გზა
კონტეინერიზაციის დონეზე დებაგია `crictl`-ის მეშვეობით.

```bash
ssh k8s1_controlPlane_1
sudo -i

# კონტეინერების ნახვა — ვეძებთ kube-apiserver-ს Exited მდგომარეობაში
crictl ps -a | grep kube-apiserver
# CONTAINER   IMAGE   CREATED   STATE    NAME                ATTEMPT
# abc123...   ...     ...       Exited   kube-apiserver      5

# ვკითხულობთ ჩავარდნილი კონტეინერის ლოგებს
crictl logs <container-id>
# Error: unknown flag: --invalid-nonexistent-flag

# ვასწორებთ მანიფესტს — ვშლით ხაზს გატეხილი ფლაგით
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# წაშალეთ ხაზი:    - --invalid-nonexistent-flag=true
```

> **ალტერნატივა:** `grep -n "invalid" /etc/kubernetes/manifests/kube-apiserver.yaml`
> ხაზის მოსაძებნად, შემდეგ `sed -i '/--invalid-nonexistent-flag/d' /etc/kubernetes/manifests/kube-apiserver.yaml`.

kubelet მანიფესტის შესწორების შემდეგ ხელახლა ქმნის static pod-ს. ველოდებით ~30 წმ:

```bash
# control plane-ზე
crictl ps | grep kube-apiserver    # უნდა იყოს Running
exit
```

```bash
# worker PC-ზე — ვამოწმებთ
kubectl get --raw='/healthz'       # ok
```

## დავალება 2. kube-scheduler-ის შეკეთება

```bash
# სიმპტომი: ახალი pod-ები არ იგეგმება
kubectl get pod sched-check -n default            # Pending
kubectl -n kube-system get pods -l component=kube-scheduler   # ImagePullBackOff

# ვუყურებთ მიზეზს
kubectl -n kube-system describe pod -l component=kube-scheduler   # bad image tag v0.0.0-broken

# ვასწორებთ static pod-ს control plane node-ზე
ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
#   image: registry.k8s.io/kube-scheduler:v0.0.0-broken
# ->image: registry.k8s.io/kube-scheduler:v1.35.2   (ვერსია = კლასტერის ვერსია)
```

kubelet მანიფესტის შესწორების შემდეგ თავად ქმნის static pod-ს ხელახლა.
~30-60 წმ-ში დამგეგმავი აიწევს და `sched-check` გადავა Running-ში.

> image-ის ზუსტი ვერსია შეიძლება აიღოთ მუშა კომპონენტიდან:
> `kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].image}'`

## დავალება 3. worker-node-ის შეკეთება (NotReady)

```bash
kubectl get nodes                     # worker არის NotReady
kubectl describe node <worker>        # kubelet არ ატყობინებს სტატუსს

ssh k8s1_node_node_1
sudo systemctl status kubelet         # activating/failed
sudo journalctl -u kubelet -n 10      # failed to load kubelet config file ... NONEXISTENT-config.yaml

# ვშლით გატეხილ drop-in-ს (კონფიგის გზას ცვლიდა)
sudo rm /etc/systemd/system/kubelet.service.d/99-broken.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet         # active (running)
```

~30 წმ-ში node დაბრუნდება Ready-ში.

## დავალება 4. control plane-ზე გატეხილი static pod-ის შეკეთება

```bash
kubectl get pods -n default           # staticweb-<cp> ImagePullBackOff-ში
kubectl describe pod staticweb-<cp> -n default   # image viktoruj/ping_pong:doesnotexist999

ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/staticweb.yaml
#   image: viktoruj/ping_pong:doesnotexist999  ->  image: viktoruj/ping_pong:latest
```

kubelet ხელახლა შექმნის static pod-ს, mirror-pod `staticweb-<cp>` გადავა Running-ში.

## შემოწმება

```bash
check_result
```
