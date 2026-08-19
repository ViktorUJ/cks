[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 131 - Musterlösung (PDB blockiert drain, topology spread, matchLabelKeys)

Alle Befehle werden auf der Arbeitsmaschine (worker) per SSH ausgeführt. kubectl ist
bereits für den Cluster konfiguriert (die kubeconfig wurde beim Hochfahren der Maschine
über `aws eks update-kubeconfig` erstellt).

## Aufgabe 1. Namespace `eks-131`

```bash
kubectl create namespace eks-131
```

## Aufgabe 2. Deployment `web` mit topology spread und matchLabelKeys

Der Cluster des Labs läuft in zwei Zonen (`eu-central-1a` und `eu-central-1b`), mit
privaten Subnetzen `eks1`/`eks2` für jede davon. Das reicht, damit Karpenter die Knoten auf
zwei Zonen verteilt und `topologySpreadConstraints` die Pods darüber verteilt.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-131
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
          matchLabelKeys:
            - pod-template-hash
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
EOF

kubectl rollout status deployment/web -n eks-131
```

Wir prüfen die Bereitschaft und die Verteilung über die Zonen:

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

In der Spalte `NODE` der drei Pods sollten mindestens zwei verschiedene Knoten stehen, und
diese Knoten sollten unterschiedliche Werte von `topology.kubernetes.io/zone` haben.
`matchLabelKeys: [pod-template-hash]` beeinflusst dieses erste Deployment noch nicht (es
gibt nur eine Revision) - es zeigt sich in Aufgabe 6.

## Aufgabe 3. Symptom: ein zu strenges PDB blockiert drain

Wir erstellen ein PDB, das verlangt, dass alle 3 Replicas verfügbar sind - das Budget
erlaubt keine Eviction eines Pods:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: eks-131
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web
EOF
```

Wir nehmen den Knoten einer der `web`-Replicas und versuchen, ihn zu draining:

```bash
NODE=$(kubectl get pod -n eks-131 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node: $NODE"

mkdir -p /var/work/tests/artifacts/3
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=60s \
  > /var/work/tests/artifacts/3/drain_blocked.txt 2>&1
echo "drain exit code: $?"
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

Der Befehl schlägt fehl: `kubectl drain` versucht, die Eviction-API für den Pod `web`
aufzurufen, aber die API antwortet mit `429` wegen Budgetverletzung, und nach
`--timeout=60s` scheitert drain mit `global timeout reached`. Der Grund ist das PDB
`web-pdb` mit `minAvailable: 3`, das 3 verfügbare Replicas verlangt, während es genau 3
gibt - das Budget erlaubt also nie die Eviction einer einzigen: die Eviction kann nie
fortschreiten, drain bleibt hängen, bis das Budget gelockert wird.

Wir fügen die Erklärung demselben Artefakt hinzu:

```bash
cat >> /var/work/tests/artifacts/3/drain_blocked.txt <<'EOF'

Erklärung: Das PDB web-pdb setzt minAvailable: 3, gleich der Anzahl der Replicas des
Deployments web. Das Budget erlaubt keine Eviction eines einzigen Pods, deshalb antwortet
die Eviction-API mit 429, und kubectl drain hängt/läuft in ein Timeout - das ist das
Symptom eines zu strengen PDB, kein Clusterfehler.
EOF
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

## Aufgabe 4. Korrektur: PDB lockern und drain wiederholen

Zuerst bringen wir den Knoten zurück in Betrieb (drain hat ihn bereits cordoned):

```bash
kubectl uncordon "$NODE"
```

Wir lockern das Budget: jetzt kann eine von drei Replicas evakuiert werden
(`minAvailable: 2`):

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge -p '{"spec":{"minAvailable":2}}'
kubectl get pdb web-pdb -n eks-131
```

Wir wiederholen drain auf demselben Knoten - das Budget erlaubt jetzt die Eviction eines
Pods, drain geht durch:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s \
  > /var/work/tests/artifacts/4/drain_ok.txt 2>&1
echo "drain exit code: $?" >> /var/work/tests/artifacts/4/drain_ok.txt

echo "--- pdb status after drain ---" >> /var/work/tests/artifacts/4/drain_ok.txt
kubectl get pdb web-pdb -n eks-131 >> /var/work/tests/artifacts/4/drain_ok.txt
cat /var/work/tests/artifacts/4/drain_ok.txt
```

Wir bringen den Knoten zurück in Betrieb und warten, dass alle 3 Replicas wieder bereit
sind (der Ersatz landete auf einem anderen Knoten):

```bash
kubectl uncordon "$NODE"
kubectl rollout status deployment/web -n eks-131
```

## Aufgabe 5. unhealthyPodEvictionPolicy: AlwaysAllow

Standardmäßig verwendet das PDB die Policy `IfHealthyBudget`: ein ungesunder (nicht
`Ready`) Pod kann nur evakuiert werden, wenn das Budget dadurch ohnehin nicht verletzt
würde. Wenn die Anwendung kaputt ist und ein Pod in `CrashLoopBackOff` hängt, blockiert
dieser Pod selbst die Budgetberechnung und kann drain für immer verhindern. `AlwaysAllow`
hebt diese Blockade auf: ungesunde Pods können immer evakuiert werden, gesunde bleiben
durch das Budget geschützt.

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge \
  -p '{"spec":{"unhealthyPodEvictionPolicy":"AlwaysAllow"}}'

kubectl get pdb web-pdb -n eks-131 -o jsonpath='{.spec.unhealthyPodEvictionPolicy}'
echo
```

Wir speichern die Erklärung im Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/unhealthy_policy.txt <<'EOF'
unhealthyPodEvictionPolicy: AlwaysAllow wurde web-pdb hinzugefügt.

Standardmäßig (IfHealthyBudget) wird ein ungesunder Pod nur evakuiert, wenn currentHealthy
nicht unter desiredHealthy fällt, deshalb zählt sich ein Pod in CrashLoopBackOff selbst als
Teil des Budgets und kann drain für immer blockieren, auch wenn die Anwendung schon nicht
mehr funktioniert.

AlwaysAllow erlaubt die Eviction eines ungesunden Pods unabhängig vom Budget: ein kaputter
Pod in CrashLoopBackOff hält drain nicht mehr auf, und die gesunden Replicas bleiben durch
das PDB geschützt.
EOF
cat /var/work/tests/artifacts/5/unhealthy_policy.txt
```

## Aufgabe 6. Rolling Update: matchLabelKeys lässt alte Pods die Verteilung nicht stören

Wir aktualisieren das Deployment, sodass eine neue Revision entsteht (neuer
`pod-template-hash`): wir fügen eine Umgebungsvariable hinzu. Alte und neue Pods tragen
gemeinsam das Label `app: web`, aber `matchLabelKeys: [pod-template-hash]` in
`topologySpreadConstraints` zwingt dazu, den Skew nur innerhalb der eigenen Revision zu
zählen, sodass neue Pods nicht von alten Replicas blockiert werden.

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl set env deployment/web -n eks-131 RELEASE=v2

kubectl rollout status deployment/web -n eks-131 --timeout=180s \
  | tee /var/work/tests/artifacts/6/rollout.txt
```

Wir prüfen, dass es keine hängenden `Pending`-Pods gibt und die Aktualisierung wirklich
angewendet wurde:

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get deploy web -n eks-131 \
  -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}'
echo
```

Ohne `matchLabelKeys: [pod-template-hash]` würden sowohl alte als auch neue Pods zum Skew
beitragen - sie teilen sich das Label `app: web`. Damit fügt der Scheduler dem Selektor das
Revisions-Label hinzu und zählt die Verteilung nur innerhalb der eigenen Revision.

Eine ehrliche Anmerkung, die man selbst prüfen sollte, statt sie einfach zu glauben. Auf
diesem Testaufbau gelingt der Rollout AUCH ohne `matchLabelKeys` - durch Experiment
geprüft: ein zweites Deployment mit derselben Topologie, aber ohne dieses Feld, mit
`maxUnavailable: 0` und `maxSurge: 1`, wurde in derselben Zeit aktualisiert, `Pending`
dauerte weniger als fünf Sekunden und war eine gewöhnliche Warteschleife des Schedulers,
keine Blockade durch Skew. Der Grund ist einfach: drei Replicas auf zwei Zonen ergeben eine
Verteilung von 2 plus 1, und der zusätzliche Pod passt immer in die Zone mit weniger Pods,
und wenn auf den Knoten kein Platz ist, hebt Karpenter einen weiteren an.

Wo der Unterschied real wird: ein statischer Pool ohne Reservekapazität, mehr als zwei
Zonen und eine ungleich verteilte alte Revision. Dann lässt der über beide Revisionen
zusammen berechnete Skew dem neuen Pod keine zulässige Zone, und er wartet, bis eine alte
Replica abgeht - bei einem großen Pool wird daraus ein langsamer Rollout mit unklaren
`Pending`. Deshalb wird `matchLabelKeys` vorab gesetzt, nicht erst nach einem Vorfall. Das
tatsächlich jetzt geprüfte Ergebnis ist, dass die neue Revision innerhalb von `maxSkew: 1`
über die Zonen verteilt geblieben ist:

```bash
HASH=$(kubectl get po -n eks-131 -l app=web \
  -o jsonpath='{.items[0].metadata.labels.pod-template-hash}')
for n in $(kubectl get po -n eks-131 -l app=web,pod-template-hash="$HASH" \
    -o jsonpath='{.items[*].spec.nodeName}'); do
  kubectl get node "$n" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}'
done | sort | uniq -c
```

## Schnellprüfung

```bash
check_result
```
