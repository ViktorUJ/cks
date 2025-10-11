param(
    [int]$SinceHours = 24,                 # fallback duration if -Hours not provided
    [int]$Top = 0,                         # 0 = show all; otherwise top N rows
    [string]$ExportCsv = "",               # optional CSV export path (overall)
    [string]$ExportDailyCsv = "",          # optional CSV export path (daily breakdown)
    [ValidateSet('browsers','browsers+games')]
    [string]$Mode = 'browsers+games',      # report mode
    [datetime]$Start,                      # optional absolute window start (local time)
    [int]$Hours = 0,                       # optional duration in hours; if 0 -> use SinceHours
    [int]$RetentionDays = 0                # if >0, estimate & set Security log size to retain at least N days
)

# ============================== config ==============================
$IgnoreNames = @('openvpn.exe','openvpn-gui.exe')

$BrowserNames = @(
    'chrome.exe','msedge.exe','firefox.exe','opera.exe',
    'vivaldi.exe','brave.exe','yandex.exe'
)

$GameLaunchers = @(
    'battle.net.exe','agent.exe','steam.exe','epicgameslauncher.exe',
    'riotclientservices.exe','goggalaxy.exe','origin.exe',
    'eaapp.exe','ubisoftconnect.exe'
)

$KnownGameExe = @(
    'sc2_x64.exe','sc2switcher_x64.exe','starcraft.exe','starcraft ii.exe'
)

# ============================== helpers ==============================
function Parse468xEvent {
    param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)
    $xml = [xml]$Event.ToXml()
    $data = @{}
    foreach ($d in $xml.Event.EventData.Data) {
        $name = $d.name
        if (-not [string]::IsNullOrWhiteSpace($name)) { $data[$name] = $d.'#text' }
    }

    $procId = $null
    if ($data.ContainsKey('NewProcessId') -and $data['NewProcessId']) { $procId = $data['NewProcessId'] }
    elseif ($data.ContainsKey('ProcessId')) { $procId = $data['ProcessId'] }

    $procNameFull = $null
    if ($data.ContainsKey('NewProcessName') -and $data['NewProcessName']) { $procNameFull = $data['NewProcessName'] }
    elseif ($data.ContainsKey('ProcessName')) { $procNameFull = $data['ProcessName'] }

    $procNameLeaf = $null
    if ($procNameFull) { $procNameLeaf = (Split-Path -Leaf $procNameFull) }

    $parentName = $null
    if ($data.ContainsKey('ParentProcessName')) { $parentName = $data['ParentProcessName'] }

    $subjectUser = $null
    if ($data.ContainsKey('SubjectUserName')) { $subjectUser = $data['SubjectUserName'] }

    $subjectDomain = $null
    if ($data.ContainsKey('SubjectDomainName')) { $subjectDomain = $data['SubjectDomainName'] }

    $procGuid = $null
    if ($data.ContainsKey('ProcessGuid')) { $procGuid = $data['ProcessGuid'] }

    [PSCustomObject]@{
        TimeCreated       = $Event.TimeCreated
        Id                = $Event.Id
        Computer          = $Event.MachineName
        ProcessGuid       = $procGuid
        ProcessId         = $procId
        ProcessNameFull   = $procNameFull
        ProcessNameLeaf   = $procNameLeaf
        ParentProcessName = $parentName
        SubjectUser       = $subjectUser
        SubjectDomain     = $subjectDomain
    }
}

function IsWindowsStandard {
    param($rec)
    if (-not $rec) { return $true }
    $sysUsers = @('SYSTEM','LOCAL SERVICE','NETWORK SERVICE')
    if ($rec.SubjectUser -and ($sysUsers -contains $rec.SubjectUser)) { return $true }
    if ($rec.ParentProcessName -and ($rec.ParentProcessName -match '(^|\\)services\.exe$')) { return $true }
    if ($rec.ProcessNameFull) {
        $winRoot = [Regex]::Escape("$env:WINDIR").ToLower()
        $full = $rec.ProcessNameFull.ToLower()
        if ($full -match "^$winRoot\\") { return $true }
    }
    return $false
}

function IsIgnored {
    param([string]$NameLower, [string[]]$IgnoreList)
    if (-not $NameLower) { return $false }
    foreach ($n in $IgnoreList) { if ($NameLower -eq ($n.ToLower())) { return $true } }
    return $false
}

