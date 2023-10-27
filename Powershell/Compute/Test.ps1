

# OneView Credentials and IP
$OV_username = "Administrator"
$OV_IP = "oneview.lj.lab"


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



if ($PSEdition -eq 'Core') {
    # $Script:PSDefaultParameterValues = @{
    #     "invoke-restmethod:SkipCertificateCheck" = $true
    #     "invoke-webrequest:SkipCertificateCheck" = $true
    # }


}
else {
    Add-Type @"
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
}



#################################################################################


$servers = Get-OVServer | Where-Object { $_.mpModel -eq "iLO6" }
# $servers = Get-OVServer | ? model -match "480 Gen10" | select -first 1


ForEach ($compute in $servers) {}


$compute | Get-OVIloSso -IloRestSession -SkipCertificateCheck -Verbose
    
    # Capture of the SSO Session Key
    $iloSessionkey = ($compute | Get-OVIloSso -IloRestSession -SkipCertificateCheck)."X-Auth-Token"
    $iloIP = $compute  | % { $_.mpHostInfo.mpIpAddresses[-1].address }
    $iloSessionkey 
    # $connection = Connect-HPEiLO -IP $iloIP -XAuthToken $iloSessionkey 
    
    # # To update a System ROM
    # $task = Update-HPEiLOFirmware -Connection $connection -Location $serverFWlocation -Force -Confirm:$False #-DisableCertificateAuthentication
       
    # # To update ilo FW :     
    # # $task = Update-HPEiLOFirmware -Connection $connection -Location $iloFWlocation -Force -Confirm:$False
  
    # Write-host -f Cyan ($task.IP) -NoNewline
    # Write-host " [" -NoNewline
    # Write-host -f Cyan ($task.hostname) -NoNewline
    # Write-host "]: Message returned by the update task: " -NoNewline
    # Write-host -f Cyan ($task.StatusInfo.Message) 

}
