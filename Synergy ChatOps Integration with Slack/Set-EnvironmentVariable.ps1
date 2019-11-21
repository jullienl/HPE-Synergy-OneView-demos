# -------------------------------------------------------------------------------------------------------
#   
#   Set a persistant Windows environment variable for the Username/Password, IP address of OneView
#
# --------------------------------------------------------------------------------------------------------

function Set-EnvironmentVariable {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Name,
    
        [Parameter(Mandatory = $true)]
        [String]
        $Value
    
    )
        
    
    $servicename = "Hubot_Hubot"

    # Create a hashtable for the results
    $result = @{ }

    Try {
        [Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Machine)
        
        sleep 5

        # Checking the presence of the Hubot Windows service   
        Try {
            Restart-Service $servicename -ErrorAction stop -WhatIf
        }
        Catch {
            $result.output = "I cannot configure ``$value`` as the Windows service ``$($servicename)`` cannot be found on my Windows machine !`nPlease modify ``Set-EnvironmentVariable.ps1`` with the correct service name (line 22)" 
            $result.success = $false
            return $result | ConvertTo-Json    
        }

        $result.output = "``$value`` is now set, please wait while I restart my ``$($servicename)`` Windows service..." 
        $result.success = $true
    }
    Catch {
        $result.output = "``$value`` cannot be set !" 
        $result.success = $false
    }


    # Restarting the Hubot windows service to activate the new environment variable in Hubot
    Start-Process powershell.exe -ArgumentList "-file $PSScriptRoot\restart-hubotservice.ps1", "Hubot_Hubot"   
     
   
    # Return the result and convert it to json
    return $result | ConvertTo-Json

}