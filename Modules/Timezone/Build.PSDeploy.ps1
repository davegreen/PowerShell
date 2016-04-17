Deploy 'Deploy Timezone Module' {
    By Filesystem Modules {
        FromSource '.\Timezone'
        To "$($($env:PSModulePath).Split(';')[0])\Timezone"
        Tagged Prod
        WithPostScript {
            Remove-Item -Path "$($($env:PSModulePath).Split(';')[0])\Timezone\Build-Manifest.ps1"
        }
    }
}
