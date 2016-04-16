## Overview
An example of using the Release Pipeline Model with a PowerShell module

## Usage
A ```psake``` script has been created to manage the various operations related to testing and deployment of the Timezone module.

### Build Operations

* Test the script via Pester and Script Analyzer  
```powershell
.\build.ps1
```
    
* Test the script with Pester only  
```powershell
.\build.ps1 -Task Test
```
    
* Test the script with Script Analyzer only  
```powershell
.\build.ps1 -Task Analyze
```
    
* Deploy the script via PSDeploy  
```powershell
.\build.ps1 -Task Deploy
```

Contact
---------------------

For help, feedback, suggestions or bugfixes please check out [http://tookitaway.co.uk/](http://tookitaway.co.uk/) or contact david.green@tookitaway.co.uk.

Thanks
---------------------

[Brandon Olin](https://devblackops.io) - For his excellent deployment pipeline example, which you can see in use here!.
[Rohn Edwards](https://rohnspowershellblog.wordpress.com) - For his session on advanced parameter completion at the PowerShell Global Summit.