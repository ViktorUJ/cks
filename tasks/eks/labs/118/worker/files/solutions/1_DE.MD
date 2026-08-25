[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 118 - Referenzlösung (GitOps: Argo CD, Drift und Self-Heal, Sync Waves)

Alle Befehle werden auf der Worker-Maschine über SSH ausgeführt. kubectl ist bereits
für den Cluster konfiguriert (das kubeconfig wird beim Booten der Maschine über `aws
eks update-kubeconfig` erstellt).

## Aufgabe 1. Installation von Argo CD über Helm

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd

kubectl rollout status deployment/argocd-server -n argocd
```

Wir prüfen, dass der Server hochgekommen ist:

```bash
kubectl get deploy argocd-server -n argocd
kubectl get pods -n argocd
```

## Aufgabe 2. Namespace `eks-118` und das Application-Objekt

```bash
kubectl create namespace eks-118
```

Die Application verbindet eine Git-Quelle (das Repository des Kurses selbst, Branch
`AG-155`, Pfad `tasks/eks/labs/118/gitops-demo`) mit dem Zielcluster und dem Namespace
`eks-118`. `selfHeal: true` rollt manuelle Änderungen zurück, `prune: true` entfernt aus
dem Cluster Ressourcen, die aus Git entfernt wurden:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ViktorUJ/cks.git
    targetRevision: AG-155
    path: tasks/eks/labs/118/gitops-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: eks-118
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF
```

Wir warten, bis die Application `Synced` und `Healthy` erreicht:

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}'
echo
```

Beide Befehle sollten am Ende `Synced` und `Healthy` zurückgeben (Argo CD fragt Git ab
und wendet Manifeste automatisch an, Auto-Sync ist standardmäßig aktiviert).

## Aufgabe 3. Prüfung, ob die Objekte tatsächlich angewendet wurden

```bash
kubectl get deployment demo-app -n eks-118
kubectl get configmap demo-config -n eks-118 -o yaml
kubectl rollout status deployment/demo-app -n eks-118
```

Das Deployment `demo-app` (Image `viktoruj/ping_pong:latest`, 2 Replicas) und die
ConfigMap `demo-config` kamen über Argo CD aus Git, nicht über einen manuellen
`kubectl apply` des Studenten.

## Aufgabe 4. Drift und Self-Heal

Ein wichtiges Detail, das man nur auf einem lebenden Cluster sieht: bei aktiviertem
`selfHeal` rollt der Controller Drift innerhalb von Sekunden zurück, und `OutOfSync`
mit eigenen Augen zu erfassen ist praktisch unmöglich (ein manuelles `kubectl scale`
wird noch vor dem ersten `kubectl get application` zurückgerollt). Deshalb wird Drift
in zwei Schritten gezeigt: zuerst wird die Selbstheilung deaktiviert, `OutOfSync`
festgehalten, dann die Selbstheilung wieder aktiviert und der Rollback beobachtet.

Schritt 1. Wir deaktivieren nur `selfHeal`, lassen `prune` aktiviert:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false,"prune":true}}}}'
```

Schritt 2. Wir brechen den Live-Zustand unter Umgehung von Git und halten den Drift
fest:

```bash
kubectl scale deployment demo-app -n eks-118 --replicas=5

for i in $(seq 1 20); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  [[ "$status" == "OutOfSync" ]] && break
  sleep 3
done

mkdir -p /var/work/tests/artifacts/4
{
  echo "=== Drift bei selfHeal=false (manuelles kubectl scale --replicas=5) ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} > /var/work/tests/artifacts/4/drift.txt
```

Ohne self-heal bleibt die Application `OutOfSync`: Auto-Sync reagiert auf Änderungen
in Git, während eine im Cluster erzeugte Abweichung genau von `selfHeal` behoben wird.

Schritt 3. Wir aktivieren `selfHeal` wieder und beobachten den automatischen Rollback
zum Zustand aus Git:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'

for i in $(seq 1 40); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  replicas=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.spec.replicas}')
  [[ "$status" == "Synced" ]] && [[ "$replicas" == "2" ]] && break
  sleep 3
done

