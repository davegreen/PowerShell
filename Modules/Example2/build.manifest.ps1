<#
    Name  : Build-Manifest (Timezone)
    Author: David Green

    http://www.tookitaway.co.uk/

#>

$ModuleName = (Get-Item -Path $PSScriptRoot).Name
$ModuleRoot = "$PSScriptRoot\src\$ModuleName.psm1"

# Removes all versions of the module from the session before importing
Get-Module $ModuleName | Remove-Module
$Module         = Import-Module $ModuleRoot -PassThru -ErrorAction Stop
$ModuleCommands = Get-Command -Module $Module
Remove-Module $Module

if ($ModuleCommands) {
    $Function = $ModuleCommands | Where-Object { $_.CommandType -eq 'Function' -and $_.Name -like '*-*' }
    $Cmdlet = $ModuleCommands   | Where-Object { $_.CommandType -eq 'Cmdlet' -and $_.Name -like '*-*' }
    $Alias = $ModuleCommands    | Where-Object { $_.CommandType -eq 'Alias' -and $_.Name -like '*-*' }
}

Push-Location -Path $PSScriptRoot\src
$FileList = (Get-ChildItem -Recurse | Resolve-Path -Relative).Substring(2) | Where-Object { $_ -like '*.*' }
Pop-Location

$ModuleDescription = @{
    Path                = "$(Split-Path -Path $ModuleRoot)\$((Get-Item -Path $ModuleRoot).BaseName).psd1"
    Description         = 'A PowerShell script module designed to get and set the timezone, wrapping the tzutil command.'
    RootModule          = "$ModuleName.psm1"
    Author              = 'David Green'
    CompanyName         = 'tookitaway.co.uk'
    Copyright           = '(c) 2018. All rights reserved.'
    PowerShellVersion   = '5.1'
    ModuleVersion       = '1.0.0'
    # RequiredModules   = ''
    FileList            = $FileList
    FunctionsToExport   = $Function
    CmdletsToExport     = $Cmdlet
    AliasesToExport     = $Alias
    Tags                = @($ModuleName, 'tzutil')
    # VariablesToExport = ''
    LicenseUri          = 'https://github.com/davegreen/PowerShell/blob/master/LICENSE'
    ProjectUri          = 'http://tookitaway.co.uk'
    # IconUri           = ''
    ReleaseNotes        = Get-Content -Path "$PSScriptRoot\CHANGELOG.md" -Raw
}

[string]$Tags = $ModuleDescription.Tags | Foreach-Object { "'$_' " }

[xml]$ModuleNuspec = @"
<?xml version="1.0"?>
<package>
  <metadata>
    <id>$ModuleName</id>
    <version>$($ModuleDescription.ModuleVersion)</version>
    <authors>$($ModuleDescription.Author)</authors>
    <owners>$($ModuleDescription.Author)</owners>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>$($ModuleDescription.Description)</description>
    <releaseNotes>$(Get-Content -Path "$PSScriptRoot\CHANGELOG.md" -Raw)</releaseNotes>
    <copyright>$($ModuleDescription.Copyright)</copyright>
    <tags>$Tags</tags>
  </metadata>
</package>
"@

New-ModuleManifest @ModuleDescription
$ModuleNuspec.Save("$(Split-Path -Path $ModuleRoot)\$((Get-Item -Path $ModuleRoot).BaseName).nuspec")