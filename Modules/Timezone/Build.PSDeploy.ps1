Deploy 'Deploy Timezone Module' {
    By Filesystem Modules {
        FromSource $DeploymentRoot
        To "$($($env:PSModulePath).Split(';')[0])\Timezone"
        Tagged Prod
    }
}