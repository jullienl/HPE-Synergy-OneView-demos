<#
.DESCRIPTION
   Invoke-HPOVefuse efuses a component managed by HPE OneView, i.e. reset virtually (without physically reseting the server).
   An e-fuse reset causes the component to loose power momentarily as the e-fuse is tripped and reset.
   Supported components are : compute, interconnect, appliance and Frame Link Modules.
   A prompt requesting efuse confirmation is always provided.
 
   Supports common parameters -verbose, -whatif, and -confirm 
   
   OneView administrator account is required 
       
.PARAMETER composer
  IP address of the Composer
  Default: 192.168.1.110
  
.PARAMETER composerusername
  OneView administrator account of the Composer
  Default: Administrator
  
.PARAMETER composerpassword
  password of the OneView administrator account 
  Default: password

.PARAMETER compute
  The server hardware resource to efuse. This is normally retrieved with a 'Get-HPOVServer' call  
  Can also be the Server Hardware name, e.g. Frame2-CN7515049L, bay 4
  Accepts pipeline input ByValue and ByPropertyName 
  
.PARAMETER interconnect
  The interconnect hardware resource to efuse. This is normally retrieved with a 'Get-HPOVInterconnect' call  
  Can also be the Interconnect Hardware name, e.g. Frame1-CN7516060D, interconnect 3   

.PARAMETER appliance
  The serial number of the composable infrastructure appliance resource to efuse; e.g. UH53CP0509
  This is normally retrieved with a '(Get-HPOVEnclosure).applianceBays.serialnumber' call  
  
.PARAMETER FLM
  The serial number of the frame link module resource to efuse; e.g. CN7514V012
  This is normally retrieved with a '(Get-HPOVEnclosure).managerbays.serialnumber' call  

.EXAMPLE
  PS C:\> Invoke-HPOVefuse -composer 192.168.1.110 -composerusername Administrator -composerpassword password -compute "CN7515049C, bay 5" 
  Efuses the compute module in frame CN7515049C in bay 5 
  
.EXAMPLE
  PS C:\> Invoke-HPOVefuse -composer 192.168.1.110 -composerusername Administrator -composerpassword password -interconnect "CN7516060D, interconnect 3"
  Efuses the interconnect module in frame CN7516060D in interconnect bay 3 

.EXAMPLE
  PS C:\> Invoke-HPOVefuse -composer 192.168.1.110 -composerusername Administrator -composerpassword password -appliance "UH53CP0509"
  Efuses the composable infrastructure appliance with the serial number UH53CP0509

.EXAMPLE
  PS C:\> Invoke-HPOVefuse -composer 192.168.1.110 -composerusername Administrator -composerpassword password -FLM "CN7514V012"
  Efuses the frame link module with the serial number CN7514V012

.EXAMPLE
  PS C:\> Get-HPOVServer -NoProfile | ? {$_.name -match "Frame1"} | Invoke-HPOVefuse
  Efuses all servers without server profile in the frame whose name matches with "Frame1" and provides a prompt requesting efuse confirmation for each server

.EXAMPLE
  PS C:\> (Get-HPOVServer).portmap.deviceslots | ? {$_.slotnumber -eq 1 -and $_.devicename -eq "" } | Invoke-HPOVefuse
  Efuses all servers managed by OneView that have mezzanine slot 1 empty and provides a prompt requesting efuse confirmation for each server found
  
.COMPONENT
  This script makes use of the PowerShell language bindings library for HPE OneView
  https://github.com/HewlettPackard/POSH-HPOneView
  
.LINK
    https://github.com/HewlettPackard/POSH-HPOneView
  
.NOTES
    Author: lionel.jullien@hpe.com
    Date:   April 2017 
    
