# -------------------------------------------------------------------------------------------------------
#  by lionel.jullien@hpe.com
#  July 2018
#
#  This is a POSH script example on how to create a Logical Drive using hpeRedFishcmdlets
#  First two drives found are used to create a RAID1 Logical volume 
#  
#  Requirement:
#    - HPE Redfish PowerShell library (hpeRedFishcmdlets)
#    - HPE OneView Powershell Library
#    - HPE OneView administrator account 
#
#  An iLO user account is not required, the authentication is done through OneView iLO SSO REST session
# 
# --------------------------------------------------------------------------------------------------------


# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "composer2.lj.lab"


# MODULES TO INSTALL

# HPEOneView
# If (-not (get-module HPEOneView.630 -ListAvailable )) { Install-Module -Name HPEOneView.630 -scope Allusers -Force }

# hpeRedFishcmdlets
# If (-not (get-module hpeRedFishcmdlets -ListAvailable )) { Install-Module -Name hpeRedFishcmdlets -scope Allusers -Force }

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

#################################################################################


Get-OVServer | ? model -match Gen10 | Out-Host

$servername = read-host "Enter the server hardware name where you want to create a RAID1 Logical volume"

$sh = Get-OVServer -Name $servername

"Server Hardware: {0}" -f $sh.name

$iloSession = $sh | Get-OVIloSso -IloRestSession
$iloSession.RootUri = $iloSession.RootUri.Replace("rest", "redfish")


# Get smartstorageconfig settings
$uri = "/redfish/v1/Systems/1/SmartStorage/"

$data = Get-HPERedfishDataRaw -Odataid $uri -Session $iloSession  -DisableCertificateAuthentication

# Get ArrayControllers
$uri = $data.Links.ArrayControllers.'@odata.id'
$ctrls = Get-HPERedfishDataRaw -Odataid $uri -Session $iloSession -DisableCertificateAuthentication


foreach ($ctrl in $ctrls.members) {
    $my_ctrl = Get-HPERedfishDataRaw -Odataid $ctrl.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
    "model: {0}, Location: {1}, Health: {2}, State: {3}" -f $my_ctrl.Model, $my_ctrl.Location, $my_ctrl.Status.Health, $my_ctrl.Status.State | Write-Host -ForegroundColor Yellow
    "`tEncryptionEnabled={0}, EncryptionStandaloneModeEnabled={1}, EncryptionCryptoOfficerPasswordSet={2}, EncryptionMixedVolumesEnabled={3}" -f $my_ctrl.EncryptionEnabled, $my_ctrl.EncryptionStandaloneModeEnabled, $my_ctrl.EncryptionCryptoOfficerPasswordSet, $my_ctrl.EncryptionMixedVolumesEnabled | Write-Host -ForegroundColor Green
    # Get Physical Drives
    $pDrives = Get-HPERedfishDataRaw -Odataid $my_ctrl.Links.PhysicalDrives.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
    "`t{0} Physical Drive(s) attached to controller" -f $pDrives.'Members@odata.count' | Write-Host
    foreach ($pDrive in $pDrives.members) {
        $my_pDrive = Get-HPERedfishDataRaw -Odataid $pDrive.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
        "`t`tId={0}, Location={1}, Model={2}, Type={3}, CapacityGB={4}, EncryptedDrive={5}" -f $my_pDrive.Id, $my_pDrive.Location, $my_pDrive.Model, ("{0}{1}" -f $my_pDrive.InterfaceType, $my_pDrive.MediaType), $my_pDrive.CapacityGB, $my_pDrive.EncryptedDrive | Write-Host
    }
	
    # Get Logical Drives
    $lDrives = Get-HPERedfishDataRaw -Odataid $my_ctrl.Links.LogicalDrives.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
    "`t{0} Logical Drive(s) configured on controller" -f $lDrives.'Members@odata.count' | Write-Host
	
    foreach ($lDrive in $lDrives.members) {
        $my_lDrive = Get-HPERedfishDataRaw -Odataid $lDrive.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
        "`t`tId={0}, RAID={1}, CapacityMiB={2}, LogicalDriveEncryption={3}, Health={4}, State={5}" -f $my_lDrive.Id, $my_lDrive.Raid, $my_lDrive.CapacityMiB, $my_lDrive.LogicalDriveEncryption, $my_lDrive.CapacityMiB, $my_lDrive.Status.Health, $my_lDrive.Status.State 
        $dataDrives = Get-HPERedfishDataRaw -Odataid $my_lDrive.Links.DataDrives.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
        foreach ($dataDrive in $dataDrives.members) {
            $my_dataDrive = Get-HPERedfishDataRaw -Odataid $dataDrive.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
            "`t`t`tId={0}, Location={1}, Model={2}, Type={3}, CapacityGB={4}, EncryptedDrive={5}" -f $my_dataDrive.Id, $my_dataDrive.Location, $my_dataDrive.Model, ("{0}{1}" -f $my_dataDrive.InterfaceType, $my_dataDrive.MediaType), $my_dataDrive.CapacityGB, $my_dataDrive.EncryptedDrive | Write-Host
        }
    }
	
}
#>

$nb = 1
foreach ($pDrive in $pDrives.members) {
			
    $my_dataDrive = Get-HPERedfishDataRaw -Odataid $pDrive.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
		    
    New-variable -Name "dataDrive$nb" -Value $my_dataDrive.Location -Force
    # Creation of a logical drive using the following disk:
    #Get-variable -Name "dataDrive$nb" -ValueOnly
    $nb++

}

# $dataDrive1
# $datadrive2
# etc

$settings = @{
    "LogicalDrives" = @(
        @{
            "Raid"             = "Raid1"
            "DataDrives"       = @("$dataDrive1", "$dataDrive2")
            "LogicalDriveName" = "LD_RAID1-2DISKS"
                
        }
    )
    
    "DataGuard"     = "Disabled"
}


<#
Sample of the body content to create a RAID1 logical drive using 2 Drives

$settings=@{
	"LogicalDrives"=@(
	 	@{
			"Raid"="Raid1"
			"DataDrives"=@("3I:1:1","3I:1:2")
            "LogicalDriveName"= "LD_RAID1-2DISKS"
                
		}
	 )
    
    "DataGuard" = "Disabled"
}
#>


# $settings | Convertto-Json -d 99



# Edit smartstorageconfig settings

$uri = "/redfish/v1/systems/1/smartstorageconfig/settings/"

$return = Edit-HPERedfishData -Odataid $uri -Setting $settings -Session $iloSession -ErrorAction Stop -DisableCertificateAuthentication

$message = $return.error.'@Message.ExtendedInfo'.MessageId

Write-host "$message" -f Green




# Deleting the RedFish Session

$sessions = Get-HPERedfishDataRaw -Odataid "/redfish/v1/SessionService/Sessions/" -Session $iloSession
$mySession = $sessions.Oem.Hpe.Links.MySession.'@odata.id'
# "My Session: {0}" -f $mySession | Write-Host -ForegroundColor Yellow
$ret = Remove-HPERedfishData -Odataid $mySession -Session $iloSession
Write-Host "Deleting My Session"

foreach ($msg in $ret.error) {
    foreach ($msgExt in $msg.'@Message.ExtendedInfo') {
        if ($msgExt.MessageId.ToLower().Contains("success")) {
            "{0}" -f $msgExt.MessageId | Write-Host -ForegroundColor Green
        }
    }
}

Disconnect-OVMgmt