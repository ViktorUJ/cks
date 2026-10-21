[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 111 - analyse d'images, corrections statiques et supply-chain evidence

## Objectif

Dans ce lab CKS, vous allez rassembler des artefacts d'evidence reproductibles pour une application
conteneurisée : rapports de vulnérabilités et d'analyseurs statiques, corrections sûres
du `Dockerfile` et du manifest du workload, deux SBOM, la recherche de versions de dépendances et la vérification de
la signature de l'image. Le résultat n'est pas simplement la sortie d'un terminal : chaque rapport doit être
enregistré à l'endroit indiqué et être apte à un audit.

C'est une tâche CKS sur le security tooling et la supply chain, et non un exercice CKA. La plupart des
artefacts sont analysés localement sur le worker ; la seule exception est la tâche 4, où
il faut appliquer un Deployment hardened pour vérifier Ready/Available et un HTTP smoke test.

## Threat model

Le lab modélise la confiance dans la supply chain à travers plusieurs menaces indépendantes. Le code
malveillant ou les faiblesses connues dans l'image sont détectés par les scanners Trivy, kubesec,
kube-linter et Hadolint aux niveaux correspondants de l'image, du Dockerfile et des manifests.

Les secrets et tokens laissés par accident dans un layer nécessitent une vérification distincte : secret
scanning (par exemple, Trivy secret scanning) et inspection de l'history de l'image (`docker history`,
extraction des couches). Le SBOM résout une autre tâche - l'inventaire des composants et des versions de
paquets ; il aide à la supply-chain investigation (par exemple, trouver une bibliothèque vulnérable),
mais n'est pas un mécanisme fiable de recherche de secrets dans l'history des couches et ne remplace pas le secret
scanning. Même si la configuration de travail ne contient plus le secret, il peut rester
accessible dans l'history des couches.

La menace de mutable-tag tampering consiste en ce qu'après le déploiement, à une référence inchangée
avec tag, on peut substituer une autre image, malveillante. C'est précisément pourquoi le digest pinning est important dans
les tâches 3–5 : il fige le contenu concret de l'image, et pas seulement son nom et son tag.

La vérification de la signature dans la tâche 7 démontre qu'un digest concret est signé par une
key/identity de confiance (signature integrity), tandis que le Trivy scan de la tâche 1 ne détecte pas
de vulnérabilités connues entrant dans sa detection coverage avec la vulnerability DB actuelle
(Trivy documente lui-même un trade-off en faveur de la precision, dans lequel des faux
négatifs sont possibles : « 0 findings » n'est pas égal à une formal proof de l'absence de vulnérabilités). Ce sont des axes différents de
protection : aucun ne remplace l'autre, puisque vulnerability != signature. La signature
n'est PAS la même chose que provenance/attestation
(par exemple, build metadata de style SLSA sur de quoi et comment l'artifact a été construit) : `cosign
verify` confirme l'authenticité de la signature, et non l'history complet de la build ; pour l'attestation,
Sigstore fournit des commandes distinctes `cosign attest`/`cosign verify-attestation`, non
utilisées dans ce lab.

Le `cosign verify` local (tâche 7) n'est pas en soi un enforcement : il démontre la
signature d'une image reference concrète au moment de la vérification, mais n'empêche pas quelqu'un de lancer une
image non signée ou signée autrement par un `kubectl apply` direct, en contournant le CI. Seule la
vérification admission-time (tâche 9a-9c) fait de la signature une condition obligatoire d'admission d'un
Pod dans le cluster - c'est la différence entre « nous avons vérifié la signature » et « le cluster ne lancera pas d'
image non signée ».

La preuve de cette propriété exige de la rigueur : un nouveau `kubectl apply` d'un Deployment déjà
existant ne crée pas de nouveau Pod si le template n'a pas changé, c'est pourquoi
`Running` peut signifier « un ancien Pod, créé avant la policy », et non « la policy a admis
précisément cette image » (la tâche 9b vérifie `creationTimestamp` explicitement). De même, le DENY
unsigned ne démontre la propriété que si le digest vérifié existe réellement et est pullable dans le
même repository que l'image signée (tâche 9c) - sinon l'admission peut refuser
à cause d'un manifest absent du registry, et non à cause de l'absence de signature.

## Vérifiez-vous avant de commencer

<details>
<summary>1. Pourquoi le SBOM n'est-il pas un mécanisme fiable de recherche de secrets laissés dans un image layer ?</summary>

Le SBOM résout la tâche d'inventaire des COMPOSANTS et des versions de paquets (ce qui est installé, quelle version) - c'est une analyse structurelle des métadonnées du gestionnaire de paquets, et non une recherche de chaînes/secrets arbitraires dans le contenu des fichiers des couches. Un secret laissé, par exemple, dans une variable d'environnement ENV ou un fichier temporaire pendant la build, peut rester dans l'history des couches même après que la couche finale ne le contient plus - pour cela, il faut un outil distinct (secret scanning, `docker history`, extraction des couches), et non un SBOM.
</details>

<details>
<summary>2. Quelle est la différence entre ce que démontre le Trivy scan (tâche 1) et ce que démontre la signature Cosign (tâche 9a-9c) ?</summary>

Au moment de la vérification, avec la vulnerability DB actuelle et la logique de détection de Trivy, le scan N'A PAS DÉTECTÉ de vulnérabilités connues entrant dans sa detection coverage - cela concerne la qualité/sécurité du contenu de l'image dans la mesure où Trivy est capable de le voir. La documentation de Trivy décrit elle-même directement un trade-off en faveur de la precision (minimisation des false positives), dans lequel des false negatives sont possibles - c'est-à-dire que « 0 findings » n'équivaut pas à la preuve formelle de l'absence totale de vulnérabilités. La signature Cosign démontre la SIGNATURE INTEGRITY - qu'un digest concret est signé par une clé/identity de confiance, c'est-à-dire que quelqu'un d'autorisé a confirmé que c'est précisément l'artifact qui doit être déployé. Ce n'est PAS la même chose que provenance/attestation (l'history complet de la build - de quoi, par qui et comment l'artifact a été construit) : pour l'attestation, Sigstore a des commandes distinctes (`cosign attest`/`cosign verify-attestation`), non utilisées dans ce lab. Une image peut être entièrement sûre (0 CVE) et en même temps non signée - ou signée, mais contenir une vulnérabilité inconnue. Ce sont deux axes indépendants de protection.
</details>

<details>
<summary>3. Pourquoi `cosign verify` en local dans le CI n'empêche-t-il pas quelqu'un de déployer une image non signée via `kubectl apply` ?</summary>

`cosign verify`, exécuté localement (par exemple, dans un CI pipeline), est simplement une commande qui vérifie la signature et renvoie le résultat à celui qui l'a invoquée. Elle n'est pas intégrée au chemin d'admission de la Kubernetes API - rien n'empêche quelqu'un ayant accès au cluster d'exécuter simplement `kubectl apply` avec N'IMPORTE QUELLE image, en contournant entièrement le CI. Seule la vérification admission-time (tâche 9a-9c), intégrée au cluster lui-même comme policy, fait de la signature une condition OBLIGATOIRE d'admission - c'est la différence entre « nous avons vérifié » et « le cluster ne la laissera physiquement pas passer ».
</details>

## Infrastructure

L'environnement est créé par Terragrunt dans AWS `eu-central-1`.

| Composant | Rôle |
|---|---|
| `vpc` | VPC `10.111.0.0/16` avec des sous-réseaux publics |
| `ssh-keys` | accès au nœud |
| `k8s-1` | kubeadm mono-nœud avec Kubernetes `1.36.0`, containerd et **Calico** |
| `worker` | poste de travail pour l'analyse, `kubectl`, `check_result` et security tools |

Infrastructure de style CKA : l'unique nœud control-plane est autorisé pour les workload et
marqué `cks.io/lab=111`. Les commandes principales et les security tools s'exécutent sur le worker.
Le cluster Kubernetes est utilisé comme target environment pour vérifier le workload hardened et
la signature policy admission-time : la tâche 4 déploie `catalog`, et les tâches 9b/9c
réalisent les admission probes positive/negative.

Sur le worker sont disponibles à l'avance exactement ces versions figées :

| Outil | Version | Rôle |
|---|---:|---|
| Trivy | `0.74.0` | CVE et liste de paquets de l'image |
| kubesec | `2.14.0` | security score du YAML Kubernetes |
| kube-linter | `0.8.3` | policy lint du YAML Kubernetes |
| Hadolint | `2.12.0` | lint du Dockerfile |
| Syft | `1.51.0` | SBOM CycloneDX JSON |
| bom | `0.8.0` | SBOM SPDX JSON (format natif de `bom`) |
| Cosign | `3.1.3` | signing et verification de la signature d'une image OCI |

Helm et `install-kyverno` sont aussi disponibles sur le worker, mais Kyverno n'est volontairement **pas installé** :
son installation fait partie de la tâche 9, comme dans le lab 108. `install-kyverno` fige Kyverno
`1.19`/chart `3.9.0` ; la support matrix officielle upstream pour cette version est Kubernetes
`1.33-1.35`, alors que ce cluster est en `1.36`. C'est une exception lab-specific consciente, hors de la
plage testée (comme le précédent du lab 108), et non un support officiel
garanti ; lors de la mise à jour de Kyverno, retirez cette exception.

## Prérequis et limitations

**podman et le registry sur le banc d'essai sont déjà configurés.** Pour construire et publier des images, utilisez `podman`
(outil de la liste de l'examen ; rootless, depuis l'utilisateur `ubuntu`). Les tâches 3 et 9c exigent de construire et
**publier** une image dans un registry accessible à la fois depuis le worker et depuis le cluster (la référence immuable
`repo@sha256:...` est prise du registry, un image ID local ne convient pas). Ce registry,
`registry:2` sur le control-plane, a été levé par le bootstrap :

- adresse : `<IP du control-plane>:5000`, elle est notée dans `/etc/cks111/registry` sur le worker ;
- le protocole est du HTTP ordinaire à l'intérieur du VPC : podman sur le worker et containerd sur le nœud sont configurés pour lui comme
  insecure registry (le flag `--tls-verify=false` n'est pas nécessaire), et dans l'`ImageValidatingPolicy` pour Kyverno il faut
  `credentials.allowInsecureRegistry: true` ;
- les données sont conservées sur un PV local du nœud (`/var/lib/cks111-registry`), elles survivent donc au
  redémarrage du Pod du registry ;
- le digest de l'image publiée, obtenez-le de `podman push --digestfile`, et la présence du manifest,
  vérifiez-la par une requête à `/v2/` (dans le registry, il n'y a pas d'outils HTTPS-only comme `docker buildx imagetools`) ;
- la séquence détaillée de commandes est à l'étape « 0. Préparation » de la [solution](worker/files/solutions/1_FR.MD).

**Limite de Docker Hub.** Les pull anonymes depuis une même IP ont une limite (environ 100 requêtes par 6 heures).
Pour que `check_result` ne s'y heurte pas, le bootstrap télécharge une seule fois les images du lab dans un cache local
(`nginx:1.27.3-alpine` et les candidats pour les tâches 1b/1c), et Trivy et Syft lors des scans répétés prennent l'
image de ce cache par la même référence `nom@sha256:...`, sans s'adresser à Docker Hub. `bom` sait
lire l'image uniquement depuis le registry, il fait donc toujours plusieurs requêtes par lancement.
Si Docker Hub a tout de même renvoyé `TOOMANYREQUESTS`, patientez (la fenêtre de la limite est glissante) ou exécutez
`podman login docker.io` avec votre propre compte.

**Cosign et le mot de passe de la clé.** `cosign generate-key-pair` et `cosign sign --key` demandent le mot de passe de
la clé ; pour une paire pédagogique, on peut le laisser vide (`export COSIGN_PASSWORD=""`), afin que les commandes
n'attendent pas de saisie.

**`trivy sbom` et un SBOM sans OS (tâche 8).** Le SPDX de `bom` pour une image multi-arch ne contient pas
d'informations sur l'OS : Trivy écrit `Detected OS family="none"` et ne trouve pas de vulnérabilités (`Results` vide).
C'est pourquoi dans la tâche 8 on scanne le CycloneDX de la tâche 7 : il contient un composant `operating-system`,
et `trivy sbom` donne un `Results` non vide.

## Déploiement

```bash
TASK=111 make run_cks_task
```

Connectez-vous au worker et choisissez le contexte :

```bash
kubectl config use-context cluster1-admin@cluster1
cd /home/ubuntu/cks-111
check_result
```

Initialement, `Dockerfile` et `deployment.yaml` sont volontairement non sûrs. Créez les artefacts de travail
uniquement dans `/var/work/tests/artifacts/<numéro>/`.

## Tâches

`nginx:1.27.3-alpine` est un mutable tag, et non une référence figée. Obtenez d'abord le registry manifest digest canonique depuis `Metadata.RepoDigests[0]` du JSON de Trivy et utilisez l'immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` (ci-après `$IMAGE`). Pour votre propre hardened image, construisez et publiez d'abord l'image dans un registry accessible au cluster, puis utilisez son manifest digest ; un image ID local et un layer DiffID ne sont pas un registry manifest digest.

---
| **1** | **Trivy : rapport de vulnérabilités de l'image** |
| :---: | :--- |
| Ce qu'on fait | • Scannez l'`$IMAGE` immuable avec Trivy, y compris les vulnérabilités d'OS et de bibliothèques.<br/>• Enregistrez le JSON structuré dans `/var/work/tests/artifacts/1/trivy-report.json`. |
| Critères d'acceptation | • **Fichier :** non vide, le JSON est analysé par `jq`, contient `Results` et l'immutable reference de l'image analysée.<br/>• **Vérification fraîche :** le checker répète lui-même `trivy image` pour la même image et exige que ce scan frais coïncide avec succès par `ArtifactName`.<br/>• Un JSON écrit à la main, mais syntaxiquement valide, ne passe pas. |

<details>
<summary>💡 Indice pour la tâche 1</summary>

`$IMAGE` se construit en deux étapes : vous scannez d'abord `nginx:1.27.3-alpine` (un tag ordinaire) et vous extrayez `Metadata.RepoDigests[0]` de CE premier rapport JSON, puis vous reconstruisez la commande avec `nginx:1.27.3-alpine@sha256:<digest>` et vous scannez déjà la référence immuable - c'est précisément ce second rapport qu'il faut enregistrer comme final. N'utilisez pas `ImageID`/`DiffID` de la sortie de Trivy comme substitut du registry digest - ce sont des identifiants LOCAUX, qui ne coïncident pas avec le manifest digest dans le registry.
</details>

---
| **1b** | **Multi-image CVE triage : trouver l'image contenant une CVE concrète** |
| :---: | :--- |
| Ce qu'on fait | • Ouvrez `~/cks-111/candidates.txt` : il y a trois immutable image reference (`CANDIDATE_1/2/3`) et la `TARGET_CVE` cible, définies individuellement pour votre instance du lab lors du bootstrap.<br/>• Scannez **les trois** images avec Trivy et trouvez laquelle contient réellement `TARGET_CVE`.<br/>• Enregistrez le rapport JSON précisément de cette image dans `/var/work/tests/artifacts/1b/target-scan.json`.<br/>• La ligne `OFFENDING_IMAGE=<référence complète de cette image>` enregistrez-la dans `/var/work/tests/artifacts/1b/answer.txt`. |
| Critères d'acceptation | • **Réponse :** `answer.txt` indique précisément le `CANDIDATE_N` dont le scan réel de Trivy contient `TARGET_CVE`.<br/>• **Rapport :** `target-scan.json` est la sortie authentique de Trivy pour cette même image (le checker répète lui-même le scan et compare). |

<details>
<summary>💡 Indice pour la tâche 1b</summary>

`TARGET_CVE` est différente pour chaque instance du lab - elle est calculée lors du provisioning à partir de la vulnerability DB de Trivy en direct, et n'est pas figée à l'avance, donc dans ce fichier se trouve votre propre réponse. Ne devinez pas d'après le nom du tag (« le plus ancien est sûrement vulnérable ») - scannez réellement les trois et trouvez la correspondance exacte de `VulnerabilityID` dans le JSON. Une commande par image : `trivy image --format json "$ref" | tee scan.json`, puis `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | index("<TARGET_CVE>")' scan.json` - `null` signifie que cette CVE concrète est absente précisément de cette image (elle peut très bien contenir d'autres CVE - cela n'est pas vérifié).
</details>

---
| **1c** | **Workload image triage by CRITICAL severity** |
| :---: | :--- |
| Ce qu'on fait | • Dans le namespace `cks-111`, 4 Deployment sont déjà déployés (label `cks.io/task=1c`), chacun avec une seule image immutable épinglée par digest.<br/>• Obtenez les image references de ces Deployments LIVE (ne devinez pas d'après le nom du tag), scannez **les 4** images avec Trivy avec `--severity CRITICAL` et comptez le nombre de `VulnerabilityID` CRITICAL uniques pour chacune.<br/>• Déterminez le Deployment avec le plus grand nombre de CRITICAL (« le plus vulnérable ») et les deux Deployment avec le plus petit nombre (« les deux moins vulnérables »). Notez leurs noms dans `/var/work/tests/artifacts/1c/ranking.txt` comme `MOST_VULNERABLE=<deployment-name>`, `LEAST_VULNERABLE_1=<deployment-name>`, `LEAST_VULNERABLE_2=<deployment-name>`.<br/>• Pour l'image du Deployment le plus vulnérable, générez un CycloneDX SBOM **précisément de Trivy** (`trivy image --format cyclonedx`) dans `1c/cyclonedx.json`.<br/>• Ensuite, remédiez : ne laissez `replicas > 0` que sur les deux Deployment les moins vulnérables, et scalez les deux autres (y compris le plus vulnérable) à `replicas: 0`. |
| Critères d'acceptation | • **Ranking :** le checker répète lui-même le scan CRITICAL de Trivy des 4 live images et recalcule le ranking - `ranking.txt` doit coïncider avec ce scan frais, et non avec un scan périmé/deviné.<br/>• **SBOM :** `cyclonedx.json` est un document CycloneDX valide précisément de Trivy, se rapportant à l'image du Deployment réellement le plus vulnérable.<br/>• **Remediation :** exactement 2 Deployment (les moins vulnérables d'après le scan frais) ont `replicas > 0`, les 2 autres - `replicas: 0`. |

<details>
<summary>💡 Indice pour la tâche 1c</summary>

Obtenez les image references par une commande du type `kubectl -n cks-111 get deployment -l cks.io/task=1c -o jsonpath=...` - n'essayez pas de deviner d'après le nom du Deployment quelle image est « plus récente » ou « plus sûre ». La commande pour compter : `trivy image --scanners vuln --severity CRITICAL --format json <ref>`, puis `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length'`. Pour CycloneDX, utilisez précisément `trivy image --format cyclonedx --output <file> <ref>` - pas Syft (Syft est déjà utilisé dans la tâche 7 pour une autre image, ici Trivy est explicitement exigé). Le scale se fait via `kubectl scale deployment/<name> -n cks-111 --replicas=0` (ou `--replicas=1` pour ceux que l'on conserve).
</details>

---
| **2** | **Rapports initiaux de l'analyse statique** |
| :---: | :--- |
| Ce qu'on fait | • AVANT les corrections (sans toucher à aucun de ces trois fichiers après le début de la tâche 3), enregistrez les résultats : Hadolint dans `2/hadolint-before.txt`, kubesec JSON dans `2/kubesec-before.json`, kube-linter JSON dans `2/kube-linter-before.json`.<br/>• Lancez-les directement contre les `Dockerfile`/`deployment.yaml` initiaux ORIGINAUX.<br/>• Ne masquez pas les erreurs via `|| true` dans les fichiers de rapports : un exit code non nul du linter est attendu. |
| Critères d'acceptation | • **Artefacts :** les trois existent ; Hadolint contient des findings, kubesec contient `scoring`, kube-linter est un objet JSON de KubeLinter valide avec les champs `Reports` et `Summary` ; avant les corrections, `Reports` contient des findings.<br/>• **Comparaison avec le baseline :** le checker compare le contenu des trois artefacts avec son propre baseline, relevé lors du provisioning contre les fichiers initiaux originaux AVANT qu'ils ne soient remis à l'étudiant.<br/>• Un rapport écrit à la main, mais syntaxiquement valide, ne passe pas. |

<details>
<summary>💡 Indice pour la tâche 2</summary>

Un exit code non nul du linter lorsqu'il détecte des problèmes est un comportement ATTENDU, et non une erreur de votre commande. Si vous enveloppez l'appel dans `|| true` seulement pour que le script ne s'arrête pas avec `set -e`, assurez-vous que la sortie de la commande est tout de même enregistrée dans le fichier (via `tee` ou une redirection AVANT `|| true`), et non perdue.
</details>

---
| **3** | **Corriger le Dockerfile d'après les findings** |
| :---: | :--- |
| Ce qu'on fait | • Corrigez `/home/ubuntu/cks-111/Dockerfile` : figez l'image de base par l'immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>`.<br/>• N'utilisez pas `ADD` avec une URL, ne conservez pas de token dans `ENV`, n'installez pas `sudo`.<br/>• Ajoutez un `USER` non privilégié (uid différent de `0`). Utilisez `COPY` et une installation reproductible de paquets seulement si nécessaire.<br/>• Ajoutez `ARG CKS_SIGNATURE_TEST=signed` et `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` à côté des autres instructions - c'est l'unique point de différence contrôlée de l'image qui sera nécessaire dans la tâche 9c, pour garantir un digest différent sans changer les propriétés de sécurité vérifiées ici.<br/>• Après la correction, enregistrez la sortie réussie de Hadolint dans `3/hadolint-after.txt`. |
| Critères d'acceptation | • **Dockerfile :** pas de `latest`, le `ADD` distant est supprimé, il ne reste ni `API_TOKEN` ni `TOKEN`, il y a un `USER` non-root, il y a `ARG CKS_SIGNATURE_TEST` et `LABEL cks.signature-test`.<br/>• **Hadolint :** le rapport final ne contient pas `DL3007`, `DL3013`, `DL3020`, `DL3045`. |

<details>
<summary>💡 Indice pour la tâche 3</summary>

`ARG`/`LABEL` pour `CKS_SIGNATURE_TEST` peut sembler sans rapport avec les findings actuels de Hadolint - il est ajouté exprès ici à l'avance, afin que la tâche 9c (bien plus tard) puisse construire une image physiquement différente via `--build-arg`, sans réécrire le Dockerfile une seconde fois. Ajoutez ces deux lignes maintenant, même si leur utilité ne deviendra claire qu'en 9c.
</details>

---
| **4** | **Corriger le workload YAML d'après kubesec et kube-linter** |
| :---: | :--- |
| Ce qu'on fait | • Construisez et publiez d'abord la hardened image de la tâche 3, puis indiquez dans `deployment.yaml` sa immutable manifest reference `registry/.../catalog@sha256:<manifest-digest>` (et non l'nginx upstream).<br/>• Au niveau du Pod, ajoutez `automountServiceAccountToken: false`, `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`.<br/>• Dans le conteneur, définissez `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, requests/limits CPU et memory.<br/>• Pour nginx, montez un `emptyDir`/tmpfs writable dans les chemins temp, pid/run, cache et config et préparez la config avant le démarrage.<br/>• Supprimez `privileged`, appliquez le Deployment, confirmez Ready/Available et une requête HTTP réussie.<br/>• Enregistrez les nouveaux rapports `4/kubesec-after.json` et `4/kube-linter-after.json`. |
| Critères d'acceptation | • **Image :** le YAML utilise une hardened image épinglée par digest avec `USER 101`, et non l'nginx upstream.<br/>• **Manifest :** les champs requis et les writable mounts sont présents ; `privileged` est absent.<br/>• **Fonctionnement :** le Deployment est Available et la requête HTTP réussit.<br/>• **Rapports :** les deux rapports finaux sont du JSON valide. |

<details>
<summary>💡 Indice pour la tâche 4</summary>

`readOnlyRootFilesystem: true` nécessite des chemins writable pour CHAQUE répertoire dans lequel nginx écrit habituellement : `/tmp`, `/var/run` (fichier PID), `/var/cache/nginx` (cache) et `/etc/nginx/conf.d` (si la config est générée au démarrage). Si vous en omettez ne serait-ce qu'un, le conteneur démarrera, mais plantera à la première tentative de nginx d'y écrire quelque chose. L'init container `prepare-nginx-config` est nécessaire pour copier la config par défaut dans un volume writable distinct AVANT le démarrage du conteneur principal - c'est précisément pourquoi il est mentionné séparément dans les critères d'acceptation.
</details>

---
| **5** | **Recherche de versions de paquets** |
| :---: | :--- |
| Ce qu'on fait | • Utilisez Trivy en mode liste de tous les paquets pour `$IMAGE`.<br/>• Enregistrez la commande, l'immutable image reference, le `nginx@sha256:<manifest-digest>` canonique de `Metadata.RepoDigests[0]` et au moins trois lignes `nom=version` dans `/var/work/tests/artifacts/5/version-search.txt`.<br/>• Ne remplacez pas la recherche par une liste manuelle : dans l'evidence doit figurer la ligne de la commande avec `trivy image --list-all-pkgs`. |
| Critères d'acceptation | • **Artefact :** contient la commande, l'immutable `nginx:1.27.3-alpine@sha256:...`, `repo_digest=nginx@sha256:...` de Trivy et au moins trois paires package/version.<br/>• **Vérification fraîche :** le checker répète lui-même `trivy image --list-all-pkgs` pour la même image et exige que `repo_digest=` et au moins trois paires `name=version` enregistrées coïncident avec ce scan frais.<br/>• Une liste écrite à la main, mais syntaxiquement plausible, ne passe pas. |

<details>
<summary>💡 Indice pour la tâche 5</summary>

Le flag s'appelle précisément `--list-all-pkgs`, et non `--list-packages` ni une variante proche - vérifiez le nom exact du flag dans `trivy image --help`, si la commande ne fonctionne pas. Enregistrez la sortie RÉELLE de la commande dans le fichier (par exemple via `tee`), ne réécrivez pas à la main quelques lignes package=version « de mémoire » - le test cherche la ligne avec la commande elle-même comme preuve que les données proviennent de l'outil.
</details>

---
| **5b** | **Find a package version in workload images and remove offending containers** |
| :---: | :--- |
| Ce qu'on fait | • Dans le namespace `cks-111` est déjà déployé le Deployment `pkg-audit-app` avec trois conteneurs (`c1`, `c2`, `c3`), chacun sur sa propre image immutable épinglée par digest.<br/>• Exactement dans deux des trois images est présent un même paquet d'une version concrète - les `TARGET_PACKAGE`/`TARGET_VERSION` indiqués pour votre instance du lab sont définis dynamiquement lors du provisioning, il n'y a pas de valeurs figées.<br/>• Obtenez les trois image references du Deployment live, pour chacune exécutez `bom generate` (enregistrez chaque SBOM séparément dans `/var/work/tests/artifacts/5b/bom/`).<br/>• Déterminez quels deux conteneurs contiennent réellement le même package/version et notez la paire trouvée dans `5b/answer.txt` comme `TARGET_PACKAGE=<name>` et `TARGET_VERSION=<version>`.<br/>• Supprimez PRÉCISÉMENT ces deux conteneurs offending du Deployment (via `kubectl edit`/`kubectl apply` d'un manifest corrigé) de sorte qu'il ne reste que le conteneur « propre », et que le Deployment reste `Available`. |
| Critères d'acceptation | • **Réponse :** `answer.txt` nomme le package/version réel, présent précisément dans deux des trois images d'origine (et non deviné). Ces deux images ont beaucoup de paquets en commun : toute paire `name=version` qui n'est pas dans la troisième image convient.<br/>• **SBOM :** dans `5b/bom/` il y a au moins une sortie authentique de `bom generate` qui confirme cette trouvaille.<br/>• **Vérification indépendante :** le checker exécute indépendamment `bom generate` pour les candidate images d'origine (enregistrées lors du provisioning) et compare votre réponse avec cette exécution indépendante.<br/>• **Deployment :** le Deployment final contient uniquement le conteneur « propre » et reste `Available`. |

<details>
<summary>💡 Indice pour la tâche 5b</summary>

La commande est `bom generate --format json --output <file> --image <ref>` pour CHACUNE des trois image references séparément. Comparez les SBOM par paires : un paquet est considéré « offending » si la même paire `name`/`versionInfo` apparaît dans le SBOM de deux conteneurs, mais est absente (ou a une autre version) dans le troisième. N'essayez pas de deviner d'après le nom/tag de l'image - certaines paires d'images peuvent sembler « semblables », mais la coïncidence réelle d'un paquet ne se détermine que par la comparaison des SBOM réels. En modifiant le Deployment, supprimez le conteneur en entier de `spec.template.spec.containers`, et ne changez pas simplement son image.
</details>

---
| **6** | **SPDX SBOM via bom** |
| :---: | :--- |
| Ce qu'on fait | • Générez un SPDX JSON SBOM avec l'outil `bom` précisément pour l'`$IMAGE` immuable (le même `tag@digest` que celui utilisé dans la tâche 1, et non le bare tag `nginx:1.27.3-alpine`) ; enregistrez-le dans `/var/work/tests/artifacts/6/bom.spdx.json`.<br/>• Dans le fichier `6/bom-command.txt`, notez la commande exécutée avec le `--image $IMAGE` exact. |
| Critères d'acceptation | • **SBOM :** JSON valide, a `spdxVersion`, contient le tableau `packages` ; l'un des paquets top-level auxquels se réfère `documentDescribes` identifie LE MÊME manifest digest que `$IMAGE` de la tâche 1 (via `versionInfo`/`name`).<br/>• **Commande :** `bom-command.txt` contient l'`$IMAGE` immuable exacte et utilise `bom generate`.<br/>• Un SBOM d'une autre image (sans rapport avec l'`$IMAGE` de la tâche 1) ne passe pas, même si `bom-command.txt` est falsifié.<br/>• **Vérification fraîche :** le checker régénère en outre lui-même le SBOM avec le même `bom` pour la même image et exige que l'ensemble de paquets (`name`/`versionInfo`) de votre SBOM coïncide avec cette exécution fraîche - un document SPDX minimal écrit à la main avec un seul paquet top-level ne passe pas. |

<details>
<summary>💡 Indice pour la tâche 6</summary>

La commande `bom generate -o <output.json> -i <image>` - obligatoirement avec le flag `-o` pour indiquer le fichier de sortie, sinon la sortie ira sur stdout. Le format de sortie de `bom` est son PROPRE SPDX JSON, qui diffère par ses détails du SPDX que peut générer Syft - ne confondez pas ces deux outils différents lors de la génération d'un même format du standard.
</details>

---
| **7** | **CycloneDX SBOM via Syft et vérification avec Cosign** |
| :---: | :--- |
| Ce qu'on fait | • Générez un CycloneDX JSON SBOM de Syft pour la même `$IMAGE` immuable (`nginx:1.27.3-alpine@sha256:<manifest-digest>`) de la tâche 1 et enregistrez-le dans `7/syft.cdx.json`.<br/>• Vérifiez ensuite la signature de l'image publique `gcr.io/distroless/static-debian13:nonroot` via Cosign keyless et enregistrez la sortie réussie complète dans `7/cosign-verify.txt`.<br/>• Pour Distroless, utilisez l'issuer `https://accounts.google.com` et l'identity `keyless@distroless.iam.gserviceaccount.com`. |
| Critères d'acceptation | • **Syft SBOM :** `bomFormat: CycloneDX`, `components` non vide, `metadata.component.type == "container"` et `metadata.component.version` égal au manifest digest de la même `$IMAGE` de la tâche 1 - un SBOM d'une autre image (bare tag, alpine, busybox, etc.) ne passe pas.<br/>• **Cosign :** une vraie commande `cosign verify` pour `gcr.io/distroless/static-debian13:nonroot` (le tag actuel pris en charge - `gcr.io/distroless/static:nonroot` sans le suffixe `-debian13` est considéré deprecated d'après le README officiel de Distroless et n'est plus mis à jour) avec l'issuer/identity indiqués se termine avec l'exit code `0`, et la sortie complète est enregistrée dans `7/cosign-verify.txt`.<br/>• **Vérification fraîche :** le checker régénère en outre lui-même le SBOM avec le même Syft pour la même image et exige que l'ensemble de composants (`name`/`version`) de votre SBOM coïncide avec cette exécution fraîche - un document CycloneDX minimal écrit à la main avec un seul composant top-level ne passe pas. |

<details>
<summary>💡 Indice pour la tâche 7</summary>

Syft génère CycloneDX via le flag `-o cyclonedx-json` (à ne pas confondre avec la sortie SPDX du même outil). Pour la keyless verification de Distroless, il ne faut NI clé NI `cosign generate-key-pair` - utilisez `cosign verify --certificate-identity <identity> --certificate-oidc-issuer <issuer>` avec les chaînes issuer/identity EXACTES indiquées dans la tâche - une faute de frappe dans l'une d'elles donnera une erreur de vérification.
</details>

---
| **8** | **`trivy sbom` : scanner un fichier SBOM déjà prêt à la recherche de vulnérabilités** |
| :---: | :--- |
| Ce qu'on fait | • Le CycloneDX SBOM de la tâche 7 (`7/syft.cdx.json`) décrit la composition de l'image et son OS, mais ne contient pas par lui-même de conclusions sur les vulnérabilités.<br/>• Scannez précisément ce fichier SBOM (et non l'image directement) avec l'outil `trivy sbom` et enregistrez le JSON structuré dans `/var/work/tests/artifacts/8/sbom-scan.json`.<br/>• La commande doit accepter explicitement le fichier SBOM en entrée, et non rescanner `$IMAGE`. |
| Critères d'acceptation | • **Fichier :** non vide, le JSON est analysé par `jq`, `ArtifactType` = `cyclonedx`, `Results` non vide et contient les vulnérabilités trouvées.<br/>• **Commande :** `sbom-scan-command.txt` contient la commande `trivy sbom` avec le chemin vers `7/syft.cdx.json`.<br/>• **Vérification fraîche :** le checker répète lui-même `trivy sbom` sur ce fichier. |

<details>
<summary>💡 Indice pour la tâche 8</summary>

La commande est `trivy sbom <chemin-vers-le-fichier-sbom>`, et PAS `trivy image <chemin-vers-le-fichier>` - ce sont des sous-commandes différentes avec une logique d'entrée différente. Si vous passez par accident le chemin du fichier SBOM à `trivy image`, Trivy essaiera de l'interpréter comme un nom d'image reference et se terminera par une erreur ou un comportement inattendu.
</details>

---
| **9a** | **Kyverno : installer et créer une `ImageValidatingPolicy` de trusted signature** |
| :---: | :--- |
| Ce qu'on fait | • Installez Kyverno via `install-kyverno` et attendez que l'`admission controller` soit prêt.<br/>• Générez une paire de clés locale `cosign generate-key-pair` (une paire pédagogique, pas une production key).<br/>• Signez votre **propre** hardened image de la tâche 4 (`$HARDENED_IMAGE`, et non l'nginx upstream) avec votre private key et enregistrez la sortie de `cosign sign` dans `9a/cosign-sign.txt`.<br/>• Créez une `ImageValidatingPolicy` `require-signed-catalog-images`, qui vérifie `verifyImageSignatures` avec votre public key pour tous les Pod avec une image dans le repository de votre `$HARDENED_IMAGE`, y compris les UPDATE de `pods/ephemeralcontainers` et toutes les container lists, et **rejette** (`validationActions: [Deny]`) les images unsigned/à signature invalide. |
| Critères d'acceptation | • **Kyverno :** installé, son admission controller `Available`.<br/>• **Signature :** `9a/cosign-sign.txt` contient la sortie réussie de la signature précisément de `$HARDENED_IMAGE` ; la vraie commande `cosign verify --key cosign.pub "$HARDENED_IMAGE"` se termine avec succès.<br/>• **Policy :** l'`ImageValidatingPolicy require-signed-catalog-images` appliquée existe, a `apiVersion: policies.kyverno.io/v1`, `validationActions: [Deny]`, la public key et `verifyImageSignatures`.<br/>• **Champ d'action :** ses `matchImageReferences` sont limitées précisément à `$HARDENED_REPO:*` et `$HARDENED_REPO@*`, et non au préfixe non sûr `$HARDENED_REPO*`. |

<details>
<summary>💡 Indice pour la tâche 9a</summary>

`cosign generate-key-pair` crée `cosign.key`/`cosign.pub` dans le répertoire courant - une paire pédagogique, non liée à un OIDC issuer, contrairement à la keyless verification de la tâche 7. Conservez la private key en dehors de `/home/ubuntu/cks-111`, car ce répertoire est réutilisé comme Docker build context dans la tâche 9c - un `cosign.key` laissé dedans se retrouvera directement dans le système de fichiers de l'image publiée via `COPY . /usr/share/nginx/html`. `matchImageReferences` dans la policy doit limiter son action PRÉCISÉMENT à votre repository (`$HARDENED_REPO`), et non à tout le cluster - sinon la policy bloquera TOUS les Pod sans signature, y compris les composants système de Kubernetes.
</details>

---
| **9b** | **Fresh signed ALLOW : un Pod nouveau après la création de la policy** |
| :---: | :--- |
| Ce qu'on fait | • La policy de la tâche 9a doit admettre le `$HARDENED_IMAGE` signé - mais un nouveau `kubectl apply` d'un Deployment déjà existant **ne démontre pas** cela : si le template n'a pas changé, un nouveau ReplicaSet/Pod peut ne pas être créé, et `Running` s'avérera être simplement un ancien Pod, créé avant la policy.<br/>• Créez un objet **nouveau**, qui n'existait pas auparavant : `kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" --restart=Never --command -- sleep 300`.<br/>• Enregistrez le `creationTimestamp` de ce Pod, le `creationTimestamp` de la policy de 9a, et le `status.phase`/condition `Ready` final dans `9b/signed-admission-check.json`. |
| Critères d'acceptation | • **Pod :** `signed-admission-check` existe, utilise précisément `$HARDENED_IMAGE` ; pour lui, `cosign verify --key cosign.pub "$HARDENED_IMAGE"` s'exécute avec succès, `status.phase` n'est pas `Failed`, et la condition `Ready` atteint `True`.<br/>• **Artefact :** `9b/signed-admission-check.json` contient cette image et le `creationTimestamp` du Pod **postérieur** au `creationTimestamp` de l'`ImageValidatingPolicy require-signed-catalog-images`.<br/>• Cela démontre le fresh post-policy admission précisément d'une image vérifiablement signée, et non d'un ancien Pod qui a survécu à la policy. |

<details>
<summary>💡 Indice pour la tâche 9b</summary>

Ne réutilisez pas le Deployment `catalog` de la tâche 4 pour cette vérification - utilisez littéralement un nouveau `kubectl run` avec un nouveau nom de Pod, comme indiqué dans la tâche. Les deux timestamp (du Pod et de la policy) sont des chaînes ISO8601 en UTC, on peut les comparer lexicographiquement comme des chaînes ordinaires (`"2026-09-06T10:05:00Z" > "2026-09-06T10:00:00Z"` en bash fonctionne correctement pour ce format).
</details>

---
| **9c** | **Signature-specific DENY : un digest unsigned qui existe réellement dans le même repository** |
| :---: | :--- |
| Ce qu'on fait | • Construisez et publiez un **second** tag dans le même repository que `$HARDENED_IMAGE` (par exemple, `${HARDENED_TAG%:*}:unsigned-1.0`), sans le signer.<br/>• Cette image doit être un **artifact physiquement différent**, et non le même digest que le `$HARDENED_IMAGE` déjà signé : si vous construisez le même `Dockerfile`/context sans changement, un reproducible/cached build peut donner un digest identique, et alors le tag « unsigned » pointera en fait vers un artifact déjà signé, et `cosign verify` passera de façon inattendue.<br/>• Introduisez une différence contrôlée via un build-arg (par exemple `--build-arg CKS_SIGNATURE_TEST=unsigned-1` avec le `ARG`/`LABEL` correspondant dans le Dockerfile) et enregistrez explicitement la preuve `$UNSIGNED_DIGEST != $HARDENED_DIGEST` dans `9c/digest-comparison.txt`.<br/>• Obtenez le registry manifest digest de la même façon que dans la tâche 3 (`podman push --digestfile`), constituez `$UNSIGNED_IMAGE` dans le même repository.<br/>• Démontrez explicitement que ce digest **existe et est pullable** (une requête `GET /v2/catalog/manifests/<digest>` au registry réussit) et **n'a pas** de signature valide avec votre clé (`cosign verify --key cosign.pub "$UNSIGNED_IMAGE"` se termine par une erreur) - enregistrez les deux sorties dans `9c/unsigned-exists.txt` et `9c/unsigned-not-signed.txt`.<br/>• Créez ensuite un Pod `catalog-unsigned-probe` avec cette `$UNSIGNED_IMAGE` et enregistrez l'admission denial dans `9c/admission-deny.txt`. |
| Critères d'acceptation | • **Artefact :** `9c/digest-comparison.txt` contient `hardened_digest=`, `unsigned_digest=` et `unsigned_image=` (une référence `tag@digest` complète dans le même repository que `$HARDENED_IMAGE`, avec un digest réellement différent).<br/>• **Vérification du checker :** il résout lui-même `unsigned_image` dans le registry, confirme l'absence de signature valide via son propre `cosign verify`, crée SON nouveau Pod avec cette image et exige le validation message unique de sa propre policy : `catalog image must have a valid release signature`.<br/>• Une erreur générique d'admission/signature d'une autre policy ne compte pas comme PASS, ni n'importe quelle erreur d'admission (`manifest unknown`/registry lookup ne suffisent pas).<br/>• Les fichiers d'evidence écrits à la main sans véritable admission control ne donnent pas PASS - le checker ne fait confiance à aucun fichier texte, sauf `unsigned_image=` comme indicateur de l'image réelle à vérifier. |

<details>
<summary>💡 Indice pour la tâche 9c</summary>

L'ordre des preuves ici est important pour leur fiabilité : démontrez d'abord que `$UNSIGNED_IMAGE` EXISTE et est PULLABLE (sinon le denial ultérieur peut être simplement « manifest unknown », et non lié à la signature), puis démontrez l'ABSENCE de signature, et ce n'est qu'APRÈS cela que vous essayez de créer le Pod. Si la comparaison de digest dans `digest-comparison.txt` montre une coïncidence - obtenez une vraie différence de content (par exemple, changez le build-arg `CKS_SIGNATURE_TEST` pour une autre valeur et reconstruisez).
</details>

## Vérification

```bash
check_result
```

La vérification contient `Init` et quatorze tests d'évaluation indépendants (la tâche 9 est divisée en 9a/9b/9c). Elle vérifie le contenu des fichiers et le
JSON, et pas seulement la présence des noms. Les requêtes externes au registry sont nécessaires pour Trivy, SBOM et
Cosign ; si le registry est temporairement indisponible, répétez précisément la commande correspondante.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=111 make delete_cks_task
```
