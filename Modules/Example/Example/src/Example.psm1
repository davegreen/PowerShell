# Import module files
Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}