#################################################################################
#                             Invoke-HPOVeFuse.ps1                                 #
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
Function Invoke-HPOVefuse {

[CmdletBinding( DefaultParameterSetName=’Compute’, 
                SupportsShouldProcess=$True,
                ConfirmImpact='High'
               )]
    Param 
    (
        [parameter(ParameterSetName="Compute")]
        [parameter(ParameterSetName="Interconnect")]
        [parameter(ParameterSetName="Appliance")]
        [parameter(ParameterSetName="FLM")]
        [string]$composer = "192.168.1.110", 

        [parameter(ParameterSetName="Compute")]
        [parameter(ParameterSetName="Interconnect")]
        [parameter(ParameterSetName="Appliance")]
        [parameter(ParameterSetName="FLM")]
        [string]$composerusername = "Administrator", 

        [parameter(ParameterSetName="Compute")]
        [parameter(ParameterSetName="Interconnect")]
        [parameter(ParameterSetName="Appliance")]
        [parameter(ParameterSetName="FLM")]
        [string]$composerpassword = "password",

        [parameter(Mandatory=$true, Valuefrompipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="Compute")]
        [Alias('name')]
        [Object]$compute,
    
        [parameter(Mandatory=$true, ParameterSetName="Interconnect")]
        [string]$interconnect,

        [parameter(Mandatory=$true, ParameterSetName="Appliance")]
        [string]$appliance,

        [parameter(Mandatory=$true, ParameterSetName="FLM")]
        [string]$FLM
            
    )

Begin
{

#region Global Variables
   
[string]$HPOVMinimumVersion = "3.0.1264.2772"

#endregion


#region Functions
Function Get-HPOVTaskError ($Taskresult)
{
        if ($Taskresult.TaskState -eq "Error")
        {
            $ErrorCode     = $Taskresult.TaskErrors.errorCode
            $ErrorMessage  = $Taskresult.TaskErrors.Message
            $TaskStatus    = $Taskresult.TaskStatus

            write-host -foreground Yellow $TaskStatus
            write-host -foreground Yellow "Error Code --> $ErrorCode"
            write-host -foreground Yellow "Error Message --> $ErrorMessage"
        
           # To be used like:
           #   $result = Wait-HPOVTaskComplete $taskNetwork.Details.uri
           #   Get-HPOVTaskError -Taskresult $result
        
        
        }
}

function Check-HPOVVersion {
    #Check HPOV version
    #Encourge people to run the latest version
    $arrMinVersion = $HPOVMinimumVersion.split(".")
    $arrHPOVVersion=((Get-HPOVVersion ).LibraryVersion)
    if ( ($arrHPOVVersion.Major -gt $arrMinVersion[0]) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -gt $arrMinVersion[1])) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -eq $arrMinVersion[1]) -and ($arrHPOVVersion.Build -gt $arrMinVersion[2])) -or
        (($arrHPOVVersion.Major -eq $arrMinVersion[0]) -and ($arrHPOVVersion.Minor -eq $arrMinVersion[1]) -and ($arrHPOVVersion.Build -eq $arrMinVersion[2]) -and ($arrHPOVVersion.Revision -ge $arrMinVersion[3])) )
        {
        #HPOVVersion the same or newer than the minimum required
        }
    else {
        Write-Error "You are running a version of POSH-HPOneView that do not support this script. Please update your HPOneView POSH from: https://github.com/HewlettPackard/POSH-HPOneView/releases"
        
        exit
        }
    }
#endregion


#region Import the OneView 3.10 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    if (-not (get-module HPOneview.310)) 
    {  
    Import-module HPOneview.310
    }
#endregion


#region Check oneview version

Check-HPOVVersion
#endregion
      
       
#region Connection to the Synergy Composer

    if ((test-path Variable:ConnectedSessions) -and ($ConnectedSessions.Count -gt 1)) {
        Write-Host -ForegroundColor red "`n`tDisconnect all existing HPOV / Composer sessions and before running script"
        pause 
        exit 1
        }
    elseif ((test-path Variable:ConnectedSessions) -and ($ConnectedSessions.Count -eq 1) -and ($ConnectedSessions[0].Default) -and ($ConnectedSessions[0].Name -eq $IP)) {
        Write-Host -ForegroundColor gray "`n`tReusing Existing Composer session"
        }
    else {
        #Make a clean connection
        Disconnect-HPOVMgmt -ErrorAction SilentlyContinue
        $Appplianceconnection = Connect-HPOVMgmt -appliance $composer -UserName $composerusername -Password $composerpassword
        }

                
                
    import-HPOVSSLCertificate
#endregion

}


