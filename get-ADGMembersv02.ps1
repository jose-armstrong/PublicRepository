######################
# get-ADGMembers
# Created by: Jose Armstrong
# Created on: 11/10/2020
# Notes: v0.2
######################
# Set variables
$domainname = (get-addomain).DNSRoot
$timestamp = (get-date).ToString('yyyyMMdd-hhmm')
$csvFile = ".\get-adgmembers-results-$domainname-$timestamp.csv"
$GroupCount = $AllADGroups.Count
$CurrentDate = (get-date).ToString('MM-dd-yyyy @ hh:mm')

$allADGroups = get-adgroup -Filter * -Properties ManagedBy | sort name
$GroupCount = $AllADGroups.Count


foreach ($groupName in $allADGroups){ #00
    if ($groupName.ManagedBy) {$gtsManagedBy = get-aduser $groupName.ManagedBy | select Name } 
    $gName = $groupName.Name 
    $gsname = $groupName.SamAccountName
    $gsManagedBy = $gtsManagedBy.name
    Write-Output "GROUPNAME: $gname`tManaged By:$gsManagedBy"
    Write-Output "GROUPNAME:`t$gname`tManaged By:$gsManagedBy" | Out-File -filepath $csvFile -Append
    write-output "`tType`tEnabled`tName`tCreated`tLastLogonDate`temail`tEmployeeID`tManager`tDescription" | Out-File -filepath $csvFile -Append
    $GroupMemberList = get-adgroupmember $gsname | select name,objectclass,samaccountname | sort objectclass,name
    
    Foreach ($Member in $GroupMemberList){ #01
        $Membername = $Member.Name
        $MemberType = $Member.objectclass
        $MemberSAMA = $Member.samaccountname

         if ($MemberType -eq "user"){ #04
            $memberInformation = get-aduser $MemberSAMA -Properties Enabled,created,lastlogondate, emailaddress, employeeid, Manager, Description | select Enabled,created, lastlogondate, emailaddress, employeeid, Manager, Description
            $mStatus = $memberInformation.Enabled
            $mCreated = $memberInformation.created
            $mLastLogonDate = $memberInformation.lastlogondate
            $meMail = $memberInformation.emailaddress
            $mEmployeeID = $memberInformation.employeeid
            $msamaManager = $memberInformation.Manager
            if ($msamaManager) {$mManager = (get-aduser $msamaManager).Name} else {$mManager = ""}
            $mDescription = $memberInformation.Description
            write-output "`t$MemberType`t$mStatus`t$memberName`t$mCreated`t$mLastLogonDate`t$memail`t$mEmployeeID`t$mManager`t$mDescription" | Out-File -filepath $csvFile -Append

         } #04

         if ($MemberType -eq "group"){ #05

            $MemberStatus = "N\A"
            Write-Output "`tSubGroup: $Membername"
            write-output "`tSubGroup: $MemberName" | Out-File -filepath $csvFile -Append
            $subGroupMemberList = get-adgroupmember $MemberSAMA | select name,objectclass,samaccountname | sort name
            
            Foreach ($SubMember in $SubGroupMemberList){ #02
                       $SubMembername = $SubMember.Name
                       $SubMemberType = $SubMember.objectclass
                       $SubMemberSAMA = $SubMember.samaccountname

                       if ($subMemberType -eq "user"){ #03
                            $smemberInformation = get-aduser $subMemberSAMA -Properties Enabled,created,lastlogondate, emailaddress, employeeid, Manager, Description | select Enabled,created, lastlogondate, emailaddress, employeeid, Manager, Description
                            $smStatus = $smemberInformation.Enabled
                            $smCreated = $smemberInformation.created
                            $smLastLogonDate = $smemberInformation.lastlogondate
                            $smeMail = $smemberInformation.emailaddress
                            $smEmployeeID = $smemberInformation.employeeid
                            $smsamaManager = $smemberInformation.Manager
                            if ($smsamaManager) {$smManager = (get-aduser $smsamaManager).Name} else {$smManager = ""}
                            $smDescription = $smemberInformation.Description
                            write-output "`tSubGroup-$subMemberType`t$smStatus`t$subMemberName`t$smCreated`t$smLastLogonDate`t$smemail`t$smEmployeeID`t$smManager`t$smDescription" | Out-File -filepath $csvFile -Append
                           
                           # write-output "`t---`t$subMemberType`t$subMemberStatus`t$subMemberName" | Out-File -filepath $csvFile -Append
                       } #03

         }  #02
         
            } #05
         } #01
    Write-Output "" | Out-File -filepath $csvFile -Append
    } #00

Write-Output "`n================================="
Write-Output "Domain $DomainName has $GroupCount Groups."
Write-Output "Script ran on $CurrentDate."

         