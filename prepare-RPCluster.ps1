#################################
# prepare-rpcluster.ps1
# ver 0.75
# Update date: 8/12/2021
#    Bug: B node is not Failover tools installation is failing.
#################################


param (
    [string]$help,
    [Parameter(Mandatory=$True)]
    [string]$node1 = "RCDMSEVMTST999A" ,
    [Parameter(Mandatory=$True)]
    [string]$node2 = "RCDMSEVMTST999B.corp.realpage.com",
    [Parameter(Mandatory=$True)]
    [string]$clusterIP = "10.35.24.66",
    [Parameter(Mandatory=$True)]
    [ValidateSet("Prod","Ent","Dev")]
    [string]$Environment = "Dev"

)
function usage {
    write-host "prepare-rpcluster.ps1 [-help] [-Node1] [-Node2] [-ClusterIP] [-Environment] `n" -foregroundcolor "white"
    write-host "  -help prints this information" -foregroundcolor "yellow"
    write-host "  -Node1 - Name of the first server node in the cluster. (Mandatory)" -foregroundcolor "yellow"
    write-host "  -Node2 - Name of the second server node in the cluster. (Mandatory)" -foregroundcolor "yellow"
    write-host "  -ClusterIP - IP address to be assign to the cluster object. (Mandatory)" -foregroundcolor "yellow"
    write-host "  -Environment - Which environment this cluster resides.  The valid options are Prod, Ent and Dev. (Mandatory)" -foregroundcolor "yellow"
    write-host " "
    exit
}
   
 function get-runlevel {
    Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
    Write-output "Checking for Powershell elevated session permissions..." | timestamp | Tee-Object -FilePath $logfile -Append
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Output "##### WARNING ######" | timestamp | Tee-Object -FilePath $logfile -Append
            Write-Output "This script requires ADMINISTRATOR level access"  | timestamp | Tee-Object -FilePath $logfile -Append
            Write-Output "Please open a PowerShell console as an administrator and try again."  | timestamp | Tee-Object -FilePath $logfile -Append
            Write-Output "*** END OF LINE ***"
            Break
        } else {
            Write-Output "Run level access administrator verified." | timestamp | Tee-Object -FilePath $logfile -Append
    }  
}

Function Get-FOCName {
    param(
        [Parameter(Mandatory=$true)]
        [string] $NodeName
    )
    $FOCBaseName = $NodeName.substring(0,6)+"FOC"+$NodeName.Substring(8,3)
    $loopCounter = 0
    do {
        $computerfound = $null
        $loopCounter++
        $X = $loopCounter | ForEach-Object tostring 000
        $FOCName1 = $FOCBaseName+$x
        try 
        {
            $computerfound = get-adcomputer $FOCName1 -ErrorAction SilentlyContinue
        }
        catch 
        {
#             Write-host "Computer name $FOCName1 is available to be used as the cluster node name"
        }
    } while ($computerfound -ne $null) 
    return $FOCName1
}

function set-FQDN {
    param(
        [Parameter(Mandatory=$true)]
        [string] $NodeName
    )

    if ($NodeName -like "*$env:USERDNSDOMAIN"){
    } else {
        $NodeName = $NodeName+"."+$env:USERDNSDOMAIN
    }

    return $NodeName
    
}

#=======================================================================
# PROCEDURES
$logfile = ".\prepare-rpcluster_$(Get-Date -Format yyyyMMdd_HHmmss).log"
filter timestamp {"$(get-date -format G): $_"}

#Help switch
if ("-help", "--help", "-?", "--?", "/?" -contains $args[0]) {
    usage
 
 }


###########################################################
# Check\Set script directory C:\ClusterBuild
$CBDir = "C:\ClusterBuild"
if (Test-Path -path $CBDir) {
    Set-Location $CBDir
} else {
    New-Item -Path $CBDir -ItemType "directory"
    Set-Location $CBDir
}



###########################################################
Clear-Host
$sline = "=============================================="  
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
Write-output "Real Page Microsoft Cluster Preparation Script"  | timestamp | Tee-Object -FilePath $logfile -Append
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append

get-runlevel
import-module servermanager

