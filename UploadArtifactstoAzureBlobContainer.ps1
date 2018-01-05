Param(
	[Parameter(Position=0, Mandatory=$true, HelpMessage="Specify the Repository Local Path.")]
	[string] $BuildRepositoryLocalPath="C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory",
	[Parameter(Mandatory=$false, HelpMessage="Specify the name of the solution")]
	[ValidatePattern("^(?![0-9]+$)(?!-)[a-zA-Z0-9-]{3,49}[a-zA-Z0-9]{1,1}$")]
	[ValidateLength(3, 62)]
	[string] $DeploymentName = "myfactories",
	[Parameter(Mandatory=$false, HelpMessage="Specify the name of the Azure environment to deploy your solution into.")]
	[ValidateSet("AzureCloud")]
	[string] $AzureEnvironmentName = "AzureCloud",
	[Parameter(Mandatory=$false, HelpMessage="Specify the Azure location to use for the Azure deployment.")]
	[string] $ServicePrincipalId = "be4baceb-25a1-4b6b-bde8-eb7122183185",
	[Parameter(Mandatory=$false, HelpMessage="Specify the Azure location to use for the Azure deployment.")]
	[string] $ServicePrincipalPassword = "man5480U#",
	[Parameter(Mandatory=$false, HelpMessage="Specify the Azure location to use for the Azure deployment.")]
	[string] $AzureSubscriptionId = "54ecce53-5b7e-4faa-870c-ac479b0b83d7",
	[Parameter(Mandatory=$false, HelpMessage="Specify the Azure location to use for the Azure deployment.")]
	[string] $AzureTenantId = "3a8245c0-3fee-45f8-b985-3b71f26ebe84",
	[Parameter(Mandatory=$false, HelpMessage="Specify the Azure location to use for the Azure deployment.")]
	[string] $PresetAzureLocationName="West Europe"
)
#Import-Module "C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory\UploadArtifactstoAzureBlobContainer.ps1" -ArgumentList 'C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory','myfactories','AzureCloud','Aditya@manuapratapsinghaccenture.onmicrosoft.com','man5480U#','54ecce53-5b7e-4faa-870c-ac479b0b83d7','3a8245c0-3fee-45f8-b985-3b71f26ebe84','West Europe'

Function AddAzureContext()
{
	$password = ConvertTo-SecureString $script:ServicePrincipalPassword -AsPlainText -Force
	$credential = New-Object System.Management.Automation.PSCredential($script:ServicePrincipalId, $password)
	$account = Add-AzureRmAccount -ServicePrincipal -Environment $script:AzureEnvironment.Name -Credential $credential -SubscriptionId $script:AzureSubscriptionId -TenantId $script:AzureTenantId
	Select-AzureRmSubscription -SubscriptionName $account.Context.Subscription.Name
	Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) Subscription used '{0}'" -f $account.Context.Subscription.Id)
	return $account.Context
}

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

Function GetResourceGroup()
{
    $resourceGroup = Find-AzureRmResourceGroup -Tag @{"IotSuiteType" = $script:SuiteType} | ?{$_.Name -eq $script:SuiteName}
    if ($resourceGroup -eq $null)
    {
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) No resource group found with name '{0}' and type '{1}'" -f $script:SuiteName, $script:SuiteType)
        # If the simulation should be updated, it is expected that the resource group exists
        if ($script:Command -ne "updatesimulation")
        {
            Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) GetResourceGroup Location: '{0}, IoTSuiteVersion: '{1}'" -f $script:AzureLocation, $script:IotSuiteVersion)
            return New-AzureRmResourceGroup -Name $script:SuiteName -Location $script:AzureLocation -Tag @{"IoTSuiteType" = $script:SuiteType ; "IoTSuiteVersion" = $script:IotSuiteVersion ; "IoTSuiteState" = "Created"}
        }
        else
        {
            return $null
        }
    }
    else
    {
        return Get-AzureRmResourceGroup -Name $script:SuiteName 
    }
}

Function AzureNameExists() {
     Param(
        [Parameter(Mandatory=$true,Position=0)] [string] $resourceBaseName,
        [Parameter(Mandatory=$true,Position=1)] [string] $resourceType,
        [Parameter(Mandatory=$true,Position=2)] [string] $resourceUrl
    )

    switch ($resourceType.ToLowerInvariant())
    {
        "microsoft.storage/storageaccounts"
        {
			$storageAccount = Get-AzureRmStorageAccount | where {$_.ResourceGroupName -eq $script:ResourceGroupName -and $_.StorageAccountName -eq $resourceBaseName}
            return ($storageAccount -ne $null)
        }
        "microsoft.eventhub/namespaces"
        {
            return Test-AzureName -ServiceBusNamespace $resourceBaseName
        }
        "microsoft.web/sites"
        {
            return Test-AzureName -Website $resourceBaseName
        }
        "microsoft.devices/iothubs"
        {
            if($script:CorruptedIotHubDNS)
            {
                return HostReplyRequest("https://{0}.{1}/devices" -f $resourceBaseName, $resourceUrl)
            }
            else
            {
                return HostEntryExists ("{0}.{1}" -f $resourceBaseName, $resourceUrl)
            }
        }
        default 
        {
            return $true
        }
    }
}

