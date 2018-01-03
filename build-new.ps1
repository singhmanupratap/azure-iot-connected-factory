Param(
	[Parameter(Position=0, Mandatory=$true, HelpMessage="Specify the Repository Local Path.")]
	[string]$BuildRepositoryLocalPath="C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory",
	[Parameter(Mandatory=$false, HelpMessage="Specify the configuration for build.")]
	[string]$Configuration="release",
	[Parameter(Mandatory=$false, HelpMessage="Specify the name of the solution")]
	[ValidatePattern("^(?![0-9]+$)(?!-)[a-zA-Z0-9-]{3,49}[a-zA-Z0-9]{1,1}$")]
	[ValidateLength(3, 62)]
	[string] $DeploymentName = "myfactories"
)

#Import-Module "C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory\build-new.ps1" -ArgumentList 'C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory','release','myfactories'
#,'AzureCloud','0','1','Aditya@manuapratapsinghaccenture.onmicrosoft.com','Visual Studio Professional with MSDN','West Europe','Default Directory','man5480U!','C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory','man5480U#'

Function InstallNuget()
{
    $nugetPath = "{0}/.nuget" -f $script:IoTSuiteRootPath
    if (-not (Test-Path "$nugetPath")) 
    {
        New-Item -Path "$nugetPath" -ItemType "Directory" | Out-Null
    }
    if (-not (Test-Path "$nugetPath/nuget.exe"))
    {
        $sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
        $targetFile = $nugetPath + "/nuget.exe"
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - 'nuget.exe' not found. Downloading latest from $sourceNugetExe ...")
        Invoke-WebRequest $sourceNugetExe -OutFile "$targetFile"
    }
}
Function Find-MsBuild([int] $MaxVersion = 2017)  
{
    $agentPath = "$Env:programfiles `(x86`)\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\msbuild.exe"
    $devPath = "$Env:programfiles `(x86`)\Microsoft Visual Studio\2017\Enterprise\MSBuild\15.0\Bin\msbuild.exe"
    $proPath = "$Env:programfiles `(x86`)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\msbuild.exe"
    $communityPath = "$Env:programfiles `(x86`)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\msbuild.exe"
    $fallback2015Path = "${Env:ProgramFiles(x86)}\MSBuild\14.0\Bin\MSBuild.exe"
    $fallback2013Path = "${Env:ProgramFiles(x86)}\MSBuild\12.0\Bin\MSBuild.exe"
    $fallbackPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319"

    If ((2017 -le $MaxVersion) -And (Test-Path $agentPath)) { return $agentPath } 
    If ((2017 -le $MaxVersion) -And (Test-Path $devPath)) { return $devPath } 
    If ((2017 -le $MaxVersion) -And (Test-Path $proPath)) { return $proPath } 
    If ((2017 -le $MaxVersion) -And (Test-Path $communityPath)) { return $communityPath } 
    If ((2015 -le $MaxVersion) -And (Test-Path $fallback2015Path)) { return $fallback2015Path } 
    If ((2013 -le $MaxVersion) -And (Test-Path $fallback2013Path)) { return $fallback2013Path } 
    If (Test-Path $fallbackPath) { return $fallbackPath } 

    throw "Unable to find msbuild"
}
Function FindMsBuildFilePath([int] $MaxVersion = 2017)  
{
   $msbuildPath = Find-MsBuild 
	Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - MS BUILD PATH '{0}'." -f $msbuildPath)
	$fs = New-Object -ComObject Scripting.FileSystemObject
	$f = $fs.GetFile($msbuildPath)
	return $f.shortpath   
}

Function Build()
{
    # Check installation of required tools.
    #CheckCommandAvailability "msbuild.exe" | Out-Null

    # Restore packages.
    Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Restoring nuget packages for solution.")
    Invoke-Expression "$script:IoTSuiteRootPath/.nuget/nuget.exe restore $script:IoTSuiteRootPath/Connectedfactory.sln"
    if ($LASTEXITCODE -ne 0)
    {
        Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Restoring nuget packages for solution failed.")
        throw "Restoring nuget packages for solution failed."
    }
    Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Restoring dotnet packages for solution.")
    Invoke-Expression "dotnet restore $script:IoTSuiteRootPath/Connectedfactory.sln"
    if ($LASTEXITCODE -ne 0)
    {
        Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Restoring dotnet packages for solution failed.")
        throw "Restoring dotnet packages for solution failed."
    }

    # Enforce WebApp admin mode if requested via environment.
    if (-not [string]::IsNullOrEmpty($env:EnforceWebAppAdminMode))
    {
        $script:EnforceWebAppAdminMode = '/p:DefineConstants="GRANT_FULL_ACCESS_PERMISSIONS"'
    }

    # Build the solution.
    Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Building Connectedfactory.sln for configuration '{0}'." -f $script:Configuration)

	$msbuildPath2 = FindMsBuildFilePath
    Invoke-Expression "$msbuildPath2 $script:IoTSuiteRootPath/Connectedfactory.sln /v:m /p:Configuration=$script:Configuration $script:EnforceWebAppAdminMode"
    if ($LASTEXITCODE -ne 0)
    {
        Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Building Connectedfactory.sln failed.")
        throw "Building Connectedfactory.sln failed."
    }
}

