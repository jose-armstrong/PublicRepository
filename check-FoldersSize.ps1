#
# check-FolderSize
param([string]$FolderLocation,[int]$ScanDepth)
<# 
.Synopsis
    The purpose of this script is lo list the size of all the folder under the directory

.Example
#>
#
if (!$FolderLocation) {$FolderLocation = Read-Host "Please enter the folder path"} 
if (!$ScanDepth) {$ScanDepth = Read-Host "How depth do you want to scan"} 
write-host "Starting scan on"$FolderLocation" at level "$ScanDepth
$FolderScanResults = get-childitem -path $FolderLocation -recurse -depth $ScanDepth -ErrorAction SilentlyContinue | sort FullName
# write-host $FolderScanResults
foreach ($i in $FolderScanResults){
    $files = Get-ChildItem -Recurse -Path $i.FullName -ErrorAction SilentlyContinue
    $totalSize = "{0:N0}" -f (($files | Measure-Object -Sum Length -ErrorAction SilentlyContinue).Sum / 1MB)
    write-host "Directory name"$i.FullName"`t`t  Size:"$totalSize" MB"
}
