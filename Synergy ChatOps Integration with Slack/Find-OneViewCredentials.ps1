# -------------------------------------------------------------------------------------------------------
#   
#   Finds the RDP sessions from $server
#
# --------------------------------------------------------------------------------------------------------

function Find-OneViewcredentials {
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [string]$server 

    )
  

    # Create a hashtable for the results
    $result = @{ }
 

    $IP = (Get-ChildItem Env: | ? { $_.key -eq "OneView_IP" }).value
    $Username = (Get-ChildItem Env: | ? { $_.key -eq "OneView_username" }).value
    $password = (Get-ChildItem Env: | ? { $_.key -eq "OneView_password" }).value

    
    if ($IP -eq $Null -and $username -eq $Null) { 

        $result.output = "I am not correctly configured as no OneView environment variable can be found ! `nConfigure my OneView settings using ``set IP <IP>``, ``set password <password>`` and ``set username <username>``" 
        $result.success = $false

    }

    elseif ($IP -eq $Null -and $username -ne $Null) {
        
        $env = "I am not correctly configured as no OneView IP is set ! Please use ``set IP <IP>`` `nThe Username set is ``$($Username)``" 

        $result.output = "$($env)" 
        $result.success = $false
    }

    elseif ($IP -ne $Null -and $username -eq $Null) {
        
        $env = "I am not correctly configured as no OneView Username is set ! Please use ``set username <username>``  `nThe OneView IP set is ``$($IP)``" 
        $result.output = "$($env)" 
        $result.success = $false
    }

    elseif ($password -eq $Null) {
        
        $env = "I am not correctly configured as no OneView password is set ! Please use ``set password <password>`` `nThe OneView IP set is ``$($IP)`` `nThe OneView Username set is ``$($Username)``" 
        $result.output = "$($env)" 
        $result.success = $false
    }

    else {
        
        $env = "It seems that I am correctly configured:`nThe OneView IP set is ``$($IP)`` `nThe OneView Username/password is set with ``$($Username)``" 
        $result.output = "$($env)" 
        $result.success = $true
    }

 

    # Return the result and convert it to json
    return $result | ConvertTo-Json
    
}