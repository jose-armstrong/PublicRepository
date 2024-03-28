# Check-ADGroupsonGroups.ps1
#
#
#
# This script will find nested group (Groups inside Groups
#
)


Param ([string]$DisplayName)

if (!$DisplayName) {$xRootGroupName = Read-Host "Group Display name?"} else {$xRootGroupName = $DisplayName }

$xGroupMembers = ""
$xGroupMembers = Get-ADGroupMember $xRootGroupName | Where {$_.objectclass -eq 'group'} |select name,objectclass | sort name 
 
if (!$xGroupMembers) {
    write "There are not groups inside $xRootGroupName"     
} else {
    write "Group $xRootGroupName has the following groups as members"
    $xGroupMembers | ft -AutoSize
    write " "
    Write "Here is the list of members per group."
    write " "
}


foreach ($subGroup in $xGroupMembers) {
    $gpname = $subgroup.name
    write "============================================================="
    Write "Members of group: $gpname"
    Get-ADGroupMember -Identity $gpname | select name, samaccountname, objectclass | sort name | ft -AutoSize
    write " "
}

