[CmdletBinding()]
Param(
    [string[]]$Task = 'default'
)

if (!(Get-Module -Name Pester -ListAvailable))   { Install-Module -Name Pester -Scope CurrentUser }
if (!(Get-Module -Name psake -ListAvailable))    { Install-Module -Name psake -Scope CurrentUser }
if (!(Get-Module -Name PSDeploy -ListAvailable)) { Install-Module -Name PSDeploy -Scope CurrentUser }

Invoke-psake -buildFile "$PSScriptRoot\Build.PSake.ps1" -taskList $Task, CleanManifest -Verbose:$VerbosePreference