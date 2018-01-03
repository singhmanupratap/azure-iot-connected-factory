Param(
		[Parameter(Mandatory=$false,Position=0)] [string] $subscriptionId="54ecce53-5b7e-4faa-870c-ac479b0b83d7",
		[Parameter(Mandatory=$false,Position=1)] [string] $username="743fcf27-47ba-4d19-9424-c48525ffa21a",
		[Parameter(Mandatory=$false,Position=2)] [string] $password="MAN5480U#",
		[Parameter(Mandatory=$false,Position=3)] [string] $location="West Europe",
		[Parameter(Mandatory=$false,Position=4)] [string] $resourceGroup="rg-fc-ondemanddemo",
        [Parameter(Mandatory=$false,Position=5)] [string] $filePath="C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory\Adityaa@manuapratapsinghaccenture.onmicrosoft.com.user",
        [Parameter(Mandatory=$false,Position=6)] [string] $storageAccountName="rgfcondemanddemostorage",
        [Parameter(Mandatory=$false,Position=7)] [string] $containerName= "configfiles"
    )
    #$file = Get-Item -Path "$filePath"
    $fileName = Split-Path $filePath -leaf
	$password = ConvertTo-SecureString $password -AsPlainText -Force
	$credential = New-Object System.Management.Automation.PSCredential($username, $password)
	#Login-AzureRmAccount -EnvironmentName "AzureCloud" -Credential $credential -SubscriptionId $subscriptionId -ErrorAction Stop | Out-Null
	#Login-AzureRmAccount -ServicePrincipal -ApplicationId  "743fcf27-47ba-4d19-9424-c48525ffa21a" -Credential $pscredential -TenantId $tenantid
    
    #$creds = Get-Credential #3a8245c0-3fee-45f8-b985-3b71f26ebe84
    Login-AzureRmAccount -Credential $credential -ServicePrincipal -TenantId {3a8245c0-3fee-45f8-b985-3b71f26ebe84} -SubscriptionId $subscriptionId

    if (!(Test-AzureName -Storage $storageAccountName))
    {
		$storageAccount = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup `
		-Name $storageAccountName `
		-Location $location `
		-SkuName Standard_LRS `
		-Kind Storage `
		-EnableEncryptionService Blob
		$storageAccountKey = (Get-AzureRmStorageAccountKey -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroup).Value[0]
		$context = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
		New-AzureStorageContainer $containerName -Permission Off -Context $context -ErrorAction SilentlyContinue | Out-Null
	}
	else{
        $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup `
	    -Name $storageAccountName
        $context = $storageAccount.Context
	}
    
    # Upload the file
    Set-AzureStorageBlobContent -Blob $fileName -Container $containerName -File $filePath -Context $context -Force | Out-Null

    #Get-AzureStorageBlobContent -Blob $fileName -Container $containerName -Destination "$filePath" -Context $context -Force | Out-Null