Function Package()
{
    Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Packaging for configuration '{0}'." -f $script:Configuration)

    # Check installation of required tools.

    $msbuildPath2 = FindMsBuildFilePath 
    Invoke-Expression "$msbuildPath2 $script:IotSuiteRootPath/WebApp/WebApp.csproj /v:m /T:Package /p:Configuration=$script:Configuration"
    if ($LASTEXITCODE -ne 0)
    {
        Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Building WebApp.csproj failed.")
        throw "Building Webapp.csproj failed."
    }

    $root = "$script:IotSuiteRootPath";
    $webPackage = "$root/WebApp/obj/$script:Configuration/package/WebApp.zip";
    $packageDir = "$root/Build_Output/$script:Configuration/package";

    Write-Host 'Cleaning up previously generated packages';
    if ((Test-Path "$packageDir/WebApp.zip") -eq $true) 
    {
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Remove WebApp '{0}/WebApp.zip'" -f $packageDir)
        Remove-Item -Force "$packageDir/WebApp.zip" 2> $null
    }

    if ((Test-Path "$webPackage") -ne $true) 
    {
        Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - Failed to find WebApp package in directory '{0}'" -f $webPackage)
        throw "Failed to find package for the WebApp."
    }

    if (((Test-Path "$packageDir") -ne $true)) 
    {
        Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Creating package directory '{0}'" -f $packageDir)
        New-Item -Path "$packageDir" -ItemType Directory | Out-Null
    }

    Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Copying packages to package directory '{0}'" -f $packageDir)
    Copy-Item $webPackage -Destination $packageDir | Out-Null
}

Function UpdateBrowserEndpoints()
{
    # Use a copy of the original to patch
    $originalFileName = "$script:IoTSuiteRootPath\WebApp\OPC.Ua.SampleClient.Endpoints.xml"
    $applicationFileName = "$script:IoTSuiteRootPath\WebApp\OPC.Ua.Browser.Endpoints.xml"
    Copy-Item $originalFileName $applicationFileName -Force
    # Patch the endpoint configuration file. Grab a node we import into the patched file
    $xml = [xml] (Get-Content $originalFileName)
    $configuredEndpoint = $xml.ConfiguredEndpointCollection.Endpoints.ChildNodes[0]

    $xml = [xml] (Get-Content $applicationFileName)
    $content = Get-Content -raw $script:TopologyDescription
    $json = ConvertFrom-Json -InputObject $content
    $productionLines = ($json | select -ExpandProperty Factories | select -ExpandProperty ProductionLines)
    foreach($productionLine in $productionLines)
    {
        $configuredEndpoint.Endpoint.EndpointUrl = CreateProductionLineStationUrl -productionLine $productionLine -type "Assembly"
        $child = $xml.ImportNode($configuredEndpoint, $true)
        $xml.ConfiguredEndpointCollection.Endpoints.AppendChild($child) | Out-Null

        $configuredEndpoint.Endpoint.EndpointUrl = CreateProductionLineStationUrl -productionLine $productionLine -type "Test"
        $child = $xml.ImportNode($configuredEndpoint, $true)
        $xml.ConfiguredEndpointCollection.Endpoints.AppendChild($child) | Out-Null

        $configuredEndpoint.Endpoint.EndpointUrl = CreateProductionLineStationUrl -productionLine $productionLine -type "Packaging"
        $child = $xml.ImportNode($configuredEndpoint, $true)
        $xml.ConfiguredEndpointCollection.Endpoints.AppendChild($child) | Out-Null
    }
 
    # Remove the entry with localhost (original template)
    $nodes = $xml.ConfiguredEndpointCollection.Endpoints.ChildNodes
    for ($i=0; $i -lt $nodes.Count; )
    {
        if ($nodes[$i].Endpoint.EndpointUrl -like "*localhost*")
        {
            $xml.ConfiguredEndpointCollection.Endpoints.RemoveChild($nodes[$i]) | Out-Null
        }
        else
        {
            $i++
        }
    }

    $xml.Save($applicationFileName)
}