Write-Output "Active-Directory administration tools and Power-Shell modules" | timestamp | Tee-Object -FilePath $logfile -Append
if ((get-WindowsFeature -Name RSAT-AD-PowerShell).installState -eq "Available")
{
   
    Write-Output "Installing the necesary cluster features to the local server." | timestamp | Tee-Object -FilePath $logfile -Append
    Write-Output "- ActiveDirectory administration tools" | timestamp | Tee-Object -FilePath $logfile -Append
    add-WindowsFeature RSAT-ADDS | Out-Null
    Write-Output "- Active Directory Power-Shell modules" | timestamp | Tee-Object -FilePath $logfile -Append
    add-WindowsFeature RSAT-AD-PowerShell | Out-Null

} else {
    Write-Output "Local Server has the necesary Active Directory administration tools." | timestamp | Tee-Object -FilePath $logfile -Append
}


# Run function to check\set the server name to FQDN
$node1 = set-FQDN($node1)
$node2 = set-FQDN($node2)

#Generated variables
$Nodes = ($node1,$node2)
$portchecklist = "445"
$Domain = (Get-ADDomain).Name

# Static variable
Switch ($Domain) {
   "Corp"     {$ClusterOU = "OU=Cluster Nodes,OU=Servers,OU=_Realpage,DC=corp,DC=realpage,DC=com"}
   "RealPage" {$ClusterOU = "OU=Cluster Nodes,OU=Servers,OU=_Realpage,DC=realpage,DC=com"}
   Default { 
       Write-output "This script will not work on this domain."  | timestamp | Tee-Object -FilePath $logfile -Append
       write-output "I don't have the information of the Cluster Node OU"  | timestamp | Tee-Object -FilePath $logfile -Append
       Write-output "##### END OF LINE #####"  | timestamp | Tee-Object -FilePath $logfile -Append
       BREAK
    }
}

switch ($Environment) {
    "Prod"     {$WitnessServer = "RCPSQLFS001.Realpage.com"}
    "Ent"      {$WitnessServer = "rcesqlfs001.corp.realpage.com"}
    "Dev"      {$WitnessServer = "RCDONEFS002.Corp.Realpage.com"}
    Default { 
        Write-output "This script will not work on this environment."  | timestamp | Tee-Object -FilePath $logfile -Append
        write-output "Without the correct environment, a witness file share can be configure."  | timestamp | Tee-Object -FilePath $logfile -Append
        Write-output "##### END OF LINE #####" | timestamp | Tee-Object -FilePath $logfile -Append
        BREAK
     }
}

write-output "Parameters:"  | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Node 1: $node1"  | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Node 2: $node2"  | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Cluster IP:$ClusterIP"  | timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "Witness Server: $WitnessServer"  | timestamp | Tee-Object -FilePath $logfile -Append


Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "Start cluster name generation function." | timestamp | Tee-Object -FilePath $logfile -Append
$ClusterName = Get-FOCName($node1)
Write-Output "Cluster name: $Clustername." | timestamp | Tee-Object -FilePath $logfile -Append

$FSWitness = "\\"+$WitnessServer+"\FileShareWitness"+"\"+$ClusterName
$NoGo = $False

# MAIN PROCEDURE

# Verify/Add Cluster funcionality to local server

write-output "Current domain: $Domain" | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Cluster nodes OU for domain $Domain - $ClusterOU" | timestamp | Tee-Object -FilePath $logfile -Append

Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Local Server Checks" | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Install\Verify that the local server has the Active Directory and Cluster administration tools." | timestamp | Tee-Object -FilePath $logfile -Append

#################################################
# Local Server AD features Tools Check

Write-Output "Active-Directory administration tools and Power-Shell modules" | timestamp | Tee-Object -FilePath $logfile -Append
if ((get-WindowsFeature -Name RSAT-AD-PowerShell).installState -eq "Available")
{
   
    Write-Output "Installing the necesary cluster features to the local server." | timestamp | Tee-Object -FilePath $logfile -Append
    Write-Output "- ActiveDirectory administration tools" | timestamp | Tee-Object -FilePath $logfile -Append
    add-WindowsFeature RSAT-ADDS | Out-Null
    Write-Output "- Active Directory Power-Shell modules" | timestamp | Tee-Object -FilePath $logfile -Append
    add-WindowsFeature RSAT-AD-PowerShell | Out-Null

} else {
    Write-Output "Local Server has the necesary Active Directory administration tools." | timestamp | Tee-Object -FilePath $logfile -Append
}

#################################################
# Localserver cluster management tools check

