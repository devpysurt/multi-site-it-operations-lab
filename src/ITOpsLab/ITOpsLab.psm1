Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LabWorkstationData {
    <# .SYNOPSIS
    Collect local Windows information without changing workstation settings.
    Each collector fails independently; unavailable data is never reported as healthy.
    #>
    [CmdletBinding()]
    param([ValidateNotNullOrEmpty()][string[]]$ServiceNames = @('Spooler', 'wuauserv'))
    if (-not $IsWindows) { throw 'Live collection requires Windows. Use the -Demo entry point on other systems.' }
    $issues = [System.Collections.Generic.List[object]]::new()
    $os = $null; $memoryGB = $null; $disks = @(); $adapters = @(); $services = @()
    try {
        $raw = Get-CimInstance -ClassName Win32_OperatingSystem -OperationTimeoutSec 20 -ErrorAction Stop
        $os = [pscustomobject]@{
            Caption = $raw.Caption; Version = $raw.Version
            LastBootUtc = $raw.LastBootUpTime.ToUniversalTime().ToString('o')
        }
    } catch { $issues.Add([pscustomobject]@{ Section = 'OperatingSystem'; Message = $_.Exception.Message }) }
    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -OperationTimeoutSec 20 -ErrorAction Stop
        $memoryGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
    } catch { $issues.Add([pscustomobject]@{ Section = 'Memory'; Message = $_.Exception.Message }) }
    try {
        $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -OperationTimeoutSec 20 -ErrorAction Stop |
            ForEach-Object { [pscustomobject]@{
                Name = $_.DeviceID; SizeGB = [math]::Round($_.Size / 1GB, 2)
                FreeGB = [math]::Round($_.FreeSpace / 1GB, 2)
            } })
    } catch { $issues.Add([pscustomobject]@{ Section = 'Disks'; Message = $_.Exception.Message }) }
    try {
        $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapter -Filter 'PhysicalAdapter=True' -OperationTimeoutSec 20 -ErrorAction Stop |
            ForEach-Object { [pscustomobject]@{
                Name = $_.Name
                Status = if ($_.NetConnectionStatus -eq 2) { 'Connected' } else { 'NotConnected' }
            } })
    } catch { $issues.Add([pscustomobject]@{ Section = 'Network'; Message = $_.Exception.Message }) }
    foreach ($name in $ServiceNames) {
        try {
            $service = Get-Service -Name $name -ErrorAction Stop
            $services += [pscustomobject]@{ Name = $service.Name; Status = [string]$service.Status }
        } catch {
            $services += [pscustomobject]@{ Name = $name; Status = 'Unavailable' }
            $issues.Add([pscustomobject]@{ Section = "Service:$name"; Message = $_.Exception.Message })
        }
    }
    [pscustomobject]@{
        SchemaVersion = 1; IsDemo = $false; CollectedAtUtc = [datetime]::UtcNow.ToString('o')
        ComputerName = [Environment]::MachineName; OperatingSystem = $os; MemoryGB = $memoryGB
        Disks = @($disks); NetworkAdapters = @($adapters); Services = @($services)
        CollectionErrors = $issues.ToArray()
    }
}

