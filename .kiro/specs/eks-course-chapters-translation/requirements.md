# Requirements Document

## Introduction

Курс EKS (репозиторий `cks`, каталог `tasks/eks/course/`) состоит из 53 глав: 5 вводных
глав Части 0 (`00-1-aws`, `00-2-iam`, `00-3-vpc`, `00-4-ec2`, `00-5-tools`) и 48 пронумерованных
глав (`01`..`48`). Сейчас в каждом каталоге главы лежит только русский оригинал (`ru.md`), без
переключателя языков. Лабы курса (`tasks/eks/labs/101`..`132`) уже переведены и проверены на
8 языках (RU, EN, ES, FR, DE, GE - грузинский, TW - традиционный китайский, JP) в рамках фичи
`eks-labs-translation-124-132`; настоящая фича использует тот же набор языков и ту же конвенцию
Language_Switcher для перевода самих глав.

Помимо 53 глав, в объём входят оглавление курса (`README_RU.md`) и пять справочников
(`GLOSSARY_RU.md`, `ADR_RU.md`, `COST_MODEL_RU.md`, `RUNBOOK_RU.md`, `SCORECARD_RU.md`) - все
они переводятся на те же 7 дополнительных языков той же конвенцией. Пять скрытых файлов
планирования (`.chapter-spec.md`, `.content-notes.md`, `.labs-plan.tsv`, `.labs-spec.md`,
`.progress.md`) - внутренние рабочие материалы авторов курса, не читательский контент, и в
объём перевода не входят.

Критично важное требование - корректность перекрёстных ссылок. Внутри переведённой главы
ссылки на другие главы, на оглавление и на связанную лабу должны указывать на файлы того же
языка, а не оставаться на `ru.md`/`README_RU.MD` независимо от языка страницы. Симметрично,
уже переведённые и закрытые лабы 101-132 (на всех 8 языках) сейчас всегда ссылаются на главу
курса через `../../course/NN/ru.md» независимо от своего языка - потому что раньше версий глав
на других языках не существовало. Эта фича обязана точечно исправить и эти обратные ссылки
во всех файлах README лаб 101-132 на всех 8 языках, чтобы каждая версия лабы ссылалась на
версию главы своего языка.

Отдельная часть работы - двусторонняя проверка привязки «глава <-> лаба» на русском оригинале
до начала перевода: обнаруженные асимметрии (лаба ссылается на главу в разделе «Цель», а глава
не упоминает эту лабу в разделе «Практика») фиксируются в отчёте и точечно исправляются в
русском оригинале главы, чтобы перевод шёл по уже согласованной, симметричной привязке.

Процесс перевода отличается от использованного для лаб: там сабагенты параллелились по лабам.
Здесь перевод идёт по одной главе за раз (не параллельно по главам), но внутри перевода одной
главы - на каждый язык (EN/ES/FR/DE/GE/TW/JP) отдельный Translation_Subagent, и одновременно
работают не более 2 таких сабагентов.

## Glossary

- **Chapter**: один из 53 каталогов курса - `tasks/eks/course/00-1-aws` .. `00-5-tools` и
  `tasks/eks/course/01` .. `48`.
- **Language**: один из восьми языков перевода: `RU` (оригинал), `EN`, `ES`, `FR`, `DE`, `GE`
  (грузинский), `TW` (традиционный китайский), `JP`.
- **Chapter_File**: файл содержания Chapter на конкретном Language - `ru.md`, `en.md`,
  `es.md`, `fr.md`, `de.md`, `ge.md`, `tw.md` или `jp.md` внутри каталога Chapter.
- **TOC_File**: файл оглавления курса на конкретном Language - `README_RU.md` (существующий,
  без изменения имени) для `RU`, `README.md` для `EN`, либо `README_XX.md`, где `XX` - код
  Language из набора `ES, FR, DE, GE, TW, JP`, в корне `tasks/eks/course/`.
- **Reference_Doc**: один из пяти справочников курса - глоссарий (`GLOSSARY`), архитектурные
  решения (`ADR`), модель затрат (`COST_MODEL`), диагностический справочник (`RUNBOOK`),
  матрица зрелости (`SCORECARD`) - в корне `tasks/eks/course/`.
- **Reference_Doc_File**: файл конкретного Reference_Doc на конкретном Language, по той же
  схеме именования, что TOC_File (например `GLOSSARY_RU.md`, `GLOSSARY.md`, `GLOSSARY_ES.md`).
- **Planning_File**: один из пяти скрытых служебных файлов курса - `.chapter-spec.md`,
  `.content-notes.md`, `.labs-plan.tsv`, `.labs-spec.md`, `.progress.md` - вне объёма перевода.
- **Language_Switcher**: первая строка Chapter_File, TOC_File или Reference_Doc_File,
  содержащая markdown-ссылки на версии этого же файла на всех Language, кроме Language самого
  файла, в порядке `RU -> EN -> ES -> FR -> DE -> GE -> TW -> JP` (собственный Language
  пропускается), с подписями `Русская версия`, `Eng version`, `Versión en español`,
  `Version française`, `Deutsche Version`, `ქართული ვერსია`, `繁體中文版`, `日本語版`.
- **Course_Chapter_Link**: markdown-ссылка из Chapter_File на другой Chapter_File или на
  TOC_File - навигационная строка в конце файла (`[Оглавление](...)`, `[Глава N-1](...)`,
  `[Глава N+1](...)`).
- **Chapter_Number_Mention**: упоминание номера главы в прозе текста Chapter_File (например
  «глава 6», «глава 30»), НЕ являющееся markdown-ссылкой, по конвенции курса
  (`.chapter-spec.md`: «ссылки на другие главы давать словами, без markdown-ссылок внутри
  текста»).
- **Practice_Section**: раздел `## Практика` (или переведённый эквивалент заголовка) в конце
  Chapter_File, содержащий либо Lab_Reference на связанную Lab, либо текст об отсутствии своей
  лабы у Chapter.
