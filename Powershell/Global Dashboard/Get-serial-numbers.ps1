<# 

This script generates an Excel file with multiple worksheets of all servers, frames and Virtual Connect modules serial number managed by HPE OneView Global Dashboard

Requirements:
   - HPE Global Dashboard administrator account 


  Author: lionel.jullien@hpe.com
  Date:   Nov 2022
    
#################################################################################
#                         Server FW Inventory in rows.ps1                       #
#                                                                               #
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


# Global Dashboard information
$username = "Administrator"
$globaldashboard = "oneview-global-dashboard.lj.lab"
 
# Folder location to generate the CSV files
$path = '.\Powershell\Global Dashboard'

#################################################################################

$secpasswd = read-host  "Please enter the OneView Global Dashboard password" -AsSecureString
 
# To avoid with self-signed certificate: could not establish trust relationship for the SSL/TLS Secure Channel – Invoke-WebRequest
add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
   
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

################################################################################# 

#Creation of the header
$headers = @{ } 
$headers["content-type"] = "application/json" 

# Capturing X-API Version
$xapiversion = ((invoke-webrequest -Uri "https://$globaldashboard/rest/version" -Headers $headers -Method GET ).Content | Convertfrom-Json).currentVersion

$headers["X-API-Version"] = $xapiversion


$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secpasswd)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) 

#Creation of the body
#$Body = @{userName = $username; password = $password; authLoginDomain = "lj.lab" } | ConvertTo-Json 
$Body = @{userName = $username; password = $password; domain = "local" } | ConvertTo-Json 


#Opening a login session with Global DashBoard
$session = invoke-webrequest -Uri "https://$globaldashboard/rest/login-sessions" -Headers $headers -Body $Body -Method Post 

#Capturing the OneView Global DashBoard Session ID and adding it to the header
$key = ($session.content | ConvertFrom-Json).sessionID
$headers["auth"] = $key

# Capturing managed appliances
$ManagedAppliances = (invoke-webrequest -Uri "https://$globaldashboard/rest/appliances" -Headers $headers -Method GET) | ConvertFrom-Json

$OVappliances = $ManagedAppliances.members | ? model -match "Composer"

foreach ($OVappliance in $OVappliances) {

    $OVssoid = $false
    Write-host "`nAppliance name: "-nonewline ; Write-Host $OVappliance.applianceName -f Green  
    Write-host "Appliance IP: "-nonewline ; Write-Host $OVappliance.applianceLocation -f Green  

    $OVIP = $OVappliance.applianceLocation
    $ID = $OVappliance.id
    $apiversion = $OVappliance.currentApiVersion

    #Creation of the header
    $OVheaders = @{ } 
    $OVheaders["content-type"] = "application/json" 
    $OVheaders["X-API-Version"] = $apiversion
    
    do {
        $OVssoid = ((invoke-webrequest -Uri "https://$globaldashboard/rest/appliances/$ID/sso" -Headers $headers -Method GET) | ConvertFrom-Json).sessionID
    } until ($OVssoid )
       
    $OVheaders["auth"] = $OVssoid

    # Retrieve Server hardware information
    $SH_DB = @{}

    $SHs = (invoke-webrequest -Uri "https://$OVIP/rest/server-hardware" -Headers $OVheaders -Method Get | ConvertFrom-Json).members 
     
    foreach ($SH in $SHs) {
          
        $SH_name = $SH.name
        $SH_serialNumber = $SH.serialNumber

        $SH_DB["$($SH_name)"] = $SH_serialNumber
    }

    # Retrieve Frame information
    $Frame_DB = @{}

    $Frames = (invoke-webrequest -Uri "https://$OVIP/rest/enclosures" -Headers $OVheaders -Method Get | ConvertFrom-Json).members 
        
    foreach ($frame in $Frames) {
             
        $frame_name = $frame.name
        $frame_serialNumber = $frame.serialNumber
   
        $Frame_DB["$($frame_name)"] = $frame_serialNumber
    }
       
    # Retrieve Virtual Connect information
    $VC_DB = @{}

    $VCs = ((invoke-webrequest -Uri "https://$OVIP/rest/interconnects" -Headers $OVheaders -Method Get | ConvertFrom-Json).members ) | ? productname -match "Virtual Connect"
    
    foreach ($VC in $VCs) {
         
        $VC_name = $VC.name
        $VC_serialNumber = $VC.serialNumber

        $VC_DB["$($VC_name)"] = $VC_serialNumber
    }
   

}


$SH_DB.GetEnumerator() | Select-Object -Property @{N = 'Compute Names'; E = { $_.Key } }, @{N = 'Serial Numbers'; E = { $_.Value } } |   Export-Csv -NoTypeInformation "$path\Computes_Report.csv"
$Frame_DB.GetEnumerator() | Select-Object -Property @{N = 'Frame Names'; E = { $_.Key } }, @{N = 'Serial Numbers'; E = { $_.Value } } |   Export-Csv -NoTypeInformation  "$path\Frames_Report.csv"
$VC_DB.GetEnumerator() | Select-Object -Property @{N = 'Virtual Connect Module Names'; E = { $_.Key } }, @{N = 'Serial Numbers'; E = { $_.Value } } |   Export-Csv -NoTypeInformation  "$path\Virtual_Connect_Modules_Report.csv"

# Import the three CSV files to Excel file in multiple worksheets
## This following lines won't work without Office installed & licensed

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $true
$wb = $excel.Workbooks.Add()

Get-ChildItem $path\*.csv | ForEach-Object {
    if ((Import-Csv $_.FullName).Length -gt 0) {
        $csvBook = $excel.Workbooks.Open($_.FullName)
        $csvBook.ActiveSheet.Copy($wb.Worksheets($wb.Worksheets.Count))
        $csvBook.Close()
    }
}



remove-item "$path\Computes_Report.csv" -Confirm:$false
remove-item "$path\Frames_Report.csv" -Confirm:$false
remove-item "$path\Virtual_Connect_Modules_Report.csv" -Confirm:$false
