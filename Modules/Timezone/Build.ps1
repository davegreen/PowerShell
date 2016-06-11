[CmdletBinding()]

Param(
    [Parameter()]
    [string[]]$Task = 'default',
    
    [Parameter()]
    [System.Collections.Hashtable]$Parameters
)

'Pester', 'psake', 'PsScriptAnalyzer' | Foreach-Object { 
    if (!(Get-Module -Name $_ -ListAvailable)) {
        Install-Module -Name $_ -Scope CurrentUser
    }
}

$psake = @{
    buildFile  = "$PSScriptRoot\Build.PSake.ps1"
    taskList   = $Task + 'Clean'
    Verbose    = $VerbosePreference
}

if ($Parameters) {
    $psake.parameters = $Parameters
}

Invoke-psake @psake