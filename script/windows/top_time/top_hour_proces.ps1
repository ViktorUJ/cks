param(
    [int]$SinceHours = 24,        # how many hours back to look
    [int]$Top = 10,               # top N programs
    [string]$ExportCsv = ""       # optional path to export CSV summary
)

# ------------------------------ helpers ------------------------------
function Parse468xEvent {
    param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)

    # Parse event XML and flatten EventData to a dictionary safely
    $xml = [xml]$Event.ToXml()
    $data = @{}

    foreach ($d in $xml.Event.EventData.Data) {
        $name = $d.name
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $data[$name] = $d.'#text'
        }
    }

    # Select fields with fallback for 4688/4689 naming differences
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

function IsUserProcess4688 {
    param($rec)
    # Exclude obvious services/system accounts and service controller parent
    $sysUsers = @('SYSTEM','LOCAL SERVICE','NETWORK SERVICE')
    $isSysUser = $false
    if ($rec.SubjectUser) { $isSysUser = $sysUsers -contains ($rec.SubjectUser) }

    $parentIsServices = $false
    if ($rec.ParentProcessName) { $parentIsServices = $rec.ParentProcessName -match '(^|\\)services\.exe$' }

    $inSystem32 = $false
    if ($rec.ProcessNameFull) { $inSystem32 = $rec.ProcessNameFull -match [Regex]::Escape("$env:WINDIR\System32") }

    return -not ($isSysUser -or $parentIsServices -or $inSystem32)
}

function Summarize-Durations {
    param($instances, $top)

    $byName = $instances | Group-Object ProcessName
    $rows = foreach ($g in $byName) {
        $sum = ($g.Group | Measure-Object DurationMin -Sum).Sum
        [PSCustomObject]@{
            Name      = $g.Name
            Sessions  = $g.Count
            TotalMin  = [math]::Round($sum,2)
            TotalHrs  = [math]::Round($sum/60,2)
        }
    }

    $rows | Sort-Object TotalMin -Descending | Select-Object -First $top
}

# ------------------------------ main ------------------------------
$since = (Get-Date).AddHours(-1 * $SinceHours)
$now = Get-Date

$startEvents = @()
$endEvents   = @()
$eventQueryWorked = $true

try {
    # 4688 = process creation, 4689 = process termination
    $startEvents = Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4688; StartTime=$since } -ErrorAction Stop |
        ForEach-Object { Parse468xEvent $_ } |
        Where-Object { IsUserProcess4688 $_ }

    $endEvents = Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4689; StartTime=$since } -ErrorAction Stop |
        ForEach-Object { Parse468xEvent $_ }
}
catch {
    Write-Verbose "Falling back: Security log not available or access denied. $_"
    $eventQueryWorked = $false
}

$instances = @()

if ($eventQueryWorked -and $startEvents.Count -gt 0) {

    # Build lookups for ends (by GUID and by PID)
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
    # Fallback: snapshot of currently running user processes (SessionId != 0)
    try {
        $procs = Get-Process -ErrorAction Stop | Where-Object { $_.StartTime -ge $since -and $_.SessionId -ne 0 }
        foreach ($p in $procs) {
            $end = $now
            if ($p.HasExited) { $end = $p.ExitTime }
            $instances += [PSCustomObject]@{
                ProcessName = "$($p.ProcessName).exe"
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

# Aggregate and show Top N
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

$mode = "Running-process snapshot (approximate)"
if ($eventQueryWorked -and $startEvents.Count -gt 0) { $mode = "Security 4688/4689 (accurate)" }
Write-Host ("Mode: {0}. Window: {1:g} .. {2:g}" -f $mode, $since, $now)
