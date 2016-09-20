Properties {
    $ModuleName    = (Get-Item -Path $PSScriptRoot).Name
    $BuildLocation = "$($env:TEMP)\$ModuleName"
    $DeployDir     = Join-Path -Path (Split-Path $profile.CurrentUserAllHosts -Parent) -ChildPath $ModuleName

    # If you do not specify the NuGetApiKey as a build parameter, the first time
    # you publish you will be prompted to enter your API key. The build will store
    # the key encrypted in a file, so that on subsequent publishes you will no
    # longer be prompted for the API key.

    # If you specify the certificate subject when running a build that certificate
    # must exist in the users personal certificate store. The build will import the
    # certificate (if required), then store the subject, so that on subsequent
    # signing the build will use the same (or newer) certificate with that subject.

    # PFX certificates for import are supported in an interactive scenario only,
    # as a way to import a certificate into the user personal store for later use.
    # This can be provided using the CertPfxPath parameter.
    # PFX passwords will not be stored.
    $SettingsPath = "$env:LOCALAPPDATA\WindowsPowerShell\SecuredSettings.clixml"
}

Task default -depends BuildManifest, Setup, Analyze, Test, Clean

Task Setup -depends BuildManifest {
    if (-not (Test-Path -Path $BuildLocation)) {
        New-Item -Path $BuildLocation -ItemType Directory -Verbose:$VerbosePreference | Out-Null
    }

    $Setup = @{
        Path        = "$PSScriptRoot\$ModuleName\*"
        Destination = $BuildLocation
        Recurse     = $true
        Force       = $true
        Exclude     = 'Build-Manifest.ps1'
    }

    Copy-Item @Setup -Verbose:$VerbosePreference
}

Task BuildManifest {
    Write-Verbose -Message "Building manifest in $PSScriptRoot\$ModuleName\Build-Manifest.ps1"
    . "$PSScriptRoot\$ModuleName\Build-Manifest.ps1"
}

Task Analyze -depends Setup {
    $analysisResult = Invoke-ScriptAnalyzer -Path $BuildLocation -Recurse -Verbose:$VerbosePreference

    if ($analysisResult) {
        $analysisResult | Format-Table
        Write-Error -Message 'One or more Script Analyzer errors/warnings were found. Build cannot continue!'
    }
}

Task Test -depends Setup {
    $TestResult = Invoke-Pester -Path $BuildLocation -PassThru -Verbose:$VerbosePreference

    if ($TestResult.FailedCount -gt 0) {
        $TestResult | Format-List
        Write-Error -Message 'One or more Pester tests for the deployment failed. Build cannot continue!'
    }
}

