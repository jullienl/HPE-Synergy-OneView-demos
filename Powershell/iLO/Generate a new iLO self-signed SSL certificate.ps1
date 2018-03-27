<# 

Script to generates a new self-signed SSL certificate on iLO 4 firmware 2.55 (or later)

Using a REST command that was added in iLO 4 firmware 2.55 (or later) to generate the new self-signed certificate

This script does not require the iLO credentials

The latest HPOneView 400 library is required


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
MyImport-Module HPOneview.400 -update
#MyImport-Module PoshRSJob


# OneView Credentials and IP
$username = "Administrator" 
$password = "password" 
$IP = "composer.etss.lab" 

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

#Refreshing all Compute modules managed by OneVIew
Get-HPOVServer | Update-HPOVServer -Async | Out-Null

Write-host "`nRefreshing all Servers to detect iLO Self-Signed certificate issues, please wait..." -ForegroundColor Yellow

# Waiting for the refresh to end
Do {
$refreshstate = Get-HPOVServer | % refreshState | select -Unique
sleep 7
}
until (-not ($refreshstate | ? {$_ -eq "Refreshing"})  )

# Displaying a message if iLO certificate issue is found or not
If ($refreshstate | ? {$_ -eq "RefreshFailed"}  ) 
{
Write-host "`nSome iLO Self-Signed certificate issues has been found ! Generating new self-signed certificates, please wait..." -ForegroundColor Yellow
}
Else
{
Write-host "`nNo iLO Self-Signed certificate issue found !" -ForegroundColor Green
Read-Host -Prompt "`nOperation done ! Hit return to close" 
exit
}



#Capturing iLO IP adresses of servers managed by OneView that have a RefreshFailed status
$iloIPs = Get-HPOVServer | ? refreshState -Match "RefreshFailed" | where mpModel -eq iLO4 | % {$_.mpHostInfo.mpIpAddresses[-1].address }
# $iloIPs = Get-HPOVServer -Name "Frame3-CN7515049C, bay 12"  | % {$_.mpHostInfo.mpIpAddresses[-1].address }

#Capturing iLO IP adresses of servers managed by OneView that have a Warning status
#$iloIPs = Get-HPOVServer | ? status -Match "Critical" | where mpModel -eq iLO4 | % {$_.mpHostInfo.mpIpAddresses[1].address }


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



#Generating a new self-signed certificate

Foreach($iloIP in $iloIPs)
{
# Capture of the SSO Session Key

#[HPOneView.PKI.SslValidation]::EnableVerbose = $true
#[HPOneView.PKI.SslValidation]::EnableDebug = $true

 
$ilosessionkey = (Get-HPOVServer | where {$_.mpHostInfo.mpIpAddresses[-1].address -eq $iloIP} | Get-HPOVIloSso -IloRestSession)."X-Auth-Token"
 
# Creation of the header using the SSO Session Key 
$headerilo = @{} 
$headerilo["Accept"] = "application/json" 
$headerilo["X-Auth-Token"] = $ilosessionkey 

Try {

    $error.clear()

    # # Send the request to generate a now iLO Self-signed Certificate

    $rest = Invoke-WebRequest -Uri "https://$iloIP/redfish/v1/Managers/1/SecurityService/HttpsCert/" -Headers $headerilo  -Method Delete  -UseBasicParsing -ErrorAction Stop -Verbose
    
    if ($Error[0] -eq $Null) 

        { 
            write-host ""
            Write-Host "`nSelf-signed SSL certificate on iLo $iloIP has been regenerated. iLO is reseting..."}

        }

    
Catch [System.Net.WebException] 
 
    { 

    #Error returned if iLO FW is not supported
    $Error[0] | fl *
    pause
    exit
    
    }

}


sleep 120

#Importing the new iLO certificates

Foreach($iloIP in $iloIPs)
{
    Add-HPOVApplianceTrustedCertificate -ComputerName $iloIP
    write-host "`nThe new generated iLO Self-signed certificate of $iloIP has been imported in OneView"

}



Read-Host -Prompt "`nOperation done ! Hit return to close" 

