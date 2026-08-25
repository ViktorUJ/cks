# Документ требований

## Введение

Эта спецификация определяет локализацию учебных материалов Istio Certified Associate (ICA) в `tasks/ica/course/` и `tasks/ica/labs/`. В область входят 32 каталога глав курса (`01`..`32`), каталог курса и 35 каталогов лабораторных работ (`01`..`35`). Требования распространяются только на артефакты, включённые в `Localization_Manifest` и `DAG_Execution_Plan`.

Обязательная языковая матрица для каждого включённого `Course_Chapter`, `Course_Index_File`, `Lab_README_File` и пользовательского `Lab_Solution_File` состоит из восьми `Locale`: RU, EN, ES, FR, DE, GE, TW и JP. Отсутствие варианта из этой матрицы является `Missing_Localized_Artifact`; GE, TW и JP не являются дополнительными или необязательными локалями.

Результатом будущей реализации будет полный и проверяемый набор языковых вариантов для каждого включённого артефакта, включая локализованные `Language_Switcher` и согласованные ссылки между главой, лабораторной работой и решением. Перевод текстов, изменение лабораторных решений и создание плана реализации в текущую фазу требований не входят.

Локализация должна планироваться как направленный ациклический граф (DAG), пригодный для выполнения в Kiro CLI: инвентаризация определяет объём, независимые варианты одного артефакта могут выполняться отдельными сабагентами, а проверка ссылок запускается после готовности зависимых артефактов. Локализованные файлы, появившиеся после инвентаризации, являются входными данными следующего запуска и сами по себе не считаются дефектом.

## Глоссарий

- **ICA_Localization_Workflow**: будущий процесс локализации ICA-материалов и проверки их связей.
- **ICA_Course**: набор материалов в `tasks/ica/course/`, включающий каталог курса, `Course_Chapter` и `Course_Index_File`.
- **Course_Chapter**: один каталог глав ICA в `tasks/ica/course/01`..`tasks/ica/course/32`.
- **Course_Chapter_File**: содержательный Markdown-файл `Course_Chapter` на конкретном `Locale`, включая `ru.md`, `en.md`, `es.md`, `fr.md`, `de.md`, `ge.md`, `tw.md` или `jp.md` по действующей конвенции.
- **Course_Index_File**: локализованный индекс `ICA_Course` в `tasks/ica/course/`: `README_RU.md` для RU, `README.md` для EN или `README_XX.md` для другого `Locale`.
- **ICA_Lab**: один каталог лабораторной работы в `tasks/ica/labs/01`..`tasks/ica/labs/35`.
- **Lab_README_File**: локализованное описание `ICA_Lab`: `README_RU.MD` для RU, `README.MD` для EN или `README_XX.MD` для другого `Locale`.
- **Locale**: код языка локализованного файла: RU, EN, ES, FR, DE, GE, TW или JP.
- **Required_Locale_Set**: обязательный неизменяемый набор из RU, EN, ES, FR, DE, GE, TW и JP, назначенный каждому включённому артефакту.
- **Artifact_Identity**: неизменяемая пара из относительного к репозиторию пути базового артефакта и его типа, общая для всех его языковых вариантов.
- **Inventory_Record**: единственная запись `Localization_Manifest` для одной пары `Artifact_Identity` и `Locale`, содержащая путь, тип, состояние наличия и кандидата на исходный язык.
- **Source_Artifact**: существующий локализованный файл, однозначно выбранный `Localization_Manifest` как источник для создания одного языкового варианта.
- **Output_Artifact**: отсутствующий локализованный файл на назначенном `Locale`, создаваемый одним узлом локализации.
- **Localization_Manifest**: машиночитаемый результат инвентаризации, фиксирующий обнаруженные артефакты, их `Locale`, `Required_Locale_Set`, отсутствующие варианты, связанные ссылки и время создания снимка.
- **Missing_Localized_Artifact**: ожидаемый путь `Output_Artifact` для пары `Artifact_Identity` и `Locale` из `Required_Locale_Set`, для которого в снимке `Localization_Manifest` нет существующего файла.
- **Out_of_Matrix_Artifact**: обнаруженный локализованный файл, чей `Locale` не входит в `Required_Locale_Set`.
- **Language_Switcher**: первая физическая строка локализованного Markdown-файла, содержащая Markdown-ссылки на доступные `Localization_Equivalent` того же `Artifact_Identity` в нормативном порядке `Locale`.
- **Chapter_Reference**: Markdown-ссылка из `Lab_README_File` на соответствующий `Course_Chapter_File`.
- **Lab_Reference**: Markdown-ссылка из `Course_Chapter_File` или `Course_Index_File` на соответствующий `Lab_README_File`.
- **Lab_Solution_File**: файл решения `ICA_Lab`, определённый инвентаризацией как пользовательский локализуемый материал.
- **Absent_User_Facing_Solution**: отсутствие `Lab_Solution_File`, определённого инвентаризацией как пользовательский локализуемый материал, для `Artifact_Identity` лабораторной работы.
- **Solution_Reference**: Markdown-ссылка из `Lab_README_File` на `Lab_Solution_File`.
- **Localization_Equivalent**: существующий вариант того же `Artifact_Identity`, чей `Locale` равен `Locale` исходного документа.
- **Technical_Artifact**: команда, флаг, имя поля манифеста, идентификатор, URL, путь к файлу или исполняемый блок кода исходного документа.
- **Artifact_Validation_Report**: машиночитаемый отчёт проверки структуры, `Language_Switcher` и межфайловых ссылок после локализации.
- **DAG_Execution_Plan**: машиночитаемое описание узлов, зависимостей, входов, выходов, статусов и назначений сабагентов для Kiro CLI.
- **Localization_Node**: узел `DAG_Execution_Plan`, который создаёт ровно один `Output_Artifact` из ровно одного `Source_Artifact` на ровно одном `Locale`.
- **Validation_Node**: узел `DAG_Execution_Plan`, который проверяет артефакт или связь и не создаёт локализованный текст.
- **Translation_Subagent**: сабагент Kiro CLI, которому назначен ровно один `Localization_Node`.
- **Self_Check_Process**: детерминированная проверка, выполняемая оркестратором после завершения зависимых узлов DAG без доверия только отчёту `Translation_Subagent`.