function IsWantedName {
    param([string]$LeafLower, [string]$Mode)
    if (-not $LeafLower) { return $false }
    $browserSet  = $BrowserNames  | ForEach-Object { $_.ToLower() }
    $gameSet     = $KnownGameExe  | ForEach-Object { $_.ToLower() }
    $launcherSet = $GameLaunchers | ForEach-Object { $_.ToLower() }

    $isBrowser  = $browserSet  -contains $LeafLower
    if ($Mode -eq 'browsers') { return $isBrowser }

    $isGameExe  = $gameSet     -contains $LeafLower
    $isLauncher = $launcherSet -contains $LeafLower
    return ($isBrowser -or $isGameExe -or $isLauncher)
}

function ParentIsLauncher {
    param($rec)
    if (-not $rec.ParentProcessName) { return $false }
    $launcherSet = $GameLaunchers | ForEach-Object { $_.ToLower() }
    $parentLeaf = (Split-Path -Leaf $rec.ParentProcessName).ToLower()
    return ($launcherSet -contains $parentLeaf)
}

function Summarize-Durations {
    param($instances, [int]$top)
    $byName = $instances | Group-Object ProcessName
    $rows = foreach ($g in $byName) {
        $sum = ($g.Group | Measure-Object DurationMin -Sum).Sum
        [PSCustomObject]@{
            Name      = $g.Name
            Sessions  = $g.Count
            TotalMin  = [math]::Round($sum, 2)
            TotalHrs  = [math]::Round($sum / 60, 2)
        }
    }
    $rows = $rows | Sort-Object -Property TotalMin -Descending
    if ($top -gt 0) { return $rows | Select-Object -First $top }
    return $rows
}

# split one usage interval across calendar days
function Split-Instance-ByDay {
    param([datetime]$Start, [datetime]$End, [string]$ProcessName)

    $fragments = @()
    if ($End -le $Start) { return $fragments }

    $curStart = $Start
    while ($curStart -lt $End) {
        $dayEnd = ($curStart.Date).AddDays(1)
        if ($dayEnd -gt $End) { $dayEnd = $End }
        $durMin = ($dayEnd - $curStart).TotalMinutes
        $fragments += [PSCustomObject]@{
            Day         = $curStart.Date
            ProcessName = $ProcessName
            DurationMin = $durMin
        }
        $curStart = $dayEnd
    }
    return $fragments
}

function Summarize-Durations-ByDay {
    param($instances, [int]$top)

    # explode into daily fragments
    $frags = @()
    foreach ($i in $instances) {
        $frags += Split-Instance-ByDay -Start $i.Start -End $i.End -ProcessName $i.ProcessName
    }

    # aggregate per day+process
    $grp = $frags | Group-Object { "{0:yyyy-MM-dd}|{1}" -f $_.Day, $_.ProcessName }

    $rows = @()
    foreach ($g in $grp) {
        $parts = $g.Name -split '\|', 2
        $dayStr = $parts[0]
        $pname = $parts[1]
        $sum = ($g.Group | Measure-Object DurationMin -Sum).Sum
        $rows += [PSCustomObject]@{
            Day       = [datetime]::ParseExact($dayStr,'yyyy-MM-dd',$null)
            Name      = $pname
            TotalMin  = [math]::Round($sum,2)
            TotalHrs  = [math]::Round($sum/60,2)
        }
    }

    # sort safely in a separate statement (PS 5.1-friendly)
    $rows = $rows | Sort-Object -Property Day, @{Expression='TotalMin'; Descending=$true}

    if ($top -gt 0) {
        # take top-N per day
        $byDay = $rows | Group-Object Day
        $limited = @()
        foreach ($d in $byDay) {
            $limited += ($d.Group | Sort-Object -Property TotalMin -Descending | Select-Object -First $top)
        }
        return $limited
    }
    return $rows
}

