# Implementation Plan: статическая локализация ICA course и labs

## Overview

Инвентаризация `tasks/ica/course/` и `tasks/ica/labs/` зафиксировала статический объём этого плана:

- индекс курса, все 32 главы `01`…`32` и все 35 README лабораторий `01`…`35` содержат ровно варианты RU, EN, ES, FR и DE;
- у каждого из этих 68 логических артефактов отсутствуют только обязательные GE, TW и JP: **204** выходных Markdown-файла;
- рекурсивная инвентаризация всех `tasks/ica/labs/*/worker/files/solutions/` выявила 35 пользовательских содержательных Markdown-файлов: по одному английскому `1.MD` в лабораториях `01`…`35`. Английский исходник сохраняется без изменения. Для каждого нормативны соседние варианты `1_RU.MD`, `1_ES.MD`, `1_FR.MD`, `1_DE.MD`, `1_GE.MD`, `1_TW.MD`, `1_JP.MD`: **245** выходных Markdown-файлов;
- общий объём создания составляет **449** файлов для 103 логических артефактов. `worker/files/solutions/1.MD` является `Lab_Solution_File`, а не служебным файлом;
- фактические `Lab_Reference` в курсе: `02 → 01,15`; `04 → 01`; `05 → 02`; `11 → 16`; `13 → 04,20`; `18 → 18`; `22 → 09,24`. README лабораторий не содержат `Chapter_Reference`; ссылка README лаборатории `35` на `worker/files/solutions/1.MD` является `Solution_Reference` и после создания вариантов должна вести на решение той же Locale.

Во всех задачах решений источник `1.MD` остаётся неизменным. Переводятся только пользовательские тексты; команды, флаги, YAML/JSON/HCL, идентификаторы, URL, пути, исполняемые fenced-code blocks, Mermaid node IDs и style сохраняются. В Mermaid переводятся только display labels. Символ `—` не используется.

Каждая задача перевода ниже создаёт ровно один явно указанный output path. Агент изменяет **только** этот output path; источники, существующие варианты других языков, `worker/`, инфраструктура и служебные файлы не входят в его write-scope. Для EN/ES/FR/DE/TW/JP используется `gpt-5.6-terra`; для GE — `gpt-5.6-sol`.

Во всех задачах перевода: переводить только пользовательский текст; не переводить и не менять команды, флаги, YAML/JSON/HCL, имена полей, идентификаторы, URL, пути, исполняемые fenced-code blocks, Mermaid node IDs и style. В Mermaid допускается перевод только display labels. Не использовать символ `—`. Новые файлы сначала содержат первую строку `Language_Switcher` без self-ссылки; окончательную строку во всех вариантах формирует только фаза reconciliation.

## Tasks

- [x] 1. Создать отсутствующие варианты индекса курса
  - [x] 1.1 Создать `tasks/ica/course/README_GE.md` из `tasks/ica/course/README_RU.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); агент владеет только `README_GE.md`.
    - _Requirements: 2.1-2.3, 2.6, 3.2-3.5, 7.5, 9.2_
  - [x] 1.2 Создать `tasks/ica/course/README_TW.md` из `tasks/ica/course/README_RU.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); агент владеет только `README_TW.md`.
    - _Requirements: 2.1-2.3, 2.6, 3.2-3.5, 7.5, 9.2_
  - [x] 1.3 Создать `tasks/ica/course/README_JP.md` из `tasks/ica/course/README_RU.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); агент владеет только `README_JP.md`.
    - _Requirements: 2.1-2.3, 2.6, 3.2-3.5, 7.5, 9.2_

- [x] 2. Создать отсутствующие варианты главы `01`
  - [x] 2.1 Создать `tasks/ica/course/01/ge.md` из `tasks/ica/course/01/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); агент владеет только `ge.md`.
  - [x] 2.2 Создать `tasks/ica/course/01/tw.md` из `tasks/ica/course/01/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); агент владеет только `tw.md`.
  - [x] 2.3 Создать `tasks/ica/course/01/jp.md` из `tasks/ica/course/01/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); агент владеет только `jp.md`.
    - _Requirements: 2.1-2.3, 2.6, 3.1, 3.3-3.7, 7.5, 9.2_
