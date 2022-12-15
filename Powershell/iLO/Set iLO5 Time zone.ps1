<# 

PowerShell script to set a time zone on all iLO managed by HPE OneView. 

Gen10/Gen10+ servers are supported. Gen9 servers are skipped by the script.

 Requirements:
   - HPE OneView Powershell Library
   - HPE OneView administrator account 


Output example:

2 x iLO5 are going to be configured with the new time zone:
Frame3, bay 2
Frame3, bay 3

iLO 192.168.3.188 Time zone is now configured, iLO needs to be reset... API response: [iLO.2.15.ResetRequired]
iLO 192.168.3.188 - Reseting iLO to enable the new time zone...

iLO 192.168.3.191 Time zone is now configured, iLO needs to be reset... API response: [iLO.2.15.ResetRequired]
iLO 192.168.3.191 - Reseting iLO to enable the new time zone...


 Author: lionel.jullien@hpe.com
 Date:   May 2022
    
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


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer.lj.lab"


$timezone = "Dublin, London"
<#
Time zone list:
    "Name": "International Date Line West", "UtcOffset": "-12:00",
    "Name": "Midway Island, Samoa", "UtcOffset": "-11:00",
    "Name": ""Hawaii","UtcOffset": "-10:00",
    "Name": ""Marquesas","UtcOffset": "-09:30",
    "Name": "Alaska", "UtcOffset": "-09:00",
    "Name": "Pacific Time(US & Canada), Tijuana, Portland", "UtcOffset": "-08:00",
    "Name": "Arizona, Chihuahua, La Paz, Mazatlan, Mountain Time (US & Canad", "UtcOffset": "-07:00",
    "Name": "Central America, Central Time(US & Canada)", "UtcOffset": "-06:00",
    "Name": "Bogota, Lima, Quito, Eastern Time(US & Canada)", "UtcOffset": "-05:00",
    "Name": "Caracas, Georgetown", "UtcOffset": "-04:00",
    "Name": "Atlantic Time(Canada), Santiago",    "UtcOffset": "-04:00",
    "Name": "Newfoundland", "UtcOffset": "-03:30",
    "Name": "Brasilia, Buenos Aires, Greenland", "UtcOffset": "-03:00",
    "Name": "Mid-Atlantic", "UtcOffset": "-02:00",
    "Name": "Azores, Cape Verde Is.", "UtcOffset": "-01:00",
    "Name": "Greenwich Mean Time, Casablanca, Monrovia", "UtcOffset": "+00:00",
    "Name": "Dublin, London", "UtcOffset": "+00:00",
    "Name": "Amsterdam, Berlin, Bern, Rome, Paris, West Central Africa", "UtcOffset": "+01:00",
    "Name": "Athens, Bucharest, Cairo, Jerusalem", "UtcOffset": "+02:00",
    "Name": "Baghdad, Kuwait, Riyadh, Moscow, Istanbul, Nairobi", "UtcOffset": "+03:00",
    "Name": "Tehran", "UtcOffset": "+03:30",
    "Name": "Abu Dhabi, Muscat, Baku, Tbilisi, Yerevan","UtcOffset": "+04:00",
    "Name": "Kabul", "UtcOffset": "+04:30",
    "Name": "Ekaterinburg, Islamabad, Karachi, Tashkent", "UtcOffset": "+05:00",
    "Name": "Chennai, Kolkata, Mumbai, New Delhi", "UtcOffset": "+05:30",
    "Name": "Kathmandu", "UtcOffset": "+05:45",
    "Name": "Almaty, Dhaka, Sri Jayawardenepura", "UtcOffset": "+06:00",
    "Name": "Rangoon",  "UtcOffset": "+06:30",
    "Name": "Bangkok, Hanio, Jakarta, Novosibirsk, Astana, Krasnoyarsk", "UtcOffset": "+07:00",
    "Name": "Beijing, Chongqing, Hong Kong, Urumqi, Taipei, Perth",  "UtcOffset": "+08:00",
    "Name": "Eucla",    "UtcOffset": "+08:45",
    "Name": "Osaka, Sapporo, Tokyo, Seoul, Yakutsk", "UtcOffset": "+09:00",
    "Name": "Adelaide, Darwin", "UtcOffset": "+09:30",
    "Name": "Canberra, Melbourne, Sydney, Guam, Hobart, Vladivostok", "UtcOffset": "+10:00",
    "Name": "Lord Howe", "UtcOffset": "+10:30",
    "Name": "Chatham", "UtcOffset": "+10:45",
    "Name": "Magadan, Solomon Is., New Caledonia", "UtcOffset": "+11:00",
    "Name": "Auckland, Wellington, Fiji, Kamchatka, Marshall Is.",  "UtcOffset": "+12:00",
    "Name": "Nuku'alofa", "UtcOffset": "+13:00",
    "Name": "Line Islands", "UtcOffset": "+14:00",
    "Name": "Unspecified Time Zone", "UtcOffset": "+00:00",
