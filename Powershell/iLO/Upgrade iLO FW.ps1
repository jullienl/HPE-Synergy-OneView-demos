   
# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# Sept 2016
#
# Upgrade all iLO FW managed by the OneView Composer using iLO local account so it is required to first use the 'Add User to iLO' script
#
# OneView administrator account is required and HPE iLO PowerShell Cmdlets must be installed
# from https://www.hpe.com/us/en/product-catalog/detail/pip.5440657.html  
# 
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


#Global variables
$Location = "C:\\Kits\\_HP\\iLO\\iLO4\\ilo4_254.bin" #Location of the iLO Firmware bin file
$ilocreds = Get-Credential -UserName Administrator -Message "Please enter the iLO password"   


# Composer information
$username = "Administrator"
$password = "password"
$IP = "composer.lj.lab"


If (-not (get-Module HPOneview.500) ) {

    Import-Module HPOneview.500
}


# Connection to the Synergy Composer
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-HPOVMgmt -Hostname $IP -Credential $credentials | Out-Null


import-HPOVSSLCertificate


$iLO4serverIPs = Get-HPOVServer | % { $_.mpHostInfo.mpIpaddresses[1].address } # | select -first 1 
     
$iLO4serverIPs | Update-HPiLOFirmware -Credential $ilocreds -Location $Location -DisableCertificateAuthentication
   
# To manually upadate an iLO, use its IP address like:
# "192.168.1.203" | Update-HPiLOFirmware -Credential $ilocreds -Location $Location -DisableCertificateAuthentication
      
   
Write-Host "The following" $iLO4serverIPs.Count "iLOs have been updated:"
$iLO4serverIPs  
    
Disconnect-HPOVMgmt 