- **Lab**: одна из директорий `tasks/eks/labs/101` .. `tasks/eks/labs/132`.
- **Lab_README_File**: файл описания Lab на конкретном Language - `README.MD` (EN) или
  `README_XX.MD` (`RU, ES, FR, DE, GE, TW, JP`), уже существующий для всех Lab 101-132.
- **Lab_Reference**: markdown-ссылка из Practice_Section Chapter_File на Lab_README_File,
  например `[лаба 132 - ...](../../labs/132/README_RU.MD)`.
- **Chapter_Reference**: markdown-ссылка из раздела «Цель» (или переведённого эквивалента)
  Lab_README_File на Chapter_File, например `[Глава 8. ...](../../course/08/ru.md)`.
- **Lab_Chapter_Mapping_Gap**: несогласованность русского оригинала, при которой существует
  Chapter_Reference из Lab на Chapter, но Practice_Section этой Chapter на Language `RU` не
  содержит соответствующего Lab_Reference на эту Lab (или содержит Lab_Reference на другую
  Lab, или ссылку на несуществующий файл).
- **Reverse_Mapping_Report**: документ, фиксирующий результат двусторонней проверки всех
  Chapter_Reference (лаба -> глава) и Lab_Reference (глава -> лаба) для Lab 101-132 и Chapter
  01-48 и 00-1..00-5, включая перечень обнаруженных Lab_Chapter_Mapping_Gap и битых ссылок.
- **Translation_Subagent**: сабагент типа `general-task-execution`, которому делегируется
  перевод одного Chapter_File, TOC_File или Reference_Doc_File на один Language.
- **Self_Check_Process**: обязательная проверка, выполняемая после перевода Chapter на все 7
  Language, сверяющая структурные счётчики, ссылки и терминологию между всеми Chapter_File
  одной Chapter, описанная в требовании 9.

## Requirements

### Requirement 1: Формат и наименование файлов перевода главы

**User Story:** Как читатель курса на любом из 8 языков, я хочу открыть главу на своём языке и
увидеть рабочие ссылки на версии на остальных языках, чтобы свободно переключаться между
переводами, как это уже устроено в лабах.

#### Acceptance Criteria

1. WHERE Language равен `RU`, THE Chapter_File SHALL иметь имя `ru.md` (существующее имя не
   меняется).
2. WHERE Language не равен `RU`, THE Chapter_File SHALL иметь имя `en.md`, `es.md`, `fr.md`,
   `de.md`, `ge.md`, `tw.md` или `jp.md` в соответствии с Language.
3. THE Chapter_File на каждом из 8 Language SHALL иметь первой строкой файла
   Language_Switcher.
