<# 

 This script provides physical and logical drives information from the HPE smart array  
 
 OneView Powershell Library and HPERedfishCmdlets are required

#>



# Composer information
$username = "Administrator"
$password = "password"
$composer = "composer.lj.lab"

$server = "Frame1, bay 6"



#Importing HPOneView module
If (-not (get-Module HPOneview.420 ) ) {

    Try { Import-Module HPOneview.420 -ErrorAction Stop } 
    catch {
        install-Module HPOneview.420
        import-Module HPOneview.420
    }
}


#Importing HPERedfishCmdlets module
If (-not (get-Module HPERedfishCmdlets ) ) {

    Try { Import-Module HPERedfishCmdlets -ErrorAction Stop } 
    catch {
        install-Module HPERedfishCmdlets
        import-Module HPERedfishCmdlets
    }
}


#Connecting to the Synergy Composer
Connect-HPOVMgmt -appliance $composer -UserName $username -Password $password | Out-Null




$sh = Get-HPOVServer -Name $server

"Server Hardware: {0}" -f $sh.name

$iloSession = $sh | Get-HPOVIloSso -IloRestSession
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
        "`t`tId={0}, RAID={1}, CapacityGB={2}, LogicalDriveEncryption={3}, Health={4}, State={5}" -f $my_lDrive.Id, $my_lDrive.Raid, [math]::Round(($my_lDrive.CapacityMiB) / 1024, 0) , $my_lDrive.LogicalDriveEncryption, $my_lDrive.CapacityMiB, $my_lDrive.Status.Health, $my_lDrive.Status.State 

        $dataDrives = Get-HPERedfishDataRaw -Odataid $my_lDrive.Links.DataDrives.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
		

        foreach ($dataDrive in $dataDrives.members) {
		
            $my_dataDrive = Get-HPERedfishDataRaw -Odataid $dataDrive.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
            "`t`t`tId={0}, Location={1}, Model={2}, Type={3}, CapacityGB={4}, EncryptedDrive={5}" -f $my_dataDrive.Id, $my_dataDrive.Location, $my_dataDrive.Model, ("{0}{1}" -f $my_dataDrive.InterfaceType, $my_dataDrive.MediaType), $my_dataDrive.CapacityGB, $my_dataDrive.EncryptedDrive | Write-Host
        }

        Try { $sparedrives = Get-HPERedfishDataRaw -Odataid $my_lDrive.Links.StandbySpareDrives.'@odata.id' -Session $iloSession -DisableCertificateAuthentication } catch { }
        
        if ($sparedrives) {
            
            foreach ($sparedrive in $sparedrives.members) {
		
                $my_spareDrive = Get-HPERedfishDataRaw -Odataid $SpareDrive.'@odata.id' -Session $iloSession -DisableCertificateAuthentication
                "`t`t`t`tSpare drive: Id={0}, Location={1}, Model={2}, Type={3}, CapacityGB={4}, EncryptedDrive={5}" -f $my_spareDrive.Id, $my_spareDrive.Location, $my_spareDrive.Model, ("{0}{1}" -f $my_spareDrive.InterfaceType, $my_spareDrive.MediaType), $my_spareDrive.CapacityGB, $my_dataDrive.EncryptedDrive | Write-Host
            }
        }

    }
	
}

Disconnect-HPOVMgmt