- [x] 3. Создать отсутствующие варианты главы `02`
  - [x] 3.1 Создать `tasks/ica/course/02/ge.md` из `tasks/ica/course/02/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 3.2 Создать `tasks/ica/course/02/tw.md` из `tasks/ica/course/02/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 3.3 Создать `tasks/ica/course/02/jp.md` из `tasks/ica/course/02/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
    - _Requirements: 2.1-2.3, 2.6, 3.1, 3.3-3.7, 7.5, 9.2_
- [x] 4. Создать отсутствующие варианты главы `03`
  - [x] 4.1 Создать `tasks/ica/course/03/ge.md` из `tasks/ica/course/03/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 4.2 Создать `tasks/ica/course/03/tw.md` из `tasks/ica/course/03/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 4.3 Создать `tasks/ica/course/03/jp.md` из `tasks/ica/course/03/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 5. Создать отсутствующие варианты главы `04`
  - [x] 5.1 Создать `tasks/ica/course/04/ge.md` из `tasks/ica/course/04/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 5.2 Создать `tasks/ica/course/04/tw.md` из `tasks/ica/course/04/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 5.3 Создать `tasks/ica/course/04/jp.md` из `tasks/ica/course/04/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 6. Создать отсутствующие варианты главы `05`
  - [x] 6.1 Создать `tasks/ica/course/05/ge.md` из `tasks/ica/course/05/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 6.2 Создать `tasks/ica/course/05/tw.md` из `tasks/ica/course/05/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 6.3 Создать `tasks/ica/course/05/jp.md` из `tasks/ica/course/05/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 7. Создать отсутствующие варианты главы `06`
  - [x] 7.1 Создать `tasks/ica/course/06/ge.md` из `tasks/ica/course/06/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 7.2 Создать `tasks/ica/course/06/tw.md` из `tasks/ica/course/06/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 7.3 Создать `tasks/ica/course/06/jp.md` из `tasks/ica/course/06/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 8. Создать отсутствующие варианты главы `07`
  - [x] 8.1 Создать `tasks/ica/course/07/ge.md` из `tasks/ica/course/07/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 8.2 Создать `tasks/ica/course/07/tw.md` из `tasks/ica/course/07/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 8.3 Создать `tasks/ica/course/07/jp.md` из `tasks/ica/course/07/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 9. Создать отсутствующие варианты главы `08`
  - [x] 9.1 Создать `tasks/ica/course/08/ge.md` из `tasks/ica/course/08/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 9.2 Создать `tasks/ica/course/08/tw.md` из `tasks/ica/course/08/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 9.3 Создать `tasks/ica/course/08/jp.md` из `tasks/ica/course/08/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 10. Создать отсутствующие варианты главы `09`
  - [x] 10.1 Создать `tasks/ica/course/09/ge.md` из `tasks/ica/course/09/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 10.2 Создать `tasks/ica/course/09/tw.md` из `tasks/ica/course/09/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 10.3 Создать `tasks/ica/course/09/jp.md` из `tasks/ica/course/09/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 11. Создать отсутствующие варианты главы `10`
  - [x] 11.1 Создать `tasks/ica/course/10/ge.md` из `tasks/ica/course/10/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 11.2 Создать `tasks/ica/course/10/tw.md` из `tasks/ica/course/10/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 11.3 Создать `tasks/ica/course/10/jp.md` из `tasks/ica/course/10/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 12. Создать отсутствующие варианты главы `11`
  - [x] 12.1 Создать `tasks/ica/course/11/ge.md` из `tasks/ica/course/11/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 12.2 Создать `tasks/ica/course/11/tw.md` из `tasks/ica/course/11/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 12.3 Создать `tasks/ica/course/11/jp.md` из `tasks/ica/course/11/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 13. Создать отсутствующие варианты главы `12`
  - [x] 13.1 Создать `tasks/ica/course/12/ge.md` из `tasks/ica/course/12/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 13.2 Создать `tasks/ica/course/12/tw.md` из `tasks/ica/course/12/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 13.3 Создать `tasks/ica/course/12/jp.md` из `tasks/ica/course/12/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 14. Создать отсутствующие варианты главы `13`
  - [x] 14.1 Создать `tasks/ica/course/13/ge.md` из `tasks/ica/course/13/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 14.2 Создать `tasks/ica/course/13/tw.md` из `tasks/ica/course/13/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 14.3 Создать `tasks/ica/course/13/jp.md` из `tasks/ica/course/13/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 15. Создать отсутствующие варианты главы `14`
  - [x] 15.1 Создать `tasks/ica/course/14/ge.md` из `tasks/ica/course/14/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 15.2 Создать `tasks/ica/course/14/tw.md` из `tasks/ica/course/14/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 15.3 Создать `tasks/ica/course/14/jp.md` из `tasks/ica/course/14/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 16. Создать отсутствующие варианты главы `15`
  - [x] 16.1 Создать `tasks/ica/course/15/ge.md` из `tasks/ica/course/15/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 16.2 Создать `tasks/ica/course/15/tw.md` из `tasks/ica/course/15/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 16.3 Создать `tasks/ica/course/15/jp.md` из `tasks/ica/course/15/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 17. Создать отсутствующие варианты главы `16`
  - [x] 17.1 Создать `tasks/ica/course/16/ge.md` из `tasks/ica/course/16/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 17.2 Создать `tasks/ica/course/16/tw.md` из `tasks/ica/course/16/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 17.3 Создать `tasks/ica/course/16/jp.md` из `tasks/ica/course/16/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 18. Создать отсутствующие варианты главы `17`
  - [x] 18.1 Создать `tasks/ica/course/17/ge.md` из `tasks/ica/course/17/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 18.2 Создать `tasks/ica/course/17/tw.md` из `tasks/ica/course/17/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 18.3 Создать `tasks/ica/course/17/jp.md` из `tasks/ica/course/17/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 19. Создать отсутствующие варианты главы `18`
  - [x] 19.1 Создать `tasks/ica/course/18/ge.md` из `tasks/ica/course/18/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 19.2 Создать `tasks/ica/course/18/tw.md` из `tasks/ica/course/18/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 19.3 Создать `tasks/ica/course/18/jp.md` из `tasks/ica/course/18/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 20. Создать отсутствующие варианты главы `19`
  - [x] 20.1 Создать `tasks/ica/course/19/ge.md` из `tasks/ica/course/19/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 20.2 Создать `tasks/ica/course/19/tw.md` из `tasks/ica/course/19/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 20.3 Создать `tasks/ica/course/19/jp.md` из `tasks/ica/course/19/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 21. Создать отсутствующие варианты главы `20`
  - [x] 21.1 Создать `tasks/ica/course/20/ge.md` из `tasks/ica/course/20/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 21.2 Создать `tasks/ica/course/20/tw.md` из `tasks/ica/course/20/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 21.3 Создать `tasks/ica/course/20/jp.md` из `tasks/ica/course/20/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 22. Создать отсутствующие варианты главы `21`
  - [x] 22.1 Создать `tasks/ica/course/21/ge.md` из `tasks/ica/course/21/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 22.2 Создать `tasks/ica/course/21/tw.md` из `tasks/ica/course/21/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 22.3 Создать `tasks/ica/course/21/jp.md` из `tasks/ica/course/21/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 23. Создать отсутствующие варианты главы `22`
  - [x] 23.1 Создать `tasks/ica/course/22/ge.md` из `tasks/ica/course/22/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 23.2 Создать `tasks/ica/course/22/tw.md` из `tasks/ica/course/22/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 23.3 Создать `tasks/ica/course/22/jp.md` из `tasks/ica/course/22/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 24. Создать отсутствующие варианты главы `23`
  - [x] 24.1 Создать `tasks/ica/course/23/ge.md` из `tasks/ica/course/23/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 24.2 Создать `tasks/ica/course/23/tw.md` из `tasks/ica/course/23/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 24.3 Создать `tasks/ica/course/23/jp.md` из `tasks/ica/course/23/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 25. Создать отсутствующие варианты главы `24`
  - [x] 25.1 Создать `tasks/ica/course/24/ge.md` из `tasks/ica/course/24/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 25.2 Создать `tasks/ica/course/24/tw.md` из `tasks/ica/course/24/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 25.3 Создать `tasks/ica/course/24/jp.md` из `tasks/ica/course/24/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 26. Создать отсутствующие варианты главы `25`
  - [x] 26.1 Создать `tasks/ica/course/25/ge.md` из `tasks/ica/course/25/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 26.2 Создать `tasks/ica/course/25/tw.md` из `tasks/ica/course/25/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 26.3 Создать `tasks/ica/course/25/jp.md` из `tasks/ica/course/25/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 27. Создать отсутствующие варианты главы `26`
  - [x] 27.1 Создать `tasks/ica/course/26/ge.md` из `tasks/ica/course/26/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 27.2 Создать `tasks/ica/course/26/tw.md` из `tasks/ica/course/26/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 27.3 Создать `tasks/ica/course/26/jp.md` из `tasks/ica/course/26/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 28. Создать отсутствующие варианты главы `27`
  - [x] 28.1 Создать `tasks/ica/course/27/ge.md` из `tasks/ica/course/27/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 28.2 Создать `tasks/ica/course/27/tw.md` из `tasks/ica/course/27/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 28.3 Создать `tasks/ica/course/27/jp.md` из `tasks/ica/course/27/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 29. Создать отсутствующие варианты главы `28`
  - [x] 29.1 Создать `tasks/ica/course/28/ge.md` из `tasks/ica/course/28/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 29.2 Создать `tasks/ica/course/28/tw.md` из `tasks/ica/course/28/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 29.3 Создать `tasks/ica/course/28/jp.md` из `tasks/ica/course/28/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 30. Создать отсутствующие варианты главы `29`
  - [x] 30.1 Создать `tasks/ica/course/29/ge.md` из `tasks/ica/course/29/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 30.2 Создать `tasks/ica/course/29/tw.md` из `tasks/ica/course/29/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 30.3 Создать `tasks/ica/course/29/jp.md` из `tasks/ica/course/29/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 31. Создать отсутствующие варианты главы `30`
  - [x] 31.1 Создать `tasks/ica/course/30/ge.md` из `tasks/ica/course/30/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 31.2 Создать `tasks/ica/course/30/tw.md` из `tasks/ica/course/30/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 31.3 Создать `tasks/ica/course/30/jp.md` из `tasks/ica/course/30/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 32. Создать отсутствующие варианты главы `31`
  - [x] 32.1 Создать `tasks/ica/course/31/ge.md` из `tasks/ica/course/31/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 32.2 Создать `tasks/ica/course/31/tw.md` из `tasks/ica/course/31/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 32.3 Создать `tasks/ica/course/31/jp.md` из `tasks/ica/course/31/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
