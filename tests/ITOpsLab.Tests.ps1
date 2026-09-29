BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    Import-Module "$repoRoot/src/ITOpsLab/ITOpsLab.psd1" -Force
}

Describe 'Asset inventory contract' {
    It 'accepts the fictional multi-site inventory' {
        $result = Test-LabAssetInventory "$repoRoot/data/assets.example.csv"
        $result.IsValid | Should -BeTrue
        $result.AssetCount | Should -Be 6
    }
    It 'rejects duplicate identifiers case-insensitively and after trimming' {
        @'
AssetId,DeviceName,SerialNumber,Site,AssignedTo,Status
LAB-1,PC-1,SN-1,Site,,InStock
 lab-1 ,PC-2,SN-2,Site,,InStock
'@ | Set-Content "$TestDrive/duplicate.csv"
        $result = Test-LabAssetInventory "$TestDrive/duplicate.csv"
        $result.IsValid | Should -BeFalse
        $result.Errors.Field | Should -Contain 'AssetId'
    }
    It 'rejects duplicate serial numbers and device names' {
        @'
AssetId,DeviceName,SerialNumber,Site,AssignedTo,Status
LAB-1,PC-1,SN-1,Site,,InStock
LAB-2,PC-1,SN-1,Site,,InStock
'@ | Set-Content "$TestDrive/duplicate-hardware.csv"
        $result = Test-LabAssetInventory "$TestDrive/duplicate-hardware.csv"
        $result.Errors.Field | Should -Contain 'SerialNumber'
        $result.Errors.Field | Should -Contain 'DeviceName'
    }
    It 'requires an owner for assigned assets' {
        "AssetId,DeviceName,SerialNumber,Site,AssignedTo,Status`nLAB-1,PC-1,SN-1,Site,,Assigned" | Set-Content "$TestDrive/owner.csv"
        (Test-LabAssetInventory "$TestDrive/owner.csv").Errors.Field | Should -Contain 'AssignedTo'
    }
    It 'rejects an owner for stock assets and unknown statuses' {
        "AssetId,DeviceName,SerialNumber,Site,AssignedTo,Status`nLAB-1,PC-1,SN-1,Site,a@example.invalid,InStock`nLAB-2,PC-2,SN-2,Site,,Lost" | Set-Content "$TestDrive/status.csv"
        $result = Test-LabAssetInventory "$TestDrive/status.csv"
        $result.Errors.Field | Should -Contain 'Status'
        $result.Errors.Field | Should -Contain 'AssignedTo'
    }
    It 'rejects missing columns without throwing a property access error' {
        "AssetId,Status`nLAB-1,Assigned" | Set-Content "$TestDrive/header.csv"
        (Test-LabAssetInventory "$TestDrive/header.csv").IsValid | Should -BeFalse
    }
    It 'rejects a header-only inventory' {
        'AssetId,DeviceName,SerialNumber,Site,AssignedTo,Status' | Set-Content "$TestDrive/empty.csv"
        (Test-LabAssetInventory "$TestDrive/empty.csv").IsValid | Should -BeFalse
    }
    It 'rejects an unreadable path' {
        { Test-LabAssetInventory "$TestDrive/missing.csv" } | Should -Throw
    }
}