# --- Retention estimator: set Security log max size to keep ~N days ---
function Ensure-SecurityLogRetentionDays {
    param([int]$Days, [double]$SafetyFactor = 1.3, [int]$SampleEvents = 5000)

    if ($Days -le 0) { return }
    Write-Host "Estimating Security log size for ~$Days days..."

    try {
        $events = Get-WinEvent -LogName Security -MaxEvents $SampleEvents -ErrorAction Stop
        if (-not $events -or $events.Count -eq 0) {
            Write-Warning "No events sampled; skipping size estimation."
            return
        }

        $totalLen = 0
        foreach ($ev in $events) { $totalLen += ($ev.ToXml()).Length }
        $avgSize = [math]::Max([double]($totalLen / $events.Count), 900.0)

        $minTime = ($events | Measure-Object TimeCreated -Minimum).Minimum
        $maxTime = ($events | Measure-Object TimeCreated -Maximum).Maximum
        $spanSec = [math]::Max((New-TimeSpan -Start $minTime -End $maxTime).TotalSeconds, 1)
        $ratePerSec = $events.Count / $spanSec

        $bytesPerDay = [double]$avgSize * $ratePerSec * 86400.0
        $sizeBytes = [long]([math]::Ceiling($bytesPerDay * $Days * $SafetyFactor))
        if ($sizeBytes -lt 134217728) { $sizeBytes = 134217728 } # >=128MB

        wevtutil sl Security /ms:$sizeBytes | Out-Null
        Write-Host ("Security log size set to ~{0} MB" -f [math]::Round($sizeBytes/1MB,0))
    }
    catch {
        Write-Warning "Failed to estimate or set Security log size: $_"
    }
}

# ============================== window ==============================
$windowStart = if ($PSBoundParameters.ContainsKey('Start')) { Get-Date $Start } else { (Get-Date).AddHours(-1 * $SinceHours) }
$durationHrs = if ($Hours -gt 0) { $Hours } else { $SinceHours }
$windowEnd   = $windowStart.AddHours($durationHrs)

if ($RetentionDays -gt 0) { Ensure-SecurityLogRetentionDays -Days $RetentionDays }

# ============================== main ==============================
$startEvents = @()
$endEvents   = @()
$eventQueryWorked = $true

try {
    $startEvents = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security'
        Id        = 4688
        StartTime = $windowStart
        EndTime   = $windowEnd
    } -ErrorAction Stop |
        ForEach-Object { Parse468xEvent $_ } |
        Where-Object { -not (IsWindowsStandard $_) }

    $endEvents = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security'
        Id        = 4689
        StartTime = $windowStart
        EndTime   = $windowEnd
    } -ErrorAction Stop |
        ForEach-Object { Parse468xEvent $_ }
}
catch {
    Write-Verbose "Falling back: Security log not available or access denied. $_"
    $eventQueryWorked = $false
}

$startEvents = $startEvents | Where-Object {
    $leafLower = if ($_.ProcessNameLeaf) { $_.ProcessNameLeaf.ToLower() } else { "" }
    $wantedByName   = IsWantedName -LeafLower $leafLower -Mode $Mode
    $wantedByParent = ParentIsLauncher $_
    $notIgnored     = -not (IsIgnored -NameLower $leafLower -IgnoreList $IgnoreNames)
    ($notIgnored -and ($wantedByName -or $wantedByParent))
}

$instances = @()

