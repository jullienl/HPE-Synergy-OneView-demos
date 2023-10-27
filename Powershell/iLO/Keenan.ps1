
<#

1.	Check and flash iLO version if needed
2.	Update DNS, maybe check forward/reverse lookup
3.	Update NTP
4.	Set enhanced download
5.	Check AMS/SUT presence and version
6.	Able to try alternate iLO credentials if primary fails…. And then update iLO account password to standard
7.	Output SN/PN to CSV for import to GreenLake, and a separate logging CVS with a for each node, one field for each step success/failure

#>

$iLOhostname = "DL360G10p-1-ilo.lj.lab"

# iLO Credentials 
$iLO_username = "Administrator"
$ilo_password = "password"

# iLO Alternate Credentials 
$iLO_alternate_username = "demopaq"
$ilo_alternate_password = "password"

# Location of the iLO5 firmware 
$iLO5_Location = "D:\\Kits\\_HP\\iLO\\iLO5\\ilo5_244.bin" 
# Location of the iLO4 firmware 
$iLO6_Location = "D:\\Kits\\_HP\\iLO\\iLO6\\ilo6_2.bin" 


$NTPServer1 = "192.168.2.1"
$NTPServer2 = "192.168.2.3"

$DNSServer1 = "192.168.2.1"
$DNSServer2 = "192.168.2.3"




# Save output to file to execution directory
# $directorypath = Split-Path $MyInvocation.MyCommand.Path
# Start-Transcript -path $directorypath\$report -append

# Object to save result
$SettingsStatus = [System.Collections.ArrayList]::new()


# Build object for the output
$objStatus = [pscustomobject]@{
  
    iLO                           = $iLOhostname
    FirmwareUpdate                = $Null
    FirmwareUpdateStatus          = $Null
    ResourceRestrictionPolicyName = $Null
    NTPServers                    = $Null
    NTPServersStatus              = $Null
    Status                        = $Null
    Details                       = $Null
    Exception                     = $Null
                  
}



#############################################################################################################################
#Region Collecting iLO data 

# HPE iLO PowerShell Cmdlets 
If (-not (get-module HPEiLOCmdlets -ListAvailable )) { Install-Module -Name HPEiLOCmdlets -scope Allusers -Force }

clear-host

$secpasswd = ConvertTo-SecureString -String $ilo_password -AsPlainText -Force
$ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $secpasswd)

$connection = Connect-HPEiLO -Credential $ilocreds -Address $iLOhostname -DisableCertificateAuthentication 

$iLOIP = $connection.ip
$iloGen = $connection.TargetInfo.iLOGeneration
$ProductName = $connection.TargetInfo.ProductName
$XAuthToken = $connection.ConnectionInfo.Redfish.XAuthToken
$ODataVersion = $connection.ConnectionInfo.Redfish.ODataVersion
$iLOinfo = Get-HPEiLOInfo -Address $ilohost -DisableCertificateAuthentication
$SystemInfo = Get-HPEiLOSystemInfo -Connection $Connection
$PartNumber = $SystemInfo.SKU
$SerialNumber = $SystemInfo.SerialNumber
$serverName = $SystemInfo.DNSHostName
if (! $serverName) { $serverName = "Unnamed" }

#EndRegion

#############################################################################################################################
#Region iLO Session creation 

$headers = @{} 
$headers["OData-Version"] = "4.0"
$headers["Content-Type"] = "application/json"

$body = @{} 
$body["UserName"] = $iLO_username
$body["Password"] = $ilo_password
$body = $Body | ConvertTo-Json


