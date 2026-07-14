[RU version](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD)

# Lab 23 - WasmPlugin: Erweiterung des data plane über WebAssembly

## Überblick

Manchmal reichen die eingebauten Istio-CRDs (`AuthorizationPolicy`, `EnvoyFilter`) nicht
aus - man braucht eigene Logik direkt im data plane. Dafür gibt es **WebAssembly (Wasm)**:
Sie schreiben (oder nehmen ein fertiges) Modul, und Envoy lädt es dynamisch zur Laufzeit,
ohne den Proxy neu zu bauen.

In diesem Lab binden Sie das Community-Modul **`basic_auth`** am ingress gateway ein,
sodass Anfragen eine HTTP-Basic-Authentifizierung erfordern.

> Istio `1.29` verwendet die API `WasmPlugin` (`extensions.istio.io/v1alpha1`). In `1.30+`
> löst die API `TrafficExtension` sie ab.

Istio ist bereits installiert (ingress gateway auf NodePort `32080`), die Anwendung
`ping-pong` ist im Namespace `app` deployt und unter `http://myapp.local:32080/`
veröffentlicht.

```mermaid
flowchart LR
    C["client"] --> GW["istio-ingressgateway<br>+ WasmPlugin basic_auth"]
    GW -->|"keine/falsche creds"| R["401 Unauthorized"]
    GW -->|"korrekte creds"| A["ping-pong<br>200 OK"]
    OCI["oci://ghcr.io/.../basic_auth:1.12.0"] -.pull.-> GW
```

## Infrastruktur

| Komponente | Typ | Anzahl | Rolle |
|---|---|---|---|
| control-plane | `t3.medium` | 1 | master + istiod + ingress gateway |
| worker | `t3.small` | 1 | Kapazität für die Anwendung |
| worker PC | `t3.small` | 1 | Arbeitsplatz: `kubectl`, `curl`, `check_result` |

Region: `eu-central-1` (AZ `eu-central-1a` / `eu-central-1b`).

## Deployment

```bash
TASK=23 make run_ica_task
```

## Was ist WebAssembly (für alle, die es noch nicht kennen)

Kurz gesagt: **WebAssembly (Wasm)** ist ein Format für kleine kompilierte Programme, die
man sicher innerhalb eines anderen Programms ausführen kann. Ursprünglich wurde Wasm für
Browser erdacht (um Code in C++/Rust neben JavaScript laufen zu lassen), aber heute wird
es überall eingesetzt, auch innerhalb von Netzwerk-Proxys.

Gehen wir Schritt für Schritt durch, was hier passiert:

