## vim

When you take exams you need to edit a lot of manifests.
The Vim editor is used by default, which means you should be aware how to use shortcuts.

`G`  - go to end of file

`gg` - first line of file

`Shift + A` - go to the end of the current row (insert mode)

`Shift + C` - delete everything after the cursor (insert mode)

`Shift + I` - go to the first letter on the current row (insert mode)

`/Pod` - find any instances of `Pod` in the file

`e` - jump to the end of the next word

`w` - jump to the start of the next word

`:25` - go to the 25th row in the file

## aliases

`export do="--dry-run=client -o yaml" `
````
# usage fo create pod template

k run  test --image nginx $do
````
