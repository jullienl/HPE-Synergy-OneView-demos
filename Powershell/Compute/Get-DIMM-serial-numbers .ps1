<# 

This script generates a CSV file to retrieve all memory DIMM serial numbers for all Gen10/Gen10 Plus servers managed by one or more HPE OneView appliances. 

Generated CSV example:

"Compute_Name","Compute_SerialNumber","DIMM_SerialNumber","DIMM_PartNumber","DIMM_DeviceLocator","DIMM_CapacityMiB","DIMM_ErrorCorrection","DIMM_VendorID","DIMM_Manufacturer","DIMM_MemoryDeviceType","DIMM_BaseModuleType","DIMM_MemoryType","DIMM_OperatingSpeedMhz","DIMM_RankCount","DIMM_State","DIMM_Health","Compute_romVersion","Compute_iLOVersion"
"Frame3, bay 1","CZ212406GL","94E6D08D","HMA81GR7CJR8N-WM","PROC 1 DIMM 3","8192","MultiBitECC","44288","HPE","DDR4","RDIMM","DRAM","2666","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 1","CZ212406GL","94E6D098","HMA81GR7CJR8N-WM","PROC 1 DIMM 5","8192","MultiBitECC","44288","HPE","DDR4","RDIMM","DRAM","2666","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 1","CZ212406GL","94E6D051","HMA81GR7CJR8N-WM","PROC 1 DIMM 8","8192","MultiBitECC","44288","HPE","DDR4","RDIMM","DRAM","2666","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 1","CZ212406GL","94E6D06E","HMA81GR7CJR8N-WM","PROC 1 DIMM 10","8192","MultiBitECC","44288","HPE","DDR4","RDIMM","DRAM","2666","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 1","CZ212406GL","94E6D05D","HMA81GR7CJR8N-WM","PROC 2 DIMM 3","8192","MultiBitECC","44288","HPE","DDR4","RDIMM","DRAM","2666","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 1","CZ212406GL","94E6D05E","HMA81GR7CJR8N-WM","PROC 2 DIMM 5","8192","MultiBitECC","44288","HPE","DDR4","RDIMM","DRAM","2666","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 1","CZ212406GL","94E6D05F","HMA81GR7CJR8N-WM","PROC 2 DIMM 8","8192","MultiBitECC","44288","HPE","DDR4","RDIMM","DRAM","2666","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 1","CZ212406GL","94E6D055","HMA81GR7CJR8N-WM","PROC 2 DIMM 10","8192","MultiBitECC","44288","HPE","DDR4","RDIMM","DRAM","2666","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 10","CZ221705V7","474D5B52","M393A2K40DB3-CWE","PROC 1 DIMM 8","16384","MultiBitECC","52736","HPE","DDR4","RDIMM","DRAM","2400","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 11","CZ221705V1","474D182B","M393A2K40DB3-CWE","PROC 1 DIMM 8","16384","MultiBitECC","52736","HPE","DDR4","RDIMM","DRAM","2400","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"
"Frame3, bay 12","CZ221705V6","474D25E9","M393A2K40DB3-CWE","PROC 1 DIMM 8","16384","MultiBitECC","52736","HPE","DDR4","RDIMM","DRAM","2400","1","Enabled","OK","I42 v2.68 (07/14/2022)","2.72 Sep 04 2022"


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
$appliances = @("192.168.1.10", "192.168.1.110")


# Location of the folder to generate the CSV file
$path = '.\Powershell\Compute'
$Filename = 'DIMMs_Report.csv'

#################################################################################


# OneView Credentials
$OV_username = "Administrator" 
$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the OneView / Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)


