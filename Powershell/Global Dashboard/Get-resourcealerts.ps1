$username = "Administrator"
$password = "P@ssw0rd"
 
#Creation of the header
$headers = @{ } 
$headers["content-type"] = "application/json" 
$headers["X-API-Version"] = "2"

#Creation of the body
#$Body = @{userName = $username; password = $password; authLoginDomain = "lj.lab" } | ConvertTo-Json 
$Body = @{userName = $username; password = $password; domain = "local" } | ConvertTo-Json 

#Opening a login session with Global DashBoard
$session = invoke-webrequest -Uri "https://192.168.1.50/rest/login-sessions" -Headers $headers -Body $Body -Method Post 


#Capturing the OneView Global DashBoard Session ID and adding it to the header
$key = ($session.content | ConvertFrom-Json).sessionID
$headers["auth"] = $key


#Capturing the OneView Global DashBoard alerts
$resourcealerts = (invoke-webrequest -Uri "https://192.168.1.50/rest/resource-alerts" -Headers $headers -Method GET) | ConvertFrom-Json
Clear-Host
if (($resourcealerts.total) -eq "0") {
    Write-host "No alert found !`n"
    
}
else {

    Write-host "`nThe number of alerts is " -NoNewline; write-host $resourcealerts.count -ForegroundColor Green
    Write-host "`nThe latest 5 alerts are: "
    $resourcealerts.members | select -First 5 | Format-List -Property severity, description, correctiveAction
}