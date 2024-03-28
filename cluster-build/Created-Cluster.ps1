#################################
# create-rpcluster.ps1
# ver 0.73
# date 7/21/2021
#  Add timestamp to cluster verification report.
#  Presentation fix
#################################

####################################
# FUNCTIONS

param(
    [string]$node1 = "SERVERVMTST999A.corp.company.com" ,
    [string]$node2 = "SERVERVMTST999B.corp.company.com",
    [string]$clusterIP = "10.35.20.66",
    [string]$FSWitness = "\\TESTFS002.Corp.company.com\FileShareWitness"
)
function check-runlevel {
    write-output $sline |timestamp | Tee-Object -FilePath $logfile -Append
    Write-output "Checking for elevated permissions..."  |timestamp | Tee-Object -FilePath $logfile -Append
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
            [Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Output "##### WARNING ###### " | timestamp | Tee-Object -FilePath $logfile -Append
            Write-Output "This script requires ADMINISTRATOR level access." | timestamp | Tee-Object -FilePath $logfile -Append
            Write-Output "Please open a PowerShell console as an administrator and try again. " | timestamp | Tee-Object -FilePath $logfile -Append
            Write-Output "*** END OF LINE ***" | timestamp | Tee-Object -FilePath $logfile -Append
    Break
    } else {
    Write-Output "Run Level Access verified." | timestamp | Tee-Object -FilePath $logfile -Append
    }
}

###########################################################
# Logs variables
$logfile = ".\create-rpcluster_$(Get-Date -Format yyyyMMdd_HHmmss).log"
filter timestamp {"$(get-date -format G): $_"}
$sline = "=============================================="  
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
Write-output "Real Page Microsoft Cluster Creation Script"  | timestamp | Tee-Object -FilePath $logfile -Append
Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append


check-runlevel
import-module FailoverClusters
###########################################################
# Check\Set script directory C:\ClusterBuild
$CBDir = "C:\ClusterBuild"
if (Test-Path -path $CBDir) {
    Set-Location $CBDir
} else {
    New-Item -Path $CBDir -ItemType "directory"
    Set-Location $CBDir
}

####################################################
#  Read cluster-data.json
$JSONData = Get-Content ".\cluster-data.json" | ConvertFrom-JSon

# Static variables
$ClusterName = $JSONData.name
$ClusterIP = $JSONData.IP
$Node1 = $JSONData.Node1
$Node2 = $JSONData.Node2
$WitnessFS = $JSONData.WitnessShare
$ClusterOU = $JSONData.OU

#Generated variables
$Nodes = ($node1,$node2)
$portchecklist = "445"
$Domain = (Get-ADDomain).Name

# Static variables
Switch ($Domain) {
    "Corp" {
            $ClusterOU = "OU=Cluster Nodes,OU=Servers,OU=_Realpage,DC=corp,DC=realpage,DC=com"
            $ADClusterObjectGroup = "AGAD-JoinClusterObjects-RW"
        }
    "RealPage" {
            $ClusterOU = "OU=Cluster Nodes,OU=Servers,OU=_Realpage,DC=realpage,DC=com"
            $ADClusterObjectGroup = "AGAD-JoinClusterObjects-RW"
        }
    Default { 
        Write-output "Your are in domain: $Domain."  | timestamp | Tee-Object -FilePath $logfile -Append
        write-output "This script will not work on this domain as the script don't have the requirer information for this domain."  | timestamp | Tee-Object -FilePath $logfile -Append
        Write-output "##### END OF LINE #####"  | timestamp | Tee-Object -FilePath $logfile -Append
        BREAK
     }
}

#FLAGS
$NoGo = $False
$SkipPostVerification = $False

# Create cluster 
write-output $sline |timestamp | Tee-Object -FilePath $logfile -Append
write-output "Starting Cluster Configuration Process " |timestamp | Tee-Object -FilePath $logfile -Append
write-output "Using the current variables:" |timestamp | Tee-Object -FilePath $logfile -Append
write-output "`tNode 1: $node1" |timestamp | Tee-Object -FilePath $logfile -Append
write-output "`tNode 2: $node2" |timestamp | Tee-Object -FilePath $logfile -Append
write-output "`tCluster Name: $clustername" |timestamp | Tee-Object -FilePath $logfile -Append
write-output "`tCluster IP:$ClusterIP" |timestamp | Tee-Object -FilePath $logfile -Append
write-output "`tDomain: $Domain" |timestamp | Tee-Object -FilePath $logfile -Append

