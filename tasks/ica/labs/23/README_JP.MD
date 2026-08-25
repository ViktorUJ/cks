[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 23 - WasmPlugin: WebAssemblyによるdata planeの拡張

> [リファレンス解答](worker/files/solutions/1_JP.MD)

## 概要

Istioの組み込みCRD（`AuthorizationPolicy`、`EnvoyFilter`）だけでは足りず、
data plane内で独自ロジックが必要になることがあります。そのために**WebAssembly (Wasm)**があります。
（または既製の）モジュールを作成すると、Envoyはプロキシを再ビルドせずに、
実行時に動的にロードできます。

このラボでは、リクエストにHTTP Basic認証を必要とさせるため、
ingress gatewayにcommunityモジュール**`basic_auth`**を接続します。

> Istio `1.29`は`WasmPlugin` API（`extensions.istio.io/v1alpha1`）を使用します。`1.30+`では、
> 後継として`TrafficExtension` APIが導入されます。

Istioはすでにインストール済みです（ingress gatewayはNodePort `32080`）。アプリケーション`ping-pong`は
namespace `app`にデプロイされ、`http://myapp.local:32080/`で公開されています。

```mermaid
flowchart LR
    C["client"] --> GW["istio-ingressgateway<br>+ WasmPlugin basic_auth"]
    GW -->|"認証情報なし/不正"| R["401 Unauthorized"]
    GW -->|"正しい認証情報"| A["ping-pong<br>200 OK"]
    OCI["oci://ghcr.io/.../basic_auth:1.12.0"] -.pull.-> GW
```

## インフラストラクチャ

| コンポーネント | タイプ | 数 | 役割 |
|---|---|---|---|
| control-plane | `t3.medium` | 1 | master + istiod + ingress gateway |
| worker | `t3.small` | 1 | アプリケーション用の容量 |
| worker PC | `t3.small` | 1 | ワークステーション: `kubectl`、`curl`、`check_result` |

リージョン: `eu-central-1`（AZ `eu-central-1a` / `eu-central-1b`）。

## デプロイ

```bash
TASK=23 make run_ica_task
```

## WebAssemblyとは（初めての方向け）

簡潔に言うと、**WebAssembly (Wasm)**は別のプログラムの内部で安全に実行できる、
小さなコンパイル済みプログラムの形式です。もともとWasmはブラウザ向けに考案されました
（JavaScriptと並行してC++/Rustのコードを実行するため）が、現在ではネットワークプロキシの
内部を含め、さまざまな場所で使用されています。

ここで何が起きているのかを、順を追って見ていきましょう。

- **data planeとEnvoyとは。** Istioでは、各Podの隣で**Envoy**プロキシ
  （いわゆる「sidecar」）が動作します。Podのすべてのネットワークトラフィック、
  つまり受信・送信の両方がこれを通過します。これらのプロキシの集合を*data plane*と
  呼びます。mTLS、ルーティング、制限、認可などのルールを実際に適用するのはEnvoyです。
- **問題。** Envoyには多くの機能が「標準で」備わっていますが、すべてを想定することはできません。
  かつて独自ロジックを追加するには、EnvoyをC++で再ビルドしてプロキシイメージを置き換える必要がありました。
  これは時間がかかり、リスクがあり、アップデート時に壊れやすい方法です。
- **Wasmプラグインの考え方。** 再ビルドの代わりに、使いやすい言語
  （**Rust、C++、Go/TinyGo、AssemblyScript**）で小さなモジュールを書き、`.wasm`にコンパイルして
  Envoyに渡します。Envoyはこのモジュールを**再起動も再ビルドもなしに、その場で**ロードし、
  リクエストを通すようになります。
- **サンドボックス（sandbox）。** Wasmモジュールは隔離環境で実行されます。Envoyのメモリやホストに
  直接アクセスできず、厳密に定義されたインターフェースを通じてのみプロキシと通信します。モジュールが
  「クラッシュ」しても、プロキシ全体は停止しません。このため、プロキシ内で外部または独自コードを
  実行することは比較的安全です。
- **proxy-wasm ABI。** 「Envoy ↔ Wasmモジュール」の相互作用は、
  **proxy-wasm**プロトコル（「リクエストが来た」「ヘッダーが来た」「ボディが来た」などの
  関数フック群）によって標準化されています。共通規格のおかげで、同じモジュールは異なる
  Envoy/Istioバージョンや、proxy-wasmをサポートする他のプロキシでも動作します。
- **モジュールがプロキシへ届く仕組み。** モジュールは（通常のDockerイメージのように）
  **OCIイメージ**としてパッケージ化され、レジストリに格納されます。`WasmPlugin`で`url: oci://...`を
  指定すると、istio-agentがモジュールをダウンロードし、ノード上にキャッシュして、Envoyに
  HTTPフィルターとして接続します。

たとえるなら、これは「ブラウザのプラグイン/拡張機能」のようなものです。ただし、ここでプラグインを
インストールする先はブラウザではなくネットワークプロキシであり、処理するのはWebページではなく
サービス間のネットワークリクエストです。このラボでは、meshへの入口でログイン/パスワード
（HTTP Basic auth）を要求する既製の`basic_auth`モジュールが、この「プラグイン」になります。

## 既製モジュールと独自モジュールの作成方法

**既製Wasmモジュール（コードを書く必要はありません）。** 必要な機能はすでに誰かが実装している場合が多く、
`WasmPlugin`にイメージへのリンクを指定するだけで済みます。

- **istio-ecosystem/wasm-extensions** - Istioコミュニティによる公式サンプル
  （`basic_auth`など）。`ghcr.io/istio-ecosystem/wasm-extensions/...`で公開されており、
  このラボでもこれを使用します。
- ベンダー提供の**完成済みプロダクトモジュール**（たとえばWasmとしてのcoraza-WAF、OPA、
  各種auth/rate-limitフィルター）。OCIイメージとして配布されます。
- **WebAssembly Hub / OCIレジストリ** - モジュールは通常のOCIイメージとしてパッケージ化されるため、
  任意のレジストリ（ghcr、Docker Hub、ECR、プライベートHarbor）に格納できます。

ルールは簡単です。モジュールがOCIイメージとして存在するなら、`url: oci://...`と書くだけでよく、
コードを書く必要はありません。

**独自モジュールが必要な場合の近道。** 独自ロジックは、proxy-wasm SDKを使い、Wasmにコンパイル可能な
言語で書きます。

1. **言語とSDKを選択する。** 一般的なのは**Rust**（`proxy-wasm/proxy-wasm-rust-sdk`）、
   **Go/TinyGo**（`proxy-wasm-go-sdk`）、C++、AssemblyScriptです。本番ではRust
   （高速でコンパクトな`.wasm`）がよく選ばれます。
2. **フックを書く。** SDKで、たとえば`on_http_request_headers`（リクエストヘッダー到着時）、
   `on_http_response_headers`などのリクエストライフサイクルコールバックを実装します。中では、
   ヘッダーの検証、追加/変更、エラーの返却といった独自ロジックを実装します。
3. **Wasmにコンパイルする。** Rustの場合の例:
   ```bash
   rustup target add wasm32-wasip1
   cargo build --release --target wasm32-wasip1
   # 結果: target/wasm32-wasip1/release/my_plugin.wasm
   ```
4. **OCIイメージにパッケージ化してプッシュする。** IstioはOCIアーティファクト内のWasmを想定します。
   `buildah`/`docker`や`func-e`/`wasme`などのツールでビルドすると便利です。続いて
   `docker push <registry>/my-plugin:1.0`を実行します。
5. **WasmPlugin経由で接続する。** このラボと同様に`url: oci://<registry>/my-plugin:1.0`を指定し、
   必要に応じて独自パラメーターを持つ`pluginConfig`を設定します。

Rustによる最小限のロジック例（レスポンスヘッダーを追加）:

```rust
use proxy_wasm::traits::*;
use proxy_wasm::types::*;

proxy_wasm::main! {{
    proxy_wasm::set_http_context(|_, _| -> Box<dyn HttpContext> { Box::new(MyPlugin) });
}}

struct MyPlugin;
impl Context for MyPlugin {}
impl HttpContext for MyPlugin {
    fn on_http_response_headers(&mut self, _n: usize, _eos: bool) -> Action {
        self.set_http_response_header("x-my-plugin", Some("hello"));
        Action::Continue
    }
}
```

実際の開発については、`istio-ecosystem/wasm-extensions`リポジトリのガイドを参照してください
（OCIイメージの作成、テスト、ビルド方法）。

## 課題

1. プラグインなしでアプリケーションにアクセスできること（`200`）を確認する。
2. ingress gateway（`selector: istio=ingressgateway`）において、OCIレジストリから
   `basic_auth`モジュールをロードし、Basic認証を要求する`WasmPlugin`を適用する。
3. 認証情報なしのリクエストが`401`で拒否され、正しい認証情報では`200`となることを確認する。

## ステップ1. 基本動作（authなし）

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## ステップ2. WasmPluginを適用する

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

Ingress gateway上のistio-agentがWasm OCIイメージをダウンロードし、ローカルにキャッシュして
HTTPフィルターとして組み込みます。数秒待ってください。

## ステップ3. 確認

```bash
# 認証情報なし -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# 正しい認証情報あり -> 200  (admin3:admin3 の base64)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## 仕組み

- **WebAssembly (Wasm)**により、プロキシを再ビルドせずにEnvoyへカスタムロジックを追加し、
  実行時に動的にロードできます。
- **`url: oci://...`** - モジュールはOCIアーティファクトとして配布され、istio-agentが
  取得してキャッシュします。`file://`（イメージに組み込み済み）および`http(s)://`もサポートされます。
- **`phase: AUTHN`**はフィルターをチェーンの早い段階（ルーティング/認可より前）に配置します。
- **`selector`**はラベルによりプラグインをワークロードに限定します（ここではingress gateway）。
- **`pluginConfig`**はモジュールに渡されます。`basic_auth`は`basic_auth_rules`（パスプレフィックス、
  メソッド、許可する認証情報）を読み取ります。

## 有用な場面（実際のシナリオ）

- **カスタム認証/認可**: Basic auth、APIキー検証、リクエストのHMAC署名、標準外IdPとの統合など、
  `RequestAuthentication`/`AuthorizationPolicy`では表現できないもの。
- **リクエスト/レスポンスの操作**: 外部ソースからのヘッダー拡充、署名計算、本文の編集（PIIのマスキング）、
  パスの正規化。
- **境界でのプロトコルおよびビジネスロジック**: カスタムキーによる特有のrate limiting、
  feature flags、複雑なルールに基づくA/B、独自プロトコルのデコード。
- **コンプライアンスとセキュリティ**: 特殊な形式での監査ログ記録、WAF類似の検査、
  カスタムシグネチャによるブロック。
- **アプリケーションからのロジック分離**: 同じ横断的ロジック（auth、ロギング、ヘッダー）を、
  各言語の各サービスで実装するのではなく、mesh内で一度だけ実装します。

## 代替手段に対する利点

| アプローチ | 利点 | 欠点 / Wasmより劣る場合 |
|---|---|---|
| **組み込みCRD**（`AuthorizationPolicy`、`RequestAuthentication`、`Telemetry`、`EnvoyFilter` local ratelimit） | シンプル、宣言的、Istioでサポートされる | あらかじめ定められた機能に限定され、任意ロジックは表現できない |
| **`EnvoyFilter` + Lua**（lua-scriptsを参照） | 再ビルド不要、スクリプトをインラインで記述 | Luaのみ。重いタスクは低速。厳密な型付け/テストがなく、ロジックがYAMLに「分散」する |
| **ネイティブC++フィルターを使う`EnvoyFilter`** | 最大の速度 | Envoyの再ビルドとカスタムプロキシイメージが必要。アップグレードと互換性がなく、参入障壁が高い |
| **アプリケーション自体にロジックを置く** | 完全な制御 | 各言語の各サービスに重複し、一貫性とアップデートの確保が難しい |
| **外部サービス（ext_authz / callout）** | 任意の言語、個別のデプロイ | 各リクエストに追加のネットワークホップと遅延が発生し、運用するコンポーネントが1つ増える |
| **WasmPlugin（このラボ）** | Wasmにコンパイルできる任意の言語（C++、Rust、Go/TinyGo、AssemblyScript）で独自コードを作成可能。**Envoyの再ビルドや再起動なしに実行時ロード**。**in-process**で実行（ext_authzのようなネットワークホップなし）。Wasmサンドボックスによる分離と安全性。安定したproxy-wasm ABIによりEnvoy/Istioバージョン間で可搬性がある。OCIレジストリによるバージョニングと配布 | APIはAlphaステータス。モジュールの実行時ロードとキャッシュにオーバーヘッドがある。独自コードには保守、テスト、バージョン管理が必要。宣言的CRDよりデバッグが難しい |

**要するに:** Wasmはdata planeに*任意の*ロジックが必要で、かつ低遅延（in-process、
ext_authzのような余分なホップなし）、安全性（サンドボックス）、プロキシを再ビルドせずに
動的にフィルターをロールアウト/更新できることが重要な場合に優れています。

**実践における選択順序:** まず組み込みCRD → 不足する場合は`EnvoyFilter`
（簡単なものにはLuaも含む）→ ロジックを別サービスとして保持しやすく、遅延が重要でない場合は
外部`ext_authz` → プロキシ自体で高速なin-processコードが必要な場合は**Wasm**。Wasmの
運用コストも考慮してください。モジュール配布、バージョニング、実行時ロードが必要です
（`failStrategy`はロード失敗時の動作をfail-openまたはfail-closeに設定します）。

## 結果の確認

worker PCで実行します。

```bash
check_result
```

## まとめ

OCIレジストリからロードされる独自Wasmモジュールでdata planeを拡張し、アプリケーションを変更せずに
meshの境界でBasic認証を追加しました。`WasmPlugin`の利用は、Istioの組み込み機能だけでは不十分な場合に
求められるシニアレベルのスキルです。