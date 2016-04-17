<#
    Name  : Build-Manifest (Timezone)
    Author: David Green

    http://www.tookitaway.co.uk/
	
#>

$PSData = @{
    Tags = @('Timezone', 'tzutil')
    LicenseUri = 'https://github.com/davegreen/PowerShell/blob/master/LICENSE'
    ProjectUri = 'http://tookitaway.co.uk'
    # IconUri = ''
    # ReleaseNotes = ''
}

$CmdLets = @('Get-Timezone', 'Get-TimezoneFromOffset', 'Set-Timezone')

$ModuleDescription = @{
    Path = "$PSScriptRoot\Timezone.psd1"
    Description = 'A PowerShell script module designed to get and set the timezone, wrapping the tzutil command.'
    RootModule = 'Timezone.psm1'
    Author = 'David Green'
    CompanyName = 'http://tookitaway.co.uk/, https://github.com/davegreen/PowerShell/'
    Copyright = '(c) 2016 David Green. All rights reserved.'
    PowerShellVersion = '5.0'
    ModuleVersion = '1.1' 
    FileList = @('Timezone.psd1', 'Timezone.psm1', 'Timezone.Tests.ps1') 
    FunctionsToExport = $CmdLets
    CmdletsToExport = $CmdLets
    VariablesToExport = $null
    AliasesToExport = $CmdLets
    PrivateData = $PSData
}

New-ModuleManifest @ModuleDescription