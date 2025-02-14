<#
Examples of iLO interaction using different methods and HPE PowerShell libraries:
1- HPEiLOCmdlets
2- HPEiLOCmdlets with X-Auth-Token from HPECOMCmdlets
3- HPEiLOCmdlets with X-Auth-Token from HPEOneView
4- Native RedFish API calls with X-Auth-Token from HPEiLOCmdlets
5- Native RedFish API calls with X-Auth-Token from HPECOMCmdlets
6- Native RedFish API calls
7- HPEBIOSCmdlets
8- HPERedfishCmdlets


 Author: lionel.jullien@hpe.com
 Date:   Oct 2023
    
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



#---------------------------------------------------------------------------------------------------------------
#Region "1- Using HPEiLOCmdlets"
################################################# 
# Requirements: HPEiLOCmdlets
# install-module HPEiLOCmdlets -Scope CurrentUser
################################################# 

# iLO information
$iLO_IP = "192.168.3.52"
$iLO_username = "Administrator"

# Ask for iLO password
$secpasswd = read-host  "Please enter the iLO password" -AsSecureString
$ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $secpasswd)

# List of cmdlets
Get-command -Module HPEiLOCmdlets

# Connection
$connection = Connect-HPEiLO -Address $iLO_IP -Credential $ilocreds  -DisableCertificateAuthentication 

# Examples

# Get iLO User Information
(Get-HPEiLOUser -Connection $connection).userinformation
# Get iLO device list
(Get-HPEiLODeviceInventory -Connection $connection).devices

#Endregion


#---------------------------------------------------------------------------------------------------------------
#Region "2- Using HPEiLOCmdlets with X-Auth-Token from HPECOMCmdlets"
################################################# 
# Requirements: HPEiLOCmdlets and HPECOMCmdlets modules
# install-module HPEiLOCmdlets -Scope CurrentUser
# install-module HPECOMCmdlets -MinimumVersion 1.0.11 -Scope CurrentUser
################################################# 

# HPE account credentials
$MyHPEAccount = "email@domain.com"
$MyHPEAccountPassword = "01000000d08c9ddf0115d1118c7a0"

# Workspace name to create
$WorkspaceName = "HPE_Workspace_12345678"
$Region = "us-west"

# List of cmdlets
Get-command -Module HPEiLOCmdlets
Get-command -Module HPECOMCmdlets

# Connection to HPE GreenLake and HPE Compute Ops Management
$secpasswd = ConvertTo-SecureString -String $MyHPEAccountPassword -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($MyHPEAccount, $secpasswd)
Connect-HPEGL -Credential $credentials -Workspace $WorkspaceName

# Get the iLO IP address from Compute Ops Management of a server
$iLO_IP = Get-HPECOMServer -Region $Region -Name "TWA4614528" | Select-Object -ExpandProperty iLOIPAddress

# Capture of the SSO Session Key
$iloSession = Get-HPECOMServeriLOSSO -Region $Region -SerialNumber "XXXXXXXXXXXXX" -GenerateXAuthToken -SkipCertificateValidation
$ilosessionkey = $iloSession."X-Auth-Token"

# Connection to iLO with HPEiLOCmdlets XAuthToken
$connection = Connect-HPEiLO -Address $iLO_IP -XAuthToken $ilosessionkey -DisableCertificateAuthentication

# Examples
(Get-HPEiLOEventLog -Connection $connection).Eventlog
(Get-HPEiLOUser -Connection  $connection).userinformation.count
Get-HPEiLOServerInfo -Connection $connection

#Endregion


#---------------------------------------------------------------------------------------------------------------
#Region "3- Using HPEiLOCmdlets with X-Auth-Token from HPEOneView"
#################################################
# Requirements: HPEiLOCmdlets and HPEOneView modules + iLO5 or greater
# install-module HPEiLOCmdlets -Scope CurrentUser
# install-module HPEOneView.9xx -Scope CurrentUser
#################################################

# OneView Credentials and IP
$OneView_username = "Administrator"
$OneView_IP = "composer.lab"

# List of cmdlets
Get-command -Module HPEiLOCmdlets
Get-command -Module HPEOneView.9xx

# Connection to OneView
$credentials = New-Object System.Management.Automation.PSCredential ($OneView_username, $secpasswd)
Connect-OVMgmt -Hostname $OneView_IP -Credential $credentials