- [x] 33. Создать отсутствующие варианты главы `32`
  - [x] 33.1 Создать `tasks/ica/course/32/ge.md` из `tasks/ica/course/32/ru.md` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `ge.md`.
  - [x] 33.2 Создать `tasks/ica/course/32/tw.md` из `tasks/ica/course/32/ru.md` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `tw.md`.
  - [x] 33.3 Создать `tasks/ica/course/32/jp.md` из `tasks/ica/course/32/ru.md` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `jp.md`.
    - _Requirements для задач 3-33: 2.1-2.3, 2.6, 3.1, 3.3-3.7, 7.3, 7.5, 8.1-8.2, 9.2-9.3_

- [x] 34. Создать отсутствующие варианты README лабораторной работы `01`
  - [x] 34.1 Создать `tasks/ica/labs/01/README_GE.MD` из `tasks/ica/labs/01/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 34.2 Создать `tasks/ica/labs/01/README_TW.MD` из `tasks/ica/labs/01/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 34.3 Создать `tasks/ica/labs/01/README_JP.MD` из `tasks/ica/labs/01/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
    - _Requirements: 2.1-2.3, 2.6, 4.1, 4.3-4.7, 7.5, 9.2_
- [x] 35. Создать отсутствующие варианты README лабораторной работы `02`
  - [x] 35.1 Создать `tasks/ica/labs/02/README_GE.MD` из `tasks/ica/labs/02/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 35.2 Создать `tasks/ica/labs/02/README_TW.MD` из `tasks/ica/labs/02/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 35.3 Создать `tasks/ica/labs/02/README_JP.MD` из `tasks/ica/labs/02/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 36. Создать отсутствующие варианты README лабораторной работы `03`
  - [x] 36.1 Создать `tasks/ica/labs/03/README_GE.MD` из `tasks/ica/labs/03/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 36.2 Создать `tasks/ica/labs/03/README_TW.MD` из `tasks/ica/labs/03/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 36.3 Создать `tasks/ica/labs/03/README_JP.MD` из `tasks/ica/labs/03/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 37. Создать отсутствующие варианты README лабораторной работы `04`
  - [x] 37.1 Создать `tasks/ica/labs/04/README_GE.MD` из `tasks/ica/labs/04/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 37.2 Создать `tasks/ica/labs/04/README_TW.MD` из `tasks/ica/labs/04/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 37.3 Создать `tasks/ica/labs/04/README_JP.MD` из `tasks/ica/labs/04/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 38. Создать отсутствующие варианты README лабораторной работы `05`
  - [x] 38.1 Создать `tasks/ica/labs/05/README_GE.MD` из `tasks/ica/labs/05/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 38.2 Создать `tasks/ica/labs/05/README_TW.MD` из `tasks/ica/labs/05/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 38.3 Создать `tasks/ica/labs/05/README_JP.MD` из `tasks/ica/labs/05/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 39. Создать отсутствующие варианты README лабораторной работы `06`
  - [x] 39.1 Создать `tasks/ica/labs/06/README_GE.MD` из `tasks/ica/labs/06/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 39.2 Создать `tasks/ica/labs/06/README_TW.MD` из `tasks/ica/labs/06/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 39.3 Создать `tasks/ica/labs/06/README_JP.MD` из `tasks/ica/labs/06/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 40. Создать отсутствующие варианты README лабораторной работы `07`
  - [x] 40.1 Создать `tasks/ica/labs/07/README_GE.MD` из `tasks/ica/labs/07/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 40.2 Создать `tasks/ica/labs/07/README_TW.MD` из `tasks/ica/labs/07/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 40.3 Создать `tasks/ica/labs/07/README_JP.MD` из `tasks/ica/labs/07/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 41. Создать отсутствующие варианты README лабораторной работы `08`
  - [x] 41.1 Создать `tasks/ica/labs/08/README_GE.MD` из `tasks/ica/labs/08/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 41.2 Создать `tasks/ica/labs/08/README_TW.MD` из `tasks/ica/labs/08/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 41.3 Создать `tasks/ica/labs/08/README_JP.MD` из `tasks/ica/labs/08/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 42. Создать отсутствующие варианты README лабораторной работы `09`
  - [x] 42.1 Создать `tasks/ica/labs/09/README_GE.MD` из `tasks/ica/labs/09/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 42.2 Создать `tasks/ica/labs/09/README_TW.MD` из `tasks/ica/labs/09/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 42.3 Создать `tasks/ica/labs/09/README_JP.MD` из `tasks/ica/labs/09/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 43. Создать отсутствующие варианты README лабораторной работы `10`
  - [x] 43.1 Создать `tasks/ica/labs/10/README_GE.MD` из `tasks/ica/labs/10/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 43.2 Создать `tasks/ica/labs/10/README_TW.MD` из `tasks/ica/labs/10/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 43.3 Создать `tasks/ica/labs/10/README_JP.MD` из `tasks/ica/labs/10/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 44. Создать отсутствующие варианты README лабораторной работы `11`
  - [x] 44.1 Создать `tasks/ica/labs/11/README_GE.MD` из `tasks/ica/labs/11/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 44.2 Создать `tasks/ica/labs/11/README_TW.MD` из `tasks/ica/labs/11/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 44.3 Создать `tasks/ica/labs/11/README_JP.MD` из `tasks/ica/labs/11/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 45. Создать отсутствующие варианты README лабораторной работы `12`
  - [x] 45.1 Создать `tasks/ica/labs/12/README_GE.MD` из `tasks/ica/labs/12/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 45.2 Создать `tasks/ica/labs/12/README_TW.MD` из `tasks/ica/labs/12/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 45.3 Создать `tasks/ica/labs/12/README_JP.MD` из `tasks/ica/labs/12/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 46. Создать отсутствующие варианты README лабораторной работы `13`
  - [x] 46.1 Создать `tasks/ica/labs/13/README_GE.MD` из `tasks/ica/labs/13/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 46.2 Создать `tasks/ica/labs/13/README_TW.MD` из `tasks/ica/labs/13/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 46.3 Создать `tasks/ica/labs/13/README_JP.MD` из `tasks/ica/labs/13/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 47. Создать отсутствующие варианты README лабораторной работы `14`
  - [x] 47.1 Создать `tasks/ica/labs/14/README_GE.MD` из `tasks/ica/labs/14/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 47.2 Создать `tasks/ica/labs/14/README_TW.MD` из `tasks/ica/labs/14/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 47.3 Создать `tasks/ica/labs/14/README_JP.MD` из `tasks/ica/labs/14/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 48. Создать отсутствующие варианты README лабораторной работы `15`
  - [x] 48.1 Создать `tasks/ica/labs/15/README_GE.MD` из `tasks/ica/labs/15/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 48.2 Создать `tasks/ica/labs/15/README_TW.MD` из `tasks/ica/labs/15/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 48.3 Создать `tasks/ica/labs/15/README_JP.MD` из `tasks/ica/labs/15/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 49. Создать отсутствующие варианты README лабораторной работы `16`
  - [x] 49.1 Создать `tasks/ica/labs/16/README_GE.MD` из `tasks/ica/labs/16/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 49.2 Создать `tasks/ica/labs/16/README_TW.MD` из `tasks/ica/labs/16/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 49.3 Создать `tasks/ica/labs/16/README_JP.MD` из `tasks/ica/labs/16/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 50. Создать отсутствующие варианты README лабораторной работы `17`
  - [x] 50.1 Создать `tasks/ica/labs/17/README_GE.MD` из `tasks/ica/labs/17/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 50.2 Создать `tasks/ica/labs/17/README_TW.MD` из `tasks/ica/labs/17/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 50.3 Создать `tasks/ica/labs/17/README_JP.MD` из `tasks/ica/labs/17/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 51. Создать отсутствующие варианты README лабораторной работы `18`
  - [x] 51.1 Создать `tasks/ica/labs/18/README_GE.MD` из `tasks/ica/labs/18/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 51.2 Создать `tasks/ica/labs/18/README_TW.MD` из `tasks/ica/labs/18/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 51.3 Создать `tasks/ica/labs/18/README_JP.MD` из `tasks/ica/labs/18/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 52. Создать отсутствующие варианты README лабораторной работы `19`
  - [x] 52.1 Создать `tasks/ica/labs/19/README_GE.MD` из `tasks/ica/labs/19/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 52.2 Создать `tasks/ica/labs/19/README_TW.MD` из `tasks/ica/labs/19/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 52.3 Создать `tasks/ica/labs/19/README_JP.MD` из `tasks/ica/labs/19/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 53. Создать отсутствующие варианты README лабораторной работы `20`
  - [x] 53.1 Создать `tasks/ica/labs/20/README_GE.MD` из `tasks/ica/labs/20/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 53.2 Создать `tasks/ica/labs/20/README_TW.MD` из `tasks/ica/labs/20/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 53.3 Создать `tasks/ica/labs/20/README_JP.MD` из `tasks/ica/labs/20/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 54. Создать отсутствующие варианты README лабораторной работы `21`
  - [x] 54.1 Создать `tasks/ica/labs/21/README_GE.MD` из `tasks/ica/labs/21/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 54.2 Создать `tasks/ica/labs/21/README_TW.MD` из `tasks/ica/labs/21/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 54.3 Создать `tasks/ica/labs/21/README_JP.MD` из `tasks/ica/labs/21/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 55. Создать отсутствующие варианты README лабораторной работы `22`
  - [x] 55.1 Создать `tasks/ica/labs/22/README_GE.MD` из `tasks/ica/labs/22/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 55.2 Создать `tasks/ica/labs/22/README_TW.MD` из `tasks/ica/labs/22/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 55.3 Создать `tasks/ica/labs/22/README_JP.MD` из `tasks/ica/labs/22/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 56. Создать отсутствующие варианты README лабораторной работы `23`
  - [x] 56.1 Создать `tasks/ica/labs/23/README_GE.MD` из `tasks/ica/labs/23/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 56.2 Создать `tasks/ica/labs/23/README_TW.MD` из `tasks/ica/labs/23/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 56.3 Создать `tasks/ica/labs/23/README_JP.MD` из `tasks/ica/labs/23/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 57. Создать отсутствующие варианты README лабораторной работы `24`
  - [x] 57.1 Создать `tasks/ica/labs/24/README_GE.MD` из `tasks/ica/labs/24/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 57.2 Создать `tasks/ica/labs/24/README_TW.MD` из `tasks/ica/labs/24/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 57.3 Создать `tasks/ica/labs/24/README_JP.MD` из `tasks/ica/labs/24/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 58. Создать отсутствующие варианты README лабораторной работы `25`
  - [x] 58.1 Создать `tasks/ica/labs/25/README_GE.MD` из `tasks/ica/labs/25/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 58.2 Создать `tasks/ica/labs/25/README_TW.MD` из `tasks/ica/labs/25/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 58.3 Создать `tasks/ica/labs/25/README_JP.MD` из `tasks/ica/labs/25/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 59. Создать отсутствующие варианты README лабораторной работы `26`
  - [x] 59.1 Создать `tasks/ica/labs/26/README_GE.MD` из `tasks/ica/labs/26/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 59.2 Создать `tasks/ica/labs/26/README_TW.MD` из `tasks/ica/labs/26/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 59.3 Создать `tasks/ica/labs/26/README_JP.MD` из `tasks/ica/labs/26/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 60. Создать отсутствующие варианты README лабораторной работы `27`
  - [x] 60.1 Создать `tasks/ica/labs/27/README_GE.MD` из `tasks/ica/labs/27/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 60.2 Создать `tasks/ica/labs/27/README_TW.MD` из `tasks/ica/labs/27/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 60.3 Создать `tasks/ica/labs/27/README_JP.MD` из `tasks/ica/labs/27/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 61. Создать отсутствующие варианты README лабораторной работы `28`
  - [x] 61.1 Создать `tasks/ica/labs/28/README_GE.MD` из `tasks/ica/labs/28/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 61.2 Создать `tasks/ica/labs/28/README_TW.MD` из `tasks/ica/labs/28/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 61.3 Создать `tasks/ica/labs/28/README_JP.MD` из `tasks/ica/labs/28/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 62. Создать отсутствующие варианты README лабораторной работы `29`
  - [x] 62.1 Создать `tasks/ica/labs/29/README_GE.MD` из `tasks/ica/labs/29/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 62.2 Создать `tasks/ica/labs/29/README_TW.MD` из `tasks/ica/labs/29/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 62.3 Создать `tasks/ica/labs/29/README_JP.MD` из `tasks/ica/labs/29/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 63. Создать отсутствующие варианты README лабораторной работы `30`
  - [x] 63.1 Создать `tasks/ica/labs/30/README_GE.MD` из `tasks/ica/labs/30/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 63.2 Создать `tasks/ica/labs/30/README_TW.MD` из `tasks/ica/labs/30/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 63.3 Создать `tasks/ica/labs/30/README_JP.MD` из `tasks/ica/labs/30/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 64. Создать отсутствующие варианты README лабораторной работы `31`
  - [x] 64.1 Создать `tasks/ica/labs/31/README_GE.MD` из `tasks/ica/labs/31/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 64.2 Создать `tasks/ica/labs/31/README_TW.MD` из `tasks/ica/labs/31/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 64.3 Создать `tasks/ica/labs/31/README_JP.MD` из `tasks/ica/labs/31/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 65. Создать отсутствующие варианты README лабораторной работы `32`
  - [x] 65.1 Создать `tasks/ica/labs/32/README_GE.MD` из `tasks/ica/labs/32/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 65.2 Создать `tasks/ica/labs/32/README_TW.MD` из `tasks/ica/labs/32/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 65.3 Создать `tasks/ica/labs/32/README_JP.MD` из `tasks/ica/labs/32/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 66. Создать отсутствующие варианты README лабораторной работы `33`
  - [x] 66.1 Создать `tasks/ica/labs/33/README_GE.MD` из `tasks/ica/labs/33/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 66.2 Создать `tasks/ica/labs/33/README_TW.MD` из `tasks/ica/labs/33/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 66.3 Создать `tasks/ica/labs/33/README_JP.MD` из `tasks/ica/labs/33/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 67. Создать отсутствующие варианты README лабораторной работы `34`
  - [x] 67.1 Создать `tasks/ica/labs/34/README_GE.MD` из `tasks/ica/labs/34/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 67.2 Создать `tasks/ica/labs/34/README_TW.MD` из `tasks/ica/labs/34/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 67.3 Создать `tasks/ica/labs/34/README_JP.MD` из `tasks/ica/labs/34/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
