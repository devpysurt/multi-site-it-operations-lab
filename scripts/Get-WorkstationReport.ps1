#Requires -Version 7.4
<#
.SYNOPSIS
Write an HTML/JSON workstation report, or a clearly labelled fictional demo.
.EXAMPLE
./scripts/Get-WorkstationReport.ps1 -Demo
.EXAMPLE
./scripts/Get-WorkstationReport.ps1 -OutputDirectory ./reports -FreeSpaceWarningPercent 20
#>
[CmdletBinding()]
param(
    [switch]$Demo,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../reports'),
    [ValidateRange(1, 99)][int]$FreeSpaceWarningPercent = 15,
    [ValidateNotNullOrEmpty()][string[]]$ServiceNames = @('Spooler', 'wuauserv')
)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot '../src/ITOpsLab/ITOpsLab.psd1') -Force
    $data = if ($Demo) {
        Get-Content (Join-Path $PSScriptRoot '../examples/workstation.demo.json') -Raw -Encoding utf8 | ConvertFrom-Json
    } else { Get-LabWorkstationData -ServiceNames $ServiceNames }
    Export-LabReport -Data $data -OutputDirectory $OutputDirectory -FreeSpaceWarningPercent $FreeSpaceWarningPercent
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