#>


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.800 -ListAvailable )) { Install-Module -Name HPEOneView.800 -scope Allusers -Force }


#################################################################################

if (! $ConnectedSessions) {
    
    $secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
    # Connection to the OneView / Synergy Composer
    $credentials = New-Object System.Management.Automation.PSCredential ($OV_username, $secpasswd)

    try {
        Connect-OVMgmt -Hostname $OV_IP -Credential $credentials -ErrorAction stop | Out-Null    
    }
    catch {
        Write-Warning "Cannot connect to '$OV_IP'! Exiting... "
        return
    }

    # Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}

# Added these lines to avoid the error: "The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel."
# due to an invalid Remote Certificate
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

# Capture iLO5 server hardware managed by HPE OneView
$SH = Search-OVIndex -Category server-hardware | ? { $_.Attributes.mpModel -eq "iLO5" } #| select -first 2

clear

if ($SH) {
    write-host ""
    if (! $SH.count) { 
        Write-host "1 x iLO5 is going to be configured with the new time zone:" 
    }
    else {
        Write-host $SH.Count "x iLO5 are going to be configured with the new time zone:" 
    } 
    $SH.name | Format-Table -autosize | Out-Host

}
else {
    Write-Warning "No iLO5 server found ! Exiting... !"
    Disconnect-OVMgmt
    exit
}


# Request content to set time zone
$body = @"
{
    "TimeZone": {
        "Name": "$timezone"
    }

}

"@

# Creation of the headers  
$headers = @{} 
$headers["OData-Version"] = "4.0"

# iLO5 Redfish URI
$uri = "/redfish/v1/Managers/1/DateTime/"

# Method
$method = "patch"

#####################################################################################################################

foreach ($item in $SH) {

    $iLOIP = $item.multiAttributes.mpIpAddresses |  ? { $_ -NotMatch "fe80" }

    # Capture of the SSO Session Key
    try {
        $ilosessionkey = ($item | Get-OVIloSso -IloRestSession)."X-Auth-Token"
        $headers["X-Auth-Token"] = $ilosessionkey 
    }
    catch {
        Write-Warning "`niLO [$iLOIP] cannot be found ! Fix any communication problem you have in OneView with this iLO/server hardware !"
        continue
    }

      
    # Setting Time zone
    try {
        $response = Invoke-WebRequest -Uri "https://$iLOIP$uri" -Body $body -ContentType "application/json" -Headers $headers -Method $method -ErrorAction Stop
        $msg = ($response.Content | ConvertFrom-Json).error.'@Message.ExtendedInfo'.MessageId
        write-host "`niLO $($iloip) Time zone is now configured, iLO needs to be reset... API response: [$($msg)]"
    }
    catch {
        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
        $msg = ($err | ConvertFrom-Json ).error.'@Message.ExtendedInfo'.MessageId
        Write-Host -BackgroundColor:Black -ForegroundColor:Red "iLO $($iloip) Time zone configuration error ! Message returned: [$($msg)]"
        continue
    }
          
    # Reset iLO to activate the iLO change
    try {
        write-host "iLO $($iloip) - Reseting iLO to enable the new time zone..." 
        $task = Invoke-WebRequest -Uri "https://$iLOIP/redfish/v1/Managers/1/Actions/Manager.Reset" -Headers $headers -ContentType "application/json" -Method Post
    }
    catch {
        $error[0]
    }           

}


Disconnect-OVMgmt