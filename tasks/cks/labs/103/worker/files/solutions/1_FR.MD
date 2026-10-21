[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 103 - solution de référence

> Les commandes s'exécutent sur le worker, sauf indication explicite de `control-plane`. Avant de modifier les
> static Pod manifests, faites-en des copies. Le kubelet remarquera lui-même la modification des fichiers et recréera
> les static Pods correspondants ; ne les supprimez pas via la Kubernetes API.
>
> À l'examen, `k` (`alias k=kubectl`) et la bash-completion pour lui sont déjà configurés sur le SSH-host -
> ne perdez pas de temps à les configurer, utilisez simplement `k` (voir le chapitre 33.6).

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
k config use-context "$CTX"
ssh control-plane hostname
```

## Tâche 1. Rapport kube-bench

`kube-bench` `0.16.0` est déjà installé sur `control-plane` (comme à l'examen réel, où
les outils CIS Benchmark sont déjà présents sur les nœuds) - inutile de le copier depuis le worker. Kubernetes
`1.36` ne figure pas encore dans la support table officielle de kube-bench ; le version mapping intégré
de cette version se termine par l'entrée `"1.34": "cis-1.12"` - il n'y a pas de profils plus récents (y compris
un quelconque profil pour 1.35/1.36) dans `0.16.0`, nous utilisons donc précisément `cis-1.12`
comme le plus proche existant. Nous le lançons donc de force comme approximate
hardening signal, et non comme authoritative CIS compliance assessment.

```bash
mkdir -p /var/work/tests/artifacts/1
{
  printf 'kubernetes_version=%s\n' "$(k version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-1.12\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,node,controlplane,etcd,policies'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

grep '== Summary' /var/work/tests/artifacts/1/kube-bench.txt
# == Summary master ==
# == Summary node ==
# == Summary controlplane ==
# == Summary etcd ==
# == Summary policies ==
```

Vérifiez à l'œil que les cinq `== Summary <target> ==` sont présentes - sans
`--targets` explicite, une partie d'entre elles (`etcd`, `policies`) n'entrera pas dans le rapport.

## Tâche 2. Hardening du kubelet

Ne vous rappelez pas les noms des champs de mémoire - à l'examen, il est plus rapide de les extraire directement du rapport
kube-bench déjà produit (tâche 1). Chaque check y a une section `== Remediations <target> ==`
avec le texte de correction tout prêt - `grep -A1` sur le numéro du check donne tout de suite le champ voulu :

```bash
grep -A1 '^4.2.1 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.1 If using a Kubelet config file, edit the file to set `authentication: anonymous: enabled` to
# `false`.

grep '^4.2.4 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.4 If using a Kubelet config file, edit the file to set `readOnlyPort` to 0.
```

Sur le control-plane, le kubelet lit `/var/lib/kubelet/config.yaml`. Dans le YAML doivent figurer précisément
les champs suivants (n'ajoutez pas deux fois des clés de même nom) :

```yaml
readOnlyPort: 0
authentication:
  anonymous:
    enabled: false
```

À l'examen, ne préfixez pas chaque commande de `sudo` - devenez root une seule fois (`sudo -i`), c'est plus
rapide :

```bash
ssh control-plane
sudo -i
cp /var/lib/kubelet/config.yaml ~/2-kubelet-config.yaml
vim /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet
exit   # sortir du shell root
exit   # sortir de control-plane
```

On vérifie non pas le texte statique du fichier, mais la configuration en vigueur que le kubelet
a réellement appliquée - via l'API `configz` (l'analyse textuelle du YAML se laisse facilement tromper par des champs semblables
comme `webhook.enabled`, tandis que `configz` reflète ce que le kubelet lui-même considère comme sa
configuration) :

```bash
NODE=$(k get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}')

k get --raw="/api/v1/nodes/${NODE}/proxy/configz" \
  | jq -e '
      (.kubeletconfig.readOnlyPort // 0) == 0 and
      .kubeletconfig.authentication.anonymous.enabled == false
    '

k wait --for=condition=Ready "node/${NODE}" --timeout=120s
```

## Tâche 3. Désactiver profiling de kube-apiserver

La même technique que dans la tâche 2 - utilisez le rapport kube-bench de la tâche 1 comme source de
vérité, ne vous rappelez pas le flag de mémoire :

```bash
grep -A2 '^1.2.15 ' /var/work/tests/artifacts/1/kube-bench.txt
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
# --profiling=false
```

Ajoutez le paramètre à la liste `command` du conteneur `kube-apiserver`.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/3-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Dans le tableau command, ajoutez une ligne avec la même indentation que les autres arguments :
# - --profiling=false
exit
exit

ssh control-plane "sudo grep -n -- '--profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
k get po -n kube-system -l component=kube-apiserver
# STATUS doit passer à Running - sinon, patientez quelques secondes et recommencez
```

## Tâche 4. TLS Secret et Ingress

Créez une application minimale et un Service, générez un certificat auto-signé pour
le nom DNS exact, puis créez le TLS Secret et l'Ingress. Le controller `ingress-nginx` est déjà
installé et Ready dans ce lab (lab-owned fixture, version figée dans le bootstrap) - nous nous en assurerons
avant de créer l'Ingress.

Les noms courts de ressources (`ns` = namespace, `deploy` = deployment, `svc` = service,
`ing` = ingress, `po` = pod) économisent de la frappe sous la pression du temps.

```bash
k get ingressclass
k -n ingress-nginx get deploy ingress-nginx-controller
k -n ingress-nginx get endpoints ingress-nginx-controller

k create ns cks-103
k -n cks-103 create deploy secure-app --image=viktoruj/ping_pong:alpine
k -n cks-103 set env deploy/secure-app SERVER_NAME=secure-app SRV_PORT=80
k -n cks-103 expose deploy secure-app --name=secure-app --port=80 --target-port=80
k -n cks-103 wait --for=condition=Available deploy/secure-app --timeout=60s

mkdir -p /tmp/cks-103-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/cks-103-tls/tls.key \
  -out /tmp/cks-103-tls/tls.crt \
  -subj '/CN=secure.cks.local' \
  -addext 'subjectAltName=DNS:secure.cks.local'

k -n cks-103 create secret tls secure-ingress-tls \
  --cert=/tmp/cks-103-tls/tls.crt --key=/tmp/cks-103-tls/tls.key

cat <<'EOF' | k apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: cks-103
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.cks.local
    secretName: secure-ingress-tls
  rules:
  - host: secure.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port:
              number: 80
EOF

k get secret,ing -n cks-103
k get ing secure-ingress -n cks-103 -o yaml
```

Nous ne nous arrêtons pas à `k get ... -o yaml` - nous confirmons que le TLS Ingress fonctionne réellement
via un vrai controller. `secure.cks.local` se résout déjà en une vraie node IP
(le bootstrap a ajouté l'entrée dans `/etc/hosts`), et `ingress-nginx-controller` est un Service de type
`NodePort`, ouvert sur chaque nœud, curl est donc exécuté directement depuis cette machine, sans SSH
vers le cluster :

```bash
HTTPS_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -k "https://secure.cks.local:${HTTPS_NODEPORT}/"
# HTTPCODE 200, le corps contient "Server Name: secure-app"

HTTP_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
curl -v "http://secure.cks.local:${HTTP_NODEPORT}/"
# < HTTP/1.1 308 Permanent Redirect
# < Location: https://secure.cks.local
```

Ce redirect HTTP→HTTPS est une vraie question d'examen, et non une exigence artificielle du
lab (voir le mock-examen `tasks/cks/mock/04`, tâche 4).

## Tâche 5. TLS hardening de kube-apiserver et etcd

Ne cherchez pas le nom exact du flag dans la documentation - il est plus rapide de le demander au binaire lui-même depuis l'intérieur d'un
Pod déjà en cours d'exécution (`--help` existe pour n'importe quel composant du control plane) et de filtrer avec grep ce dont vous avez besoin :

```bash
k exec -n kube-system $(k get po -n kube-system -l component=kube-apiserver -o name) -- kube-apiserver --help | grep -i tls
# --tls-min-version string   Minimum TLS version supported. Possible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13
# --tls-cipher-suites strings   Comma-separated list of cipher suites for the server. Preferred values: TLS_AES_128_GCM_SHA256, ...

k exec -n kube-system $(k get po -n kube-system -l component=etcd -o name) -- etcd --help | grep -i cipher
# --cipher-suites ''   Comma-separated list of supported TLS cipher suites between client/server and peers
```

Dans les deux static Pod manifests, ajoutez les paramètres au `command`. Sur kube-apiserver, la tâche exige
LES DEUX flags, bien que la protection réelle avec `VersionTLS13` soit assurée précisément par `--tls-min-version`
(Go choisit lui-même les TLS 1.3 cipher suites, `--tls-cipher-suites` n'a pas d'effet sur elles - voir la question
2 de la section « Vérifiez-vous avant de commencer »). `--tls-cipher-suites` reste tout de même nécessaire explicitement - c'est
de la defense-in-depth : si la version minimale est ensuite abaissée à 1.2, les ensembles de chiffrements faibles ne
s'activeront pas d'eux-mêmes. Sur etcd (où TLS 1.2 est admis), `--cipher-suites` limite déjà réellement
l'ensemble dès maintenant, et pas pour l'avenir.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
cp /etc/kubernetes/manifests/etcd.yaml ~/5-etcd.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Ajoutez au command :
# - --tls-min-version=VersionTLS13
# - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
vim /etc/kubernetes/manifests/etcd.yaml
# Ajoutez au command :
# - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
exit
exit

k get po -n kube-system -l component=etcd
# STATUS doit passer à Running - sinon, patientez quelques secondes et recommencez
ssh control-plane "sudo grep -E -- '--tls-min-version=VersionTLS13|--tls-cipher-suites=' /etc/kubernetes/manifests/kube-apiserver.yaml"
ssh control-plane "sudo grep -- '--cipher-suites=' /etc/kubernetes/manifests/etcd.yaml"

mkdir -p /var/work/tests/artifacts/5
ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_3 -brief </dev/null' \
  > /var/work/tests/artifacts/5/tls13.txt 2>&1
# Protocol version: TLSv1.3 - la connexion a abouti

ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null' \
  >> /var/work/tests/artifacts/5/tls13.txt 2>&1
# ssl3_read_bytes:tlsv1 alert protocol version - le handshake doit échouer, c'est exactement ce qu'il faut

echo 'TLS 1.2 correctly rejected (non-zero exit / handshake failure)' \
  >> /var/work/tests/artifacts/5/tls13.txt
cat /var/work/tests/artifacts/5/tls13.txt
```

On attend une ligne de la forme `Protocol version: TLSv1.3` ou `Protocol : TLSv1.3`, et la terminaison de
`openssl s_client -tls1_2` avec une erreur de handshake/non-zero exit doit être consignée comme
`TLS 1.2 correctly rejected`.

## Tâche 6. Vérifier le SHA-256 de kubelet et kubectl

La référence n'est pas calculée à partir de fichiers locaux. Téléchargez les sommes officielles publiées de
Kubernetes `v1.36.0`, constituez les fichiers au format `sha256sum -c` et enregistrez les résultats.

```bash
mkdir -p /var/work/tests/artifacts/6 /tmp/cks-103-sha
cd /tmp/cks-103-sha
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl.sha256
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubelet.sha256

printf '%s  %s\n' "$(cat kubectl.sha256)" "$(command -v kubectl)" > kubectl.check
scp kubelet.sha256 control-plane:/tmp/kubelet.sha256
ssh control-plane 'printf "%s  %s\\n" "$(cat /tmp/kubelet.sha256)" "$(command -v kubelet)" > /tmp/kubelet.check && sha256sum -c /tmp/kubelet.check' \
  | tee /var/work/tests/artifacts/6/binaries.sha256.txt
sha256sum -c kubectl.check | tee -a /var/work/tests/artifacts/6/binaries.sha256.txt

cat /var/work/tests/artifacts/6/binaries.sha256.txt
```

Les deux lignes doivent se terminer par `: OK`. Si le chemin du binaire diffère de `/usr/bin`,
`command -v` produit tout de même une entrée correcte pour `sha256sum -c`.

## Tâche 7. Remediation cycle : un kube-bench FAIL concret jusqu'à PASS

Contrairement à la tâche 1 (instantané de tout le rapport), il faut ici relier un check concret
à sa correction. `kube-bench` prend en charge une exécution ciblée via `--check`, il n'est donc pas
nécessaire de relire manuellement tout le rapport :

```bash
mkdir -p /var/work/tests/artifacts/7

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/before.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/before.txt
# [FAIL] 1.1.1 Ensure that the API server pod specification file permissions ...
```

Vérifiez le droit d'accès réel sur le nœud et corrigez-le en `600` - c'est une modification
file-only, le kubelet ne recrée pas le static Pod à cause d'un changement de droits, seulement à cause d'un changement du
contenu du manifest :

```bash
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 644 /etc/kubernetes/manifests/kube-apiserver.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 600 /etc/kubernetes/manifests/kube-apiserver.yaml
```

La nouvelle exécution ciblée du même check doit afficher `PASS` :

```bash
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/after.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/after.txt
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions ...
```

Confirmez que kube-apiserver est resté sain : la modification des droits du fichier ne change pas son
contenu, le kubelet ne doit donc pas recréer le static Pod.

```bash
k get --raw='/readyz'
k -n kube-system get pods -l component=kube-apiserver
```

## Tâche 8. Remediation cycle : kube-controller-manager

La même technique que dans la tâche 7, pour un autre composant et un autre check ID (`1.1.3` -
kube-controller-manager pod specification file permissions) :

```bash
mkdir -p /var/work/tests/artifacts/8

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/before.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/before.txt
# [FAIL] 1.1.3 Ensure that the controller manager pod specification file permissions ...

ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 644 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-controller-manager.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 600 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/after.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/after.txt
# [PASS] 1.1.3 Ensure that the controller manager pod specification file permissions ...

k -n kube-system get pods -l component=kube-controller-manager
```

## Tâche 9. Remediation cycle : profiling sur kube-controller-manager et kube-scheduler

La même technique que dans les tâches 7-8 (trouver le `[FAIL]` concret via kube-bench, corriger,
confirmer `[PASS]`), pour les checks `1.3.2` (kube-controller-manager profiling) et `1.4.1`
(kube-scheduler profiling). Tous deux, comme toute la section `1.x`, relèvent du target `master` dans
`cis-1.12`, un `--targets` explicite n'est donc pas nécessaire - exactement comme dans les tâches 7-8. La tâche 3
a déjà désactivé profiling uniquement sur kube-apiserver ; kubeadm par défaut N'ajoute PAS du tout
`--profiling=false` aux manifests de kube-controller-manager/kube-scheduler.

```bash
mkdir -p /var/work/tests/artifacts/9

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-before.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-before.txt
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-before.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-before.txt
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false ...
```

Nous corrigeons les deux static Pod manifests - la même technique que dans la tâche 3, seulement pour deux autres
composants :

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-controller-manager.yaml ~/9-controller-manager.yaml
cp /etc/kubernetes/manifests/kube-scheduler.yaml ~/9-scheduler.yaml
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# Dans le tableau command, ajoutez une ligne avec la même indentation que les autres arguments :
# - --profiling=false
vim /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
exit
exit

k -n kube-system get pods -l component=kube-controller-manager
k -n kube-system get pods -l component=kube-scheduler
```

On vérifie non pas le texte du fichier, mais le Pod réellement en cours d'exécution (le kubelet recrée le static Pod non
instantanément après la modification du manifest), et la nouvelle exécution ciblée du même check doit
afficher `PASS` :

```bash
k -n kube-system get pod -l component=kube-controller-manager -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

k -n kube-system get pod -l component=kube-scheduler -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-after.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-after.txt
# [PASS] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-after.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-after.txt
# [PASS] 1.4.1 Ensure that the --profiling argument is set to false ...
```

`jq -e` doit afficher `true` pour les deux composants, et les deux commandes `k get pods`
ci-dessus - afficher `Running`.

## Tâche 10. Remediation cycle : protect-kernel-defaults sur le nœud worker

La même technique que dans les tâches 7-9, maintenant sur le nœud worker RÉEL (et non sur le control-plane), mais pour
un AUTRE profil. Le `kube-bench 0.16.0`/`cis-1.12` figé (utilisé dans toutes les autres
tâches de ce lab) ne contient pas du tout le check protect-kernel-defaults - CIS l'a supprimé/
renuméroté à partir de cette version du profil ; le `4.2.6` propre de `cis-1.12` est un AUTRE
check (`--make-iptables-util-chains`, `PASS` par défaut, sans rapport
avec protect-kernel-defaults). Le check nécessaire avec le même ID `4.2.6` existe dans le profil plus ancien
`cis-1.24` du même binaire - utilisez précisément celui-ci, avec un `--benchmark cis-1.24` explicite, uniquement
pour cette seule tâche.

Contrairement au control-plane, sur le nœud worker `kube-bench` N'est PAS préinstallé - installez-le
ici vous-même (une vraie installation, pas une copie depuis le control-plane ou le worker PC) : téléchargez la même
release figée depuis GitHub, décompressez `binary` et `cfg` dans le default `--config-dir`
(`/etc/kube-bench/cfg`), afin de ne pas indiquer ce flag explicitement dans chaque commande :

```bash
WORKER_NODE=$(k get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')

cat <<'EOF' > /tmp/install-kube-bench.sh
KUBE_BENCH_VERSION=0.16.0
arch=$(dpkg --print-architecture)
workdir=$(mktemp -d)
asset="kube-bench_${KUBE_BENCH_VERSION}_linux_${arch}.tar.gz"
base="https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}"
curl -fsSL -o "$workdir/$asset" "$base/$asset"
# La même technique que dans la tâche 6 : on compare avec une somme publiée indépendamment, et non avec une
# somme calculée à partir du fichier lui-même.
curl -fsSL -o "$workdir/checksums.txt" "$base/kube-bench_${KUBE_BENCH_VERSION}_checksums.txt"
(cd "$workdir" && grep -E "[[:space:]]${asset}\$" checksums.txt | sha256sum --check --strict -)
tar -xzf "$workdir/$asset" -C "$workdir"
sudo install -d -m 0755 /opt/kube-bench /etc/kube-bench
sudo cp -a "$workdir"/cfg /etc/kube-bench/cfg
sudo install -m 0755 "$workdir/kube-bench" /opt/kube-bench/kube-bench
sudo ln -sf /opt/kube-bench/kube-bench /usr/local/bin/kube-bench
rm -rf "$workdir"
EOF
scp /tmp/install-kube-bench.sh "$WORKER_NODE":/tmp/install-kube-bench.sh
ssh "$WORKER_NODE" 'bash /tmp/install-kube-bench.sh'
ssh "$WORKER_NODE" 'kube-bench version'

mkdir -p /var/work/tests/artifacts/10
ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/before.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/before.txt
# [FAIL] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```

`protectKernelDefaults` ne fait pas du tout partie du `KubeletConfiguration` généré par kubeadm -
le champ est physiquement absent (équivalent au default non sûr `false`), donc ajoutez-le simplement,
et ne cherchez pas de ligne existante à remplacer :

```bash
ssh "$WORKER_NODE" 'echo "protectKernelDefaults: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh "$WORKER_NODE" 'sudo systemctl restart kubelet'
k get node "$WORKER_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

Confirmez via `/configz` (la configuration réellement appliquée, et non le texte du fichier) et
par une nouvelle exécution ciblée du check :

```bash
k get --raw="/api/v1/nodes/$WORKER_NODE/proxy/configz" \
  | jq -e '.kubeletconfig.protectKernelDefaults == true'

ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/after.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/after.txt
# [PASS] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```
