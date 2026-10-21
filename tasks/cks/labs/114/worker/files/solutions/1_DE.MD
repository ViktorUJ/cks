[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 114 - Kurzlösung

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

`staging`/`legacy` - decoy, der Server wird nicht aufgelöst/antwortet nicht. Wir wechseln auf den echten:

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

Wir schreiben genau diese Werte (fingerprint - hex ohne Doppelpunkte) ins artifact:

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

Dieses Zertifikat wird nie zur Authentifizierung verwendet - `cluster9-admin` hat keine Rechte im Cluster,
die Aufgabe handelt nur vom Lesen und Analysieren des Zertifikats.

## 3. Baseline: NodePort exposure

```bash
kubectl create ns cks-114
kubectl -n cks-114 create deployment backend --image=viktoruj/ping_pong:alpine
kubectl -n cks-114 set env deployment/backend SRV_PORT=80
kubectl -n cks-114 expose deployment backend --name=kubernetes-public --port=80 --type=NodePort
kubectl -n cks-114 patch svc kubernetes-public -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30114}]}}'
kubectl -n cks-114 wait --for=condition=Ready pod -l app=backend --timeout=90s
```

Wir prüfen von außen (vom worker) und innerhalb des Clusters:

```bash
node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
# kube-proxy programmiert die NodePort-Regeln mit einer Verzögerung von 1-2 Sekunden - wir warten, bis der Port antwortet
for i in $(seq 1 15); do curl -s -o /dev/null -m2 "http://$node_ip:30114/" && break; sleep 2; done
curl -sS -o /dev/null -w 'external HTTP:%{http_code}\n' -m5 "http://$node_ip:30114/"
kubectl -n cks-114 run probe --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 300
kubectl -n cks-114 wait --for=condition=Ready pod/probe --timeout=60s
kubectl -n cks-114 exec probe -- curl -sS -o /dev/null -w 'in-cluster HTTP:%{http_code}\n' -m5 http://kubernetes-public.cks-114.svc.cluster.local/
# Warte vor Task 4 auf die unabhängige Erfassung der NodePort- und DNS-probes durch den Monitor.
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

`kubectl patch` auf dem Array `ports` **entfernt** `nodePort` nicht von selbst - man muss das ganze Array
ohne dieses Feld ersetzen (oder `kubectl edit` von Hand und die Zeile entfernen):

```bash
kubectl -n cks-114 patch svc kubernetes-public --type=json -p '[
  {"op": "replace", "path": "/spec/type", "value": "ClusterIP"},
  {"op": "remove", "path": "/spec/ports/0/nodePort"}
]'
```

Wir prüfen dasselbe Paar von Prüfungen (kube-proxy entfernt die NodePort-Regeln ebenfalls nicht sofort, daher
warten wir zuerst, bis der Port nicht mehr antwortet):

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

`kubernetes-public:30114` wird von kube-proxy auf dem Node nicht mehr bedient (transport deny); der clusterinterne Pfad
über Service DNS ist nicht regrediert.

```bash
kubectl -n cks-114 delete pod probe --ignore-not-found
```

---

## Prüfung

```bash
check_result
```
