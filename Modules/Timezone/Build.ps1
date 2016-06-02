[CmdletBinding()]

Param(
    [string[]]$Task = 'default',
    [System.Collections.Hashtable]$Parameters
)

if (!(Get-Module -Name Pester -ListAvailable)) {
    Install-Module -Name Pester -Scope CurrentUser
}

if (!(Get-Module -Name psake -ListAvailable)) {
    Install-Module -Name psake -Scope CurrentUser
}

if ($Parameters) {
    Invoke-psake -buildFile "$PSScriptRoot\Build.PSake.ps1" -taskList $Task, Clean -parameters $Parameters -Verbose:$VerbosePreference
}

else {
    Invoke-psake -buildFile "$PSScriptRoot\Build.PSake.ps1" -taskList $Task, Clean -Verbose:$VerbosePreference
}