[Русская версия](ru.md) · [Eng version](README.md) · [Versión en español](es.md) · [Version française](fr.md) · [ქართული ვერსია](ge.md)

# Kapitel 0.8. vim in 15 Minuten: überleben und für YAML einrichten

> **Für wen dieses Kapitel ist.** Ein kurzes praktisches Minimum zum Editor `vim`. In den
> Prüfungen CKA/CKAD und auf den Cluster-Knoten ist er der Standardeditor, und Sie werden
> ständig damit arbeiten (Manifeste, Konfigurationen, `/etc/...`). Das Ziel ist nicht,
> „vim zu lernen“, sondern keine Zeit damit zu verlieren: hineingehen, bearbeiten,
> speichern, verlassen und die Einrückungen korrekt für YAML einstellen. Wenn Sie bereits
> sicher mit vim arbeiten - überspringen Sie das Kapitel.

## 0.8.1. Zwei Modi - das Wichtigste, das man verstehen muss

Die ganze Verwirrung des Anfängers in vim entsteht durch die **Modi**. Die Tasten tun
Unterschiedliches, je nachdem, in welchem Modus Sie sich befinden.

```mermaid
flowchart LR
    normal["NORMAL<br>Befehle: Bewegen,<br>Löschen, Speichern"] -->|"i drücken"| insert["INSERT<br>normales Texttippen"]
    insert -->|"Esc drücken"| normal
    style normal fill:#326ce5,color:#fff
    style insert fill:#0f9d58,color:#fff
```

- **NORMAL** (standardmäßig beim Einstieg) - die Tasten sind Befehle, kein Text.
- **INSERT** - normale Texteingabe; man betritt ihn mit der Taste `i`, verlässt ihn mit
  `Esc`.

Überlebensregel: **wenn etwas schiefgeht - drücken Sie `Esc`** (Sie kehren in den
Normal-Modus zurück) und geben erst danach den Befehl ein.

## 0.8.2. Das Minimum an Befehlen zum Überleben

Dieser Satz reicht für 95 % der Arbeit in der Prüfung:

| Aktion | Tasten (aus dem Normal-Modus) |
|--------|-------------------------------|
| In die Bearbeitung wechseln | `i` |
| Bearbeitung verlassen | `Esc` |
| Speichern | `:w` + Enter |
| Speichern und verlassen | `:wq` oder `ZZ` |
| Ohne Speichern verlassen | `:q!` |
| Rückgängig / wiederherstellen | `u` / `Ctrl+r` |
| Zeile löschen | `dd` |
| Zeile kopieren / einfügen | `yy` / `p` |
| An den Anfang / das Ende der Datei | `gg` / `G` |
| Suchen | `/Text` + Enter (nächstes - `n`) |
| Zeilennummern | `:set number` |

Datei öffnen: `vim file.yaml`. Das ist alles. Mehr braucht man in der Prüfung meist nicht.

## 0.8.3. Einrichtung für YAML - unbedingt notwendig

Das Hauptproblem in vim bei der Arbeit mit Kubernetes: **Tabs statt Leerzeichen** und
„verrutschende“ Einrückungen. YAML verbietet Tabs (Kapitel 0.6), und vim kann sie
standardmäßig einfügen. Deshalb ist das Erste, was man in der Prüfung tut, das Anlegen
einer `~/.vimrc`:

```vim
set expandtab       " Tab fügt Leerzeichen ein, keinen Tab
set tabstop=2       " Breite des Tabs - 2 Leerzeichen
set shiftwidth=2    " Einrückung der Autoindentierung - 2 Leerzeichen
set number          " Zeilennummern
set autoindent      " Einrückung in der neuen Zeile beibehalten
syntax on           " Syntaxhervorhebung
```

Mit dieser Konfiguration ergibt die Tab-Taste zwei Leerzeichen, und die Manifeste
zerbrechen nicht an den Einrückungen. Die Einrichtung der `~/.vimrc` sollte man in der
Prüfung **als Allererstes** vornehmen (das gehört zu den Startaktionen aus Kapitel 1).

