c:\#import-module activedirectory
#import-module grouppolicy
#import-module PSDiagnostics
#import-module TroubleshootingPack
#import-module C:\Users\joarms\Documents\windowspowershell\modules\jose-tools.psm1
#
# ================================================================================= #
#  Working with variables,arrays
#
#get-variable                     # Get variable information (SET)
#measure-object                   # Count 
#
# ================================================================================= #
#
# Get User Information
#
# get-aduser user1 -properties * | select samaccountname,Name,CanonicalName,DistinguishedName,mail,LastBadPasswordAttempt,Lockedout,PasswordLastSet,WhenChanged,WhenCreated
# 
# FIND USER BY LASTNAME
# get-aduser -filter {Surname -like "Armstrong"}
# 
# FIND USER BY NAME
# get-aduser -filter {Givenname -like "Armstrong"}
#
# ALL USERS CREATED ON THE LAST 7 DAYS
# get-aduser -filter * -Properties * | where {$_.WhenCreated -gt ((get-date).AddDays(-7))} | select name, whencreated
#
#
# ================================================================================= #
# #SEARCH
#
#search-adaccount -lockedout                                                                                                                   # Lockout accounts
#
#search-adaccount -accountdisabled                                                                                                             # Disabled Accounts
#
#search-adaccount -accountdisabled | select Name,SamAccountName,lastLogonDate | sort name
#
#search-adaccount -accountexpired                                                                                                              # Expirer account
#
#search-adaccount -accountexpiring
#
#search-adaccount -accountinactive -timespan 90                                                                                                
#
# Account Inactive after X days
#Search-ADAccount -AccountInactive -DateTime ((get-date).adddays(-90)) -UsersOnly | select name,LastLogonDate,enabled | sort name
#
# ACCOUNTS WITH EXPIRER PASSWORD
#search-adaccount -passwordexpired
#
#Account with password that never expirer
#search-adaccount -passwordNeverexpires
#
# ================================================================================= #
#
# Find Delete Objects on Active Directory (AD)
#
#$xAccountName = "*s_quest_fog"
#$xAccountName = read-host "What Account?"
#get-adobject -filter {samaccountName -like $xAccountName} -IncludeDeletedObjects -Properties * | Select Name, samAccountName, Isdeleted, LastKnownParent, WhenCreated, WhenChanged, objectclass | sort Name | fl                           # Find account by samaccountname
#get-adobject -filter {objectsid -eq "S-1-5-21-675877366-1047755519-1629300891-41047"} -IncludeDeletedObjects -Properties * | Select Name, samAccountName, Isdeleted, LastKnownParent, WhenCreated, WhenChanged, objectclass | fl           # Find Account by SID
#Get-ADobject -filter * -SearchBase "cn=Deleted Objects,dc=tcbna,dc=net" -IncludeDeletedObjects -Properties * | select name,WhenChanged | sort name
#
# Restore Delete Objects on Active Directory (AD)
#
#get-adobject -filter {samaccountname -eq "s_quest_fog"} -IncludeDeletedObjects -properties *| Foreach-Object {Restore-ADObject $_.objectguid -NewName $_.samaccountname -TargetPath $_.LastKnownParent}                                    # Restore AD account using samaccount
#
# ================================================================================= #
#
# Get Group Information
#
#$xinput_group1 = "Service Accounts - Deny Interactive Logon"
#get-adgroup $xInput_group1 -properties * | select samaccountname,Name,CanonicalName,DistinguishedName,IsDeleted,GroupCategory,GroupScope,mail,WhenChanged,WhenCreated
#get-adgroupmember $xInput_group1 -recursive | Select Name,samaccountname,objectclass | Sort name
#
# All the group that user is memberof
# foreach ($group in (Get-ADuser -identity $xuser -Properties memberof | Select-Object -ExpandProperty memberof )) { Get-ADGroup $group | select name,groupscope,groupcategory | sort name}
#
# ================================================================================= #
#
# Get Domain Controllers
#
#get-adcomputer -filter * -searchbase "ou=domain controllers,dc=tcbna,dc=net"  | select name | sort name
#
#get-addomaincontroller
# get-ADDomainController -Filter * 
#
#[System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().GlobalCatalogs          # Global catalogs
#
# ================================================================================= #
#
# Get all Servers on the domain
#
# Get-adcomputer -filter 'OperatingSystem -like "*server*"'
# get-adcomputer –filter * -Properties name,DNSHostName,CanonicalName,OperatingSystem | sort CanonicalName | ft -autosize
# get-adcomputer –filter * -Properties name,DNSHostName,CanonicalName,OperatingSystem | sort CanonicalName | export-csv computer_list.csv 
#
# ================================================================================= #
#
# Get Event logs (Get-WinEvent)
#
#
#$xServerName = "CDPIADCTDC2"
#$xEntryType = "Error"                                                                                                              # Entry Types (Error/Information/FailureAudit/SuccessAUdit/Warning)
#$xAfterDate = "09/12/2016 00:01"
#$xBeforeDate = "09/01/2016 23:59"
#$xEventlog = "System"
#
#get-winevent -logname security -computername $xServerName                                                                         # Get security log files
#get-winevent -logname security -computername $xServerName | where-object {$_.EventID –eq “4933”}                                  # Get a event on the Security Logs
#get-winevent -logname application -computername $xServerName                                                                      # Get security log files
#get-winevent -logname system -computername $xServerName                                                                           # Get security log files
#
#
#
# Get Event Log (Get-EventLog)
#
#get-eventlog -list -computername $xServerName                                                                                      # Get the computer event-log list
#get-eventlog -logname $xEventlog -computername $xServerName                                                                            # Get the computer system event-logs
#get-eventlog -logname $xEventlog -computername $xServerName -newest 50                                                                 # Get the computer last x system event-logs 
#get-eventlog -logname $xEventlog -computername $xServerName -EntryType $xEntryType                                                     # Get the computer system Entrytype event-logs 
#get-eventlog -logname $xEventlog -computername $xServerName -After $xAfterDate -Before $xBeforeDate                                    # Get the computer system event-logs between after and before dates  
#get-eventlog -logname $xEventlog -computername $xServerName -After $xAfterDate                                    # Get the computer system event-logs between after and before dates  
#get-eventlog -logname $xEventlog" -computername RDPIADCTDC2 -EntryType Error -After $xAfterDate
#
#
# ================================================================================= #
#
# Get AD FSMO roles
# TAG:#activedirectory, #domaincontrollers
# 
# write "Get FSMO Roles"
# get-addomain | select InfrastructureMaster,PDCEmulator,RIDMaster | FL
# get-adforest | select DomainNamingMaster,SchemaMaster | FL
#
# ================================================================================= #
#
# LIST Windows Updates
# TAG: #updates, #windowsupdates
#
# get-hotfix
#
#
# Get Windows Updates Packages using dism
# dism /online /get-packages                                                                              # Get Windows Updates Packages using dism
# dism /online /get-packages | findstr KB2952664                                                          # Find specific package by KB Number
# dism /online /remove-package /PackageName:Package_for_KB2952664~31bf3856ad364e35~amd64~~6.1.1.3         # Remove a package
#
# ================================================================================= #
#
#  Time Synchronization
#
#net time \\<DC_name_or_IP> /set /y                                          # To force a computer to synchronize its time with a specific DC
#w32tm /stripchart /computer:time.windows.com /dataonly                      # To check your DC's current time settings against an external time server such as time.windows.com.
#W32tm /resync /computer:time.windows.com /nowait                            # To synchronize the DC's current system time with an external time server such as time.windows.com
#
#================================================================================= #
#
# Ping all domain controllers
# TAG: #activedirectory, #domaincontrollers
#
#$lDC = (get-adcomputer -filter * -SearchBase "ou=domain controllers,dc=tcbna,dc=net" | sort name | select name)
#test-connection $lDC.Name
#
#
#================================================================================= #
#
# Find groups created on the last 7 days
#
# $xTargetDate = (get-date).AddDays(-7)
# Get-adgroup -Filter * -Properties * | where {$_.Created -gt $xTargetDate} | select name,created | sort Name
#
#
#=================================================================================
#
#
# Get folder size of current folder
#
#
# "{0:N2} MB" -f ((get-ChildItem . -Recurse | Measure-Object -Property Length -sum -ErrorAction Stop).sum /1MB)
#
#
# Get size of files and folders 
#
# $xListDirectories = gci . | select FullName
# foreach ($i in $xListDirectories) 
#    {
#    $xDirectorySize = "{0:N2} GB" -f ((get-ChildItem $i.FullName -Recurse | Measure-Object -Property Length -sum -ErrorAction Stop).sum /1GB)
#    write-host $xDirectorySize `t $i.FullName
#    }
#
#
#
#=================================================================================
#=================================================================================
#=================================================================================
# VMWARE POWERCLI COMMANDS
# TAG: #powercli
#
# Connect-viserver rlpmvsphas2,rdpmvsphas2,cdpmvsphas2 -Verbose
#
# FIND ALL VM PowerOFF and ADD THE ASSGIN STORAGE
# TAG: #powercli
#
# get-vm * | where {$_.PowerState -eq "PoweredOff"} | Get-HardDisk | select Parent, filename, capacityGB | Measure-Object -Property CapacityGB  -Sum
#
#
# FIND ALL VM PowerOFF and SUM THE ASSGIN MEMORY
# TAG: #powercli
#
# get-vm * | where {$_.PowerState -eq "PoweredOff"} | Get-HardDisk | select Parent, filename, capacityGB | Measure-Object -Property CapacityGB  -Sum
#
#
########################################################################
#
#  Start KeePass
# & 'C:\data\keepass\Jose''s Safe-2.kdbx'
#
#
#  start new powershell session
#
# start-process powershell.exe -Credential "oncalld120\a_joarms"
#
#=================================================================================
#=================================================================================
#=================================================================================

# Find Null Attributes (Not in use)
#   Example Employee Type
#
#   get-aduser -Filter * -Properties *  | Where {$_.employeetype -ne $null} | select name,employeeType