{
  echo "=== nach Aktivierung von selfHeal: Rollback zum Zustand aus Git ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} >> /var/work/tests/artifacts/4/drift.txt

cat /var/work/tests/artifacts/4/drift.txt
```

Die Datei enthält sowohl `OutOfSync` (Drift ohne Selbstheilung) als auch `Synced`
(self-heal hat den Zustand aus Git zurückgeholt). `replicas` ist am Ende wieder `2`.

## Aufgabe 5. Sync Waves: Reihenfolge der Anwendung

`gitops-demo/configmap.yaml` trägt die Annotation `argocd.argoproj.io/sync-wave: "0"`,
und `gitops-demo/deployment.yaml` trägt `argocd.argoproj.io/sync-wave: "1"`. Die
niedrigere Wellennummer wird zuerst angewendet, sodass die ConfigMap garantiert vor dem
Deployment im Cluster landet (wichtig, wenn das Deployment Werte aus der ConfigMap über
`envFrom` liest):

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
kubectl get deployment demo-app -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
```

Wir bestätigen, dass beide Objekte trotz unterschiedlicher Wellen am Ende synchronisiert
sind:

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.resources}' | head -c 400
```

## Aufgabe 6. Was prune löscht und was nicht: Ressourcen-Eigentum

`prune: true` ist bereits seit Aufgabe 2 aktiviert. Wir erstellen manuell in `eks-118`
eine ConfigMap, die es in `gitops-demo/` nicht gibt - ein gewöhnliches manuelles
Objekt, als hätte es jemand außerhalb von Git erstellt:

```bash
kubectl create configmap manual-extra -n eks-118 --from-literal=note=manual

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

sleep 30
kubectl get configmap manual-extra -n eks-118
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'; echo
```

Unerwartetes Ergebnis: `prune=true` ist aktiviert, aber `manual-extra` wird **nicht
gelöscht**, und die Application bleibt `Synced`. Der Grund liegt im Eigentumsmodell:
Argo CD verwaltet nur Objekte, die als zur Anwendung gehörend markiert sind. In Argo CD
3.x ist das die Annotation `argocd.argoproj.io/tracking-id` - sieh dir an, wie das aus
Git stammende Objekt markiert ist:

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'; echo
# demo-app:/ConfigMap:eks-118/demo-config
```

Das manuelle Objekt hat diese Markierung nicht, es ist für Argo CD fremd (orphaned) und
fällt nicht unter den Prune-Bereich. Wir halten diese Beobachtung fest:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== ohne Tracking-Annotation ruehrt prune das Objekt nicht an ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "sync: $(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')"
} > /var/work/tests/artifacts/6/prune.txt
```

Jetzt markieren wir die ConfigMap als zur Anwendung gehörend. Das Wertformat ist
`<app>:<group>/<Kind>:<namespace>/<name>`, bei Core-Ressourcen ist die group leer:

```bash
kubectl annotate configmap manual-extra -n eks-118 \
  'argocd.argoproj.io/tracking-id=demo-app:/ConfigMap:eks-118/manual-extra' --overwrite

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

for i in $(seq 1 20); do
  kubectl get configmap manual-extra -n eks-118 >/dev/null 2>&1 || break
  sleep 5
done

kubectl get configmap manual-extra -n eks-118 2>&1
```

Jetzt wird das Objekt von der Anwendung verfolgt, es ist nicht in Git - und prune
löscht es. Dabei bleiben `demo-config` und `demo-app` an ihrem Platz, weil sie in
`gitops-demo/` beschrieben sind:

```bash
{
  echo "=== nach Hinzufuegen der Tracking-Annotation hat prune das Objekt geloescht ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 2>&1 | tail -n1)"
  echo "demo-config: $(kubectl get configmap demo-config -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "demo-app: $(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.metadata.name}')"
  echo
  echo "prune entfernt nur von der Anwendung VERFOLGTE Ressourcen, die in Git fehlen."
  echo "Ein manuell erstelltes Objekt ohne Tracking-Annotation ist fuer Argo CD fremd"
  echo "(orphaned) und faellt nicht unter prune - das war das erste beobachtete"
  echo "Ergebnis. demo-config und demo-app blieben, weil sie in gitops-demo/"
  echo "beschrieben sind und Argo CD sie weiter synchronisiert."
} >> /var/work/tests/artifacts/6/prune.txt

