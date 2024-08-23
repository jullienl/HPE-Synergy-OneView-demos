Function Get-HPEiLOProxy {
    <#
    .SYNOPSIS
    Retrieves or modifies HPE iLO proxy settings.

    .DESCRIPTION
    This function allows users to gather, set, or remove information related to HPE iLO (Integrated Lights-Out) proxy settings. 
    
    The content of the input CSV file should be in the following format:

    ```
    IP
    192.168.0.20
    192.168.0.21
    192.168.0.22
    ```

    .PARAMETER IloIP  
    Specifies the iLO IP or hostname of the device.

    .PARAMETER SetiLOProxy
    Enables setting the iLO proxy settings.

    .PARAMETER IloCredential  
    PSCredential object comprising a username associated with the iLO of the device and the corresponding password.
 
    .PARAMETER IloProxyServer  
    Specifies the hostname or IP address of the web proxy server.
  
    .PARAMETER IloProxyPort 
    Specifies the iLO web proxy port number. Valid port values range from 1–65535.
  
    .PARAMETER IloProxyUserName 
    Username for the iLO web proxy (if any).
  
    .PARAMETER IloProxyPassword  
    Password for the iLO web proxy (if any) as a SecureString.

    .PARAMETER RemoveProxySettings  
    Switch parameter to remove the iLO proxy settings (if any).
    
    .EXAMPLE
    # Create PSCredential object
    $iLO_userName = "demopaq"
    $EncryptedPassword = "01000000d08c9ddf9432b32a730af3b80567e2378c570b3a111d627d70ac9eb6f281...."
    $secpasswd = ConvertTo-SecureString $EncryptedPassword
    $credentials = New-Object System.Management.Automation.PSCredential ($iLO_userName, $secpasswd)

    Get-HPEiLOProxy -IloIP 192.168.0.20 -iLOCredential $credentials 
    
    Retrieve iLO proxy information.

    .EXAMPLE
    "192.168.0.20", "192.168.0.21" | Get-HPEiLOProxy -iLOCredential $credentials 
    
    Pass an array of iLO IP addresses directly and retrieve iLO proxy information.
    
    .EXAMPLE
    Import-Csv -Path Z:\Scripts\_PowerShell\iLO\iLO-IPs.csv | Get-HPEiLOProxy -iLOCredential $credentials 
    
    Import iLO IP addresses from a CSV file and retrieve iLO proxy information.
    
    .EXAMPLE
    Get-HPEiLOProxy -IloIP 192.168.0.21 -iLOCredential $credentials -SetiLOProxy -IloProxyServer web.proxy.com -IloProxyPort 8088 
    
    Set iLO proxy settings for a specific IP with specific proxy server and port.

    .EXAMPLE
    Import-Csv -Path Z:\Scripts\_PowerShell\iLO\iLO-IPs.csv | Get-HPEiLOProxy -iLOCredential $credentials -SetiLOProxy -IloProxyServer web.proxy.com -IloProxyPort 8088 
    
    Import iLO IPs from a CSV, then set iLO proxy settings for all with specific proxy server and port.

    .EXAMPLE
    $iLO_secureString_Proxy_Password = Read-Host -Prompt "Enter the proxy password" -AsSecureString
    "192.168.0.20", "192.168.0.21", "192.168.6.2" | Get-HPEiLOProxy -iLOCredential $credentials -SetiLOProxy -IloProxyServer web.proxy.com -IloProxyPort 8088 -IloProxyUserName admin -IloProxyPassword $iLO_secureString_Proxy_Password
    
    Set iLO proxy settings including proxy username and password.

    .EXAMPLE
    Import-Csv -Path Z:\Scripts\_PowerShell\iLO\iLO-IPs.csv | Get-HPEiLOProxy -iLOCredential $credentials -SetiLOProxy -IloProxyServer web.proxy.com -IloProxyPort 8088 -IloProxyUserName admin -IloProxyPassword $iLO_secureString_Proxy_Password
    
    Import iLO IPs from a CSV, then set iLO proxy settings for all including proxy username and password.

    .EXAMPLE
    Import-Csv -Path Z:\Scripts\_PowerShell\iLO\iLO-IPs.csv | Get-HPEiLOProxy -iLOCredential $credentials -RemoveProxySettings
    
    Remove proxy settings for iLOs imported from a CSV file.

    .EXAMPLE
    "192.168.0.20", "192.168.0.21", "192.168.6.2" | Get-HPEiLOProxy -iLOCredential $credentials -RemoveProxySettings
    
    Remove proxy settings for a list of IP addresses.

    .INPUTS
    System.Collections.ArrayList
        List of iLO IP addresses.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing:
        * `iLO` - iLO IP address 
        * `Status` - Status of the iLO Proxy configuration attempt (e.g., Failed for HTTP error return; Complete if successful)
        * `Details` - More information about the iLO Proxy configuration status
        * `Exception` - Details about any exceptions encountered during operation.
    #>


    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "Default")]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "SetiLOProxy")]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "RemoveProxySettings")]
        [ValidateScript({ [String]::IsNullOrEmpty($_) -or
                $_ -match [Net.IPAddress]$_ })]
        [Alias ('IP')]
        [IPAddress]$IloIP,
  
        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "SetiLOProxy")]
        [Parameter (Mandatory, ParameterSetName = "RemoveProxySettings")]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$iLOCredential,

        [Parameter (Mandatory, ParameterSetName = "SetiLOProxy")]
        [switch]$SetiLOProxy,

        [Parameter (Mandatory, ParameterSetName = "SetiLOProxy")]
        [String]$IloProxyServer,

        [Parameter (Mandatory, ParameterSetName = "SetiLOProxy")]
        [Int]$IloProxyPort,
  
        [Parameter (ParameterSetName = "SetiLOProxy")]
        [String]$IloProxyUserName,
  
        [Parameter (ParameterSetName = "SetiLOProxy")]
        [ValidateNotNullOrEmpty()]
        [System.Security.SecureString]$IloProxyPassword,

        [Parameter (Mandatory, ParameterSetName = "RemoveProxySettings")]
        [Switch]$RemoveProxySettings
  
    ) 

    Begin {

        $iLOConfigurationStatus = [System.Collections.ArrayList]::new()

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    
    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($SetiLOProxy -or $RemoveProxySettings) {
            
            # Create object for the output
            $objStatus = [pscustomobject]@{
      
                iLO       = $IloIP
                Status    = $Null
                Details   = $Null
                Exception = $Null
            }
        }


        # Test if iLO pingable

        $Test = (New-Object System.Net.NetworkInformation.Ping).Send($IloIP, 4000) 

        "[{0}] PING test result: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $test.status | Write-Verbose


        if (-not $SetiLOProxy -and -not $RemoveProxySettings -and $Test.Status -ne "Success") {
            Write-Warning "Error! iLO '$iloIP' cannot be contacted!"
            Return 
        }
       
        elseif (($SetiLOProxy -or $RemoveProxySettings) -and $Test.Status -ne "Success") {
            # Must return a message if device is not found
            $objStatus.Status = "Warning"
            $objStatus.Details = "iLO cannot be contacted!"
            [void] $iLOConfigurationStatus.add($objStatus)
            return
            
        }
       
        else {       

            # Connection to iLO
  
            If ( ($PSVersionTable.PSVersion.ToString()).Split('.')[0] -eq 5) {

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

            }


            $iLOBaseURL = "https://$IloIP"
                
            $AddURI = "/redfish/v1/SessionService/Sessions/"
                
            $url = $iLOBaseURL + $AddURI

            $IloUsername = $iLOCredential.UserName
            $IlodecryptPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($iLOCredential.Password))
                
            $Body = [System.Collections.Hashtable]@{
                UserName = $IloUserName
                Password = $IlodecryptPassword
            } | ConvertTo-Json 
                
            # Create iLO session     
            "[{0}] '{1}' -- Attempting an iLO session creation!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP  | Write-Verbose
            "[{0}] '{1}' -- Method: POST - URI: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $url | Write-Verbose
            "[{0}] '{1}' -- Body content: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $Body | Write-Verbose

            try {

                If ( ($PSVersionTable.PSVersion.ToString()).Split('.')[0] -eq 5) {
        
                    $response = Invoke-WebRequest -Method POST -Uri $url -Body $Body -Headers $Headers -ContentType "Application/json" -ErrorAction Stop

                    
                }
                else {
                    $response = Invoke-WebRequest -Method POST -Uri $url -Body $Body -Headers $Headers -ContentType "Application/json" -SkipCertificateCheck -ErrorAction Stop
                    
                }
                
                $XAuthToken = (($response.RawContent -split "[`r`n]" | select-string -Pattern 'X-Auth-Token' ) -split " ")[1]
                
                "[{0}] '{1}' -- Received status code response: '{2}' - Description: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $response.StatusCode, $InvokeReturnData.StatusDescription | Write-verbose              
                "[{0}] '{1}' -- Raw response: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $response | Write-Verbose

                "[{0}] '{1}' -- iLO session created successfully!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP  | Write-Verbose
      
            }
            catch {
                $objStatus.Status = "Failed"
                $objStatus.Details = "iLO connection error! Check your iLO credential!"
                $objStatus.Exception = $_.Exception.message 

                "[{0}] '{1}' -- iLO session cannot be created!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP  | Write-Verbose
                [void] $iLOConfigurationStatus.add($objStatus)
                return
            }

            # Get System information
                  
            $Headers = [System.Collections.Hashtable]@{
                'X-Auth-Token'  = $XAuthToken
                'Content-Type'  = 'application/json'
                'OData-Version' = '4.0'    
            }
    
            "[{0}] '{1}' -- Getting iLO generation " -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP  | Write-Verbose
              
            $AddURI = "/redfish/v1/Managers/1/"

            If ( ($PSVersionTable.PSVersion.ToString()).Split('.')[0] -eq 5) {
                $iLOGeneration = (Invoke-RestMethod -Method GET -Uri ($iLObaseURL + $AddURI) -Headers $Headers).model
            }
            else {
                $iLOGeneration = (Invoke-RestMethod -Method GET -Uri ($iLObaseURL + $AddURI) -Headers $Headers -SkipCertificateCheck).model
                
            } 

            if ($iLOGeneration -eq "iLO 5" -or $iLOGeneration -eq "iLO 6") {     
                
                
                if ($SetiLOProxy) {
                
                    #-----------------------------------------------------------Enable iLO Proxy settings if needed-----------------------------------------------------------------------------

                    "[{0}] '{1}' -- iLO '{2}' attempting to set iLO proxy server settings" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP | Write-Verbose

                    $AddURI = "/redfish/v1/Managers/1/NetworkProtocol/"
                         
                    $url = ( $iLObaseURL + $AddURI)
                         
                         
                    if ($IloProxyUserName -and $IloProxyPassword) {
                                                 
                        $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($IloProxyPassword)
                        $IloProxyPasswordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
                         
                        $Body = [System.Collections.Hashtable]@{
                            Oem = @{
                                Hpe = @{
                                    WebProxyConfiguration = @{
                                        ProxyServer   = $IloProxyServer
                                        ProxyPort     = $IloProxyPort
                                        ProxyUserName = $IloProxyUserName
                                        ProxyPassword = $IloProxyPasswordPlainText
                                    }
                                }
                            }
                        }  | ConvertTo-Json -d 9
                         
                    }
                    else {
                         
                        $Body = [System.Collections.Hashtable]@{
                            Oem = @{
                                Hpe = @{
                                    WebProxyConfiguration = @{
                                        ProxyServer = $IloProxyServer
                                        ProxyPort   = $IloProxyPort
                                    }
                                }
                            }
                        }  | ConvertTo-Json -d 9
                         
                    }
                         
                    "[{0}] '{1}' -- iLO '{2}' - Method: POST - URI: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $url | Write-Verbose
                    "[{0}] '{1}' -- iLO '{2}' - Hearders content: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, ($Headers | Out-String) | Write-Verbose
                    "[{0}] '{1}' -- iLO '{2}' - Body content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $Body | Write-Verbose
                         
                    try {
                                     
                        If ( ($PSVersionTable.PSVersion.ToString()).Split('.')[0] -eq 5) {
                            $Response = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $Body -ErrorAction Stop
                        }
                        else {
                            $Response = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $Body -ErrorAction Stop -SkipCertificateCheck
                        }
                         
                        "[{0}] '{1}' -- iLO '{2}' - Raw response: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, ($Response | Out-String) | Write-Verbose
                         
                        $msg = $response.error.'@Message.ExtendedInfo'.MessageId
                                           
                        "[{0}] '{1}' -- iLO '{2}' - Response: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $msg | Write-Verbose
                                
                        if ($msg -match "Success") {
                            "[{0}] '{1}' -- iLO '{2}' proxy server settings modified successfully!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP | Write-Verbose
                            $objStatus.Status = "Complete"
                            $objStatus.Details = "iLO proxy server settings modified successfully!"
                        }
                                          
                           
                    }
                    catch {
                         
                        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                        $msg = $err.error.'@Message.ExtendedInfo'.MessageId
                         
                        "[{0}] '{1}' -- iLO '{2}' proxy server settings cannot be configured! Error: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $msg | Write-Verbose
                         
                         
                        $objStatus.Status = "Failed"
                        $objStatus.Details = $_.Exception.message 
                         
                    }
                }

                elseif ($RemoveProxySettings) {

                    #-----------------------------------------------------------Disable iLO Proxy settings if needed-----------------------------------------------------------------------------

                    "[{0}] '{1}' -- iLO '{2}' attempting to remove iLO proxy server settings" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP | Write-Verbose

                    $AddURI = "/redfish/v1/Managers/1/NetworkProtocol/"

                    $url = ( $iLObaseURL + $AddURI)

                    $Body = [System.Collections.Hashtable]@{
                        Oem = @{
                            Hpe = @{
                                WebProxyConfiguration = @{
                                    ProxyServer   = ""
                                    ProxyPort     = $Null
                                    ProxyUserName = ""
                                    ProxyPassword = ""

                                }
                            }
                        }
                    }  | ConvertTo-Json -d 9


                    "[{0}] '{1}' -- iLO '{2}' - Method: PATCH - URI: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $url | Write-Verbose
                    "[{0}] '{1}' -- iLO '{2}' - Hearders content: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, ($Headers | Out-String) | Write-Verbose
                    "[{0}] '{1}' -- iLO '{2}' - Body content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $Body | Write-Verbose

                    try {
            
                        If ( ($PSVersionTable.PSVersion.ToString()).Split('.')[0] -eq 5) {
                            $Response = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $Body -ErrorAction Stop
                        }
                        else {
                            $Response = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $Body -ErrorAction Stop -SkipCertificateCheck
                        }

                        "[{0}] '{1}' -- iLO '{2}' - Raw response: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, ($Response | Out-String) | Write-Verbose

                        $msg = $response.error.'@Message.ExtendedInfo'.MessageId
                  
                        "[{0}] '{1}' -- iLO '{2}' - Response: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $msg | Write-Verbose
       
                        if ($msg -match "Success") {
                            "[{0}] '{1}' -- iLO '{2}' proxy server settings removed successfully!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP | Write-Verbose
                            $objStatus.Status = "Complete"
                            $objStatus.Details = "iLO proxy server settings removed successfully!"
                        }
                 
  
                    }
                    catch {

                        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                        $msg = $err.error.'@Message.ExtendedInfo'.MessageId

                        "[{0}] '{1}' -- iLO '{2}' proxy server settings cannot be removed! Error: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $msg | Write-Verbose


                        $objStatus.Status = "Failed"
                        $objStatus.Details = $_.Exception.message 

                    }
                    
                }

                else {
                    #-----------------------------------------------------------Get iLO Proxy information -----------------------------------------------------------------------------

                    "[{0}] '{1}' -- iLO '{2}' attempting iLO proxy server settings" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP | Write-Verbose

                    $AddURI = "/redfish/v1/Managers/1/NetworkProtocol/"

                    $url = ( $iLObaseURL + $AddURI)

                    "[{0}] '{1}' -- iLO '{2}' - Method: GET - URI: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $url | Write-Verbose
                    "[{0}] '{1}' -- iLO '{2}' - Hearders content: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, ($Headers | Out-String) | Write-Verbose

                    try {
            
                        If ( ($PSVersionTable.PSVersion.ToString()).Split('.')[0] -eq 5) {
                            $CollectionList = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers -ErrorAction Stop
                        }
                        else {
                            $CollectionList = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers -ErrorAction Stop -SkipCertificateCheck
                        }

                        "[{0}] '{1}' -- iLO '{2}' - Raw response: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, ($Response | Out-String) | Write-Verbose

                        $msg = $response.error.'@Message.ExtendedInfo'.MessageId
                  
                        "[{0}] '{1}' -- iLO '{2}' - Response: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $msg | Write-Verbose
       
                        if ($msg -match "Success") {
                            "[{0}] '{1}' -- iLO '{2}' proxy server settings read successfully!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP | Write-Verbose
                            $objStatus.Status = "Complete"
                            $objStatus.Details = "iLO proxy server settings read successfully!"
                        }
                 
  
                    }
                    catch {

                        $err = (New-Object System.IO.StreamReader( $_.Exception.Response.GetResponseStream() )).ReadToEnd() 
                        $msg = $err.error.'@Message.ExtendedInfo'.MessageId

                        "[{0}] '{1}' -- iLO '{2}' proxy server settings cannot be read! Error: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $IloIP, $msg | Write-Verbose


                        $objStatus.Status = "Failed"
                        $objStatus.Details = $_.Exception.message 

                    }

                    $ReturnData = @()
      
                    if ($Null -ne $CollectionList.Oem.Hpe.WebProxyConfiguration.ProxyServer) {   

                        # $objStatus.Status = "Configured"
                        
                        $WebProxyConfiguration = $CollectionList.Oem.Hpe.WebProxyConfiguration

                        # Add iloIP to object
                        $WebProxyConfiguration | Add-Member -type NoteProperty -name IP -value $IloIP

                        if ($Null -ne $WebProxyConfiguration.ProxyUserName) {
                            

                            $ReturnData = $WebProxyConfiguration | Select-Object IP, ProxyServer, ProxyPort, ProxyUserName
                        }
                        else {
                            $ReturnData = $WebProxyConfiguration | Select-Object IP, ProxyServer, ProxyPort

                        }
                        #  @{N = "Model"; E = { $_.attributes.model } }, @{N = "Serial Number"; E = { $_.attributes.serial_number } }  
                    
                        if ($ReturnData) {
                            return $ReturnData 
                        }
                        else {
                            Return
                        }
                            
                    }
                    else {
            
                        # $objStatus.Status = "Unconfigured"
                            
                    }     
            
                }

                
               
    
            
            }
            else {
  
                "[{0}] '{1}' -- iLO is not supported by this script! Skipping iLO..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose
      
                $objStatus.Status = "Error" 
                $objStatus.Details = "Only iLO5 and iLO6 are supported"
            }   
            
        
        }

        if ($SetiLOProxy -or $RemoveProxySettings) {

            [void] $iLOConfigurationStatus.add($objStatus)
        }
      
    }

    end {

        if ($SetiLOProxy -or $RemoveProxySettings) {

            if ($iLOConfigurationStatus | Where-Object { $_.Status -eq "Failed" }) {
  
                write-error "One or more iLO failed the proxy configuration!"
          
            }
         
            Return $iLOConfigurationStatus
        }


    }
        
}