function ConvertTo-LabReportHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Data,
        [ValidateRange(1, 99)][int]$FreeSpaceWarningPercent = 15
    )
    function Encode([object]$Value) { [System.Net.WebUtility]::HtmlEncode([string]$Value) }
    function Format-Utc([object]$Value) {
        if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('o') }
        return [string]$Value
    }
    # Encode every data value; even local computer/service names are untrusted HTML input.
    $diskRows = foreach ($disk in $Data.Disks) {
        $rawPercent = if ($disk.SizeGB -gt 0) { 100 * $disk.FreeGB / $disk.SizeGB } else { $null }
        $percent = if ($null -eq $rawPercent) { $null } else { [math]::Round($rawPercent, 2) }
        # Compare before display rounding so a nearly-full disk does not lose its warning.
        $percentText = if ($null -eq $percent) { 'Unavailable' } else { "$percent%" }
        $state = if ($null -eq $rawPercent) { 'Unknown' } elseif ($rawPercent -lt $FreeSpaceWarningPercent) { 'Low space' } else { 'OK' }
        "<tr><td>$(Encode $disk.Name)</td><td>$(Encode $disk.SizeGB) GB</td><td>$(Encode $disk.FreeGB) GB</td><td>$(Encode $percentText)</td><td>$(Encode $state)</td></tr>"
    }
    $networkRows = foreach ($adapter in $Data.NetworkAdapters) {
        "<tr><td>$(Encode $adapter.Name)</td><td>$(Encode $adapter.Status)</td></tr>"
    }
    $serviceRows = foreach ($service in $Data.Services) {
        "<tr><td>$(Encode $service.Name)</td><td>$(Encode $service.Status)</td></tr>"
    }
    $errorRows = foreach ($issue in $Data.CollectionErrors) {
        "<li><strong>$(Encode $issue.Section):</strong> $(Encode $issue.Message)</li>"
    }
    $osText = if ($null -eq $Data.OperatingSystem) { 'Unavailable' } else { "$($Data.OperatingSystem.Caption) ($($Data.OperatingSystem.Version))" }
    $boot = if ($null -eq $Data.OperatingSystem) { 'Unavailable' } else { (Format-Utc $Data.OperatingSystem.LastBootUtc) }
    $memory = if ($null -eq $Data.MemoryGB) { 'Unavailable' } else { "$($Data.MemoryGB) GB" }
    $mode = if ($Data.IsDemo) { 'DEMO · fictional workstation' } else { 'LOCAL · workstation report' }
    $quality = if (@($Data.CollectionErrors).Count -gt 0) { 'Partial collection — review collection issues below.' } else { 'Collection completed. Review findings below; this is not a compliance assessment.' }
    $diskBody = if (@($Data.Disks).Count) { $diskRows -join "`n" } else { '<tr><td colspan="5">No disk data available</td></tr>' }
    $networkBody = if (@($Data.NetworkAdapters).Count) { $networkRows -join "`n" } else { '<tr><td colspan="2">No network data available</td></tr>' }
    $serviceBody = if (@($Data.Services).Count) { $serviceRows -join "`n" } else { '<tr><td colspan="2">No services selected</td></tr>' }
    $errorBody = if (@($Data.CollectionErrors).Count) { $errorRows -join "`n" } else { '<li>No collection errors recorded.</li>' }
    @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Workstation report — $(Encode $Data.ComputerName)</title>