Function ClearDnsCache()
{
    if ($ClearDns -eq $null)
    {
        try 
        {
            $ClearDns = CheckCommandAvailability Clear-DnsClientCache
        }
        catch 
        {
            $ClearDns = $false
        }
    }
    if ($ClearDns)
    {
        Clear-DnsClientCache
    }
}

Function GetUniqueResourceName()
{
    Param(
        [Parameter(Mandatory=$true,Position=0)] [string] $resourceBaseName,
        [Parameter(Mandatory=$true,Position=1)] [string] $resourceType,
        [Parameter(Mandatory=$true,Position=2)] [string] $resourceUrl
    )

    # retry max 200 times if the random name already exists
    $max = 200
    $name = $resourceBaseName
    while (AzureNameExists $name $resourceType $resourceUrl)
    {
        $name = "{0}{1:x5}" -f $resourceBaseName, (get-random -max 1048575)
        if ($max-- -le 0)
        {
            Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Unable to create unique name for resource {0} for url {1}" -f $name, $resourceUrl)
            throw ("Unable to create unique name for resource {0} for url {1}" -f $name, $resourceUrl)
        }
    }
    ClearDnsCache
    return $name
}

Function ValidateResourceName()
{
    Param(
        [Parameter(Mandatory=$true,Position=0)] [string] $resourceBaseName,
        [Parameter(Mandatory=$true,Position=1)] [string] $resourceType
    )

    # Generate a unique name
    $resourceUrl = " "
    $allowNameReuse = $true
    switch ($resourceType.ToLowerInvariant())
    {
        "microsoft.devices/iothubs"
        {
            $resourceUrl = $script:IotHubSuffix
        }
        "microsoft.storage/storageaccounts"
        {
            $resourceUrl = "blob.{0}" -f $script:AzureEnvironment.StorageEndpointSuffix
            $resourceBaseName = $resourceBaseName.Substring(0, [System.Math]::Min(19, $resourceBaseName.Length))
        }
        "microsoft.web/sites"
        {
            $resourceUrl = $script:WebsiteSuffix
        }
        "microsoft.network/publicipaddresses"
        {
            $resourceBaseName = $resourceBaseName.Substring(0, [System.Math]::Min(40, $resourceBaseName.Length))
        }
        "microsoft.compute/virtualmachines"
        {
           return  $resourceBaseName.Substring(0, [System.Math]::Min(64, $resourceBaseName.Length))
        }
        "microsoft.timeseriesinsights/environments"
        {
           return  $resourceBaseName.Substring(0, [System.Math]::Min(64, $resourceBaseName.Length))
        }
        default {}
    }
    
    # Return name for existing resource if exists
    Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Check if Azure resource: '{0}' (type: '{1}') exists in resource group '{2}'" -f $resourceBaseName, $resourceType, $resourceGroupName)
    $resources = Find-AzureRmResource -ResourceGroupNameContains $script:ResourceGroupName -ResourceType $resourceType -ResourceNameContains $resourceBaseName
    if ($resources -ne $null -and $allowNameReuse)
    {
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Found the resource. Validating exact naming.")
        foreach($resource in $resources)
        {
            if ($resource.ResourceGroupName -eq $script:ResourceGroupName -and $resource.Name.ToLowerInvariant().StartsWith($resourceBaseName.ToLowerInvariant()))
            {
                Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Resource with matching resource group name and name found.")
                return $resource.Name
            }
        }
    }
    
    return GetUniqueResourceName $resourceBaseName $resourceType $resourceUrl
}

Function GetAzureStorageAccount()
{
    $storageTempName = $script:SuiteName.ToLowerInvariant().Replace('-','')
    $storageAccountName = ValidateResourceName $storageTempName.Substring(0, [System.Math]::Min(19, $storageTempName.Length)) Microsoft.Storage/storageAccounts
    $storage = Get-AzureRmStorageAccount -ResourceGroupName $script:ResourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue
    if ($storage -eq $null)
    {
		Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Storage
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Creating new storage account: '{0}" -f $storageAccountName)
        $storage = New-AzureRmStorageAccount -ResourceGroupName $script:ResourceGroupName -StorageAccountName $storageAccountName -Location $script:AzureLocation -Type $script:StorageSkuName -Kind $script:StorageKind
    }
    return $storage
}
Write-Output "BuildRepositoryLocalPath  ######$script:BuildRepositoryLocalPath#######"
Write-Output "DeploymentName ######$script:DeploymentName#######"
Write-Output "AzureEnvironmentName ######$script:AzureEnvironmentName#######"
Write-Output "ServicePrincipalId ######$script:ServicePrincipalId#######"
Write-Output "AzureSubscriptionId ######$script:AzureSubscriptionId#######"
Write-Output "PresetAzureLocationName ######$script:PresetAzureLocationName#######"
Write-Output "AzureTenantId ######$script:AzureTenantId#######"

