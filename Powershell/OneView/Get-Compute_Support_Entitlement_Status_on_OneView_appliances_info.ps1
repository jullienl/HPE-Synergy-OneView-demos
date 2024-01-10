<# 

This script generates an Excel file by querying HPE OneView for the Compute support entitlement status and end date. 

Example of the content of the Excel file:

Appliance	    Compute Module Names    Compute Serial Numbers	OV Remote Support Entitlement Status	OV Remote Support Entitlement End Date
192.168.1.110	Frame2, bay 7	        CN76010B74	            INVALID	                                01/01/0001
192.168.1.110	Frame3, bay 1	        CZ212406GL	            VALID	                                7/18/2024
192.168.1.110	Frame3, bay 10	        CZ221705V7	            VALID	                                5/27/2025
192.168.1.10	Frame3, bay 3	        CZ212406GJ	            VALID	                                7/18/2024
192.168.1.10	Frame3, bay 4	        CZ212406GK	            VALID	                                7/18/2024
192.168.1.10	Frame3, bay 5		    CZ212406GJ              INVALID	                                01/01/0001


Requirements:
   - HPE OneView administrator account 
   - HPE OneView Powershell Library
   - Microsoft Excel installed and licensed (required to generate the Excel file with multiple spreadsheets)


  Author: lionel.jullien@hpe.com
  Date:   Jan 2024
    
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


echo "Appliance; Compute Module Names; Compute Serial Numbers; OV Remote Support Entitlement Status; OV Remote Support Entitlement End Date" > $path\Compute-Support-Entitlement-Status.txt

foreach ($appliance in $appliances) {
   
    try {
        "Connecting to appliance {0}..." -f $appliance
        Connect-OVMgmt -Hostname $appliance -Credential $credentials -ErrorAction stop  | Out-Null    
    }
    catch {
        Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
        return
    }
    
    # Retrieve Server hardware information
 
    $SHs = Get-OVServer #| ? model -match "Synergy" | ? model -match "Gen10"
         
    foreach ($SH in $SHs) {
          
        $SH_name = $SH.name
        $SH_serialNumber = $SH.serialNumber
        $OVRemoteSupportEntitlementStatus = Get-OVServer -Name $SH_name | Get-OVRemoteSupportEntitlementStatus  

        "$($OVRemoteSupportEntitlementStatus.ApplianceConnection); $SH_name; $SH_serialNumber; $($OVRemoteSupportEntitlementStatus.EntitlementStatus); $(($($OVRemoteSupportEntitlementStatus.OfferEndDate)).ToString('MM/dd/yyyy'))" | Out-File $path\Compute-Support-Entitlement-Status.txt  -Append

    }

    Disconnect-OVMgmt | Out-Null

}

import-csv $path\Compute-Support-Entitlement-Status.txt -Delimiter ";" | Export-Csv -NoTypeInformation "$path\Compute-Support-Entitlement-Status.csv"

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

