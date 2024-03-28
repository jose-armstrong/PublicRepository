# Check Server Sevices
#
#
# Service Status check


$ServerList = Import-Csv -Path "ServerOPS_services_list.csv"

# Service test
Write-host "ServerName `t`t Status`t`t Display Name"   
#
#
foreach ($Server in $ServerList){
    $connectionStatus = test-NetConnection -ComputerName $Server.ServerName -InformationLevel Quiet
    if ($connectionStatus) {
        $xService = get-service -ComputerName $Server.ServerName -DisplayName $Server.Service
        If ($xService.Status -eq "Running") {
            Write-host $Server.ServerName `t`t $xService.Status`t`t`t  $xService.DisplayName -foregroundColor Green
        } else {
            Write-host $Server.ServerName `t`t $xService.Status`t`t`t  $xService.DisplayName  -foregroundColor Red
        }
    } else {
        Write-host "Server " $Server.ServerName "is not responding" 
    }  
}

$host.ui.RawUI.ForegroundColor = "White"

