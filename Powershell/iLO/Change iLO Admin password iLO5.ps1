# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# Jan 2019
#
# Change the default Administrator account password in all iLOs managed by OneView without using any iLO local account
#
# iLO5 modification is done through OneView and iLO SSO session key using REST POST method
# 
# Requirements:
#    - PowerShell 7 or later
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
# --------------------------------------------------------------------------------------------------------

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


# Capture server hardware managed by HPE OneView
$Computes = Search-OVIndex -Category server-hardware 

if ($Computes) {
    write-host ""
    if (! $Computes.count) { 
        Write-host "1 x iLO is going to be configured:" 
    }
    else {
        Write-host $Computes.Count " x iLO are going to be configured:" 
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


# Capture iLO Administrator account password
$Defaultadmpassword = "password"
$secuadmpassword = Read-Host "Please enter the password you want to assign to all iLos for the user Administrator [$($Defaultadmpassword)]" -AsSecureString

$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secuadmpassword)
$admpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

$admpassword = ($Defaultadmpassword, $admpassword)[[bool]$admpassword]

#Creation of the body content to pass to iLO
$body = @{Password = $admpassword } | ConvertTo-Json 

$error_found = $false

#####################################################################################################################

Foreach ($compute in $computes) {

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

    $Location = "/redfish/v1/accountservice/accounts/1/"
    $method = "patch"  
    
    # Modification of the Administrator password
    try {

        $response = Invoke-RestMethod -Uri ($RootUri + $Location) -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop -SkipCertificateCheck
        
        if ($response.error.'@Message.ExtendedInfo'.MessageId) {

            "[{0} - iLO {1}]: Administrator password has been changed, API response: {2}" -f $servername, $iloIP, $response.error.'@Message.ExtendedInfo'.MessageId | Write-Host 
        }

    }
    catch [System.Net.WebException] {

        if ($null -ne $_.Exception.Response) {
    
            $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
            $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId

            "[{0} - iLO {1}]: Configuration error! Message returned: {2}" -f $servername, $iloIP, $msg | Write-Host -ForegroundColor Red
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
    Write-Host -ForegroundColor Cyan "One or more errors occurred during the configuration. Please review the output above."
}
else {
    Write-Host -ForegroundColor Cyan "All iLOs have been configured successfully."
}


Disconnect-OVMgmt
Read-Host -Prompt "Operation completed ! Hit return to close" 