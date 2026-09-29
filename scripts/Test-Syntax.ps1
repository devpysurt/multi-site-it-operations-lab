#Requires -Version 7.4
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failed = $false
Get-ChildItem $root -Recurse -File -Include *.ps1,*.psm1,*.psd1 | ForEach-Object {
    $tokens = $null; $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($issue in $parseErrors) { Write-Error "$($_.FullName):$($issue.Extent.StartLineNumber): $($issue.Message)" -ErrorAction Continue; $failed = $true }
}
if ($failed) { exit 1 }
Test-ModuleManifest (Join-Path $root 'src/ITOpsLab/ITOpsLab.psd1') | Select-Object Name, Version
exit 0