$script:Command = "cloud"
$script:Configuration = "release"
$script:SuiteName = $script:DeploymentName
$script:IoTSuiteRootPath = $BuildRepositoryLocalPath
$script:SuiteType = "Connectedfactory"
$script:AzureLocation = $script:PresetAzureLocationName
$script:WebAppLocalPath = "$script:IoTSuiteRootPath/WebApp/obj/{0}/Package/WebApp.zip" -f $script:Configuration
$script:DeploymentConfigPath = "$script:IoTSuiteRootPath/Deployment"
$script:DeploymentTemplateFile = "$script:DeploymentConfigPath/ConnectedfactoryMapKey.json"
$script:DeploymentTemplateFileBingMaps = "$script:DeploymentConfigPath/Connectedfactory.json"
$script:VmDeploymentTemplateFile = "$script:DeploymentConfigPath/FactorySimulation.json"
$script:DeploymentSettingsFile = "{0}/{1}.config.user" -f $script:IoTSuiteRootPath, $script:DeploymentName
$script:IotSuiteVersion = Get-Content ("{0}/VERSION.txt" -f $script:IoTSuiteRootPath)
$script:SimulationPath = "$script:IoTSuiteRootPath/Simulation"
$script:SimulationBuildOutputPath = "$script:SimulationPath/Factory/buildOutput"
$script:SimulationBuildOutputInitScript = "$script:SimulationBuildOutputPath/initsimulation"
if ((Get-AzureRMEnvironment AzureCloud) -eq $null)
{
    Write-Verbose  "$(Get-Date –f $TIME_STAMP_FORMAT) - Can not find AzureCloud environment. Adding it."
    Add-AzureRMEnvironment –Name AzureCloud -EnableAdfsAuthentication $False -ActiveDirectoryServiceEndpointResourceId https://management.core.windows.net/ -GalleryUrl https://gallery.azure.com/ -ServiceManagementUrl https://management.core.windows.net/ -SqlDatabaseDnsSuffix .database.windows.net -StorageEndpointSuffix core.windows.net -ActiveDirectoryAuthority https://login.microsoftonline.com/ -GraphUrl https://graph.windows.net/ -trafficManagerDnsSuffix trafficmanager.net -AzureKeyVaultDnsSuffix vault.azure.net -AzureKeyVaultServiceEndpointResourceId https://vault.azure.net -ResourceManagerUrl https://management.azure.com/ -ManagementPortalUrl http://go.microsoft.com/fwlink/?LinkId=254433
}

# Initialize public cloud suffixes.
$script:IotHubSuffix = "azure-devices.net"
$script:WebsiteSuffix = "azurewebsites.net"
$script:RdxSuffix = "timeseries.azure.com"
$script:docdbSuffix = "documents.azure.com"
# Set locations were all resource are available. This might need to get updated if resources are deployed to more locations.
$script:AzureLocations = @("West US", "North Europe", "West Europe")

$script:StorageSkuName = "Standard_LRS"
$script:StorageKind = "Storage"

$script:AzureEnvironment = Get-AzureEnvironment $script:AzureEnvironmentName
$script:AzureContext = AddAzureContext
$script:ResourceGroupName = (GetResourceGroup).ResourceGroupName
$script:StorageAccount = GetAzureStorageAccount
# Copy the factory simulation template, the factory simulation binaries and the VM init script into the WebDeploy container.
Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Upload all required files into the storage account.")
$script:VmArmTemplateUri = UploadFileToContainerBlob $script:VmDeploymentTemplateFile $script:StorageAccount.StorageAccountName "WebDeploy" $true
$script:SimulationUri = UploadFileToContainerBlob "$script:SimulationPath/simulation" $script:StorageAccount.StorageAccountName "WebDeploy" $true
$script:InitSimulationUri = UploadFileToContainerBlob $script:SimulationBuildOutputInitScript $script:StorageAccount.StorageAccountName "WebDeploy" $true
$script:WebAppUri = UploadFileToContainerBlob $script:WebAppLocalPath $script:StorageAccount.StorageAccountName "WebDeploy" -secure $true

# Ensure that our build output is picked up by the ARM deployment.
# Set up ARM parameters.
$script:ArmParameter = @{ `
	webAppUri = $script:WebAppUri; `
    vmArmTemplateUri = $script:VmArmTemplateUri; `
    simulationUri = $script:SimulationUri; `
    initSimulationUri = $script:InitSimulationUri; `
}
$script:TemplateParameteLocalFile = "$script:IoTSuiteRootPath/ArmParameter.json"
$script:ArmParameter | ConvertTo-Json -depth 100 | Out-File $script:TemplateParameteLocalFile
$script:TemplateUri = UploadFileToContainerBlob $script:DeploymentTemplateFile $script:StorageAccount.StorageAccountName "WebDeploy" -secure $true
$script:TemplateParameterUri = UploadFileToContainerBlob $script:TemplateParameteLocalFile $script:StorageAccount.StorageAccountName "WebDeploy" -secure $true

Write-Output $script:TemplateUri
Write-Output $script:TemplateParameterUri
Write-Host ("##vso[task.setvariable variable=TemplateUri;]$script:TemplateUri")
Write-Host ("##vso[task.setvariable variable=TemplateParameterUri;]$script:TemplateParameterUri")