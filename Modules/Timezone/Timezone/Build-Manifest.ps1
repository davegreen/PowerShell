<#
    Name  : Build-Manifest (Timezone)
    Author: David Green

    http://www.tookitaway.co.uk/
	
#>

$ModuleBase = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModuleName = Split-Path $ModuleBase -Leaf

# Removes all versions of the module from the session before importing
Get-Module $ModuleName | Remove-Module

$Module   = Import-Module $ModuleBase\$ModuleName.psm1 -PassThru -ErrorAction Stop
$commands = Get-Command -Module $Module
$FileList = ((Get-ChildItem -File -Path $PSScriptRoot).Name | Where-Object { $_ -ne 'Build-Manifest.ps1' })
$FileList += foreach ($Directory in (Get-ChildItem -Directory -Path $PSScriptRoot).Name) {
    ((Get-ChildItem -File -Path $PSScriptRoot\$Directory).Name) | ForEach-Object { Write-Output "$Directory\$_" }
}

$ModuleDescription = @{
    Path              = "$PSScriptRoot\$ModuleName.psd1"
    Description       = 'A PowerShell script module designed to get and set the timezone, wrapping the tzutil command.'
    RootModule        = "$ModuleName.psm1"
    Author            = 'David Green'
    CompanyName       = 'http://tookitaway.co.uk/, https://github.com/davegreen/PowerShell/'
    Copyright         = '(c) 2016 David Green. All rights reserved.'
    PowerShellVersion = '5.0'
    ModuleVersion     = '1.2.3'
    FileList          = $FileList
    FunctionsToExport = $commands.Name
    CmdletsToExport   = $commands.Name
    # VariablesToExport = ''
    AliasesToExport   = $commands.Name
    Tags              = @($ModuleName, 'tzutil')
    LicenseUri        = 'https://github.com/davegreen/PowerShell/blob/master/LICENSE'
    ProjectUri        = 'http://tookitaway.co.uk'
    # IconUri         = ''
    # ReleaseNotes    = ''
}

if (Test-Path -Path $ModuleDescription.Path) {
    Update-ModuleManifest @ModuleDescription
}

else {
    New-ModuleManifest @ModuleDescription
}