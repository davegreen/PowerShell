## Overview
An example of using the Release Pipeline Model with a PowerShell module

## Usage
The timezone module has three functions: Get-Timezone, Get-TimezoneFromOffset and Set-Timezone. Get-Timezone and Get-TimezoneFromOffset both return a PSObject representing a timezone:

```
ExampleLocation                         UTCOffset Timezone
---------------                         --------- --------
(UTC) Casablanca                        +00:00    Morocco Standard Time
(UTC) Coordinated Universal Time        +00:00    UTC
(UTC) Dublin, Edinburgh, Lisbon, London +00:00    GMT Standard Time
(UTC) Monrovia, Reykjavik               +00:00    Greenwich Standard Time
```

### Build Operations
A ```psake``` script has been created to manage the various operations related to testing and deployment of the Timezone module.

* Clean and test the script via Pester and Script Analyzer  
```powershell
.\Build.ps1
```

* Test the script with Pester  
```powershell
.\Build.ps1 -Task Test
```

* Test the script with Script Analyzer only  
```powershell
.\Build.ps1 -Task Analyze
```

* Deploy the script via PSDeploy  
```powershell
.\Build.ps1 -Task Deploy
```

## Contact
For help, feedback, suggestions or bugfixes please check out [http://tookitaway.co.uk/](http://tookitaway.co.uk/) or contact david.green@tookitaway.co.uk.

## Thanks
[Brandon Olin](https://devblackops.io) - For his excellent deployment pipeline example, which you can see in use here!.

[Rohn Edwards](https://rohnspowershellblog.wordpress.com) - For his session on advanced parameter completion at the PowerShell Global Summit.
