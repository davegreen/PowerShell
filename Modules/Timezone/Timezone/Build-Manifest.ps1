<#
    Name  : Build-Manifest (Timezone)
    Author: David Green

    http://www.tookitaway.co.uk/
	
#>

$ModuleBase = Split-Path -Parent $MyInvocation.MyCommand.Path

# Handles modules in version directories
$leaf          = Split-Path $ModuleBase -Leaf
$parent        = Split-Path $ModuleBase -Parent
$parsedVersion = $null

if ([System.Version]::TryParse($leaf, [ref]$parsedVersion)) {
	$ModuleName = Split-Path $parent -Leaf
}

else {
	$ModuleName = $leaf
}

# Removes all versions of the module from the session before importing
Get-Module $ModuleName | Remove-Module

# Because ModuleBase includes version number, this imports the required version
# of the module
$Module   = Import-Module $ModuleBase\$ModuleName.psm1 -PassThru -ErrorAction Stop
$commands = Get-Command -Module $Module

$ModuleDescription = @{
    Path              = "$PSScriptRoot\$ModuleName.psd1"
    Description       = 'A PowerShell script module designed to get and set the timezone, wrapping the tzutil command.'
    RootModule        = "$ModuleName.psm1"
    Author            = 'David Green'
    CompanyName       = 'http://tookitaway.co.uk/, https://github.com/davegreen/PowerShell/'
    Copyright         = '(c) 2016 David Green. All rights reserved.'
    PowerShellVersion = '5.0'
    ModuleVersion     = '1.2.2'
    FileList          = ((Get-ChildItem -Recurse -File -Path $PSScriptRoot).Name | Where-Object { $_ -ne 'Build-Manifest.ps1' })
    FunctionsToExport = $commands.Name
    CmdletsToExport   = $commands.Name
    VariablesToExport = $null
    AliasesToExport   = $commands.Name
    Tags              = @($ModuleName, 'tzutil')
    LicenseUri        = 'https://github.com/davegreen/PowerShell/blob/master/LICENSE'
    ProjectUri        = 'http://tookitaway.co.uk'
    # IconUri         = ''
    # ReleaseNotes    = ''
}

New-ModuleManifest @ModuleDescription