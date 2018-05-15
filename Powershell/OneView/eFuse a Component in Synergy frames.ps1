# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# October 2016
#
# This is a POSH script to eFuse a component (compute, appliance, interconnect or flm) in Synergy frames
# 
# OneView administrator account is required. 
# Script created for up to 3 frames
# 
# --------------------------------------------------------------------------------------------------------

#
# $enc = Get-HPOVEnclosure -Name "Frame3-CN7515049C" 
# Reset-HPOVEnclosureDevice -Enclosure $enc  -Component Device -DeviceID 6 -Efuse -confirm:$false


#IP address of OneView
$IP = "192.168.1.110" 

# OneView Credentials
$username = "Administrator" 
$password = "password" 

# Import the OneView 4.00 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -Confirm:$false 


Function MyImport-Module {
    
    # Import a module that can be imported
    # If it cannot, the module is installed
    # When -update parameter is used, the module is updated 
    # to the latest version available on the PowerShell library
    
    param ( 
        $module, 
        [switch]$update 
           )
   
   if (get-module $module -ListAvailable)

        {
        if ($update.IsPresent) 
            {
            # Updates the module to the latest version
            [string]$Moduleinstalled = (Get-Module -Name $module).version
            [string]$ModuleonRepo = (Find-Module -Name $module -ErrorAction SilentlyContinue).version

            $Compare = Compare-Object $Moduleinstalled $ModuleonRepo -IncludeEqual

            If (-not $Compare.SideIndicator -eq '==')
                {
                Update-Module -Name $module -Confirm -Force | Out-Null
           
                }
            Else
                {
                Write-host "You are using the latest version of $module" 
                }
            }
            
        Import-module $module
            
        }

    Else

        {
        Write-Warning "$Module is not present"
        Write-host "`nInstalling $Module ..." 

        Try
            {
                If ( !(get-PSRepository).name -eq "PSGallery" )
                {Register-PSRepository -Default}
                Install-Module –Name $module -Scope CurrentUser –Force -ErrorAction Stop | Out-Null
            }
        Catch
            {
                Write-Warning "$Module cannot be installed" 
                $error[0] | FL * -force
            }
        }

}

#MyImport-Module PowerShellGet
#MyImport-Module FormatPX
#MyImport-Module SnippetPX
MyImport-Module HPOneview.400 #-update
#MyImport-Module PoshRSJob
   
  

# Connection to the Synergy Composer

If ($connectedSessions -and ($connectedSessions | ? {$_.name -eq $IP})) {
    Write-Verbose "Already connected to $IP."
}

Else {
    Try {
        Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password | Out-Null
    }
    Catch {
        throw $_
    }
}




import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? {$_.name -eq $IP})


# Creation of the header

$postParams = @{userName = $username; password = $password} | ConvertTo-Json 
$headers = @{} 
#$headers["Accept"] = "application/json" 
$headers["X-API-Version"] = "300"

# Capturing the OneView Session ID and adding it to the header
    
$key = $ConnectedSessions[0].SessionID 

$headers["auth"] = $key
    

$numberofframes = @(Get-HPOVEnclosure).count
$frames = Get-HPOVEnclosure | % {$_.name}
    
    
#clear


#Which enclosure you want to eFuse a component?