# write-output "------------------------------------------------------------------"
# Write-Output "Clustering management tools"
if ((get-WindowsFeature -Name rsat-clustering-mgmt).installState -eq "Available")
{
    Write-Output "Installing the cluster management tools to the local server." | timestamp | Tee-Object -FilePath $logfile -Append
    # Write-Output "- Installing Failover-Clustering management Tools"
    add-WindowsFeature rsat-clustering-mgmt
    # Write-Output "- Installing Failover-Clustering Power-Shell modules"
    Add-WindowsFeature RSAT-Clustering-PowerShell 
} else {
    Write-Output "Local Server has the cluster management tools." | timestamp | Tee-Object -FilePath $logfile -Append
}


#################################################
# Pre-stage the Cluster Object on AD (if Need it)
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
# write-output "Active Directory Object Checks"
write-output "Cluster Name Object (CNO)." | timestamp | Tee-Object -FilePath $logfile -Append
# write-output "- If the CNO is missing a new CNO will be generated."
# write-output "- If the CNO is on the wrong OU, it will be move."

Try {
      Write-Output "Creating CNO $Clustername." | timestamp | Tee-Object -FilePath $logfile -Append
      New-ADComputer -Name $ClusterName -path $ClusterOU -Description "Cluster Name Object - Created by Cluster Build Script" -Enabled $False
      Write-Output "Account created.  Please wait for verification on AD." | timestamp | Tee-Object -FilePath $logfile -Append
      do {
        Write-Output "Wait 10 seconds." | timestamp | Tee-Object -FilePath $logfile -Append
        Start-Sleep 10
        $isCNO = Get-ADComputer $ClusterName
        $KeepDo = $True
        if ($isCNO) {
          $CNOOU = ($isCNO.DistinguishedName).Substring((($clustername.Length)+4),(($isCNO.DistinguishedName).Length-(($clustername.Length)+4)))
          Write-Output "Verified: CNO $clustername was created sucessfully on" | timestamp | Tee-Object -FilePath $logfile -Append
          Write-Output "OU $CNOOU." | timestamp | Tee-Object -FilePath $logfile -Append
          $KeepDo = $False
        }  else {
            Write-Output "Cluster Name Object wasn't found." | timestamp | Tee-Object -FilePath $logfile -Append
            Write-Output "Let's wait a little more and try again." | timestamp | Tee-Object -FilePath $logfile -Append
        }  
      } while ($KeepDo)

}

catch {
    Write-Output "ERROR: CNO creation failed." | timestamp | Tee-Object -FilePath $logfile -Append
    Write-Output "Account will need to be created manually on OU $ClusterOU." | timestamp | Tee-Object -FilePath $logfile -Append
    # Get-ADComputer -Identity $Clustername | Disable-ADAccount  # TO DELETE
}
 

#################################################
# Nodes communications check
#Verify that the Nodes are power-on and accessible
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Server Nodes Connectivity Checks" | timestamp | Tee-Object -FilePath $logfile -Append


forEach ($Server in $Nodes) {
    Write-Output "Testing connectivity to server $Server" | timestamp | Tee-Object -FilePath $logfile -Append
    if (Test-Connection $Server -ErrorAction SilentlyContinue)
    {
        write-output "Pass: Computer $Server is on-line" | timestamp | Tee-Object -FilePath $logfile -Append
    } else {
        write-output "ERROR: Computer $Server is off-line" | timestamp | Tee-Object -FilePath $logfile -Append
        $NoGo = $True
    } 
}

Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "Testing TCP port connectivity to node servers" | timestamp | Tee-Object -FilePath $logfile -Append
forEach ($Server in $Nodes) {
    foreach ($port in $portchecklist) {
        $IsConnectionGoon = Test-NetConnection -ComputerName $server -Port $port -ErrorAction SilentlyContinue   
        if ($IsConnectionGoon){
            write-output "Pass: Server $Server Port $port is accessible" | timestamp | Tee-Object -FilePath $logfile -Append
        } else {
            write-output "WARNING: Server $Server Port $port is not accessible" | timestamp | Tee-Object -FilePath $logfile -Append
            $NoGo = $True
        }
    }
}

#Perform a connectivity test between Node and WitnessFS
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "Testing TCP Port connectivity between nodes and File Share Witness" | timestamp | Tee-Object -FilePath $logfile -Append

