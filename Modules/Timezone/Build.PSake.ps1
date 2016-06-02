Properties {
    $ModuleName    = (Get-Item -Path $PSScriptRoot).Name
    $BuildLocation = "$($env:TEMP)\$ModuleName"
    $DeployDir     = "$($($env:PSModulePath).Split(';')[0])\$ModuleName"
    
    # Name of the repository you wish to publish to. Default repo is the PSGallery.
    $PublishRepository = $null

    # Leave $NuGetApiKey as $null and the first time you publish you will be prompted
    # to enter your API key.  The build will store the key encrypted in a file, so
    # that on subsequent publishes you will no longer be prompted for the API key.
    $NuGetApiKey = $null
    $EncryptedApiKeyPath = "$env:LOCALAPPDATA\WindowsPowerShell\NuGetApiKey.clixml"
}

Task default -depends Setup, BuildManifest, Analyze, Test, Clean

Task Setup {
    if (-not (Test-Path -Path $BuildLocation)) {
        New-Item -Path $BuildLocation -ItemType Directory -Verbose:$VerbosePreference | Out-Null
    }

    Copy-Item -Path "$PSScriptRoot\$ModuleName\*" -Destination $BuildLocation -Verbose:$VerbosePreference
}

Task BuildManifest -depends Setup {
    . "$BuildLocation\Build-Manifest.ps1"
    Remove-Item -Path "$BuildLocation\Build-Manifest.ps1"
}

Task Analyze -depends BuildManifest {
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

Task Sign -depends BuildManifest {
    if (Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert) {
        $Authenticode   = @{
            FilePath    = @(Get-ChildItem -Path "$BuildLocation\*" -Include '*.ps1', '*.psm1')
            Certificate = @(Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert)[0]
        }

        $SignResult = Set-AuthenticodeSignature @Authenticode -Verbose:$VerbosePreference
        if ($SignResult.Status -ne 'Valid') {
            throw 'Signing one or more scripts failed.'
        }
    }

    else {
        throw 'No code signing certificates available.'
    }
}

Task Deploy -depends BuildManifest, Analyze, Test {    
    if (-not (Test-Path -Path $DeployDir)) {
        New-Item -Path $DeployDir -ItemType Directory -Verbose:$VerbosePreference | Out-Null
    }

    Copy-Item -Path "$BuildLocation\*" -Destination $DeployDir -Verbose:$VerbosePreference -Force
}

Task Publish -depends BuildManifest, Analyze, Test -requiredVariables $EncryptedApiKeyPath {
    if (Test-Path -LiteralPath $EncryptedApiKeyPath) {
        $NuGetApiKey = LoadAndUnencryptNuGetApiKey $EncryptedApiKeyPath
        Write-Output "Using stored NuGetApiKey from $EncryptedApiKeyPath"
    }

    else {
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

    Publish-Module @publishParams -WhatIf
}

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
    $nuGetApiKeyCred = PromptUserForNuGetApiKeyCredential -DestinationPath $EncryptedApiKeyPath
    "The NuGetApiKey has been stored in $EncryptedApiKeyPath"
}

Task ShowKey -requiredVariables EncryptedApiKeyPath {
    if ($NuGetApiKey) {
        "The embedded (partial) NuGetApiKey is: $($NuGetApiKey[0..7])"
    }

    else {
        $NuGetApiKey = LoadAndUnencryptNuGetApiKey -Path $EncryptedApiKeyPath
        "The stored (partial) NuGetApiKey is: $($NuGetApiKey[0..7])"
    }

    Write-Output 'To see the full key, use the task "ShowFullKey"'
}

Task ShowFullKey -requiredVariables EncryptedApiKeyPath {
    if ($NuGetApiKey) {
        "The embedded NuGetApiKey is: $NuGetApiKey"
    }

    else {
        $NuGetApiKey = LoadAndUnencryptNuGetApiKey -Path $EncryptedApiKeyPath
        "The stored NuGetApiKey is: $NuGetApiKey"
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
        EncryptAndSaveNuGetApiKey -NuGetApiKeySecureString $nuGetApiKeyCred.Password -Path $DestinationPath
    }

    Write-Output $nuGetApiKeyCred
}

Function EncryptAndSaveNuGetApiKey {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    [Diagnostics.CodeAnalysis.SuppressMessage('PSProvideDefaultParameterValue', '')]
    Param(
        [Parameter(
            Mandatory = $True,
            ParameterSetName='SecureString'
        )]
        [ValidateNotNull()]
        [SecureString]$NuGetApiKeySecureString,

        [Parameter(
            Mandatory = $True,
            ParameterSetName='PlainText'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$NuGetApiKey,

        [Parameter(
            Mandatory = $True
        )]
        [string]$Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'PlainText') {
        $NuGetApiKeySecureString = ConvertTo-SecureString -String $NuGetApiKey -AsPlainText -Force
    }

    $parentDir = Split-Path $Path -Parent

    if (!(Test-Path -LiteralPath $parentDir)) {
        $null = New-Item -Path $parentDir -ItemType Directory
    }
    elseif (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path
    }

    $NuGetApiKeySecureString | ConvertFrom-SecureString | Export-Clixml $Path
    Write-Verbose -Message "The NuGetApiKey has been encrypted and saved to $Path"
}

Function LoadAndUnencryptNuGetApiKey {
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
    Write-Verbose -Message "The NuGetApiKey has been loaded and unencrypted from $Path"
}