4. THE Language_Switcher Chapter_File SHALL содержать ровно 7 markdown-ссылок - по одной на
   каждый Language, отличный от Language самого файла, - и SHALL ссылаться на Chapter_File
   остальных Language внутри того же каталога Chapter (например `de.md` ссылается на `en.md`,
   `es.md`, `fr.md`, `ge.md`, `tw.md`, `jp.md`, `ru.md`).
5. IF `ru.md` каталога Chapter существовал до перевода без Language_Switcher, THEN THE перевод
   SHALL добавить Language_Switcher первой строкой в `ru.md`, а не только в новых Chapter_File.
6. THE первая содержательная строка Chapter_File (заголовок `# Глава N. ...` или переведённый
   эквивалент) SHALL остаться второй строкой файла после Language_Switcher, сохраняя нумерацию
   главы `N` неизменной на всех Language.

### Requirement 2: Перевод оглавления курса и справочников

**User Story:** Как читатель курса, я хочу открыть оглавление и справочники курса на своём
языке и перейти по ним к главам того же языка, чтобы не переключаться на русский посреди
изучения материала.

#### Acceptance Criteria

1. WHERE Language равен `RU`, THE TOC_File SHALL сохранять существующее имя `README_RU.md`.
2. WHERE Language равен `EN`, THE TOC_File SHALL иметь имя `README.md`.
3. WHERE Language не равен `RU` и не равен `EN`, THE TOC_File SHALL иметь имя `README_XX.md`,
   где `XX` - код Language (`ES, FR, DE, GE, TW, JP`).
4. THE TOC_File на каждом из 8 Language SHALL иметь первой строкой файла Language_Switcher,
   ссылающийся на TOC_File остальных Language по правилам требования 1.4, применённым к
   именам TOC_File.
5. THE список глав в TOC_File на Language `XX` SHALL содержать ссылки на Chapter_File того же
   Language `XX` для каждой главы (например TOC_File `README_DE.md` ссылается на `01/de.md`,
   не на `01/ru.md`).
6. THE TOC_File на Language `XX` SHALL содержать ссылки на Reference_Doc_File того же Language
   `XX` (например ссылка на глоссарий из `README_DE.md` указывает на `GLOSSARY_DE.md`).
7. WHERE Reference_Doc - один из пяти справочников курса (`GLOSSARY`, `ADR`, `COST_MODEL`,
   `RUNBOOK`, `SCORECARD`), THE Reference_Doc_File SHALL существовать на каждом из 8 Language
   по схеме именования требования 2.1-2.3, применённой к базовому имени Reference_Doc.
8. THE Reference_Doc_File на каждом из 8 Language SHALL иметь первой строкой файла
   Language_Switcher, ссылающийся на Reference_Doc_File остальных Language.
9. WHERE Reference_Doc_File на Language `RU` существовал до перевода без Language_Switcher,
   THE перевод SHALL добавить Language_Switcher первой строкой, не изменяя остальное содержимое
   файла сверх необходимого для ссылок требования 2.10.
10. THE ссылки на главы внутри Reference_Doc_File на Language `XX` SHALL указывать на
    Chapter_File того же Language `XX`.

### Requirement 3: Служебные файлы планирования вне объёма перевода

**User Story:** Как автор курса, я хочу быть уверен, что перевод не затрагивает внутренние
рабочие материалы, чтобы процесс написания и сопровождения курса не сломался.

#### Acceptance Criteria

1. THE процесс перевода SHALL НЕ создавать переводы Planning_File (`.chapter-spec.md`,
   `.content-notes.md`, `.labs-plan.tsv`, `.labs-spec.md`, `.progress.md`) на какой-либо
   Language, отличный от `RU`.
2. THE процесс перевода SHALL НЕ изменять содержимое Planning_File, за исключением обновлений
   `.progress.md`, отражающих ход работы по самой этой фиче.

### Requirement 4: Корректность внутренних ссылок глав на свой язык

**User Story:** Как читатель главы на конкретном языке, я хочу, чтобы ссылки на другие главы и
на оглавление вели на версии того же языка, чтобы не переключаться на русский язык посреди
навигации по курсу.

#### Acceptance Criteria

1. THE навигационная строка в конце Chapter_File на Language `XX` (Course_Chapter_Link на
   предыдущую и следующую главу и на оглавление) SHALL ссылаться на Chapter_File и TOC_File
   того же Language `XX`.
