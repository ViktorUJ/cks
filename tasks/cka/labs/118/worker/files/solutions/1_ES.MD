[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 118 — solución de referencia (certificados, CoreDNS, red del clúster)

Los informes se guardan en la máquina de trabajo en el directorio `/home/ubuntu/answers/`.
Al control plane nos conectamos por SSH: `ssh k8s1_controlPlane_1`.

## Tarea 1. Health-check de certificados → `certs.txt`

Los certificados del clúster están en el control plane, en `/etc/kubernetes/pki/`. Los
leemos con `openssl` ([documentación oficial: Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)).

```bash
ssh k8s1_controlPlane_1

# vigencia del certificado del API server
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate
# notAfter=Jul 20 10:00:00 2026 GMT   <- el valor después de "notAfter="

# CN de la autoridad de certificación del clúster
sudo openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -subject
# subject=CN = kubernetes   <- CN = kubernetes

# resumen general cómodo de las fechas de caducidad:
sudo kubeadm certs check-expiration
```

En la máquina de trabajo escribe el informe (el valor de `notAfter` es exactamente la
cadena que sigue al signo `=`):

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/certs.txt <<EOF
apiserver_notafter=Jul 20 10:00:00 2026 GMT
ca_cn=kubernetes
EOF
```

> Sustituye por tu propio valor de `notAfter` de la salida de `openssl`.

## Tarea 2. Reparar CoreDNS

CoreDNS es un Deployment en `kube-system`
([documentación oficial: DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)).

```bash
kubectl -n kube-system get deploy coredns          # READY 0/0 — réplicas a cero
kubectl -n kube-system scale deployment coredns --replicas=2
kubectl -n kube-system rollout status deploy coredns

# comprobación de la resolución:
kubectl run dnstest --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup kubernetes.default
```

## Tarea 3. Datos de la red del clúster → `net.txt`

```bash
# Pod CIDR del clúster (--cluster-cidr de kube-controller-manager)
ssh k8s1_controlPlane_1 \
  "sudo grep -o 'cluster-cidr=[^ ]*' /etc/kubernetes/manifests/kube-controller-manager.yaml"
# cluster-cidr=10.0.0.0/16

# CNI: DaemonSet del agente de red en kube-system
kubectl -n kube-system get ds | grep calico
# calico-node ...
```

Documentación: [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[kubeadm: pod-network-cidr](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/).

En la máquina de trabajo escribe el informe:

```bash
cat > /home/ubuntu/answers/net.txt <<EOF
pod_cidr=10.0.0.0/16
cni_daemonset=calico-node
EOF
```

## Tarea 4. Bajar ndots para un pod (dnsConfig)

kubelet escribe en los pods un `/etc/resolv.conf` con `options ndots:5`: los nombres con
menos de 5 puntos se prueban primero con los sufijos de search. Para los nombres externos
(`api.github.com` — 2 puntos) esto son consultas NXDOMAIN de más. El umbral se puede bajar
para un pod mediante `dnsConfig`
([documentación oficial: DNS for Services and Pods — Pod DNS Config](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config)).

Primero un pod con el DNS por defecto:

```bash
kubectl run dns-default --image=viktoruj/ping_pong:alpine --restart=Never

# mira su resolv.conf: allí aparecerá "options ndots:5"
kubectl exec dns-default -- cat /etc/resolv.conf
```

Luego un pod con el `ndots` reducido (de forma declarativa, ya que `--dry-run` no soporta
dnsConfig):

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

> Compromiso: `ndots:2` acelera los nombres externos, pero el acceso a un servicio de
> **otro** namespace por el nombre corto `backend.prod` (2 puntos → ya es absoluto) dejará
> de completarse con los sufijos de search. Para los nombres externos es más fiable un FQDN
> con punto final: `api.github.com.`.

## Tarea 5. Informe sobre ndots → `dns.txt`

```bash
# valor de ndots del pod por defecto
kubectl exec dns-default -- cat /etc/resolv.conf | grep -oE 'ndots:[0-9]+'
# ndots:5

cat > /home/ubuntu/answers/dns.txt <<EOF
default_ndots=5
tuned_ndots=2
EOF
```

## Comprobación

```bash
check_result
```

## Tarea 6. Encontrar el nombre DNS del pod

Cada Pod recibe un registro A según la fórmula:
`<ip-del-pod-con-guiones>.<namespace>.pod.cluster.local`
([documentación oficial: DNS for Services and Pods — Pod's A/AAAA record](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pods)).

```bash
# averiguar la IP del pod dns-test
kubectl get pod dns-test -n dns-lab -o wide
# NAME       READY   STATUS    IP           ...
# dns-test   1/1     Running   10.0.1.23    ...

# formar el nombre DNS: los puntos de la IP se cambian por guiones
# 10.0.1.23 → 10-0-1-23.dns-lab.pod.cluster.local

# comprobar la resolución (desde cualquier pod con nslookup/dig)
kubectl exec dns-default -- nslookup 10-0-1-23.dns-lab.pod.cluster.local

# escribir la respuesta
echo "10-0-1-23.dns-lab.pod.cluster.local" > /home/ubuntu/answers/pod-dns-name.txt
```

> Sustituye por la IP real de tu pod.
