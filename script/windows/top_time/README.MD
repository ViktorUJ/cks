```` 
auditpol /get /subcategory:"Process Creation","Process Termination"

auditpol /set /subcategory:"Process Creation"   /success:enable /failure:enable
auditpol /set /subcategory:"Process Termination" /success:enable /failure:enable

reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit `
  /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f


````


``` 
# Последние 72 часа, с разбивкой по суткам, экспорт обоих отчётов
powershell -ExecutionPolicy Bypass -File .\top_hour_proces.ps1 -SinceHours 72 -Top 0 `
  -ExportCsv ".\summary.csv" -ExportDailyCsv ".\daily.csv"

# Окно: с 2025-09-15 00:00 на 48 часов, только браузеры
powershell -ExecutionPolicy Bypass -File .\top_hour_proces.ps1 -Start "2025-09-15" -Hours 48 -Mode browsers -Top 0



```

```
Name                   Sessions TotalMin TotalHrs
----                   -------- -------- --------
chrome.exe                   13  2406,53    40,11
RuntimeBroker.exe             9  2093,97     34,9
slack.exe                     7  1697,22    28,29
svchost.exe                   6  1375,03    22,92
OpenVPNConnect.exe            4   970,01    16,17
conhost.exe                   4   734,31    12,24
taskhostw.exe                 2   485,67     8,09
unsecapp.exe                  2   485,46     8,09
backgroundTaskHost.exe        2   479,25     7,99
csrss.exe                     1   242,93     4,05

```