## Требования

### Требование 1: Инвентаризация локалей и объёма ICA

**Пользовательская история:** Как сопровождающий ICA-материалы, я хочу получить снимок существующих локалей и связанных артефактов, чтобы планировать только действительно отсутствующие варианты.

#### Критерии приёмки

1. WHEN ICA_Localization_Workflow запускается, THE ICA_Localization_Workflow SHALL перечислить Course_Chapter, Course_Index_File, ICA_Lab, Lab_README_File и Lab_Solution_File в `tasks/ica/course/` и `tasks/ica/labs/`.
2. WHEN ICA_Localization_Workflow обнаруживает локализуемый файл, THE ICA_Localization_Workflow SHALL записать ровно один Inventory_Record для пары Artifact_Identity и Locale с относительным к репозиторию путём, типом артефакта, состоянием наличия и кандидатом на исходный язык.
3. WHEN ICA_Localization_Workflow перечисляет Markdown-артефакт, THE ICA_Localization_Workflow SHALL записать в Localization_Manifest каждый Language_Switcher, Chapter_Reference, Lab_Reference и Solution_Reference, найденный в артефакте.
4. THE ICA_Localization_Workflow SHALL записать Required_Locale_Set со значениями RU, EN, ES, FR, DE, GE, TW и JP для каждого включённого Course_Chapter_File, Course_Index_File, Lab_README_File и пользовательского Lab_Solution_File.
5. WHEN ICA_Localization_Workflow вычисляет ожидаемый путь для пары Artifact_Identity и Locale из Required_Locale_Set, THE ICA_Localization_Workflow SHALL классифицировать этот путь как Missing_Localized_Artifact, если в снимке Localization_Manifest отсутствует существующий файл по этому пути.
6. WHEN Localization_Manifest создаётся, THE ICA_Localization_Workflow SHALL записать время создания и относительные к репозиторию пути, использованные для инвентаризации.
7. IF локализованный файл появляется после создания Localization_Manifest и отсутствует в снимке манифеста, THEN THE ICA_Localization_Workflow SHALL классифицировать файл как вновь обнаруженный вход следующей инвентаризации, а не как дефект.

### Требование 2: Определение обязательных локалей и отсутствующих вариантов

