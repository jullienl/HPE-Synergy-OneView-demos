
Param($Name)
    
    start-sleep 2
    write-host "Restarting service $name"
    Restart-Service $name
    
