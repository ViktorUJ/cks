Русский · [English](usage_scenarios.md) · [Español](usage_scenarios_ES.md) · [Français](usage_scenarios_FR.md) · [Deutsch](usage_scenarios_DE.md) · [ქართული](usage_scenarios_GE.md) · [繁體中文](usage_scenarios_TW.md) · [日本語](usage_scenarios_JP.md) · [На главную](../README_RU.MD)

<a id="usage"></a>

# Сценарии использования

<details>
<summary>Лабораторные CKA + CKAD и CKS: от запуска до проверки</summary>

1. Выберите работу в [каталоге лабораторных](labs.MD) и прочитайте её описание: `tasks/cka/labs/<номер>/README_RU.MD` либо `tasks/cks/labs/<номер>/README_RU.MD` для переведённых работ.
2. Проверьте `env.hcl`: регион, типы инстансов и параметры окружения. Если задаёте `ami_id` вручную, образ должен соответствовать региону и архитектуре инстанса; при автоматическом выборе следуйте настройкам сценария.
3. Создайте окружение: `TASK=101 make run_cka_task` либо `TASK=101 make run_cks_task`.
4. Найдите SSH-команду в выводе Terraform. В комплексных лабораторных работа обычно начинается на рабочей машине `worker`, а в отдельных сценариях - на control-plane-узле. Используйте адрес `worker_pc_ip`, `master_external_ip` или готовую команду подключения, которые выводит именно ваш сценарий.
5. Подключитесь пользователем `ubuntu`. При доступе по ключу используйте `ssh ubuntu@<IP> -i <путь_к_ключу>`; если окружение выводит пароль, подключитесь через `ssh ubuntu@<IP>` и введите пароль по запросу.
6. При необходимости проверьте завершение настройки на соответствующей машине: `tail -f /var/log/cloud-init-output.log`.
7. Выполните задания. В комплексных лабораторных запустите `check_result` на рабочей машине; ориентируйтесь на способ проверки в описании работы.
8. Разберите эталонное решение. Для лабораторной 101: [CKA + CKAD](../tasks/cka/labs/101/worker/files/solutions/1_RU.MD) и [CKS](../tasks/cks/labs/101/worker/files/solutions/1_RU.MD). У других работ расположение решения может отличаться - ссылка приведена в каталоге или описании.
9. Выполните предварительные действия из раздела удаления лабораторной и удалите окружение: `TASK=101 make delete_cka_task` либо `TASK=101 make delete_cks_task`.

Если нужен повторный запуск с очисткой локального каталога окружения, используйте `run_cka_task_clean` или `run_cks_task_clean`. Для удаления облачных ресурсов нужны команды `delete_*`.

</details>

<details>
<summary>Практические пробные экзамены CKA, CKAD, CKS, ICA и HR</summary>

Общий порядок работы:

1. Выберите номер экзамена и откройте его README в `tasks/<направление>/mock/<номер>/`.
2. При необходимости измените параметры в `env.hcl`: ОС (`ubuntu_version`), режим покупки EC2 (`spot` или `ondemand`) и типы инстансов, если эти параметры предусмотрены сценарием.
3. Запустите окружение соответствующей командой `TASK=<номер> make run_<направление>_mock`. Для запуска с очисткой локального каталога есть вариант `run_<направление>_mock_clean`.
4. Найдите `worker_pc_ip` или готовую SSH-команду в выводе Terraform и подключитесь к рабочей машине пользователем `ubuntu` с ключом либо паролем, указанным для этого окружения.
5. Откройте список заданий и работайте с рабочей машины. Для перехода на узел кластера используйте `ssh <имя_узла>` в соответствии с описанием экзамена.
6. Проверяйте оставшееся время командой `time_left`, а результат - командой `check_result`, если они предусмотрены окружением.
7. После попытки изучите решения и тесты по ссылкам ниже.
8. Удалите окружение командой `TASK=<номер> make delete_<направление>_mock`.

| Направление | Задания № 01 | Решения | Автоматические проверки |
|---|---|---|---|
| CKA | [Описание](../tasks/cka/mock/01) | [Решения](../tasks/cka/mock/01/worker/files/solutions) | [tests.bats](../tasks/cka/mock/01/worker/files/tests.bats) |
| CKAD | [Описание](../tasks/ckad/mock/01) | [Решения](../tasks/ckad/mock/01/worker/files/solutions) | [tests.bats](../tasks/ckad/mock/01/worker/files/tests.bats) |
| CKS | [Описание](../tasks/cks/mock/01) | [Решения](../tasks/cks/mock/01/worker/files/solutions) | [tests.bats](../tasks/cks/mock/01/worker/files/tests.bats) |
| ICA | [Описание](../tasks/ica/mock/01) | [Решения](../tasks/ica/mock/01/worker/files/solutions) | [Каталог тестов](../tasks/ica/mock/01/worker/files/tests) |
| HR | [Описание](../tasks/hr/mock/01) | [Решения](../tasks/hr/mock/01/worker/files/solutions) | [tests.bats](../tasks/hr/mock/01/worker/files/tests.bats) |

Видеоинструкции и разборы:

- CKA: [запуск пробного экзамена](https://www.youtube.com/watch?v=P-YYX4CTWIg), [решения экзамена № 01](https://youtu.be/IZsqAPpbBxM).
- CKS: [запуск пробного экзамена](https://youtu.be/_GbsBOMaJ9Q), [разбор решений](https://youtu.be/I8CPwcGbrG8).
- CKAD: [запуск пробного экзамена](https://youtu.be/7X4Y9QhbTsk), [разбор решений](https://youtu.be/yQK7Ca8d-yw).
- HR: [видео по работе со сценарием](https://youtu.be/4CTC1jl8lxE).

</details>

<details>
<summary>Amazon EKS: работа с лабораторной</summary>

1. Выберите номер в [каталоге EKS](labs.MD#eks-labs) и прочитайте описание работы.
2. Проверьте настройки `env.hcl`, затем выполните `TASK=101 make run_eks_task`, подставив номер выбранной лабораторной.
3. Найдите адрес рабочей машины `worker_pc_ip` или SSH-команду в выводе Terraform. Подключитесь пользователем `ubuntu` с ключом либо паролем согласно описанию работы.
4. Выполните задания и проверку результата. В комплексных лабораторных доступна команда `check_result`.
5. Изучите решение по ссылке из описания или каталога. Например, [решение лабораторной 101](../tasks/eks/labs/101/worker/files/solutions/1_RU.MD).
6. Выполните предварительную очистку из раздела удаления работы, затем запустите `TASK=101 make delete_eks_task` с нужным номером.

</details>

Другие сценарии: [лабораторные Istio / ICA](../tasks/ica/README_RU.MD), [пробный экзамен LFCS № 01](../tasks/lfcs/mock/01), [тестовые материалы KCSA](../tasks/kcsa/README_RU.md), [мок-экзамен KCNA № 01](../tasks/kcna/mock/01/README.MD) и [мок-экзамен AWS Certified AI Practitioner № 01](../tasks/aws_AI_practitioner/mock/01/README.MD).