if ($numberofframes -gt 0) {
    $interconnects = Get-HPOVInterconnect     
    $whosframe1 = $interconnects | where {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 3"} | % {$_.enclosurename}
}

if ($numberofframes -gt 1) {
    $whosframe2 = $interconnects | where {$_.partNumber -match "794502-B23" -and $_.name -match "interconnect 6"} | % {$_.enclosurename}
}

if ($numberofframes -gt 2) {
    $frameswithsatellites = $interconnects | where -Property Partnumber -eq "779218-B21" 
    $whosframe3 = $frameswithsatellites | group-object -Property enclosurename |  ? { $_.Count -gt 1 } | % {$_.name}  
}

if ($numberofframes -gt 3) { Write-Host "This script does not support more than 3 frames"}


do 

{    
   
    do {
        
        clear
        write-host "On which frame do you want to eFuse a component?"
        write-host ""
        write-host "1 - $whosframe1"
        if ($numberofframes -gt 1) {write-host "2 - $whosframe2"}
        if ($numberofframes -gt 2) {write-host "3 - $whosframe3"}
        write-host ""
        write-host "X - Exit"
        write-host ""
        write-host -nonewline "Type your choice (1, 2 or 3) and press Enter: "
        
        $choice = read-host
        
        write-host ""
        
        $ok = $choice -match '^[123x]+$'
        
        if ( -not $ok) {
            write-host "Invalid selection"
            write-host ""
        }
   
    } until ( $ok )

    if ($choice -eq "x") { exit }

      
    switch -Regex ( $choice ) {
        "1" {
            $frame = $whosframe1
        }
        
        "2" {
            $frame = $whosframe2
        }

        "3" {
            $frame = $whosframe3
        }

    }
    
   
    $enclosure = Get-HPOVEnclosure | where {$_.name -Match $frame}
    $frameuuid = (Get-HPOVEnclosure | where {$_.name -Match $frame}).uuid
    $locationUri = (Get-HPOVEnclosure | where {$_.name -Match $frame}).uri
    

    do {
        clear
        write-host "What do you want to eFuse?"
        write-host "1 - A Compute Module"
        write-host "2 - An Interconnect"
        write-host "3 - An Appliance"
        write-host "4 - A Frame Link Module"
        write-host ""
        write-host "X - Exit"
        write-host ""
        write-host -nonewline "Type your choice and press Enter: "
        
        $componenttoefuse = read-host
        
        write-host ""
        
        $ok = $componenttoefuse -match '^[1234x]+$'
        
        if ( -not $ok) {
            write-host "Invalid selection"
            write-host ""
        }
   
    } until ( $ok )

      
       

    #Creation of the body content to efsue a Compute Module

    if ($componenttoefuse -eq 1) {
        clear
        $ert = Get-HPOVServer | where {$_.locationUri -eq $locationUri} 

        $ert | Select @{Name = "Model"; expression = {$_.shortmodel}},
        @{Name = "Compute"; expression = {$_.name}},
        @{Name = "Power State"; expression = {$_.powerState}},
        @{Name = "Profile"; expression = {$_.state}}        | Format-Table -AutoSize | out-host
                  
        $baynb = Read-Host "Please enter the Computer Module Bay number to efuse (1 to 12)"
        #$body = '[{"op":"replace","path":"/deviceBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]' 
        $component = "Device"  
    }

    if ($componenttoefuse -eq 2) {
        clear
        $ert = Get-HPOVInterconnect | where {$_.enclosurename -eq $frame} 
                    
        $ert | Select @{Name = "Interconnect Model"; Expression = {$_.model}}, @{Name = "Bay number"; Expression = {$_.interconnectlocation.locationEntries | where {$_.type -eq "Bay"} | select  value | % {$_.value}}} | Sort-Object –Property "Bay number" | Out-Host


        $baynb = Read-Host "Please enter the Interconnect Module Bay number to efuse (1 to 6)"
        #$body = '[{"op":"replace","path":"/interconnectBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]'   
        $component = "ICM"  
    }

    if ($componenttoefuse -eq 3) {
        clear
        $ert = (Get-HPOVEnclosure | where {$_.name -Match $frame}).applianceBays | where {$_.devicePresence -eq "Present"}
        $ert | Select @{Name = "Model"; Expression = {$_.model}}, @{Name = "Bay number"; Expression = {$_.baynumber}}, @{Name = "Status"; Expression = {$_.status}} | Out-Host
        
        $baynb = Read-Host "Please enter the Appliance Bay number to efuse (1 or 2)"
        #$body = '[{"op":"replace","path":"/applianceBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]'   
        $component = "Appliance"  
    }

    if ($componenttoefuse -eq 4) {
        clear
        $ert = (Get-HPOVEnclosure | where {$_.name -Match $frame}).managerbays
        $ert | Select @{Name = "Model"; Expression = {$_.model}}, @{Name = "Bay number"; Expression = {$_.baynumber}}, @{Name = "Role"; Expression = {$_.role}}, @{Name = "Status"; Expression = {$_.status}} | Out-Host

        $baynb = Read-Host "Please enter the FLM Bay number to efuse (1 or 2)"
        #$body = '[{"op":"replace","path":"/managerBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]'   
        $component = "FLM"  
    }

    if ($componenttoefuse -eq "x") { exit }



    # eFuse the Component
    #$efusecomponent = Invoke-WebRequest -Uri "https://$IP/rest/enclosures/$frameuuid" -ContentType "application/json" -Headers $headers -Method PATCH -UseBasicParsing -Body $body
    
    $efusecomponent = Reset-HPOVEnclosureDevice -Enclosure $enclosure  -Component $component -DeviceID $baynb -Efuse -confirm:$false | Wait-HPOVTaskComplete
    
    #sleep 15

    write-host `n`n`n`n
    Write-Warning "The $Component in Bay $baynb is efusing!`n"

    pause
 
} until ( $componenttoefuse -eq "X" )


