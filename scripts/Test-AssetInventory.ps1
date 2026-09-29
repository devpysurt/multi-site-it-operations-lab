#Requires -Version 7.4
<# .SYNOPSIS
Validate the asset CSV. Exit 0 means valid, 2 means validation errors, 1 means a runtime error.
#>
[CmdletBinding()]
param([string]$Path = (Join-Path $PSScriptRoot '../data/assets.example.csv'))
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot '../src/ITOpsLab/ITOpsLab.psd1') -Force
    $result = Test-LabAssetInventory -Path $Path
    $result | ConvertTo-Json -Depth 5
    if (-not $result.IsValid) { exit 2 }
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
