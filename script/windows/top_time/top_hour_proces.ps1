param(
    [int]$SinceHours = 24,        # how many hours back to look
    [int]$Top = 10,               # top N apps in output
    [string]$ExportCsv = ""       # optional CSV export path
)

# ============================== helpers ==============================
function Parse468xEvent {
    param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)
    # Parse event XML and flatten EventData into a dictionary (safe for PS 5.1)
    $xml = [xml]$Event.ToXml()
    $data = @{}

    foreach ($d in $xml.Event.EventData.Data) {
        $name = $d.name
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $data[$name] = $d.'#text'
        }
    }

    # Normalize common fields (4688/4689 have slightly different names)
    $procId = $null
    if ($data.ContainsKey('NewProcessId') -and $data['NewProcessId']) {
        $procId = $data['NewProcessId']
    } elseif ($data.ContainsKey('ProcessId')) {
        $procId = $data['ProcessId']
    }

    $procNameFull = $null
    if ($data.ContainsKey('NewProcessName') -and $data['NewProcessName']) {
        $procNameFull = $data['NewProcessName']
    } elseif ($data.ContainsKey('ProcessName')) {
        $procNameFull = $data['ProcessName']
    }

    $procNameLeaf = $null
    if ($procNameFull) {
        $procNameLeaf = (Split-Path -Leaf $procNameFull)
    }

    $parentName = $null
    if ($data.ContainsKey('ParentProcessName')) {
        $parentName = $data['ParentProcessName']
    }

    $subjectUser = $null
    if ($data.ContainsKey('SubjectUserName')) {
        $subjectUser = $data['SubjectUserName']
    }

    $subjectDomain = $null
    if ($data.ContainsKey('SubjectDomainName')) {
        $subjectDomain = $data['SubjectDomainName']
    }

    $cmdLine = $null
    if ($data.ContainsKey('CommandLine')) {
        $cmdLine = $data['CommandLine']
    }

    $procGuid = $null
    if ($data.ContainsKey('ProcessGuid')) {
        $procGuid = $data['ProcessGuid']
    }

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
        CommandLine       = $cmdLine
    }
}

function IsWantedProcess {
    param($rec)

    # 1) Exclude obvious system/service things
    $sysUsers = @('SYSTEM','LOCAL SERVICE','NETWORK SERVICE')
    if ($rec.SubjectUser -and ($sysUsers -contains $rec.SubjectUser)) { return $false }

    if ($rec.ParentProcessName -and ($rec.ParentProcessName -match '(^|\\)services\.exe$')) { return $false }

    if ($rec.ProcessNameFull) {
        $win32 = [Regex]::Escape("$env:WINDIR\System32")
        if ($rec.ProcessNameFull -match $win32) { return $false }
    }

    if (-not $rec.ProcessNameLeaf) { return $false }

    # 2) Allowlist: browsers and game launchers (extend as needed)
    $name = $rec.ProcessNameLeaf.ToLower()
    $browsers = @(
        'chrome.exe','msedge.exe','firefox.exe','opera.exe',
        'vivaldi.exe','brave.exe','yandex.exe'
    )
    $launchers = @(
        'steam.exe','epicgameslauncher.exe','battle.net.exe','riotclient.exe','goggalaxy.exe'
    )

    if ($browsers -contains $name) { return $true }
    if ($launchers -contains $name) { return $true }

    # 3) Heuristic for direct game executables by install path
    if ($rec.ProcessNameFull) {
        $full = $rec.ProcessNameFull.ToLower()
        if ($full -match 'steamapps\\common' -or
            $full -match '^d:\\games' -or
            $full -match '^c:\\games') {
            return $true
        }
    }

    return $false
}

function Summarize-Durations {
    param($instances, $top)

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

    $rows | Sort-Object TotalMin -Descending | Select-Object -First $top
}

# ============================== main ==============================
$since = (Get-Date).AddHours(-1 * $SinceHours)
$now = Get-Date

$startEvents = @()
$endEvents   = @()
$eventQueryWorked = $true

try {
    # Security 4688 = process creation (we filter here to wanted apps only)
    $startEvents = Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4688; StartTime=$since } -ErrorAction Stop |
        ForEach-Object { Parse468xEvent $_ } |
        Where-Object { IsWantedProcess $_ }

    # Security 4689 = process termination (no filter yet; used for matching)
    $endEvents = Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4689; StartTime=$since } -ErrorAction Stop |
        ForEach-Object { Parse468xEvent $_ }
}
catch {
    Write-Verbose "Falling back: Security log not available or access denied. $_"
    $eventQueryWorked = $false
}