- [x] 68. Создать отсутствующие варианты README лабораторной работы `35`
  - [x] 68.1 Создать `tasks/ica/labs/35/README_GE.MD` из `tasks/ica/labs/35/README_RU.MD` на GE через `eks-translation-ge` (`gpt-5.6-sol`); только `README_GE.MD`.
  - [x] 68.2 Создать `tasks/ica/labs/35/README_TW.MD` из `tasks/ica/labs/35/README_RU.MD` на TW через `eks-translation-tw` (`gpt-5.6-terra`); только `README_TW.MD`.
  - [x] 68.3 Создать `tasks/ica/labs/35/README_JP.MD` из `tasks/ica/labs/35/README_RU.MD` на JP через `eks-translation-jp` (`gpt-5.6-terra`); только `README_JP.MD`.
    - _Requirements для задач 35-68: 2.1-2.3, 2.6, 4.1, 4.3-4.7, 7.3, 7.5, 8.1-8.2, 9.2-9.3_

- [x] 69. Выполнить обязательный `Self_Check_Process` до reconciliation
  - [x] 69.1 Проверить индекс и главы `01`…`08`: для каждого из восьми вариантов сверить с RU порядок heading levels, количество и порядок fenced-code blocks, таблиц, Mermaid/diagram blocks и Markdown-ссылок; проверить сохранность Technical_Artifact, первую строку, отсутствие `—` и write-scope каждого агента по изменённым путям.
    - _Requirements: 3.3-3.5, 8.1-8.2, 8.7, 9.2-9.4_
  - [x] 69.2 Проверить главы `09`…`16` по тем же детерминированным правилам.
  - [x] 69.3 Проверить главы `17`…`24` по тем же детерминированным правилам.
  - [x] 69.4 Проверить главы `25`…`32` по тем же детерминированным правилам.
  - [x] 69.5 Проверить README лабораторий `01`…`09`: структурные счётчики, неизменность Technical_Artifact и ровно один созданный output path на агента.
  - [x] 69.6 Проверить README лабораторий `10`…`18` по тем же правилам.
  - [x] 69.7 Проверить README лабораторий `19`…`27` по тем же правилам.
  - [x] 69.8 Проверить README лабораторий `28`…`35` по тем же правилам. `worker/files/solutions/1.MD` лаборатории `35` является пользовательским `Lab_Solution_File`; его локализация и проверка выполняются отдельными dispatch-волнами ниже.
    - _Requirements: 4.3-4.7, 8.1-8.2, 8.7, 9.2-9.4_