2. IF Chapter_File на Language `XX` ссылается через Course_Chapter_Link на Chapter_File или
   TOC_File Language, отличного от `XX`, THEN THIS SHALL считаться дефектом перевода,
   подлежащим исправлению до завершения работы по Chapter.
3. THE Chapter_Number_Mention внутри прозы Chapter_File SHALL оставаться текстовым упоминанием
   номера главы (например «глава 6» переводится как «chapter 6», «Kapitel 6» и так далее) и
   SHALL НЕ становиться markdown-ссылкой ни на одном Language, сохраняя конвенцию курса не
   создавать гиперссылки на главы внутри прозы.
4. THE переводы номеров глав в Chapter_Number_Mention SHALL сохранять тот же номер главы, что
   и в оригинале на Language `RU`.

### Requirement 5: Двусторонняя проверка привязки лаб к главам и отчёт

**User Story:** Как автор курса, я хочу заранее знать обо всех несостыковках между лабами и
главами на русском оригинале, чтобы перевод шёл по уже согласованной, симметричной привязке, а
не переносил существующий дефект на 8 языков сразу.

#### Acceptance Criteria

1. THE проверка привязки SHALL для каждой Lab 101-132 прочитать Chapter_Reference из раздела
   «Цель» Lab_README_File на Language `RU` и сверить, что указанный файл Chapter_File
   существует.
2. THE проверка привязки SHALL для каждой Chapter прочитать все Lab_Reference из Practice_Section
   Chapter_File на Language `RU` и сверить, что указанный файл Lab_README_File существует.
3. THE проверка привязки SHALL для каждой пары (Lab, Chapter), где Lab через Chapter_Reference
   ссылается на Chapter, проверить наличие обратного Lab_Reference на эту Lab в Practice_Section
   этой Chapter.
4. IF для пары (Lab, Chapter) обратный Lab_Reference из требования 5.3 отсутствует, THEN THE
   проверка привязки SHALL зафиксировать это как Lab_Chapter_Mapping_Gap в Reverse_Mapping_Report.
5. IF Chapter_Reference или Lab_Reference указывает на несуществующий файл, THEN THE проверка
   привязки SHALL зафиксировать это как битую ссылку в Reverse_Mapping_Report.
6. THE Reverse_Mapping_Report SHALL быть создан и представлен до начала перевода Chapter,
   затронутой хотя бы одним Lab_Chapter_Mapping_Gap или битой ссылкой.
7. WHEN Reverse_Mapping_Report зафиксировал Lab_Chapter_Mapping_Gap для Chapter на Language
   `RU`, THE Practice_Section этой Chapter на Language `RU` SHALL быть точечно дополнен
   Lab_Reference на соответствующую Lab до начала перевода этой Chapter на остальные Language.
8. THE точечная правка Practice_Section по требованию 5.7 SHALL ограничиваться добавлением
   или исправлением Lab_Reference и минимально необходимого поясняющего текста, SHALL НЕ
   переписывать остальное содержимое Chapter_File на Language `RU`.
9. THE проверка привязки SHALL подтвердить, что каждая Lab из набора 101-132 упомянута хотя бы
   одним Lab_Reference в Practice_Section хотя бы одной Chapter на Language `RU` после
   применения правок требования 5.7.

### Requirement 6: Ссылки «глава -> лаба» и «лаба -> глава» на свой язык

**User Story:** Как читатель главы или лабы на конкретном языке, я хочу, чтобы связанные лаба
и глава ссылались друг на друга в рамках моего языка, чтобы не переключаться на русский язык
между теорией и практикой.

#### Acceptance Criteria

1. THE Lab_Reference в Practice_Section Chapter_File на Language `XX` SHALL ссылаться на
   Lab_README_File того же Language `XX` соответствующей Lab (например `de.md` главы 8
   ссылается на `../../labs/132/README_DE.MD`).
2. THE Chapter_Reference в разделе «Цель» (или переведённом эквиваленте заголовка)
   Lab_README_File на Language `XX` SHALL ссылаться на Chapter_File того же Language `XX`
   соответствующей Chapter (например `README_DE.MD` лабы 132 ссылается на `../../course/08/de.md`).
3. THE правка Chapter_Reference по требованию 6.2 SHALL быть применена к Lab_README_File всех
   8 Language для каждой Lab из диапазона 101-132, включая Lab 101-123, ранее закрытые в
   рамках фичи `eks-labs-translation-124-132`.
