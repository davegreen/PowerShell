Deploy 'Deploy Timezone Module' {
    By Filesystem Modules {
        FromSource '.\Timezone'
        To "$($($env:PSModulePath).Split(';')[0])\Timezone"
        Tagged Prod
        WithPreScript {
            . '.\Timezone\Build-Manifest.ps1'
        }
        WithPostScript {
            Remove-Item -Path "$($($env:PSModulePath).Split(';')[0])\Timezone\Build-Manifest.ps1"
        }
    }
}