## 0.8.4. Die Falle beim Einfügen (paste)

Wenn Sie fertiges YAML (mit der Maus) in vim im Insert-Modus mit aktiviertem
`autoindent` einfügen, wachsen die Einrückungen **kaskadenartig** - jede Zeile
verschiebt sich weiter nach rechts. Das behebt man so:

```vim
:set paste      " vor dem Einfügen - schaltet die Autoindentierung ab
" ... Text einfügen ...
:set nopaste    " nach dem Einfügen - den normalen Modus zurückholen
```

Wenn Sie nach dem Einfügen eine „Treppe“ aus Einrückungen sehen - das ist es. `:set
paste`, rückgängig machen (`u`), erneut einfügen.

## 0.8.5. Mini-Glossar

- **Normal-Modus** - der Befehlsmodus von vim (standardmäßig); die Tasten sind Befehle.
- **Insert-Modus** - der Texteingabemodus; Eintritt `i`, Austritt `Esc`.
- **`:wq` / `:q!`** - speichern und verlassen / ohne Speichern verlassen.
- **`~/.vimrc`** - die Einstellungsdatei von vim (Einrückungen, Zeilennummern).
- **`expandtab`** - Tab durch Leerzeichen ersetzen (kritisch für YAML).
- **`:set paste`** - Einfügemodus ohne Autoindentierung (gegen die „Treppe“).

## 0.8.6. Zusammenfassung des Kapitels

- In vim gibt es zwei Modi: Normal (Befehle) und Insert (Text); der Wechsel - `i` und
  `Esc`. Verwirrt - drücken Sie `Esc`.
- Das Überlebensminimum: `i`, `Esc`, `:wq`, `:q!`, `u`, `dd`, `/Suche`, `:set number`.
- Für YAML muss man unbedingt die `~/.vimrc` einrichten (`expandtab`, `tabstop=2`,
  `shiftwidth=2`) - sonst zerbrechen Tabs die Manifeste.
- Beim Einfügen von fertigem Text nutzen Sie `:set paste`, damit die Einrückungen nicht
  „verrutschen“.

## 0.8.7. Wie das nützt: in der Prüfung und im echten Arbeitsalltag

**In der Prüfung.** Der Editor ist Ihr Hauptwerkzeug 2 Stunden am Stück. Die für das
Herumfummeln mit vim verlorenen Minuten sind ungelöste Aufgaben. Eine eingerichtete
`~/.vimrc` und ein Dutzend Befehle sparen bei jeder Aufgabe mit einem Manifest Zeit.

**Im echten Arbeitsalltag.** vim gibt es auf jedem Linux-Knoten ohne Installation - wenn
man eine Konfiguration auf einem Server über SSH bearbeitet, hat man oft keine Wahl. Die
Grundbeherrschung von vim ist eine Pflichtfähigkeit eines Ingenieurs.

## 0.8.8. Fragen zur Selbstüberprüfung

1. Worin unterscheidet sich der Normal-Modus vom Insert-Modus und wie wechselt man
   zwischen ihnen?
2. Wie speichert man eine Datei und verlässt sie? Wie verlässt man sie ohne Speichern?
3. Warum muss man für YAML unbedingt `expandtab` und eine Einrückung von 2 Leerzeichen
   einrichten?
4. Was tun, wenn nach dem Einfügen von Text die Einrückungen „treppenartig verrutscht“
   sind?

## Praxis

Das Kapitel hat keine eigene Übung: vim werden Sie in allen folgenden Übungen und
Mock-Prüfungen verwenden, während Sie Manifeste bearbeiten. Richten Sie die `~/.vimrc`
einmal ein - und vergessen Sie das Problem mit den Einrückungen. Danach beginnt der
Hauptkurs - Kapitel 1.

---
[Inhalt](../README_DE.md) · [Kapitel 0.7](../00-7-netns/de.md) · [Kapitel 1](../01/de.md)
