# This script corrects the SNMPv3 incorrect Engine ID settings in OneView 4.20
# that is causing OneView to send incorrect SNMPv3 trap format
#
# Script requirements: Composer 4.20
# OneView Powershell Library is not required
# 
# Note: If using a OneView Self-signed certificate, it is required to uncomment line 29


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

# Uncomment the following line if facing the error: "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."  (usually due to using a OneView Self-signed certificate)
# [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

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

#Retrieving SNMPv3 information 
$snmpv3 = (invoke-webrequest -Uri "https://$composer/rest/global-settings/appliance/global/applianceSNMPv3EngineId" -Headers $headers -Method Get ).content | ConvertFrom-Json 

#Capturing SNMPv3 value and reducing to 32 bytes (16 characters)
$snmpv3value = ($snmpv3.value).SubString(0, 16)

#Creating the Payload for the PUT rest call
$payload = ConvertTo-Json  @{ type = "SettingV2"; name = "applianceSNMPv3EngineId" ; value = $snmpv3value } 


#Reconfiguraing SNMPv3 settings
try {
    
    invoke-webrequest -Uri "https://$composer/rest/global-settings/appliance/global/applianceSNMPv3EngineId" -Headers $headers -Body $payload -Method PUT | out-Null

    Write-Host "Operation done ! The SNMPv3 engine ID is now correctly set."
}
catch {

    failure

}