**Пользовательская история:** Как владелец курса, я хочу явно видеть обязательные локали каждого материала, чтобы не перепутать отсутствующий перевод с необязательным или появившимся позднее файлом.

#### Критерии приёмки

1. THE ICA_Localization_Workflow SHALL использовать RU, EN, ES, FR, DE, GE, TW и JP как единственный Required_Locale_Set для каждого включённого Course_Chapter_File, Course_Index_File, Lab_README_File и пользовательского Lab_Solution_File.
2. WHEN ICA_Localization_Workflow назначает Required_Locale_Set Artifact_Identity, THE ICA_Localization_Workflow SHALL записать для каждой пары Artifact_Identity и Locale из Required_Locale_Set один ожидаемый относительный путь и одно состояние наличия в Localization_Manifest.
3. WHEN ожидаемый путь пары Artifact_Identity и Locale из Required_Locale_Set отсутствует в снимке Localization_Manifest, THE ICA_Localization_Workflow SHALL записать эту пару как Missing_Localized_Artifact.
4. WHEN ICA_Localization_Workflow обнаруживает локализованный файл с Locale вне Required_Locale_Set, THE ICA_Localization_Workflow SHALL записать файл как Out_of_Matrix_Artifact без классификации файла как дефекта или Missing_Localized_Artifact.
5. IF Localization_Manifest не может однозначно выбрать Source_Artifact для Missing_Localized_Artifact, THEN THE ICA_Localization_Workflow SHALL записать причину неоднозначности и исключить соответствующий Localization_Node из DAG_Execution_Plan до разрешения области.
6. WHEN Localization_Manifest фиксирует Missing_Localized_Artifact для GE, TW или JP, THE ICA_Localization_Workflow SHALL создать для него тот же тип Localization_Node, что и для Missing_Localized_Artifact для RU, EN, ES, FR или DE.

### Требование 3: Локализация глав и индекса курса

**Пользовательская история:** Как читатель ICA_Course на выбранном языке, я хочу читать главы и индекс на одном Locale, чтобы перемещаться по курсу без непреднамеренного переключения языка.

#### Критерии приёмки

1. WHEN Course_Chapter имеет Missing_Localized_Artifact для Locale `XX` и однозначный Source_Artifact, THE ICA_Localization_Workflow SHALL создать один Course_Chapter_File по ожидаемому пути для Locale `XX`.
2. WHEN Course_Index_File имеет Missing_Localized_Artifact для Locale `XX` и однозначный Source_Artifact, THE ICA_Localization_Workflow SHALL создать один Course_Index_File по ожидаемому пути для Locale `XX`.
3. WHEN ICA_Localization_Workflow создаёт Course_Chapter_File или Course_Index_File, THE ICA_Localization_Workflow SHALL назначить создающему Localization_Node ровно один Source_Artifact, один Output_Artifact и один Locale.
4. WHEN ICA_Localization_Workflow создаёт Course_Chapter_File, THE ICA_Localization_Workflow SHALL сохранить последовательность уровней заголовков, число и порядок блоков кода, таблиц и блоков диаграмм Source_Artifact.
5. WHEN ICA_Localization_Workflow создаёт Course_Chapter_File или Course_Index_File, THE ICA_Localization_Workflow SHALL сохранить каждый Technical_Artifact Source_Artifact без изменения текста.
6. WHEN Course_Index_File на Locale `XX` содержит ссылку на Course_Chapter и существует Localization_Equivalent Course_Chapter_File на Locale `XX`, THE ICA_Localization_Workflow SHALL направить ссылку на относительный путь этого Localization_Equivalent.
7. WHEN Course_Chapter_File на Locale `XX` содержит навигационную ссылку на другой Course_Chapter или Course_Index_File и существует Localization_Equivalent на Locale `XX`, THE ICA_Localization_Workflow SHALL направить ссылку на относительный путь этого Localization_Equivalent.
8. IF Source_Artifact для Course_Chapter_File или Course_Index_File не определён однозначно, THEN THE ICA_Localization_Workflow SHALL записать Artifact_Identity как требующий разрешения области и не создавать Output_Artifact.

### Требование 4: Локализация описаний лабораторных работ и решений

**Пользовательская история:** Как читатель лабораторной работы, я хочу использовать описание лабы и доступное решение на одном Locale, чтобы инструкции и эталонный материал оставались согласованными.

