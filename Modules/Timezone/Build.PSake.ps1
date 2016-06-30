Properties {
    $ModuleName    = (Get-Item -Path $PSScriptRoot).Name
    $BuildLocation = "$($env:TEMP)\$ModuleName"
    $DeployDir     = "$($($env:PSModulePath).Split(';')[0])\$ModuleName"

    # Name of the repository you wish to publish to. Default repo is the PSGallery.
    $PublishRepository = $null

    # If you do not specify the NuGetApiKey as a build parameter, the first time
    # you publish you will be prompted to enter your API key. The build will store
    # the key encrypted in a file, so that on subsequent publishes you will no
    # longer be prompted for the API key.
    $EncryptedApiKeyPath = "$env:LOCALAPPDATA\WindowsPowerShell\NuGetApiKey.clixml"

    # If you specify the certificate subject when running a build that certificate 
    # must exist in the users personal certificate store. The build will import the 
    # certificate (if required), then store the subject, so that on subsequent 
    # signing the build will use the same (or newer) certificate with that subject.
    $CertSubjectPath  = "$env:LOCALAPPDATA\WindowsPowerShell\CertificateSubject.clixml"

    # In addition, PFX certificates are supported in an interactive scenario only,
    # as a way to import a certificate into the user personal store for later use.
    # This can be provided using the CertPfxPath parameter.
    # PFX passwords will not be stored.
}

Task default -depends BuildManifest, Setup, Analyze, Test, Clean

Task Setup -depends BuildManifest {
    if (-not (Test-Path -Path $BuildLocation)) {
        New-Item -Path $BuildLocation -ItemType Directory -Verbose:$VerbosePreference | Out-Null
    }

    Copy-Item -Path "$PSScriptRoot\$ModuleName\*" -Destination $BuildLocation -Recurse -Force -Exclude 'Build-Manifest.ps1' -Verbose:$VerbosePreference
}

Task BuildManifest {
    . "$PSScriptRoot\$ModuleName\Build-Manifest.ps1"
}

Task Analyze -depends Setup {
    $analysisResult = Invoke-ScriptAnalyzer -Path $BuildLocation -Severity @('Error', 'Warning') -Recurse -Verbose:$false
    if ($analysisResult) {
        $analysisResult | Format-Table
        Write-Error -Message 'One or more Script Analyzer errors/warnings where found. Build cannot continue!'
    }
}

Task Test -depends Setup {
    $TestResult = Invoke-Pester -Path $BuildLocation -PassThru -Verbose:$VerbosePreference

    if ($TestResult.FailedCount -gt 0) {
        $TestResult | Format-List
        Write-Error -Message 'One or more Pester tests for the deployment failed. Build cannot continue!'
    }
}

