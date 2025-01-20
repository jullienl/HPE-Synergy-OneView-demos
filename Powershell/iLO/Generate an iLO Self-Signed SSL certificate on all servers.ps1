<# 

This PowerShell script generates a new iLO self-signed SSL certificate for all servers managed by HPE OneView.


Gen9, Gen10 and Gen10+ servers are supported 

Requirements: 
- Latest HPEOneView library 
- OneView administrator account


Output sample:
    Please enter the OneView password: ********
    [Frame3, bay 1 - iLO 192.168.3.186]: Analysis in progress...
    [Frame3, bay 1 - iLO 192.168.3.186]: iLO self-signed certificate detected that will expire in less than 90 days. Generating a new self-signed certificate...
    [Frame3, bay 1 - iLO 192.168.3.186]: iLO reset in progress to generate a new self-signed certificate...
    [Frame3, bay 1 - iLO 192.168.3.186]: Operation completed successfully! The SSL certificate has been renewed successfully!
    [Frame3, bay 1 - iLO 192.168.3.186]: Waiting for OneView to detect an iLO communication failure...
    [Frame3, bay 1 - iLO 192.168.3.186]: Communication failure detected, removing old certificate and adding the new iLO self-signed certificate to the OneView trust store...!
    [Frame3, bay 1 - iLO 192.168.3.186]: The new iLO self-signed certificate added successfully to the OneView trust store!
    [Frame3, bay 1 - iLO 192.168.3.186]: Refresh in progress to update the status of the server using the new certificate...
    [Frame3, bay 1 - iLO 192.168.3.186]: The SSL certificate has been renewed successfully and communication has been restored with Oneview.
    [Frame3, bay 2 - iLO 192.168.3.187]: Analysis in progress...
    [Frame3, bay 2 - iLO 192.168.3.187]: The iLO uses a certificate with an expiration date greater than 90 days. No action is required as expiration = 2650 days
    Operation completed successfully! All iLOs with a self-signed certificate have been successfully updated.


  Author: lionel.jullien@hpe.com
  Date:   May 2021
    
#################################################################################
#        (C) Copyright 2017 Hewlett Packard Enterprise Development LP           #
#################################################################################
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#                                                                               #
#################################################################################
#>

# VARIABLES

# OneView Credentials and IP
$OneView_username = "Administrator"
$OneView_IP = "composer.lj.lab"


# MODULES TO INSTALL


# Check if the HPE OneView PowerShell module is installed and install it if not
If (-not (get-module HPEOneView.* -ListAvailable )) {
    
    try {
        
        $APIversion = Invoke-RestMethod -Uri "https://$OneView_IP/rest/version" -Method Get | select -ExpandProperty currentVersion
        
        switch ($APIversion) {
            "3800" { [decimal]$OneViewVersion = "6.6" }
            "4000" { [decimal]$OneViewVersion = "7.0" }
            "4200" { [decimal]$OneViewVersion = "7.1" }
            "4400" { [decimal]$OneViewVersion = "7.2" }
            "4600" { [decimal]$OneViewVersion = "8.0" }
            "4800" { [decimal]$OneViewVersion = "8.1" }
            "5000" { [decimal]$OneViewVersion = "8.2" }
            "5200" { [decimal]$OneViewVersion = "8.3" }
            "5400" { [decimal]$OneViewVersion = "8.4" }
            "5600" { [decimal]$OneViewVersion = "8.5" }
            "5800" { [decimal]$OneViewVersion = "8.6" }
            "6000" { [decimal]$OneViewVersion = "8.7" }
            "6200" { [decimal]$OneViewVersion = "8.8" }
            "6400" { [decimal]$OneViewVersion = "8.9" }
            "6600" { [decimal]$OneViewVersion = "9.0" }
            "6800" { [decimal]$OneViewVersion = "9.1" }
            "7000" { [decimal]$OneViewVersion = "9.2" }
            Default { $OneViewVersion = "Unknown" }
        }
        
        Write-Verbose "Appliance running HPE OneView $OneViewVersion"
        
        If ($OneViewVersion -ne "Unknown" -and -not (get-module HPEOneView* -ListAvailable )) { 
            
            Find-Module HPEOneView* | Where-Object version -le $OneViewVersion | Sort-Object version | Select-Object -last 1 | Install-Module -scope CurrentUser -Force -SkipPublisherCheck
            
        }
    }
    catch {
        
        Write-Error "Error: Unable to contact HPE OneView to retrieve the API version. The OneView PowerShell module cannot be installed."
        Return
    }
}


# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force


#################################################################################

Clear-Host

