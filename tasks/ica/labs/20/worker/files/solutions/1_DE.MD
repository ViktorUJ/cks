[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 20: Referenzlösung

Istio `1.29.1` ist installiert. Drei Workloads sind bereitgestellt:
- `ping-pong` im Namespace `app` (Sidecar injiziert, bedient die App);
- `mesh-client` im Namespace `app` (Sidecar injiziert, kommuniziert über mTLS);
- `legacy-client` im Namespace `legacy` (**kein** Sidecar, nur Klartext).

Ohne `PeerAuthentication` ist mTLS standardmäßig **PERMISSIVE**: Sowohl der Mesh-Client
(mTLS) als auch der Legacy-Client (Klartext) können die App erreichen.

## Ziel

Migrieren Sie den Namespace `app` zu **STRICT** mTLS, sodass nur mTLS-Datenverkehr akzeptiert
wird, ohne den Client innerhalb des Mesh zu beeinträchtigen.

## Schritt 1. Die PERMISSIVE-Basis beobachten

```bash
# in-mesh client -> app : works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : ALSO works under PERMISSIVE
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200
```

## Schritt 2. (empfohlen) Die Absicht mit PERMISSIVE explizit machen

Eine sichere Migration fixiert zuerst PERMISSIVE explizit und wechselt dann zu STRICT, nachdem
Sie (über Metriken) bestätigt haben, dass kein Klartextdatenverkehr mehr vorhanden ist:

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

## Schritt 3. Den Namespace auf STRICT umstellen

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: STRICT
EOF
```

## Schritt 4. Überprüfen

```bash
# in-mesh client -> app : still works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : now rejected (connection reset)
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 http://ping-pong.app.svc.cluster.local:8080/
# -> 000 (curl exit 56: reset by peer)
```

## So funktioniert es

- **PeerAuthentication** steuert, wie der Sidecar auf der *Serverseite* eingehende
  Verbindungen akzeptiert:
  - `PERMISSIVE` (Mesh-Standard) akzeptiert sowohl mTLS als auch Klartext. Dies ermöglicht eine
    Migration ohne Ausfallzeit: Sie können Workloads schrittweise in das Mesh aufnehmen,
    während Legacy-Clients mit Klartext weiterhin funktionieren.
  - `STRICT` akzeptiert nur mTLS; Klartextverbindungen werden zurückgesetzt.
- Bereichshierarchie: Eine `PeerAuthentication` in `istio-system` (Stamm) gilt für das gesamte
  Mesh; eine in einem Namespace überschreibt sie dort; eine mit `selector` überschreibt sie pro
  Workload.
- **Rezept für eine sichere Migration**: Behalten Sie PERMISSIVE bei und überwachen Sie die
  Metrik `istio_requests_total{connection_security_policy="none"}`, bis sie auf null fällt
  (kein Klartext mehr), und wechseln Sie dann zu STRICT.

## Verwandte Inhalte

Labor 04 behandelt den STRICT-Endzustand in Kombination mit `AuthorizationPolicy` (wer wen
aufrufen darf). Dieses Labor konzentriert sich auf den Übergang selbst und die Rolle von PERMISSIVE.
