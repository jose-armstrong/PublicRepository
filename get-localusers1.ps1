###################################
# Created by: Jose Armstrong
# Created on: 10/9/2020
# Modified on: 
# Notes: v1
#   # This script will be run on remote computer using the SECM.
#   # The result will be a one-line that will list all the local account on the computer.
#   # The fields are; username, full name, Disabled status, Domain
###################################

#Get-LocalUsers1V1

# $Computer = $env:COMPUTERNAME
# $Domain = (Get-WmiObject Win32_ComputerSystem).Domain
$users = Get-WmiObject -class win32_userAccount -Namespace "root\cimv2" -Filter "Localaccount='$true'"


foreach ($user in $users) {
    $Username = $user.Name
    $Fullname = $User.FullName
    $Domain = $User.Domain
    $Disabled = $User.Disabled
    $Description = $user.Description
    write-output ";$UserName;$Fullname;$Disabled;$Domain;"

}