Describe 'HTML and JSON reporting' {
    BeforeEach {
        $data = Get-Content "$repoRoot/examples/workstation.demo.json" -Raw | ConvertFrom-Json
    }
    It 'labels demo output and highlights low space' {
        $html = ConvertTo-LabReportHtml $data
        $html | Should -Match 'fictional workstation'
        $html | Should -Match 'Low space'
        $html | Should -Match '8%'
    }
    It 'uses the requested threshold including the exact boundary' {
        $data.Disks = @([pscustomobject]@{Name='C:'; SizeGB=100; FreeGB=15})
        (ConvertTo-LabReportHtml $data -FreeSpaceWarningPercent 15) | Should -Not -Match 'Low space'
        (ConvertTo-LabReportHtml $data -FreeSpaceWarningPercent 16) | Should -Match 'Low space'
    }
    It 'does not round away a low-space warning near the threshold' {
        $data.Disks = @([pscustomobject]@{Name='C:'; SizeGB=100; FreeGB=14.96})
        (ConvertTo-LabReportHtml $data -FreeSpaceWarningPercent 15) | Should -Match 'Low space'
    }
    It 'HTML-encodes host names and error messages' {
        $data.ComputerName = '<script>alert(1)</script>'
        $data.CollectionErrors = @([pscustomobject]@{Section='<img>'; Message='a & b <script>'})
        $html = ConvertTo-LabReportHtml $data
        $html | Should -Not -Match '<script>'
        $html | Should -Match '&lt;script&gt;'
        $html | Should -Match 'a &amp; b'
        $html | Should -Match 'Partial collection'
    }
    It 'handles unknown OS, memory, empty arrays and zero-capacity disks' {
        $data.OperatingSystem = $null; $data.MemoryGB = $null
        $data.Disks = @([pscustomobject]@{Name='X:'; SizeGB=0; FreeGB=0})
        $data.NetworkAdapters = @(); $data.Services = @()
        $html = ConvertTo-LabReportHtml $data
        $html | Should -Match 'Unknown'
        $html | Should -Match 'Unavailable'
        $html | Should -Match 'No network data available'
    }
    It 'writes independently named HTML and JSON pairs on repeated exports' {
        $first = Export-LabReport $data "$TestDrive/reports"
        $second = Export-LabReport $data "$TestDrive/reports"
        $first.HtmlPath | Should -Not -Be $second.HtmlPath
        $first.HtmlPath | Should -Exist
        (Get-Content $first.JsonPath -Raw | ConvertFrom-Json).ComputerName | Should -Be $data.ComputerName
    }
    It 'fails clearly if the output parent is a file' {
        'file' | Set-Content "$TestDrive/not-a-directory"
        { Export-LabReport $data "$TestDrive/not-a-directory/child" } | Should -Throw '*Cannot write report*'
    }
}