$Session = Invoke-webrequest "https://$iLOhostname/redfish/v1/SessionService/Sessions/" -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck
$msg = ($Session.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId


if (-not $Session) {

    $body = @{} 
    $body["UserName"] = $iLO_alternate_username
    $body["Password"] = $ilo_alternate_password
    $body = $Body | ConvertTo-Json

    $AlternateSession = Invoke-webrequest "https://$iLOhostname/redfish/v1/SessionService/Sessions/" -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck
    $msg = ($AlternateSession.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId

    if (-not  $AlternateSession) {

        # Must return a message if session creation error
        "{0}: iLO Session cannot be created." -f $iLOhostname | Write-Verbose
        $objStatus.Status = "Failed"
        $objStatus.Details = "iLO session cannot be created with both credentials and alternate credentials!"
    
        $objStatus.Exception = $msg
        
    } 
        
}
else {

    if ($AlternateSession) {
        $Session = $AlternateSession
    }

    $token = $Session.headers | % X-Auth-Token
    $headers["X-Auth-Token"] = $token


    #EndRegion 

    #######################################################################################################################
    #Region iLO Firmware update 

    try {

        if ($iloGen -match "iLO5") {
            $task = Update-HPEiLOFirmware -Location $iLO5_location -Connection $connection -Confirm:$False -Force
        }
        elseif ($iloGen -match "iLO6") {
            $task = Update-HPEiLOFirmware -Location $iLO6_location -Connection $connection -Confirm:$False -Force
        }
            
        "{0} {1} [{2} - {3} - {4}]: {5}" -f $iloGen, $iloIP, $iLOhostname, $serverName, $ProductName, $task.statusinfo.message | Write-Verbose

        $objStatus.FirmwareUpdate = "Complete"
        $objStatus.FirmwareUpdateStatus = "iLO Firmware upgrade successful!"

    }
    catch {
            
        "{0} {1} [{2} - {3} - {4}]: Firmware upgrade failure!" -f $iloGen, $iloIP, $iLOhostname, $serverName, $ProductName | Write-Verbose
        $objStatus.FirmwareUpdate = "Failed"
        $objStatus.FirmwareUpdateStatus = "iLO Firmware upgrade failure!"

        $objStatus.Exception = $_.Exception.message 

    }

   
    #Endregion

   
    #######################################################################################################################
    #Region Set iLO DNS Configuration, maybe check forward/reverse lookup

    $DNSServersList = [System.Collections.ArrayList]::new()

    $DNSServersList += $DNSServer1
    $DNSServersList += $DNSServer2

    $body = @{}
    $body["DHCPv4"] = [pscustomobject]@{ UseDNSServers = $false }
    $body["Oem"] = @{"Hpe" = @{"IPv4" = @{"DNSServers" = @($DNSServersList) } } }
    $body = $body | ConvertTo-Json  -Depth 5

    # Creation of the headers  
    $headers = @{} 
    $headers["OData-Version"] = "4.0"

    # iLO5 Redfish URI
    $uri = "/redfish/v1/Managers/1/EthernetInterfaces/1/"

    # Method
    $method = "patch"


    try {
      
        $response = Invoke-WebRequest -Uri $uri -Body $body -ContentType "application/json" -Headers $header -Method $method -SkipCertificateCheck -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        
        "{0} {1} [{2} - {3} - {4}]: {5}" -f $iloGen, $iloIP, $iLOhostname, $serverName, $ProductName, $msg | Write-Verbose

        $objStatus.FirmwareUpdate = "Complete"
        $objStatus.FirmwareUpdateStatus = "iLO DNS configuration successful!"

    }
    catch {
            
        "{0} {1} [{2} - {3} - {4}]: DNS configuration failure!" -f $iloGen, $iloIP, $iLOhostname, $serverName, $ProductName | Write-Verbose

        $objStatus.NTPServers = "Failed"
        $objStatus.NTPServersStatus = "iLO DNS configuration failure!"

        $objStatus.Exception = $_.Exception.message 

    }


    #Endregion


    #######################################################################################################################
    #Region iLO NTP update +

    $NTPServersList = [System.Collections.ArrayList]::new()

    $NTPServersList += $NTPServer1
    $NTPServersList += $NTPServer2


    $body = @{}
    $body["StaticNTPServers"] = $NTPServersList
    $body = $body | ConvertTo-Json  


    # Creation of the headers  
    $headers = @{} 
    $headers["OData-Version"] = "4.0"

    # iLO5 Redfish URI
    $uri = "/redfish/v1/Managers/1/DateTime/"

    # Method
    $method = "patch"


    try {
      
        $response = Invoke-WebRequest -Uri $uri -Body $body -ContentType "application/json" -Headers $header -Method $method -SkipCertificateCheck -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        
        "{0} {1} [{2} - {3} - {4}]: {5}" -f $iloGen, $iloIP, $iLOhostname, $serverName, $ProductName, $msg | Write-Verbose

        $objStatus.FirmwareUpdate = "Complete"
        $objStatus.FirmwareUpdateStatus = "iLO Static NTP servers configuration successful!"

    }
    catch {
            
        "{0} {1} [{2} - {3} - {4}]: Static NTP servers configuration failure!" -f $iloGen, $iloIP, $iLOhostname, $serverName, $ProductName | Write-Verbose

        $objStatus.NTPServers = "Failed"
        $objStatus.NTPServersStatus = "iLO Static NTP servers configuration failure!"

        $objStatus.Exception = $_.Exception.message 

    }

    #Endregion



    #######################################################################################################################
    #Region iLO Set enhanced download performance 
    
    $body = @{}
    $body["Oem"] = @{"Hpe" = @{"EnhancedDownloadPerformanceEnabled" = $True } }
    $body = $body | ConvertTo-Json  -Depth 5

    # Creation of the headers  
    $headers = @{} 
    $headers["OData-Version"] = "4.0"

    # iLO5 Redfish URI
    $uri = "/redfish/v1/Managers/1/networkprotocol"

    # Method
    $method = "patch"


    try {
      
        $response = Invoke-WebRequest -Uri $uri -Body $body -ContentType "application/json" -Headers $header -Method $method -SkipCertificateCheck -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        
        "{0} {1} [{2} - {3} - {4}]: {5}" -f $iloGen, $iloIP, $iLOhostname, $serverName, $ProductName, $msg | Write-Verbose

        $objStatus.FirmwareUpdate = "Complete"
        $objStatus.FirmwareUpdateStatus = "iLO DNS configuration successful!"

    }
    catch {
            
        "{0} {1} [{2} - {3} - {4}]: DNS configuration failure!" -f $iloGen, $iloIP, $iLOhostname, $serverName, $ProductName | Write-Verbose

        $objStatus.NTPServers = "Failed"
        $objStatus.NTPServersStatus = "iLO DNS configuration failure!"

        $objStatus.Exception = $_.Exception.message 

    }


    #Endregion



    #######################################################################################################################
    #Region Check AMS/SUT presence and version


    #Endregion


    #######################################################################################################################
    #Region Able to try alternate iLO credentials if primary fails…. And then update iLO account password to standard

    $Primarycredentials
    $SecondaryCredentials

    # iLO Credentials 
    $iLO_username = "demopaq"
    $ilo_password = "password"


    $secpasswd = ConvertTo-SecureString -String $ilo_password -AsPlainText -Force
    $ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $secpasswd)

    $connection = Connect-HPEiLO -Credential $ilocreds -Address $iloHost -DisableCertificateAuthentication 
 
    $connection = Connect-HPERedfish -Address $iloHost -Credential $ilocreds -DisableCertificateAuthentication

    $task = Get-HPERedfishDataRaw -Session $connection -Odataid "/redfish/v1/Chassis/1/Thermal" -DisableCertificateAuthentication 

    # Capture of the SSO Session Key
    $iloSession = $compute | Get-OVIloSso -IloRestSession
    $ilosessionkey = $iloSession."X-Auth-Token"

    $iloIP = $compute.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
 
    # Creation of the header using the SSO Session Key 
    $headerilo = @{ } 
    $headerilo["X-Auth-Token"] = $ilosessionkey 


    
    # Modification of the Administrator password
    try {
        $response = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/accountservice/accounts/1/" -Body $bodyiloParams -ContentType "application/json" -Headers $headerilo -Method PATCH -UseBasicParsing -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        Write-Host "Administrator password has been changed in iLO $iloIP, message returned: [$($msg)]"

    }
    catch {
        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
        $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloIP): Error ! Password cannot be changed ! Message returned: [$($msg)]"
        continue
    }

    
    #Endregion

    #######################################################################################################################
    # Output SN/PN to CSV for import to Greenlake, and a separate logging CVS with a for each node, one field for each step success/failure


 
}




