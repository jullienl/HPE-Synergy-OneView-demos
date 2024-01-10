<# 

This script generates an Excel file by querying HPE OneView for the serial numbers of Synergy Gen10/Gen10 Plus servers and 
Synergy Virtual Connect modules, as well as the serial numbers of the Synergy frames where they reside.

A different spreadsheet is generated, one for the Computes and one for the VC modules.

Example of the content of the Excel file:

Compute Module Names	Compute Serial Numbers	Frame Serial Numbers
Frame3, bay 1	        CZ212406GL	            CZ212406H0
Frame3, bay 10	        CZ221705V7	            CZ212406H0
Frame3, bay 11	        CZ221705V1	            CZ212406H0
Frame4, bay 10	        MXQ828048J	            CN7515049C
Frame4, bay 11	        MXQ828048H	            CN7515049C
Frame4, bay 12	        MXQ828049J	            CN7515049C

VC 100G Module Names	    VC 100G Serial Numbers	    Frame Serial Numbers
Frame3, interconnect 3	    7C910200VL	                CZ212406H0
Frame3, interconnect 6	    7C910200V2	                CZ212406H0


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
$path = '.\Powershell\Compute\tmp'

#################################################################################


# OneView Credentials
$OV_username = "Administrator" 
$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the OneView / Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)


#################################################################################

echo "Compute Module Names; Compute Serial Numbers; Frame Serial Numbers" > $path\Compute-modules.txt 
echo "VC 100G Module Names; VC 100G Serial Numbers; Frame Serial Numbers" > $path\VC100-modules.txt 

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
         
    foreach ($SH in $SHs) {
          
        $SH_name = $SH.name
        $SH_serialNumber = $SH.serialNumber
        $frame_serialNumber = (Send-OVRequest ((Search-OVAssociations -AssociationName ENCLOSURE_TO_BLADE -Child $SH).parenturi)).serialNumber

        "$SH_name; $SH_serialNumber; $frame_serialNumber" | Out-File $path\Compute-modules.txt  -Append

    }

    # Retrieve Virtual Connect information

    $VCs = Get-OVInterconnect | ? productname -match "Virtual Connect SE 100Gb F32 Module for Synergy" 
    
    foreach ($VC in $VCs) {
         
        $VC_name = $VC.name
        $VC_serialNumber = $VC.serialNumber

        $frame_serialNumber = (Send-OVRequest ((Search-OVAssociations -AssociationName ENCLOSURE_TO_INTERCONNECT -Child $VC).parenturi)).serialNumber

        "$VC_name; $VC_serialNumber; $frame_serialNumber" | Out-File $path\VC100-modules.txt  -Append
    }
   
    $ConnectedSessions | Disconnect-OVMgmt
}

import-csv $path\Compute-modules.txt -Delimiter ";" | Export-Csv -NoTypeInformation "$path\Compute-modules.csv"
import-csv $path\VC100-modules.txt -Delimiter ";" | Export-Csv -NoTypeInformation "$path\VC100-modules.csv"

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

remove-item "$path\*.txt" -Confirm:$false
remove-item "$path\*.csv" -Confirm:$false

