
#IP address of OneView
$DefaultIP = "192.168.1.110" 
#Clear
$IP = Read-Host "Please enter the IP address of your OneView appliance [$($DefaultIP)]" 
$IP = ($DefaultIP,$IP)[[bool]$IP]

# OneView Credentials
$username = "Administrator" 
$defaultpassword = "password" 
$password = Read-Host "Please enter the Administrator password for OneView [$($Defaultpassword)]"
$password = ($Defaultpassword,$password)[[bool]$password]


# Import the OneView 3.0 library

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    if (-not (get-module HPOneview.300)) 
    {  
    Import-module HPOneview.300
    }

   
   
$PWord = ConvertTo-SecureString –String $password –AsPlainText -Force
$cred = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $Username, $PWord


    # Connection to the Synergy Composer
    if ((test-path Variable:ConnectedSessions) -and ($ConnectedSessions.Count -gt 1)) {
        Write-Host -ForegroundColor red "Disconnect all existing HPOV / Composer sessions and before running script"
        exit 1
        }
    elseif ((test-path Variable:ConnectedSessions) -and ($ConnectedSessions.Count -eq 1) -and ($ConnectedSessions[0].Default) -and ($ConnectedSessions[0].Name -eq $IP)) {
        Write-Host -ForegroundColor gray "Reusing Existing Composer session"
        }
    else {
        #Make a clean connection
        Disconnect-HPOVMgmt -ErrorAction SilentlyContinue
        $Appplianceconnection = Connect-HPOVMgmt -appliance $IP -PSCredential $cred
        }

                
import-HPOVSSLCertificate



Do {
    #clear
    
    If (get-hpovserverprofile) 
    {
        Write-host ""
        Write-host "The following profiles are available:"
        (Get-HPOVServerProfile).name
        Write-host ""
        $profile = Read-Host "Please enter the profile ressource you want to analyse"
     }
    
    

$profileuri = (Get-HPOVServerProfile  | ? {$_.name -eq $profile}).uri

$node = Get-HPOVServer | ? {$_.serverProfileUri -eq $profileuri }

$URI = $node.uri
$NAME = $node.Name
$temp = $URI + "/utilization?fields=AmbientTemperature"

$Resulttemp = Send-HPOVRequest $temp

$CurrentSampletemp = $Resulttemp.metricList.metricSamples
$SampleTimetemp = $Resulttemp.newestSampleTime
$LastTempValue = echo $CurrentSampletemp[0][1]

Write-host ""

write-host -ForegroundColor Cyan "Sample Time              | Name                     | Temp Reading "

write "$SampleTimetemp | $Name | Temp Reading: $LastTempValue"

$cpu = $URI + "/utilization?fields=CpuAverageFreq"
$Resultcpu = Send-HPOVRequest $cpu
$CurrentSamplecpu = $Resultcpu.metricList.metricSamples
$SampleTimecpu = $Resultcpu.newestSampleTime
$LastcpuValue = echo $CurrentSamplecpu[0][1]

write "$SampleTimecpu | $Name | CPU Average Reading: $LastcpuValue"

$cpuu = $URI + "/utilization?fields=CpuUtilization"
$Resultcpuu = Send-HPOVRequest $cpuu
$CurrentSamplecpuu = $Resultcpuu.metricList.metricSamples
$SampleTimecpuu = $Resultcpuu.newestSampleTime
$LastcpuuValue = echo $CurrentSamplecpuu[0][1]

write "$SampleTimecpuu | $Name | CPU Utilization Reading: $LastcpuuValue"

$AveragePower = $URI + "/utilization?fields=AveragePower"
$ResultAveragePower = Send-HPOVRequest $AveragePower
$CurrentSampleAveragePower = $ResultAveragePower.metricList.metricSamples
$SampleTimeAveragePower = $ResultAveragePower.newestSampleTime
$LastAveragePowerValue = echo $CurrentSampleAveragePower[0][1]

write "$SampleTimeAveragePower | $Name | Average Power Reading: $LastAveragePowerValue"
Write-host ""

pause
clear

do {

        write-host ""
        write-host ""
        write-host "Do you want to analyse another compute module?"
        write-host "1 - Yes"
        write-host "2 - No"
        write-host ""
        write-host -nonewline "Type your choice and press Enter (1 or 2): "
        
        $deletemore = read-host
        
        write-host ""
        
        $ok = $deletemore -match '^[12]+$'
        
        if ( -not $ok) { write-host "Invalid selection"
        write-host ""}
   
        } until ( $ok )


}
until ( $deletemore -eq "2" )
