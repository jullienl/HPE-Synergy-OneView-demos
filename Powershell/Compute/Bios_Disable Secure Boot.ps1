<# Script to disable Bios secure boot on HPE Gen9 and Gen10 server
#
# Requires the HPE Bios Cmdlets for Windows PowerShell (HPEBIOSCmdlets library), see https://www.hpe.com/us/en/product-catalog/detail/pip.5440657.html 
# 
# Servers must be restarted to disable Secure Boot. 
#
# This script only turns on servers that are powered-off to disable Secure Boot but it does not restart servers that are running. 
#
# Script requires the iLO credentials


  Author: lionel.jullien@hpe.com
  Date:   March 2018
    
#################################################################################
#                         Server FW Inventory in rows.ps1                       #
#                                                                               #
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


Function Import-ModuleAdv {
    
    # Import a module that can be imported
    # If it cannot, the module is installed
    # When -update parameter is used, the module is updated 
    # to the latest version available on the PowerShell library
    #
    # ex: import-moduleAdv hponeview.500
    
    param ( 
        $module, 
        [switch]$update 
    )
   
    if (get-module $module -ListAvailable) {

        if ($update.IsPresent) {
            
            [string]$InstalledModule = (Get-Module -Name $module -ListAvailable).version
            
            Try {
                [string]$RepoModule = (Find-Module -Name $module -ErrorAction Stop).version
            }
            Catch {
                Write-Warning "Error: No internet connection to update $module ! `
                `nCheck your network connection, you might need to configure a proxy if you are connected to a corporate network!"
                return 
            }

            #$Compare = Compare-Object $Moduleinstalled $ModuleonRepo -IncludeEqual

            #If ( ( $Compare.SideIndicator -eq '==') ) {
            
            If ( [System.Version]$InstalledModule -lt [System.Version]$RepoModule ) {
                Try {
                    # not using update-module as it keeps the old version of the module
                    #Remove existing version
                    Get-Module $Module -ListAvailable | Uninstall-Module 

                    #Install latest one from PSGallery
                    Install-Module -Name $Module
                }
                Catch {
                    write-warning "Error: $module cannot be updated !"
                    return
                }
           
            }
            Else {
                Write-host "You are using the latest version of $module !" 
            }
        }
            
        Import-module $module
            
    }


    Else {
        Write-host "$Module cannot be found, let's install it..." -ForegroundColor Cyan

        
        If ( !(get-PSRepository).name -eq "PSGallery" )
        { Register-PSRepository -Default }
                
        Try {
            find-module -Name $module -ErrorAction Stop | out-Null
                
            Try {
                Install-Module -Name $module -Scope AllUsers -Force -AllowClobber -ErrorAction Stop | Out-Null
                Write-host "`nInstalling $Module ..." 
                Import-module $module
               
            }
            catch {
                Write-Warning "$Module cannot be installed!" 
                $error[0] | FL * -force
                pause
                exit
            }

        }
        catch {
            write-warning "Error: $module cannot be found in the online PSGallery !"
            return
        }
            
    }

}

Import-ModuleAdv HPOneview.500 #-update

  

# MyImport-Module HPRESTCmdlets


# OneView Credentials and IP
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110" 

# iLO Credentials
$ilousername = "Administrator" 
$ilopassword = "password" 


#Loading HPEBIOSCmdlets module
Try {
    Import-Module HPEBIOSCmdlets -ErrorAction stop
}

Catch {
    Write-Host "`nHPEBIOSCmdlets module cannot be loaded"
    write-host "It is necessary to install the HPE Bios Cmdlets for Windows PowerShell (HPEBIOSCmdlets library)"
    write-host "See http://www.hpe.com/servers/powershell" 
    Write-Host "Exit..."
    exit
}


$InstalledBiosModule = Get-Module -Name "HPEBIOSCmdlets"
Write-Host "`nHPiLOCmdlets Module Version : $($InstalledBiosModule.Version) is installed on your machine."


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

#Connecting to the Synergy Composer

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-HPOVMgmt -Hostname $IP -Credential $credentials | Out-Null

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? { $_.name -eq $IP })



#Capturing iLO IP adresses managed by OneView
$iloIPs = Get-HPOVServer | where mpModel -eq iLO4 | % { $_.mpHostInfo.mpIpAddresses[1].address }


#Checking Secure Boot on all iLOst
Foreach ($iloIP in $iLOIPs) {
    Try { 
        $connection = Connect-HPEBIOS -IP $iloIP -Username $ilousername -Password $ilopassword -DisableCertificateAuthentication -ErrorAction Stop
    
        $sbs = get-HPEBIOSSecureBootState -Connection $connection  -ErrorAction Stop
        
        if ($sbs.SecureBootState -eq 'Enabled') {
            Try {
                Set-HPEBIOSSecureBootState -Connection $connection -SecureBootState Disabled -ErrorAction Stop
            }
            Catch {
                echo ($error[0] | FL)
                return
            }

            write-host "`nSecure Boot on iLO: $iloIP has been disabled" 

            $server = Get-HPOVServer | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } 
                       
            
            if ($server.powerState -eq "Off") { 
                write-host "`nStarting server: $($server.name) to enable the change..."

                Start-HPOVServer -Server $server | Wait-HPOVTaskComplete
            }
            else {
                write-host "`n $($server.name) is running. You need to restart the server to enable the change..." -ForegroundColor Yellow
  
            }

        }
        else {
            write-host "Secure Boot on iLO: $iloIP is already disabled" 
        }
   
    }
    Catch {
        write-host "Error disabling Secure boot on iLO: $iloIP"
        echo ($error[0] | fl)
    }

}

Disconnect-HPOVMgmt