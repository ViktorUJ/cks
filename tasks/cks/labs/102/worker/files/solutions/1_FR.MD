[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 102 - solution courte

On utilise `k` à la place de `kubectl` (l'alias est déjà disponible à l'examen). Le contexte `cluster1-admin@cluster1` est déjà sélectionné.

## 1. Namespace et Pods de lab

```bash
k create ns cks-102
k -n cks-102 run backend --image=nginx:1.27-alpine -l app=backend --port=80
k -n cks-102 expose pod backend --port=80
k -n cks-102 run frontend --image=curlimages/curl:8.10.1 -l role=frontend --command -- sleep 3600
k -n cks-102 run client --image=curlimages/curl:8.10.1 -l role=untrusted --command -- sleep 3600
k -n cks-102 wait --for=condition=Ready pod/backend pod/frontend pod/client --timeout=120s
sleep 5
```

## 2. CiliumNetworkPolicy L3/L4

On vérifie AVANT la policy - les deux Pods doivent réellement atteindre backend :

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:200
```

Policy : sélectionne `backend`, autorise l'ingress uniquement depuis `role=frontend` sur TCP/80.

```bash
k apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
EOF
```

On vérifie APRÈS la policy :

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:000
curl: (28) Connection timed out after 5000 milliseconds
```

`client` -> transport-level deny (`000` et timeout), et pas simplement « autre chose que 200 ».

## 3. Restriction L7 : seulement GET /

On vérifie AVANT (avec la L4-only policy encore en vigueur) - GET et POST doivent tous deux atteindre réellement backend :

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:405
```

On remplace la règle (on n'ajoute pas une seconde règle L4 large à côté - sinon le filtre L7 ne fonctionnera pas) :

```bash
k apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/"
EOF
```

On vérifie APRÈS :

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:403
```

POST est rejeté par l'Envoy proxy de Cilium en L7 (`403`), et non par un transport deny.

## 4. DNS-aware egress via toFQDNs

`allowed.cks102.test`/`blocked.cks102.test` sont un lab-owned fixture qui se résout en
`198.18.0.10`/`198.18.0.20` (IP synthétiques hors de l'address space de Kubernetes, un
network namespace distinct sur le nœud control-plane, et PAS un ClusterIP : `toFQDNs` dans Cilium n'applique pas
la règle allow à une IP à l'intérieur du cluster), levé et inscrit dans CoreDNS dès le bootstrap :
contrairement à `example.com`, ces noms sont toujours disponibles et ne dépendent pas d'Internet. On vérifie AVANT
la policy - le DNS et les deux endpoint de contrôle doivent être réellement accessibles (`-k` - certificat
auto-signé du fixture) :

```bash
k -n cks-102 exec frontend -- nslookup allowed.cks102.test
k -n cks-102 exec frontend -- curl -sSk -o /dev/null -w 'allowed:443 HTTP:%{http_code}\n' -m10 https://allowed.cks102.test/
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'allowed:80 HTTP:%{http_code}\n' -m5 http://allowed.cks102.test:80/
k -n cks-102 exec frontend -- curl -sSk -o /dev/null -w 'blocked:443 HTTP:%{http_code}\n' -m10 https://blocked.cks102.test/
```

```
allowed.cks102.test has address ...
allowed:443 HTTP:200
allowed:80 HTTP:200
blocked:443 HTTP:200
```

Trois règles egress dans un même objet : (1) DNS vers `kube-dns` via `rules.dns` - sans cela, Cilium ne construira pas le FQDN-to-IP mapping ; (2) le `backend` interne sur TCP/80 - sans lui, le default-deny egress bloquera le flux déjà autorisé des tâches 2-3 ; (3) `toFQDNs` uniquement sur `allowed.cks102.test:443`.

```bash
k apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-fqdn
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      role: frontend
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s:k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: ANY
          rules:
            dns:
              - matchPattern: "*"
    - toEndpoints:
        - matchLabels:
            app: backend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
    - toFQDNs:
        - matchName: allowed.cks102.test
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
EOF
```

On vérifie APRÈS (patientez quelques secondes, le FQDN-mapping n'est pas instantané) et on s'assure que backend des tâches 2-3 n'a pas régressé :

```bash
k -n cks-102 exec frontend -- curl -sSk -o /dev/null -w 'allowed:443 HTTP:%{http_code}\n' -m10 https://allowed.cks102.test/
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'allowed:80 HTTP:%{http_code}\n' -m5 http://allowed.cks102.test:80/
k -n cks-102 exec frontend -- curl -sSk -o /dev/null -w 'blocked:443 HTTP:%{http_code}\n' -m10 https://blocked.cks102.test/
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
allowed:443 HTTP:200
allowed:80 HTTP:000
blocked:443 HTTP:000
GET HTTP:200
POST HTTP:403
```

`allowed.cks102.test` HTTPS reste `200` ; `allowed.cks102.test:80` et `blocked.cks102.test:443` se bloquent/expirent (`000`) ; backend GET/POST - comme dans les tâches 2-3, pas de régression.

## 5. Observation via Hubble

Relay est déjà activé par worker.sh. On ouvre le port-forward et l'observation, on génère GET et POST :

```bash
cilium hubble port-forward &
sleep 3
hubble observe --from-pod cks-102/frontend --to-pod cks-102/backend --protocol http --follow &
sleep 2

k -n cks-102 exec frontend -- curl -sS http://backend/ -o /dev/null
k -n cks-102 exec frontend -- curl -sS -X POST http://backend/ -o /dev/null
sleep 3
```

```
cks-102/frontend:xxxxx -> cks-102/backend:80 http-request FORWARDED (HTTP/1.1 GET http://backend/)
cks-102/frontend:xxxxx -> cks-102/backend:80 http-request DROPPED (HTTP/1.1 POST http://backend/)
```

On doit voir exactement deux flow : `GET /` avec le verdict `FORWARDED` et `POST /` avec le verdict `DROPPED`. S'ils sont absents, `hubble observe` n'a pas été lancé pendant les requêtes ; recommencez.

## 6. L7 policy composite : public/private path scopes

Un second backend indépendant avec deux path-scope. On remplace entièrement la configuration nginx
(`default.conf`), afin que `location` renvoie `200` sur un prefix précis et `404` sur tout le
reste - sans cela, il n'y a aucun moyen de distinguer « autorisé » de « refusé » par le code HTTP.

```bash
k create ns production
k create ns finance

k create configmap portal-nginx-conf -n production --from-literal=default.conf='
server {
  listen 80;
  location /public/ { return 200 "public ok\n"; }
  location /private/ { return 200 "private ok\n"; }
  location / { return 404; }
}
'

k apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: portal
  namespace: production
  labels:
    app: portal
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: conf
      mountPath: /etc/nginx/conf.d/default.conf
      subPath: default.conf
  volumes:
  - name: conf
    configMap:
      name: portal-nginx-conf
EOF
k expose pod portal -n production --port=80
k -n finance run finance-client --image=curlimages/curl:8.10.1 --command -- sleep 3600
k -n production wait --for=condition=Ready pod/portal --timeout=60s
k -n finance wait --for=condition=Ready pod/finance-client --timeout=60s
```

Baseline AVANT la policy - les deux path depuis les deux namespace doivent réellement renvoyer `200` :

```bash
k -n finance exec finance-client -- curl -sS -o /dev/null -w 'public:%{http_code}\n' -m5 http://portal.production/public/
k -n finance exec finance-client -- curl -sS -o /dev/null -w 'private:%{http_code}\n' -m5 http://portal.production/private/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'public:%{http_code}\n' -m5 http://portal.production/public/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'private:%{http_code}\n' -m5 http://portal.production/private/
```

```
public:200
private:200
public:200
private:200
```

Policy : deux règles ingress sur le même port. **Un piège important de Cilium** : `fromEndpoints:
[{}]` (sélecteur vide) dans une `CiliumNetworkPolicy` namespaced ne signifie PAS « n'importe quelle identity dans
tout le cluster » - Cilium ajoute implicitement la restriction par le namespace DE LA POLICY ELLE-MÊME à tout
sélecteur de `fromEndpoints` sans namespace-label explicite, y compris un `{}` vide. C'est-à-dire que `{}`
ici, en pratique, ne correspond qu'aux endpoints du namespace `production`, et non à `finance`/`cks-102`
- la vérification en direct le confirme : avec un `{}` littéral, le client externe reçoit un transport
timeout sur LES DEUX path (la règle ne s'applique pas du tout à son namespace), et `finance` reçoit
`403` sur `/public/*` (ne correspond qu'à la règle 2, qui n'autorise que `/private/*`).
Pour faire réellement correspondre n'importe quelle identity indépendamment du namespace, il faut `matchExpressions` avec
`operator: Exists` sur le reserved-label `k8s:io.kubernetes.pod.namespace` (la simple présence de
ce label est vraie pour absolument n'importe quel Pod, indépendamment de la valeur) - c'est cela, et non un
`{}` vide, qui donne l'acceptation cross-namespace pour la règle 1 :

```bash
k apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: portal-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: portal
  ingress:
    - fromEndpoints:
        - matchExpressions:
            - key: k8s:io.kubernetes.pod.namespace
              operator: Exists
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/public/.*"
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: finance
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/private/.*"
EOF
sleep 3
```

Avec ce sélecteur, la règle 1 correspond réellement à ABSOLUMENT n'importe quelle identity (y compris
`finance`), donc l'allow-set final pour `finance` est l'union de `/public/*` (règle 1)
et `/private/*` (règle 2, ne correspond qu'à `finance`). Pour tout autre namespace,
seule la règle 1 agit.

On vérifie APRÈS la policy :

```bash
k -n finance exec finance-client -- curl -sS -o /dev/null -w 'public:%{http_code}\n' -m5 http://portal.production/public/
k -n finance exec finance-client -- curl -sS -o /dev/null -w 'private:%{http_code}\n' -m5 http://portal.production/private/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'public:%{http_code}\n' -m5 http://portal.production/public/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'private:%{http_code}\n' -m5 http://portal.production/private/
```

```
public:200
private:200
public:200
private:403
```

`finance-client` -> les deux path `200`. `cks-102/client` (n'importe quel autre namespace) -> `/public/*`
reste `200`, et `/private/*` - `403` (Envoy L7 deny, et non un transport-level `000` : la règle 1
a déjà autorisé la connexion TCP elle-même pour toutes les identity).

---

## Vérification

```bash
check_result
```