Task Sign -depends Analyze, Test -requiredVariables CertSubjectPath {
    if ($CertPfxPath) {
        $CertImport = @{
            CertStoreLocation = 'Cert:\CurrentUser\My'
            FilePath          = $CertPfxPath
            Password          = $(PromptUserForKeyCredential -Message 'Enter the PFX password to import the certificate').Password
            ErrorAction       = 'Stop'
        }

        $Cert = Import-PfxCertificate @CertImport -Verbose:$VerbosePreference
    }
    else {
        if ($CertSubject -eq $null -and (Test-Path -LiteralPath $CertSubjectPath)) {
            $CertSubject = LoadAndUnencryptString $CertSubjectPath
            $LoadedFromSubjectFile = $true
        }

        else {
            $CertSubject = 'CN='
            $CertSubject += Read-Host -Prompt 'Enter the certificate subject you wish to use (CN= prefix will be added)'
        }
        
        $Cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
            Where-Object { $_.Subject -eq $CertSubject -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object -Property NotAfter -Descending | Select-Object -First 1
    }
    
    if ($Cert) {
        if (-not $LoadedFromSubjectFile) {
            EncryptAndSaveString -String $Cert.Subject -Path $CertSubjectPath
            Write-Output "The new certificate subject has been stored in $CertSubjectPath"
        }

        else {
            Write-Output "Using stored certificate subject $CertSubject from $CertSubjectPath"
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

Task RemoveCertSubject -requiredVariables CertSubjectPath {
    if (Test-Path -LiteralPath $CertSubjectPath) {
        Remove-Item -LiteralPath $CertSubjectPath
    }
}

Task ShowCertSubject -requiredVariables CertSubjectPath {
    $CertSubject = LoadAndUnencryptString -Path $CertSubjectPath
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
        New-Item -Path $DeployDir -ItemType Directory -Verbose:$VerbosePreference | Out-Null
    }
    
    Copy-Item -Path "$BuildLocation\*" -Destination $DeployDir -Verbose:$VerbosePreference -Recurse -Force
}

Task DeploySigned -depends Sign, Deploy {}

Task Publish -depends Setup, Analyze, Test -requiredVariables $EncryptedApiKeyPath {
    if ($NuGetApiKey) {
        EncryptAndSaveString -NuGetApiKey $NuGetApiKey -Path $EncryptedApiKeyPath
        Write-Output "The new NuGetApiKey has been stored in $EncryptedApiKeyPath"
    }

    elseif ($NuGetApiKey -eq $null -and (Test-Path -LiteralPath $EncryptedApiKeyPath)) {
        $NuGetApiKey = LoadAndUnencryptString $EncryptedApiKeyPath
        Write-Output "Using stored NuGetApiKey from $EncryptedApiKeyPath"
    }

    else {
        $KeyCred = @{
            DestinationPath = $EncryptedApiKeyPath
            Message         = 'Enter your NuGet API key in the password field'
        }
        $cred = PromptUserForKeyCredential @KeyCred
        $NuGetApiKey = $cred.GetNetworkCredential().Password
        "The NuGetApiKey has been stored in $EncryptedApiKeyPath"
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
        Remove-Item -Path $BuildLocation -Recurse -Force -Verbose:$VerbosePreference
    }
}

Task RemoveKey -requiredVariables EncryptedApiKeyPath {
    if (Test-Path -LiteralPath $EncryptedApiKeyPath) {
        Remove-Item -LiteralPath $EncryptedApiKeyPath
    }
}

Task StoreKey -requiredVariables EncryptedApiKeyPath {
    $nuGetApiKeyCred = PromptUserForKeyCredential -DestinationPath $EncryptedApiKeyPath
    "The NuGetApiKey has been stored in $EncryptedApiKeyPath"
}

Task ShowKey -requiredVariables EncryptedApiKeyPath {
    $NuGetApiKey = LoadAndUnencryptString -Path $EncryptedApiKeyPath
    Write-Output "The stored (partial) NuGetApiKey is: $($NuGetApiKey[0..7])"
    Write-Output 'To see the full key, use the task "ShowFullKey"'
}

Task ShowFullKey -requiredVariables EncryptedApiKeyPath {
    $NuGetApiKey = LoadAndUnencryptString -Path $EncryptedApiKeyPath
    "The stored NuGetApiKey is: $NuGetApiKey"
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
        [string]$DestinationPath,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $KeyCred = Get-Credential -Message $Message -UserName "ignored"

    if ($DestinationPath) {
        EncryptAndSaveString -SecureString $KeyCred.Password -Path $DestinationPath
    }

    $KeyCred
}

function EncryptAndSaveString {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingConvertToSecureStringWithPlainText", '')]
    [Diagnostics.CodeAnalysis.SuppressMessage("PSProvideDefaultParameterValue", '')]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName='SecureString'
        )]
        [ValidateNotNull()]
        [SecureString]$SecureString,

        [Parameter(
            Mandatory, 
            ParameterSetName='PlainText'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$String,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'PlainText') {
        $SecureString = ConvertTo-SecureString -String $String -AsPlainText -Force
    }

    $parentDir = Split-Path $Path -Parent
    
    if (!(Test-Path -LiteralPath $parentDir)) {
        $null = New-Item -Path $parentDir -ItemType Directory
    }

    elseif (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path
    }

    $SecureString | ConvertFrom-SecureString | Export-Clixml $Path
    Write-Verbose "The data has been encrypted and saved to $Path"
}

function LoadAndUnencryptString {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSProvideDefaultParameterValue", '')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $storedKey = Import-Clixml $Path | ConvertTo-SecureString
    $cred = New-Object -TypeName PSCredential -ArgumentList 'jpgr',$storedKey
    $cred.GetNetworkCredential().Password
    Write-Verbose "The data has been loaded and unencrypted from $Path"
}