- **Was data plane und Envoy sind.** In Istio läuft neben jedem Pod ein **Envoy**-Proxy
  (der berühmte „Sidecar"). Durch ihn läuft der gesamte Netzwerkverkehr des Pods -
  eingehend und ausgehend. Die Gesamtheit dieser Proxys nennt man *data plane*. Genau
  Envoy wendet die Regeln tatsächlich an: mTLS, Routing, Limits, Autorisierung.
- **Das Problem.** Envoy kann viel „von Haus aus", aber nicht alles lässt sich vorsehen.
  Früher musste man, um eigene Logik hinzuzufügen, Envoy in C++ neu bauen und das
  Proxy-Image austauschen - das ist langwierig, riskant und bricht bei Updates.
- **Die Idee des Wasm-Plugins.** Statt Neubau schreiben Sie ein kleines Modul in einer
  bequemen Sprache (**Rust, C++, Go/TinyGo, AssemblyScript**), kompilieren es zu `.wasm`
  und „füttern" es Envoy. Envoy lädt dieses Modul **im laufenden Betrieb, ohne Neustart
  und Neubau** und beginnt, Anfragen durch es zu leiten.
- **Sandbox.** Das Wasm-Modul läuft in einer isolierten Umgebung: es hat keinen direkten
  Zugriff auf den Speicher von Envoy oder den Host und kommuniziert mit dem Proxy nur über
  eine streng definierte Schnittstelle. Selbst wenn das Modul „abstürzt", reißt es den
  Proxy nicht mit. Das macht das Ausführen fremden/eigenen Codes in Proxys relativ sicher.
- **proxy-wasm ABI.** Die Interaktion „Envoy ↔ Wasm-Modul" ist durch das Protokoll
  **proxy-wasm** standardisiert (eine Reihe von Hook-Funktionen: „Anfrage eingetroffen",
  „Header eingetroffen", „Body eingetroffen" usw.). Dank dieses gemeinsamen Standards
  funktioniert dasselbe Modul auf verschiedenen Versionen von Envoy/Istio und sogar in
  anderen Proxys, die proxy-wasm unterstützen.
- **Wie das Modul in den Proxy gelangt.** Das Modul wird in ein **OCI-Image** verpackt
  (wie ein normales Docker-Image) und in eine Registry gelegt. In `WasmPlugin` geben Sie
  `url: oci://...` an, und der istio-agent lädt das Modul selbst herunter, cached es auf
  dem Node und bindet es als HTTP-Filter in Envoy ein.

Analogie: Es ist wie ein „Plugin/Erweiterung für den Browser", nur wird das Plugin hier
nicht in den Browser installiert, sondern in einen Netzwerk-Proxy, und es verarbeitet
keine Webseiten, sondern Netzwerkanfragen zwischen Services. In diesem Lab ist ein solches
„Plugin" das fertige Modul `basic_auth`, das beim Eintritt ins Mesh Login/Passwort
(HTTP-Basic auth) verlangt.

## Fertige Module und wie man ein eigenes erstellt

**Fertige Wasm-Module (kein Code nötig).** Oft ist die benötigte Funktionalität bereits
von jemandem geschrieben - es genügt, im `WasmPlugin` einen Verweis auf das Image
anzugeben:

- **istio-ecosystem/wasm-extensions** - offizielle Beispiele der Istio-Community
  (`basic_auth` u. a.), veröffentlicht unter
  `ghcr.io/istio-ecosystem/wasm-extensions/...` (genau dieses verwenden wir im Lab).
- **Fertige Produktmodule** von Anbietern (z. B. coraza-WAF als Wasm, OPA, verschiedene
  auth/rate-limit-Filter), die als OCI-Images verteilt werden.
- **WebAssembly Hub / OCI-Registries** - Module werden als normale OCI-Images verpackt,
  daher lassen sie sich in jeder Registry ablegen (ghcr, Docker Hub, ECR, privates
  Harbor).

Die Regel ist einfach: Liegt das Modul als OCI-Image vor - schreiben Sie einfach
`url: oci://...`, und Code muss nicht geschrieben werden.

**Wenn ein eigenes Modul nötig ist - der kurze Weg.** Eigene Logik wird in einer Sprache
geschrieben, die zu Wasm kompiliert, unter Verwendung des proxy-wasm SDK:

1. **Sprache und SDK wählen.** Beliebt: **Rust** (`proxy-wasm/proxy-wasm-rust-sdk`),
   **Go/TinyGo** (`proxy-wasm-go-sdk`), C++ oder AssemblyScript. Für die Produktion nimmt
   man häufiger Rust (schnelles, kompaktes `.wasm`).
2. **Hooks schreiben.** Im SDK implementieren Sie Callbacks des Anfrage-Lebenszyklus, etwa
   `on_http_request_headers` (Request-Header eingetroffen), `on_http_response_headers`
   usw. Darin - Ihre Logik: einen Header prüfen, hinzufügen/ändern, einen Fehler
   zurückgeben.
3. **Zu Wasm kompilieren.** Zum Beispiel für Rust:
   ```bash
   rustup target add wasm32-wasip1
   cargo build --release --target wasm32-wasip1
   # Ergebnis: target/wasm32-wasip1/release/my_plugin.wasm
   ```
4. **In ein OCI-Image verpacken und pushen.** Istio erwartet Wasm innerhalb eines
   OCI-Artefakts. Praktisch ist der Bau mit Werkzeugen wie `buildah`/`docker` oder
   `func-e`/`wasme`; dann `docker push <registry>/my-plugin:1.0`.
5. **Über WasmPlugin einbinden.** Sie geben `url: oci://<registry>/my-plugin:1.0` und bei
   Bedarf `pluginConfig` mit Ihren Parametern an - genau wie in diesem Lab.

Minimalbeispiel der Logik in Rust (wir fügen einen Antwort-Header hinzu):

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

Für die reale Entwicklung sehen Sie sich die Guides im Repository
`istio-ecosystem/wasm-extensions` an (wie man OCI-Images schreibt, testet und baut).

## Aufgabe

1. Prüfen, dass die Anwendung ohne Plugin erreichbar ist (`200`).
2. Ein `WasmPlugin` anwenden, das am ingress gateway (`selector: istio=ingressgateway`)
   das Modul `basic_auth` aus der OCI-Registry lädt und Basic-Authentifizierung verlangt.
3. Prüfen, dass eine Anfrage ohne Anmeldedaten mit `401` abgewiesen wird und mit korrekten
   Daten `200` liefert.

## Schritt 1. Basisverhalten (ohne auth)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Schritt 2. WasmPlugin anwenden

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

Der istio-agent am ingress gateway lädt das OCI-Image des Wasm herunter, cached es lokal
und bindet es als HTTP-Filter ein. Geben Sie ihm ein paar Sekunden.

## Schritt 3. Prüfung

```bash
# ohne Anmeldedaten -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# mit korrekten Daten -> 200  (base64 von admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## Wie es funktioniert

- **WebAssembly (Wasm)** erlaubt, Envoy um eigene Logik zu erweitern, ohne den Proxy neu
  zu bauen, und diese dynamisch zur Laufzeit zu laden.
- **`url: oci://...`** - das Modul wird als OCI-Artefakt geliefert; der istio-agent lädt
  und cached es. Ebenfalls unterstützt werden `file://` (ins Image eingebettet) und
  `http(s)://`.
- **`phase: AUTHN`** platziert den Filter früh in der Kette (vor Routing/Autorisierung).
- **`selector`** beschränkt das Plugin über Labels auf bestimmte Workloads (hier - ingress
  gateway).
- **`pluginConfig`** wird an das Modul übergeben; `basic_auth` liest `basic_auth_rules`
  (Pfad-Präfix, Methoden, zulässige Anmeldedaten).

## Wann das nützlich ist (reale Szenarien)

- **Eigene Authentifizierung/Autorisierung**: Basic auth, Prüfung eines API-Keys,
  HMAC-Signatur der Anfrage, Integration mit einem nicht standardmäßigen IdP - das, was
  sich nicht über `RequestAuthentication`/`AuthorizationPolicy` ausdrücken lässt.
- **Manipulation von Anfragen/Antworten**: Anreicherung von Headern aus einer externen
  Quelle, Berechnung einer Signatur, Bearbeitung des Bodys (Maskierung von PII),
  Normalisierung von Pfaden.
- **Protokoll- und Geschäftslogik am Rand**: spezifisches rate limiting nach eigenem
  Schlüssel, feature flags, A/B auf Basis komplexer Regeln, Dekodierung eines proprietären
  Protokolls.
- **Compliance und Sicherheit**: Audit-Logging in einem besonderen Format, WAF-ähnliche
  Prüfungen, Blockierung nach eigenen Signaturen.
- **Auslagerung von Logik aus der Anwendung**: dieselbe Cross-Cutting-Logik (auth,
  Logging, Header) wird einmal im Mesh implementiert und nicht in jedem Service in jeder
  Sprache.

## Vorteile gegenüber Alternativen

| Ansatz | Vorteile | Nachteile / wann schlechter als Wasm |
|---|---|---|
| **Eingebaute CRDs** (`AuthorizationPolicy`, `RequestAuthentication`, `Telemetry`, `EnvoyFilter` local ratelimit) | Einfach, deklarativ, von Istio unterstützt | Auf vorgegebene Möglichkeiten beschränkt; beliebige Logik nicht ausdrückbar |
| **`EnvoyFilter` + Lua** (siehe lua-scripts) | Ohne Neubau, Skript inline | Nur Lua; schwere Aufgaben langsamer; keine strenge Typisierung/Tests; Logik über YAML „verstreut" |
| **`EnvoyFilter` mit nativem C++-Filter** | Maximale Geschwindigkeit | Neubau von Envoy und eigenes Proxy-Image nötig; inkompatibel mit Upgrades; hohe Einstiegshürde |
| **Logik in der Anwendung selbst** | Volle Kontrolle | Wird in jedem Service und jeder Sprache dupliziert; Einheitlichkeit und Aktualisierung schwer sicherzustellen |
| **Externer Service (ext_authz / callout)** | Beliebige Sprache, separates Deployment | Zusätzlicher Netzwerk-Hop und Latenz pro Anfrage; eine weitere Komponente im Betrieb |
| **WasmPlugin (dieses Lab)** | Eigener Code in beliebiger Sprache mit Kompilierung zu Wasm (C++, Rust, Go/TinyGo, AssemblyScript); Laden **zur Laufzeit ohne Neubau von Envoy und ohne Neustart**; Ausführung **in-process** (kein Netzwerk-Hop wie bei ext_authz); Wasm-Sandbox - Isolation und Sicherheit; Portabilität zwischen Versionen von Envoy/Istio dank stabilem proxy-wasm ABI; Versionierung und Auslieferung über OCI-Registry | Alpha-Status der API; Overhead durch Laufzeit-Laden und Caching des Moduls; eigener Code muss gepflegt, getestet und versioniert werden; Debugging schwerer als bei deklarativen CRDs |

**Kurz gesagt:** Wasm gewinnt, wenn *beliebige* Logik im data plane nötig ist, dabei aber
niedrige Latenz (in-process, ohne zusätzlichen Hop wie bei ext_authz), Sicherheit
(Sandbox) und die Möglichkeit wichtig sind, den Filter dynamisch ohne Neubau des Proxys
auszurollen/zu aktualisieren.

**Reihenfolge der Wahl in der Praxis:** zuerst eingebaute CRDs → wenn nicht ausreichend,
`EnvoyFilter` (u. a. Lua für Einfaches) → externes `ext_authz`, wenn die Logik einfacher
als separater Service zu halten ist und die Latenz unkritisch ist → **Wasm**, wenn eigener
schneller in-process Code im Proxy selbst gebraucht wird. Berücksichtigen Sie die
Betriebskosten von Wasm: Auslieferung des Moduls, Versionierung und Laufzeit-Laden
(`failStrategy` legt das Verhalten bei fehlgeschlagenem Laden fest - fail-open oder
fail-close).

## Ergebnisprüfung

Führen Sie auf dem worker PC aus:

```bash
check_result
```

## Fazit

Sie haben den data plane um ein eigenes Wasm-Modul erweitert, das aus einer OCI-Registry
geladen wird, und Basic-Authentifizierung am Rand des Mesh hinzugefügt, ohne die Anwendung
zu ändern. Die Arbeit mit `WasmPlugin` ist eine Senior-Fähigkeit für Fälle, in denen die
eingebauten Möglichkeiten von Istio nicht ausreichen.