<style>
:root{color-scheme:light}*{box-sizing:border-box}body{margin:0;background:#eef2f6;color:#182b3a;font:16px/1.6 system-ui,sans-serif}main{max-width:1000px;margin:auto;padding:38px 20px}header{background:#102d40;color:#fff;padding:28px;border-radius:14px}h1{margin:6px 0;font-size:32px}h2{font-size:20px;margin:0 0 12px}.label{color:#8ce0cf;letter-spacing:.08em;font-size:12px;font-weight:700}section{background:#fff;border:1px solid #d6e1e9;border-radius:12px;margin-top:18px;padding:22px;overflow-x:auto}.meta{color:#dae5ee;font-size:14px}table{border-collapse:collapse;width:100%;font-size:14px}th,td{text-align:left;padding:10px;border-bottom:1px solid #e5ebef;overflow-wrap:anywhere}th{color:#526777}dl{display:grid;grid-template-columns:150px 1fr;gap:8px}dt{color:#526777}dd{margin:0;overflow-wrap:anywhere}footer{font-size:13px;color:#526777;margin-top:20px}@media(max-width:550px){dl{grid-template-columns:1fr}dd{margin-bottom:10px}h1{font-size:24px}}@media print{body{background:white}section{break-inside:avoid}}
</style></head><body><main>
<header><div class="label">$(Encode $mode)</div><h1>$(Encode $Data.ComputerName)</h1><div class="meta">Collected $(Encode (Format-Utc $Data.CollectedAtUtc))</div></header>
<section><h2>Overview</h2><p>$(Encode $quality)</p><dl><dt>Operating system</dt><dd>$(Encode $osText)</dd><dt>Memory</dt><dd>$(Encode $memory)</dd><dt>Last boot (UTC)</dt><dd>$(Encode $boot)</dd></dl></section>
<section><h2>Storage</h2><p>Warning below $FreeSpaceWarningPercent% free space.</p><table><thead><tr><th>Drive</th><th>Capacity</th><th>Free</th><th>Free %</th><th>Finding</th></tr></thead><tbody>$diskBody</tbody></table></section>
<section><h2>Network adapters</h2><p>Link state only; internet connectivity is not tested.</p><table><thead><tr><th>Adapter</th><th>State</th></tr></thead><tbody>$networkBody</tbody></table></section>
<section><h2>Selected services</h2><p>A stopped service can be normal. Check its role before taking action.</p><table><thead><tr><th>Service</th><th>State</th></tr></thead><tbody>$serviceBody</tbody></table></section>
<section><h2>Collection issues</h2><ul>$errorBody</ul></section>
<footer>IT Operations Lab · Schema $(Encode $Data.SchemaVersion) · Review and redact live reports before sharing.</footer>
</main></body></html>
"@
}

function Export-LabReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject]$Data,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [ValidateRange(1, 99)][int]$FreeSpaceWarningPercent = 15
    )
    # Unique run directory prevents an accidental overwrite and keeps a JSON/HTML pair together.
    $root = [System.IO.Path]::GetFullPath($OutputDirectory)
    $run = Join-Path $root ("report-{0}-{1}" -f [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ'), [guid]::NewGuid().ToString('N').Substring(0, 8))
    $html = ConvertTo-LabReportHtml -Data $Data -FreeSpaceWarningPercent $FreeSpaceWarningPercent
    $json = ConvertTo-Json -InputObject $Data -Depth 12
    try {
        [void][System.IO.Directory]::CreateDirectory($run)
        [System.IO.File]::WriteAllText((Join-Path $run 'report.json'), $json, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $run 'report.html'), $html, [System.Text.UTF8Encoding]::new($false))
    } catch { throw "Cannot write report to '$run': $($_.Exception.Message)" }
    [pscustomobject]@{ JsonPath = Join-Path $run 'report.json'; HtmlPath = Join-Path $run 'report.html'; IsDemo = $Data.IsDemo }
}