# Replace browser endpoint configuration file in WebApp
Function FixWebAppPackage()
{
    Param(
        [Parameter(Mandatory=$true,Position=0)] [string] $filePath
    )

    # Set path correct
    $browserEndpointsName = "OPC.Ua.Browser.Endpoints.xml"
    $browserEndpointsFullName = "$script:IoTSuiteRootPath/WebApp/$browserEndpointsName"
    $zipfile = Get-Item "$filePath"
    [System.IO.Compression.ZipArchive]$zipArchive = [System.IO.Compression.ZipFile]::Open($zipfile.FullName, "Update")

    $entries = $zipArchive.Entries | Where-Object { $_.FullName -match ".*$browserEndpointsName" } 
    foreach ($entry in $entries)
    { 
        $fullPath = $entry.FullName
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Found '{0}' in archive" -f $fullPath)
        $entry.Delete()
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $browserEndpointsFullName, $fullPath) | Out-Null
    }
    $zipArchive.Dispose()
}

Function FinalizeWebPackages
{
    Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Uploading packages")

    # Set path correct
    $script:WebAppLocalPath = "$script:IoTSuiteRootPath/WebApp/obj/{0}/Package/WebApp.zip" -f $script:Configuration

    # Update browser endpoints
    UpdateBrowserEndpoints

    # Upload WebApp package
    Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - Fix WebApp package")
    FixWebAppPackage $script:WebAppLocalPath
}

Function SimulationBuild
{
    Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Building Simulation for configuration '{0}'." -f $script:Configuration)

    # Check installation of required tools.
    #CheckCommandAvailability "dotnet.exe" | Out-Null

    # call BuildSimulation.cmd
    Invoke-Expression "$script:SimulationPath/Factory/BuildSimulation.cmd -c --config $script:Configuration"

    # Provide other files
    Copy-Item -Force "$script:SimulationPath/Factory/Dockerfile" "$script:SimulationBuildOutputPath" | Out-Null
}

function RecordVmCommand
{
    Param(
        [Parameter(Mandatory=$true)] $command,
        [Switch] $initScript,
        [Switch] $deleteScript,
        [Switch] $startScript,
        [Switch] $stopScript
    )
    
    if ($initScript -eq $false -and $deleteScript -eq $false -and $startScript -eq $false-and $stopScript -eq $false)
    {
        Write-Error ("$(Get-Date –f $TIME_STAMP_FORMAT) - No switch set. Please check usage.")
        throw ("No switch set. Please check usage.")
    }
    if ($initScript)
    {
        # Add this to the init script.
        Add-Content -path "$script:SimulationBuildOutputInitScript" -Value "$command `n" -NoNewline
    }
    if ($deleteScript)
    {
        # Add this to the delete script.
        Add-Content -path "$script:SimulationBuildOutputDeleteScript" -Value "$command `n" -NoNewline
    }
    if ($startScript)
    {
        # Add this to the start script.
        Add-Content -path "$script:SimulationBuildOutputStartScript" -Value "$command `n" -NoNewline
    } 
    if ($stopScript)
    {
        # Add this to the stop script.
        Add-Content -path "$script:SimulationBuildOutputStopScript" -Value "$command `n" -NoNewline
    } 
}

