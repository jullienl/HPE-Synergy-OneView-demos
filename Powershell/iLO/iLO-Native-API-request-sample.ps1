<# 

Example of a PowerShell script to illustrate a typical native API request to iLOs managed by HPE OneView. 

This script will connect to HPE OneView, get the session token, and then use that token to send a request to each iLO.

Gen9/Gen10/Gen10+ servers are supported. PowerShell 5 and 7 are supported.

This script deliberately provides a different payload/URI/method for each iLO model (iLO4,iLO5 and 6) to support queries that might differ depending on the iLO model type.
In this example, where the script changes the iLO's security mode, the payload, URI and method are the same for each iLO type, but this is not always the case.

 Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 

 Author: lionel.jullien@hpe.com
 Date:   May 2022
    
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


# OneView Credentials and IP
$OneView_username = "Administrator"
$OneView_IP = "composer.lab"


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


#################################################################################

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

# Capture server hardware managed by HPE OneView
$Computes = Search-OVIndex -Category server-hardware 

if ($Computes) {
    write-host ""
    if (! $Computes.count) { 
        Write-host "1 x iLO is going to be configured with iLO High Security state to enable:" 
    }
    else {
        Write-host $Computes.Count "x iLO are going to be configured with iLO High Security state to enable:" 
    } 
    $Computes.name | Format-Table -autosize | Out-Host

}
else {
    Write-Warning "No iLO server found ! Exiting... !"
    Disconnect-OVMgmt
    exit
}

# Creation of the headers  
$headers = @{} 
$headers["OData-Version"] = "4.0"

$error_found = $false


#####################################################################################################################

Get-OVServer -Name "Frame3, bay 11" | Get-OVIloSso | fl
Get-OVServer -Name "Frame3, bay 11" | Get-OVIloSso -IloRestSession | fl
Get-OVServer -Name "Frame3, bay 11" | Get-OVIloSso -RemoteConsoleOnly | fl


#####################################################################################################################

foreach ($Compute in $Computes) {

    $iLOIP = $Compute.multiAttributes.mpIpAddresses | ? { $_ -NotMatch "fe80" }
    $servername = $Compute.name
    $iloModel = $Compute.attributes | % mpmodel

    $RootUri = "https://{0}" -f $iloIP
   
    # Capture of the SSO Session Key
    try {
        $ilosessionkey = ($Compute | Get-OVIloSso -IloRestSession -SkipCertificateCheck)."X-Auth-Token"
        $headers["X-Auth-Token"] = $ilosessionkey 
    }
    catch {
        "[{0} - iLO {1}]: Error: Server cannot be contacted at this time. Resolve any issues found in OneView and run this script again. Skipping server!" -f $servername, $iloIP | Write-Host -ForegroundColor Red
        $error_found = $true
        continue 
    }

    # This example modifies the security mode and in this case, the payload/URI/method is the same for each iLO type (which is not always the case).

    # iLO4
    if ($iloModel -eq "ilo4") {

        # Request content to enable iLO High Security state
        $body = @{}
        $body["SecurityState"] = "Production"
        # $body["SecurityState"] = "HighSecurity"
        $body = $body | ConvertTo-Json -Depth 10  

        # iLO4 Redfish URI
        $Location = "/redfish/v1/Managers/1/SecurityService"

        # Method
        $method = "patch"

    }

    # iLO5 
    elseif ($iloModel -eq "ilo5") {
      
        # Request content to enable iLO High Security state
        $body = @{}
        $body["SecurityState"] = "Production"
        # $body["SecurityState"] = "HighSecurity"
        $body = $body | ConvertTo-Json -Depth 10 
        
        # iLO5 Redfish URI
        $Location = "/redfish/v1/Managers/1/SecurityService"
        
        # Method
        $method = "patch"
    }

    # iLO6
    elseif ($iloModel -eq "ilo6") {
    
        # Request content to enable iLO High Security state
        $body = @{}
        $body["SecurityState"] = "Production"
        # $body["SecurityState"] = "HighSecurity"
        $body = $body | ConvertTo-Json -Depth 10 
            
        # iLO6 Redfish URI
        $Location = "/redfish/v1/Managers/1/SecurityService"
            
        # Method
        $method = "patch"
    }

    
    # Enabling iLO High Security state
    try {
        
        $response = Invoke-RestMethod -Uri ($RootUri + $Location) -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop -SkipCertificateCheck
        
        if ($response.error.'@Message.ExtendedInfo'.MessageId) {

            "[{0} - iLO {1}]:  High Security state is now enabled... API response: {2}" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host 
        }

    }
    catch [System.Net.WebException] {

        if ($null -ne $_.Exception.Response) {
    
            $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
            $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId

            "[{0} - iLO {1}]:  Configuration error! Message returned: {2}" -f $servername, $iloIP, $msg | Write-Host -ForegroundColor Red
            $error_found = $true
            continue
    
        }
        else {
            "[{0} - iLO {1}]: WebException occurred, but no response stream is available" -f $servername, $iloIP | Write-Host -ForegroundColor Red
            $error_found = $true
            continue
        }
          
    }
    catch {

        if ($response.error.'@Message.ExtendedInfo'.MessageId) {

            "[{0} - iLO {1}]: Configuration error! Message returned: {2}" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host -ForegroundColor Red
            $error_found = $true
            continue
        }
        else {
            "[{0} - iLO {1}]: Configuration error! Message returned: {2}" -f $servername, $iloIP, $_ | Write-Host -ForegroundColor Red
            $error_found = $true
            continue
        }
    }
}

if ($error_found) {
    Write-Host -ForegroundColor Red "One or more errors occurred during the configuration. Please review the output above."
}
else {
    Write-Host "All iLOs have been configured successfully."
}

Disconnect-OVMgmt
Read-Host -Prompt "Operation completed ! Hit return to close" 