If ( ($PSVersionTable.PSVersion.ToString()).Split('.')[0] -eq 5) {

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

}


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
        $SH_iLOVersion = $SH.mpFirmwareVersion
        $SH_romVersion = $SH.romVersion


        $iLOIP = ($SH.mpHostInfo.mpIpAddresses |  ? { $_ -NotMatch "fe80" }).address

        # Capture of the SSO Session Key
        try {
            $ilosessionkey = ($SH | Get-OVIloSso -IloRestSession -SkipCertificateCheck )."X-Auth-Token"
            $headers["X-Auth-Token"] = $ilosessionkey 
        }
        catch {
            Write-Warning "`niLO [$iLOIP] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
            continue
        }
    
          
        # Get DIMM Information

        try {

            If ( ($PSVersionTable.PSVersion.ToString()).Split('.')[0] -eq 5) {
                $response = Invoke-RestMethod -Uri "https://$iLOIP$uri" -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop

            }
            else {
                $response = Invoke-RestMethod -Uri "https://$iLOIP$uri" -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop -SkipCertificateCheck
            }
            
            $DIMMs = $response.Members | ? SerialNumber | ? SerialNumber -notmatch "NOT AVAILABLE" 
            
            foreach ($DIMM in $DIMMs) {

                $Object = [pscustomobject]@{

                    DIMM_SerialNumber      = $Null
                    DIMM_PartNumber        = $Null
                    DIMM_DeviceLocator     = $Null
                    DIMM_VendorID          = $Null
                    DIMM_CapacityMiB       = $Null
                    DIMM_ErrorCorrection   = $Null
                    DIMM_Manufacturer      = $Null
                    DIMM_MemoryDeviceType  = $Null
                    DIMM_BaseModuleType    = $Null
                    DIMM_MemoryType        = $Null
                    DIMM_OperatingSpeedMhz = $Null
                    DIMM_RankCount         = $Null
                    DIMM_State             = $Null
                    DIMM_Health            = $Null
        
                    Server_Name            = $SH_name
                    Server_SerialNumber    = $SH_serialNumber
                    Server_romVersion      = $SH_romVersion
                    Server_iLOVersion      = $SH_iLOVersion
                          
                }

                $Object.DIMM_SerialNumber = $DIMM.SerialNumber
                $Object.DIMM_PartNumber = $DIMM.PartNumber.TrimEnd()
                $Object.DIMM_DeviceLocator = $DIMM.DeviceLocator
                $Object.DIMM_VendorID = $DIMM.VendorID
                $Object.DIMM_CapacityMiB = $DIMM.CapacityMiB
                $Object.DIMM_ErrorCorrection = $DIMM.ErrorCorrection
                $Object.DIMM_Manufacturer = $DIMM.Manufacturer
                $Object.DIMM_MemoryDeviceType = $DIMM.MemoryDeviceType
                $Object.DIMM_BaseModuleType = $DIMM.BaseModuleType
                $Object.DIMM_MemoryType = $DIMM.MemoryType
                $Object.DIMM_OperatingSpeedMhz = $DIMM.OperatingSpeedMhz
                $Object.DIMM_RankCount = $DIMM.RankCount
                $Object.DIMM_State = $DIMM.Status.State
                $Object.DIMM_Health = $DIMM.Status.Health
                
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


$DIMM_DB.GetEnumerator() | Select-Object -Property  `
@{N = 'Compute_Name'; E = { $_.Server_Name } }, `
@{N = 'Compute_SerialNumber'; E = { $_.Server_SerialNumber } }, `
@{N = 'DIMM_SerialNumber'; E = { $_.DIMM_SerialNumber } }, `
@{N = 'DIMM_PartNumber'; E = { $_.DIMM_PartNumber } }, `
@{N = 'DIMM_DeviceLocator'; E = { $_.DIMM_DeviceLocator } }, `
@{N = 'DIMM_CapacityMiB'; E = { $_.DIMM_CapacityMiB } }, `
@{N = 'DIMM_ErrorCorrection'; E = { $_.DIMM_ErrorCorrection } }, `
@{N = 'DIMM_VendorID'; E = { $_.DIMM_VendorID } }, `
@{N = 'DIMM_Manufacturer'; E = { $_.DIMM_Manufacturer } }, `
@{N = 'DIMM_MemoryDeviceType'; E = { $_.DIMM_MemoryDeviceType } }, `
@{N = 'DIMM_BaseModuleType'; E = { $_.DIMM_BaseModuleType } }, `
@{N = 'DIMM_MemoryType'; E = { $_.DIMM_MemoryType } }, `
@{N = 'DIMM_OperatingSpeedMhz'; E = { $_.DIMM_OperatingSpeedMhz } }, `
@{N = 'DIMM_RankCount'; E = { $_.DIMM_RankCount } }, `
@{N = 'DIMM_State'; E = { $_.DIMM_State } }, `
@{N = 'DIMM_Health'; E = { $_.DIMM_Health } }, `
@{N = 'Compute_romVersion'; E = { $_.Server_romVersion } }, `
@{N = 'Compute_iLOVersion'; E = { $_.Server_iLOVersion } } | Export-Csv -NoTypeInformation "$path\$Filename"

"CSV file successfully generated in: {0}\{1}" -f $path, $Filename


# Get-content -path $path\$filename 