function StartMES
{
    Param(
        [Parameter(Mandatory=$true)] $net,
        [Parameter(Mandatory=$true)] $productionLine
    )

    # Create the instance name
    $containerInstance = "MES." + $productionLine.Simulation.Mes + "." + $net

    # Create config and logs directory in the build output. They are copied to their final place in the VM by the init script
    if (-not (Test-Path "$script:SimulationBuildOutputPath/$script:DockerConfigFolder/$containerInstance")) 
    {
        New-Item -Path "$script:SimulationBuildOutputPath/$script:DockerConfigFolder/$containerInstance" -ItemType "Directory" | Out-Null
    }
    if (-not (Test-Path "$script:SimulationBuildOutputPath/$script:DockerLogsFolder/$containerInstance")) 
    {
        New-Item -Path "$script:SimulationBuildOutputPath/$script:DockerLogsFolder/$containerInstance" -ItemType "Directory" | Out-Null
    }

    # Create unique configuration for this production line's MES
    $originalFileName = "$script:SimulationPath/Factory/MES/Opc.Ua.MES.Endpoints.xml"
    $applicationFileName = "$script:SimulationBuildOutputPath/Opc.Ua.MES.Endpoints.xml"
    Copy-Item $originalFileName $applicationFileName -Force

    # Patch the endpoint configuration file
    $xml = [xml] (Get-Content $applicationFileName)
    $configuredEndpoints = $xml.ConfiguredEndpointCollection.Endpoints.ChildNodes
    $configuredEndpoints[0].Endpoint.EndpointUrl = (CreateProductionLineStationUrl -productionLine $productionLine -type "Assembly")
    $configuredEndpoints[1].Endpoint.EndpointUrl = (CreateProductionLineStationUrl -productionLine $productionLine -type "Test")
    $configuredEndpoints[2].Endpoint.EndpointUrl = (CreateProductionLineStationUrl -productionLine $productionLine -type "Packaging")
    $xml.Save($applicationFileName)

    # Copy the endpoint configuration file
    Copy-Item -Path $applicationFileName -Destination "$script:SimulationBuildOutputPath/$script:DockerConfigFolder/$containerInstance"

    # Patch the application configuration file
    $originalFileName = "$script:SimulationPath/Factory/MES/Opc.Ua.MES.Config.xml"
    $applicationFileName = "$script:SimulationBuildOutputPath/Opc.Ua.MES.Config.xml"
    Copy-Item $originalFileName $applicationFileName -Force
    $xml = [xml] (Get-Content $applicationFileName)
    $xml.ApplicationConfiguration.SecurityConfiguration.ApplicationCertificate.SubjectName = $containerInstance
    $xml.Save($applicationFileName)

    # Copy the application configuration file
    Copy-Item -Path $applicationFileName -Destination "$script:SimulationBuildOutputPath/$script:DockerConfigFolder/$containerInstance"

    # Set MES hostname.
    $hostName = $productionLine.Simulation.Mes.ToLower() + "." + $net
    
    # Disconnect from network on stop and delete.
    $vmCommand = "docker network disconnect -f $net $hostName"
    RecordVmCommand -command $vmCommand -stopScript -deleteScript

    # Start MES.
    $commandLine = "../buildOutput/MES.dll"
    Write-Output("$(Get-Date –f $TIME_STAMP_FORMAT) - Start Docker container for MES node $hostName ...");
    $volumes = "-v $script:DockerRoot/$($script:DockerSharedFolder):/app/$script:DockerSharedFolder "
    $volumes += "-v $script:DockerRoot/$script:DockerLogsFolder/$($containerInstance):/app/$script:DockerLogsFolder "
    $volumes += "-v $script:DockerRoot/$script:DockerConfigFolder/$($containerInstance):/app/$script:DockerConfigFolder"
    $vmCommand = "docker run -itd $volumes -w /app/Config --name $hostName -h $hostName --network $net --restart always simulation:latest $commandLine"
    RecordVmCommand -command $vmCommand -startScript
    $vmCommand = "sleep 10s"
    RecordVmCommand -command $vmCommand -startScript
}

function StartProxy
{
    Param(
        [Parameter(Mandatory=$true)] $net
    )

    # Start proxy container in the VM and link to simulation container
    $hostName = "proxy." + $net

    # Disconnect from network on stop and delete.
    $vmCommand = "docker network disconnect -f $net $hostName"
    RecordVmCommand -command $vmCommand -stopScript -deleteScript

    # Start proxy.
    Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Start Docker container for Proxy node $hostName ...")
    $vmCommand = "docker run -itd -v $script:DockerRoot/$($script:DockerLogsFolder):/app/$script:DockerLogsFolder --name $hostName -h $hostName --network $net --restart always " + '$DOCKER_PROXY_REPO:$DOCKER_PROXY_VERSION ' + "-c " + '"$IOTHUB_CONNECTIONSTRING" ' + "-l /app/$script:DockerLogsFolder/proxy1.$net.log "
    RecordVmCommand -command $vmCommand -startScript
    $vmCommand = "sleep 5s"
    RecordVmCommand -command $vmCommand -startScript
}

