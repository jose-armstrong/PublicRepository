#################################
# remove-cluster.ps1
# ver 0.71
# date 7/21/2021
#   Add domain ID
#   Add $allCleanUP switch 
#   Clean-up redundant static variables
#################################

param(
    [switch]$allCleanUp = $false
)

function check-runlevel {
    Write-Host "Checking for elevated permissions..."
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
            [Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Output "##### WARNING ######"
            Write-Output "This script requires ADMINISTRATOR level access."
            Write-Output "Please open a PowerShell console as an administrator and try again."
            Write-Output "*** END OF LINE ***"
    Break
    }
else {
    Write-Output "Run Level Access verified."
    }
}

check-runlevel

import-module servermanager
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


#  Read cluster-data.json
$JSONData = Get-Content ".\cluster-data.json" | ConvertFrom-JSon
$ClusterName = $JSONData.name
$ClusterIP = $JSONData.IP
$Node1 = $JSONData.Node1
$Node2 = $JSONData.Node2
$WitnessFS = $JSONData.WitnessShare
$ClusterOU = $JSONData.OU

$Domain = (Get-ADDomain).Name
$Nodes = ($node1,$node2)


#Destroy Witness share 
get-cluster -Name $ClusterName -Domain $Domain | Set-Clusterquorum -NoWitness

if ((Get-Item -Path $WitnessFS -ErrorAction SilentlyContinue) -eq $True)
{   
    #Target folder exist.  Deleting target folder.
    Write-Output "Deleting target folder $WitnessFS."
    remove-Item -Path $WitnessFS -recurse
} else {
    Write-Output "Target folder $WitnessFS does not exist."
}    


# Destroy cluster
Get-Cluster $Clustername -Domain $Domain | Remove-Cluster -force -CleanupAD

if ($allcleanup) {
    forEach ($Server in $Nodes) {
        Write-Output "Removing the Failover-clustering fuction on server $Server"
        Invoke-command -ComputerName $Server -ScriptBlock {
            remove-WindowsFeature Failover-Clustering -IncludeManagementTools
        }
    }

#clean-up Nodes on AD.  This is need it if the clean-up command fails. Uncomment if need it.

# Clear-ClusterNode -Name $node1 -force
# Clear-ClusterNode -Name $node2 -force
# remove-adcomputer -identity $ClusterName

}