- [x] 70. Детерминированно согласовать `Language_Switcher` во всех восьми вариантах
  - [x] 70.1 Перестроить первую строку `tasks/ica/course/README_RU.md`, `README.md`, `README_ES.md`, `README_FR.md`, `README_DE.md`, `README_GE.md`, `README_TW.md`, `README_JP.md`.
  - [x] 70.2 Перестроить switcher во всех вариантах глав `01`…`08`.
  - [x] 70.3 Перестроить switcher во всех вариантах глав `09`…`16`.
  - [x] 70.4 Перестроить switcher во всех вариантах глав `17`…`24`.
  - [x] 70.5 Перестроить switcher во всех вариантах глав `25`…`32`.
  - [x] 70.6 Перестроить switcher во всех вариантах README лабораторий `01`…`09`.
  - [x] 70.7 Перестроить switcher во всех вариантах README лабораторий `10`…`18`.
  - [x] 70.8 Перестроить switcher во всех вариантах README лабораторий `19`…`27`.
  - [x] 70.9 Перестроить switcher во всех вариантах README лабораторий `28`…`35`.
    - В каждой строке использовать только относительные пути вариантов того же logical artifact, порядок RU, EN, ES, FR, DE, GE, TW, JP, точные подписи `Русская версия`, `Eng version`, `Versión en español`, `Version française`, `Deutsche Version`, `ქართული ვერსია`, `繁體中文版`, `日本語版`; не включать current locale, дубликаты или self-link. При полном наборе каждый файл содержит ровно семь ссылок.
    - _Requirements: 5.1-5.7, 8.3, 9.2_

