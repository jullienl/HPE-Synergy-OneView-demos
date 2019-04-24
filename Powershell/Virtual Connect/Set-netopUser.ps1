# This script sets the password for the netop VC CLI user in the Synergy VC interconnects
#
# Note: netop user is only supported for Virtual Connect SE 40Gb F8 Modules and Virtual Connect SE 100Gb F32 Modules for Synergy.
#
# In OneView 4.20 we change the netop configuration because previously existing default/hardcoded password was considered a security issue. 
#
# New behavior is:
#
# - Existing LE update from earlier version to OV 4.20 or later will preserve the netop/netoppwd user/password combo for all modules
# - New LE in OV 4.20 or later will not have default netop user configured and will require REST API to enable it
#
# Script requirements: Composer 4.20
# OneView Powershell Library is not required



# Defining the netop VC CLI user password
$netoppwd = "mypassword"


# Composer information
$username = "Administrator"
$password = "password"
$composer = "composer.lj.lab"
 

function Failure {
    $global:helpme = $bodyLines
    $global:helpmoref = $moref
    $global:result = $_.Exception.Response.GetResponseStream()
    $global:reader = New-Object System.IO.StreamReader($global:result)
    $global:responseBody = $global:reader.ReadToEnd();
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "`nStatus: A system exception was caught."
    Write-Host -BackgroundColor:Black -ForegroundColor:Red `n$global:responsebody
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "`nThe request body has been saved to `$global:helpme"
    #break
}


#Creation of the header
$headers = @{ } 
$headers["content-type"] = "application/json" 
$headers["X-API-Version"] = "1000"

#Creation of the body
$Body = @{userName = $username; password = $password; authLoginDomain = "Local"; loginMsgAck = "true" } | ConvertTo-Json 

#Opening a login session with Composer
$session = invoke-webrequest -Uri "https://$composer/rest/login-sessions" -Headers $headers -Body $Body -Method Post 


#Capturing the Composer Session ID and adding it to the header
$key = ($session.content | ConvertFrom-Json).sessionID
$headers["auth"] = $key

#Retrieving interconnect URI information for all VC 40G modules
$interconnects = (invoke-webrequest -Uri "https://$composer/rest/interconnects" -Headers $headers -Method Get ).content | ConvertFrom-Json
$interconnecturis = ($interconnects.members | Where-Object model -match "Virtual Connect SE 40Gb F8 Module for Synergy").uri

#Preparing body to change the netop password
$operation = '   { "op" : "replace", "path" : "/netOpPasswd", "value" : "' + $netoppwd + '" }'
$payload = "[`n" + $operation + "`n]"

#Setting up the netop user with the $netoppwd variable
Foreach ($interconnecturi in $interconnecturis) {
    
    $link = $composer + $interconnecturi

    try {
    
        invoke-webrequest -Uri "https://$link/" -Headers $headers -Body $payload -Method Patch
    }
    catch {

        failure

    }

}