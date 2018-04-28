[CmdletBinding()]

Param (
    [Parameter()]
    [string[]]
    $Task = 'build',

    [Parameter()]
    [System.Collections.Hashtable]
    $Parameters,

    [Parameter()]
    [switch]
    $InstallPrerequisites
)

$psake = @{
    buildFile  = "$PSScriptRoot\Build.psake.ps1"
    taskList   = $Task
    Verbose    = $VerbosePreference
}

if ($Parameters) {
    $psake.parameters = $Parameters
}

# Prerequisites
if ($InstallPrerequisites) {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    }

    'pester', 'psake' | ForEach-Object {
        Install-Module -Name $_ -Force -Verbose -Scope CurrentUser -SkipPublisherCheck
    }
}

. $PSScriptRoot\Build.manifest.ps1
Invoke-psake @psake