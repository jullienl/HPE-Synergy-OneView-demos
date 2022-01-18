<# 

This is a PowerShell script to eFuse a component (compute, appliance, interconnect or flm) in HPE Synergy frames

Script supporting up to 5 frames. 

Requirements: 
- HPE OneView administrator account.


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

$numberofframes = @(Get-OVEnclosure).count
$frames = Get-OVEnclosure | % { $_.name }
    
#clear
#Which enclosure you want to eFuse a component?

if ($numberofframes -gt 0) {
    $interconnects = Get-OVInterconnect     
    $whosframe1 = $interconnects | where { $_.model -match "Virtual Connect" -and $_.name -match "interconnect 3" } | % { $_.enclosurename }
}

if ($numberofframes -gt 1) {
    $whosframe2 = $interconnects | where { $_.model -match "Virtual Connect" -and $_.name -match "interconnect 6" } | % { $_.enclosurename }
}

if ($numberofframes -gt 2) {
    $frameswithsatellites = $interconnects | where -Property Model -match "Interconnect Link Module" 
    $whosframe3 = $frameswithsatellites | group-object -Property enclosurename | ? { $_.Count -gt 1 } | select -first 1 | % { $_.name }  
}

if ($numberofframes -gt 3) { 
    $frameswithsatellites = $interconnects | where -Property Model -match "Interconnect Link Module" 
    $whosframe4 = $frameswithsatellites | group-object -Property enclosurename | ? { $_.Count -gt 1 } | select -Skip 1 | select -first 1 | % { $_.name }  

}

if ($numberofframes -gt 4) { 
    $frameswithsatellites = $interconnects | where -Property Model -match "Interconnect Link Module" 
    $whosframe5 = $frameswithsatellites | group-object -Property enclosurename | ? { $_.Count -gt 1 } | select -Skip 2 | select -first 1 | % { $_.name }  

}


do {    
   
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
        write-host -nonewline "Type your choice (1, 2, ... or 5) and press Enter: "
        
        $choice = read-host
        
        write-host ""
        
        $ok = $choice -match '^[12345x]+$'
        
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
        "1" {
            $frame = $whosframe1
        }
        
        "2" {
            $frame = $whosframe2
        }

        "3" {
            $frame = $whosframe3
        }

        "4" {
            $frame = $whosframe4
        }

        "5" {
            $frame = $whosframe5
        }

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