cat /var/work/tests/artifacts/6/prune.txt
```

## Aufgabe 7. Diagnose: sync status und health status - zwei verschiedene Achsen

Wir deaktivieren Auto-Sync (und damit auch self-heal, das im selben Block lebt), um das
Symptom in Ruhe auslösen zu können, ohne sofortigen Rollback:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

Wir brechen die readinessProbe des Containers direkt im Cluster. Wichtig: das
Übungsimage `ping_pong` antwortet mit `200` auf jeden Pfad, sodass eine Probe auf eine
„nicht existierende URL“ problemlos besteht und kein Symptom liefert. Wir richten die
Probe auf den geschlossenen Port `9999` - dort hört niemand zu:

```bash
kubectl patch deployment demo-app -n eks-118 --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/readinessProbe","value":{
    "httpGet": {"path": "/healthz", "port": 9999},
    "initialDelaySeconds": 2,
    "periodSeconds": 3,
    "failureThreshold": 2
  }}
]'
```

Wir warten und erfassen die Statuswerte. Sync und health sind unabhängige Achsen: sync
spiegelt die Abweichung zwischen Git und dem Live-Zustand wider, health ist die
tatsächliche Gesundheit der Ressourcen (Bereitschaft der Pods usw.):

```bash
sleep 30
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== beobachtete Statuswerte nach der manuellen readinessProbe-Aenderung ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  echo
  echo "=== Erklaerung: sync status und health status sind unterschiedliche Achsen ==="
  echo "Sync status (Synced/OutOfSync) vergleicht den Live-Zustand der Objekte mit dem,"
  echo "was in Git gespeichert ist: stimmt ueberein - Synced, weicht ab - OutOfSync."
  echo "Health status (Healthy/Progressing/Degraded/Missing) ist die tatsaechliche"
  echo "Gesundheit der Ressource jetzt gerade: sind die Pods bereit, haben die"
  echo "readiness/liveness-Proben bestanden."
  echo "Wegen der Probe auf einem geschlossenen Port bestehen die neuen demo-app-Pods"
  echo "die Readiness nicht, daher geht health nach Progressing (und wird nach"
  echo "progressDeadlineSeconds zu Degraded), waehrend sync Synced bleibt. Der Grund:"
  echo "das Feld readinessProbe ist im Git-Manifest nicht beschrieben, und das manuell"
  echo "hinzugefuegte Feld zaehlt nicht in die Abweichung; replicas hingegen steht in"
  echo "Git, daher ergab dessen manuelle Aenderung in Aufgabe 4 OutOfSync."
  echo "Das beweist, dass beide Achsen unabhaengig berechnet werden: man kann"
  echo "gleichzeitig Synced und Degraded/Progressing sein, ebenso OutOfSync und"
  echo "Healthy gleichzeitig."
} > /var/work/tests/artifacts/7/health.txt

cat /var/work/tests/artifacts/7/health.txt
```

Wir aktivieren Auto-Sync und self-heal wieder:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'
```

Wichtige Beobachtung: self-heal wird diesen Defekt **nicht beheben**. Für Argo CD
besteht keine Abweichung von Git (`sync=Synced`), also gibt es nichts zu heilen -
während `health` ehrlich `Progressing`, dann `Degraded` anzeigt. Die praktische
Schlussfolgerung: `Synced` bedeutet nicht, dass der Cluster byteweise mit Git
übereinstimmt; Felder, die nicht im Manifest stehen, bleiben in der Verantwortung des
Operators. Deshalb entfernen wir die Probe manuell:

```bash
kubectl patch deployment demo-app -n eks-118 --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]'

for i in $(seq 1 20); do
  health=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}')
  ready=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.status.readyReplicas}')
  [[ "$health" == "Healthy" ]] && [[ "$ready" == "2" ]] && break
  sleep 5
done

kubectl get application demo-app -n argocd \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
echo
```

## Schnelle Prüfung

```bash
check_result
```