- [x] 71. Проверить одноязычные межфайловые ссылки после reconciliation
  - [x] 71.1 Для каждой локали RU, EN, ES, FR, DE, GE, TW, JP проверить фактические `Lab_Reference`: `course/02 → labs/01, labs/15`; `course/04 → labs/01`; `course/05 → labs/02`; `course/11 → labs/16`; `course/13 → labs/04, labs/20`; `course/18 → labs/18`; `course/22 → labs/09, labs/24`. Если target на той же локали существует, ссылка обязана вести именно к нему; исправлять можно только исходный Markdown-файл с неверной ссылкой.
    - _Requirements: 3.6-3.7, 6.1-6.2, 6.5-6.7, 8.4-8.5_
  - [x] 71.2 Подтвердить, что в 35 README лабораторий по-прежнему нет `Chapter_Reference` и пользовательских `Solution_Reference`; служебная ссылка лаборатории `35` на `worker/files/solutions/1.MD` не создаёт target, задачу или дефект локализации.
    - _Requirements: 4.5-4.7, 6.3-6.7, 8.4-8.5_

- [x] 72. Создать локализованные варианты пользовательских solution-файлов ICA
  - Для каждого существующего англоязычного user-facing Markdown solution-файла в `tasks/ica/labs/*/worker/files/solutions/` сохранить английский исходник без изменений и создать варианты рядом с ним по шаблонам `<stem>_RU.MD`, `<stem>_ES.MD`, `<stem>_FR.MD`, `<stem>_DE.MD`, `<stem>_GE.MD`, `<stem>_TW.MD`, `<stem>_JP.MD`. Не перечислять и не инвентаризировать конкретные файлы; не изменять исходные solution-файлы и README links.
  - Каждый dispatch-узел использует ровно один профиль, один англоязычный source-файл и один output-файл; агент изменяет только назначенный output path. Выполнять независимые узлы параллельными пакетами не более 12 агентов.
  - [~] 72.1 Для каждого исходника создать вариант RU через `eks-translation-ru` (`gpt-5.6-terra`); один агент создаёт только соответствующий `<stem>_RU.MD`.
  - [ ] 72.2 Для каждого исходника создать вариант ES через `eks-translation-es` (`gpt-5.6-terra`); один агент создаёт только соответствующий `<stem>_ES.MD`.
  - [ ] 72.3 Для каждого исходника создать вариант FR через `eks-translation-fr` (`gpt-5.6-terra`); один агент создаёт только соответствующий `<stem>_FR.MD`.
  - [ ] 72.4 Для каждого исходника создать вариант DE через `eks-translation-de` (`gpt-5.6-terra`); один агент создаёт только соответствующий `<stem>_DE.MD`.
  - [ ] 72.5 Для каждого исходника создать вариант GE через `eks-translation-ge` (`gpt-5.6-sol`); один агент создаёт только соответствующий `<stem>_GE.MD`.
  - [ ] 72.6 Для каждого исходника создать вариант TW через `eks-translation-tw` (`gpt-5.6-terra`); один агент создаёт только соответствующий `<stem>_TW.MD`.
  - [ ] 72.7 Для каждого исходника создать вариант JP через `eks-translation-jp` (`gpt-5.6-terra`); один агент создаёт только соответствующий `<stem>_JP.MD`.
    - Во всех вариантах переводить только пользовательский текст; сохранять команды, флаги, YAML/JSON/HCL, идентификаторы, URL, пути, исполняемые fenced-code blocks, Mermaid node IDs и style. В Mermaid переводить только display labels; не использовать символ `—`.
    - _Requirements: 2.1-2.3, 2.6, 4.1-4.4, 7.3-7.6, 9.2-9.3_