function StartGWPublisher
{
    Param(
        [Parameter(Mandatory=$true)] $net,
        [Parameter(Mandatory=$true)] $topologyJson
    )

    # Create the instance name.
    $hostName = "publisher." + $net
    $port = "62222"
    
    # Create config and logs directory in the build output. They are copied to their final place in the VM by the init script.
    if (-not (Test-Path "$script:SimulationBuildOutputPath/$script:DockerConfigFolder/$hostName")) 
    {
        New-Item -Path "$script:SimulationBuildOutputPath/$script:DockerConfigFolder/$hostName" -ItemType "Directory" | Out-Null
    }
    if (-not (Test-Path "$script:SimulationBuildOutputPath/$script:DockerLogsFolder/$hostName")) 
    {
        New-Item -Path "$script:SimulationBuildOutputPath/$script:DockerLogsFolder/$hostName" -ItemType "Directory" | Out-Null
    }

    # Create the published nodes file for all production lines of the factory network the publisher is on (from the topology JSON file)
    New-Item "$script:SimulationBuildOutputPath/$script:DockerConfigFolder/$hostName/publishednodes.JSON" -type file -force | Out-Null
    $publishedNodesFileName = "$script:SimulationBuildOutputPath/$script:DockerConfigFolder/$hostName/publishednodes.JSON"
    $jsonOut = New-Object System.Collections.ArrayList($null)
    $factories = ($topologyJson | Select -ExpandProperty Factories)
    $productionLines = ($factories | Select -ExpandProperty ProductionLines)
    foreach($productionLine in $productionLines)
    {
        if ($productionLine.Simulation.Network -eq $net)
        {
            $stations = ($productionLine | Select -ExpandProperty Stations)
            foreach($station in $stations)
            {
                $url = CreateProductionLineStationUrl -productionLine $productionLine -type $station.Simulation.Type
                $opcnodes = ($station | Select -ExpandProperty OpcNodes)
                foreach($opcnode in $opcnodes)
                {
                    if((-not [string]::IsNullOrEmpty($opcnode.NodeId)))
                    {
                        $identifier = (New-Object PSObject | Add-Member -PassThru NoteProperty 'Identifier' $opcnode.NodeId)
                        $entry = (New-Object PSObject | Add-Member -PassThru NoteProperty 'EndpointUrl' $url)
                        $entry | Add-Member -PassThru NoteProperty 'NodeId' $identifier
                        $jsonOut.Add($entry)
                    }
                }
            }
        }
    }

    # Save the published nodes file
    $jsonOut | ConvertTo-Json -depth 100 | Out-File $publishedNodesFileName

    # Disconnect from network on stop and delete.
    $vmCommand = "docker network disconnect -f $net $hostName"
    RecordVmCommand -command $vmCommand -stopScript -deleteScript

    # Start GW Publisher container in the VM and link to simulation container
    Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Start Docker container for GW Publisher node $hostName ...")
    $volumes = "-v $script:DockerRoot/$($script:DockerSharedFolder):/app/$script:DockerSharedFolder "
    $volumes += "-v $script:DockerRoot/$script:DockerLogsFolder/$($hostName):/app/$script:DockerLogsFolder "
    $volumes += "-v $script:DockerRoot/$script:DockerConfigFolder/$($hostName):/app/$script:DockerConfigFolder"

    $vmCommand = "docker run -itd $volumes --name $hostName -h $hostName --network $net --expose $port --restart always " + '$DOCKER_PUBLISHER_REPO:$DOCKER_PUBLISHER_VERSION ' + "$hostName " + '"$IOTHUB_CONNECTIONSTRING" ' + "--pf `'/app/$script:DockerConfigFolder/publishednodes.JSON`' --tp `'/app/Shared/CertificateStores/UA Applications`' --lf `'/app/$script:DockerLogsFolder/$hostName.log.txt`' --si 1 --ms 0 --di 60 --oi 1000 --op 1000 --fd true --tm true --as true --vc true"
    RecordVmCommand -command $vmCommand -startScript
}

function CreateStationUrl
{
    Param(
        [Parameter(Mandatory=$true,Position=0)] $net,
        [Parameter(Mandatory=$true,Position=1)] $station
    )
    # Create a station uri from the station configuration
    $port = $station.Simulation.Port
    if ($port -eq $null) { $port = "51210" }
    $opcUrl = "opc.tcp://" + $station.Simulation.Id.ToLower() + "." + $net + ":" + $port + "/UA/" + $station.Simulation.Path
    return $opcUrl
}

function CreateProductionLineStationUrl
{
    Param(
        [Parameter(Mandatory=$true,Position=0)] $productionLine,
        [Parameter(Mandatory=$true,Position=1)] $type
    )
    $station = ($productionLine.Stations | where { $_.Simulation.Type -eq $type})
    return CreateStationUrl -net $productionLine.Simulation.Network.ToLowerInvariant() -station $station
}

function StartStation
{
    Param(
        [Parameter(Mandatory=$true)] $net,
        [Parameter(Mandatory=$true)] $station
    )

    # Create the instance name
    $containerInstance = "Station." + $station.Simulation.Id + "." + $net

    # Create logs directory in the build output. They are copied to their final place in the VM by the init script
    # Each station needs a unique logs folder to avoid race conditions in the volume driver
    if (-not (Test-Path "$script:SimulationBuildOutputPath/$script:DockerLogsFolder/$containerInstance")) 
    {
        New-Item -Path "$script:SimulationBuildOutputPath/$script:DockerLogsFolder/$containerInstance" -ItemType "Directory" | Out-Null
    }

    # Set simulation variables.
    $hostName = $station.Simulation.Id.ToLower() + "." + $net
    $port = $station.Simulation.Port
    $defaultPort = 51210
    if ($port -eq $null)
    { 
        Write-Verbose ("$(Get-Date –f $TIME_STAMP_FORMAT) - For station '{0}' there was no port configured. Using default port 51210.." -f $containerInstance, $defaultPort)
        $port = "$defaultPort" 
    }

    # Disconnect from network on stop and delete.
    $vmCommand = "docker network disconnect -f $net $hostName"
    RecordVmCommand -command $vmCommand -stopScript -deleteScript

    # Start the station
    $stationUri = (CreateStationUrl -net $net -station $station)
    $commandLine = "../buildOutput/Station.dll " + $station.Simulation.Id + " " + $stationUri.ToLower() + " " + $station.Simulation.Args
    Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Start Docker container for station node $hostName ...")
    $volumes = "-v $script:DockerRoot/$($script:DockerSharedFolder):/app/$script:DockerSharedFolder "
    $volumes +="-v $script:DockerRoot/$script:DockerLogsFolder/$($containerInstance):/app/$script:DockerLogsFolder"
    $vmCommand = "docker run -itd $volumes -w /app/buildOutput --name $hostName -h $hostName --network $net --restart always --expose $port simulation:latest $commandLine"
    RecordVmCommand -command $vmCommand -startScript
    $vmCommand = "sleep 5s"
    RecordVmCommand -command $vmCommand -startScript
}