$instances = @()

if ($eventQueryWorked -and $startEvents.Count -gt 0) {
    # Build lookups for termination events
    $endsByGuid = @{}
    foreach ($e in ($endEvents | Where-Object { $_.ProcessGuid })) {
        if (-not $endsByGuid.ContainsKey($e.ProcessGuid)) { $endsByGuid[$e.ProcessGuid] = @() }
        $endsByGuid[$e.ProcessGuid] += ,$e
    }
    foreach ($k in @($endsByGuid.Keys)) {
        $endsByGuid[$k] = $endsByGuid[$k] | Sort-Object TimeCreated
    }

    $endsByPid = @{}
    foreach ($e in $endEvents) {
        $key = "$($e.Computer)|$($e.ProcessId)"
        if (-not $endsByPid.ContainsKey($key)) { $endsByPid[$key] = @() }
        $endsByPid[$key] += ,$e
    }
    foreach ($k in @($endsByPid.Keys)) {
        $endsByPid[$k] = $endsByPid[$k] | Sort-Object TimeCreated
    }

    foreach ($s in $startEvents) {
        $startTime = $s.TimeCreated
        $endTime = $null

        # Prefer match by ProcessGuid
        if ($s.ProcessGuid -and $endsByGuid.ContainsKey($s.ProcessGuid)) {
            $cand = $endsByGuid[$s.ProcessGuid] | Where-Object { $_.TimeCreated -ge $startTime } | Select-Object -First 1
            if ($cand) { $endTime = $cand.TimeCreated }
        }

        # Fallback: match by (Computer|PID)
        if (-not $endTime -and $s.ProcessId) {
            $key = "$($s.Computer)|$($s.ProcessId)"
            if ($endsByPid.ContainsKey($key)) {
                $cand = $endsByPid[$key] | Where-Object { $_.TimeCreated -ge $startTime } | Select-Object -First 1
                if ($cand) { $endTime = $cand.TimeCreated }
            }
        }

        if (-not $endTime) { $endTime = $now }

        $duration = ($endTime - $startTime).TotalMinutes
        if ($duration -lt 0) { $duration = 0 }

        $procName = $s.ProcessNameLeaf
        if (-not $procName) { $procName = $s.ProcessNameFull }

        $userStr = $s.SubjectUser
        if ($s.SubjectDomain) { $userStr = "$($s.SubjectDomain)\$($s.SubjectUser)" }

        $instances += [PSCustomObject]@{
            ProcessName = $procName
            Start       = $startTime
            End         = $endTime
            DurationMin = $duration
            User        = $userStr
            Source      = "SecurityLog"
        }
    }
}
else {
    # Fallback: running-process snapshot (approximate, only still-alive processes)
    try {
        $procs = Get-Process -ErrorAction Stop | Where-Object { $_.StartTime -ge $since -and $_.SessionId -ne 0 }
        foreach ($p in $procs) {
            $full = ""
            $leaf = ""
            try { $full = ($p.Path) } catch { $full = "" }
            if (-not $full -or $full -eq "") { $full = "$($p.ProcessName).exe" }
            $leaf = (Split-Path -Leaf $full)

            # Build a fake record to reuse the same filter
            $fakeRec = [PSCustomObject]@{
                SubjectUser       = $null
                ParentProcessName = $null
                ProcessNameFull   = $full
                ProcessNameLeaf   = $leaf
            }
            if (-not (IsWantedProcess $fakeRec)) { continue }

            $end = Get-Date
            if ($p.HasExited) { $end = $p.ExitTime }

            $instances += [PSCustomObject]@{
                ProcessName = $leaf
                Start       = $p.StartTime
                End         = $end
                DurationMin = (($end - $p.StartTime).TotalMinutes)
                User        = ""
                Source      = "Snapshot"
            }
        }
    }
    catch {
        Write-Error "Cannot read process list: $_"
        return
    }
}

# Aggregate and print Top N
$topRows = Summarize-Durations -instances $instances -top $Top
$topRows | Format-Table -AutoSize

# Optional export
if ($ExportCsv -and $ExportCsv.Trim()) {
    try {
        $topRows | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Saved summary to: $ExportCsv"
    }
    catch {
        Write-Warning "Failed to export CSV to '$ExportCsv': $_"
    }
}

# Footer with context
$mode = "Running-process snapshot (approximate)"
if ($eventQueryWorked -and $startEvents.Count -gt 0) { $mode = "Security 4688/4689 (accurate)" }
Write-Host ("Mode: {0}. Window: {1:g} .. {2:g}" -f $mode, $since, $now)
