<#

Script to set the iLO thermal configuration on one iLO

Requirements: HPEiLOCmdlets module

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

# import-module HPEiLOCmdlets

# Set the thermal configuration to 'Maximum cooling' on the iLO:
$ThermalConfiguration = "MaximumCooling" 
# possible values for ThermalConfiguration:
# OptimalCooling
# IncreasedCooling
# MaximumCooling
# EnhancedCooling 

# iLO information
$iLO_IP = "ilo-dl365g11-1.lj.lab"
$iLO_username = "Administrator"

# Ask for iLO password
$secpasswd = read-host  "Please enter the iLO password" -AsSecureString
$ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $secpasswd)


# Connection
$connection = Connect-HPEiLO -Address $iLO_IP -Credential $ilocreds -DisableCertificateAuthentication 

# Get the encoded session token
$encodedToken = $connection.ConnectionInfo.Redfish.XAuthToken

# Extract Modifier1 and Modifier2 to get the encryption key and initialization vector (IV)
$modifier1 = $connection.ExtendedInfo.Modifier1
$modifier2 = $connection.ExtendedInfo.Modifier2

# Convert the modifiers from Base64
$key = [System.Convert]::FromBase64String($modifier1)
$iv = [System.Convert]::FromBase64String($modifier2)

# Convert the token from Base64
$cipherText = [System.Convert]::FromBase64String($encodedToken)

# Create AES decryptor
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV = $iv
$decryptor = $aes.CreateDecryptor($aes.Key, $aes.IV)

# Decrypt the token
$ms = New-Object System.IO.MemoryStream
$cs = New-Object System.Security.Cryptography.CryptoStream($ms, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
$cs.Write($cipherText, 0, $cipherText.Length)
$cs.Close()
$plainTextXAuthToken = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())

# Add the token to the headers
$headers = @{} 
$headers["OData-Version"] = "4.0"
$headers["X-Auth-Token"] = $plainTextXAuthToken
$headers["Content-Type"] = "application/json"


######################## GET Example ############################

# iLO5 Redfish URI
$Location = "/redfish/v1/Chassis/1/Thermal"
$RootUri = "https://" + $iLO_IP

# Method
$Method = "PATCH"

# Body
$Body = @{} 
$Body["Oem"] = @{ "Hpe" = @{ "ThermalConfiguration" = $ThermalConfiguration } }
$Body = $Body | ConvertTo-Json   



# Request
try {
  $response = Invoke-WebRequest -Uri ($RootUri + $Location) -Headers $headers -body $Body -Method $Method -ErrorAction Stop -SkipCertificateCheck # -SkipCertificateCheck is only supported with PowerShell 7
  $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId

  if ($response.StatusCode -eq 200) {

    Write-Host -BackgroundColor:Black -ForegroundColor:Green "iLO $($iLO_IP) success $Method operation ! Message returned: [$($msg)]"
  }
  else {

    Write-Host "iLO $($iloHost) Patch operation failure ! Message returned: [$($msg)]"
  }

}
catch {
  
  Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iLO_IP) $Method operation failure ! Message returned: $($_)"
    
}