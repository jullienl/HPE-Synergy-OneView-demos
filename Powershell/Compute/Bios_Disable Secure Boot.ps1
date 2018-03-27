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

            If (-not ($Compare.SideIndicator -eq '=='))
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
            }
        }

}

MyImport-Module PowerShellGet
MyImport-Module FormatPX
MyImport-Module SnippetPX
MyImport-Module HPOneview.400 #-update

# MyImport-Module HPRESTCmdlets


# OneView Credentials and IP
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110" 

# iLO Credentials
$ilousername = "Administrator" 
$ilopassword = "password" 


#Loading HPEBIOSCmdlets module
Try
{
    Import-Module HPEBIOSCmdlets -ErrorAction stop
}

Catch 

{
    Write-Host "`nHPEBIOSCmdlets module cannot be loaded"
    write-host "It is necessary to install the HPE Bios Cmdlets for Windows PowerShell (HPEBIOSCmdlets library)"
    write-host "See http://www.hpe.com/servers/powershell" 
    Write-Host "Exit..."
    exit
    }


$InstalledBiosModule  =  Get-Module -Name "HPEBIOSCmdlets"
Write-Host "`nHPiLOCmdlets Module Version : $($InstalledBiosModule.Version) is installed on your machine."


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

#Connecting to the Synergy Composer

if ($connectedSessions -and ($connectedSessions | ?{$_.name -eq $IP}))
{
    Write-Verbose "Already connected to $IP."
}

else
{
    Try 
    {
        Connect-HPOVMgmt -appliance $IP -UserName $username -Password $password | Out-Null
    }
    Catch 
    {
        throw $_
    }
}

               
import-HPOVSSLCertificate -ApplianceConnection ($connectedSessions | ?{$_.name -eq $IP})



#Capturing iLO IP adresses managed by OneView
$iloIPs = Get-HPOVServer |  where mpModel -eq iLO4 | % {$_.mpHostInfo.mpIpAddresses[1].address }


#Checking Secure Boot on all iLOst
Foreach ($iloIP in $iLOIPs)
{
   Try 
   { 
        $connection = Connect-HPEBIOS -IP $iloIP -Username $ilousername -Password $ilopassword -DisableCertificateAuthentication -ErrorAction Stop
    
        $sbs = get-HPEBIOSSecureBootState -Connection $connection  -ErrorAction Stop
        
        if ($sbs.SecureBootState -eq 'Enabled') 
        {
            Try {
                Set-HPEBIOSSecureBootState -Connection $connection -SecureBootState Disabled -ErrorAction Stop
                }
            Catch
                {
                echo ($error[0] | FL)
                return
                }

            write-host "`nSecure Boot on iLO: $iloIP has been disabled" 

            $server = Get-HPOVServer  |  where {$_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP} 
                       
            
            if ($server.powerState -eq "Off")
            { 
                    write-host "`nStarting server: $($server.name) to enable the change..."

                    Start-HPOVServer -Server $server  | Wait-HPOVTaskComplete
            }
            else
            {
                   write-host "`n $($server.name) is running. You need to restart the server to enable the change..." -ForegroundColor Yellow
  
            }

        }
        else
        {
            write-host "Secure Boot on iLO: $iloIP is already disabled" 
        }
   
    }
   Catch
   {
        write-host "Error disabling Secure boot on iLO: $iloIP"
        echo ($error[0] | fl)
   }

}