function SimulationBuildScripts
{
    # Initialize init script
    Set-Content -Path "$script:SimulationBuildOutputInitScript" -Value "#!/bin/bash `n" -NoNewline
    # Unpack the simulation files
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "chmod +x simulation `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "tar -xjvf simulation -C $script:DockerRoot `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "rm simulation `n" -NoNewline
    # Put Config, Logs and Shared folders to final destination
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "cp -r $script:DockerRoot/buildOutput/$script:DockerConfigFolder $script:DockerRoot `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "cp -r $script:DockerRoot/buildOutput/$script:DockerLogsFolder $script:DockerRoot `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "cp -r $script:DockerRoot/buildOutput/$script:DockerSharedFolder $script:DockerRoot `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "cp $script:DockerRoot/buildOutput/startsimulation $script:DockerRoot `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "chmod +x $script:DockerRoot/startsimulation `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "cp $script:DockerRoot/buildOutput/deletesimulation $script:DockerRoot `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "chmod +x $script:DockerRoot/deletesimulation `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "cp $script:DockerRoot/buildOutput/stopsimulation $script:DockerRoot `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "chmod +x $script:DockerRoot/stopsimulation `n" -NoNewline
    # Bring the public key in place.
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "if [ `"`$2`" != `"`" ] && [ -e ../../../`$2.crt ] `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "then `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "    cp ../../../`$2.crt `"$script:DockerRoot/$script:DockerCertsFolder/$script:UaSecretBaseName.der`" `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "fi `n" -NoNewline

    # Initialize start script
    Set-Content -Path "$script:SimulationBuildOutputStartScript" -Value "#!/bin/bash `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "cd $script:DockerRoot/buildOutput `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "export DOCKER_PROXY_REPO=`"$script:DockerProxyRepo`" `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "export DOCKER_PROXY_VERSION=`"$script:DockerProxyVersion`" `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "export DOCKER_PUBLISHER_REPO=`"$script:DockerPublisherRepo`" `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "export DOCKER_PUBLISHER_VERSION=`"$script:DockerPublisherVersion`" `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "if [ `"`$IOTHUB_CONNECTIONSTRING`" == `"`" ] `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "then `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "    echo `"Please make sure that the environment variable IOTHUB_CONNECTIONSTRING is defined.`" `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "    exit `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStartScript" -Value "fi `n" -NoNewline

    # Initialize delete script
    Set-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "#!/bin/bash `n" -NoNewline

    # Initialize stop script
    Set-Content -Path "$script:SimulationBuildOutputStopScript" -Value "#!/bin/bash `n" -NoNewline

    # Create shared folder in the build output. It will copied to its final place in the VM by the init script
    if (-not (Test-Path "$script:SimulationBuildOutputPath/$script:DockerSharedFolder")) 
    {
        New-Item -Path "$script:SimulationBuildOutputPath/$script:DockerSharedFolder" -ItemType "Directory" | Out-Null
    }

    try
    {
        # The initialization created the buildOutput folder with all content.
        $vmCommand = "cd $script:DockerRoot/buildOutput"
        RecordVmCommand -command $vmCommand -initScript
        $vmCommand = 'docker build -t simulation:latest .'
        RecordVmCommand -command $vmCommand -initScript

        # Pull proxy image from docker hub.
        $vmCommand = "docker pull $script:DockerProxyRepo:$script:DockerProxyVersion"
        RecordVmCommand -command $vmCommand -initScript

        # Pull GW Publisher image from docker hub.
        $vmCommand = "docker pull $script:DockerPublisherRepo:$script:DockerPublisherVersion"
        RecordVmCommand -command $vmCommand -initScript

        # Put UA Web Client public cert in place
        if (-not (Test-Path "$script:SimulationBuildOutputPath/$script:DockerCertsFolder")) 
        {
            New-Item -Path "$script:SimulationBuildOutputPath/$script:DockerCertsFolder" -ItemType "Directory" -Force | Out-Null
        }

        # Create a cert if we do not have one from a previous build.
        if (-not (Test-Path "$script:CreateCertsPath/certs/$script:DeploymentName/$script:UaSecretBaseName.der"))
        {
            Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Create certificate to secure OPC communication.");
            Invoke-Expression "dotnet run -p $script:CreateCertsPath/CreateCerts.csproj $script:CreateCertsPath `"UA Web Client`" `"urn:localhost:Contoso:FactorySimulation:UA Web Client`""
            New-Item -Path "$script:CreateCertsPath/certs/$script:DeploymentName" -ItemType "Directory" -Force | Out-Null
            Move-Item "$script:CreateCertsPath/certs/$script:UaSecretBaseName.der" "$script:CreateCertsPath/certs/$script:DeploymentName/$script:UaSecretBaseName.der" -Force | Out-Null
            New-Item -Path "$script:CreateCertsPath/private/$script:DeploymentName" -ItemType "Directory" -Force | Out-Null
            Move-Item "$script:CreateCertsPath/private/$script:UaSecretBaseName.pfx" "$script:CreateCertsPath/private/$script:DeploymentName/$script:UaSecretBaseName.pfx" -Force | Out-Null
            
            if ($script:Command -eq "local")
            {
                # For a local build, we install the pfx into our local cert store.
                Import-PfxCertificate -FilePath "$script:CreateCertsPath/private/$script:DeploymentName/$script:UaSecretBaseName.pfx" -CertStoreLocation cert:\CurrentUser\My -Password (ConvertTo-SecureString -String $script:UaSecretPassword -Force –AsPlainText)
            }
        }
        else
        {
            Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Using existing certificate for deployment '{0}'" -f $script:DeploymentName);
        }
        Copy-Item "$script:CreateCertsPath/certs/$script:DeploymentName/$script:UaSecretBaseName.der" "$script:SimulationBuildOutputPath/$script:DockerCertsFolder" -Force | Out-Null

        # Start simulation based on topology configuration in ContosoTopologyDescription.json.
        $content = Get-Content -raw $script:TopologyDescription
        $json = ConvertFrom-Json -InputObject $content

        $factories = ($json | Select -ExpandProperty Factories)
        $productionLines = ($factories | select -ExpandProperty ProductionLines)
        $networks = ($productionLines | select -ExpandProperty Simulation | select net -ExpandProperty Network -Unique)
        foreach($network in $networks)
        {
            # Create bridge network in vm and start proxy.
            $net = $network.ToLower()
            Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Create network $net ...");
            $vmCommand = "docker network create -d bridge -o 'com.docker.network.bridge.enable_icc'='true' $net"
            RecordVmCommand -command $vmCommand -initScript
            StartProxy -net $net
        }

        foreach($productionLine in $productionLines)
        {
            # Start production lines.
            $net = $productionline.Simulation.Network.ToLower()

            Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Create production line " + $productionline.Simulation.Id + " on network $net ...")

            StartStation -net $net -station ($productionLine.Stations | where { $_.Simulation.Type -eq "Assembly"})
            StartStation -net $net -station ($productionLine.Stations | where { $_.Simulation.Type -eq "Test"})
            StartStation -net $net -station ($productionLine.Stations | where { $_.Simulation.Type -eq "Packaging"})

            StartMES -net $net -productionLine $productionLine
                
            Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Production line " + $productionline.Simulation.Id + " complete!")
        }

        foreach($network in $networks)
        {
            # Start publisher
            $net = $network.ToLower()
            StartGWPublisher -net $net -topologyJson $json
        }

        # Remove the networks on delete.
        foreach($network in $networks)
        {
            $net = $network.ToLower()
            Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Remove network $net ...");
            $vmCommand = "docker network rm $net"
            RecordVmCommand -command $vmCommand -deleteScript
        }
    }
    catch
    {
        throw $_
    }
    # Now the init script is recorded completely and a few last things to do is to fix ownership.
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "sudo chown -R docker:docker $script:DockerRoot `n" -NoNewline
    # The certs folder and all certs should be still owned by root.
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "sudo chown -R root:root `"$script:DockerRoot/$script:DockerCertsFolder`" `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "sudo chmod u+x `"$script:DockerRoot/$script:DockerCertsFolder/$script:UaSecretBaseName.der`" `n" -NoNewline
    # Start the simulation.
    Add-Content -Path "$script:SimulationBuildOutputInitScript" -Value "sudo bash -c `'export IOTHUB_CONNECTIONSTRING=`"`$0`"; $script:DockerRoot/startsimulation`' `$1 &`n" -NoNewline

    # To delete, we remove the build output. all mapped folders and stop all containers.
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "sudo rm -r $script:DockerRoot/$script:DockerSharedFolder `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "sudo rm -r $script:DockerRoot/$script:DockerLogsFolder `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "sudo rm -r $script:DockerRoot/$script:DockerConfigFolder `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "sudo rm -r $script:DockerRoot/buildOutput `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "if [ `$(docker ps -a -q | wc -l) -gt 0 ] `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "then `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "    docker stop `$(docker ps -a -q) `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "    docker rm -f `$(docker ps -a -q) `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputDeleteScript" -Value "fi `n" -NoNewline

    # To stop, we just stop all docker containers.
    Add-Content -Path "$script:SimulationBuildOutputStopScript" -Value "if [ `$(docker ps -a -q | wc -l) -gt 0 ] `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStopScript" -Value "then `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStopScript" -Value "    docker stop `$(docker ps -a -q) `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStopScript" -Value "    docker rm `$(docker ps -a -q) `n" -NoNewline
    Add-Content -Path "$script:SimulationBuildOutputStopScript" -Value "fi `n" -NoNewline
}
$TIME_STAMP_FORMAT="u"
$script:IoTSuiteRootPath = $BuildRepositoryLocalPath