function Test-LabAssetInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $rows = @(Import-Csv -LiteralPath $Path -Encoding utf8 -ErrorAction Stop)
    $errors = [System.Collections.Generic.List[object]]::new()
    $required = @('AssetId', 'DeviceName', 'SerialNumber', 'Site', 'AssignedTo', 'Status')
    if ($rows.Count -eq 0) {
        $errors.Add([pscustomobject]@{ Row = 0; Field = 'File'; Message = 'Inventory must contain at least one asset.' })
    } else {
        foreach ($column in $required) {
            if ($column -notin $rows[0].PSObject.Properties.Name) {
                $errors.Add([pscustomobject]@{ Row = 1; Field = $column; Message = 'Required column is missing.' })
            }
        }
    }
    # Validate row values only after the header contract has been checked.
    if ($errors.Count -eq 0) {
        $seen = @{ AssetId = @{}; DeviceName = @{}; SerialNumber = @{} }
        for ($i = 0; $i -lt $rows.Count; $i++) {
            $row = $rows[$i]
            foreach ($column in $required) {
                $value = ([string]$row.$column).Trim()
                if ($column -ne 'AssignedTo' -and [string]::IsNullOrWhiteSpace($value)) {
                    $errors.Add([pscustomobject]@{ Row = $i + 2; Field = $column; Message = 'Value is required.' })
                }
                if ($column -in @('AssetId', 'DeviceName', 'SerialNumber') -and $value) {
                    if ($seen[$column].ContainsKey($value)) {
                        $errors.Add([pscustomobject]@{ Row = $i + 2; Field = $column; Message = "Duplicate value '$value'." })
                    } else { $seen[$column][$value] = $true }
                }
            }
            $status = ([string]$row.Status).Trim()
            if ($status -cnotin @('InStock', 'Assigned', 'Repair', 'Retired')) {
                $errors.Add([pscustomobject]@{ Row = $i + 2; Field = 'Status'; Message = 'Use InStock, Assigned, Repair or Retired (case-sensitive).' })
            }
            if ($status -eq 'Assigned' -and [string]::IsNullOrWhiteSpace($row.AssignedTo)) {
                $errors.Add([pscustomobject]@{ Row = $i + 2; Field = 'AssignedTo'; Message = 'Assigned assets require an owner.' })
            }
            if ($status -in @('InStock', 'Retired') -and -not [string]::IsNullOrWhiteSpace($row.AssignedTo)) {
                $errors.Add([pscustomobject]@{ Row = $i + 2; Field = 'AssignedTo'; Message = 'InStock and Retired assets must have no owner.' })
            }
        }
    }
    [pscustomobject]@{ IsValid = $errors.Count -eq 0; AssetCount = $rows.Count; Errors = $errors.ToArray() }
}

function Read-LabConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $config = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable -NoEnumerate
    if ($config -isnot [System.Collections.IDictionary]) { throw 'Configuration must be a JSON object.' }
    foreach ($key in @('schemaVersion', 'directories', 'packages')) {
        if (-not $config.Contains($key)) { throw "Configuration is missing '$key'." }
    }
    foreach ($key in $config.Keys) {
        if ($key -notin @('schemaVersion', 'directories', 'packages')) { throw "Unknown configuration key '$key'." }
    }
    if ($config.schemaVersion -isnot [long] -and $config.schemaVersion -isnot [int]) { throw 'schemaVersion must be an integer.' }
    if ($config.schemaVersion -ne 1) { throw 'Only configuration schemaVersion 1 is supported.' }
    foreach ($key in @('directories', 'packages')) {
        if ($config[$key] -isnot [array]) { throw "'$key' must be a JSON array." }
    }
    $seen = @{}
    foreach ($directory in $config.directories) {
        # Only relative child paths. This also rejects drive/UNC paths and parent traversal.
        if ($directory -isnot [string] -or $directory -notmatch '^[A-Za-z0-9_-]+([/\\][A-Za-z0-9_-]+)*$') {
            throw "Invalid relative directory '$directory'. Use letters, numbers, underscores and hyphens."
        }
        $normalized = $directory.Replace('\', '/').ToLowerInvariant()
        if ($seen.ContainsKey($normalized)) { throw "Duplicate directory '$directory'." }
        $seen[$normalized] = $true
        foreach ($part in ($normalized -split '/')) {
            if ($part -match '^(con|prn|aux|nul|com[1-9]|lpt[1-9])$') { throw "Reserved Windows directory name '$part'." }
        }
    }
    $seen = @{}
    foreach ($package in $config.packages) {
        if ($package -isnot [System.Collections.IDictionary] -or $package.Keys.Count -ne 1 -or -not $package.Contains('id')) {
            throw 'Each package must contain exactly one key: id.'
        }
        if ($package.id -isnot [string] -or $package.id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') { throw 'Invalid WinGet package id.' }
        if ($seen.ContainsKey($package.id)) { throw "Duplicate package '$($package.id)'." }
        $seen[$package.id] = $true
    }
    $config
}

function Assert-LabLocalPath {
    param([Parameter(Mandatory)][string]$Path)
    # Refuse existing symlink/junction ancestors before creating directories or a log.
    $current = [System.IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse points are not supported: '$current'." }
            if (-not $item.PSIsContainer) { throw "A directory path contains a file: '$current'." }
        }
        $parent = [System.IO.Directory]::GetParent($current)
        $current = if ($null -eq $parent) { $null } else { $parent.FullName }
    }
}

