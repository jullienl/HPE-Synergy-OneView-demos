<# This script reduces the OneView reserved VLAN pool to 4035-4094.

There is a reserved VLAN pool, a range of VLANs used for Tunnel, Untagged and Native FC networks. 

These VLAN IDs are reserved and cannot be used.
• 128 is the default reserved range [3967-4094]
• The minimum size of the pool must be 60 VLANs [4035-4094] to ensure the pool is not exhausted

This pool can only be reduced using the REST API 
See http://h17007.www1.hpe.com/docs/enterprise/servers/oneview4.2/cicf-api/en/index.html#rest/fabrics
 
OneView Powershell Library is required
#>


# Composer information
$username = "Administrator"
$password = "password"
$composer = "composer.lj.lab"


If (-not (get-Module HPOneview.420) ) {

    Import-Module HPOneview.420
}


#Connecting to the Synergy Composer
Connect-HPOVMgmt -appliance $composer -UserName $username -Password $password | Out-Null


# GET (before)

$fabric = Send-HPOVRequest -uri "/rest/fabrics" 

 

$pool = $fabric.members.reservedVlanRange

"BEFORE - vlan-pool: start={0}, length={1}" -f $pool.start, $pool.length | Write-Host -ForegroundColor Yellow

 

 

# PUT

$vlanRangeStart = "4035"

$vlanRangeLength = "60"

 

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