$script:SimulationPath = "$script:IoTSuiteRootPath/Simulation"
$script:CreateCertsPath = "$script:SimulationPath/Factory/CreateCerts"
$script:WebAppPath = "$script:IoTSuiteRootPath/WebApp"
$script:DeploymentConfigPath = "$script:IoTSuiteRootPath/Deployment"
$script:IotSuiteVersion = Get-Content ("{0}/VERSION.txt" -f $script:IoTSuiteRootPath)
# OptionIndex is at script level because of its use in certain expression blocks
$script:OptionIndex = 0;
# Timeout in seconds for SSH operations
$script:SshTimeout = 120
$script:SimulationBuildOutputPath = "$script:SimulationPath/Factory/buildOutput"
$script:SimulationBuildOutputInitScript = "$script:SimulationBuildOutputPath/initsimulation"
$script:SimulationBuildOutputDeleteScript = "$script:SimulationBuildOutputPath/deletesimulation"
$script:SimulationBuildOutputStartScript = "$script:SimulationBuildOutputPath/startsimulation"
$script:SimulationBuildOutputStopScript = "$script:SimulationBuildOutputPath/stopsimulation"
$script:SimulationConfigPath = "$script:SimulationBuildOutputPath/Config"

# Import and check installed Azure cmdlet version
$script:AzurePowershellVersionMajor = (Get-Module -ListAvailable -Name Azure).Version.Major


