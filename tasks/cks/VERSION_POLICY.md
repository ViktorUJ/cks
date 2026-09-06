# Политика версий и весов курса CKS

Последняя проверка: **2026-09-06**.

Три версии независимы и не должны автоматически выравниваться:

| Контур | Текущее значение | Источник истины |
|---|---:|---|
| Учебные лаборатории (core, `labs/101-112`) | Kubernetes `v1.36` | `env.hcl` core labs, проверенная совместимость инструментов |
| Учебные лаборатории (legacy, `labs/01-30`) | Kubernetes `v1.28-v1.34` (разброс, не единая версия) | `env.hcl` каждой legacy лабы; сохраняют исторические exam-pattern стенды |
| Экзаменационная среда CKS | Kubernetes `v1.35` | LF CKS product page + LF «Important Instructions: CKS» + LF FAQ (сверено 2026-09-06, все три источника согласованно указывают v1.35) |
| Программа CKS | `CKS Curriculum v1.34` | root-level CKS curriculum PDF в `cncf/curriculum` |

Разделение core/legacy labs важно: не все `env.hcl` в `labs/01-30` обновлены до training
baseline v1.36 - механическое обновление только даты проверки без реальной проверки
`env.hcl` может закрепить неверное состояние в prose.

Несовпадение версий само по себе не является дефектом. Перед выпуском курса нужно отдельно:

1. проверить training version во всех лабораториях и compatibility matrix Cilium, Istio,
   Kyverno, Falco и kube-bench;
2. проверить exam version минимум по основной странице CKS, «Important Instructions: CKS»
   и LF FAQ; если официальные источники расходятся, зафиксировать все значения и не
   объявлять одно из них согласованным source of truth; непосредственно перед попыткой
   дополнительно сверить ExamUI;
3. найти актуальный root-level CKS curriculum PDF в `cncf/curriculum`, записать filename,
   размер и SHA-256, затем извлечь из него веса;
4. проверить LF `Resources Allowed` независимо от curriculum и записать дату;
5. обновить prose только по первичным источникам.

### Политика весов доменов

Веса экзамена не привязываются автоматически к версии Kubernetes и не считаются
согласованными только потому, что не менялись давно.

Для release snapshot отдельно фиксируются два независимых сигнала:

1. веса, опубликованные на LF CKS product page;
2. веса из актуального root-level CKS curriculum PDF в `cncf/curriculum`.

Если значения совпадают - snapshot считается согласованным, а текущие веса
**15 / 15 / 10 / 20 / 20 / 20** остаются в силе.

Если значения расходятся:

- оба набора сохраняются в `metadata/cks-exam-snapshot.yaml` как отдельные наблюдения;
- расхождение блокирует объявление весов «согласованными» в prose курса, но не блокирует
  само использование курса;
- maintainer вручную проверяет LF product page, актуальный curriculum PDF и, где возможно,
  Candidate Handbook/ExamUI перед тем как менять веса в тексте глав;
- prose не объявляет один из двух наборов «истиной», пока расхождение не разрешено через
  первичный источник.

Это отличается от прежнего правила «менять веса только после появления PDF новее v1.34»:
CNCF curriculum filename может отставать от LF product page или наоборот, поэтому
привязка к одному каналу (только PDF) может пропустить реальное изменение весов на
product page. Оба канала проверяются и фиксируются независимо.

Ссылки:

- [LF Important Instructions: CKS](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cks)
- [LF Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)
- [CNCF curriculum repository](https://github.com/cncf/curriculum)