Process
{

#region Creation of the header

    $postParams = @{userName=$username;password=$password} | ConvertTo-Json 
    $headers = @{} 
    #$headers["Accept"] = "application/json" 
    $headers["X-API-Version"] = "300"

    # Capturing the OneView Session ID and adding it to the header
    
    $key = $ConnectedSessions[0].SessionID 

    $headers["auth"] = $key
#endregion

<# eFusing component
     Get-HPOVServer | ? {$_.name -match "Frame2"} | Invoke-HPOVefuse -whatif
     $compute = "Frame3-CN7515049C, bay 5"
     $compute = Get-HPOVServer | select -First 1
     $compute = Get-HPOVServer | ? {$_.name -match "Frame2"} 
     #>

#region Preparation for efusing Compute            
 if ($compute)  

 {    
    Foreach ($singlecompute in $compute)
    {

        switch($singlecompute.GetType().Name)
        {
            'String'

            {          
                Write-Verbose "`$Compute is a string"
                $baynb = (Get-HPOVServer | where {$_.name -eq $singlecompute} | % {$_.position })
                $body = '[{"op":"replace","path":"/deviceBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]' 
                $frameUri = (Get-HPOVServer | where {$_.name -eq $singlecompute}).locationUri 
                $frame = (Get-HPOVEnclosure | where {$_.uri -eq $frameuri}).name
                            
            }

            'PSCustomObject'

            {
                Write-Verbose "`$Compute is a PSCustomObject"
                $singlecompute = $singlecompute.name
                $baynb = (Get-HPOVServer | where {$_.name -eq $singlecompute} | % {$_.position })
                $body = '[{"op":"replace","path":"/deviceBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]' 
                $frameUri = (Get-HPOVServer | where {$_.name -eq $singlecompute}).locationUri 
                $frame = (Get-HPOVEnclosure | where {$_.uri -eq $frameuri}).name
                
            } 

        }
        
        $ressource = $singlecompute
        $component = "compute"
        write-verbose "`$singlecompute = $singlecompute"
        write-verbose "`$baynb = $baynb"
        write-verbose "`$frame = $frame"
        
        if ($pscmdlet.ShouldProcess($frame,"eFusing the $component $ressource"))  
        {   
            Try
            {
                Write-verbose "
                    REST request destination:    https://$composer$frameUri 
                    Header:                      $headers 
                    Body:                        $body"
        
                $efusecomponent = Invoke-WebRequest -Uri "https://$composer$frameUri" -ContentType "application/json" -Headers $headers -Method PATCH -UseBasicParsing -Body $body -ErrorAction Stop
                sleep 15
                Write-host -ForegroundColor Cyan "`n`tThe $component in Frame $frame in Bay $baynb is efusing!"
             }
                
             catch [System.Net.WebException]
                
             {
                write-warning "`tThe component $ressource cannot be found ! "
             }
        
        }
        
    }
#endregion
}

#region Preparation for efusing Interconnect
 else
 {

    if ($PSboundParameters['interconnect'])

    {   $baynb = ((Get-HPOVInterconnect | where {$_.name -eq $interconnect} | % {$_.interconnectLocation }).locationEntries | where {$_.type -eq "Bay"}).value

        if ($baynb -eq $Null) 
            { 
            write-warning  "`tThe interconnect $interconnect cannot be found ! " 
            return
            }
        
        $body = '[{"op":"replace","path":"/interconnectBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]'  
        $frameUri = (Get-HPOVInterconnect | where {$_.name -eq $interconnect}).enclosureUri 
        $frame = (Get-HPOVEnclosure | where {$_.uri -eq $frameuri}).name 
        $component = "interconnect"
        $ressource = $interconnect
}
#endregion

#region Preparation for efusing Appliance
    if ($PSboundParameters['appliance'])
  
    {   # $appliance = "CN751704ZD"
        $baynb = ((Get-HPOVEnclosure).applianceBays | where  {$_.serialNumber -Match $appliance}).bayNumber

        if ($baynb -eq $Null) 
            { 
            write-warning  "`tThe appliance $appliance cannot be found ! " 
            return
            }

        $body = '[{"op":"replace","path":"/applianceBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]' 
        $frameUri = (Get-HPOVEnclosure | where  {$_.applianceBays.serialNumber -Match $appliance}).uri
        $frame = (Get-HPOVEnclosure | where  {$_.applianceBays.serialNumber -Match $appliance}).name
        $component = "appliance"
        $ressource = $appliance
    }
#endregion

#region Preparation for efusing FLM
    if ($PSboundParameters['FLM'])  

    {   # $FLM = "CN7514V012"
    $baynb = ((Get-HPOVEnclosure).managerbays | where  {$_.serialNumber -Match $FLM}).bayNumber

    if ($baynb -eq $Null) 
        { 
        write-warning  "`tThe FLM $FLM cannot be found ! " 
        return
        }

    $body = '[{"op":"replace","path":"/managerBays/' + $baynb + '/bayPowerState","value":"E-Fuse"}]'   
    $frameUri = ((Get-HPOVEnclosure) | where  {$_.managerbays.serialNumber -Match $FLM}).uri
    $frame = ((Get-HPOVEnclosure) | where  {$_.managerbays.serialNumber -Match $FLM}).name
    $component = "FLM"
    $ressource = $FLM
}
#endregion

    write-verbose "`$baynb = $baynb"
    write-verbose "`$frame = $frame"
    Write-verbose "   REST request destination:    https://$composer$frameUri 
            Body:                        $body"

#region efusing Component
    if ($pscmdlet.ShouldProcess($frame,"eFusing the $component $ressource"))   
    {   
        Try
            {
            $efusecomponent = Invoke-WebRequest -Uri "https://$composer$frameUri" -ContentType "application/json" -Headers $headers -Method PATCH -UseBasicParsing -Body $body -ErrorAction Stop
            sleep 15
            Write-host -ForegroundColor Cyan "`n`tThe $component in Frame $frame in Bay $baynb is efusing!"
            }
        
        catch [System.Net.WebException]
            {
            write-warning "`tThe component $ressource cannot be found ! "
            }
    } 
}
#endregion

}


End
{

#region Clean up
# Disconnect-HPOVMgmt
#endregion

}

}

