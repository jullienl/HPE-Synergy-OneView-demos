<# 

This PowerShell script disables the TLS1.0 and 1.1 protocols on the Synergy Composer appliance. 

Important note: Enabling/Disabling TLS protocols reboots the appliance automatically for the changes to take effect. 
This reboot does not affect Compute modules and Interconnect Modules, only the management plane is impacted.

Requirements: 
- OneView administrator account.


  Author: lionel.jullien@hpe.com
  Date:   July 2021
    
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


#IP address of OneView
$IP = "192.168.1.110" 
# OneView Credentials
$username = "Administrator" 

$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null


# Capturing the OneView Session ID
$key = $ConnectedSessions[0].SessionID 

# Headers creation
$headers = @{} 
$headers["auth"] = $key
$headers["X-API-Version"] = "1200"
$headers["Content-Type"] = "application/json"

$body = "    [  
`n        {
`n        `"protocolName`":`"TLSv1`",
`n        `"enabled`":false
`n        },
`n        {
`n        `"protocolName`":`"TLSv1.1`",
`n        `"enabled`":false
`n        },
`n        {
`n        `"protocolName`":`"TLSv1.2`",
`n        `"enabled`":true
`n        }
`n  ]"

try {
    $response = Invoke-RestMethod "https://$($IP)/rest/security-standards/protocols" -Method 'PUT' -Headers $headers -Body $body
}
catch {
    $response | ConvertTo-Json 
}


write-host "OneView is now rebooting..."
Disconnect-OVMgmt
