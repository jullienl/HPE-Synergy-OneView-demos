<# 

This script reduces the OneView reserved VLAN pool to 4035-4094.

There is a reserved VLAN pool, a range of VLANs used for Tunnel, Untagged and Native FC networks. 

These VLAN IDs are reserved and cannot be used.
• 128 is the default reserved range [3967-4094]
• The minimum size of the pool must be 60 VLANs [4035-4094] to ensure the pool is not exhausted

This pool can only be reduced using the REST API 
See http://h17007.www1.hpe.com/docs/enterprise/servers/oneview4.2/cicf-api/en/index.html#rest/fabrics
 
OneView Powershell Library is required
#>


#################################################################################
#                                Global Variables                               #
#################################################################################

# Pool range
$vlanRangeStart = "4035"
$vlanRangeLength = "60"



# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer2.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }


#################################################################################

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

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

               
# GET (before)

$fabric = Send-HPOVRequest -uri "/rest/fabrics" 

$pool = $fabric.members.reservedVlanRange

"BEFORE - vlan-pool: start={0}, length={1}" -f $pool.start, $pool.length | Write-Host -ForegroundColor Yellow

 
# PUT

$data = @{

    "start"  = $vlanRangeStart
    "length" = $vlanRangeLength
    "type"   = "vlan-pool"

}

 
$task = Send-HPOVRequest -uri $pool.uri -method PUT -body $data
$task | Wait-HPOVTaskComplete
 

# GET (after)

$newPool = Send-HPOVRequest -uri $pool.uri

"AFTER - vlan-pool: start={0}, length={1}" -f $newPool.start, $newPool.length | Write-Host -ForegroundColor Green

Disconnect-HPOVMgmt