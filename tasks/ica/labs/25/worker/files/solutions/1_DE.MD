[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 25 - Referenzlösung

Istio `1.29.1` und Prometheus sind installiert. **Flagger** läuft in `istio-system`. Der Namespace
`test` (istio-injection) enthält die Demo-Anwendung **podinfo** (`6.0.0`), einen
**flagger-loadtester** (erzeugt während der Analyse Traffic), und ein `public-gateway` existiert
in `istio-system`.

## Ziel

Erstelle eine `Canary`-Ressource, mit der Flagger die **progressive Bereitstellung** steuert: Bei
jedem neuen Image wird der Traffic schrittweise zum Canary verschoben, Metriken werden geprüft und
automatisch promoted (oder bei Fehlern automatisch zurückgerollt).

## Schritt 1. Den Canary erstellen

```bash
kubectl apply -f - <<'EOF'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 300
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: podinfo
  service:
    port: 9898
    targetPort: 9898
    gateways:
    - istio-system/public-gateway
    hosts:
    - app.example.com
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 20
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 2m -q 10 -c 2 http://podinfo-canary.test:9898/"
EOF
```

## Schritt 2. Warten, bis Flagger initialisiert ist

```bash
kubectl -n test get canary podinfo -w   # wait until STATUS = Initialized
kubectl -n test get deploy
# Flagger created: podinfo-primary, services podinfo/podinfo-canary/podinfo-primary,
# destinationrules and a virtualservice.
```

## Schritt 3. Eine Canary-Version auslösen

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.1
```

Flagger erkennt die neue Revision und startet die Analyse: Es verschiebt 20% → 40% → 50% des
Traffics zum Canary und prüft `request-success-rate` sowie `request-duration` in jedem
Intervall. Der Loadtester sendet weiterhin Traffic, damit die Metriken vorhanden sind.

## Schritt 4. Die Promotion beobachten

```bash
kubectl -n test describe canary/podinfo
# ... Advance podinfo.test canary weight 20/40/50
# ... Copying podinfo.test template spec to podinfo-primary.test
# ... Promotion completed!

kubectl -n test get canary podinfo         # STATUS = Succeeded
kubectl -n test get deploy podinfo-primary -o jsonpath='{.spec.template.spec.containers[*].image}'
# -> ghcr.io/stefanprodan/podinfo:6.0.1
```

Mit den obigen Einstellungen dauert die Promotion ungefähr 2–3 Minuten. Führe `check_result` aus,
nachdem `podinfo-primary` auf `6.0.1` aktualisiert wurde.

## Automatisches Rollback (optional)

Löse eine weitere Version aus und füge während der Analyse Fehler ein:

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.2
POD=$(kubectl -n test get pod -l app=flagger-loadtester -o jsonpath='{.items[0].metadata.name}')
kubectl -n test exec -it "$POD" -- hey -z 1m -c 5 -q 10 http://podinfo-canary.test:9898/status/500
```

Wenn fehlgeschlagene Metrikprüfungen den Schwellenwert erreichen, stoppt Flagger und rollt zurück:
Der Traffic kehrt zum Primary zurück, der Canary wird auf null skaliert und STATUS wird `Failed`.

## So funktioniert es

- Flagger überwacht das Ziel-`Deployment`. Bei einer Spec-Änderung erstellt bzw. aktualisiert es ein
  **canary**-Deployment und verschiebt den Traffic über Istio-Weights von
  `VirtualService`/`DestinationRule` schrittweise.
- Bei jedem Schritt fragt es **Prometheus** nach den konfigurierten Metriken ab. Wenn sie innerhalb
  der Schwellenwerte bleiben, fährt es fort, andernfalls rollt es nach `threshold` Fehlern zurück.
- `podinfo-primary` enthält immer die "bekanntermaßen gute" Version. Der Live-Traffic wird vom
  Primary bedient, bis der Canary vollständig erfolgreich ist und promoted wird.
- Dies macht aus einem riskanten manuellen Canary (Traffic-Shifting aus Labor 06) einen automatisierten,
  metrisch abgesicherten Release mit integriertem Rollback, die Essenz progressiver Bereitstellung.