$script:WebAppPath = "$script:IoTSuiteRootPath/WebApp"

$script:TopologyDescription = "$script:WebAppPath/Contoso/Topology/ContosoTopologyDescription.json"
$script:VmAdminUsername = "docker"
$script:DockerRoot = "/home/$script:VmAdminUsername"
$script:VmAdminUsername = "docker"
$script:DockerRoot = "/home/$script:VmAdminUsername"
# Note: These folder names need to be in sync with paths specified as defaults in the simulation config.xml file
$script:DockerConfigFolder = "Config"
$script:DockerLogsFolder = "Logs"
$script:DockerSharedFolder = "Shared"
$script:DockerCertsFolder = "$script:DockerSharedFolder/CertificateStores/UA Applications/certs"
$script:DockerProxyRepo = "microsoft/iot-edge-opc-proxy"
$script:DockerProxyVersion = "1.0.2"
$script:DockerPublisherRepo = "microsoft/iot-edge-opc-publisher"
$script:DockerPublisherVersion = "2.1.1"
# todo remove
$script:UaSecretBaseName = "UAWebClient"
# Note: The password could only be changed if it is synced with the password used in CreateCerts.exe
$script:UaSecretPassword = "password"
# Load System.Web
Add-Type -AssemblyName System.Web
# Load System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression.FileSystem
# Load System.Security.Cryptography.X509Certificates
Add-Type -AssemblyName System.Security

# Install nuget if not there
InstallNuget

# Set deployment name
$script:DeploymentName = $script:DeploymentName.ToLowerInvariant()
Write-Output ("$(Get-Date –f $TIME_STAMP_FORMAT) - Name of the deployment is '{0}'" -f $script:DeploymentName)

# Build the solution
Build

# Package and upload solution WebPackages
Package
FinalizeWebPackages

# Build the simulation
SimulationBuild

# Build simulation scripts
SimulationBuildScripts

# Compressed simulation binaries

Write-Verbose "$(Get-Date –f $TIME_STAMP_FORMAT) - Build compressed archive"

Compress-Archive -Path "$script:SimulationBuildOutputPath" -CompressionLevel Fastest -DestinationPath "$script:SimulationPath/buildOutput.zip"
Remove-Item "$script:SimulationPath/simulation" -ErrorAction SilentlyContinue | Out-Null
Move-Item "$script:SimulationPath/buildOutput.zip" "$script:SimulationPath/simulation" | Out-Null

