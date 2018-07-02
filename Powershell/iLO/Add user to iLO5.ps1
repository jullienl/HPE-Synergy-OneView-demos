# -------------------------------------------------------------------------------------------------------
# by lionel.jullien@hpe.com
# June 2018
#
# Create a User account in iLO5 managed by OneView without using the iLO Administrator local account
#
# OneView administrator account is required. 
# iLO modification is done through OneView and iLO SSOsession key using REST POST method
# --------------------------------------------------------------------------------------------------------

#################################################################################
#        (C) Copyright 2018 Hewlett Packard Enterprise Development LP           #
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


# OneView Credentials and IP
$username = "Administrator" 
$password = "Legacy2018" 
$IP = "16.107.20.29"


# iLO5 User/password to create 
$newiLOLoginName = "Ilouser"
$newiLOPassword = "Ilouser1!"


Function MyImport-Module {
    
    # Import a module that can be imported
    # If it cannot, the module is installed
    # When -update parameter is used, the module is updated 
    # to the latest version available on the PowerShell library
    
    # $module = "HPOneview.400"

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
                Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
                Update-Module -Name $module -confirm:$false | Out-Null
           
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
                Import-Module $module

            }
        Catch
            {
                Write-Warning "$Module cannot be installed" 
                $error[0] | FL * -force
            }
        }

}

 
# Modules to import

MyImport-Module HPOneview.400 #-update
#MyImport-Module HPESmartArrayCmdlets
#MyImport-Module HPERedfishCmdlets
    

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

add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
   
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    
# Capture iLO5 IP adresses managed by OneView
$iloIPs = Get-HPOVServer | where mpModel -eq iLO5 | % {$_.mpHostInfo.mpIpAddresses[1].address }

clear
write-host "`n $($iloIPs.count) x iLO5 found" -f Green
write-host "`nAddress(es): $iloIPs"


# creating iLO user object
    
    # add permissions
    $priv = @{}
    $priv.Add('RemoteConsolePriv',$True)
    $priv.Add('iLOConfigPriv',$True)
    $priv.Add('VirtualMediaPriv',$True)
    $priv.Add('UserConfigPriv',$True)
    $priv.Add('VirtualPowerAndResetPriv',$True)
    $priv.Add('HostBIOSConfigPriv',$True)
    $priv.Add('HostNICConfigPriv',$True)
    $priv.Add('HostStorageConfigPriv',$True)
    
    # add login name
    $hp = @{}
    $hp.Add('LoginName',$newiLOLoginName)
    $hp.Add('Privileges',$priv)
    
    $oem = @{}
    
    # for iLO 5
    $oem.Add('Hpe',$hp)
    
    ## for iLO 4
    #$oem.Add('Hp',$hp)

    # add username and password for access
    $user = @{}
    $user.Add('UserName',$newiLOLoginName)
    $user.Add('Password',$newiLOPassword)
    $user.Add('Oem',$oem)


$bodyiloParams = $user | ConvertTo-Json -Depth 99


#Creation of the user account using the iLO user object
# $iloIP = $iloIPs

Foreach($iloIP in $iloIPs)
{
    # Capture of the SSO Session Key
 
    $ilosessionkey = (Get-HPOVServer | where {$_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP} | Get-HPOVIloSso -IloRestSession)."X-Auth-Token"
 
    # Creation of the header using the SSO Session Key 

    $headerilo = @{} 
    $headerilo["Accept"] = "application/json" 
    $headerilo["OData-Version"] = "4"
    $headerilo["X-Auth-Token"] = $ilosessionkey 


    Try {

        $error.clear()
        $users = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/" -Headers $headerilo -Method GET -UseBasicParsing 

        # Finding all present users 

        $usersarray = $users.Content | ConvertFrom-Json 

        # If user to create is found in user list, flag is raised
        $foundFlag = $False

        foreach($accOdataId in $usersarray.Members.'@odata.id')  {

            $id = $accOdataId.Substring(36)
            $acc = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/$id" -Headers $headerilo -Method GET -UseBasicParsing 
            $accarray = $acc.Content | ConvertFrom-Json 

            # $accarray.Username | Out-Host
           
            if($accarray.Username -eq $newiLOLoginName) {
                $foundFlag = $true
                # Write-Host "$newiLOLoginName found!" -f Green
            }
        }

       # User account created if not present

        if ($foundFlag -ne $True)  {

            write-host ""
            write-host "User [$newiLOLoginName] does not exist in iLO [$iloIP] and will be created !"

            $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/AccountService/Accounts/" -Body $bodyiloParams  -Headers $headerilo -ContentType "application/json" -Method POST -UseBasicParsing
                
            write-host ""
            Write-Host "[$newiLOLoginName] has been created successfuly in iLo: $iloIP" -ForegroundColor Green
        }
        
        # User account not created if already present
        
        else {

            write-host ""
            write-warning "User [$newiLOLoginName] already exists in iLO : $iloIP !"

        }
    }


    catch [System.Net.WebException] {    
        
        write-host ""
        Write-Warning "Error ! [$newiLOLoginName] has not been added !" 
    }   

 
}


write-host ""
Read-Host -Prompt "Operation done ! Hit return to close" 
