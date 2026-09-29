# Implementation references

Primary documentation consulted for behavior and design. These links explain API semantics; they are not evidence that this repository has passed execution tests.

- [PowerShell ShouldProcess and WhatIf](https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess)
- [WinGet list command](https://learn.microsoft.com/en-us/windows/package-manager/winget/list)
- [WinGet install command](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)
- [WinGet documented return codes](https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md)
- [PowerShell ConvertFrom-Json](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json)
- [Pester v5 configuration](https://pester.dev/docs/v5/usage/configuration)
- [Pester module testing](https://pester.dev/docs/usage/modules/)
- [Microsoft Graph PowerShell](https://learn.microsoft.com/en-us/powershell/microsoftgraph/) — roadmap only
- [Intune Graph integration](https://learn.microsoft.com/en-us/graph/api/resources/intune-graph-overview) — roadmap only

The no-applications-found HRESULT is `0x8A150014`, represented as signed process exit code `-1978335212`. Other nonzero WinGet query exits remain failures. This avoids using localized console text to decide whether installation is necessary.