#### Критерии приёмки

1. WHEN ICA_Lab имеет Missing_Localized_Artifact для Lab_README_File на Locale `XX` и однозначный Source_Artifact, THE ICA_Localization_Workflow SHALL создать один Lab_README_File по ожидаемому пути для Locale `XX`.
2. WHEN пользовательский Lab_Solution_File имеет Missing_Localized_Artifact для Locale `XX` и однозначный Source_Artifact, THE ICA_Localization_Workflow SHALL создать один Lab_Solution_File по ожидаемому пути для Locale `XX`.
3. WHEN ICA_Localization_Workflow создаёт Lab_README_File или Lab_Solution_File, THE ICA_Localization_Workflow SHALL назначить создающему Localization_Node ровно один Source_Artifact, один Output_Artifact и один Locale.
4. WHEN ICA_Localization_Workflow создаёт Lab_README_File или Lab_Solution_File, THE ICA_Localization_Workflow SHALL сохранить каждый Technical_Artifact Source_Artifact без изменения текста.
5. WHEN Lab_README_File на Locale `XX` содержит Solution_Reference и существует пользовательский Localization_Equivalent Lab_Solution_File на Locale `XX`, THE ICA_Localization_Workflow SHALL направить Solution_Reference на относительный путь этого Localization_Equivalent.
6. WHEN Lab_README_File на Locale `XX` содержит Solution_Reference и пользовательский Localization_Equivalent Lab_Solution_File на Locale `XX` отсутствует, THE ICA_Localization_Workflow SHALL записать неразрешённую связь с путём источника, путём ожидаемой цели и Locale в Artifact_Validation_Report.
7. WHEN ICA_Lab не имеет Lab_Solution_File, определённого в Localization_Manifest как пользовательский локализуемый материал, THE ICA_Localization_Workflow SHALL классифицировать ICA_Lab как Absent_User_Facing_Solution и не создавать Localization_Node для решения.
8. IF Source_Artifact для Lab_README_File или Lab_Solution_File не определён однозначно, THEN THE ICA_Localization_Workflow SHALL записать Artifact_Identity как требующий разрешения области и не создавать Output_Artifact.

### Требование 5: Локализация Language_Switcher

**Пользовательская история:** Как читатель локализованного ICA-материала, я хочу переключаться между предусмотренными языковыми вариантами одного и того же материала, чтобы быстро менять язык без поиска файлов вручную.

#### Критерии приёмки

1. THE ICA_Localization_Workflow SHALL разместить Language_Switcher в первой физической строке каждого существующего включённого Course_Chapter_File, Course_Index_File, Lab_README_File и пользовательского Lab_Solution_File на Locale из Required_Locale_Set.
2. WHEN ICA_Localization_Workflow создаёт или обновляет Language_Switcher для артефакта на Locale `XX`, THE ICA_Localization_Workflow SHALL включить ровно одну Markdown-ссылку на каждый доступный Localization_Equivalent того же Artifact_Identity, кроме варианта на Locale `XX`.
3. WHEN ICA_Localization_Workflow создаёт или обновляет Language_Switcher, THE ICA_Localization_Workflow SHALL упорядочить ссылки по Locale RU, EN, ES, FR, DE, GE, TW и JP, пропуская Locale текущего файла и отсутствующие Localization_Equivalent.
4. WHEN Language_Switcher содержит ссылку на RU, EN, ES, FR, DE, GE, TW или JP, THE ICA_Localization_Workflow SHALL использовать для такой ссылки соответственно подпись `Русская версия`, `Eng version`, `Versión en español`, `Version française`, `Deutsche Version`, `ქართული ვერსია`, `繁體中文版` или `日本語版`.
5. WHEN все восемь Localization_Equivalent включённого Artifact_Identity существуют, THE ICA_Localization_Workflow SHALL разместить в Language_Switcher каждого варианта ровно семь Markdown-ссылок.
6. WHEN Localization_Equivalent на Locale из Required_Locale_Set появляется или изменяет путь, THE ICA_Localization_Workflow SHALL обновить Language_Switcher каждого существующего Localization_Equivalent того же Artifact_Identity до проверки межфайловых ссылок.
7. IF Language_Switcher содержит повторяющуюся ссылку, ссылку на текущий Locale или ссылку, чей адрес не является относительным путём Localization_Equivalent того же Artifact_Identity, THEN THE ICA_Localization_Workflow SHALL записать ссылку как дефект в Artifact_Validation_Report.