if ($eventQueryWorked -and $startEvents.Count -gt 0) {
    $endsByGuid = @{}
    foreach ($e in ($endEvents | Where-Object { $_.ProcessGuid })) {
        if (-not $endsByGuid.ContainsKey($e.ProcessGuid)) { $endsByGuid[$e.ProcessGuid] = @() }
        $endsByGuid[$e.ProcessGuid] += ,$e
    }
    foreach ($k in @($endsByGuid.Keys)) { $endsByGuid[$k] = $endsByGuid[$k] | Sort-Object -Property TimeCreated }

    $endsByPid = @{}
    foreach ($e in $endEvents) {
        $key = "$($e.Computer)|$($e.ProcessId)"
        if (-not $endsByPid.ContainsKey($key)) { $endsByPid[$key] = @() }
        $endsByPid[$key] += ,$e
    }
    foreach ($k in @($endsByPid.Keys)) { $endsByPid[$k] = $endsByPid[$k] | Sort-Object -Property TimeCreated }

    foreach ($s in $startEvents) {
        $startTime = $s.TimeCreated
        $endTime = $null

        if ($s.ProcessGuid -and $endsByGuid.ContainsKey($s.ProcessGuid)) {
            $cand = $endsByGuid[$s.ProcessGuid] | Where-Object { $_.TimeCreated -ge $startTime } | Select-Object -First 1
            if ($cand) { $endTime = $cand.TimeCreated }
        }

        if (-not $endTime -and $s.ProcessId) {
            $key = "$($s.Computer)|$($s.ProcessId)"
            if ($endsByPid.ContainsKey($key)) {
                $cand = $endsByPid[$key] | Where-Object { $_.TimeCreated -ge $startTime } | Select-Object -First 1
                if ($cand) { $endTime = $cand.TimeCreated }
            }
        }

        if (-not $endTime) { $endTime = $windowEnd }

        $duration = ($endTime - $startTime).TotalMinutes
        if ($duration -lt 0) { $duration = 0 }

        $procName = $s.ProcessNameLeaf
        if (-not $procName) { $procName = $s.ProcessNameFull }

        $instances += [PSCustomObject]@{
            ProcessName = $procName
            Start       = $startTime
            End         = $endTime
            DurationMin = $duration
            Source      = "SecurityLog"
        }
    }
}
else {
    # Fallback: still-alive processes only
    try {
        $procs = Get-Process -ErrorAction Stop | Where-Object { $_.StartTime -lt $windowEnd -and $_.StartTime -ge $windowStart -and $_.SessionId -ne 0 }
        foreach ($p in $procs) {
            $leaf = "$($p.ProcessName).exe"
            $leafLower = $leaf.ToLower()

            $wantedByName = IsWantedName -LeafLower $leafLower -Mode $Mode
            $notIgnored   = -not (IsIgnored -NameLower $leafLower -IgnoreList $IgnoreNames)
            if (-not ($wantedByName -and $notIgnored)) { continue }

            $end = Get-Date
            if ($end -gt $windowEnd) { $end = $windowEnd }

            $instances += [PSCustomObject]@{
                ProcessName = $leaf
                Start       = $p.StartTime
                End         = $end
                DurationMin = (($end - $p.StartTime).TotalMinutes)
                Source      = "Snapshot"
            }
        }
    }
    catch {
        Write-Error "Cannot read process list: $_"
        return
    }
}

# ---- Overall summary
$overall = Summarize-Durations -instances $instances -top $Top
$overall | Format-Table -AutoSize

if ($ExportCsv -and $ExportCsv.Trim()) {
    try {
        $overall | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Saved summary to: $ExportCsv"
    }
    catch {
        Write-Warning "Failed to export CSV to '$ExportCsv': $_"
    }
}

# ---- Daily breakdown if window spans > 24h
$spanHours = ($windowEnd - $windowStart).TotalHours
if ($spanHours -gt 24) {
    $daily = Summarize-Durations-ByDay -instances $instances -top $Top

    Write-Host ""
    Write-Host "Daily breakdown:"
    $days = $daily | Group-Object Day
    foreach ($d in $days) {
        Write-Host ("`n{0:yyyy-MM-dd}" -f $d.Name) -ForegroundColor Cyan
        $t = $d.Group | Select-Object @{n='Name';e={$_.Name}},
                                  @{n='TotalMin';e={$_.TotalMin}},
                                  @{n='TotalHrs';e={$_.TotalHrs}}
        $t | Format-Table -AutoSize
    }

    if ($ExportDailyCsv -and $ExportDailyCsv.Trim()) {
        try {
            $daily |
                Select-Object @{n='Day';e={$_.Day.ToString('yyyy-MM-dd')}}, Name, TotalMin, TotalHrs |
                Export-Csv -Path $ExportDailyCsv -NoTypeInformation -Encoding UTF8
            Write-Host "Saved daily breakdown to: $ExportDailyCsv"
        }
        catch {
            Write-Warning "Failed to export Daily CSV to '$ExportDailyCsv': $_"
        }
    }
}

$modeStr = if ($eventQueryWorked -and $startEvents.Count -gt 0) { "Security 4688/4689 (accurate)" } else { "Running-process snapshot (approximate)" }
Write-Host ("Mode: {0}. Window: {1:g} .. {2:g}" -f $modeStr, $windowStart, $windowEnd)
