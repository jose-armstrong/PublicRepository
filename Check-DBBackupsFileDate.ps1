# Check-FilesWriteAfter
# 
# This script will scan a target directory and list any file that been updated over a specific period of time.

    
    
    param($TargetDirectory,$NumberofDays)
    <# 
    .Synopsis
    
    Check-FilesWriteAfter
   
    This script will scan a target directory and list any file that been updated over a specific period of time.

    Paramaters
     -TargetDirectory:  The directory where the scan will take place
     -NumberofDays: How many days back will scan for a file update.
    
    .Example
    
    #>

    if (!$TargetDirectory) {$TargetDirectory = Read-host "Enter the target directory name"} else {}
    if (!$NumberofDays) {$NumberofDays = Read-host "How many days back do you want to scan?"} else {}
    #
    $cutOffDate = (Get-Date).AddDays(-$NumberofDays)
    #
    write-host " "
    Write-Host "Scan target directory: "$TargetDirectory
    write-host "Scanning for backups file that have been that have been created or modified before $cutOffDate"
    write-host " "
    $xListofFiles = Get-ChildItem -Path $targetdirectory -Recurse -erroraction Ignore| Where-Object {$_.LastWriteTime -lt $cutOffDate} | select name,directory,length, LastWriteTime 
    $xTotalLength = "{0:N0} GB" -f ((Get-ChildItem -Path $targetdirectory -Recurse -erroraction Ignore| Where-Object {$_.LastWriteTime -lt $cutOffDate -and $_.Name -like "*.bak"} | Measure-Object -Property length -sum -ErrorAction Stop).sum/1GB)

    write-host "Size`t`t`tDate`t`t`tFile Directory \ Name"
    write-host "=================================================================================================="
    foreach ($xFile in $xListofFiles) {
        if ($xFile.name -like "*.bak"){             
            $xGBLength = "{0:N0}"-f ($xFile.length/1GB)
            write-host $xGBLength "GB`t`t"$xFile.LastWriteTime"`t"$xfile.directory"\"$xFile.name
           
        }
    }

    Write-host "Files Total Size: "$xTotalLength

     

    