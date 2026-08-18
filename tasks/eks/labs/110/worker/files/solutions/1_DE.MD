[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 110 - Referenzlösung (VPC-CNI-Netzwerkrichtlinie: Default Deny, Label, Egress)

Alle Befehle laufen auf der Worker-Maschine über SSH. kubectl ist bereits für den Cluster
konfiguriert (die kubeconfig wurde über `aws eks update-kubeconfig` beim Booten der
Maschine erstellt). `enableNetworkPolicy` ist am `vpc-cni`-Add-on bereits über Terraform
aktiviert, daher ist der Agent `aws-network-policy-agent` in `aws-node` schon auf den Nodes
vorhanden, bevor Sie mit den Aufgaben beginnen.

## Aufgabe 1. Namespace `eks-110`

```bash
kubectl create namespace eks-110
```

## Aufgabe 2. Überprüfung, dass der Enforcer aktiviert ist

Wir prüfen beide Tatsachen: den Agent-Container im DaemonSet `aws-node` und das
Konfigurationsflag des Add-ons.

```bash
mkdir -p /var/work/tests/artifacts/2

{
  echo "--- kubectl describe daemonset aws-node ---"
  kubectl describe daemonset aws-node -n kube-system | grep -A2 aws-network-policy-agent
  echo
  echo "--- aws eks describe-addon vpc-cni ---"
  CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's|.*/||')
  aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
    --query "addon.configurationValues" --output text
} > /var/work/tests/artifacts/2/enforcer.txt

cat /var/work/tests/artifacts/2/enforcer.txt
```

Die Ausgabe sollte den Container `aws-network-policy-agent` in `aws-node` enthalten und
eine Zeile wie `enableNetworkPolicy":"true"` in der Add-on-Konfiguration. Das bestätigt,
dass die Control Plane und der Node-Agent `NetworkPolicy`-Objekte tatsächlich durchsetzen,
nicht nur als API-Objekt akzeptieren.

## Aufgabe 3. Symptom vor jeder Richtlinie: Konnektivität ist standardmäßig erlaubt

Wir erstellen `api` (den Server) und `client` (für `kubectl exec curl`), plus einen Service
für `api`:

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-110
kubectl rollout status deployment/api -n eks-110

kubectl expose deployment api -n eks-110 --port=8080 --target-port=8080

kubectl create deployment client --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client -n eks-110
```

Wir prüfen die Konnektivität: `client` sollte `api` über den Service-Namen erreichen
können.

```bash
mkdir -p /var/work/tests/artifacts/3
CLIENT=$(kubectl get po -n eks-110 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/3/connectivity_before.txt

cat /var/work/tests/artifacts/3/connectivity_before.txt
```

Die Datei sollte `HTTP_CODE=200` enthalten: ohne jegliche Richtlinien erlaubt VPC CNI den
gesamten Ost-West-Traffic - im Cluster wurde noch kein `NetworkPolicy`-Objekt erstellt.

## Aufgabe 4. Default Deny Ingress

Wir verweigern den gesamten eingehenden Traffic in den Namespace `eks-110`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: eks-110
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF
```

Wir prüfen, dass `client` `api` nicht mehr erreichen kann (wir warten auf den Timeout,
damit es nicht hängt):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/4/connectivity_denied.txt

cat /var/work/tests/artifacts/4/connectivity_denied.txt
```

Die Datei sollte `HTTP_CODE=000` zeigen (Verbindung nicht zustande gekommen) -
`podSelector: {}` bedeutet „jeder Pod im Namespace", und `policyTypes: ["Ingress"]` ohne
einen `ingress`-Abschnitt bedeutet „gesamten eingehenden Traffic verweigern". Das ist ein
klassisches Default Deny, durchgesetzt vom Agenten `aws-network-policy-agent` über eBPF.

## Aufgabe 5. Erlauben nach Label: `app: frontend` -> `app: api`

Wir fügen eine Richtlinie hinzu, die eingehenden Traffic zu Pods `app: api` nur von Pods
mit dem Label `app: frontend` erlaubt, auf Port `8080`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF
```

Wir erstellen einen Client mit dem richtigen Label (`frontend`) und einen Client ohne es
(`client-other`), um das Ergebnis vergleichen zu können:

```bash
kubectl create deployment frontend --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/frontend -n eks-110

kubectl create deployment client-other --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client-other -n eks-110
```

`kubectl create deployment` setzt das Label `app: <name>` automatisch, daher hat
`frontend` bereits `app: frontend`, während `client-other` `app: client-other` erhält (was
nicht zur Regel passt).

Wir prüfen beide Fälle:

```bash
mkdir -p /var/work/tests/artifacts/5
FRONTEND=$(kubectl get po -n eks-110 -l app=frontend -o jsonpath='{.items[0].metadata.name}')
OTHER=$(kubectl get po -n eks-110 -l app=client-other -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_frontend.txt

kubectl exec "$OTHER" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_other.txt

cat /var/work/tests/artifacts/5/allowed_frontend.txt
cat /var/work/tests/artifacts/5/blocked_other.txt
```

`allowed_frontend.txt` sollte `HTTP_CODE=200` zeigen (das Label passte zur
`podSelector`-Regel in `ingress.from`), während `blocked_other.txt` `HTTP_CODE=000` zeigen
sollte (dasselbe `default-deny-ingress` aus Aufgabe 4 gilt weiterhin für jeden Pod, für den
es keine explizite Allow-Regel gibt).

## Aufgabe 6. Egress mit einer DNS-Ausnahme

Wir schränken den ausgehenden Traffic von `frontend` ein: nur Traffic zu Pods `app: api`
und zu DNS (`kube-system`, Ports `53` UDP/TCP) ist erlaubt. Alles andere (jede externe
Adresse) wird blockiert.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

Wir prüfen, dass das Auflösen des Namens `api` und der Zugriff darauf weiterhin
funktionieren (sowohl DNS als auch der erlaubte Egress zum `api`-Pod werden benötigt):

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/6/egress_dns_api.txt

cat /var/work/tests/artifacts/6/egress_dns_api.txt
```

`HTTP_CODE=200` bestätigt, dass der Eintrag `to.podSelector: app: api` in der Richtlinie
Traffic zu `api` erlaubt, und die Ausnahme auf Port `53` in `kube-system` `frontend`
erlaubt, den Namen aufzulösen.

Jetzt prüfen wir, dass eine beliebige externe Adresse (die nicht von den erlaubten Regeln
abgedeckt ist) blockiert wird:

```bash
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://1.1.1.1 \
  > /var/work/tests/artifacts/6/egress_external_blocked.txt

cat /var/work/tests/artifacts/6/egress_external_blocked.txt
```

`HTTP_CODE=000` bestätigt das Deny: `restrict-egress` definiert die vollständige Liste der
erlaubten Ziele für `app: frontend`, alles andere wird verweigert (einschließlich des
Internets und jedes anderen Pods im Cluster außer `api`).

## Schnelle Prüfung

```bash
check_result
```
