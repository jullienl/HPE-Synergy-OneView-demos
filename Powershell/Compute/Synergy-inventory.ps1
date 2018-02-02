# Created by DAVIDMARTINEZROBLES
# https://github.com/DAVIDMARTINEZROBLES 


$file = "Synergy_inventory.txt"

$Linebreak = "########################################"

echo $Linebreak "RACK" $Linebreak >> $file
Get-HPOVRack | Get-HPOVRackMember | Sort-Object Ulocation >> $file
echo $Linebreak "ADDRESS POOL RANGE" $Linebreak >> $file
Get-HPOVAddressPoolRange >> $file
echo $Linebreak "ADDRESS POOL SUBNET" $Linebreak >> $file
Get-HPOVAddressPoolSubnet >> $file
echo $Linebreak "COMPOSER" $Linebreak >> $file
Get-HPOVComposerNode | ft Appliance, modelNumber, name, role, state, status, version, synchronizationPercentComplete >> $file
echo $Linebreak "IMAGE STREAMER" $Linebreak >> $file
Get-HPOVImageStreamerAppliance | ft oneViewIpv4Address, name, status, applianceserialnumber, imagestreamerversion, isactive, isprimary >> $file
echo $Linebreak "ENCLOSURE" $Linebreak >> $file
Get-HPOVEnclosure | Sort-Object -Property name >> $file
echo $Linebreak "SERVER RESUME" $Linebreak >> $file
Get-HPOVServer | Format-Table position, name, mpModel, mpFirmwareVersion, model, serialNumber, processorType, memoryMb, romVersion, intelligentProvisioningVersion, state, powerState | Sort-Object -Property locationUri, position >> $file
echo $Linebreak "DRIVE ENCLOSURE" $Linebreak >> $file
Get-HPOVDriveEnclosure | Format-Table name, bay, model, serialNumber, partNumber, productName, driveBayCount, firmwareVersion, ioAdapterCount, powerState | Sort-Object {[int]$_.bay}>> $file
echo $Linebreak "INTERCONNECT" $Linebreak >> $file
Get-HPOVinterconnect | Format-Table enclosureName, hostName,model, name, partNumber, serialNumber, interconnectIP, firmwareVersion, portCount, baseWWN | Sort-Object name >> $file
$Enclosures = Get-HPOVEnclosure | Sort-Object -Property name
Foreach ($Enclosure in $Enclosures)
{
echo $Linebreak "ENCLOSURE DETAIL" $Enclosure.name $Linebreak >> $file
echo $Linebreak "Interconnect" $Enclosure.serialNumber $Linebreak >> $file
(Send-HPOVRequest -Uri ($Enclosure.uri)).interconnectBays | Format-Table bayNumber, interconnectModel, partNumber, serialNumber, ipv4Setting | Sort-Object -Property bayNumber >> $file
echo $Linebreak "Appliance Bays" $Enclosure.serialNumber $Linebreak >> $file
(Send-HPOVRequest -Uri ($Enclosure.uri)).applianceBays | ft bayNumber, devicePresence, status, model, serialNumber, partNumber, poweredOn | Sort-Object -Property bayNumber >> $file
echo $Linebreak "Manager Bays" $Enclosure.serialNumber $Linebreak >> $file
(Send-HPOVRequest -Uri ($Enclosure.uri)).managerBays | ft bayNumber, model, devicePresence, role, FwVersion, partNumber, sparePartNumber | Sort-Object -Property bayNumber >> $file
echo $Linebreak "PowerSupply" $Enclosure.serialNumber $Linebreak >> $file
(Send-HPOVRequest -Uri ($Enclosure.uri)).powerSupplyBays | Format-Table | Sort-Object -Property bayNumber >> $file
echo $Linebreak "Fan" $Enclosure.serialNumber $Linebreak >> $file
(Send-HPOVRequest -Uri ($Enclosure.uri)).fanBays | Format-Table bayNumber, devicePresence, fanBayType, model, serialNumber, partNumber, sparePartNumber | Sort-Object -Property bayNumber >> $file
}

$servers = Get-HPOVserver | Sort-Object locationuri, {[int]$_.position}


Foreach ($server in $servers)
{
echo $Linebreak "SERVER DETAIL" $server.name $Linebreak >> $file
(Send-HPOVRequest -Uri ($server.uri)).portMap.deviceSlots | Format-Table >> $file
(Send-HPOVRequest -Uri ($server.uri)).portMap.deviceSlots.physicalPorts | Format-Table type, portNumber, physicalInterconnectPort, interconnectport, mac >> $file
(Send-HPOVRequest -Uri ($server.uri)).mpHostInfo.mpIpAddresses | Format-Table type, address >> $file
(Send-HPOVRequest -Uri ($server.uri + "/firmware")).components | Format-Table componentLocation, componentName, componentVersion | Sort-Object componentLocation, componentName | Out-File $file -Append
}
$DriveEnclosures = Get-HPOVDriveEnclosure | Sort-Object name, {[int]$_.bay}
Foreach ($DriveEnclosure in $DriveEnclosures)
{
echo $Linebreak "DRIVE ENCLOSURE DETAIL" $DriveEnclosure.serialNumber $DriveEnclosure.name $Linebreak >> $file
(Send-HPOVRequest -Uri ($DriveEnclosure.uri)).ioadapters | Format-Table model, partnumber, serialnumber, firmwareversion, portcount, redundantIoModule >> $file
(Send-HPOVRequest -Uri ($DriveEnclosure.uri)).driveBays.drive | Format-Table name, serialNumber, model, deviceInterface, driveMedia, linkRateInGbs, drivePaths, firmwareVersion, status, temperature >> $file
}
