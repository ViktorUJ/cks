[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 114 - მოკლე ამოხსნა

## 1. Kubeconfig context inventory

```bash
kubectl config get-contexts
kubectl config current-context
```

```
CURRENT   NAME                        CLUSTER     AUTHINFO         NAMESPACE
*         staging-admin@staging       staging     staging-admin
          legacy-admin@legacy         legacy      legacy-admin
          cluster9-admin@cluster1     cluster1    cluster9-admin
          cluster1-admin@cluster1     cluster1    cluster1-admin
staging-admin@staging
```

`staging`/`legacy` - decoy-ებია, სერვერი არ resolve-დება/არ პასუხობს. გადავდივართ რეალურზე:

```bash
kubectl config use-context cluster1-admin@cluster1
kubectl get nodes
```

```
Switched to context "cluster1-admin@cluster1".
NAME              STATUS   ROLES           AGE   VERSION
ip-10-114-1-xxx   Ready    control-plane   10m   v1.36.0
```

## 2. Client certificate extraction

```bash
cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' | base64 -d)
echo "$cert" | openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate
```

```
sha256 Fingerprint=AA:11:22:...
subject=CN = cluster9-admin, O = cks-lab114
issuer=CN = cluster9-admin, O = cks-lab114
notBefore=Jan  1 00:00:00 2026 GMT
notAfter=Apr  6 00:00:00 2028 GMT
```

ვწერთ artifact-ში ზუსტად ამ მნიშვნელობებს (fingerprint - hex ორწერტილების გარეშე):

```bash
mkdir -p /var/work/tests/artifacts
fp=$(echo "$cert" | openssl x509 -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')
subject=$(echo "$cert" | openssl x509 -noout -subject)
issuer=$(echo "$cert" | openssl x509 -noout -issuer)
notbefore=$(echo "$cert" | openssl x509 -noout -startdate)
notafter=$(echo "$cert" | openssl x509 -noout -enddate)
cat > /var/work/tests/artifacts/task2-cert.txt <<EOF
SHA256_FP=$fp
SUBJECT=$subject
ISSUER=$issuer
NOTBEFORE=$notbefore
NOTAFTER=$notafter
EOF
cat /var/work/tests/artifacts/task2-cert.txt
```

```
SHA256_FP=aa1122...
SUBJECT=subject=CN = cluster9-admin, O = cks-lab114
ISSUER=issuer=CN = cluster9-admin, O = cks-lab114
NOTBEFORE=notBefore=Jan  1 00:00:00 2026 GMT
NOTAFTER=notAfter=Apr  6 00:00:00 2028 GMT
```

ეს სერტიფიკატი ავტენტიფიკაციისთვის არასდროს გამოიყენება - `cluster9-admin`-ს კლასტერში უფლებები არ აქვს,
დავალება მხოლოდ სერტიფიკატის წაკითხვასა და გარჩევას ეხება.

## 3. Baseline: NodePort exposure

```bash
kubectl create ns cks-114
kubectl -n cks-114 create deployment backend --image=viktoruj/ping_pong:alpine
kubectl -n cks-114 set env deployment/backend SRV_PORT=80
kubectl -n cks-114 expose deployment backend --name=kubernetes-public --port=80 --type=NodePort
kubectl -n cks-114 patch svc kubernetes-public -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30114}]}}'
kubectl -n cks-114 wait --for=condition=Ready pod -l app=backend --timeout=90s
```

ვამოწმებთ გარედან (worker-იდან) და კლასტერის შიგნით:

```bash
node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
# kube-proxy NodePort-ის წესებს 1-2 წამის დაყოვნებით აპროგრამებს - ვიცდით, სანამ პორტი არ უპასუხებს
for i in $(seq 1 15); do curl -s -o /dev/null -m2 "http://$node_ip:30114/" && break; sleep 2; done
curl -sS -o /dev/null -w 'external HTTP:%{http_code}\n' -m5 "http://$node_ip:30114/"
kubectl -n cks-114 run probe --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 300
kubectl -n cks-114 wait --for=condition=Ready pod/probe --timeout=60s
kubectl -n cks-114 exec probe -- curl -sS -o /dev/null -w 'in-cluster HTTP:%{http_code}\n' -m5 http://kubernetes-public.cks-114.svc.cluster.local/
# დავალება 4-მდე დაელოდეთ NodePort-ისა და DNS probe-ების მონიტორის მიერ დამოუკიდებელ დაფიქსირებას.
for i in $(seq 1 60); do
  test -s /var/lib/cks-lab114-checker/nodeport-phase-seen && break
  sleep 3
done
test -s /var/lib/cks-lab114-checker/nodeport-phase-seen || { echo 'NodePort history not captured'; exit 1; }
```

```
external HTTP:200
in-cluster HTTP:200
```

## 4. Reduce exposure: NodePort -> ClusterIP

`nodePort`-ს აშკარად ვშლით: ერთი JSON patch ცვლის ტიპს და შლის `/spec/ports/0/nodePort`-ს
(ან `kubectl edit` ხელით და სტრიქონის მოხსნა):

```bash
kubectl -n cks-114 patch svc kubernetes-public --type=json -p '[
  {"op": "replace", "path": "/spec/type", "value": "ClusterIP"},
  {"op": "remove", "path": "/spec/ports/0/nodePort"}
]'
```

ვასრულებთ იმავე ორ შემოწმებას (kube-proxy NodePort-ის წესებს არც ხსნის მყისიერად, ამიტომ ჯერ
ვიცდით, სანამ პორტი პასუხს არ შეწყვეტს):

```bash
for i in $(seq 1 15); do curl -s -o /dev/null -m2 "http://$node_ip:30114/" || break; sleep 2; done
curl -sS -o /dev/null -w 'external HTTP:%{http_code}\n' -m5 "http://$node_ip:30114/"
kubectl -n cks-114 exec probe -- curl -sS -o /dev/null -w 'in-cluster HTTP:%{http_code}\n' -m5 http://kubernetes-public.cks-114.svc.cluster.local/
```

```
curl: (7) Failed to connect to 10.114.1.xxx port 30114 after 0 ms: Connection refused
external HTTP:000
in-cluster HTTP:200
```

`kubernetes-public:30114` node-ზე kube-proxy-ს მიერ აღარ ისმინება (transport deny); კლასტერის შიდა გზა
Service DNS-ით არ რეგრესირებულა.

```bash
kubectl -n cks-114 delete pod probe --ignore-not-found
```

---

## შემოწმება

```bash
check_result
```
