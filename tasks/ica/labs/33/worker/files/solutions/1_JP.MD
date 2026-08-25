[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 33 - 参照解答

Istio `1.29.1`（デフォルトプロファイル、クラスター全体のディスカバリー、Sidecar スコープなし）と OPA
Gatekeeper は事前インストールされています。次の 3 つの名前空間が存在します。

- `app`（インジェクション済み、`mesh=enabled`）- `frontend`。
- `shop`（インジェクション済み、`mesh=enabled`）- `catalog` + サイドカーなしの `probe`。
- `legacy`（インジェクションされていない、`mesh` ラベルなし）- `legacy-app`。

`istioctl` はワーカー PC で利用できます。

## 目標

1. **discovery selectors** を有効にして、istiod が `mesh=enabled` の名前空間のみを追跡するようにする
   （`legacy` を除外）。
2. `app` に **Sidecar** の egress スコープを追加し、そのプロキシが `app` + `istio-system` のみを認識するようにする
   （`shop` を除外）。
3. istiod の **golden signals** を観察する。
4. **OPA Gatekeeper** でデプロイポリシーを適用する。

## ステップ 1. Discovery selectors

`mesh=enabled` に一致する `meshConfig.discoverySelectors` を指定してインストールを再適用します
（`istio-system`、`app`、`shop` にはこのラベルがあり、`legacy` にはありません）。

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    discoverySelectors:
      - matchLabels:
          mesh: enabled
EOF
istioctl install -f /tmp/iop.yaml -y
```

`legacy` がメッシュから消えたことを確認します（まだ Sidecar スコープを持たないプロキシから）。

```bash
istioctl proxy-config clusters deploy/catalog.shop | grep legacy-app || echo "legacy dropped"
```

## ステップ 2. app の Sidecar egress スコープ

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

`./*` = プロキシ自身の名前空間（`app`）、さらにコントロールプレーンおよび
ゲートウェイ向けの `istio-system/*`。それ以外のすべて（`shop` を含む）は `app` プロキシから除外されます。

```bash
istioctl proxy-config clusters deploy/frontend.app | grep catalog.shop || echo "shop dropped from app"
```

## ステップ 3. istiod の golden signals

```bash
# convergence time + push count (the key control-plane signals)
kubectl exec -n shop deploy/probe -c probe -- \
  curl -s http://istiod.istio-system:15014/metrics \
  | grep -E 'pilot_proxy_convergence_time|pilot_xds_pushes'

# how many proxies are connected / config sync state
istioctl proxy-status
```

`pilot_proxy_convergence_time` が主なシグナルです。これは変更がプロキシに到達するまでにかかる時間を示します。
`pilot_xds_pushes` はプッシュ数をカウントします。convergence time の増加またはプッシュエラーは、
コントロールプレーンに負荷がかかっていることを意味します。ステップ 1-2 のスコープレバーが、それを軽減するものです。

## ステップ 4. OPA Gatekeeper のデプロイポリシー

すべての名前空間にインジェクションラベルの宣言を必須とします（この章にある典型的な
デプロイ衛生ポリシーです）。テンプレートと制約を作成します。

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("namespace is missing required labels: %v", [missing])
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-injection
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["istio-injection"]
EOF
```

ポリシーが適用されていることを確認します（**拒否**されるはずです）。

```bash
kubectl create ns test-no-label
# Error ... admission webhook "validation.gatekeeper.sh" denied the request:
# namespace is missing required labels: {"istio-injection"}
```

## これが機能する理由

- **Discovery selectors** は、istiod がそもそも監視する名前空間を制限します。セレクターラベルのない
  名前空間はコントロールプレーンから見えず、そのサービスがどのプロキシのクラスターやエンドポイントにも
  ならないため、設定サイズとプッシュ処理を削減します。クラスターの一部がメッシュに含まれない場合に最も効果があります。
- **Sidecar egress scope** は、名前空間ごとに、プロキシに通知するサービスを制限します。
  `./*` + `istio-system/*` により、`app` プロキシは `shop`（またはメッシュの残りの部分）の設定を
  保持しなくなります。これにより、各プロキシの設定と istiod からのプッシュのファンアウトが縮小されます。
- **Golden signals**（`pilot_proxy_convergence_time`、`pilot_xds_pushes`、接続済みプロキシ数、
  istiod CPU/mem）は、コントロールプレーンが追随できているかを確認する手段です。スコープレバーは、
  convergence time を短縮する主な手段です。
- **OPA Gatekeeper** はベストプラクティスを admission ルールに変換します。準拠していないリソースは、
  単に推奨されないだけでなく、作成時に拒否されます。