# Get iLO IP address from OneView of a server
$server = Get-OVServer -ServerName "RHEL90-1.lj.lab" 
$iLO_IP = $server.mpHostInfo.mpIpAddresses | Where-Object type -ne LinkLocal | Select-Object -ExpandProperty address

# Capture of the SSO Session Key
$iloSession = $server | Get-OVIloSso -IloRestSession -SkipCertificateCheck
$ilosessionkey = $iloSession."X-Auth-Token"

# Connection to iLO with HPEiLOCmdlets XAuthToken
$connection = Connect-HPEiLO -Address $iLO_IP -XAuthToken $ilosessionkey -DisableCertificateAuthentication

# Examples
(Get-HPEiLOUser -Connection  $connection).userinformation.count
Get-HPEiLOServerInfo -Connection $connection

#Endregion


#---------------------------------------------------------------------------------------------------------------
#Region "4- Native RedFish API calls with X-Auth-Token from HPEiLOCmdlets"
#################################################
# Requirements: HPEiLOCmdlets 
# install-module HPEiLOCmdlets -Scope CurrentUser
#################################################

# List of cmdlets
# Get-command -Module HPEiLOCmdlets

# iLO information
$iLO_IP = "192.168.3.52"
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
$headers["X-Auth-Token"] = $plainTextXAuthToken


######################## GET Example ############################

# iLO5 Redfish URI
$Location = "/redfish/v1/Managers/1/SecurityService"

# Method
$Method = "Get"

# Request
try {
    $response = Invoke-WebRequest -Uri ($RootUri + $Location) -Headers $headers -Method $Method -ErrorAction Stop -SkipCertificateCheck # -SkipCertificateCheck is only supported with PowerShell 7
    # $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
    $content = $response.Content | ConvertFrom-Json
    
}
catch {
    Write-Host "iLO $($iloHost) Patch operation failure ! Message returned: [$($_)]"
}


# Response
$content
$content.SecurityState
$content.TLSVersion


######################## PATCH Example ###########################

# iLO5 Redfish URI
$Location = "/redfish/v1/Managers/1/SecurityService"

# Body
$Body = @{} 
$Body["SecurityState"] = "Production"
$body = $body | ConvertTo-Json   

# Method
$Method = "Patch"

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

# Response
$response



#Endregion


#---------------------------------------------------------------------------------------------------------------
#Region "5- Native RedFish API calls with X-Auth-Token from HPECOMCmdlets"
#################################################
# Requirements: HPECOMCmdlets 
# install-module HPECOMCmdlets -Scope CurrentUser
#################################################

# List of cmdlets
# Get-command -Module HPECOMCmdlets

# HPE account credentials
$MyHPEAccount = "email@domain.com"
$MyHPEAccountPassword = "01000000d08c9ddf0115d1118c7a0"

# Workspace name to create
$WorkspaceName = "HPE_Workspace_12345678"
$Region = "us-west"

# List of cmdlets
Get-command -Module HPEiLOCmdlets
Get-command -Module HPECOMCmdlets

# Connection to HPE GreenLake and HPE Compute Ops Management
$secpasswd = ConvertTo-SecureString -String $MyHPEAccountPassword -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($MyHPEAccount, $secpasswd)
Connect-HPEGL -Credential $credentials -Workspace $WorkspaceName

# Get the iLO IP address from Compute Ops Management of a server
$iLO_IP = Get-HPECOMServer -Region $Region -Name "TWA4614528" | Select-Object -ExpandProperty iLOIPAddress

# Capture of the SSO Session Key
$iloSession = Get-HPECOMServeriLOSSO -Region $Region -SerialNumber "XXXXXXXXXXXXX" -GenerateXAuthToken -SkipCertificateValidation

# Add the token to the headers
$headers["X-Auth-Token"] = $iloSession."X-Auth-Token"


######################## GET Example ############################

# iLO5 Redfish URI
$Location = "/redfish/v1/Managers/1/SecurityService"

# Method
$Method = "Get"

# Request
try {
    $response = Invoke-WebRequest -Uri ($RootUri + $Location) -Headers $headers -Method $Method -ErrorAction Stop -SkipCertificateCheck # -SkipCertificateCheck is only supported with PowerShell 7
    # $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
    $content = $response.Content | ConvertFrom-Json
    
}
catch {
    Write-Host "iLO $($iloHost) Patch operation failure ! Message returned: [$($_)]"
}


# Response
$content
$content.SecurityState
$content.TLSVersion


######################## PATCH Example ###########################

# iLO5 Redfish URI
$Location = "/redfish/v1/Managers/1/SecurityService"

