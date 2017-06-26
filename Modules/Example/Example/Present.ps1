# Setup
Set-Location -Path .\Modules\Example\Example

# Run the default tasks
Invoke-psake -buildFile .\Build.psake.1.ps1

# OK, what tasks are there??
Invoke-psake  -buildFile .\Build.psake.1.ps1 -docs

# Can we get more info
Invoke-psake  -buildFile .\Build.psake.1.ps1 -detaileddocs

# Hmm, what's the ? task
Invoke-psake  -buildFile .\Build.psake.1.ps1 -taskList ?

# Interesting, how about the deploy task
Invoke-psake -buildFile .\Build.psake.1.ps1 -taskList Deploy

# What happens if i pass in two tasks
Invoke-psake -buildFile .\Build.psake.1.ps1 -taskList Deploy, ?

# What about the other way around (task ordering)
Invoke-psake -buildFile .\Build.psake.1.ps1 -taskList ?, Deploy

# Let's get into testing things a little
Invoke-psake -buildFile .\Build.psake.2.ps1 -docs
Invoke-psake -buildFile .\Build.psake.2.ps1

# A quick look at pre, postconditions
$1 = $null
Invoke-psake -buildFile .\Build.psake.2.ps1 -taskList ? #x2
# Why did the second run fail?

# Preconditions run before preactions.
# Postconditions run AFTER postactions.

# OK, lets get back to module stuff!
# Lets try signing my module
Get-Childitem -Path Cert:\CurrentUser\My
Invoke-psake -buildFile .\Build.psake.3.ps1 -taskList sign

Invoke-Item -Path C:\Users\green\AppData\Local\Temp\Example
. 'certmgr.msc'

# Nice one, lets go!
Invoke-psake -buildFile .\Build.psake.3.ps1 -taskList sign

# What about publishing a module?
Invoke-psake -buildFile .\Build.psake.4.ps1 -taskList publish

# Why can't I save some of the settings so this isn't boring?
# Using build properties
# Separating this out
# Storing secrets