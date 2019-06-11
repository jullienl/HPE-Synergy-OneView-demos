# -------------------------------------------------------------------------------------------------------
#   
#   Finds the RDP sessions from $server
#
# --------------------------------------------------------------------------------------------------------

function Find-sessions
{
    [CmdletBinding()]
    Param
    (
        # Name of the Service
        [Parameter()]
        # Name of the jump station where the lab is run
        [string]$server 

    )
  

    # Create a hashtable for the results
    $result = @{}
 
    
    $usersessions = Get-RDUserSession -ConnectionBroker $server -ErrorAction SilentlyContinue |  select   UserName,SessionState   | % { "`n$($_.UserName) : $($_.SessionState)" } 
    
    if ($usersessions -eq $Null) { 

           $result.output =  "No RDP session found !" 
           $result.success = $false

    }

    else {
        
            $result.output =  "RDP sessions opened  : $($usersessions)" 
            $result.success = $true
    }

 

    # Return the result and conver it to json
    return $result | ConvertTo-Json
    
}