<#
    Name  : Build-Manifest (Timezone)
    Author: David Green

    http://www.tookitaway.co.uk/
	
#>

$Module = 'Timezone'
$CmdLets = @('Get-Timezone', 'Set-Timezone')
$FileList = (Get-ChildItem -Path $PSScriptRoot -Exclude 'Build-Manifest.ps1').Name + "$Module.psd1"

$ModuleDescription = @{
    Path = "$PSScriptRoot\$Module.psd1"
    Description = 'A PowerShell script module designed to get and set the timezone, wrapping the tzutil command.'
    RootModule = "$Module.psm1"
    Author = 'David Green'
    CompanyName = 'http://tookitaway.co.uk/, https://github.com/davegreen/PowerShell/'
    Copyright = '(c) 2016 David Green. All rights reserved.'
    PowerShellVersion = '5.0'
    ModuleVersion = '1.2.2'
    FileList = $FileList
    FunctionsToExport = $CmdLets
    CmdletsToExport = $CmdLets
    VariablesToExport = $null
    AliasesToExport = $CmdLets
    Tags = @($Module, 'tzutil')
    LicenseUri = 'https://github.com/davegreen/PowerShell/blob/master/LICENSE'
    ProjectUri = 'http://tookitaway.co.uk'
    # IconUri = ''
    # ReleaseNotes = ''
}

New-ModuleManifest @ModuleDescription