<# 

This is a PowerShell script to eFuse a component (Compute, appliance, interconnect or Frame Link Module) in a HPE Synergy frame.

At the beginning of the execution, the script displays a list of logical enclosures (LE) available in HPE OneView. 
Once you select an LE, a list of frames belonging to that LE is displayed. Once a frame is selected, you can select 
the component you want to e-fuse (Compute module, Interconnect, appliance or FLM). Once a component type is selected, 
a list of components with bay numbers is displayed. Once you provide a bay number, the component corresponding to this bay is efused.

This script supports up to 5 frames per LE with a maximum of 21 Logical Enclosures.

Requirements: 
- HPE OneView administrator account.
- The names of the Logical Enclosure and frame must be known

  Author: lionel.jullien@hpe.com
  Date:   October 2016
    
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

#################################################################################

$LEs = Get-OVLogicalEnclosure

if ( ($LEs | gm)[0].TypeName -eq "HPEOneView.LogicalEnclosure") {
    $whosLE1 = $LEs.name
    $NumberofLEs = 1
}    
else {
    $NumberofLEs = $LEs.length
    $LE_array = @{}
    for ($i = 0; $i -le $LEs.length - 1; $i++) { 
        $nb = $i + 1
        $LE_array[$i]
        New-Variable -name whosLE$nb -Value $LEs[$i].name -Force
    }   
}

 
do {    

    do {
        
        clear
        write-host "On which Logical Enclosure do you want to eFuse a component?"
        write-host ""
        write-host "1 - $whosLE1"
        if ($NumberofLEs -gt 1) { write-host "2 - $whosLE2" }
        if ($NumberofLEs -gt 2) { write-host "3 - $whosLE3" }
        if ($NumberofLEs -gt 3) { write-host "4 - $whosLE4" }
        if ($NumberofLEs -gt 4) { write-host "5 - $whosLE5" }
        if ($NumberofLEs -gt 5) { write-host "6 - $whosLE6" }
        if ($NumberofLEs -gt 6) { write-host "7 - $whosLE7" }
        if ($NumberofLEs -gt 7) { write-host "8 - $whosLE8" }
        if ($NumberofLEs -gt 8) { write-host "9 - $whosLE9" }
        if ($NumberofLEs -gt 9) { write-host "10 - $whosLE10" }
        if ($NumberofLEs -gt 10) { write-host "11 - $whosLE11" }
        if ($NumberofLEs -gt 11) { write-host "12 - $whosLE12" }
        if ($NumberofLEs -gt 12) { write-host "13 - $whosLE13" }
        if ($NumberofLEs -gt 13) { write-host "14 - $whosLE14" }
        if ($NumberofLEs -gt 14) { write-host "15 - $whosLE15" }
        if ($NumberofLEs -gt 15) { write-host "16 - $whosLE16" }
        if ($NumberofLEs -gt 16) { write-host "17 - $whosLE17" }
        if ($NumberofLEs -gt 17) { write-host "18 - $whosLE18" }
        if ($NumberofLEs -gt 18) { write-host "19 - $whosLE19" }
        if ($NumberofLEs -gt 19) { write-host "20 - $whosLE20" }
        if ($NumberofLEs -gt 20) { write-host "21 - $whosLE21" }
        write-host ""
        write-host "X - Exit"
        write-host ""
        write-host -nonewline "Type your choice (1, 2...) and press Enter: "
        
        $choice = read-host
        
        write-host ""
        
        
        if ($NumberofLEs -gt 0) {
            $ok = $choice -match '^[1x]+$'
        }
        if ($NumberofLEs -gt 1) {
            $ok = $choice -match '^[12x]+$'
        }
        if ($NumberofLEs -gt 2) {
            $ok = $choice -match '^[123x]+$'
        }
        if ($NumberofLEs -gt 3) {
            $ok = $choice -match '^[1234x]+$'
        }
        if ($NumberofLEs -gt 4) {
            $ok = $choice -match '^[12345x]+$'
        }
        if ($NumberofLEs -gt 5) {
            $ok = $choice -match '^[123456x]+$'
        }
        if ($NumberofLEs -gt 6) {
            $ok = $choice -match '^[1234567x]+$'
        }
        if ($NumberofLEs -gt 7) {
            $ok = $choice -match '^[12345678x]+$'
        }
        if ($NumberofLEs -gt 8) {
            $ok = $choice -match '^[123456789x]+$'
        }
        if ($NumberofLEs -gt 9) {
            $ok = $choice -match '^([1-9]|x|10)$'  
        }
        if ($NumberofLEs -gt 10) {
            $ok = $choice -match '^([1-9]|x|1[0-1])$'
        }
        if ($NumberofLEs -gt 11) {
            $ok = $choice -match '^([1-9]|x|1[0-2])$'
        }
        if ($NumberofLEs -gt 12) {
            $ok = $choice -match '^([1-9]|x|1[0-3])$'
        }
        if ($NumberofLEs -gt 13) {
            $ok = $choice -match '^([1-9]|x|1[0-4])$'
        }
        if ($NumberofLEs -gt 14) {
            $ok = $choice -match '^([1-9]|x|1[0-5])$'
        }
        if ($NumberofLEs -gt 15) {
            $ok = $choice -match '^([1-9]|x|1[0-6])$'
        }
        if ($NumberofLEs -gt 16) {
            $ok = $choice -match '^([1-9]|x|1[0-7])$'
        }
        if ($NumberofLEs -gt 17) {
            $ok = $choice -match '^([1-9]|x|1[0-8])$'
        }
        if ($NumberofLEs -gt 18) {
            $ok = $choice -match '^([1-9]|x|1[0-9])$'
        }
        if ($NumberofLEs -gt 19) {
            $ok = $choice -match '^([1-9]|x|1[0-9]|20)$'
        }
        if ($NumberofLEs -gt 20) {
            $ok = $choice -match '^([1-9]|x|1[0-9]|2[0-1])$'
        }
        
        if ( -not $ok) {
            write-host "Invalid selection"
            write-host ""
        }
   
    } until ( $ok )

    if ($choice -eq "x") { 
    
        Disconnect-OVMgmt
        exit 
    }

      
    switch -Regex ( $choice ) {
        "1" { $LE = $whosLE1 }
        "2" { $LE = $whosLE2 }
        "3" { $LE = $whosLE3 }
        "4" { $LE = $whosLE4 }
        "5" { $LE = $whosLE5 }
        "6" { $LE = $whosLE6 }
        "7" { $LE = $whosLE7 }
        "8" { $LE = $whosLE8 }
        "9" { $LE = $whosLE9 }
        "10" { $LE = $whosLE10 }
        "11" { $LE = $whosLE11 }
        "12" { $LE = $whosLE12 }
        "13" { $LE = $whosLE13 }
        "14" { $LE = $whosLE14 }
        "15" { $LE = $whosLE15 }
        "16" { $LE = $whosLE16 }
        "17" { $LE = $whosLE17 }
        "18" { $LE = $whosLE18 }
        "19" { $LE = $whosLE19 }
        "20" { $LE = $whosLE20 }
        "21" { $LE = $whosLE21 }
    }


    # Get Fames information
    $enclosureUris = (Get-OVLogicalEnclosure -Name $LE).enclosureUris
    [array]::Reverse($enclosureUris)

    # Number of frames
    $numberofframes = $enclosureUris.Count
    
    $whosframe1 = (Send-OVRequest -Uri $enclosureUris[0]).name

    if ($numberofframes -gt 1) {
        $whosframe2 = (Send-OVRequest -Uri $enclosureUris[1]).name
    }

    if ($numberofframes -gt 2) {
        $whosframe3 = (Send-OVRequest -Uri $enclosureUris[2]).name
    }
   
    if ($numberofframes -gt 3) {
        $whosframe4 = (Send-OVRequest -Uri $enclosureUris[3]).name
    }   

    if ($numberofframes -gt 4) {
        $whosframe5 = (Send-OVRequest -Uri $enclosureUris[4]).name
    }



    do {
        
        clear
        write-host "On which frame do you want to eFuse a component?"
        write-host ""
        write-host "1 - $whosframe1"
        if ($numberofframes -gt 1) { write-host "2 - $whosframe2" }
        if ($numberofframes -gt 2) { write-host "3 - $whosframe3" }
        if ($numberofframes -gt 3) { write-host "4 - $whosframe4" }
        if ($numberofframes -gt 4) { write-host "5 - $whosframe5" }
        write-host ""
        write-host "X - Exit"
        write-host ""
        write-host -nonewline "Type your choice (1, 2...) and press Enter: "
        
        $choice = read-host
        
        write-host ""
        
        
        if ($numberofframes -gt 0) {
            $ok = $choice -match '^[1x]+$'
        }
        if ($numberofframes -gt 1) {
            $ok = $choice -match '^[12x]+$'
        }
        if ($numberofframes -gt 2) {
            $ok = $choice -match '^[123x]+$'
        }
        if ($numberofframes -gt 3) {
            $ok = $choice -match '^[1234x]+$'
        }
        if ($numberofframes -gt 4) {
            $ok = $choice -match '^[12345x]+$'
        }
        
        if ( -not $ok) {
            write-host "Invalid selection"
            write-host ""
        }
   
    } until ( $ok )

    if ($choice -eq "x") { 
        Disconnect-OVMgmt
        exit 
    }

      
    switch -Regex ( $choice ) {
        "1" { $frame = $whosframe1 }        
        "2" { $frame = $whosframe2 }
        "3" { $frame = $whosframe3 }
        "4" { $frame = $whosframe4 }
        "5" { $frame = $whosframe5 }

    }
    
   
    $enclosure = Get-OVEnclosure | where { $_.name -Match $frame }
    $frameuuid = (Get-OVEnclosure | where { $_.name -Match $frame }).uuid
    $locationUri = (Get-OVEnclosure | where { $_.name -Match $frame }).uri
    

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
        $ert = Get-OVServer | where { $_.locationUri -eq $locationUri } 

        $ert | Select-Object @{Name = "Model"; expression = { $_.shortmodel } },
        @{Name = "Compute"; expression = { $_.name } },
        @{Name = "PowerState"; expression = { $_.powerState } },
        @{Name = "Status"; expression = { $_.Status } },
        @{Name = "Profile"; expression = { $_.state } } | Format-Table -AutoSize | out-host
                  
        $baynb = Read-Host "Please enter the Computer Module Bay number to efuse (1 to 12)"
        #$body = '[{"op":"replace","path":"/deviceBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]' 
        $component = "Device"  
    }

    if ($componenttoefuse -eq 2) {
        clear
        $ert = Get-OVInterconnect | where { $_.enclosurename -eq $frame } 
                    
        $ert | Select @{Name = "Interconnect Model"; Expression = { $_.model } }, @{Name = "Status"; Expression = { $_.status } },
        @{Name = "Bay number"; Expression = { $_.interconnectlocation.locationEntries | where { $_.type -eq "Bay" } | select  value | % { $_.value } } } | Sort-Object -Property "Bay number" | Out-Host


        $baynb = Read-Host "Please enter the Interconnect Module Bay number to efuse (1 to 6)"
        #$body = '[{"op":"replace","path":"/interconnectBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]'   
        $component = "ICM"  
    }

    if ($componenttoefuse -eq 3) {
        clear
        $ert = (Get-OVEnclosure | where { $_.name -Match $frame }).applianceBays | where { $_.devicePresence -eq "Present" }
        $ert | Select @{Name = "Model"; Expression = { $_.model } }, @{Name = "Bay number"; Expression = { $_.baynumber } }, @{Name = "Status"; Expression = { $_.status } } | Out-Host
        
        $baynb = Read-Host "Please enter the Appliance Bay number to efuse (1 or 2)"
        #$body = '[{"op":"replace","path":"/applianceBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]'   
        $component = "Appliance"  
    }

    if ($componenttoefuse -eq 4) {
        clear
        $ert = (Get-OVEnclosure | where { $_.name -Match $frame }).managerbays
        $ert | Select @{Name = "Model"; Expression = { $_.model } }, @{Name = "Bay number"; Expression = { $_.baynumber } }, @{Name = "Role"; Expression = { $_.role } }, @{Name = "Status"; Expression = { $_.status } } | Out-Host

        $baynb = Read-Host "Please enter the FLM Bay number to efuse (1 or 2)"
        #$body = '[{"op":"replace","path":"/managerBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]'   
        $component = "FLM"  
    }

    if ($componenttoefuse -eq "x") { 
        Disconnect-OVMgmt
        exit 
    }

    
    $efusecomponent = Reset-OVEnclosureDevice -Enclosure $enclosure  -Component $component -DeviceID $baynb -Efuse -confirm:$false | Wait-OVTaskComplete
    
    #sleep 15

    write-host `n`n`n`n
    Write-Warning "The $Component in Bay $baynb is efusing!`n"

    pause
 
} until ( $componenttoefuse -eq "X" )

Disconnect-OVMgmt