Describe 'Configuration and provisioning' {
    BeforeEach {
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $caseRoot | Out-Null
        $configPath = "$caseRoot/workstation.json"
        '{"schemaVersion":1,"directories":["Support","Support/Reports"],"packages":[]}' | Set-Content $configPath
        $workspace = "$caseRoot/workstation"
        $journal = "$caseRoot/logs"
    }
    It 'accepts the example configuration' {
        (Read-LabConfiguration "$repoRoot/config/workstation.example.json").packages.Count | Should -Be 2
    }
    It 'rejects path traversal before making changes' {
        '{"schemaVersion":1,"directories":["../escape"],"packages":[]}' | Set-Content $configPath
        { Initialize-LabWorkstation $configPath $workspace $journal } | Should -Throw '*Invalid relative directory*'
        $workspace | Should -Not -Exist
        $journal | Should -Not -Exist
    }
    It 'rejects malformed config <Name>' -ForEach @(
        @{Name='array root'; Json='[{"schemaVersion":1,"directories":[],"packages":[]}]'},
        @{Name='unknown key'; Json='{"schemaVersion":1,"directories":[],"packages":[],"command":"bad"}'},
        @{Name='wrong schema'; Json='{"schemaVersion":2,"directories":[],"packages":[]}'},
        @{Name='string schema'; Json='{"schemaVersion":"1","directories":[],"packages":[]}'},
        @{Name='scalar directories'; Json='{"schemaVersion":1,"directories":"Support","packages":[]}'},
        @{Name='reserved name'; Json='{"schemaVersion":1,"directories":["NUL"],"packages":[]}'},
        @{Name='duplicate directories'; Json='{"schemaVersion":1,"directories":["Support","support"],"packages":[]}'},
        @{Name='command injection'; Json='{"schemaVersion":1,"directories":[],"packages":[{"id":"x; whoami"}]}'},
        @{Name='duplicate packages'; Json='{"schemaVersion":1,"directories":[],"packages":[{"id":"A.B"},{"id":"a.b"}]}'},
        @{Name='unknown package key'; Json='{"schemaVersion":1,"directories":[],"packages":[{"id":"A.B","arguments":"--force"}]}'},
        @{Name='missing packages'; Json='{"schemaVersion":1,"directories":[]}'}
    ) {
        $Json | Set-Content $configPath
        { Read-LabConfiguration $configPath } | Should -Throw
    }
    It 'WhatIf creates no directories, logs or package processes' {
        $result = Initialize-LabWorkstation "$repoRoot/config/workstation.example.json" $workspace $journal -InstallPackages -WhatIf
        $result.IsPreview | Should -BeTrue
        $result.LogPath | Should -BeNullOrEmpty
        $workspace | Should -Not -Exist
        $journal | Should -Not -Exist
        @($result.Events | Where-Object Status -eq 'NotApplied').Count | Should -BeGreaterThan 0
    }
    It 'creates directories, records a journal and skips them on the second run' {
        $first = Initialize-LabWorkstation $configPath $workspace $journal -Confirm:$false
        $first.Succeeded | Should -BeTrue
        "$workspace/Support/Reports" | Should -Exist
        $first.LogPath | Should -Exist
        $entries = @(Get-Content $first.LogPath | ForEach-Object { $_ | ConvertFrom-Json })
        @($entries | Where-Object Status -eq 'Created').Count | Should -Be 3
        $second = Initialize-LabWorkstation $configPath $workspace $journal -Confirm:$false
        @($second.Events | Where-Object Status -eq 'Created').Count | Should -Be 0
        $second.LogPath | Should -Not -Be $first.LogPath
    }
    It 'refuses a file in the planned directory path before creating a journal' {
        New-Item -ItemType Directory $workspace | Out-Null
        'occupied' | Set-Content "$workspace/Support"
        { Initialize-LabWorkstation $configPath $workspace $journal } | Should -Throw '*contains a file*'
        $journal | Should -Not -Exist
    }
    It 'requires explicit package agreement acceptance before any mutation' {
        { Initialize-LabWorkstation $configPath $workspace $journal -InstallPackages } | Should -Throw '*AcceptPackageAgreements*'
        $journal | Should -Not -Exist
    }
    It 'skips packages unless explicitly requested' {
        $result = Initialize-LabWorkstation "$repoRoot/config/workstation.example.json" $workspace $journal -Confirm:$false
        @($result.Events | Where-Object { $_.Action -eq 'Package' -and $_.Status -eq 'Skipped' }).Count | Should -Be 2
    }
}

Describe 'WinGet error classification' {
    It 'treats exit 0 as installed' {
        InModuleScope ITOpsLab {
            Mock Invoke-LabNativeCommand { [pscustomobject]@{ExitCode=0; StdOut=''; StdErr=''} }
            Get-LabPackageState 'winget.exe' 'A.B' | Should -Be 'Installed'
        }
    }
    It 'treats only the documented not-found code as absent' {
        InModuleScope ITOpsLab {
            Mock Invoke-LabNativeCommand { [pscustomobject]@{ExitCode=-1978335212; StdOut=''; StdErr=''} }
            Get-LabPackageState 'winget.exe' 'A.B' | Should -Be 'Absent'
        }
    }
    It 'does not confuse source/network failure with an absent package' {
        InModuleScope ITOpsLab {
            Mock Invoke-LabNativeCommand { [pscustomobject]@{ExitCode=123; StdOut=''; StdErr='source unavailable'} }
            { Get-LabPackageState 'winget.exe' 'A.B' } | Should -Throw '*could not determine*'
        }
    }
    It 'passes identifiers as separate exact-match arguments' {
        InModuleScope ITOpsLab {
            Mock Invoke-LabNativeCommand { [pscustomobject]@{ExitCode=0; StdOut=''; StdErr=''} }
            Get-LabPackageState 'winget.exe' 'A.B' | Out-Null
            Should -Invoke Invoke-LabNativeCommand -Times 1 -Exactly -ParameterFilter {
                $Arguments[0] -eq 'list' -and $Arguments[2] -eq 'A.B' -and '--exact' -in $Arguments
            }
        }
    }
}

