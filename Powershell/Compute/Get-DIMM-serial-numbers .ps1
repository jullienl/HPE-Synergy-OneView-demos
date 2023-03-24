<# 

This script generates a CSV file to retrieve all memory DIMM serial numbers for all Gen10/Gen10 Plus servers managed by one or more HPE OneView appliances. 

Output example:

DIMM_SerialNumber Server_Name    Server_SerialNumber
----------------- -----------    -------------------
94E6D055          Frame3, bay 1  CZ212406GL
94E6D055          Frame3, bay 1  CZ212406GL
94E6D055          Frame3, bay 1  CZ212406GL
94E6D055          Frame3, bay 1  CZ212406GL
94E6D055          Frame3, bay 1  CZ212406GL
94E6D055          Frame3, bay 1  CZ212406GL
94E6D055          Frame3, bay 1  CZ212406GL
94E6D055          Frame3, bay 1  CZ212406GL
474D5B52          Frame3, bay 10 CZ221705V7
474D182B          Frame3, bay 11 CZ221705V1
474D25E9          Frame3, bay 12 CZ221705V6

Requirements:
   - HPE OneView administrator account 
   - HPE OneView Powershell Library


  Author: lionel.jullien@hpe.com
  Date:   March 2023
    
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

# OneView appliance list
$appliances = @("192.168.1.110")#, "192.168.1.10")


# Location of the folder to generate the CSV file
$path = '.\Powershell\Compute'
$Filename = 'DIMMs_Report.csv'

#################################################################################


# OneView Credentials
$OV_username = "Administrator" 
$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the OneView / Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)


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

$DIMM_DB = @()

foreach ($appliance in $appliances) {
   
    try {
        Connect-OVMgmt -Hostname $appliance -Credential $credentials -ErrorAction stop | Out-Null    
    }
    catch {
        Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
        return
    }
    
    # Retrieve Server hardware information
 

    $SHs = Get-OVServer | ? model -match "Synergy" | ? model -match "Gen10"
    
    
    # Creation of the headers  
    $headers = @{} 
    $headers["OData-Version"] = "4.0"

    # iLO5 Redfish URI
    $uri = "/redfish/v1/Systems/1/Memory/?`$expand=."

    # Method
    $method = "GET"

    foreach ($SH in $SHs) {

        $SH_name = $SH.name
        $SH_serialNumber = $SH.serialNumber
        
        $Object = [pscustomobject]@{

            DIMM_SerialNumber   = $Null
            DIMM_PartNumber     = $Null
            Server_Name         = $SH_name
            Server_SerialNumber = $SH_serialNumber
                  
        }

        $iLOIP = ($SH.mpHostInfo.mpIpAddresses |  ? { $_ -NotMatch "fe80" }).address

        # Capture of the SSO Session Key
        try {
            $ilosessionkey = ($SH | Get-OVIloSso -IloRestSession)."X-Auth-Token"
            $headers["X-Auth-Token"] = $ilosessionkey 
        }
        catch {
            Write-Warning "`niLO [$iLOIP] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
            continue
        }
    
          
        # Get DIMM Information

        try {
            $response = Invoke-RestMethod -Uri "https://$iLOIP$uri" -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop

            $DIMMs = $response.Members |  where-object { $_.SerialNumber -notmatch "NOT AVAILABLE" } 
            
            foreach ($DIMM in $DIMMs) {

                $Object.DIMM_SerialNumber = $DIMM.SerialNumber
                $Object.DIMM_PartNumber = $DIMM.PartNumber.TrimEnd()
                
                $DIMM_DB += $Object

            }
        }
        catch {
            $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
            $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
            Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloip) Read operation failure ! Message returned: [$($msg)]"
            continue
        }
             

    }

       
    $ConnectedSessions | Disconnect-OVMgmt
}

$DIMM_DB.GetEnumerator() | Select-Object -Property  @{N = 'DIMM Serial Number'; E = { $_.DIMM_SerialNumber } }, @{N = 'DIMM Part Number'; E = { $_.DIMM_PartNumber } }, @{N = 'Compute Name'; E = { $_.Server_Name } }, @{N = 'Compute Serial Number'; E = { $_.Server_SerialNumber } } |   Export-Csv -NoTypeInformation "$path\$Filename"

"CSV file successfully generated in: {0}\{1}" -f $path, $Filename