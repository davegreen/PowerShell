Properties {
    $ModuleName  = 'Timezone'
    $BuildLocation = "$($env:TEMP)\$ModuleName"
}

Task default -depends Setup, BuildManifest, Analyze, Test, Teardown

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

Task Analyze -depends Setup, BuildManifest {
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

Task Sign -depends Setup, BuildManifest {
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
    Write-Output $BuildLocation
    Invoke-PSDeploy -Path Build.PSDeploy.ps1 -Force -DeploymentRoot $BuildLocation -Verbose:$VerbosePreference
}

Task  Publish -depends Deploy -requiredVariables $ApiKey {
    Assert ($ApiKey -ne $null) 'API Key required to publish'
    Publish-Module -Name Timezone -NuGetApiKey $ApiKey -Confirm
}

Task Teardown {
    if (Test-Path -Path $BuildLocation) {
        Remove-Item -Path $BuildLocation -Recurse -Force -Verbose:$VerbosePreference
    }
}