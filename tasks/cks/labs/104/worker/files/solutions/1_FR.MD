[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 104 - solution de référence : RBAC, ServiceAccount token et anonymous API

> Exécutez les commandes depuis la machine de travail, sauf indication contraire dans l'étape. Le namespace
> `security-104` existe déjà.
>
> À l'examen, `k` (`alias k=kubectl`) et la bash-completion pour lui sont déjà configurés sur le SSH-host -
> ne perdez pas de temps à les configurer, utilisez simplement `k` (voir le chapitre 33.6).

## 1. Accès minimal de `auditor` uniquement aux Pod

À l'examen, écrire à la main le YAML complet d'un objet RBAC typique est une perte de temps :
`kubectl create` génère ServiceAccount/Role/RoleBinding en une commande chacun :

```bash
k create sa auditor -n security-104
k create role pod-observer -n security-104 --resource=pods --verb=get,list,watch
k create rolebinding auditor-pod-observer -n security-104 \
  --role=pod-observer --serviceaccount=security-104:auditor

k auth can-i list pods -n security-104 \
  --as=system:serviceaccount:security-104:auditor
k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:auditor # doit être no
```

## 2. Projected token de ServiceAccount

Le TokenRequest volume délivre un token de courte durée ; l'automontage ordinaire est désactivé.
Nous ne figeons pas `audience: kubernetes.default.svc` : pour kubeadm, ce n'est pas une valeur garantie
acceptée par l'API server. Si `audience` est omise, le kubelet utilise l'identifier de
l'API server par défaut. Une audience distincte ne peut être indiquée qu'après vérification de
`--api-audiences` (ou du default de `--service-account-issuer`) sur le control-plane.
`expirationSeconds` doit être dans la plage `600`-`3600` incluse - la Kubernetes API
rejette comme invalid toute valeur inférieure à `600` secondes pour une `serviceAccountToken`
projected source, indépendamment de ce qui est écrit dans le manifest.

La syntaxe exacte de `projected.sources[].serviceAccountToken` n'a pas à être rappelée de mémoire à l'examen :
sur `kubernetes.io/docs`, elle se trouve dans la section Concepts → Storage →
[Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), sous le
titre **« serviceAccountToken projected volumes »** (il y a un exemple tout prêt de Pod avec ce
volume - prenez-en la structure, ne l'écrivez pas de zéro). `kubectl run` ne sait pas ajouter
un tel volume via des flags - nous générons le squelette du Pod via `--dry-run=client -o yaml` et
nous ajoutons dans `vim` uniquement les champs nécessaires, copiés de l'exemple de la documentation :

```bash
k create sa api-client -n security-104
k run token-client -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > token-client.yaml
vim token-client.yaml
```

```yaml
# Ajoutez au spec du Pod (containers/image/command sont déjà générés par kubectl run) :
spec:
  serviceAccountName: api-client              # ajouter
  automountServiceAccountToken: false         # ajouter
  containers:
  - name: token-client
    volumeMounts:                             # ajouter
    - name: api-token                         # ajouter
      mountPath: /var/run/secrets/tokens       # ajouter
      readOnly: true                          # ajouter
    ...
  volumes:                                    # ajouter
  - name: api-token                           # ajouter
    projected:                                # ajouter
      sources:                                # ajouter
      - serviceAccountToken:                  # ajouter
          path: api-token                     # ajouter
          expirationSeconds: 3600             # ajouter
```

```bash
k apply -f token-client.yaml
k wait -n security-104 --for=condition=Ready po/token-client --timeout=120s
k exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token
# le fichier existe - si le manifest coïncide avec l'exemple de la documentation, le kubelet l'a émis

k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:api-client
# no
```

On vérifie non seulement la présence du fichier, mais aussi que le projected token monté
s'authentifie réellement comme le ServiceAccount attendu, en l'envoyant à `TokenReview` :

```bash
TOKEN=$(k exec -n security-104 token-client -- cat /var/run/secrets/tokens/api-token)

k create -o jsonpath='{.status.authenticated}{" "}{.status.user.username}{"\n"}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: $TOKEN
EOF
# true system:serviceaccount:security-104:api-client
```

Pour le lab, cette vérification est obligatoire : la présence du fichier ne démontre pas à elle seule
que le projected token est valide et s'authentifie comme le ServiceAccount attendu. `TokenReview`
doit renvoyer `authenticated: true` et le username
`system:serviceaccount:security-104:api-client`.

À l'examen, il n'est pas nécessaire d'exécuter `TokenReview` séparément, si l'énoncé de la tâche ne l'exige pas :
il suffit d'y créer rapidement un projected token volume correct et de vérifier le résultat de la
façon requise dans la tâche donnée. Ici, `TokenReview` est une vérification pédagogique,
qui correspond en même temps au critère d'acceptation du lab.

## 3. Pod sans token de l'API

Nous désactivons l'automontage à la fois sur le ServiceAccount et sur le Pod : cela protège contre des
modifications ultérieures du template ou du ServiceAccount.

`kubectl create serviceaccount` n'a pas de flag pour `automountServiceAccountToken` - nous créons
et patchons aussitôt :

```bash
k create sa no-token-sa -n security-104
k patch sa no-token-sa -n security-104 -p '{"automountServiceAccountToken":false}'
k run no-token -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > no-token.yaml
vim no-token.yaml
```

```yaml
# Ajoutez au spec du Pod :
spec:
  serviceAccountName: no-token-sa       # ajouter
  automountServiceAccountToken: false   # ajouter
  containers:
  - name: no-token
    ...
```

```bash
k apply -f no-token.yaml
k wait -n security-104 --for=condition=Ready po/no-token --timeout=60s
k get po no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'

# Nous confirmons au niveau du runtime, et pas seulement au niveau de la spécification YAML : dans le
# conteneur, il n'y a effectivement pas de fichier de token.
k exec -n security-104 no-token -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - le fichier est absent, l'exec lui-même s'est exécuté avec succès
```

Ne montez pas non plus séparément un legacy `Secret` avec `type: kubernetes.io/service-account-token` -
même avec l'automount désactivé, un tel Secret peut être monté à la main via
`volumes[].secret`, et le Pod est alors formellement « sans token » d'après le champ automount, mais de fait
possède tout de même un API-token valide dans le conteneur.

## 4. Suppression des permissions wildcard

Nous supprimons à la fois le binding (le sujet ne reçoit plus d'accès) et le ClusterRole lui-même (le modèle
dangereux ne reste pas disponible pour une réutilisation) :

```bash
k delete clusterrolebinding legacy-operator-admin
k delete clusterrole legacy-operator-admin
k auth can-i get secrets -n security-104 \
  --as=system:serviceaccount:security-104:legacy-operator # doit être no
```

## 5. Désactivation d'anonymous-auth

Un simple `--anonymous-auth=false` ne convient pas ici : kubeadm `release-1.36` génère le
static Pod de kube-apiserver avec des HTTPS liveness/readiness/startup probes sur `/livez` et
`/readyz`, et les HTTP probes du kubelet ne transmettent pas de client credentials - avec
l'anonymous access entièrement désactivé, ces requêtes recevront `401`, et le kubelet commencera à considérer kube-apiserver
comme malsain (ce qui casse à son tour aussi la tâche 9, qui dépend d'un API
server fonctionnant de façon stable). À la place, nous utilisons un `AuthenticationConfiguration` avec `anonymous.conditions`,
qui limitent l'anonymous access à seulement trois chemins health. À l'examen, ne préfixez pas
chaque commande de `sudo` - devenez root une seule fois (`sudo -i`), c'est plus rapide :

```bash
ssh control-plane
sudo -i
cat > /etc/kubernetes/authentication-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

Nous modifions le static manifest : nous retirons `--anonymous-auth=true` complètement (on ne peut pas le laisser
à côté de `--authentication-config` - kube-apiserver refusera de démarrer si les deux sont indiqués),
nous ajoutons `--authentication-config`, ainsi qu'un `hostPath` volume/volumeMount pour le nouveau
fichier de configuration - kube-apiserver lit `authentication-config.yaml` depuis le système de
fichiers du nœud, donc le fichier doit être visible à l'intérieur du container via un volumeMount, et pas
seulement se trouver sur l'hôte :

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Dans le tableau command :
# - supprimez la ligne "- --anonymous-auth=true"
# - ajoutez une ligne avec la même indentation que les autres arguments :
#   - --authentication-config=/etc/kubernetes/authentication-config.yaml
# Dans les volumeMounts du conteneur (la même indentation que les éléments voisins) :
#   - mountPath: /etc/kubernetes/authentication-config.yaml
#     name: authentication-config
#     readOnly: true
# Dans les volumes du Pod (la même indentation que les éléments voisins) :
#   - hostPath:
#       path: /etc/kubernetes/authentication-config.yaml
#       type: File
#     name: authentication-config
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` force la reconstruction immédiate du static Pod - à l'examen, c'est plus
rapide que d'attendre que le kubelet remarque lui-même la modification du fichier (en général quelques secondes, mais ce n'est pas
garanti instantané) :

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS doit passer à Running - sinon, patientez quelques secondes et recommencez
```

Vérifiez les trois comportements : `/version` rejette les requêtes anonymes, et `/livez`/`/readyz`
les acceptent :

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401 - anonymous access fermé
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/livez"   # 200 - la health probe fonctionne
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/readyz"  # 200 - la health probe fonctionne
```

Une requête authentifiée vers `/readyz` (via le kubectl context déjà configuré)
continue de fonctionner exactement de la même façon - `AuthenticationConfiguration.anonymous.conditions`
ne fait qu'ÉTENDRE l'accès des requêtes anonymes à des chemins précis, mais ne restreint pas l'accès
des clients déjà authentifiés :

```bash
k get --raw=/readyz # ok
```

Une authentication sans authorization restrictive n'a aucun sens - vérifiez que
`--authorization-mode` sur le static Pod est toujours `Node,RBAC` et ne contient pas `AlwaysAllow`
(kubeadm le définit par défaut, mais il vaut mieux s'assurer que rien n'a changé le flag) :

```bash
k get po -n kube-system -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep authorization-mode
# --authorization-mode=Node,RBAC
```

Séparément, nous auditons les ClusterRoleBinding dont les subjects pointent vers l'utilisateur anonyme
ou le groupe - dans le cluster, on a laissé volontairement un tel binding lab-owned :

```bash
k get clusterrolebinding -o json | jq -r \
  '.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name == "system:unauthenticated")] | length > 0) | .metadata.name'
# system:public-info-viewer
# lab104-unintended-anonymous-access
```

`system:public-info-viewer` est un binding standard de kubeadm : il vise lui aussi
`system:unauthenticated`, mais son ClusterRole autorise un `GET` read-only uniquement sur les
non-resource URL `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`, et non sur les
ressources ordinaires de Kubernetes - c'est le default Kubernetes RBAC, une partie nécessaire du bootstrap, n'y touchez pas.
Ce n'est pas la même chose que `anonymous.conditions` de cette même tâche : cette liste
détermine les seuls chemins sur lesquels la requête reçoit une anonymous identity à l'étape
d'authentication (là uniquement `/livez`/`/readyz`/`/healthz`) - `/version` renvoie `401` anonymement
précisément parce qu'aucune anonymous identity n'y est attribuée, et non parce que
`system:public-info-viewer` manque de droits à cet endroit. `lab104-unintended-anonymous-access` est un
constat (finding) lab-owned délibéré : son ClusterRole `lab104-anonymous-debug-access` donne un
RBAC `get`/`list` complet sur `pods`/`secrets`/`configmaps` à l'échelle du cluster, c'est-à-dire que N'IMPORTE QUELLE
requête anonyme peut les lire. Nous supprimons les deux objets, comme dans les tâches 4/7 :

```bash
k delete clusterrolebinding lab104-unintended-anonymous-access
k delete clusterrole lab104-anonymous-debug-access
```

Nous confirmons la révocation par un contrôle négatif au nom précisément de l'identity non authentifiée
(`system:anonymous` + le groupe `system:unauthenticated`, et rien d'autre) via
`SubjectAccessReview` - il est créé par le contexte admin, il n'est donc pas nécessaire d'étendre
artificiellement la liste des groupes :

```bash
for R in pods secrets configmaps; do
  for NS in $(k get ns -o jsonpath='{.items[*].metadata.name}'); do
    ALLOWED=$(k create -o jsonpath='{.status.allowed}' -f - <<EOF
apiVersion: authorization.k8s.io/v1
kind: SubjectAccessReview
spec:
  user: system:anonymous
  groups: ["system:unauthenticated"]
  resourceAttributes:
    namespace: $NS
    resource: $R
    verb: get
EOF
    )
    printf '%-12s %-24s %s\n' "$R" "$NS" "$ALLOWED"
  done
done
# pour chaque ligne, on attend false
```

N'ajoutez pas `--as-group=system:authenticated` à `can-i --as=system:anonymous` : une vraie
requête non authentifiée n'appartient pas à ce groupe, et la vérification cesserait de refléter la
vraie anonymous identity. Nous vérifions chaque namespace séparément, car
un RoleBinding n'agit que dans son namespace : l'absence d'un binding cluster-wide ne
démontre pas l'absence d'un binding local, et le critère d'acceptation exige l'absence d'accès dans tous les namespaces.

À la fin, exécutez `check_result`.

## 6. Fuite de Secret via env dans `/proc/1/environ` : passage à un volume

`app-vulnerable` reçoit `db-creds` via `envFrom`, la valeur se retrouve donc dans
l'environment du processus PID 1 du conteneur. Quiconque a le droit de faire `kubectl exec` dans ce
Pod peut lire le secret directement depuis `/proc`, sans passer par la Kubernetes API et sans RBAC
sur `get secrets` :

```bash
mkdir -p /var/work/tests/artifacts/6
k exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | grep DB_PASSWORD | tee /var/work/tests/artifacts/6/env-leak-before.txt
```

Nous enregistrons précisément la ligne `DB_PASSWORD=<valeur réelle>` de l'environnement du processus, et pas
simplement le mot `DB_PASSWORD` sans valeur - le checker la comparera lui-même avec la valeur réelle
du Secret `db-creds`, il n'est pas nécessaire de calculer et de comparer la valeur soi-même.

Nous recréons le Pod avec le même nom : nous retirons `envFrom`, nous montons le même Secret comme volume
`db-creds-vol` dans `/etc/secrets`, read-only, avec `defaultMode: 0400` (`256` en décimal, comme le
montre `kubectl get pod -o json`). `0400` est read-only uniquement pour le propriétaire du fichier
à l'intérieur du conteneur ; le processus de l'application doit tout de même s'exécuter sous cet UID, sinon
il ne pourra pas lire le fichier.

La plupart des champs du Pod (y compris `volumes`) sont immuables, donc le Pod doit être supprimé et recréé avec le même nom. De nouveau, il est moins coûteux de
générer le squelette via `--dry-run` et d'ajouter le volume dans `vim` que d'écrire tout le YAML :

```bash
k run app-vulnerable -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > app-vulnerable-fixed.yaml
vim app-vulnerable-fixed.yaml
```

```yaml
# Ajoutez au spec du Pod :
spec:
  automountServiceAccountToken: false     # ajouter
  containers:
  - name: app-vulnerable
    volumeMounts:                         # ajouter
    - name: db-creds-vol                  # ajouter
      mountPath: /etc/secrets             # ajouter
      readOnly: true                      # ajouter
    ...
  volumes:                                # ajouter
  - name: db-creds-vol                    # ajouter
    secret:                               # ajouter
      secretName: db-creds                # ajouter
      defaultMode: 0400                   # ajouter
```

```bash
k delete pod app-vulnerable -n security-104
k apply -f app-vulnerable-fixed.yaml
k wait -n security-104 --for=condition=Ready po/app-vulnerable --timeout=120s
```

Nous confirmons trois propriétés finales, et pas seulement « le secret n'est pas dans l'environment » : les droits
du fichier sont exactement `400` (et ne contiennent pas simplement quelque part la sous-chaîne `400`) et, ce qui est plus important, l'application
peut encore RÉELLEMENT lire la valeur du secret - sinon le hardening pourrait casser sans qu'on s'en aperçoive
la fonctionnalité même de l'application :

```bash
k exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# rien n'est trouvé - c'est attendu

k exec -n security-104 app-vulnerable -- stat -L -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400 - précisément cette valeur, et non un texte arbitraire contenant quelque part "400". Le flag -L
# est obligatoire : le secret volume est monté via une chaîne de symlinks ("..data"), et sans -L
# stat affichera le mode du symlink lui-même (toujours 777 sous Linux), et non du fichier réel.

# Positive control : le processus de l'application doit pouvoir réellement lire la valeur du secret.
k exec -n security-104 app-vulnerable -- cat /etc/secrets/DB_PASSWORD
# doit coïncider avec la valeur qui était dans env-leak-before.txt avant la correction
```

`defaultMode: 0400` protège contre la lecture par d'autres UID dans ce même Pod (par exemple, un
sidecar-container voisin sans l'UID voulu), mais ne remplace pas l'encryption at rest d'etcd et n'empêche pas
un processus exécuté sous l'UID attendu de lire le fichier lui-même - le mount autorise précisément cela.
Assurez-vous aussi que `db-creds` n'est pas monté par une SECONDE voie en même temps
(par exemple, également via un `projected` volume) - il doit rester exactement un volume
qui monte ce Secret.

À la fin, exécutez `check_result`.

## 7. Audit et révocation des chemins cachés de RBAC privilege escalation

`build-agent-hidden-privesc` ne contient pas le wildcard `*`, mais `impersonate`/`bind`/`escalate`/
CSR-approval sont une catégorie distincte de verbs dangereux : ils n'étendent pas la liste des ressources
visibles, mais donnent la possibilité d'**agir au nom d'autrui** ou de **se délivrer
des droits supplémentaires**. Dans cette version du fixture, le ClusterRole contient aussi les
`create`/`update` de base sur `clusterroles`/`clusterrolebindings` - sans eux, `bind`/`escalate`
seraient des escalation primitives incomplètes (RBAC exige SOIT d'avoir déjà les droits du rôle, SOIT
d'avoir explicitement `escalate`/`bind` DANS LE CONTEXTE d'une tentative réelle de créer/mettre à jour un Role/Binding).
Nous trouvons tous les ClusterRoleBinding dont les ClusterRole autorisent l'un des verbs dangereux. Nous ne partons pas
des ClusterRole (il y en a des dizaines dans le cluster, y compris les `system:*` standard), mais des
ClusterRoleBinding - `kubectl get clusterrolebinding` affiche déjà par défaut la colonne
`ROLE` (format `ClusterRole/<nom>`), et `-o wide` ajoute en plus `USERS`/`GROUPS`/
`SERVICEACCOUNTS` - ni custom-columns ni YAML ne sont nécessaires :

```bash
mkdir -p /var/work/tests/artifacts/7
k get clusterrolebinding -o wide | grep -v system:
# build-agent-hidden-privesc   ClusterRole/build-agent-hidden-privesc   ...   security-104/build-agent
```

Pour chaque candidat, nous regardons son ClusterRole de façon lisible par un humain, sans `jq`/`grep` sur le YAML -
`kubectl describe` imprime lui-même les verbs sous forme de tableau, où l'on voit tout de suite `impersonate`/`bind`/
`escalate` et la règle distincte sur `certificatesigningrequests/approval` :

```bash
k describe clusterrole build-agent-hidden-privesc
# Les Verbs dans le tableau PolicyRule afficheront impersonate / bind / escalate / update
# (sur certificatesigningrequests/approval) - visuellement, on voit que le rôle est dangereux
```

Nous enregistrons le nom du ClusterRoleBinding (et non du ClusterRole - ils peuvent ne pas coïncider, dans ce lab
ils ont coïncidé par hasard) dans l'artifact :

```bash
echo build-agent-hidden-privesc > /var/work/tests/artifacts/7/dangerous-bindings-before.txt
cat /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` doit figurer dans le fichier final (comme nom du ClusterRoleBinding,
et non du ClusterRole). Nous supprimons précisément ce ClusterRoleBinding (et le ClusterRole, afin que le modèle ne
reste pas disponible pour une réutilisation), sans toucher aux bindings `system:*`, qui donnent aux
composants core de Kubernetes l'accès nécessaire d'`impersonate`/CSR :

```bash
k delete clusterrolebinding build-agent-hidden-privesc
k delete clusterrole build-agent-hidden-privesc
```

Nous confirmons la révocation de TOUS les droits dangereux déclarés, et pas seulement d'une partie d'entre eux. Deux nuances :
le fixture donne `impersonate` à la fois sur trois types de ressource (`users`/`groups`/`serviceaccounts`) -
vérifier seulement `users` ne démontre pas la révocation des deux autres ; et `TYPE/NAME` dans `kubectl auth
can-i` est un resourceName, et non un subresource (`kubectl auth can-i --help` montre directement
l'exemple « jobs.batch/bar » - la vérification d'un objet littéralement nommé `bar`), c'est pourquoi pour
`certificatesigningrequests/approval`, il faut un flag distinct `--subresource=approval`, et non
une barre oblique :

```bash
k auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate groups --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate serviceaccounts -n security-104 --as=system:serviceaccount:security-104:build-agent
k auth can-i bind clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i update certificatesigningrequests --subresource=approval --as=system:serviceaccount:security-104:build-agent
k auth can-i approve signers/kubernetes.io/kube-apiserver-client --as=system:serviceaccount:security-104:build-agent
# no / no / no / no / no / no / no
```

À la fin, exécutez `check_result`.

## 8. Baseline au niveau du namespace : SA `default` sans automount

La tâche 3 désactivait l'automount de façon ponctuelle, pour un Pod précis et son propre SA. Ici,
il faut un baseline systémique : nous modifions le SA `default` du namespace **avant** d'y créer le moindre
Pod, afin qu'aucun nouveau workload ne reçoive le token par défaut, même si le développeur
oublie le champ explicite dans le manifest.

Le ServiceAccount `default` est créé par un controller distinct de façon asynchrone après l'apparition du
Namespace - `kubectl wait` sait attendre précisément l'apparition de l'objet (`--for=create`), et pas
seulement sa condition, donc ni retry manuel ni boucle maison ne sont nécessaires :

```bash
k create namespace security-104-baseline
k wait -n security-104-baseline --for=create sa/default --timeout=30s

k -n security-104-baseline patch sa default \
  -p '{"automountServiceAccountToken":false}'
k -n security-104-baseline get sa default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

Nous créons un Pod qui **ne** définit ni `serviceAccountName`, ni `automountServiceAccountToken` -
c'est le cas le plus fréquent dans la réalité, quand le développeur ne pense simplement pas au SA. Le champ
`automountServiceAccountToken` doit être ABSENT du spec du Pod - indiquer explicitement `false`
ne démontrerait qu'une configuration ponctuelle du Pod lui-même (comme dans la tâche 3), et non que
le namespace-level baseline fonctionne réellement.

Ici, même `--dry-run` n'est pas nécessaire - puisqu'aucun champ sur SA/automount n'est ajouté au Pod,
`kubectl run` sans flags crée exactement ce qu'il faut, directement :

```bash
k run implicit-default-sa -n security-104-baseline --image=busybox:1.36 --command -- sh -c "sleep 3600"
k wait -n security-104-baseline --for=condition=Ready po/implicit-default-sa --timeout=60s
k get po implicit-default-sa -n security-104-baseline -o jsonpath='{.spec.serviceAccountName}{"\n"}'
# default

k get po implicit-default-sa -n security-104-baseline \
  -o jsonpath='{.spec.automountServiceAccountToken}{"\n"}'
# sortie vide - le champ est absent du spec, et n'est pas défini à false

k exec -n security-104-baseline implicit-default-sa -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - le fichier est absent, et l'exec lui-même s'est exécuté avec succès (contrairement à un simple
# "cat" sur un fichier inexistant, dont l'exit code est aussi non nul, mais pour une autre
# raison ; test ! -e fait précisément la vérification nécessaire, et son propre succès
# doit être exigé séparément, et non simplement « toute erreur = le fichier est absent »)
```

La valeur du SA n'agit que si le Pod ne la redéfinit pas lui-même. Si le même namespace
a besoin d'un Pod avec un accès à l'API, ajoutez `automountServiceAccountToken: true` explicitement dans le
manifest en question après avoir vérifié que l'accès est réellement nécessaire - ne remettez pas le baseline
du SA `default` à `true` pour tout le namespace. Ne montez pas non plus à la main un ancien
(legacy) `Secret` avec `type: kubernetes.io/service-account-token` via `volumes[].secret` -
cela donnerait au Pod un API-token valide indépendamment des réglages d'automount.

À la fin, exécutez `check_result`.

## 9. Tâche d'intégration : détection d'un changement RBAC dangereux → audit log → containment

Les tâches 1-8 fermaient des chemins précis d'élévation de privilèges, disponibles pour `build-agent` lui-même
(wildcard, impersonate/bind/escalate, automount). Ici, il faut une autre couche de protection -
la détection d'un **RBAC grant dangereux délivré par un administrateur** (par erreur, à cause d'une
automatisation compromise, ou de manière malveillante), et pas seulement un instantané actuel de RBAC.
Nous nous connectons au control-plane et préparons un audit backend minimal :

```bash
ssh control-plane
sudo -i
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings"]
- level: Metadata
EOF
```

La règle RBAC est la première - la règle plus spécifique doit précéder le catch-all
général, sinon `Metadata` interceptera l'événement plus tôt. `omitStages: [RequestReceived]`
au niveau de toute la policy supprime l'entrée superflue précédant le traitement de la requête - elle n'a pas
de `requestObject`/`responseStatus`, et le checker écarte de toute façon de telles entrées (`stage ==
"ResponseComplete"`), et avec la règle catch-all `Metadata` sur TOUTES les autres requêtes du cluster,
cette étape doublerait le volume d'audit.log sans bénéfice.

Nous modifions le static manifest : nous ajoutons `--audit-policy-file`/`--audit-log-path` et des hostPath
volume/volumeMount pour les répertoires de la policy et des logs - avec la même technique que dans la tâche 5 pour
`authentication-config.yaml` :

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/9-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Dans le tableau command, ajoutez des lignes avec la même indentation que les autres arguments :
#   - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
#   - --audit-log-path=/var/log/kubernetes/audit/audit.log
# Dans les volumeMounts du conteneur (la même indentation que les éléments voisins) :
#   - mountPath: /etc/kubernetes/audit
#     name: audit-policy
#     readOnly: true
#   - mountPath: /var/log/kubernetes/audit
#     name: audit-log
# Dans les volumes du Pod (la même indentation que les éléments voisins) :
#   - hostPath:
#       path: /etc/kubernetes/audit
#       type: Directory
#     name: audit-policy
#   - hostPath:
#       path: /var/log/kubernetes/audit
#       type: DirectoryOrCreate
#     name: audit-log
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` force la reconstruction immédiate du static Pod - comme dans la
tâche 5, c'est plus rapide que d'attendre que le kubelet remarque de lui-même la modification du fichier :

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS doit passer à Running - sinon, patientez quelques secondes et recommencez
```

Nous revenons sur la machine de travail (au nom de l'administrateur `cluster1-admin`) et créons
le binding dangereux - ce n'est **pas** une tentative d'escalade de la part de `build-agent` (il n'a plus
de chemins réels pour cela après la tâche 7), mais une action d'administrateur modélisée,
que l'audit log doit capturer comme evidence reproductible de qui précisément l'a
effectuée et à qui précisément les droits ont été délivrés :

```bash
k create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

D'abord, nous nous assurons simplement visuellement que la règle d'audit fonctionne réellement et que l'événement est arrivé dans le
log - à l'examen, c'est généralement précisément cette vérification qu'il faut, et non un artifact tout fait :

```bash
ssh control-plane
sudo cat /var/log/kubernetes/audit/audit.log | jq . | grep -A 30 incident-simulated-escalation
exit
```

`jq .` imprime chaque entrée du log de façon lisible (un champ par ligne), `grep -A 30`
montre la ligne trouvée avec le nom et 30 lignes APRÈS elle - c'est suffisant pour voir
`stage`, `user.username` (l'initiateur réel), `requestObject.roleRef`,
`requestObject.subjects` visuellement, sans syntaxe jq particulière.

Cela suffit pour un examen réel, mais ce lab exige en plus un fichier artifact avec
l'événement - non pas parce qu'il ne suffirait pas au checker de savoir que la règle fonctionne (lui-même, indépendamment,
lit `audit.log` sur le control-plane via SSH), mais pour vérifier une compétence distincte :
extraire et enregistrer précisément une entrée RÉELLE comme forensic evidence, et non la raconter
avec ses propres mots (le checker compare l'`auditID` de votre fichier avec l'`auditID` de l'entrée réelle dans le log).
`/var/work/tests/artifacts/9/` est un chemin sur la machine de TRAVAIL, et non sur le control-plane, c'est pourquoi
nous enregistrons depuis la machine de travail via `ssh control-plane "..."`, avec le même enchaînement de grep sur des sous-chaînes ordinaires
(nom de l'événement + `ResponseComplete`, pour ne pas tomber sur l'entrée intermédiaire
`ResponseStarted` de la même request) :

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | grep incident-simulated-escalation | grep ResponseComplete \
  | tail -n1 > /var/work/tests/artifacts/9/audit-escalation-event.json
```

Nous enregistrons l'événement **en entier**, tel qu'il se trouve réellement dans l'audit log (y compris l'`auditID`) - nous ne
le réécrivons pas et n'assemblons pas le JSON à la main, sinon l'artifact ne coïncidera pas avec l'entrée réelle
dans le log lors de la vérification.

Containment : nous supprimons le binding et confirmons que l'accès est réellement révoqué, et pas que
l'objet est simplement devenu illisible. `can-i` sans `-n`/`-A` ne vérifie que le namespace courant du
contexte du kubeconfig, et non tout le cluster - pour un RoleBinding namespaced dans `security-104`
(contrairement au ClusterRoleBinding cluster-wide déjà supprimé), cela change le résultat,
c'est pourquoi nous indiquons le namespace explicitement :

```bash
k delete clusterrolebinding incident-simulated-escalation
k auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent \
  | tee /var/work/tests/artifacts/9/containment-result.txt
# no
```

La différence avec la tâche 7 : là-bas, nous trouvions et révoquions un chemin caché **déjà existant** par
analyse statique des objets RBAC, appartenant au workload lui-même (`build-agent`). Ici, la
source of truth est un **événement dans le temps** (l'audit log), qui démontre qui précisément
(le champ `user.username` est l'initiateur réel de la requête, dans ce cas l'administrateur, et non
`build-agent`) a délivré les droits dangereux et à qui précisément - c'est ce qu'il faut pour un
incident réel, quand l'objet lui-même a pu être déjà supprimé après usage, et `build-agent` dans
l'événement ne figure que comme destinataire des droits, et non comme auteur de la requête.

À la fin, exécutez `check_result`.

## 10. Décodage, création et montage d'un Secret

`legacy-config` existe déjà. Nous lisons les deux valeurs via l'API, et ne devinons pas :

```bash
mkdir -p /var/work/tests/artifacts/10
SERVICE_USER=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_USER}' | base64 -d)
SERVICE_TOKEN=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_TOKEN}' | base64 -d)
printf 'SERVICE_USER=%s\nSERVICE_TOKEN=%s\n' "$SERVICE_USER" "$SERVICE_TOKEN" \
  | tee /var/work/tests/artifacts/10/decoded-values.txt
```

Nous créons un nouveau generic Secret avec les mêmes noms de clés et les mêmes valeurs -
`--from-literal` encode lui-même la valeur en base64, inutile de le faire à la main :

```bash
k create secret generic rehydrated-config -n security-104 \
  --from-literal=SERVICE_USER="$SERVICE_USER" \
  --from-literal=SERVICE_TOKEN="$SERVICE_TOKEN"
```

Nous le montons comme read-only volume dans un Pod - de nouveau dry-run + modification ponctuelle dans `vim` :

```bash
k run secret-workflow -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > secret-workflow.yaml
vim secret-workflow.yaml
```

```yaml
# Ajoutez au spec du Pod :
spec:
  automountServiceAccountToken: false      # ajouter
  containers:
  - name: secret-workflow
    volumeMounts:                          # ajouter
    - name: rehydrated-config-vol          # ajouter
      mountPath: /etc/rehydrated           # ajouter
      readOnly: true                       # ajouter
    ...
  volumes:                                 # ajouter
  - name: rehydrated-config-vol            # ajouter
    secret:                                # ajouter
      secretName: rehydrated-config        # ajouter
```

```bash
k apply -f secret-workflow.yaml
k wait -n security-104 --for=condition=Ready po/secret-workflow --timeout=60s
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_USER
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_TOKEN
# doivent coïncider avec $SERVICE_USER / $SERVICE_TOKEN ci-dessus
```

À la fin, exécutez `check_result`.

## 11. Réparation du Role existant et liaison à un SA d'un autre namespace

Le Role existant `pod-role` dans `rbac-a` autorise `get`, `list`, `delete` - nous retirons le
`delete` superflu, nous ajoutons le `watch` nécessaire :

```bash
k patch role pod-role -n rbac-a --type=json -p \
  '[{"op":"replace","path":"/rules/0/verbs","value":["get","list","watch"]}]'
k auth can-i delete pods -n rbac-a --as=system:serviceaccount:rbac-a:dev # no
k auth can-i watch pods -n rbac-a --as=system:serviceaccount:rbac-a:dev  # yes
```

`shared-config` existe déjà dans `rbac-b`. Nous créons un NOUVEAU Role+RoleBinding précisément dans
`rbac-b` - RoleBinding prend en charge un subject d'un autre namespace, mais les droits eux-mêmes
n'agissent que dans le namespace du RoleBinding lui-même :

```bash
k create role configmap-reader -n rbac-b --resource=configmaps --verb=get,list
k create rolebinding configmap-reader-binding -n rbac-b \
  --role=configmap-reader --serviceaccount=rbac-a:dev

k auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev    # yes
k auth can-i delete configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev # no
k auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev       # no
```

Nous créons un Pod dans `rbac-a` qui utilise réellement `dev` :

```bash
k run rbac-a-workload -n rbac-a --image=busybox:1.36 \
  --overrides='{"spec":{"serviceAccountName":"dev"}}' -- sh -c "sleep 3600"
```

À la fin, exécutez `check_result`.

## 12. Utilisateur avec certificat client via CSR + namespaced RBAC

Nous générons une private key et un CSR avec `CN=john` - le RBAC pour un utilisateur basé sur certificat
se lie via `kind: User`, et non `ServiceAccount`, et `User` n'a pas d'objet d'API
propre : son identity est entièrement déterminée par le fait que le CN dans le certificat client
coïncide avec le `name` dans le binding.

```bash
mkdir -p /var/work/tests/artifacts/12
openssl genrsa -out /var/work/tests/artifacts/12/john.key 2048
openssl req -new -key /var/work/tests/artifacts/12/john.key \
  -out /tmp/john.csr -subj "/CN=john"
```

Nous l'envoyons comme `CertificateSigningRequest` Kubernetes avec le même signer que celui déjà
utilisé dans la tâche 7 pour l'approbation d'un CSR (`kubernetes.io/kube-apiserver-client` -
le signer correct précisément pour un certificat client-auth, qui authentifiera
les requêtes vers l'API server) :

```bash
cat > john-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: $(base64 -w0 /tmp/john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF
k apply -f john-csr.yaml
k certificate approve john-csr
k get csr john-csr -o jsonpath='{.status.certificate}' \
  | base64 -d > /var/work/tests/artifacts/12/john.crt
```

Nous vérifions que le certificat est réellement signé par ce cluster, et pas seulement que le champ
`status.certificate` n'est pas vide :

```bash
openssl verify -CAfile <(ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt) \
  /var/work/tests/artifacts/12/john.crt
# /var/work/tests/artifacts/12/john.crt: OK
openssl x509 -in /var/work/tests/artifacts/12/john.crt -noout -subject
# subject=CN = john
```

RBAC : un Role dans `development`, un RoleBinding sur `kind: User, name: john` - `--user=john` dans
`kubectl create rolebinding` positionne lui-même `kind: User`, inutile d'écrire du YAML :

```bash
k create role john-pod-access -n development --resource=pods --verb=create,list,get
k create rolebinding john-pod-access-binding -n development \
  --role=john-pod-access --user=john

k auth can-i create pods -n development --as=john  # yes
k auth can-i list pods -n development --as=john    # yes
k auth can-i get pods -n development --as=john     # yes
k auth can-i delete pods -n development --as=john  # no
k auth can-i create pods -n security-104 --as=john # no
```

`--as=john` ne démontre que la logique RBAC (impersonation, disponible pour n'importe quel admin
indépendamment de l'émission d'un vrai certificat). Nous démontrons séparément que précisément le
certificat ÉMIS est réellement accepté par l'API server via une vraie requête TLS client-auth :

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt > /tmp/cluster-ca.crt
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/development/pods"     # 200
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/security-104/pods"     # 403
```

La même démonstration, mais via le `kubectl` habituel, et non `curl` - nous constituons pour John un
kubeconfig distinct à partir du certificat déjà émis (`set-credentials` avec `--client-certificate`/
`--client-key`, et non `--token`, car l'identity ici est précisément un client-cert, et non un
ServiceAccount token) :

```bash
k config set-cluster cluster1 --server="$SERVER" \
  --certificate-authority=/tmp/cluster-ca.crt --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-credentials john \
  --client-certificate=/var/work/tests/artifacts/12/john.crt \
  --client-key=/var/work/tests/artifacts/12/john.key --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-context john@cluster1 --cluster=cluster1 --user=john \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config use-context john@cluster1 \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development
# fonctionne - RBAC le laisse passer

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n security-104
# Error from server (Forbidden) - le même 403 que dans la vérification avec curl ci-dessus

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig auth whoami
# Username: john - confirme que le kubeconfig s'authentifie réellement précisément comme
# john, et ne donne pas simplement par hasard les bons codes de réponse
```

À la fin, exécutez `check_result`.