4. THE правка Chapter_Reference по требованию 6.2 SHALL изменять только целевой путь ссылки
   (замену суффикса `ru.md` на суффикс языка `XX.md` соответствующего Chapter_File) и SHALL НЕ
   изменять текст подписи ссылки, номер главы или окружающий текст раздела «Цель» сверх этой
   замены.
5. THE правка Chapter_Reference по требованию 6.2 SHALL НЕ изменять любой другой файл или
   раздел Lab, включая `worker/files/tests.bats`, файлы решений и остальные разделы
   Lab_README_File.
6. IF после правки требования 6.2 Chapter_Reference в Lab_README_File на Language `XX`
   указывает на Chapter_File Language, отличного от `XX`, THEN THIS SHALL считаться дефектом,
   подлежащим исправлению до завершения работы по этой Lab.

### Requirement 7: Структурная эквивалентность перевода главы с русским оригиналом

**User Story:** Как поддерживающий курс автор, я хочу, чтобы переведённые главы повторяли
структуру русского оригинала без потери или добавления разделов, чтобы переводы оставались
синхронными при последующих правках русского текста.

#### Acceptance Criteria

1. THE переведённый Chapter_File на Language `XX` SHALL содержать то же количество заголовков
   `## ` и `### `, что и `ru.md` той же Chapter.
2. THE переведённый Chapter_File на Language `XX` SHALL содержать то же количество блоков
   ```` ```mermaid ```` и то же количество узлов в каждом соответствующем блоке, что и `ru.md`
   той же Chapter.
3. THE переведённый Chapter_File на Language `XX` SHALL содержать ту же расстановку директив
   `style` в диаграммах mermaid (по количеству и по ссылающимся узлам), что и `ru.md` той же
   Chapter.
4. THE переведённый Chapter_File на Language `XX` SHALL содержать то же количество ограждений
   блоков кода (```` ``` ````) и то же количество markdown-таблиц, что и `ru.md` той же
   Chapter.
5. THE переведённый Chapter_File на Language `XX` SHALL сохранять служебные разделы в конце
   файла в том же порядке, что и `ru.md` (практики продакшена, мини-глоссарий, итоги главы, как
   пригодится в реальной работе, вопросы для самопроверки, раздел «Практика»).
6. THE переведённый TOC_File и Reference_Doc_File на Language `XX` SHALL содержать то же
   количество разделов и записей (глав, терминов, строк таблиц), что и версия на Language `RU`.

### Requirement 8: Сохранение технических терминов и артефактов без перевода

**User Story:** Как читатель, использующий главу как справочник при работе с кластером, я хочу
видеть команды, флаги, имена полей API и артефакты в неизменном виде, чтобы буквально
скопировать их и получить рабочий результат.

#### Acceptance Criteria

1. THE перевод Chapter_File, TOC_File и Reference_Doc_File SHALL оставлять команды, флаги CLI,
   YAML-код, имена полей API, переменные окружения, ARN, CIDR, типы инстансов, имена IAM-
   политик, ключи тегов и названия сервисов AWS без изменения на всех Language.
2. THE перевод Chapter_File SHALL оставлять Lab_Reference и Course_Chapter_Link рабочими
   markdown-ссылками (изменяется только целевой путь на свой Language по требованию 4 и 6, а
   не текст ссылки внутри технических артефактов).
3. THE перевод любого файла в объёме этой фичи SHALL использовать только обычный дефис `-`;
   символ длинного тире `—` SHALL отсутствовать (0 вхождений при проверке по каждому файлу).
4. THE перевод mermaid-диаграмм SHALL сохранять идентификаторы узлов на английском в исходном
   виде и переводить только текстовые подписи узлов и меток стрелок.

### Requirement 9: Процесс перевода и самопроверка

**User Story:** Как автор курса, я хочу, чтобы перевод каждой главы выполнялся контролируемым
процессом с проверкой результата, чтобы избежать дефектов, аналогичных известным по истории
перевода лаб (потерянный переключатель языков, неверная ссылка при переносе оригинала на
чужой язык, недоведённый до конца перевод).

#### Acceptance Criteria

1. THE перевод 53 Chapter SHALL выполняться последовательно по одной Chapter за раз - перевод
   следующей Chapter SHALL начинаться только после завершения Self_Check_Process текущей
   Chapter.