function Invoke-LabNativeCommand {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSeconds = 600)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath; $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new(); $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "Could not start '$FilePath'." }
        # Drain both streams concurrently so verbose installers cannot deadlock the process.
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill($true) } catch { Write-Verbose $_.Exception.Message }
            throw "Command timed out after $TimeoutSeconds seconds. Inspect the workstation before retrying."
        }
        # A child can inherit output handles after the parent exits. Bound stream completion too.
        $reads = [System.Threading.Tasks.Task]::WhenAll([System.Threading.Tasks.Task[]]@($stdout, $stderr))
        if (-not $reads.Wait(5000)) { throw 'Process exited but its output streams did not close within 5 seconds.' }
        [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout.GetAwaiter().GetResult(); StdErr = $stderr.GetAwaiter().GetResult() }
    } finally { $process.Dispose() }
}

function Format-LabNativeFailure {
    param([psobject]$Result)
    $detail = if (-not [string]::IsNullOrWhiteSpace($Result.StdErr)) { $Result.StdErr } else { $Result.StdOut }
    $detail = ([string]$detail).Trim()
    if ($detail.Length -gt 2000) { $detail = $detail.Substring(0, 2000) + ' [truncated]' }
    "Exit $($Result.ExitCode). $detail"
}

function Get-LabPackageState {
    param([string]$WingetPath, [string]$Id)
    $result = Invoke-LabNativeCommand -FilePath $WingetPath -Arguments @('list', '--id', $Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity') -TimeoutSeconds 60
    if ($result.ExitCode -eq 0) { return 'Installed' }
    # Only the documented no-applications-found code means absent. Network/source failures do not.
    if ($result.ExitCode -eq -1978335212) { return 'Absent' }
    throw "WinGet could not determine the state of '$Id'. $(Format-LabNativeFailure $result)"
}

function Initialize-LabWorkstation {
    <# .SYNOPSIS
    Apply a validated local configuration. WhatIf runs no native commands and writes no files.
    .DESCRIPTION
    Package installation is explicit opt-in. There is no automatic rollback of installers.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$WorkspaceRoot,
        [Parameter(Mandatory)][string]$LogDirectory,
        [switch]$InstallPackages,
        [switch]$AcceptPackageAgreements
    )
    $config = Read-LabConfiguration -Path $ConfigPath
    $root = [System.IO.Path]::GetFullPath($WorkspaceRoot)
    $logRoot = [System.IO.Path]::GetFullPath($LogDirectory)
    if ($InstallPackages -and -not $AcceptPackageAgreements -and -not $WhatIfPreference) {
        throw 'Review package/source agreements, then explicitly pass -AcceptPackageAgreements to install.'
    }
    $winget = $null
    if ($InstallPackages -and $config.packages.Count -gt 0 -and -not $WhatIfPreference) {
        if (-not $IsWindows) { throw 'Package installation requires Windows and WinGet.' }
        $winget = (Get-Command winget.exe -CommandType Application -ErrorAction Stop).Source
    }
    # Preflight the complete directory plan before any mutation.
    Assert-LabLocalPath -Path $root
    Assert-LabLocalPath -Path $logRoot
    $targets = @($root) + @($config.directories | ForEach-Object { Join-Path $root ($_.Replace('\', [string][System.IO.Path]::DirectorySeparatorChar)) })
    foreach ($target in $targets) { Assert-LabLocalPath -Path $target }
    $events = [System.Collections.Generic.List[object]]::new()
    $runId = [guid]::NewGuid().ToString('N')
    $logFile = $null
    if ($PSCmdlet.ShouldProcess($logRoot, 'Create run journal')) {
        [void][System.IO.Directory]::CreateDirectory($logRoot)
        $logFile = Join-Path $logRoot "provision-$runId.jsonl"
        [System.IO.File]::WriteAllText($logFile, '', [System.Text.UTF8Encoding]::new($false))
    }
    if (-not $WhatIfPreference -and -not $logFile) { throw 'A run journal is required; no workstation changes were made.' }
    function Record([string]$Action, [string]$Target, [string]$Status, [string]$Message) {
        $event = [pscustomobject]@{ TimestampUtc = [datetime]::UtcNow.ToString('o'); RunId = $runId; Action = $Action; Target = $Target; Status = $Status; Message = $Message }
        $events.Add($event)
        # A journal write failure stops the run instead of silently making unlogged changes.
        if ($logFile) { [System.IO.File]::AppendAllText($logFile, (($event | ConvertTo-Json -Compress) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false)) }
    }
    $directoryFailed = $false
    foreach ($target in $targets) {
        if ($directoryFailed) { Record 'Directory' $target 'Skipped' 'A previous directory operation failed.'; continue }
        if (Test-Path -LiteralPath $target -PathType Container) { Record 'Directory' $target 'Skipped' 'Already exists.'; continue }
        if (-not $PSCmdlet.ShouldProcess($target, 'Create directory')) { Record 'Directory' $target 'NotApplied' 'Preview or confirmation declined.'; continue }
        Record 'Directory' $target 'Started' 'Creating directory.'
        $status = 'Created'; $message = 'Directory created.'
        try {
            Assert-LabLocalPath -Path $target
            [void][System.IO.Directory]::CreateDirectory($target)
        } catch { $status = 'Failed'; $message = $_.Exception.Message }
        Record 'Directory' $target $status $message
        if ($status -eq 'Failed') { $directoryFailed = $true }
    }
    $packageFailed = $false
    foreach ($package in $config.packages) {
        $id = $package.id
        if ($packageFailed) { Record 'Package' $id 'Skipped' 'A previous package failed; inspect the journal before retrying.'; continue }
        if ($directoryFailed) { Record 'Package' $id 'Skipped' 'A directory operation failed.'; continue }
        if (-not $InstallPackages) { Record 'Package' $id 'Skipped' 'Package installation was not requested.'; continue }
        if (-not $PSCmdlet.ShouldProcess($id, 'Check and install missing package using WinGet')) { Record 'Package' $id 'NotApplied' 'Preview or confirmation declined; installed state not queried.'; continue }
        Record 'Package' $id 'Started' 'Checking package state.'
        $status = 'Failed'; $message = ''
        try {
            if ((Get-LabPackageState -WingetPath $winget -Id $id) -eq 'Installed') {
                $status = 'Skipped'; $message = 'Already installed; upgrades are outside this command.'
            } else {
                $result = Invoke-LabNativeCommand -FilePath $winget -Arguments @('install', '--id', $id, '--exact', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
                if ($result.ExitCode -ne 0) { throw "WinGet installation failed. $(Format-LabNativeFailure $result)" }
                if ((Get-LabPackageState -WingetPath $winget -Id $id) -ne 'Installed') { throw 'WinGet returned success but the package was not detected afterwards.' }
                $status = 'Installed'; $message = 'Installation verified.'
            }
        } catch { $message = $_.Exception.Message }
        Record 'Package' $id $status $message
        # Stop package changes after the first failure; a timeout may leave a partially installed app.
        if ($status -eq 'Failed') { $packageFailed = $true }
    }
    [pscustomobject]@{
        RunId = $runId; IsPreview = [bool]$WhatIfPreference; LogPath = $logFile
        Succeeded = @($events | Where-Object Status -eq 'Failed').Count -eq 0
        Events = $events.ToArray()
    }
}

Export-ModuleMember -Function Get-LabWorkstationData, ConvertTo-LabReportHtml, Export-LabReport, Test-LabAssetInventory, Read-LabConfiguration, Initialize-LabWorkstation
