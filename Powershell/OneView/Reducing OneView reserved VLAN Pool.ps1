# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# September 2019
#
# This script reduces the OneView reserved VLAN pool to 4035-4094.
#
# There is a reserved VLAN pool, a range of VLANs used for Tunnel, Untagged and Native FC networks. 
#
# These VLAN IDs are reserved and cannot be used.
# • 128 is the default reserved range [3967-4094]
# • The minimum size of the pool must be 60 VLANs [4035-4094] to ensure the pool is not exhausted
#
# This pool can only be reduced using the REST API 
# See http://h17007.www1.hpe.com/docs/enterprise/servers/oneview4.2/cicf-api/en/index.html#rest/fabrics
#
#
# Requirements:
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
#
# --------------------------------------------------------------------------------------------------------

#################################################################################
#        (C) Copyright 2018 Hewlett Packard Enterprise Development LP           #
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



# Reserved VLAN Pool range to set
$vlanRangeStart = "4035"
$vlanRangeLength = "60"


# OneView information
$username = "Administrator"
$IP = "composer.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################


$secpasswd = read-host  "Please enter the OneView password" -AsSecureString
 
# Connection to the Synergy Composer
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null


Clear-Host


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


#########################################################################################################


               
# GET (before)

$fabric = Send-OVRequest -uri "/rest/fabrics" 

$pool = $fabric.members.reservedVlanRange

"BEFORE - vlan-pool: start={0}, length={1}" -f $pool.start, $pool.length | Write-Host -ForegroundColor Yellow

 
# PUT

$data = @{
    "start"  = $vlanRangeStart
    "length" = $vlanRangeLength
    "type"   = "vlan-pool"
}

 
$task = Send-OVRequest -uri $pool.uri -method PUT -body $data
$task | Wait-OVTaskComplete
 

# GET (after)

$newPool = Send-OVRequest -uri $pool.uri

"AFTER - vlan-pool: start={0}, length={1}" -f $newPool.start, $newPool.length | Write-Host -ForegroundColor Green

Disconnect-OVMgmt