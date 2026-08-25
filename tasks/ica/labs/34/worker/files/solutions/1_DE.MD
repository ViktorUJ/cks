[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 34 - Referenzlösung

Istio `1.29.1` (Standardprofil, PERMISSIVE mTLS, `ALLOW_ANY`-Egress, keine authz) und OPA
Gatekeeper sind vorinstalliert. Der Namespace `app` (injectiert) enthält `frontend` sowie zwei curl-
Clients, `good` (SA `good`) und `bad` (SA `bad`), und die SA `mesh-editor`; der Namespace
`legacy` (nicht injectiert) enthält einen sidecar-losen `legacy`-curl-Client. `istioctl` befindet sich auf
dem Worker-PC.

## Ziel (Defense in Depth)

1. **STRICT mTLS** im gesamten Mesh.
2. **Standardmäßig verweigerte** Autorisierung plus eine gezielte Zulassung für `good`.
3. **Egress-Kontrolle**: `REGISTRY_ONLY`.
4. **RBAC für Istio-CRDs**: Istio-Konfiguration erlauben, aber `EnvoyFilter` verbieten.
5. **OPA Gatekeeper**: `PeerAuthentication` mit `mode: DISABLE` ablehnen.
6. **Resilienz gegen Sidecar-Umgehung**: NetworkPolicy als unabhängige L3/L4-Schicht.

## Schritt 1. STRICT mTLS (meshweit)

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

Jetzt kann der sidecar-lose `legacy`-Client (Klartext) `frontend` nicht mehr erreichen:

```bash
kubectl exec -n legacy deploy/legacy -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://frontend.app.svc.cluster.local:8080/
# connection reset / 000
```

## Schritt 2. Standardmäßig verweigern + gezielt zulassen

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

## Schritt 3. Egress-Kontrolle: REGISTRY_ONLY

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

(Um einen bestimmten externen Host zu erlauben, würdest du einen `ServiceEntry` hinzufügen, siehe Labor 05.)

## Schritt 4. RBAC für Istio-CRDs (`EnvoyFilter` verbieten)

`EnvoyFilter` ist die gefährlichste Istio-CRD: Sie injiziert rohe Envoy-Konfiguration. Gewähre
`mesh-editor` die Verwaltung der Istio-Konfiguration, aber **schließe** `envoyfilters` **aus**:

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

## Schritt 5. OPA Gatekeeper: Deaktivieren von mTLS verbieten

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

## Schritt 6. NetworkPolicy (Resilienz gegen Sidecar-Umgehung)

mTLS/authz befinden sich im Sidecar; wenn Datenverkehr das Sidecar umgeht, greifen sie nicht.
NetworkPolicy wird durch das CNI (Calico) im Kernel erzwungen, eine unabhängige L3/L4-Schicht:

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

Nur Pods in `app` können `frontend` über `8080` erreichen; `legacy` wird verworfen, bevor es
das Sidecar überhaupt erreicht. Port `15021` bleibt offen, damit der Bereitschafts-Check des Istio-
Sidecars durch den kubelet weiterhin erfolgreich ist (andernfalls würde der Pod NotReady werden).

## Warum das funktioniert (Bedrohungsmodell)

- **STRICT mTLS**: Nur gegenseitig authentifizierter Mesh-Datenverkehr wird akzeptiert; Klartext-
  und Nicht-Mesh-Clients werden abgewiesen. Verschlüsselung + Service-Identität.
- **Standardmäßig verweigerte authz**: Least Privilege: Nichts ist erlaubt, sofern keine explizite
  ALLOW-Regel zutrifft, was den Wirkungsbereich eines kompromittierten Workloads begrenzt.
- **REGISTRY_ONLY-Egress**: Ein kompromittierter Pod kann keine Daten an beliebige externe Hosts
  exfiltrieren; nur deklarierte Ziele sind erreichbar.
- **RBAC für CRDs**: Das Einschränken von `EnvoyFilter` (und der Istio-Konfiguration im
  Allgemeinen) hindert einen überprivilegierten Benutzer daran, die Datenebene umzuprogrammieren.
- **OPA Gatekeeper**: Macht „mTLS niemals deaktivieren“ zu einer harten Admission-Regel statt zu
  einer Konvention.
- **NetworkPolicy**: Unabhängige Kontrolle auf Kernel-Ebene, die weiterhin gilt, wenn das Sidecar
  umgangen wird: Defense in Depth.
