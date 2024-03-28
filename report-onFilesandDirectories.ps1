#################################
# report-onFilesandDirectories.ps1
# ver 0.19
# date 8/23/2021
#  add SubFolder Depth level limit. 
#  add Throttle switch to prevent high cpu issues
#  on ACL report 
#      filter know Admins accounts from the report
#      Filter all Sid Accounts (delete)
#      Error handler for access denied directory
#      add switch to list group membership
#      Generated report on Excel Spreadsheet
#################################
param(
    [string]$TargetDirectory,
    [string]$TargetUser,
    [switch]$ACL, 
    [int]$Depth = 0,
    [switch]$FileSize,
    [switch]$FilterAdmins,
    [switch]$FolderSize,
    [switch]$ListGroupMembers,
    [Validateset("csv","excel")]
    [string]$ReportType , 
    [switch]$Throttle,
    [switch]$VerifyAccess
    )

<#
    .SYNOPIS
    Create a report of s directory Information

    .DESCRIPTION
    The script can generated the following reports
        1. ACL - Permissions report of a directory and subfolders.
        2. Folder Size 
        3. File Size - This report includes the Create/Last Access/Last Modify.

    .PARAMETER TargetDirectory

    .PARAMETER ACL

    .PARAMETER FolderSize

    .PARAMETER FileSize

    .PARAMETER Report Type
    Select the format of report
        - excel
        - csv

    .PARAMETER ListGroupMembers

    .PARAMETER FilterAdmins

    .PARAMETER Throttle
    
#>

#########################################################
# Fuctions 



#########################################################
# MAIN PROCEDURE
#
 #Parameters
$filterList =@()
$filterList = (
    "rri\jarmstrong",
    "RRI\NOC_DFS_Admins",
    "RRI\Domain Admins",
    "BUILTIN\Administrators",
    "RRI\evault",
    "RRI\bchandel",
    "RRI\ssirasanambeti",
    "NT AUTHORITY\Authenticated Users",
    "NT AUTHORITY\SYSTEM", 
    "BUILTIN\Users"
)

if ($Throttle) { $Throttle = 50} else {$Throttle = $null}

if (!$TargetDirectory) {$TargetDirectory = Read-host "Enter the target directory name"} else {}

if ($FileSize) {
    $ReportName = "FileSize__$TargetDirectory_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
    Get-ChildItem -path $TargetDirectory -Recurse -file -Depth $Depth  | Select FullName, Length, CreationTime, LastAccessTime, LastWriteTime | export-csv $ReportName
}

if ($FolderSize) {
    $ReportName = "FolderSize_$TargetDrectory_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
    Get-ChildItem -path $TargetDirectory -Recurse -Directory -Depth $Depth | Select FullName, Length, CreationTime, LastAccessTime, LastWriteTime | export-csv $ReportName
}