- [x] 73. Выполнить `Self_Check_Process` для локализованных solution-файлов
  - [ ] 73.1 Для каждого созданного варианта сверить с английским source-файлом сохранность всех Technical_Artifact, структуру Markdown и отсутствие `—`; подтвердить первую строку `Language_Switcher` и write-scope одного output path на агента. Не добавлять и не изменять README links.
    - _Requirements: 4.3-4.4, 8.1, 8.3, 8.7, 9.2-9.4_

- [x] 74. Детерминированно согласовать `Language_Switcher` solution-файлов
  - [ ] 74.1 Для каждого logical solution artifact перестроить первую строку во всех доступных восьми вариантах в порядке RU, EN, ES, FR, DE, GE, TW, JP; использовать нормативные подписи, относительные пути соседних вариантов, исключать current locale, дубликаты и self-link. При полном наборе каждый вариант содержит ровно семь ссылок.
    - _Requirements: 5.1-5.7, 8.3, 9.2_

- [x] 75. Проверить полноту и одноязычную согласованность solution-вариантов
  - [ ] 75.1 Для каждого включённого англоязычного source-файла проверить наличие семи вариантов рядом с ним, полный набор из восьми вариантов, статусы self-check и switcher. Записать source/output path, locale, requirement ID и expected/observed для каждой ошибки; пометить artifact как `incomplete` при missing artifact или defect. Не изменять README links.
    - _Requirements: 1.4-1.7, 2.1-2.6, 4.5-4.7, 7.7-7.8, 8.3-8.9, 9.4-9.6_

- [x] 76. Сформировать детерминированный итоговый `Artifact_Validation_Report`
  - [ ] 76.1 Проверить наличие каждого из 204 созданных GE/TW/JP-файлов, наличие полного набора из восьми файлов у индекса, 32 глав, 35 лабораторных README и включённых solution-файлов, статусы self-check, switcher и каждой фактической ссылки. Отчёт должен содержать source/output path, locale, requirement ID, expected/observed при ошибке и `incomplete`, если остаётся missing artifact, defect или unresolved обязательная связь.
    - _Requirements: 1.4-1.7, 2.1-2.6, 7.7-7.8, 8.1-8.9, 9.4-9.6_

- [x] 77. Контрольная точка — убедиться, что все детерминированные проверки проходят
  - Убедиться, что все проверки проходят, и задать пользователю вопросы при их возникновении.

## Notes

- PBT не применяется: это локализация конечных Markdown-артефактов, принимаемая детерминированными проверками структуры, write-scope, `Language_Switcher` и ссылок.
- Волна перевода допускает параллельное выполнение всех задач 1.1…68.3 только потому, что у них различны output paths. Каждая проверка маршрута в задаче 71 ждёт успешного создания всех требуемых targets на соответствующей Locale.
- Reconciliation является единственным автором первой строки. Он обновляет существующие RU/EN/ES/FR/DE и созданные GE/TW/JP варианты только после успешного self-check группы.
- Блок задач 72 охватывает только существующие англоязычные user-facing Markdown solution-файлы в назначенном пути. Он не выполняет дополнительный поиск или инвентаризацию, не изменяет английские исходники и не добавляет либо не изменяет README links; служебные, исполняемые и инфраструктурные файлы не входят в область локализации.

