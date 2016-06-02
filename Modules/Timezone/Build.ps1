[CmdletBinding()]

Param(
    [Parameter()]
    [string[]]$Task = 'default',
    
    [Parameter()]
    [System.Collections.Hashtable]$Parameters
)

'Pester', 'psake' | Foreach-Object { 
    if (!(Get-Module -Name $_ -ListAvailable)) {
        Install-Module -Name $_ -Scope CurrentUser
    }
}

if ($Parameters) {
    Invoke-psake -buildFile "$PSScriptRoot\Build.PSake.ps1" -taskList $Task, Clean -parameters $Parameters -Verbose:$VerbosePreference
}

else {
    Invoke-psake -buildFile "$PSScriptRoot\Build.PSake.ps1" -taskList $Task, Clean -Verbose:$VerbosePreference
}