#Check to see if there is a pending reboot on the nodes
Write-Output "Pending reboots check." |timestamp | Tee-Object -FilePath $logfile -Append
forEach ($Server in $Nodes) {
    $GetWindowsFeatureFC = Get-WindowsFeature Failover-Clustering -ComputerName $Server
    if ($GetWindowsFeatureFC.InstallState -eq "InstallPending"){
        Write-Output "WARNING: Restart Requirer on $Server because of pending installs." |timestamp | Tee-Object -FilePath $logfile -Append
        Write-Output "You will need to perform a manual restart on the server before you can build the cluster." |timestamp | Tee-Object -FilePath $logfile -Append
        $NoGo=$true
    }
}

If ($NoGo -eq $True) {
    Write-Output "Stopping the script." |timestamp | Tee-Object -FilePath $logfile -Append
    Write-Output "##### END OF LINE #####" |timestamp | Tee-Object -FilePath $logfile -Append
    BREAK
}

# Check to see if there is already the cluster with that name on-line
if ((get-cluster -name $ClusterName -Domain $Domain) -ne $Null){
    $ClusterNodesList = Get-Cluster -Name $ClusterName -Domain $Domain | Get-ClusterNode
    Write-Output "###### WARNING #####" |timestamp | Tee-Object -FilePath $logfile -Append
    Write-Output "There is already a cluster name $ClusterName with nodes $ClusterNodesList" |timestamp | Tee-Object -FilePath $logfile -Append
    Write-Output "Stopping the script." |timestamp | Tee-Object -FilePath $logfile -Append
    Write-Output "##### END OF LINE #####" |timestamp | Tee-Object -FilePath $logfile -Append
    BREAK
}

#################################################
# Perform pre-build cluster verification test
write-output $sline |timestamp | Tee-Object -FilePath $logfile -Append
write-output "Running cluster verification tests on each node" |timestamp | Tee-Object -FilePath $logfile -Append

Test-Cluster -Node $Node1, $node2 -verbose -ReportName "C:\ClusterBuild\Pre Cluster Build Verification Report - $(Get-Date -Format yyyyMMdd_HHmmss)" |timestamp | Tee-Object -FilePath $logfile -Append

write-output $sline |timestamp | Tee-Object -FilePath $logfile -Append
Write-output "Creating Cluster.  Please wait a moment..." |timestamp | Tee-Object -FilePath $logfile -Append
try
   {
     $ClusterCfgResults = New-Cluster -Name $clusterName -Node $node1,$node2 -StaticAddress $ClusterIP -NoStorage |timestamp | Tee-Object -FilePath $logfile -Append
     Write-output "Cluster $ClusterName build completed." |timestamp | Tee-Object -FilePath $logfile -Append
   } 

catch
   {
     Write-Output "Creating cluster $clustername has failed." |timestamp | Tee-Object -FilePath $logfile -Append
     Write-Output $Error[0]
     break
   }    


#Adding ClusterFOC to ADGroup for permissions.
write-output $sline |timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "Cluster Object Membership Check" |timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "Verifying that cluster object $ClusterName is a member of $ADClusterObjectGroup." |timestamp | Tee-Object -FilePath $logfile -Append

# $ADClusterObjectGroup = "AGAD-JoinClusterObjects-RW"
$ADCOGMembers = Get-ADGroupMember $ADClusterObJectGroup | select Select -ExpandProperty Name
try
    {
    if ($ADCOGMembers -contains $ClusterName) {
        Write-output "Cluster object $ClusterName is already a member of AD group $ADClusterObjectGroup." |timestamp | Tee-Object -FilePath $logfile -Append
    } else {
        write-output "Cluster object $Clustername is not a member of $ADClusterObjectGroup." |timestamp | Tee-Object -FilePath $logfile -Append
        Write-output "Adding cluster object $ClusterName to AD group $ADClusterObjectGroup." |timestamp | Tee-Object -FilePath $logfile -Append
        $Computerobj = get-adcomputer $ClusterName
        Add-ADGroupMember -Identity $ADClusterObjectGroup -Members $ComputerObj.SamAccountName -ErrorAction SilentlyContinue
        Write-output "Cluster object membership completed." |timestamp | Tee-Object -FilePath $logfile -Append
    }
}
catch
    {
        write-output "Error adding the Cluster object $ClusterName to AD Group $ADClusterObjectGroup." |timestamp | Tee-Object -FilePath $logfile -Append
        Write-debug $Error[0]
    }
