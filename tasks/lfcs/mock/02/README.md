# Allowed resources

## **Linux Foundation Certified System Administrator (LFCS) :**

- Man pages
- Documents installed by the distribution (i.e. /usr/share and its subdirectories)
- Packages that are part of the distribution (may also be installed by Candidate if not available by default)
- If you decide to install packages (not required to complete tasks) to your exam environment, you will want to be familiar with standard package managers (apt, dpkg, dnf, and yum).

## Questions

|        **1**        | **Create hard and soft links to the file `file1`**                                                                                                                                                                     |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                                                                                     |
|        Task         | - Create a hard link from file `file1` in your home directory to `/opt/file1`<br/>- Create a soft link from `file1` in your home directory to `/opt/softlinkfile`.<br/>  - Soft link should point to the absloute path |
| Acceptance criteria | <br/> - Hard and soft links are created?                                                                                                                                                                               |

---
1. Git. Перейти в папку. Добавить файл. Сделать изменения в файле и закомитить.
2. Найти процесс который использует много IO, убить его и отключить папку, которую процесс использовал.
3. Зашарить NFS ресурс на сервере.
4. Создать виртуальную машину с заданными параметрами.
5. Netfilter. Закрыть порт. Перенаправить траффик с одного порта на другой на локальной машине. Сохранить изменения и сделать их persistent.
6. Прочитать содержимое сертификата и в зависимости от условия (к примеру, используемый метод шифрования, переместить сертификат в соответствующую папку). Или можно, например, дать 4 файла: два сертификата и два приватных ключа. Найти сертификат, где используется шифрование 4096 бита, а остальные файлы удалить.
7. Изменить размер существующей LVM. 
8. Добавить пользователя. Дать пользователю права на выполнение sudo bash /root/script.sh без необходимости вводить пароль рута.
9. Настройка параметров ядра Linux. К примеру, включить net.ipv6.conf.all.forwarding.
12. Найти процесс, который слушает на каком-то порту и убить его.
13. Сконфигурировать swap. Использовать папку /fileforswap для swap.
14. Исправить ошибку в Dockerfile. Создать образ из файла. Создать контейнер из образа. Обновить какую-то настройку у бегущего контейнера.
15. Найти подмонтированную папку из 3, которая занимает больше всего места и удалить самый тяжелый файл из этой папки.
16. Build and install from source. Инсталировать программу из source.
17. Сконфигурировать openssh. Включить/выключить какую-то глобальную настройку и потом включить/выключить какую-то настройку только для одного-двух пользователей.
18. Настроить bridge между двумя сетевыми интерфейсями. 
