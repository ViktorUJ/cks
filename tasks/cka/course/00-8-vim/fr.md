[Русская версия](ru.md) · [Eng version](README.md) · [Versión en español](es.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# Chapitre 0.8. vim en 15 minutes : survivre et le régler pour YAML

> **À qui s'adresse ce chapitre.** Un court minimum pratique sur l'éditeur `vim`. Aux
> examens CKA/CKAD et sur les nœuds du cluster, c'est l'éditeur par défaut, et vous
> l'utiliserez en permanence (manifestes, configs, `/etc/...`). L'objectif n'est pas
> d'« apprendre vim », mais de ne pas y perdre de temps : entrer, éditer, sauvegarder,
> sortir et régler correctement les indentations pour YAML. Si vous travaillez déjà avec
> assurance dans vim - passez ce chapitre.

## 0.8.1. Deux modes - l'essentiel à comprendre

Toute la confusion du débutant dans vim vient des **modes**. Les touches font des choses
différentes selon le mode dans lequel vous vous trouvez.

```mermaid
flowchart LR
    normal["NORMAL<br>commandes : déplacement,<br>suppression, sauvegarde"] -->|"appuyer sur i"| insert["INSERT<br>saisie de texte habituelle"]
    insert -->|"appuyer sur Esc"| normal
    style normal fill:#326ce5,color:#fff
    style insert fill:#0f9d58,color:#fff
```

- **NORMAL** (par défaut à l'entrée) - les touches sont des commandes, pas du texte.
- **INSERT** - saisie de texte habituelle ; on y entre avec `i`, on en sort avec `Esc`.

Règle de survie : **si quelque chose ne va pas - appuyez sur `Esc`** (vous revenez en
Normal), puis lancez la commande.

## 0.8.2. Le minimum de commandes pour survivre

Cet ensemble suffit pour 95 % du travail à l'examen :

| Action | Touches (depuis le mode Normal) |
|--------|---------------------------------|
| Entrer en édition | `i` |
| Sortir de l'édition | `Esc` |
| Sauvegarder | `:w` + Enter |
| Sauvegarder et sortir | `:wq` ou `ZZ` |
| Sortir sans sauvegarder | `:q!` |
| Annuler / rétablir | `u` / `Ctrl+r` |
| Supprimer une ligne | `dd` |
| Copier / coller une ligne | `yy` / `p` |
| Au début / à la fin du fichier | `gg` / `G` |
| Recherche | `/texte` + Enter (suivant - `n`) |
| Numéros de ligne | `:set number` |

Ouvrir un fichier : `vim file.yaml`. C'est tout. En général, rien de plus n'est
nécessaire à l'examen.

## 0.8.3. Réglage pour YAML - obligatoire

Le principal problème dans vim lorsqu'on travaille avec Kubernetes : **des tabulations à
la place des espaces** et des indentations qui « dérapent ». YAML interdit les
tabulations (chapitre 0.6), et vim peut en insérer par défaut. C'est pourquoi la
première chose qu'on fait à l'examen, c'est créer `~/.vimrc` :

```vim
set expandtab       " Tab insère des espaces, pas une tabulation
set tabstop=2       " largeur de la tabulation - 2 espaces
set shiftwidth=2    " indentation de l'auto-indent - 2 espaces
set number          " numéros de ligne
set autoindent      " conserver l'indentation sur une nouvelle ligne
syntax on           " coloration syntaxique
```

Avec cette config, la touche Tab donne deux espaces, et les manifestes ne cassent pas sur
les indentations. Le réglage de `~/.vimrc` doit se faire **en tout premier** à l'examen
(cela fait partie des actions de démarrage du chapitre 1).

## 0.8.4. Le piège du collage (paste)

Quand vous collez (à la souris) un YAML tout prêt dans vim en mode Insert avec
`autoindent` activé, les indentations **s'accumulent en cascade** - chaque ligne se
décale de plus en plus vers la droite. On corrige ainsi :

```vim
:set paste      " avant de coller - désactive l'auto-indentation
" ... vous collez le texte ...
:set nopaste    " après le collage - revenir au mode habituel
```

Si vous voyez un « escalier » d'indentations après le collage - c'est ça. `:set paste`,
annuler (`u`), coller à nouveau.

## 0.8.5. Mini-glossaire

- **Mode Normal** - le mode commande de vim (par défaut) ; les touches sont des commandes.
- **Mode Insert** - le mode de saisie de texte ; entrée `i`, sortie `Esc`.
- **`:wq` / `:q!`** - sauvegarder et sortir / sortir sans sauvegarder.
- **`~/.vimrc`** - fichier de configuration de vim (indentations, numéros de ligne).
- **`expandtab`** - remplacer la tabulation par des espaces (critique pour YAML).
- **`:set paste`** - mode de collage sans auto-indentation (contre l'« escalier »).

## 0.8.6. Récapitulatif du chapitre

- Dans vim, il y a deux modes : Normal (commandes) et Insert (texte) ; transition - `i`
  et `Esc`. Perdu - appuyez sur `Esc`.
- Minimum de survie : `i`, `Esc`, `:wq`, `:q!`, `u`, `dd`, `/recherche`, `:set number`.
- Pour YAML, il faut obligatoirement régler `~/.vimrc` (`expandtab`, `tabstop=2`,
  `shiftwidth=2`) - sinon les tabulations casseront les manifestes.
- Lors du collage d'un texte tout prêt, utilisez `:set paste` pour que les indentations
  ne « dérapent » pas.

## 0.8.7. À quoi cela sert : à l'examen et dans le travail réel

**À l'examen.** L'éditeur est votre outil principal 2 heures d'affilée. Les minutes
perdues à batailler avec vim, ce sont des tâches non résolues. Un `~/.vimrc` réglé et une
dizaine de commandes font gagner du temps sur chaque tâche avec manifeste.

**Dans le travail réel.** vim est présent sur n'importe quel nœud Linux sans
installation - quand vous éditez une config sur un serveur en SSH, il n'y a souvent pas
le choix. La maîtrise de base de vim est une compétence obligatoire de l'ingénieur.

## 0.8.8. Questions d'auto-évaluation

1. En quoi le mode Normal diffère-t-il du mode Insert et comment passer de l'un à l'autre ?
2. Comment sauvegarder un fichier et sortir ? Comment sortir sans sauvegarder ?
3. Pourquoi est-il obligatoire, pour YAML, de régler `expandtab` et une indentation de 2 espaces ?
4. Que faire si, après avoir collé un texte, les indentations « dérapent en escalier » ?

## Pratique

Le chapitre n'a pas de TP à part : vous utiliserez vim dans tous les TP et mock-examens
suivants, en éditant des manifestes. Réglez `~/.vimrc` une seule fois - et oubliez le
problème des indentations. Ensuite commence le cours principal - chapitre 1.

---
[Sommaire](../README_FR.md) · [Chapitre 0.7](../00-7-netns/fr.md) · [Chapitre 1](../01/fr.md)