if (! $ConnectedSessions) {
    
    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
    # Connection to the Synergy Composer
    $credentials = New-Object System.Management.Automation.PSCredential ($OneView_username, $secpasswd)
    
    try {
        Connect-OVMgmt -Hostname $OneView_IP -Credential $credentials | Out-Null
    }
    catch {
        Write-Warning "Cannot connect to '$OneView_IP'! Exiting... "
        return
    }
}



#################################################################################

# Retrieve all servers managed by HPE OneView
# $servers = Get-OVServer 

$servers = Get-OVServer | ? { $_.mpModel -eq "iLO5" -or $_.mpModel -eq "iLO6" } | ? status -eq OK
# $servers = Get-OVServer | ? name -eq "Frame3, bay 1"
# $servers = Get-OVServer | ? name -eq "Frame3, bay 2"
# $servers = Get-OVServer | select -first 1


$error_found = $false
$iLO_found = $false

ForEach ($server in $servers) {

    $iloIP = $server.mpHostInfo.mpIpAddresses | ? type -ne LinkLocal | % address
    $servername = $server.name
    $RootUri = "https://{0}" -f $iloIP
    
    $Ilohostname = $server | % { $_.mpHostInfo.mpHostName }
    $iloModel = $server | % mpmodel

    "[{0} - iLO {1}]: Analysis in progress..." -f $servername, $iloIP | write-host 

    try {
        $iloSession = $server | Get-OVIloSso -IloRestSession -SkipCertificateCheck
        
    }
    catch {
        "[{0} - iLO {1}]: Error! Server cannot be contacted at this time. Resolve any issues found in OneView and run this script again. Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
        $error_found = $true
        continue
    }

    
    # Collecting iLO certificate information
    try {
            
        $Location = '/redfish/v1/Managers/1/SecurityService/HttpsCert/'

        $certificate = Invoke-RestMethod -uri ($RootUri + $Location ) -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token' } -SkipCertificateCheck
        
    }
    catch {
        "[{0} - iLO {1}]: Error ! The iLO certificate information cannot be collected! Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
        $error_found = $true
        continue

    }

    $serialnumber = $certificate.X509CertificateInformation.SerialNumber.replace(":", "")
    $ValidNotAfter = $certificate.X509CertificateInformation.ValidNotAfter
    $expiresInDays = [math]::Ceiling((([datetime]$ValidNotAfter) - (Get-Date)).TotalDays)
      

    $iLO_found = $true

    "[{0} - iLO {1}]: Generating a new self-signed certificate..." -f $servername, $iloIP, $days_before_expiration | write-host 

    Try {

        # Send the request to generate a new self-signed Certificate
        $Response = Invoke-RestMethod -uri ($RootUri + $Location ) -Method Delete -Headers @{'Odata-Version' = "4.0"; 'X-Auth-Token' = $ilosession.'X-Auth-Token' } -SkipCertificateCheck

        if ($response.error.'@Message.ExtendedInfo'.MessageId) {

            if ($response.error.'@Message.ExtendedInfo'.MessageId -notmatch "ImportCertSuccessfuliLOResetinProgress") {
                "[{0} - iLO {1}]: Error! Failed to create the certificate signing request! Message returned: {2} - Skipping server!" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
                $error_found = $true
                continue
            }
        }
    }
    Catch {

        "[{0} - iLO {1}]: Error ! Failed to generate a new iLO self-signed certificate! Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
        $error_found = $true
        continue
    }

    "[{0} - iLO {1}]: iLO reset in progress to generate a new self-signed certificate..." -f $servername, $iloIP | Write-Host 
    
    # Remove the old certificate from the OneView trust store (if any)
    if (Get-OVApplianceTrustedCertificate | ? { $_.certificate.serialnumber -eq $serialnumber } ) {

        try {
            Get-OVApplianceTrustedCertificate | ? { $_.certificate.serialnumber -eq $serialnumber } | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete | Out-Null  
            "[{0} - iLO {1}]: The old iLO certificate has been successfully removed from the Oneview trust store" -f $servername, $iloIP | Write-Host 
        }
        catch {
            "[{0} - iLO {1}]: Error! The old iLO certificate cannot be removed from the Oneview trust store! Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
            $error_found = $true
            continue 
            
        }
    }
    
    "[{0} - iLO {1}]: Operation completed successfully! The SSL certificate has been renewed successfully!" -f $servername, $iloIP | Write-Host  
        
    ########################## POST EXECUTIONS ##############################

        
    # Wait for OneView to issue an alert about a trusted communication issue with the iLO due to invalid iLO certificate
    "[{0} - iLO {1}]: Waiting for OneView to detect an iLO communication failure..." -f $servername, $iloIP | Write-Host 

    Do {
        # Collect data for the 'Unable to establish trusted communication with server' alert
        $ilocertalert = ($server | Get-OVAlert -severity Critical -AlertState Locked | Where-Object { 
                $_.description -Match "Unable to establish trusted communication with server"     
            })

        sleep 2
    }
    until ( $ilocertalert )

    "[{0} - iLO {1}]: Communication failure detected, removing old certificate and adding the new iLO self-signed certificate to the OneView trust store..." -f $servername, $iloIP | Write-Host

    sleep 5
      
    # Remove the old iLO certificate from the OneView trust store

    # Remove the old certificate from the OneView trust store (if any)
    if (Get-OVApplianceTrustedCertificate | ? { $_.certificate.serialnumber -eq $serialnumber } ) {

        try {
            Get-OVApplianceTrustedCertificate | ? { $_.certificate.serialnumber -eq $serialnumber } | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete | Out-Null  
            "[{0} - iLO {1}]: The old iLO certificate has been successfully removed from the Oneview trust store" -f $servername, $iloIP | Write-Host 
        }
        catch {
            "[{0} - iLO {1}]: Error! The old iLO certificate cannot be removed from the Oneview trust store! Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
            $error_found = $true
            continue 
                
        }
    }

    sleep 10

    # Add new iLO self-signed certificate to OneView trust store
    $addcerttask = Add-OVApplianceTrustedCertificate -ComputerName $iloIP  -force | Wait-OVTaskComplete -v

    if ($addcerttask.taskstate -eq "Completed" ) {
        "[{0} - iLO {1}]: The new iLO self-signed certificate added successfully to the OneView trust store!" -f $servername, $iloIP | Write-Host 

    }
    else {
        "[{0} - iLO {1}]: Error! Failed to add the new iLO self-signed certificate to the OneView trust store!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
        $error_found = $true
        continue
    }

    sleep 5

    
    # Perform a server hardware refresh to re-establish the communication with the iLO
    try {
        "[{0} - iLO {1}]: Refresh in progress to update the status of the server using the new certificate..." -f $servername, $iloIP | Write-Host 
        $refreshtask = $server | Update-OVServer | Wait-OVTaskComplete
    
    }
    catch {
        "[{0} - iLO {1}]: Error! Failed to refresh the server hardware!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
        $error_found = $true
        continue
    }

    # If refresh is failing, we need to re-add the new iLO certificate and re-launch a server hardware refresh
    if ($refreshtask.taskState -eq "warning") {

        # write-host "The refresh could not be completed successfuly, removing and re-adding the new iLO self-signed certificate..."
        sleep 5
    
        # Remove iLO certificate again
        $iLOcertificatename = $Server | Get-OVApplianceTrustedCertificate | % name
        Get-OVApplianceTrustedCertificate -Name $iLOcertificatename | Remove-OVApplianceTrustedCertificate -Confirm:$false | Wait-OVTaskComplete | Out-Null  
    
        # Add again the new iLO self-signed certificate to OneView trust store 
        $addcerttaskretry = Add-OVApplianceTrustedCertificate -ComputerName $iloip  -force | Wait-OVTaskComplete
    
        sleep 5
    
        # Perform a new refresh to re-establish the communication with the iLO
        $newrefreshtask = $server | Update-OVServer | Wait-OVTaskComplete
    
    }


    # Wait for the trusted communication established with server.
    Do {
        $ilocertalertresult = Send-OVRequest -uri $ilocertalert.uri
        sleep 2
    }
    until ( $ilocertalertresult.alertState -eq "Cleared" )
        
        

    "[{0} - iLO {1}]: The SSL certificate has been renewed successfully and communication has been restored with Oneview." -f $servername, $iloIP | Write-Host 

    
  
     
}

   
if (-not $iLO_found -and -not $error_found) {
    "Operation completed! No action is required as all servers use an unexpired iLO self-signed certificate." | Write-Host -ForegroundColor Cyan

}
if (-not $iLO_found -and $error_found) {
    "Operation completed with errors! Resolve any issues found in OneView and run this script again." | Write-Host -ForegroundColor Cyan

}
elseif ($iLO_found -and $error_found) {
    "Operation completed with errors! Not all iLOs with a self-signed certificate have been successfully updated! Resolve any issues found in OneView and run this script again." | Write-Host -ForegroundColor Cyan

}
elseif ($iLO_found -and -not $error_found) {
    "Operation completed successfully! All iLOs with a self-signed certificate have been successfully updated." | Write-Host -ForegroundColor Cyan

}


Disconnect-OVMgmt
Read-Host -Prompt "`nOperation done ! Hit return to close" 