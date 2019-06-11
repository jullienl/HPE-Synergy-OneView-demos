# -------------------------------------------------------------------------------------------------------
#   
#   Set a persistant Windows environment variable for the IP address of OneView
#
# --------------------------------------------------------------------------------------------------------

function Set-EnvironmentVariable
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]
        $Name,
    
        [Parameter(Mandatory=$true)]
        [String]
        $Value
    
  )
        
    
    # Create a hashtable for the results
    $result = @{}

    Try {
        [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Machine)
        $result.output =  "``$value`` is now set" 
        $result.success = $true
    }
    Catch {
        $result.output =  "``$value`` cannot be set !" 
        $result.success = $false
    }


    # Return the result and conver it to json
    return $result | ConvertTo-Json

}