## Task Dependency Graph

```json
{
  "waves": [
    {"id":0,"tasks":["1.1","1.2","1.3","2.1","2.2","2.3","3.1","3.2","3.3","4.1","4.2","4.3","5.1","5.2","5.3","6.1","6.2","6.3","7.1","7.2","7.3","8.1","8.2","8.3","9.1","9.2","9.3","10.1","10.2","10.3","11.1","11.2","11.3","12.1","12.2","12.3","13.1","13.2","13.3","14.1","14.2","14.3","15.1","15.2","15.3","16.1","16.2","16.3","17.1","17.2","17.3","18.1","18.2","18.3","19.1","19.2","19.3","20.1","20.2","20.3","21.1","21.2","21.3","22.1","22.2","22.3","23.1","23.2","23.3","24.1","24.2","24.3","25.1","25.2","25.3","26.1","26.2","26.3","27.1","27.2","27.3","28.1","28.2","28.3","29.1","29.2","29.3","30.1","30.2","30.3","31.1","31.2","31.3","32.1","32.2","32.3","33.1","33.2","33.3","34.1","34.2","34.3","35.1","35.2","35.3","36.1","36.2","36.3","37.1","37.2","37.3","38.1","38.2","38.3","39.1","39.2","39.3","40.1","40.2","40.3","41.1","41.2","41.3","42.1","42.2","42.3","43.1","43.2","43.3","44.1","44.2","44.3","45.1","45.2","45.3","46.1","46.2","46.3","47.1","47.2","47.3","48.1","48.2","48.3","49.1","49.2","49.3","50.1","50.2","50.3","51.1","51.2","51.3","52.1","52.2","52.3","53.1","53.2","53.3","54.1","54.2","54.3","55.1","55.2","55.3","56.1","56.2","56.3","57.1","57.2","57.3","58.1","58.2","58.3","59.1","59.2","59.3","60.1","60.2","60.3","61.1","61.2","61.3","62.1","62.2","62.3","63.1","63.2","63.3","64.1","64.2","64.3","65.1","65.2","65.3","66.1","66.2","66.3","67.1","67.2","67.3","68.1","68.2","68.3"]},
    {"id":1,"tasks":["69.1","69.2","69.3","69.4","69.5","69.6","69.7","69.8"]},
    {"id":2,"tasks":["70.1","70.2","70.3","70.4","70.5","70.6","70.7","70.8","70.9"]},
    {"id":3,"tasks":["71.1","71.2"]},
    {"id":4,"tasks":["72.1","72.2","72.3","72.4","72.5","72.6","72.7"]},
    {"id":5,"tasks":["73.1"]},
    {"id":6,"tasks":["74.1"]},
    {"id":7,"tasks":["75.1"]},
    {"id":8,"tasks":["76.1"]}
  ],
  "dependencies": {
    "69.1":["1.1","1.2","1.3","2.1","2.2","2.3","3.1","3.2","3.3","4.1","4.2","4.3","5.1","5.2","5.3","6.1","6.2","6.3","7.1","7.2","7.3","8.1","8.2","8.3","9.1","9.2","9.3"],
    "69.2":["10.1","10.2","10.3","11.1","11.2","11.3","12.1","12.2","12.3","13.1","13.2","13.3","14.1","14.2","14.3","15.1","15.2","15.3","16.1","16.2","16.3","17.1","17.2","17.3"],
    "69.3":["18.1","18.2","18.3","19.1","19.2","19.3","20.1","20.2","20.3","21.1","21.2","21.3","22.1","22.2","22.3","23.1","23.2","23.3","24.1","24.2","24.3","25.1","25.2","25.3"],
    "69.4":["26.1","26.2","26.3","27.1","27.2","27.3","28.1","28.2","28.3","29.1","29.2","29.3","30.1","30.2","30.3","31.1","31.2","31.3","32.1","32.2","32.3","33.1","33.2","33.3"],
    "69.5":["34.1","34.2","34.3","35.1","35.2","35.3","36.1","36.2","36.3","37.1","37.2","37.3","38.1","38.2","38.3","39.1","39.2","39.3","40.1","40.2","40.3","41.1","41.2","41.3","42.1","42.2","42.3"],
    "69.6":["43.1","43.2","43.3","44.1","44.2","44.3","45.1","45.2","45.3","46.1","46.2","46.3","47.1","47.2","47.3","48.1","48.2","48.3","49.1","49.2","49.3","50.1","50.2","50.3","51.1","51.2","51.3"],
    "69.7":["52.1","52.2","52.3","53.1","53.2","53.3","54.1","54.2","54.3","55.1","55.2","55.3","56.1","56.2","56.3","57.1","57.2","57.3","58.1","58.2","58.3","59.1","59.2","59.3","60.1","60.2","60.3"],
    "69.8":["61.1","61.2","61.3","62.1","62.2","62.3","63.1","63.2","63.3","64.1","64.2","64.3","65.1","65.2","65.3","66.1","66.2","66.3","67.1","67.2","67.3","68.1","68.2","68.3"],
    "70.1":["69.1"],"70.2":["69.1"],"70.3":["69.2"],"70.4":["69.3"],"70.5":["69.4"],"70.6":["69.5"],"70.7":["69.6"],"70.8":["69.7"],"70.9":["69.8"],
    "71.1":["70.2","70.3","70.4","70.5","70.6","70.7","70.8","70.9"],"71.2":["70.6","70.7","70.8","70.9"],
    "73.1":["72.1","72.2","72.3","72.4","72.5","72.6","72.7"],
    "74.1":["73.1"],
    "75.1":["74.1"],
    "76.1":["71.1","71.2","75.1"]
  }
}
```