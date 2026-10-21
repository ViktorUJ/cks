[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 114 - 簡要解答

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

`staging`/`legacy` - decoy，伺服器無法解析/沒有回應。切換到真實的：

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

把這些值原樣(fingerprint - 不帶冒號的 hex)寫入 artifact:

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

這個憑證絕不會用於驗證 - `cluster9-admin` 在叢集中沒有權限，
這個任務只是關於憑證的讀取與解析。

## 3. Baseline: NodePort exposure

```bash
kubectl create ns cks-114
kubectl -n cks-114 create deployment backend --image=viktoruj/ping_pong:alpine
kubectl -n cks-114 set env deployment/backend SRV_PORT=80
kubectl -n cks-114 expose deployment backend --name=kubernetes-public --port=80 --type=NodePort
kubectl -n cks-114 patch svc kubernetes-public -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30114}]}}'
kubectl -n cks-114 wait --for=condition=Ready pod -l app=backend --timeout=90s
```

從外部(在 worker 上)與叢集內部檢查：

```bash
node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
# kube-proxy 會延遲 1-2 秒才寫入 NodePort 規則 - 等待埠有回應
for i in $(seq 1 15); do curl -s -o /dev/null -m2 "http://$node_ip:30114/" && break; sleep 2; done
curl -sS -o /dev/null -w 'external HTTP:%{http_code}\n' -m5 "http://$node_ip:30114/"
kubectl -n cks-114 run probe --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 300
kubectl -n cks-114 wait --for=condition=Ready pod/probe --timeout=60s
kubectl -n cks-114 exec probe -- curl -sS -o /dev/null -w 'in-cluster HTTP:%{http_code}\n' -m5 http://kubernetes-public.cks-114.svc.cluster.local/
# 在任務 4 之前,請等待監控器獨立地記錄 NodePort 與 DNS 探測。
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

明確移除 `nodePort`：用一個 JSON patch 同時變更類型並刪除 `/spec/ports/0/nodePort`
(或手動 `kubectl edit` 並刪除這一行)：

```bash
kubectl -n cks-114 patch svc kubernetes-public --type=json -p '[
  {"op": "replace", "path": "/spec/type", "value": "ClusterIP"},
  {"op": "remove", "path": "/spec/ports/0/nodePort"}
]'
```

執行同樣的兩項檢查(kube-proxy 移除 NodePort 規則同樣不是瞬間完成的，因此先
等待埠不再有回應):

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

`kubernetes-public:30114` 不再被節點上的 kube-proxy 監聽(transport deny)；透過 Service DNS 的
叢集內部路徑沒有退化。

```bash
kubectl -n cks-114 delete pod probe --ignore-not-found
```

---

## 檢查

```bash
check_result
```