2. THE перевод одной Chapter на 7 Language, отличных от `RU`, SHALL выполняться Translation_Subagent,
   запускаемыми не более чем по 2 параллельно, с назначением одного Language на один
   Translation_Subagent.
3. WHEN все 7 Translation_Subagent завершают перевод Chapter, THE Self_Check_Process SHALL быть
   выполнен для полного комплекта из 8 Chapter_File этой Chapter, не полагаясь только на отчёт
   Translation_Subagent.
4. THE Self_Check_Process SHALL для каждого из 8 Chapter_File Chapter подсчитывать: количество
   строк, количество заголовков `## ` и `### `, количество блоков ```` ```mermaid ````,
   количество директив `style`, количество ограждений блоков кода ```` ``` ````, количество
   markdown-таблиц, количество вхождений `—` (длинное тире) и количество ссылок в
   Language_Switcher.
5. THE Self_Check_Process SHALL проверять отсутствие кириллических символов вне
   Language_Switcher и вне сохраняемых по требованию 8 технических артефактов в Chapter_File на
   Language, отличных от `RU`.
6. THE Self_Check_Process SHALL проверять, что каждый Course_Chapter_Link и каждый Lab_Reference
   в Chapter_File на Language `XX` указывает на файл того же Language `XX` (требования 4 и 6).
7. IF Self_Check_Process обнаруживает, что счётчики строк, заголовков, mermaid-блоков, style,
   таблиц или code fence различаются между Language-версиями одной Chapter за пределами
   ожидаемых различий длины текста, THEN Self_Check_Process SHALL сообщить об этом как о
   несоответствии структуры, подлежащем исправлению до завершения работы по Chapter.
8. IF Self_Check_Process обнаруживает вхождение `—` в любом Chapter_File, TOC_File или
   Reference_Doc_File, THEN THIS SHALL считаться дефектом, подлежащим исправлению до завершения
   работы по соответствующему файлу.
9. IF Self_Check_Process обнаруживает, что количество ссылок в Language_Switcher любого файла
   не равно 7, THEN THIS SHALL считаться дефектом, подлежащим исправлению до завершения работы
   по соответствующему файлу.
10. THE TOC_File и Reference_Doc_File SHALL проходить аналогичный Self_Check_Process (счётчики
    структуры, Language_Switcher, отсутствие длинного тире, ссылки на свой Language) после
    завершения перевода всех 53 Chapter, поскольку их содержимое (список глав, термины со
    ссылками на главы) зависит от финальных путей Chapter_File.

### Requirement 10: Критерии полноты перевода

**User Story:** Как автор курса, я хочу иметь однозначный критерий готовности перевода всех
глав, оглавления и справочников, чтобы не оставить часть материала недопереведённой.

#### Acceptance Criteria

1. THE итоговый результат работы по фиче SHALL включать полный комплект из 8 Chapter_File
   (`ru.md`, `en.md`, `es.md`, `fr.md`, `de.md`, `ge.md`, `tw.md`, `jp.md`) для каждой из 53
   Chapter, то есть 424 Chapter_File суммарно (53 существующих `ru.md` плюс 371 новых).
2. THE итоговый результат работы по фиче SHALL включать полный комплект из 8 TOC_File и по 8
   Reference_Doc_File для каждого из 5 Reference_Doc, то есть 8 плюс 40 файлов.
3. THE проверка полноты SHALL выполняться листингом каталогов `tasks/eks/course/<chapter>/` и
   корня `tasks/eks/course/`, подтверждающим наличие всех ожидаемых имён файлов.
4. IF по какой-либо Chapter создано менее 8 Chapter_File, THEN эта Chapter SHALL считаться
   незавершённой, и работа по ней SHALL быть продолжена до достижения полного комплекта.
5. THE итоговый результат работы по фиче SHALL включать Reverse_Mapping_Report (требование 5) и
   подтверждение применения правки Chapter_Reference (требование 6) ко всем Lab_README_File
   Lab 101-132 на всех 8 Language.
6. THE перевод SHALL затрагивать только Chapter, TOC_File, Reference_Doc_File курса EKS и
   Chapter_Reference внутри Lab_README_File Lab 101-132; содержимое Lab 101-132 за пределами
   Chapter_Reference (требование 6.5) SHALL оставаться без изменений.
