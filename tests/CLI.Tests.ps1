BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $executable = (Get-Process -Id $PID).Path
    function Invoke-TestCli {
        param([string]$ScriptName, [string[]]$CliArguments = @())
        # A child process is intentional: exit codes are part of the public CLI contract.
        $PSNativeCommandUseErrorActionPreference = $false
        $output = & $executable -NoLogo -NoProfile -NonInteractive -File (Join-Path $repoRoot "scripts/$ScriptName") @CliArguments 2>&1
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output | Out-String) }
    }
}

Describe 'CLI contracts' {
    BeforeEach {
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $caseRoot | Out-Null
    }
    It 'writes a demo pair and exits zero' {
        $result = Invoke-TestCli 'Get-WorkstationReport.ps1' @('-Demo', '-OutputDirectory', "$caseRoot/reports")
        $result.ExitCode | Should -Be 0
        $jsonFiles = @(Get-ChildItem "$caseRoot/reports" -Recurse -Filter report.json)
        $htmlFiles = @(Get-ChildItem "$caseRoot/reports" -Recurse -Filter report.html)
        $jsonFiles.Count | Should -Be 1
        $htmlFiles.Count | Should -Be 1
        (Get-Content $jsonFiles[0].FullName -Raw | ConvertFrom-Json).IsDemo | Should -BeTrue
    }
    It 'returns exit one for an unwritable report destination' {
        'file' | Set-Content "$caseRoot/occupied"
        $result = Invoke-TestCli 'Get-WorkstationReport.ps1' @('-Demo', '-OutputDirectory', "$caseRoot/occupied/reports")
        $result.ExitCode | Should -Be 1
    }
    It 'returns exit zero and JSON for a valid inventory' {
        $result = Invoke-TestCli 'Test-AssetInventory.ps1'
        $result.ExitCode | Should -Be 0
        ($result.Output | ConvertFrom-Json).IsValid | Should -BeTrue
    }
    It 'returns exit two for a readable but invalid inventory' {
        "AssetId,DeviceName,SerialNumber,Site,AssignedTo,Status`nLAB-1,PC-1,SN-1,Site,,Assigned" | Set-Content "$caseRoot/invalid.csv"
        $result = Invoke-TestCli 'Test-AssetInventory.ps1' @('-Path', "$caseRoot/invalid.csv")
        $result.ExitCode | Should -Be 2
        ($result.Output | ConvertFrom-Json).IsValid | Should -BeFalse
    }
    It 'returns exit one for a missing inventory file' {
        (Invoke-TestCli 'Test-AssetInventory.ps1' @('-Path', "$caseRoot/missing.csv")).ExitCode | Should -Be 1
    }
    It 'forwards WhatIf without filesystem side effects' {
        $result = Invoke-TestCli 'Initialize-Workstation.ps1' @(
            '-InstallPackages', '-WhatIf', '-WorkspaceRoot', "$caseRoot/work", '-LogDirectory', "$caseRoot/logs"
        )
        $result.ExitCode | Should -Be 0
        "$caseRoot/work" | Should -Not -Exist
        "$caseRoot/logs" | Should -Not -Exist
    }
    It 'returns exit one on invalid configuration without a journal' {
        '{"schemaVersion":1,"directories":["../outside"],"packages":[]}' | Set-Content "$caseRoot/invalid.json"
        $result = Invoke-TestCli 'Initialize-Workstation.ps1' @(
            '-ConfigPath', "$caseRoot/invalid.json", '-WorkspaceRoot', "$caseRoot/work", '-LogDirectory', "$caseRoot/logs"
        )
        $result.ExitCode | Should -Be 1
        "$caseRoot/logs" | Should -Not -Exist
    }
    It 'can apply directory-only setup using paths containing spaces' {
        $result = Invoke-TestCli 'Initialize-Workstation.ps1' @(
            '-WorkspaceRoot', "$caseRoot/work with spaces", '-LogDirectory', "$caseRoot/log with spaces"
        )
        $result.ExitCode | Should -Be 0
        "$caseRoot/work with spaces/Support/Reports" | Should -Exist
        @(Get-ChildItem "$caseRoot/log with spaces" -Filter '*.jsonl').Count | Should -Be 1
    }
}
