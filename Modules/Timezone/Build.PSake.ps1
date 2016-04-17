Task default -depends BuildManifest, Analyze, Test

Task BuildManifest {
    . "$PSScriptRoot\Timezone\Build-Manifest.ps1"
}

Task CleanManifest {
    if (Test-Path -Path "$PSScriptRoot\Timezone\Timezone.psd1") {
        Remove-Item -Path "$PSScriptRoot\Timezone\Timezone.psd1"
    }
}

Task Analyze {
    $analysisResult = Invoke-ScriptAnalyzer -Path $PSScriptRoot -Severity @('Error', 'Warning') -Recurse -Verbose:$false
    if ($analysisResult) {
        $analysisResult | Format-Table  
        Write-Error -Message 'One or more Script Analyzer errors/warnings where found. Build cannot continue!'        
    }
}

Task Test {
    $TestResult = Invoke-Pester -Path $PSScriptRoot -PassThru -Verbose:$VerbosePreference
    
    if ($TestResult.FailedCount -gt 0) {
        $TestResult | Format-List
        Write-Error -Message 'One or more Pester tests for the deployment failed. Build cannot continue!'
    }
}

Task Deploy -depends BuildManifest, Analyze, Test {
    Invoke-PSDeploy -Path Build.PSDeploy.ps1 -Force -Verbose:$VerbosePreference

    if (Test-Path -Path "$PSScriptRoot\Timezone\Timezone.psd1") {
        Remove-Item -Path "$PSScriptRoot\Timezone\Timezone.psd1"
    }
}