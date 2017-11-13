$script:DeploymentConfigPath = "$script:IoTSuiteRootPath/Deployment"
$script:DeploymentTemplateFile = "$script:DeploymentConfigPath/ConnectedfactoryMapKey.json"
$script:DeploymentTemplateFileBingMaps = "$script:DeploymentConfigPath/Connectedfactory.json"
$script:VmDeploymentTemplateFile = "$script:DeploymentConfigPath/FactorySimulation.json"
$script:DeploymentSettingsFile = "{0}/{1}.config.user" -f $script:IoTSuiteRootPath, $script:DeploymentName

Function UploadFileToContainerBlob()
{
    Param(
        [Parameter(Mandatory=$true,Position=0)] [string] $filePath,
        [Parameter(Mandatory=$true,Position=1)] [string] $storageAccountName,
        [Parameter(Mandatory=$true,Position=2)] [string] $containerName,
        [Parameter(Mandatory=$true,Position=3)] [bool] $secure
    )

    Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Upload file from '{0}' to storage account '{1}' in resource group '{2} as container '{3}' (secure: {4})" -f $filePath, $storageAccountName, $script:ResourceGroupName, $containerName, $secure)
    $containerName = $containerName.ToLowerInvariant()
    $file = Get-Item -Path "$filePath"
    $fileName = $file.Name
    
    $storageAccountKey = (Get-AzureRmStorageAccountKey -StorageAccountName $storageAccountName -ResourceGroupName $script:ResourceGroupName).Value[0]
    $context = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
    $maxTries = $MAX_TRIES
    if (!(AzureNameExists $storageAccountName "microsoft.storage/storageaccounts" $context.StorageAccount.BlobEndpoint.Host))
    {
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Waiting for storage account '{0} to resolve." -f $context.StorageAccount.BlobEndpoint.Host)
        while (!(AzureNameExists $storageAccountName "microsoft.storage/storageaccounts" $context.StorageAccount.BlobEndpoint.Host) -and $maxTries-- -gt 0)
        {
            Write-Progress -Activity "Resolving storage account endpoint" -Status "Resolving" -SecondsRemaining ($maxTries*$SECONDS_TO_SLEEP)
            ClearDnsCache
            sleep $SECONDS_TO_SLEEP
        }
    }
    New-AzureStorageContainer $ContainerName -Permission Off -Context $context -ErrorAction SilentlyContinue | Out-Null
    # Upload the file
    Set-AzureStorageBlobContent -Blob $fileName -Container $ContainerName -File $file.FullName -Context $context -Force | Out-Null

    # Generate Uri with sas token
    $storageAccount = [Microsoft.WindowsAzure.Storage.CloudStorageAccount]::Parse(("DefaultEndpointsProtocol=https;EndpointSuffix={0};AccountName={1};AccountKey={2}" -f $script:AzureEnvironment.StorageEndpointSuffix, $storageAccountName, $storageAccountKey))
    $blobClient = $storageAccount.CreateCloudBlobClient()
    $container = $blobClient.GetContainerReference($containerName)
    if ($container -ne $null)
    {
        $maxTries = $MAX_TRIES
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Checking container '{0}'." -f $containerName) 
        while (!$container.Exists())
        {
            Write-Progress -Activity "Resolving storage account endpoint" -Status "Checking" -SecondsRemaining ($maxTries*$SECONDS_TO_SLEEP)
            sleep $SECONDS_TO_SLEEP
            if ($maxTries-- -le 0)
            {
                Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Timed out waiting for container: {0}" -f $ContainerName)
                throw ("Timed out waiting for container: {0}" -f $ContainerName)
            }
        }
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Checking blob '{0}'." -f $fileName) 
        $blob = $container.GetBlobReference($fileName)
        if ($blob -ne $null)
        {
            $maxTries = $MAX_TRIES
            while (!$blob.Exists())
            {
                Write-Progress -Activity "Checking Blob existence" -Status "Checking" -SecondsRemaining ($maxTries*$SECONDS_TO_SLEEP)
                sleep $SECONDS_TO_SLEEP
                if ($maxTries-- -le 0)
                {
                    Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Timed out waiting for blob '{0}'" -f $fileName)
                    throw ("Timed out waiting for blob: {0}" -f $fileName)
                }
            }
        }
        else
        {
            Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Cannot find blob for file with name '{0}'" -f $fileName)
        }
    }
    else
    {
        Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Cannot find container with name '{0}'" -f $containerName)
    }

    if ($secure)
    {
        $sasPolicy = New-Object Microsoft.WindowsAzure.Storage.Blob.SharedAccessBlobPolicy
        $sasPolicy.SharedAccessStartTime = [System.DateTime]::Now.AddMinutes(-5)
        $sasPolicy.SharedAccessExpiryTime = [System.DateTime]::Now.AddHours(24)
        $sasPolicy.Permissions = [Microsoft.WindowsAzure.Storage.Blob.SharedAccessBlobPermissions]::Read
        $sasToken = $blob.GetSharedAccessSignature($sasPolicy)
    }
    Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Blob URI is '{0}'" -f $blob.Uri.ToString() + $sasToken)
    return $blob.Uri.ToString() + $sasToken
}

$script:VmArmTemplateUri = UploadFileToContainerBlob $script:VmDeploymentTemplateFile $script:StorageAccount.StorageAccountName "WebDeploy" $true
$script:SimulationUri = UploadFileToContainerBlob "$script:SimulationPath/simulation" $script:StorageAccount.StorageAccountName "WebDeploy" $true
$script:InitSimulationUri = UploadFileToContainerBlob $script:SimulationBuildOutputInitScript $script:StorageAccount.StorageAccountName "WebDeploy" $true
$script:WebAppUri = UploadFileToContainerBlob $script:WebAppLocalPath $script:StorageAccount.StorageAccountName "WebDeploy" -secure $true

# Ensure that our build output is picked up by the ARM deployment.
$script:ArmParameter += @{ `
    webAppUri = $script:WebAppUri; `
    vmArmTemplateUri = $script:VmArmTemplateUri; `
    simulationUri = $script:SimulationUri; `
    initSimulationUri = $script:InitSimulationUri; `
}