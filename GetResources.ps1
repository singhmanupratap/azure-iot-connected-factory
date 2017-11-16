##################################################
Param(
    [string]$BuildId
)
$RootPath="C:\Users\manu.a.pratap.singh\Documents"
$SolutionPath="$RootPath\$BuildId"
$Author="singhmanupratap"
$Name = "azure-iot-connected-factory"
$Branch = "master"
$ZipFile = "$SolutionPath\$Name.zip" 
$OutputFolder = "$SolutionPath\$Branch" 
$GithubTokenVariableAssetName = "4ca285b48582a4f5e4bf0eb7b3a7c733079b8eec"
$RepositoryZipUrl = "https://api.github.com/repos/$Author/$Name/zipball/$Branch" 
# extract the zip 
New-Item -path $SolutionPath -itemtype directory | out-null  
# extract the zip 
New-Item -path $OutputFolder -itemtype directory | out-null 

# download the zip 
Invoke-RestMethod -Uri $RepositoryZipUrl -Headers @{"Authorization" = "token 4ca285b48582a4f5e4bf0eb7b3a7c733079b8eec"} -OutFile $ZipFile 
         
[system.reflection.assembly]::loadwithpartialname('system.io.compression.filesystem') | out-null 
[system.io.compression.zipfile]::extracttodirectory($ZipFile, $OutputFolder) 
     
 
# remove zip 
Remove-Item -Path $ZipFile -Force 
     
#output the path to the downloaded repository 
$ArchiveFolder = (ls $OutputFolder)[0].FullName 

Write-Output "##################################################"
Write-Output $ArchiveFolder
Write-Output "##################################################"
Import-Module "$ArchiveFolder\build.ps1" -ArgumentList 'cloud','release','testfactories','AzureCloud','0','1','Aditya@manuapratapsinghaccenture.onmicrosoft.com','Free Trial','West Europe','Default Directory','man5480U!',$ArchiveFolder,'man5480U#'

#Out-File -Encoding Ascii -FilePath $res -inputObject "Hello $name"