### Требование 6: Согласованность ссылок главы, лабы и решения по Locale

**Пользовательская история:** Как читатель курса, я хочу, чтобы все связи между главой, лабой и решением сохраняли текущий Locale, чтобы теория, практика и решение образовывали единый локализованный маршрут.

#### Критерии приёмки

1. WHEN Course_Chapter_File на Locale `XX` содержит Lab_Reference и существует Localization_Equivalent Lab_README_File на Locale `XX`, THE ICA_Localization_Workflow SHALL направить Lab_Reference на относительный путь этого Localization_Equivalent.
2. WHEN Course_Index_File на Locale `XX` содержит Lab_Reference и существует Localization_Equivalent Lab_README_File на Locale `XX`, THE ICA_Localization_Workflow SHALL направить Lab_Reference на относительный путь этого Localization_Equivalent.
3. WHEN Lab_README_File на Locale `XX` содержит Chapter_Reference и существует Localization_Equivalent Course_Chapter_File на Locale `XX`, THE ICA_Localization_Workflow SHALL направить Chapter_Reference на относительный путь этого Localization_Equivalent.
4. WHEN Lab_README_File на Locale `XX` содержит Solution_Reference и существует пользовательский Localization_Equivalent Lab_Solution_File на Locale `XX`, THE ICA_Localization_Workflow SHALL направить Solution_Reference на относительный путь этого Localization_Equivalent.
5. WHEN для Chapter_Reference, Lab_Reference или Solution_Reference отсутствует Localization_Equivalent на Locale исходного файла, THE ICA_Localization_Workflow SHALL записать неразрешённую ссылку с путём источника, путём ожидаемой цели, Locale и типом ссылки в Artifact_Validation_Report.
6. IF Chapter_Reference, Lab_Reference или Solution_Reference из Locale `XX` указывает на локализованный артефакт с Locale, отличным от `XX`, и Localization_Equivalent на Locale `XX` существует, THEN THE ICA_Localization_Workflow SHALL классифицировать ссылку как дефект и направить ссылку на Localization_Equivalent на Locale `XX`.
7. WHEN исходный документ содержит несколько Chapter_Reference, Lab_Reference или Solution_Reference, THE ICA_Localization_Workflow SHALL проверить и записать результат для каждой ссылки независимо.

### Требование 7: Исполнение DAG через Kiro CLI и сабагентов

**Пользовательская история:** Как оператор Kiro CLI, я хочу получить детерминированный DAG с безопасно разделёнными задачами, чтобы запускать локализацию повторяемо и параллельно только там, где зависимости это позволяют.

#### Критерии приёмки

1. WHEN Localization_Manifest проходит проверку уникальности Inventory_Record и полноты Required_Locale_Set, THE ICA_Localization_Workflow SHALL создать DAG_Execution_Plan.
2. THE DAG_Execution_Plan SHALL определить один Validation_Node для инвентаризации, один узел разрешения области для каждого Artifact_Identity с неоднозначным Source_Artifact, один Localization_Node для каждого Missing_Localized_Artifact с однозначным Source_Artifact, один узел согласования Language_Switcher для каждого Artifact_Identity, один Validation_Node для межфайловых ссылок и один Validation_Node для итоговой полноты.
3. WHEN два Localization_Node имеют разные Output_Artifact и не имеют ребра зависимости, THE DAG_Execution_Plan SHALL пометить оба узла как допустимые для параллельного выполнения.
4. WHEN Validation_Node проверяет Chapter_Reference, Lab_Reference или Solution_Reference, THE DAG_Execution_Plan SHALL сделать Validation_Node зависимым от Localization_Node исходного артефакта и от Localization_Node требуемого Localization_Equivalent, если такой узел существует.
5. WHEN Localization_Node готов к выполнению, THE DAG_Execution_Plan SHALL назначить одному Translation_Subagent ровно один Source_Artifact, один Output_Artifact и один Locale.
6. THE DAG_Execution_Plan SHALL назначить каждому Output_Artifact не более одного Localization_Node.
7. THE DAG_Execution_Plan SHALL записать для каждого узла стабильный идентификатор, тип узла, входные пути, выходные пути, Locale, зависимости, категорию команды проверки и статус из набора `pending`, `running`, `passed`, `failed` или `blocked`.
8. IF Localization_Node завершается со статусом failed или blocked, THEN THE DAG_Execution_Plan SHALL установить статус blocked у каждого зависимого Validation_Node до успешного повторного завершения Localization_Node.

