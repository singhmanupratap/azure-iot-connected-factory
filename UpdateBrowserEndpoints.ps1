# Use a copy of the original to patch
$script:IoTSuiteRootPath = $(Build.ArtifactStagingDirectory)
#$script:IoTSuiteRootPath = "C:\Users\manu.a.pratap.singh\Source\Repos\azure-iot-connected-factory"
$script:WebAppPath = "$script:IoTSuiteRootPath\WebApp"
$script:TopologyDescription = "$script:WebAppPath/Contoso/Topology/ContosoTopologyDescription.json"
$originalFileName = "$script:IoTSuiteRootPath\WebApp\OPC.Ua.SampleClient.Endpoints.xml"
$applicationFileName = "$script:IoTSuiteRootPath\WebApp\OPC.Ua.Browser.Endpoints.xml"
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
Function CreateProductionLineStationUrl
{
    Param(
        [Parameter(Mandatory=$true,Position=0)] $productionLine,
        [Parameter(Mandatory=$true,Position=1)] $type
    )
    $station = ($productionLine.Stations | where { $_.Simulation.Type -eq $type})
    return CreateStationUrl -net $productionLine.Simulation.Network.ToLowerInvariant() -station $station
}

Copy-Item $originalFileName $applicationFileName -Force
# Patch the endpoint configuration file. Grab a node we import into the patched file
$xml = [xml] (Get-Content $originalFileName)

Write-Output $xml
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