Write-Output "Wait a few moments ...." |timestamp | Tee-Object -FilePath $logfile -Append
Start-Sleep -Seconds 15

write-output $sline |timestamp | Tee-Object -FilePath $logfile -Append
write-output "Starting Cluster File Share Witness Quorum process" |timestamp | Tee-Object -FilePath $logfile -Append

#Check is the cluster active
$IsClusterActive = Get-Cluster -Name $clustername -Domain $Domain

# Create and configure quorum witness share 
if ($IsClusterActive -ne $null)
    {
        Write-output "Quorum Witness File Share" |timestamp | Tee-Object -FilePath $logfile -Append
        $IsClusterWFS = @(Get-ClusterResource -Cluster $ClusterName |where-object {$_.ResourceType -like "File Share Witness"} | Get-ClusterParameter -name "sharepath" ).value

        if ($IsClusterWFS){
            Write-output "Cluster $ClusterName has a Witness File Share configure on $IsClusterWFS" |timestamp | Tee-Object -FilePath $logfile -Append
            Write-output "Skipingng Witness File Share Quorum configuration" |timestamp | Tee-Object -FilePath $logfile -Append
        } else {
            #Invoke a connectivity Test.

            # Check to see if the WFSQ directory exist
            if ((Get-Item -Path $WitnessFS -ErrorAction SilentlyContinue) -eq $False)
            {   
                #Target folder does not exist.  Creating target folder.
                Write-Output "Creating target folder $WitnessFS."  |timestamp | Tee-Object -FilePath $logfile -Append
                $ShareCfgResults = New-Item -Path $WitnessFS -ItemType Directory -Force
            } else {
                Write-Output "Target folder $WitnessFS already exist." |timestamp | Tee-Object -FilePath $logfile -Append
            }    
            #Set the WFSQ
            Write-Output "Configuring $WitnessFS as file share witness quorum. ."  |timestamp | Tee-Object -FilePath $logfile -Append
            $ClusterCfgResults = get-cluster -Name $ClusterName -Domain $Domain | Set-Clusterquorum -FileShareWitness $WitnessFS
            If ($ClusterCfgResults.QuorumResource) 
            {
                Write-Output "Cluster quorum configuration process complete successfully."  |timestamp | Tee-Object -FilePath $logfile -Append
            } else {
                Write-Output "Cluster quorum configuration process complete with error."  |timestamp | Tee-Object -FilePath $logfile -Append

            }
         }
            
    } else {
        Write-Output "Cluster Configuration failed."  |timestamp | Tee-Object -FilePath $logfile -Append
        Write-Output "Skipping the quorum witness share configuration."  |timestamp | Tee-Object -FilePath $logfile -Append
        $NoGo = $True
    }



# Show current cluster configuration
$ClusterFSWPath = @(Get-ClusterResource -Cluster $ClusterName |where-object {$_.ResourceType -like "File Share Witness"} | Get-ClusterParameter -name "sharepath" ).value
write-output $sline |timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "Cluster Quorum Information "   |timestamp | Tee-Object -FilePath $logfile -Append
Write-Output $ClusterWFSResults | fl
Write-Output "Path: $ClusterFSWPath"  |timestamp | Tee-Object -FilePath $logfile -Append


####################################################
# Performing Post-build  cluster verification test

write-output $sline |timestamp | Tee-Object -FilePath $logfile -Append
write-output "Post-build Vefification" |timestamp | Tee-Object -FilePath $logfile -Append

if ($IsClusterActive -ne $null) {
    write-output "Running cluster verification tests on each node"  |timestamp | Tee-Object -FilePath $logfile -Append
    Test-Cluster -Node $Node1, $node2 -verbose -ReportName "C:\ClusterBuild\Post Cluster Build Verification Report - $(Get-Date -Format yyyyMMdd_HHmmss)"   |timestamp | Tee-Object -FilePath $logfile -Append
} else {
    Write-Output "Cluster configuration failed."   |timestamp | Tee-Object -FilePath $logfile -Append
    Write-Output "Skipping post-verification" |timestamp | Tee-Object -FilePath $logfile -Append
}

Write-output $sline  | timestamp | Tee-Object -FilePath $logfile -Append
Write-Output "END OF LINE"  | timestamp | Tee-Object -FilePath $logfile -Append