# Body
$Body = @{} 
$Body["SecurityState"] = "Production"
$body = $body | ConvertTo-Json   

# Method
$Method = "Patch"

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

# Response
$response



#Endregion


#---------------------------------------------------------------------------------------------------------------
#Region "6- Using Native Redfish API calls"
#################################################
# Requirements: NONE
#################################################

# if using untrusted iLO certificate, you must use with PowerShell 5.x:
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

# With PowerShell 7.x: just add -SkipCertificateCheck parameter to all your web requests

######################## iLO Session creation ############################

$RootUri = "https://" + $iLO_IP

$Url = "$RootUri/redfish/v1/SessionService/Sessions/"

$headers = @{} 
$headers["OData-Version"] = "4.0"
$headers["Content-Type"] = "application/json"

$body = @{} 
$body["UserName"] = $iLO_username
$body["Password"] = $iLO_password
$body = $Body | ConvertTo-Json

try {
    $session = Invoke-WebRequest $Url -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck 
}
catch {
    Write-Host "Error logging into iLO $iLO_IP : $_"
}

$XAuthToken = $Session.headers | ForEach-Object X-Auth-Token

$headers["X-Auth-Token"] = $XAuthToken


######################## GET Example ############################

# iLO5 Redfish URI
$Location = "/redfish/v1/Managers/1/SecurityService"

# Method
$Method = "Get"

# Request
try {
    $response = Invoke-WebRequest -Uri ($RootUri + $Location) -Headers $headers -Method $Method -ErrorAction Stop -SkipCertificateCheck # -SkipCertificateCheck is only supported with PowerShell 7
    # $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
    $content = $response.Content | ConvertFrom-Json
    
}
catch {
    Write-Host "iLO $($iloHost) Patch operation failure ! Message returned: [$($_)]"
}


# Response
$content
$content.SecurityState
$content.TLSVersion


######################## PATCH Example ###########################

# iLO5 Redfish URI
$Location = "/redfish/v1/Managers/1/SecurityService"

# Body
$Body = @{} 
$Body["SecurityState"] = "Production"
$body = $body | ConvertTo-Json   

# Method
$Method = "Patch"

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

# Response
$response

#Endregion


#---------------------------------------------------------------------------------------------------------------
#Region "7- Using HPEBIOSCmdlets"  
#################################################
# Requirements: HPEBIOSCmdlets 
# install-module HPEBIOSCmdlets -Scope CurrentUser
#################################################


# iLO information
$iLO_IP = "192.168.3.52"
$iLO_username = "Administrator"

# Ask for iLO password
$secpasswd = read-host  "Please enter the iLO password" -AsSecureString
$ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $secpasswd)

# List of cmdlets
Get-command -Module HPEBIOSCmdlets
Get-command -Module HPEBIOSCmdlets | ? name -match "security"

# Connection
$connection = Connect-HPEBIOS -Address $iLO_IP -Credential $ilocreds -DisableCertificateAuthentication 

# Examples
Get-HPEBIOSServerSecurity -Connection $connection
Get-HPEBIOSAdvancedSecurityOption -Connection $connection | fl
Set-HPEBIOSServerSecurity -Connection $connection -F11BootMenuPrompt Enabled -IntelligentProvisioningF10Prompt Enabled -IntelTxtSupport Enabled -ProcessorAESNISupport Enabled


#Endregion


#---------------------------------------------------------------------------------------------------------------
#Region "8- Using HPERedfishCmdlets" 
#################################################
# Requirements: HPERedfishCmdlets 
# install-module HPERedfishCmdlets -Scope CurrentUser
#################################################


# List of cmdlets
Get-command -Module HPERedfishCmdlets

# iLO information
$iLO_IP = "192.168.3.52"
$iLO_username = "Administrator"

# Ask for iLO password
$secpasswd = read-host  "Please enter the iLO password" -AsSecureString
$ilocreds = New-Object System.Management.Automation.PSCredential ($iLO_username, $secpasswd)

# Connection
$session = Connect-HpeRedfish -Address $iLO_IP -Credential $ilocreds -DisableCertificateAuthentication

# Examples
Get-HPERedfishDataRaw -Session $session -Odataid "/redfish/v1/Chassis/1/Thermal" -DisableCertificateAuthentication

$setting = @{'IndicatorLED' = 'Lit' }
$ret = Set-HPERedfishData -Odataid /redfish/v1/systems/1/ -Setting $setting -Session $session
$ret.error

#Endregion



