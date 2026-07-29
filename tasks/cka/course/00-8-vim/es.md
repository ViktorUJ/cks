[Русская версия](ru.md) · [Eng version](README.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md)

# Capítulo 0.8. vim en 15 minutos: sobrevivir y configurarlo para YAML

> **Para quién es este capítulo.** Un mínimo práctico y breve sobre el editor `vim`. En
> los exámenes CKA/CKAD y en los nodos del clúster es el editor por defecto, y lo vas a
> usar constantemente (manifiestos, configuraciones, `/etc/...`). El objetivo no es
> "aprender vim", sino no perder tiempo con él: entrar, editar, guardar, salir y
> configurar bien la sangría para YAML. Si ya trabajas con soltura en vim, sáltate el
> capítulo.

## 0.8.1. Dos modos - lo principal que hay que entender

Toda la confusión del principiante en vim viene de los **modos**. Las teclas hacen cosas
distintas según el modo en el que estés.

```mermaid
flowchart LR
    normal["NORMAL<br>comandos: moverse,<br>borrar, guardar"] -->|"pulsar i"| insert["INSERT<br>escritura normal de texto"]
    insert -->|"pulsar Esc"| normal
    style normal fill:#326ce5,color:#fff
    style insert fill:#0f9d58,color:#fff
```

- **NORMAL** (por defecto al entrar) - las teclas son comandos, no texto.
- **INSERT** - escritura normal de texto; se entra con la tecla `i` y se sale con `Esc`.

Regla de supervivencia: **si algo salió mal, pulsa `Esc`** (vuelves a Normal) y solo
después el comando.

## 0.8.2. Mínimo de comandos para sobrevivir

Con este conjunto basta para el 95% del trabajo en el examen:

| Acción | Teclas (desde el modo Normal) |
|--------|-------------------------------|
| Entrar en edición | `i` |
| Salir de edición | `Esc` |
| Guardar | `:w` + Enter |
| Guardar y salir | `:wq` o `ZZ` |
| Salir sin guardar | `:q!` |
| Deshacer / rehacer | `u` / `Ctrl+r` |
| Borrar línea | `dd` |
| Copiar / pegar línea | `yy` / `p` |
| Al inicio / final del archivo | `gg` / `G` |
| Buscar | `/texto` + Enter (siguiente - `n`) |
| Números de línea | `:set number` |

Abrir un archivo: `vim file.yaml`. Eso es todo. Normalmente no hace falta más en el
examen.

## 0.8.3. Configuración para YAML - obligatoria

El gran problema de vim al trabajar con Kubernetes: **tabuladores en vez de espacios** y
sangrías que "se desplazan". YAML prohíbe los tabuladores (Capítulo 0.6), y vim por
defecto puede insertarlos. Por eso lo primero que se hace en el examen es crear
`~/.vimrc`:

```vim
set expandtab       " Tab inserta espacios, no un tabulador
set tabstop=2       " ancho del tabulador - 2 espacios
set shiftwidth=2    " sangría del autoindentado - 2 espacios
set number          " números de línea
set autoindent      " mantener la sangría en la nueva línea
syntax on           " resaltado de sintaxis
```

Con esta configuración la tecla Tab da dos espacios, y los manifiestos no se rompen en
las sangrías. Configurar `~/.vimrc` conviene hacerlo **lo primero** en el examen (forma
parte de las acciones iniciales del Capítulo 1).

## 0.8.4. La trampa al pegar (paste)

Cuando pegas (con el ratón) un YAML ya listo en vim en modo Insert con `autoindent`
activado, las sangrías **crecen en cascada** - cada línea se desplaza cada vez más a la
derecha. Se soluciona así:

```vim
:set paste      " antes de pegar - desactiva el autoindentado
" ... pegas el texto ...
:set nopaste    " después de pegar - vuelve al modo normal
```

Si ves una "escalera" de sangrías tras pegar, es eso. `:set paste`, deshacer (`u`),
pegar de nuevo.

## 0.8.5. Miniglosario

- **Modo Normal** - el modo de comandos de vim (por defecto); las teclas son comandos.
- **Modo Insert** - el modo de escritura de texto; entrada `i`, salida `Esc`.
- **`:wq` / `:q!`** - guardar y salir / salir sin guardar.
- **`~/.vimrc`** - archivo de configuración de vim (sangrías, números de línea).
- **`expandtab`** - reemplazar el tabulador por espacios (crítico para YAML).
- **`:set paste`** - modo de pegado sin autoindentado (contra la "escalera").

## 0.8.6. Resumen del capítulo

- En vim hay dos modos: Normal (comandos) e Insert (texto); el cambio es `i` y `Esc`. Si
  te pierdes, pulsa `Esc`.
- Mínimo de supervivencia: `i`, `Esc`, `:wq`, `:q!`, `u`, `dd`, `/buscar`, `:set number`.
- Para YAML es obligatorio configurar `~/.vimrc` (`expandtab`, `tabstop=2`,
  `shiftwidth=2`) - de lo contrario los tabuladores romperán los manifiestos.
- Al pegar texto ya listo, usa `:set paste` para que las sangrías no "se desplacen".

## 0.8.7. Para qué sirve: en el examen y en el trabajo real

**En el examen.** El editor es tu herramienta principal durante 2 horas seguidas. Los
minutos perdidos peleándote con vim son tareas sin resolver. Un `~/.vimrc` configurado y
una decena de comandos ahorran tiempo en cada tarea con manifiestos.

**En el trabajo real.** vim está en cualquier nodo Linux sin necesidad de instalarlo -
cuando editas una configuración en un servidor por SSH, a menudo no hay alternativa. El
manejo básico de vim es una habilidad imprescindible para un ingeniero.

## 0.8.8. Preguntas de autoevaluación

1. ¿En qué se diferencia el modo Normal del Insert y cómo se pasa de uno a otro?
2. ¿Cómo se guarda un archivo y se sale? ¿Cómo se sale sin guardar?
3. ¿Por qué para YAML es obligatorio configurar `expandtab` y una sangría de 2 espacios?
4. ¿Qué hacer si tras pegar texto las sangrías "se desplazaron en escalera"?

## Práctica

El capítulo no tiene una práctica aparte: usarás vim en todas las prácticas y exámenes
de simulación posteriores, editando manifiestos. Configura `~/.vimrc` una vez y olvídate
del problema de las sangrías. A continuación empieza el curso principal - el Capítulo 1.

---
[Índice](../README_ES.md) · [Capítulo 0.7](../00-7-netns/es.md) · [Capítulo 1](../01/es.md)