### Требование 8: Самопроверка и отчёт о готовности

**Пользовательская история:** Как сопровождающий ICA-материалы, я хочу получать детерминированный отчёт о структуре и локализованных ссылках, чтобы завершать работу только после проверяемого результата.

#### Критерии приёмки

1. WHEN Localization_Node завершает создание Output_Artifact, THE ICA_Localization_Workflow SHALL выполнить Self_Check_Process до установки статуса passed для Localization_Node.
2. WHEN Self_Check_Process проверяет Course_Chapter_File, THE Self_Check_Process SHALL сравнить Output_Artifact с Source_Artifact по последовательности уровней заголовков, числу и порядку блоков кода, таблиц и блоков диаграмм.
3. WHEN Self_Check_Process проверяет Lab_README_File или Lab_Solution_File, THE Self_Check_Process SHALL проверить наличие каждого Technical_Artifact Source_Artifact в Output_Artifact без изменения текста.
4. THE Self_Check_Process SHALL проверить, что каждый Language_Switcher находится в первой физической строке, содержит нормативные подписи и порядок, не содержит текущий Locale и содержит одну ссылку на каждый доступный Localization_Equivalent.
5. WHEN существуют все восемь Localization_Equivalent включённого Artifact_Identity, THE Self_Check_Process SHALL проверить, что Language_Switcher каждого варианта содержит ровно семь ссылок.
6. THE Self_Check_Process SHALL проверить каждый Chapter_Reference, Lab_Reference и Solution_Reference на соответствие Требованию 6.
7. WHEN Self_Check_Process обнаруживает несоответствие, THE ICA_Localization_Workflow SHALL записать в Artifact_Validation_Report путь артефакта, Locale, идентификатор требования, ожидаемое значение и наблюдаемое значение.
8. WHEN все узлы DAG_Execution_Plan достигают терминального статуса, THE ICA_Localization_Workflow SHALL создать итоговый Artifact_Validation_Report со снимком Localization_Manifest, статусом каждого узла, неразрешёнными ссылками, Missing_Localized_Artifact и дефектами.
9. IF итоговый Artifact_Validation_Report содержит Missing_Localized_Artifact или дефект для Locale из Required_Locale_Set, THEN THE ICA_Localization_Workflow SHALL пометить затронутый Artifact_Identity как неполный.

### Требование 9: Границы выполнения и применимость тестирования

**Пользовательская история:** Как владелец спецификации, я хочу сохранить чёткие границы автоматизированной работы, чтобы локализация не меняла нерелевантные материалы и не создавала неподходящие тесты.

#### Критерии приёмки

1. THE ICA_Localization_Workflow SHALL создавать и поддерживать requirements.md, design.md и tasks.md этой спецификации на русском языке.
2. THE ICA_Localization_Workflow SHALL ограничить будущие изменения локализации Output_Artifact, Language_Switcher и ссылками, явно записанными в Localization_Manifest и выбранными DAG_Execution_Plan.
3. WHEN Translation_Subagent выполняет Localization_Node, THE Translation_Subagent SHALL изменить только назначенный этому Localization_Node Output_Artifact.
4. WHEN Validation_Node выполняет проверку, THE ICA_Localization_Workflow SHALL использовать детерминированные проверки Inventory_Record, структуры артефакта, Language_Switcher и межфайловых ссылок как приёмочную проверку функции локализации документации.
5. THE ICA_Localization_Workflow SHALL классифицировать тестирование на основе свойств как неприменимое, поскольку локализованное содержимое Markdown и ссылки репозитория проверяются детерминированными проверками артефактов, а не переменным поведением программы.
6. IF инвентаризация обнаруживает файл вне выбранной области локализации, THEN THE ICA_Localization_Workflow SHALL записать файл как находящийся вне области без создания Localization_Node.