forEach ($Server in $Nodes) {
    Write-Output "Testing server $Server" | timestamp | Tee-Object -FilePath $logfile -Append
    If ($Server -like "$env:COMPUTERNAME*") {
        $IsPortOpen = (Test-NetConnection -port "445" -ComputerName $WitnessServer).TCPTestSucceeded
        if ($IsPortOpen){
            write-output "Pass: Connectivity test sucessful" | timestamp | Tee-Object -FilePath $logfile -Append
        } else {
            write-output "WARNING: Connectivity test failed" | timestamp | Tee-Object -FilePath $logfile -Append
            write-output "Please verify the TCP port 445 is open from node $Server to Witness FS $WitnessServer." | timestamp | Tee-Object -FilePath $logfile -Append
        }
    } else {
        $ICParamaters = @{
            ComputerName = $Server
            ScriptBlock = {
             Param ($WitnessServer)
             filter timestamp {"$(get-date -format G): $_"}
             $IsPortOpen = (Test-NetConnection -port "445" -ComputerName $WitnessServer).TCPTestSucceeded
             if ($IsPortOpen){
                 write-output "Pass: Connectivity test sucessful"
             } else {
                 write-output "WARNING: Connectivity test failed"
                 write-output "Please verify the TCP port 445 is open from node $Server to Witness FS $WitnessServer."
             }
            }
            ArgumentList = $WitnessServer
        }
        Invoke-command @ICParamaters
    }
    # Write-Output "TCP port test between Node $Server and WitnessServer $WitnessServer completed."
}

#  if the $NOGo flag is $True, break the script.

If ($NoGo -eq $true) { 
    write-output "One of the server nodes failed the connectivity test." | timestamp | Tee-Object -FilePath $logfile -Append
    write-output "Please address this issue and try again." | timestamp | Tee-Object -FilePath $logfile -Append
    write-output "##### END OF LINE #####" | timestamp | Tee-Object -FilePath $logfile -Append
    break
}

#################################################
# Install or verify the clustering fuction on each node
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Installing or verifying the failover\clustering functionality" | timestamp | Tee-Object -FilePath $logfile -Append

forEach ($Server in $Nodes) {
    Write-Output "Verifying server $Server." | timestamp | Tee-Object -FilePath $logfile -Append
    Import-Module ServerManager
    $IsFailoverInstalled = (Get-WindowsFeature Failover-Clustering -ComputerName $server).InstallState 
    if ($IsFailoverInstalled -eq "Installed"){
            Write-Output "Server $Server already has Failover\Clustering feature installed"
        } else {
            Write-Output "Starting Failover\Clustering feature installation" | timestamp | Tee-Object -FilePath $logfile -Append
            $ResultsWindowsFeatureInstall = Add-WindowsFeature Failover-Clustering -IncludeManagementTools -ComputerName $Server
            if ($ResultsWindowsFeatureInstall.ExitCode -eq "SuccessRestartRequired") { 
                Write-Output "Restart Requirer." | timestamp | Tee-Object -FilePath $logfile -Append
                Write-Output "You will need to perform a manual restart on server $Server before you can build the cluster." | timestamp | Tee-Object -FilePath $logfile -Append
            }
        }
}


####################################################
#  Create cluster-data.json

Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
write-output "Creating file cluster-data.json"  | timestamp | Tee-Object -FilePath $logfile -Append
write-output "This JSON file contain the parameters for the cluster creation script."  | timestamp | Tee-Object -FilePath $logfile -Append

$json = @()
$JSonCluster = "" | Select-Object name,IP,WitnessShare,Node1,Node2,OU

$JSonCluster.Name = $ClusterName
$JSonCluster.IP = $clusterIP
$JSonCluster.WitnessShare = $FSWitness
$JSonCluster.Node1 = $node1
$JSonCluster.Node2 = $node2
$JSonCluster.OU = $ClusterOU

$json += $JSonCluster

try {
    $json | ConvertTo-JSon | Out-File ".\cluster-data.json" 
    Write-Output "File cluster-data.json was created successfully"  | timestamp | Tee-Object -FilePath $logfile -Append
}
catch {
    Write-Output "ERROR:  File cluster-data.json was not created."  | timestamp | Tee-Object -FilePath $logfile -Append
}
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "END OF LINE"  | timestamp | Tee-Object -FilePath $logfile -Append

