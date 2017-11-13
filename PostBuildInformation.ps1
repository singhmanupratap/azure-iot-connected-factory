Param(
	[string]$BuildId
)
$VmArmTemplateUri=$env:vmDeploymentTemplateFile+"/"+"$BuildId"+"/"+"FactorySimulation.json"+$env:sasToken
$SimulationUri=$env:simulationUri+"/"+"$BuildId"+"/"+"FactorySimulation.json"+$env:sasSimulationUriToken
$InitSimulationUri=$env:initSimulationUri+"/"+"$BuildId"+"/"+"FactorySimulation.json"+$env:sasInitSimulationUriToken
$WebAppLocalPath=$env:webAppLocalPath+"/"+"$BuildId"+"/"+"FactorySimulation.json"+$env:WebAppLocalPath
$uri="http://api-ondemanddemo.azurewebsites.net/api/builds/complete?buildId="+$BuildId;
$pkgUrl=$VmArmTemplateUri+"|"+$SimulationUri+"|"+$InitSimulationUri+"|"+$WebAppLocalPath
$qry=@{"Status"=2;"Description"="Build Completed successfully";"VSTSBuildId"=$BuildId;"PkgURL"=$pkgUrl};
$json=$qry|ConvertTo-Json;
Write-Output $json
$response=Invoke-RestMethod -Method PUT -Uri $uri -ContentType "application/json" -Headers @{} -Body $json;
Write-Output $response