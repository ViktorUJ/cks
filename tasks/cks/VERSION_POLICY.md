# Политика версий и весов курса CKS

Последняя проверка: **2026-08-31**.

Три версии независимы и не должны автоматически выравниваться:

| Контур | Текущее значение | Источник истины |
|---|---:|---|
| Учебные лаборатории | Kubernetes `v1.36` | `env.hcl` лабораторий и проверенная совместимость инструментов |
| Экзаменационная среда CKS | Kubernetes `v1.34` | LF «Important Instructions: CKS» и FAQ |
| Программа CKS | `CKS Curriculum v1.34` | root-level CKS curriculum PDF в `cncf/curriculum` |

Несовпадение версий само по себе не является дефектом. Перед выпуском курса нужно отдельно:

1. проверить training version во всех лабораториях и compatibility matrix Cilium, Istio,
   Kyverno, Falco и kube-bench;
2. проверить exam version по актуальной странице Linux Foundation;
3. найти актуальный root-level CKS curriculum PDF в `cncf/curriculum`, записать filename,
   размер и SHA-256, затем извлечь из него веса;
4. проверить LF `Resources Allowed` независимо от curriculum и записать дату;
5. обновить prose только по первичным источникам.

Текущие веса доменов: **15 / 15 / 10 / 20 / 20 / 20**. Их нельзя менять из-за drift
версий или вторичной веб-страницы. Триггер пересмотра - появление curriculum PDF новее
`v1.34`; веса меняются только если проценты действительно изменились в новом PDF.

Ссылки:

- [LF Important Instructions: CKS](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks)
- [LF Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)
- [CNCF curriculum repository](https://github.com/cncf/curriculum)