Describe 'Live Windows collection' -Tag 'Windows' {
    It 'collects baseline OS and local disk information on an accessible Windows host' -Skip:(-not $IsWindows) {
        $data = Get-LabWorkstationData
        $data.OperatingSystem | Should -Not -BeNullOrEmpty
        $data.OperatingSystem.Caption | Should -Match 'Windows'
        @($data.Disks).Count | Should -BeGreaterThan 0
        $data.MemoryGB | Should -BeGreaterThan 0
    }
    It 'collects schema-compliant data and records a missing service' -Skip:(-not $IsWindows) {
        $data = Get-LabWorkstationData -ServiceNames 'ITOpsLab-DefinitelyMissingService'
        $data.SchemaVersion | Should -Be 1
        $data.IsDemo | Should -BeFalse
        $data.ComputerName | Should -Not -BeNullOrEmpty
        $data.Services[0].Status | Should -Be 'Unavailable'
        $data.CollectionErrors.Section | Should -Contain 'Service:ITOpsLab-DefinitelyMissingService'
        { ConvertTo-LabReportHtml $data } | Should -Not -Throw
    }
}

Describe 'Native process adapter' {
    It 'preserves argument boundaries and captures both output streams and exit code' {
        InModuleScope ITOpsLab {
            $executable = (Get-Process -Id $PID).Path
            $result = Invoke-LabNativeCommand -FilePath $executable -Arguments @(
                '-NoProfile', '-NonInteractive', '-Command',
                '[Console]::Out.Write("two words; literal"); [Console]::Error.Write("diagnostic"); exit 7'
            ) -TimeoutSeconds 15
            $result.ExitCode | Should -Be 7
            $result.StdOut | Should -Be 'two words; literal'
            $result.StdErr | Should -Be 'diagnostic'
        }
    }
    It 'terminates a process that exceeds its timeout' {
        InModuleScope ITOpsLab {
            $executable = (Get-Process -Id $PID).Path
            { Invoke-LabNativeCommand -FilePath $executable -Arguments @('-NoProfile', '-NonInteractive', '-Command', 'Start-Sleep -Seconds 30') -TimeoutSeconds 1 } | Should -Throw '*timed out*'
        }
    }
}

