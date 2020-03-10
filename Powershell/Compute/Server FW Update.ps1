   
# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# Feb 2019
#
# Upgrade all Server System FW managed by the OneView Composer using iLO local account so it is required to first use the 'Add User to iLO'
# script or 'Change iLO Admin password available here: https://github.com/jullienl/HPE-Synergy-OneView-demos/tree/master/Powershell/iLO
#
# OneView administrator account is required - HPE iLO PowerShell Cmdlets will be installed (HPiLOCmdlets) if not present 
# 
# --------------------------------------------------------------------------------------------------------

   
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


#Global variables

#IP address of OneView
$IP = "192.168.1.110" 

#OneView Credentials
$username = "Administrator" 
$password = "password" 

#iLO Credentials
$ilousername = "Administrator" 
$ilopassword = "password" 

#location of FW package
#Locate and download the server firmware package from google, search for:  [  server model "Online ROM Flash Component for Windows x64" ]
#Execute the downloaded firmware package CPxxxxxx.exe and extract the package to a local folder.
#Supported image extensions are the following: 
# - ROM: .full or .flash 
# - CPLD: .vme 
# - PowerPIC: .hex

#$serverFWlocation = "D:\Kits\_Scripts\_PowerShell\Compute\I37_2.64_10_17_2018.signed.flash"
$serverFWlocation = "D:\Kits\_Scripts\_PowerShell\Compute\I42_1.46_10_05_2018.signed.flash"
# $iloFWlocation = "D:\Kits\_Scripts\_PowerShell\Compute\ilo4_261.bin"



# Import the OneView 4.10 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -Confirm:$false 


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
Import-ModuleAdv HPiLOCmdlets # -update

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

#Connecting to the Synergy Composer

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-HPOVMgmt -Hostname $IP -Credential $credentials | Out-Null

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ? { $_.name -eq $IP })

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


$servers = Get-HPOVServer | ? model -match "480 Gen10"

#$servers = Get-HPOVServer | select -first 1


$iLOserverIPs = $servers | % { $_.mpHostInfo.mpIpaddresses[1].address } # | select -first 1 
    
$iLOserverIPs | Update-HPiLOServerFirmware -Username $ilousername -Password $ilopassword -Location $serverFWlocation #-DisableCertificateAuthentication
    
# To update ilo FW :     
#$iLOserverIPs  | Update-HPiLOFirmware -Username $ilousername -Password $ilopassword -Location $serverFWlocation #-DisableCertificateAuthentication
   
# To manually upadate an iLO, use its IP address like:
# "192.168.1.203" | Update-HPiLOServerFirmware -Username $ilousername -Password $ilopassword -Location $iloFWlocation
      
   
Write-Host "`nThe following"$iLOserverIPs.Count"server System ROM have been updated:`n"
$iLOserverIPs  
    
Disconnect-HPOVMgmt









