Function Get-Timezone {
    <#
      .Synopsis
      A function that retrieves valid computer timezones.

      .Description
      This function is a wrapper around tzutil.exe,
      aiming to make getting timezones slightly easier.

      .Parameter Timezone
      Specify the timezone that you wish to retrieve data for.
      Not specifying this parameter will return the current timezone.

      .Parameter UTCOffset
      Specify the offset from UTC to return timezones for,
      using the format NN:NN (implicitly positive), -NN:NN or +NN:NN.

      .Parameter All
      Return all timezones supported by tzutil available on the system.

      .Example
      Get-Timezone

      Gets the current computer timezone

      .Example
      Get-Timezone -Timezone 'Singapore Standard Time'

      Get the timezone for Singapore standard time (UTC+08:00).

      .Example
      Get-Timezone -All

      Returns all valid computer timezones.

      .Notes
      Author: David Green (http://tookitaway.co.uk/)
    #>

    [CmdletBinding(
        DefaultParametersetName = 'Specific'
    )]

    Param(
        [Parameter(
            Position                        = 1,
            ParameterSetName                = 'Specific',
            ValueFromPipeline               = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage                     = 'Specify the timezone to set (from "tzutil /l").'
        )]
        [ValidateScript( {
            $tz = (tzutil /l)
            $validoptions = foreach ($t in $tz) {
                if (($tz.IndexOf($t) -1) % 3 -eq 0) {
                    $t.Trim()
                }
            }

            $validoptions -contains $_
        })]
        [string[]]$Timezone = (tzutil /g),

        [Parameter(
            Position         = 2,
            ParameterSetName = 'ByOffset',
            HelpMessage      = 'Specify the timezone offset.'
        )]
        [ValidateScript({
            $_ -match '^[+-]?[0-9]{2}:[0-9]{2}$'
        })]
        [string[]]$UTCOffset,

        [Parameter(
            Position         = 3,
            ParameterSetName = 'All',
            HelpMessage      = 'Show all timezones.'
        )]
        [switch]$All
    )

    Begin {
        $tz = tzutil /l

        $Timezones = foreach ($t in $tz) {
            if (($tz.IndexOf($t) -1) % 3 -eq 0) {
                $TimezoneProperties = @{
                    Timezone        = $t
                    UTCOffset       = $null
                    ExampleLocation = ($tz[$tz.IndexOf($t) - 1]).Trim()
                }

                if (($tz[$tz.IndexOf($t) - 1]).StartsWith('(UTC)')) {
                    $TimezoneProperties.UTCOffset = '+00:00'
                }
                elseif (($tz[$tz.IndexOf($t) - 1]).Length -gt 10) {
                    $TimezoneProperties.UTCOffset = ($tz[$tz.IndexOf($t) - 1]).SubString(4, 6)
                }

                $TimezoneObj = New-Object -TypeName PSObject -Property $TimezoneProperties
                Write-Output $TimezoneObj
            }
        }
    }

    Process {
        switch ($PSCmdlet.ParameterSetName) {
            'All' {
                if ($All) {
                    Write-Output $Timezones
                }
            }

            'Specific' {
                foreach ($t in $Timezone)
                {
                    Write-Output $Timezones | Where-Object { $_.Timezone -eq $t }
                }
            }

            'ByOffset' {
                foreach ($Offset in $UTCOffset) {
                    $OffsetOutput = switch ($Offset) {
                        { $_ -match '^[+-]00:00'} {
                            Write-Output '+00:00'
                        }

                        { $_ -match '^[0-9]' } {
                            Write-Output "+$Offset"
                        }

                        default {
                            Write-Output $Offset
                        }
                    }

                    Write-Output $Timezones | Where-Object { $_.UTCOffset -eq $OffsetOutput }
                }
            }
        }
    }
}

Function Set-Timezone {
    <#
      .Synopsis
      A function that sets the computer timezone.

      .Description
      This function is a wrapper around tzutil.exe, aiming to make setting timezones slightly easier.

      .Parameter Timezone
      A string containing the display name of the timezone you require.
      Only valid timezones (from 'Get-Timezone -All', or 'tzutil /l') are supported.

      .Parameter WhatIf
      If Whatif is specified, the user is notified about the timezone that would be set.

      .Parameter Confirm
      If Confirm is specified, the command will ask for input to change the currently effective timezone.

      .Example
      Set-Timezone -Timezone 'Singapore Standard Time'

      Set the timezone to Singapore standard time (UTC+08:00).

      .Notes
      Author: David Green (http://tookitaway.co.uk/)
    #>

    [CmdletBinding(
        SupportsShouldProcess = $True,
        ConfirmImpact         = 'Medium'
    )]

    Param(
        [Parameter(
            Position                        = 1,
            Mandatory                       = $True,
            ValueFromPipeline               = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage                     = 'Specify the timezone to set (from "Get-Timezone -All").'
        )]
        [ValidateScript({
            if (Get-Timezone -Timezone $_) {
                $True
            }
        })]
        [string]$Timezone
    )

    if ($PSCmdlet.ShouldProcess($Timezone)) {
        Write-Verbose "Setting Timezone to $Timezone"
        tzutil.exe /s $Timezone
    }
}

if ([version]$psversiontable.psversion -gt [version]'4.0') {
    Register-ArgumentCompleter -CommandName Get-Timezone, Set-Timezone -ParameterName Timezone -ScriptBlock {
        # This is the argument completer to return available timezone
        # parameters for use with getting and setting the timezone.
        Param(
            $commandName,        #The command calling this arguement completer.
            $parameterName,      #The parameter currently active for the argument completer.
            $currentContent,     #The current data in the prompt for the parameter specified above.
            $commandAst,         #The full AST for the current command.
            $fakeBoundParameters #A hashtable of the current parameters on the prompt.
        )

        $tz = Get-Timezone -All
        $tz | Where-Object { $_.Timezone -like "$($currentContent)*" } | ForEach-Object {
            $CompletionText = $_.Timezone
            if ($_ -match '\s') {
                $CompletionText = "'$($_.Timezone)'"
            }

            New-Object System.Management.Automation.CompletionResult (
                $CompletionText,                     #Completion text that will show up on the command line.
                "$($_.Timezone) ($($_.UTCOffset))",  #List item text that will show up in intellisense.
                'ParameterValue',                    #The type of the completion result.
                "$($_.Timezone) ($($_.UTCOffset))"   #The tooltip info that will show up additionally in intellisense.
            )
        }
    }
}