Task Sign -depends Analyze, Test -requiredVariables SettingsPath {
    if ($CertPfxPath) {
        $CertImport = @{
            CertStoreLocation = 'Cert:\CurrentUser\My'
            FilePath          = $CertPfxPath
            Password          = $(PromptUserForKeyCredential -Message 'Enter the PFX password to import the certificate').Password
            ErrorAction       = 'Stop'
        }

        Write-Verbose -Message "Importing PFX certificate from $CertPfxPath"
        $Cert = Import-PfxCertificate @CertImport -Verbose:$VerbosePreference
    }

    else {
        if ($CertSubject -eq $null -and (GetSetting -Key CertSubject -Path $SettingsPath)) {
            Write-Verbose -Message 'Getting certificate subject from stored data'
            $CertSubject = GetSetting -Key CertSubject -Path $SettingsPath
            $LoadedFromSubjectFile = $true
        }

        else {
            Write-Verbose -Message 'No stored certificate subject, asking user'
            $CertSubject = 'CN='
            $CertSubject += Read-Host -Prompt 'Enter the certificate subject you wish to use (CN= prefix will be added)'
        }

        $Cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
            Where-Object { $_.Subject -eq $CertSubject -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object -Property NotAfter -Descending | Select-Object -First 1
    }

    if ($Cert) {
        if (-not $LoadedFromSubjectFile) {
            SetSetting -Key CertSubject -Value $Cert.Subject -Path $SettingsPath
            Write-Output "The new certificate subject has been stored in $SettingsPath"
        }

        else {
            Write-Output "Using stored certificate subject $CertSubject from $SettingsPath"
        }

        $Authenticode   = @{
            FilePath    = @(Get-ChildItem -Path "$BuildLocation\*" -Recurse -Include '*.ps1', '*.psm1')
            Certificate = Get-ChildItem Cert:\CurrentUser\My |
                Where-Object { $_.Thumbprint -eq $Cert.Thumbprint }
        }

        Write-Output -InputObject $Authenticode.FilePath | Out-Default
        Write-Output -InputObject $Authenticode.Certificate | Out-Default
        $SignResult = Set-AuthenticodeSignature @Authenticode -Verbose:$VerbosePreference

        if ($SignResult.Status -ne 'Valid') {
            throw "Signing one or more scripts failed."
        }
    }

    else {
        throw 'No valid certificate subject supplied or stored.'
    }
}

Task RemoveCertSubject -requiredVariables SettingsPath {
    if (GetSetting -Path $SettingsPath -Key CertSubject) {
        Write-Verbose -Message 'Removing stored CertSubject'
        RemoveSetting -Path $SettingsPath -Key CertSubject
    }
}

Task ShowCertSubject -requiredVariables SettingsPath {
    $CertSubject = GetSetting -Path $SettingsPath -Key CertSubject
    Write-Output "The stored certificate is: $CertSubject"
    $Cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
            Where-Object { $_.Subject -eq $CertSubject -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object -Property NotAfter -Descending | Select-Object -First 1

    if ($Cert) {
        Write-Output "A valid certificate for the subject $CertSubject has been found"
    }

    else {
        Write-Output 'A valid certificate has not been found'
    }
}

Task Deploy -depends Setup, Analyze, Test {
    if (-not (Test-Path -Path $DeployDir)) {
        Write-Verbose -Message 'Creating deployment directory'
        New-Item -Path $DeployDir -ItemType Directory -Verbose:$VerbosePreference | Out-Null
    }

    Copy-Item -Path "$BuildLocation\*" -Destination $DeployDir -Verbose:$VerbosePreference -Recurse -Force
}

Task DeploySigned -depends Sign, Deploy {}

Task Publish -depends Setup, Analyze, Test -requiredVariables SettingsPath {
    if ($NuGetApiKey) {
        $SecureNuGetApiKey = ConvertTo-SecureString -String $NuGetApiKey -AsPlainText -Force
        AddSetting -Key NuGetApiKey -Value $SecureNuGetApiKey -Path $SettingsPath
        Write-Output "The new NuGetApiKey has been stored in $SettingsPath"
    }

    elseif ($NuGetApiKey -eq $null -and (GetSetting -Path $SettingsPath -Key NuGetApiKey)) {
        $NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey
        Write-Output "Using stored NuGetApiKey from $SettingsPath"
    }

    else {
        Write-Verbose -Message 'No stored NuGetApiKey found, asking user'
        $KeyCred = @{
            DestinationPath = $SettingsPath
            Message         = 'Enter your NuGet API key in the password field'
            Key             = 'NuGetApiKey'
        }

        $cred = PromptUserForKeyCredential @KeyCred
        $NuGetApiKey = $cred.GetNetworkCredential().Password
        "The NuGetApiKey has been stored in $SettingsPath"
    }

    $publishParams = @{
        Path        = $BuildLocation
        NuGetApiKey = $NuGetApiKey
    }

    if ($PublishRepository) {
        $publishParams['Repository'] = $PublishRepository
    }

    Publish-Module @publishParams
}

Task PublishSigned -depends Sign, Publish {}

Task Clean {
    if (Test-Path -Path $BuildLocation) {
        Write-Verbose -Message 'Cleaning build directory'
        Remove-Item -Path $BuildLocation -Recurse -Force -Verbose:$VerbosePreference
    }
}

Task RemoveKey -requiredVariables SettingsPath {
    if (GetSetting -Path $SettingsPath -Key NuGetApiKey) {
        Write-Verbose -Message 'Removing stored NuGetApiKey'
        RemoveSetting -Path $SettingsPath -Key NuGetApiKey
    }
}

Task StoreKey -requiredVariables SettingsPath {
    $KeyCred = @{
        DestinationPath = $SettingsPath
        Message         = 'Enter your NuGet API key in the password field'
        Key             = 'NuGetApiKey'
    }
    PromptUserForKeyCredential @KeyCred
    "The NuGetApiKey has been stored in $SettingsPath"
}

Task ShowKey -requiredVariables SettingsPath {
    $NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey

    if ($NuGetApiKey) {
        Write-Output "The stored (partial) NuGetApiKey is: $($NuGetApiKey[0..7])"
        Write-Output 'To see the full key, use the task "ShowFullKey"'
    }

    else {
        Write-Output 'No stored NugetApiKey found.'
    }
}

Task ShowFullKey -requiredVariables SettingsPath {
    $NuGetApiKey = GetSetting -Path $SettingsPath -Key NuGetApiKey

    if ($NuGetApiKey) {
        Write-Output "The stored NuGetApiKey is: $NuGetApiKey"
    }

    else {
        Write-Output 'No stored NugetApiKey found.'
    }
}

Task ? -description 'List the available tasks' {
    Write-Output 'Available tasks:'
    Write-Output $PSake.Context.Peek().Tasks.Keys | Sort-Object
}

# Helper functions
function PromptUserForKeyCredential {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSProvideDefaultParameterValue", '')]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationPath,

        [Parameter(Mandatory)]
        [string]
        $Message,

        [Parameter(Mandatory, ParameterSetName = 'SaveSetting')]
        [string]
        $Key
    )

    $KeyCred = Get-Credential -Message $Message -UserName "ignored"
    if ($DestinationPath) {
        AddSetting -Key $Key -Value $KeyCred.Password -Path $DestinationPath
    }

    $KeyCred
}

function AddSetting {
    Param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Value
    )

    switch ($Type = $Value.GetType().Name) {
        'securestring' {
            $Setting = $Value | ConvertFrom-SecureString
        }
        default {
            $Setting = $Value
        }
    }

    if (Test-Path -Path $Path) {
        $StoredSettings = Import-Clixml -Path $Path
        $StoredSettings.Add($Key, @($Type, $Setting))
        $StoredSettings | Export-Clixml -Path $Path
    }
    else {
        @{$Key = @($Type, $Setting)} | Export-Clixml -Path $Path
    }
}

function GetSetting {
    Param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -Path $Path) {
        $SecuredSettings = Import-Clixml -Path $Path
        if ($SecuredSettings.$Key) {
            switch ($SecuredSettings.$Key[0]) {
                'securestring' {
                    $Value = $SecuredSettings.$Key[1] | ConvertTo-SecureString
                    $cred = New-Object -TypeName PSCredential -ArgumentList 'jpgr', $Value
                    $cred.GetNetworkCredential().Password
                }
                default {
                    $SecuredSettings.$Key[1]
                }
            }
        }
    }
}

function SetSetting {
    Param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Value
    )

    if (GetSetting -Key $Key -Path $Path) {
        RemoveSetting -Key $Key -Path $Path
    }
    AddSetting -Key $Key -Value $Value -Path $Path
}

function RemoveSetting {
    Param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $StoredSettings = Import-Clixml -Path $Path
    $StoredSettings.Remove($Key)
    if ($StoredSettings.Count -eq 0) {
        Remove-Item -Path $Path
    }
    else {
        $StoredSettings | Export-Clixml -Path $Path
    }
}