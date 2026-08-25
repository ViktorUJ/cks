[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 34 - ეტალონური გადაწყვეტა

Istio `1.29.1` (ნაგულისხმევი პროფილი, PERMISSIVE mTLS, `ALLOW_ANY` გამავალი ტრაფიკი, ავტორიზაციის გარეშე) და OPA
Gatekeeper წინასწარ არის დაყენებული. სახელთა სივრცე `app` (ინექციით) შეიცავს `frontend`-ს და ორ curl
კლიენტს: `good` (SA `good`) და `bad` (SA `bad`), ასევე SA `mesh-editor`-ს; სახელთა სივრცე
`legacy` (ინექციის გარეშე) შეიცავს sidecar-ის არმქონე `legacy` curl კლიენტს. `istioctl` ხელმისაწვდომია
worker PC-ზე.

## მიზანი (მრავალშრიანი დაცვა)

1. **STRICT mTLS** მთელ mesh-ში.
2. **ნაგულისხმევად აკრძალული** ავტორიზაცია + მიზნობრივი დაშვება `good`-ისთვის.
3. **გამავალი ტრაფიკის კონტროლი**: `REGISTRY_ONLY`.
4. **RBAC Istio CRD-ებზე**: Istio-ს კონფიგურაციის დაშვება, მაგრამ `EnvoyFilter`-ის აკრძალვა.
5. **OPA Gatekeeper**: `PeerAuthentication`-ის უარყოფა, როდესაც მითითებულია `mode: DISABLE`.
6. **Sidecar-ის გვერდის ავლისადმი მდგრადობა**: NetworkPolicy, როგორც დამოუკიდებელი L3/L4 შრე.

## ნაბიჯი 1. STRICT mTLS (მთელ mesh-ში)

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system      # root namespace -> mesh-wide
spec:
  mtls:
    mode: STRICT
EOF
```

ახლა sidecar-ის არმქონე `legacy` კლიენტი (ღია ტექსტით) ვეღარ უკავშირდება `frontend`-ს:

```bash
kubectl exec -n legacy deploy/legacy -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://frontend.app.svc.cluster.local:8080/
# connection reset / 000
```

## ნაბიჯი 2. ნაგულისხმევად აკრძალვა + მიზნობრივი დაშვება

```bash
# default-deny for the whole app namespace (empty spec)
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: app
spec: {}
EOF

# allow only the "good" identity to call frontend
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-good
  namespace: app
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/app/sa/good"]
EOF
```

```bash
kubectl exec -n app deploy/good -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 200
kubectl exec -n app deploy/bad  -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 403
```

## ნაბიჯი 3. გამავალი ტრაფიკის კონტროლი: REGISTRY_ONLY

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
EOF
istioctl install -f /tmp/iop.yaml -y

# external host that is not in the registry is now blocked
kubectl exec -n app deploy/good -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://www.example.com/   # 502 (blocked)
```

(კონკრეტული გარე ჰოსტის დასაშვებად უნდა დაამატოთ `ServiceEntry`, იხილეთ ლაბორატორია 05.)

## ნაბიჯი 4. RBAC Istio CRD-ებზე (EnvoyFilter-ის აკრძალვა)

`EnvoyFilter` ყველაზე სახიფათო Istio CRD-ია - ის ნედლ Envoy კონფიგურაციას ნერგავს. მიანიჭეთ Istio-ს
კონფიგურაციის მართვის უფლება `mesh-editor`-ს, მაგრამ **გამორიცხეთ** `envoyfilters`:

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mesh-editor
  namespace: app
rules:
  - apiGroups: ["networking.istio.io"]
    resources: ["virtualservices","destinationrules","gateways","serviceentries","sidecars","workloadentries"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["security.istio.io"]
    resources: ["authorizationpolicies","requestauthentications"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  # envoyfilters intentionally NOT granted
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mesh-editor
  namespace: app
roleRef:
  kind: Role
  name: mesh-editor
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: mesh-editor
    namespace: app
EOF
```

```bash
kubectl auth can-i create virtualservices.networking.istio.io --as=system:serviceaccount:app:mesh-editor -n app   # yes
kubectl auth can-i create envoyfilters.networking.istio.io     --as=system:serviceaccount:app:mesh-editor -n app   # no
```

## ნაბიჯი 5. OPA Gatekeeper: mTLS-ის გამორთვის აკრძალვა

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdenymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: K8sDenyMtlsDisable
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenymtlsdisable
        violation[{"msg": msg}] {
          input.review.object.spec.mtls.mode == "DISABLE"
          msg := "PeerAuthentication with mode: DISABLE is not allowed"
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
      - apiGroups: ["security.istio.io"]
        kinds: ["PeerAuthentication"]
EOF
```

```bash
# should be DENIED
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: try-disable
  namespace: app
spec:
  mtls:
    mode: DISABLE
EOF
```

## ნაბიჯი 6. NetworkPolicy (sidecar-ის გვერდის ავლისადმი მდგრადობა)

mTLS/authz sidecar-ში მოქმედებს; თუ ტრაფიკი sidecar-ს გვერდს აუვლის, ისინი არ გამოიყენება.
NetworkPolicy ბირთვში CNI-ის (Calico) მიერ აღსრულდება - ეს დამოუკიდებელი L3/L4 შრეა:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-allow-app
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
  ingress:
    # app port 8080 only from pods in the app namespace
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: app
      ports:
        - port: 8080
          protocol: TCP
    # istio sidecar health (15021) / metrics (15090) from anywhere (kubelet, prometheus)
    - ports:
        - port: 15021
          protocol: TCP
        - port: 15090
          protocol: TCP
EOF
```

მხოლოდ `app`-ში არსებული pod-ები უკავშირდებიან `frontend`-ს `8080` პორტზე; `legacy` იბლოკება მანამდე, სანამ
sidecar-მდე მიაღწევს. `15021` პორტი ღია რჩება, რათა Istio sidecar-ის kubelet readiness probe კვლავ
წარმატებით სრულდებოდეს (წინააღმდეგ შემთხვევაში pod გადავიდოდა NotReady მდგომარეობაში).

## რატომ მუშაობს ეს (საფრთხეების მოდელი)

- **STRICT mTLS** - მიიღება მხოლოდ ორმხრივად ავთენტიფიცირებული mesh ტრაფიკი; ღია ტექსტით გადაცემული და
  mesh-ის გარეთ მყოფი კლიენტები უარყოფილია. დაშიფვრა + სერვისის იდენტობა.
- **ნაგულისხმევად აკრძალული ავტორიზაცია** - მინიმალური პრივილეგია: არაფერია დაშვებული, თუ მკაფიო ALLOW
  წესს არ ემთხვევა, რაც კომპრომეტირებული workload-ის ზემოქმედების არეალს ზღუდავს.
- **REGISTRY_ONLY გამავალი ტრაფიკი** - კომპრომეტირებული pod ვერ გაიტანს მონაცემებს ნებისმიერ გარე
  ჰოსტზე; ხელმისაწვდომია მხოლოდ დეკლარირებული დანიშნულების მისამართები.
- **RBAC CRD-ებზე** - `EnvoyFilter`-ის (და ზოგადად Istio-ს კონფიგურაციის) შეზღუდვა ზედმეტი
  პრივილეგიების მქონე მომხმარებელს data plane-ის ხელახალი პროგრამირების საშუალებას არ აძლევს.
- **OPA Gatekeeper** - „არასოდეს გამორთო mTLS“ მკაცრ admission წესად გარდაქმნის და არა უბრალოდ შეთანხმებად.
- **NetworkPolicy** - დამოუკიდებელი, ბირთვის დონეზე მოქმედი კონტროლი, რომელიც sidecar-ის გვერდის
  ავლის შემთხვევაშიც ძალაში რჩება - მრავალშრიანი დაცვა.