if ($ACL){
    $tdname = $TargetDirectory.Replace("\","-")
    $tdname = $tdname.Replace(":","-")
    $ReportName = $tdname+"_ACL_$(Get-Date -Format yyyyMMdd_HHmmss)"
    $ReportName2 = ".\report2_ACL_$Targetdirectory_$(Get-Date -Format yyyyMMdd_HHmmss).csv"

    $dlist = Get-ChildItem -Path $TargetDirectory -directory -Recurse -Depth $Depth
    $Output =@()
    foreach ($dname in $dlist){
        # Throttler CPU Utilization
        if ($Throttle) {Start-Sleep -m $Throttle}
        Write-Output "Directory: $($dname.FullName)"
        $Properties = [ordered]@{'Folder Name'=$dname.FullName;'Group/User'="";'Permissions'="";'Inherited'="";'Member Name'="";'Department'="";"Enable Account"=""}
        $Output += New-Object -TypeName psobject -Property $Properties
        try {
            $dacl = (Get-Acl -Path $dname.FullName).access 
        }
        catch {
            Write-Output "`tWARNING: Problems accessing permissions for $($dname.FullName). Your account may not have the access."
            $dacl =  @{'AccessControlType'= "No Access";'FileSystemRights'='No Access';'IdentityReference'='N/A';'InheritanceFlags'='N/A';'IsInherited'='N/A';'PropagationFlags'='N/A'}
        }
        
        foreach ($dAccess in $dacl) {
            $Properties = [ordered]@{'Folder Name'="";'Group/User'=$dAccess.IdentityReference;'Permissions'=$dAccess.FileSystemRights;'Inherited'=$dAccess.IsInherited;'Member Name'=""}
            if ($Properties.'Group/User'.Value -notlike 'S-1-5*'){    # if the name is a SID, skipped
                switch ($FilterAdmins) {
                    $True {
                        if (($filterList -notcontains $Properties.'Group/User'.Value)) {
                            $isGroup = $null
                            Write-Output "`t$($dAccess.IdentityReference)`t$($dAccess.FileSystemRights)`t$($dAccess.IsInherited)"
                            $Output += New-Object -TypeName psobject -Property $Properties 
                            if ($Properties.'Group/User'.Value -ne $null){
                                $samatarget = $($Properties.'Group/User'.Value).Replace("RRI\","")
                                try {$isGroup = Get-ADGroup $samatarget -ErrorAction SilentlyContinue | select samaccountname} 
                                catch {}
                                if ($isGroup -and $ListGroupMembers) {
                                    $OutputUser = @()
                                    $groupMemberlist = Get-ADGroupMember -Identity $samatarget |Select-Object samaccountname,objectclass | Sort-Object samaccountname
                                    foreach ($groupmember in $groupMemberlist) {
                                        if ($groupmember.objectclass -eq "user"){
                                            $userinfo = get-aduser -Identity $groupmember.samaccountname -Properties name, office, enabled, manager,department,Description
#                                            Write-Output "`t`t$($userinfo.name)`t$($userinfo.Department)`t$($userinfo.enabled)`t$($userinfo.description)"
                                            $Properties = [ordered]@{'Folder Name'="";'Group/User'="";'Permissions'="";'Inherited'="";'Member Name'=$userinfo.name;'Department'=$userinfo.Department;"Enable Account"=$userinfo.enabled}
                                            $Output += New-Object -TypeName psobject -Property $Properties
                                        }
                                    }
                                } 
                            }
                        }
                    }  # Switch Filter Admin TRUE
                    $False {
                            $isGroup = $null
                            Write-Output "`t$($dAccess.IdentityReference)`t$($dAccess.FileSystemRights)`t$($dAccess.IsInherited)"
                            $Output += New-Object -TypeName psobject -Property $Properties 
                            if ($Properties.'Group/User'.Value -ne $null){
                                $samatarget = $($Properties.'Group/User'.Value).Replace("RRI\","")
                                try {$isGroup = Get-ADGroup $samatarget -ErrorAction SilentlyContinue | select samaccountname} 
                                catch {}
                                if ($isGroup -and $ListGroupMembers) {
                                    $OutputUser = @()
                                    $groupMemberlist = Get-ADGroupMember -Identity $samatarget |Select-Object samaccountname,objectclass | Sort-Object samaccountname
                                    foreach ($groupmember in $groupMemberlist) {
                                        if ($groupmember.objectclass -eq "user"){
                                            $userinfo = get-aduser -Identity $groupmember.samaccountname -Properties name, office, enabled, manager,department,Description
 #                                           Write-Output "`t`t$($userinfo.name)`t$($userinfo.Department)`t$($userinfo.enabled)`t$($userinfo.description)"
                                            $Properties = [ordered]@{'Folder Name'="";'Group/User'="";'Permissions'="";'Inherited'="";'Member Name'=$userinfo.name;'Department'=$userinfo.Department;"Enable Account"=$userinfo.enabled}
                                            $Output += New-Object -TypeName psobject -Property $Properties
                                        } # If 
                                    } # ForEach 
                                } 
                            }
                    } # Switch Filter Admin FALSE
                    Default {                    
                    } # Switch Filter Admin Default
                }   # Filter Admin Switch
            }   
        }
    }   
    switch ($ReportType) {
        "csv" { 
            $ReportName = ".\"+$ReportName+".csv"   
            Write-Output "Writing report to $reportName"     
            $Output | Export-Csv -path $ReportName
        }
        "excel" { 
            $ReportName = ".\"+$ReportName+".xlsx" 
            Write-Output "Writing report to $reportName"     
            $Output | Export-excel -path $ReportName  -Append
        }
        Default {
            Write-Output "No report requested"
        }
    }
}



Write-Output "END OF LINE"

