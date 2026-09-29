@{
    RootModule = 'ITOpsLab.psm1'
    ModuleVersion = '0.1.0'
    GUID = '68e2b122-6c1a-4813-bef6-8d13cc7b49af'
    Author = 'IT Operations Lab contributors'
    Description = 'A fictional multi-site Windows support and workstation provisioning lab.'
    PowerShellVersion = '7.4'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @('Get-LabWorkstationData', 'ConvertTo-LabReportHtml', 'Export-LabReport',
        'Test-LabAssetInventory', 'Read-LabConfiguration', 'Initialize-LabWorkstation')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{ Tags = @('Windows', 'ITSupport', 'PowerShell', 'Portfolio'); LicenseUri = 'https://opensource.org/license/mit' } }
}
