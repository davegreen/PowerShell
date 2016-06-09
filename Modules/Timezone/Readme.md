## Overview
A PowerShell module designed to make it easier to Get and set the timezone from PowerShell.

This module also serves as my example of using the Release Pipeline Model with a PowerShell module.

Current test status [![Build status](https://ci.appveyor.com/api/projects/status/24cmkti8m8j6sahg?svg=true)](https://ci.appveyor.com/project/davegreen/powershell)

## Usage
The timezone module has two functions: ```Get-Timezone``` and ```Set-Timezone```. ```Get-Timezone``` returns one or more PSObjects that represent a timezone:

```powershell
Get-Timezone

ExampleLocation                         UTCOffset Timezone
---------------                         --------- --------
(UTC) Dublin, Edinburgh, Lisbon, London +00:00    GMT Standard Time
```

It's also possible to get timezones for a particular offset:

```powershell
Get-Timezone -UTCOffset 01:00

ExampleLocation                                               UTCOffset Timezone
---------------                                               --------- --------
(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna  +01:00    W. Europe Standard Time
(UTC+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague +01:00    Central Europe Standard Time
(UTC+01:00) Brussels, Copenhagen, Madrid, Paris               +01:00    Romance Standard Time
(UTC+01:00) Sarajevo, Skopje, Warsaw, Zagreb                  +01:00    Central European Standard Time
(UTC+01:00) West Central Africa                               +01:00    W. Central Africa Standard Time
(UTC+01:00) Windhoek                                          +01:00    Namibia Standard Time
```

Timezone objects can then be passed into Set-Timezone if required, or the timezone can be specified by the timezone name (tab completion is available for this):

```powershell
Set-Timezone -Timezone 'Alaskan Standard Time'
```

### Build Operations
A ```psake``` script has been created to manage the various operations related to testing and deployment of the Timezone module.

* Clean and test the script via Pester and Script Analyzer  
```powershell
.\Build.ps1
```

* Test the script with Script Analyzer
```powershell
.\Build.ps1 -Task Analyze
```

* Analyze, then test the script with Pester
```powershell
.\Build.ps1 -Task Test
```

* Analyze, test, then deploy the script to the current user's module folder
```powershell
.\Build.ps1 -Task Deploy
```
Alternatively, you can deploy to a custom path 
```powershell
.\Build.ps1 -Task Deploy -parameters @{ DeployDir = 'C:\My\Custom\Module\Folder' }
```

* The script can also be signed before deployment, using the first code signing certificate it can find in the current user certificate store
```powershell
.\Build.ps1 -Task DeploySigned
```
Again, you can specify a specific code signing certificate from the current user certificate store
```powershell
.\Build.ps1 -Task DeploySigned @{ CertThumbprint = '01A23BC456D7E8FA90B1C2DE3456FA7890BC1234' }
```

## Contact
For help, feedback, suggestions or bugfixes please check out [http://tookitaway.co.uk/](http://tookitaway.co.uk/) or contact david.green@tookitaway.co.uk.

## Thanks
[Brandon Olin](https://devblackops.io) - For his excellent deployment pipeline example, which you can see in use here!.

[Rohn Edwards](https://rohnspowershellblog.wordpress.com) - For his session on advanced parameter completion at the PowerShell Global Summit.

[Keith Hill](https://rkeithhill.wordpress.com/) - Build script magic from [Plaster](https://github.com/PowerShell/Plaster).