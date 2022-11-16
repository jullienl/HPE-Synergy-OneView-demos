<# 

This script generates an Excel file with multiple spreadsheets of Gen10 server, frame and Virtual Connect module serial numbers managed by the list of HPE OneView appliances. 

Requirements:
   - HPE OneView administrator account 
   - HPE OneView Powershell Library
   - Microsoft Excel installed and licensed (required to generate the Excel file with multiple spreadsheets)


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


$appliances = @("192.168.1.110", "192.168.1.10")

# Location of the folder to temporarily generate CSV files
$path = '.\Powershell\Compute'

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

$SH_DB = @{}
$Frame_DB = @{}
$VC_DB = @{}

foreach ($appliance in $appliances) {
   
    try {
        Connect-OVMgmt -Hostname $appliance -Credential $credentials -ErrorAction stop | Out-Null    
    }
    catch {
        Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
        return
    }
    
    # Retrieve Server hardware information
 

    $SHs = Get-OVServer | ? model -match "Gen10"
     
    foreach ($SH in $SHs) {
          
        $SH_name = $SH.name
        $SH_serialNumber = $SH.serialNumber

        $SH_DB["$($SH_name)"] += $SH_serialNumber
    }

    # Retrieve Frame information


    $Frames = Get-OVEnclosure 
        
    foreach ($frame in $Frames) {
             
        $frame_name = $frame.name
        $frame_serialNumber = $frame.serialNumber
   
        $Frame_DB["$($frame_name)"] += $frame_serialNumber
    }
       
    # Retrieve Virtual Connect information


    $VCs = Get-OVInterconnect | ? productname -match "Virtual Connect"
    
    foreach ($VC in $VCs) {
         
        $VC_name = $VC.name
        $VC_serialNumber = $VC.serialNumber

        $VC_DB["$($VC_name)"] += $VC_serialNumber
    }
   
    $ConnectedSessions | Disconnect-OVMgmt
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