Describe 'Windows package provisioning with mocked installers' -Tag 'Windows' {
    BeforeEach {
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $caseRoot | Out-Null
        $configurationFile = Join-Path $caseRoot 'config.json'
        '{"schemaVersion":1,"directories":[],"packages":[{"id":"Example.App"},{"id":"Example.Second"}]}' | Set-Content $configurationFile
    }
    It 'skips installed packages without launching an installer' -Skip:(-not $IsWindows) {
        InModuleScope ITOpsLab -Parameters @{CaseRoot=$caseRoot; ConfigurationFile=$configurationFile} {
            Mock Get-Command { [pscustomobject]@{Source='winget.exe'} } -ParameterFilter { $Name -eq 'winget.exe' }
            Mock Get-LabPackageState { 'Installed' }
            Mock Invoke-LabNativeCommand { throw 'Installer should not have run.' }
            $result = Initialize-LabWorkstation $ConfigurationFile "$CaseRoot/work" "$CaseRoot/logs" -InstallPackages -AcceptPackageAgreements -Confirm:$false
            $result.Succeeded | Should -BeTrue
            @($result.Events | Where-Object { $_.Action -eq 'Package' -and $_.Status -eq 'Skipped' }).Count | Should -Be 2
            Should -Invoke Invoke-LabNativeCommand -Times 0 -Exactly
        }
    }
    It 'does not install after a detection failure and skips remaining packages' -Skip:(-not $IsWindows) {
        InModuleScope ITOpsLab -Parameters @{CaseRoot=$caseRoot; ConfigurationFile=$configurationFile} {
            Mock Get-Command { [pscustomobject]@{Source='winget.exe'} } -ParameterFilter { $Name -eq 'winget.exe' }
            Mock Get-LabPackageState { throw 'Source unreachable.' }
            Mock Invoke-LabNativeCommand { throw 'Installer should not have run.' }
            $result = Initialize-LabWorkstation $ConfigurationFile "$CaseRoot/work" "$CaseRoot/logs" -InstallPackages -AcceptPackageAgreements -Confirm:$false
            $result.Succeeded | Should -BeFalse
            @($result.Events | Where-Object Status -eq 'Failed').Count | Should -Be 1
            @($result.Events | Where-Object { $_.Target -eq 'Example.Second' -and $_.Status -eq 'Skipped' }).Count | Should -Be 1
            Should -Invoke Invoke-LabNativeCommand -Times 0 -Exactly
        }
    }
    It 'verifies detection after a successful install' -Skip:(-not $IsWindows) {
        InModuleScope ITOpsLab -Parameters @{CaseRoot=$caseRoot; ConfigurationFile=$configurationFile} {
            Mock Get-Command { [pscustomobject]@{Source='winget.exe'} } -ParameterFilter { $Name -eq 'winget.exe' }
            $script:detectedPackages = @{}
            Mock Get-LabPackageState {
                if ($script:detectedPackages.ContainsKey($Id)) { 'Installed' } else { 'Absent' }
            }
            Mock Invoke-LabNativeCommand {
                $script:detectedPackages[$Arguments[2]] = $true
                [pscustomobject]@{ExitCode=0; StdOut=''; StdErr=''}
            }
            $result = Initialize-LabWorkstation $ConfigurationFile "$CaseRoot/work" "$CaseRoot/logs" -InstallPackages -AcceptPackageAgreements -Confirm:$false
            $result.Succeeded | Should -BeTrue
            @($result.Events | Where-Object Status -eq 'Installed').Count | Should -Be 2
            Should -Invoke Get-LabPackageState -Times 4 -Exactly
            Should -Invoke Invoke-LabNativeCommand -Times 2 -Exactly -ParameterFilter { $Arguments[0] -eq 'install' }
        }
    }
    It 'rejects an installer success code when post-install detection is still absent' -Skip:(-not $IsWindows) {
        InModuleScope ITOpsLab -Parameters @{CaseRoot=$caseRoot; ConfigurationFile=$configurationFile} {
            Mock Get-Command { [pscustomobject]@{Source='winget.exe'} } -ParameterFilter { $Name -eq 'winget.exe' }
            Mock Get-LabPackageState { 'Absent' }
            Mock Invoke-LabNativeCommand { [pscustomobject]@{ExitCode=0; StdOut=''; StdErr=''} }
            $result = Initialize-LabWorkstation $ConfigurationFile "$CaseRoot/work" "$CaseRoot/logs" -InstallPackages -AcceptPackageAgreements -Confirm:$false
            $result.Succeeded | Should -BeFalse
            ($result.Events | Where-Object Status -eq 'Failed').Message | Should -Match 'not detected'
            Should -Invoke Invoke-LabNativeCommand -Times 1 -Exactly
        }
    }
}

Describe 'Provisioning filesystem boundaries' {
    It 'rejects a symlink ancestor on Linux before creating a journal' -Skip:$IsWindows {
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory "$caseRoot/actual" -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path "$caseRoot/link" -Target "$caseRoot/actual" | Out-Null
        '{"schemaVersion":1,"directories":["Support"],"packages":[]}' | Set-Content "$caseRoot/config.json"
        { Initialize-LabWorkstation "$caseRoot/config.json" "$caseRoot/link/work" "$caseRoot/logs" } | Should -Throw '*Reparse points*'
        "$caseRoot/logs" | Should -Not -Exist
        "$caseRoot/actual/work" | Should -Not -Exist
    }
}

Describe 'Native failure messages' {
    It 'uses stdout when the native tool leaves stderr empty' {
        InModuleScope ITOpsLab {
            $result = [pscustomobject]@{ExitCode=12; StdOut='source unavailable'; StdErr=''}
            Format-LabNativeFailure $result | Should -Be 'Exit 12. source unavailable'
        }
    }
    It 'bounds journal error detail length' {
        InModuleScope ITOpsLab {
            $result = [pscustomobject]@{ExitCode=12; StdOut=''; StdErr=('x' * 3000)}
            $message = Format-LabNativeFailure $result
            $message.Length | Should -BeLessThan 2100
            $message | Should -Match '\[truncated\]'
        }
    }
}
