<#

Script to enable and set iLO SNMP v3 settings

Requirements: HPEiLOCmdlets (currently not supporting Synergy Gen11)
# install-module HPEiLOCmdlets -Scope CurrentUser

  Author: lionel.jullien@hpe.com
    
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


$iLO_IP = "192.168.0.40"

# iLO Credentials 
$iLO_username = "demopaq"
$iLO_password = "xxxxxxxxxxxx"


$secpasswd = ConvertTo-SecureString -String $iLO_password -AsPlainText -Force
$ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $secpasswd)

$connection = Connect-HPEiLO -Address $iLO_IP -Credential $ilocreds  -DisableCertificateAuthentication 


# SNMPv3 configuration can only be performed when the SNMP is enabled. 
$SNMPProtocolEnabled = (Get-HPEiLOAccessSetting -Connection $connection).SNMPProtocolEnabled

if ($SNMPProtocolEnabled -eq "No") {
  Set-HPEiLOAccessSetting -Connection $connection -SNMPProtocolEnabled Yes
}

# SNMP Alert setting concerns both SNMPv1 & SNMPv3 alerts so it must be enabled
$AlertEnabled = (Get-HPEiLOSNMPAlertSetting -Connection $connection).AlertEnabled

if ($AlertEnabled -eq "No") {
  Set-HPEiLOSNMPAlertSetting -Connection $connection -AlertEnabled Yes
}

# Add a SNMPv3 user
Add-HPEiLOSNMPv3User -connection $connection -SecurityName admin123 -AuthenticationProtocol MD5 -AuthenticationPassphrase abcde1234 -PrivacyProtocol AES -PrivacyPassphrase 123456adb -UserEngineID 0x01020304abcdef

# Set SNMPv3 settings
Set-HPEiLOSNMPv3Setting -connection $connection -SNMPv3EngineID 0x01020304abcdef -SNMPv3InformRetryAttempt 5 -SNMPv3InformRetryIntervalSeconds 100 


