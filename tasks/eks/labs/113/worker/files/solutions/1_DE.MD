[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 113 - Referenzlösung (Cluster-Upgrade und Rollback)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl und aws cli sind
bereits für den Cluster des Labs konfiguriert. Speichern Sie zuerst den Clusternamen in
einer Variable - Sie brauchen ihn in fast jedem Befehl:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## Aufgabe 1. Namespace und die Startversion des Clusters

```bash
kubectl create namespace eks-113

aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Erwartete Ausgabe - `"1.35"`. Der Cluster dieses Labs startet absichtlich eine Minor-Version
unter der aktuellen GA-Version `1.36`, damit Sie später ein reales Upgrade und einen
Rollback durchlaufen können.

Zusätzlich (nicht Teil der Prüfung, aber nützlich vor dem Upgrade): Schauen Sie sich an,
welche `apiVersion` der API-Server aktuell bedient, um sie später mit der Version nach dem
Upgrade zu vergleichen:

```bash
kubectl get --raw /apis | grep -o '"groupVersion":"[^"]*"'
```

## Aufgabe 2. Upgrade-Bereitschaft prüfen

Upgrade insights ist eine eingebaute EKS-Prüfung, die nach Dingen sucht, die das Upgrade
blockieren könnten: Verwendung von APIs, die in der Zielversion entfernt werden, sowie den
allgemeinen Cluster-Zustand. Die Liste der Cluster-Insights ohne `--filter` enthält alle
Kategorien, einschließlich der Upgrade-Bereitschaft:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks list-insights --cluster-name "$CLUSTER" \
  > /var/work/tests/artifacts/2/upgrade_insights.json
cat /var/work/tests/artifacts/2/upgrade_insights.json
```

Prüfen Sie, dass unter den Insights kein `ERROR`-Status auftaucht (er blockiert das Upgrade,
bis er behoben ist):

```bash
grep '"status"' /var/work/tests/artifacts/2/upgrade_insights.json
```

Hat ein Insight den Status `WARNING` - das ist kein Blocker, aber es lohnt sich, die
Empfehlung über `aws eks describe-insight --cluster-name "$CLUSTER" --id <insight-id>` zu
lesen. Liegt ein `ERROR` vor, beheben Sie die Ursache (meist eine veraltete `apiVersion` in
Manifesten) und führen Sie `aws eks list-insights` erneut aus - EKS aktualisiert Insights
einmal alle 24 Stunden, Sie können die Aktualisierung über
`aws eks start-insights-refresh --cluster-name "$CLUSTER"` erzwingen.

## Aufgabe 3. Upgrade der Control Plane auf 1.36

Das Upgrade bewegt sich immer nur um eine Minor-Version: `1.35` -> `1.36`. Starten Sie es
und speichern Sie die Update-`id`:

```bash
UPDATE_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.36 \
  --query 'update.id' --output text)
echo "$UPDATE_ID"
```

Das Update der Control Plane läuft im Hintergrund und kann 20-40 Minuten dauern. Warten Sie
auf den Status `Successful`:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$UPDATE_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

Bestätigen Sie die neue Version:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Erwartete Ausgabe - `"1.36"`. Nodes und Add-ons ändern an dieser Stelle noch nicht ihre
Version - das ist der nächste Schritt.

## Aufgabe 4. Upgrade der Core-Add-ons auf Versionen für 1.36

Die Control Plane wurde aktualisiert, aber `kube-proxy` und `coredns` folgen ihr nicht
automatisch - sie werden separat aktualisiert, auf mit der neuen Minor-Version kompatible
Versionen. Prüfen Sie die genauen kompatiblen Versionen so (falls Sie die Kurstabelle nicht
zur Hand haben):

```bash
aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
```

Aktualisieren Sie beide Add-ons (dieselben Versionen wie in Lab 101, wo der Cluster direkt
auf `1.36` startet):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.36.0-eksbuild.14
aws eks update-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --addon-version v1.14.3-eksbuild.3
```

Warten Sie für jedes von ihnen auf `ACTIVE`:

```bash
for addon in kube-proxy coredns; do
  while true; do
    status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$addon" \
      --query 'addon.status' --output text)
    echo "$addon status=$status"
    [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
    sleep 10
  done
done
```

Prüfen Sie die resultierenden Versionen:

```bash
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --query 'addon.addonVersion'
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --query 'addon.addonVersion'
```

`vpc-cni` und `eks-pod-identity-agent` sind nicht so eng an die Kubernetes-Minor-Version
gebunden wie `kube-proxy` und `coredns`, daher können Sie sie innerhalb dieses Labs
unangetastet lassen - im echten Betrieb lohnt es sich trotzdem, ihre Versionen über
`describe-addon-versions` zu prüfen.

## Aufgabe 5. Rollback-Bereitschaft prüfen

Rollback readiness insights erscheinen erst nach einem Upgrade und existieren genau 7 Tage
lang - das Rollback-Fenster. Betrachten Sie sie mit einem Kategoriefilter:

```bash
mkdir -p /var/work/tests/artifacts/5
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  > /var/work/tests/artifacts/5/rollback_readiness.json
cat /var/work/tests/artifacts/5/rollback_readiness.json
```

Prüfen Sie die Statuswerte - `ERROR` und `UNKNOWN` blockieren den Rollback:

```bash
grep '"status"' /var/work/tests/artifacts/5/rollback_readiness.json
```

Falls Sie kürzlich einen der Blocker behoben haben und nicht auf die tägliche
Aktualisierung warten möchten:

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
```

## Aufgabe 6. Rollback der Control Plane auf 1.35

In Aufgabe 4 haben wir `kube-proxy` auf die `1.36`-kompatible Version angehoben. Versuchen
Sie jetzt, die Control Plane zurückzurollen, berechnet EKS die rollback readiness insights
im Moment des Aufrufs von `update-cluster-version` neu und findet einen `ERROR` bei der
Prüfung `kube-proxy version rollback compatibility`: Die `kube-proxy`-Version `1.36` wäre
nach dem Rollback der Control Plane auf `1.35` neuer als die Control Plane, was gegen die
version skew policy verstößt. Genau deshalb sagt Kapitel 39: "Nodes/Add-ons vor der Control
Plane zurückrollen, wenn die Add-on-Version vor der Zielversion liegt" - `aws eks
list-insights` direkt nach dem Upgrade zeigt dieses Problem noch nicht (rollback insights
werden gegen den aktuellen Zustand des Clusters neu berechnet), es taucht aber auf, wenn Sie
sie nach dem Add-on-Update erneut abfragen.

Die richtige Reihenfolge ist, zuerst `kube-proxy` auf eine `1.35`-kompatible Version
zurückzubringen und erst danach die Control Plane zurückzurollen:

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.35.3-eksbuild.13

while true; do
  status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
    --query 'addon.status' --output text)
  echo "kube-proxy status=$status"
  [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
  sleep 10
done
```

Prüfen Sie, dass der kube-proxy-Insight `PASSING` geworden ist (Sie können eine Neuberechnung
erzwingen, wenn Sie nicht einen Tag warten möchten):

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
sleep 30
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  --query 'insights[].{name:name,status:insightStatus.status}'
```

Jetzt können Sie die Control Plane ohne `--force` zurückrollen - auf die Standardweise,
genauso wie beim Upgrade, aber mit der vorherigen Version:

```bash
ROLLBACK_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.35 \
  --query 'update.id' --output text)
echo "$ROLLBACK_ID"

aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type'
```

Der Update-Typ in der Antwort ist `VersionRollback`, kein reguläres `VersionUpdate`.
Speichern Sie das in einem Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/6
aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type' --output text > /var/work/tests/artifacts/6/rollback_update.txt
cat /var/work/tests/artifacts/6/rollback_update.txt
```

Der Rollback läuft ebenfalls im Hintergrund und kann 20-40 Minuten dauern. Warten Sie auf
`Successful`:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

Bestätigen Sie, dass die Control Plane wieder auf `1.35` läuft:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Erwartete Ausgabe - `"1.35"`. Die etcd-Daten, Workloads und Persistent Volumes werden beim
Rollback nicht angefasst - nur die Version der Control Plane wird zurückgerollt, das ist
kein Ersatz für ein Backup.

## Schnellprüfung

```bash
check_result
```
