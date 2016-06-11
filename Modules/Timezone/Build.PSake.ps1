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

    # If you do not specify the certificate thumbprint when specifying a build that
    # includes script signing the build will use the first code signing certificate
    # it finds in the users personal certificate store. The build will store the
    # thumbprint encrypted in a file, so that on subsequent signing the build will
    # use the same certificate.
    $CertThumbprintPath  = "$env:LOCALAPPDATA\WindowsPowerShell\CertificateThumbprint.clixml"
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

Task Sign -depends Analyze, Test {
    if ($CertThumbprint) {
        EncryptAndSaveString -String $CertThumbprint -Path $CertThumbprintPath
        Write-Output "The new thumbprint has been stored in $CertThumbprintPath"
    }

    elseif ($CertThumbprint -eq $null -and (Test-Path -LiteralPath $CertThumbprintPath)) {
        $CertThumbprint = LoadAndUnencryptString $CertThumbprintPath
        Write-Output "Using stored thumbprint from $CertThumbprintPath"
    }

    elseif ($CertThumbprint -eq $null) {
        if ($CertThumbprint = @(Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert)[0].Thumbprint) {
            EncryptAndSaveString -String $CertThumbprint -Path $CertThumbprintPath
            Write-Output "The thumbprint has been stored in $CertThumbprintPath"
        }
        
        else {
            throw 'No certificate thumbprint supplied or stored'
        }
    }

    if (Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert) {
        if ($CertThumbprint) {
            $Authenticode   = @{
                FilePath    = @(Get-ChildItem -Path "$BuildLocation\*" -Include '*.ps1', '*.psm1')
                Certificate = @(Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Thumbprint -eq $CertThumbprint })[0]
            }
        }

        else {
            $Authenticode   = @{
                FilePath    = @(Get-ChildItem -Path "$BuildLocation\*" -Include '*.ps1', '*.psm1')
                Certificate = @(Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert)[0]
            }
        }

        Write-Output -InputObject $Authenticode.FilePath | Out-Default
        Write-Output -InputObject $Authenticode.Certificate | Out-Default
        $SignResult = Set-AuthenticodeSignature @Authenticode -Verbose:$VerbosePreference
        if ($SignResult.Status -ne 'Valid') {
            throw "Signing one or more scripts failed."
        }
    }

    else {
        throw "Signing failed. No code signing certificate found."
    }
}

Task Deploy -depends Setup, Analyze, Test {
    if (-not (Test-Path -Path $DeployDir)) {
        New-Item -Path $DeployDir -ItemType Directory -Verbose:$VerbosePreference | Out-Null
    }

    Copy-Item -Path "$BuildLocation\*" -Destination $DeployDir -Verbose:$VerbosePreference -Force
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

    elseif ($NuGetApiKey -eq $null) {
        $cred = PromptUserForNuGetApiKeyCredential -DestinationPath $EncryptedApiKeyPath
        $NuGetApiKey = $cred.GetNetworkCredential().Password
        Write-Output "The NuGetApiKey has been stored in $EncryptedApiKeyPath"
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

Task RemoveCertThumbprint -requiredVariables CertThumbprintPath {
    if (Test-Path -LiteralPath $CertThumbprintPath) {
        Remove-Item -LiteralPath $CertThumbprintPath
    }
}

Task StoreKey -requiredVariables EncryptedApiKeyPath {
    $nuGetApiKeyCred = PromptUserForNuGetApiKeyCredential -DestinationPath $EncryptedApiKeyPath
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

Task ShowCertThumbprint -requiredVariables CertThumbprintPath {
    $CertThumbprint = LoadAndUnencryptString -Path $CertThumbprintPath
    Write-Output "The stored thumbprint is: $CertThumbprint"
    $Certificate = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Thumbprint -eq $CertThumbprint }

    if ($Certificate) {
        Write-Output 'The certificate has been found and is valid'
    }

    else {
        Write-Output 'The certificate has not been found'
    }
}

Task ? -description 'List the available tasks' {
    Write-Output 'Available tasks:'
    Write-Output $PSake.Context.Peek().Tasks.Keys | Sort-Object
}

# Helper functions
Function PromptUserForNuGetApiKeyCredential {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSProvideDefaultParameterValue', '')]
    Param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath
    )

    $message = "Enter your NuGet API Key for the gallery in the password field."
    $nuGetApiKeyCred = Get-Credential -Message $message -UserName "ignored"

    if ($DestinationPath) {
        EncryptAndSaveString -SecureString $nuGetApiKeyCred.Password -Path $DestinationPath
    }

    Write-Output $nuGetApiKeyCred
}

Function EncryptAndSaveString {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    [Diagnostics.CodeAnalysis.SuppressMessage('PSProvideDefaultParameterValue', '')]
    Param(
        [Parameter(
            Mandatory = $True,
            ParameterSetName='SecureString'
        )]
        [ValidateNotNull()]
        [SecureString]$SecureString,

        [Parameter(
            Mandatory = $True,
            ParameterSetName='PlainText'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$String,

        [Parameter(
            Mandatory = $True
        )]
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
    Write-Verbose -Message "The data has been encrypted and saved to $Path"
}

Function LoadAndUnencryptString {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSProvideDefaultParameterValue', '')]
    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $storedKey = Import-Clixml $Path | ConvertTo-SecureString
    $cred = New-Object -TypeName PSCredential -ArgumentList 'jpgr', $storedKey
    $cred.GetNetworkCredential().Password
    Write-Verbose -Message "The data has been loaded and unencrypted from $Path"
}