[void]$SettingsStatus.add($objStatus)

if ($SettingsStatus | Where-Object { $_.Status -eq "Failed" }) {

    write-error "One or more iLO failed the configuration attempt!"
  
}


Return $SettingsStatus










$OneView_IP = "192.168.1.10"

##############################################

####  Establish connection to OneView  ####

$Username = “Administrator”
$Password = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential $Username, $Password

$ConnctionOV = Connect-OVMgmt -Hostname $OneView_IP -Credential $Credentials




$ilo_Collection = (Import-Csv -Path Z:\Scripts\GitHub_HPE-Synergy-OneView-demos\Powershell\iLO\ilo.csv).ip


ForEach ($iLO in $iLO_Collection) {

    #### check if server is in OneView and eject if found ####
    Write-Host "Checking OneView for " $iLO

    $matchSH = Search-OVIndex -Category server-hardware | ? { $_.multiAttributes.mpIpAddresses -eq $iLO }

    Remove-OVServer $matchSH.uri -confirm:$false -force

}

$SH = Get-OVServer 
    
$SH.mpHostInfo.mpIpAddresses | ConvertTo-Json -d 4

$SH.mpHostInfo.mpIpAddresses | gm

$SH.mpHostInfo.mpIpAddresses.address |  ConvertTo-Json -d 4
    
$SH.mpHostInfo.mpIpAddresses.address$SH.mpHostInfo.mpIpAddresses.address | ConvertTo-Json -d 4

$SH.mpHostInfo.mpIpAddresses.address

$SH.mpHostInfo.mpIpAddresses.address.ToString()  


     


$SH.mpHostInfo.mpIpAddresses.Address



Get-OVServer | ? { $_.mpHostInfo.mpIpAddresses.address -eq "192.168.0.39" }
    
Get-OVServer | ? { $_.mpHostInfo.mpIpAddresses -eq $iLO }
    
.mpHostInfo.mpIpAddresses | ? { $_.type -NotMatch "LinkLocal" }).address | ConvertTo-Json -d 4

    
| Where-Object { $_.mpHostInfo.mpIpAddresses -eq $iLO }

$matchiLOIP

}