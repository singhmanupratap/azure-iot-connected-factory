$buildId=$(Build.BuildId)
$VmArmTemplateUri=$env:vmDeploymentTemplateFile+"/"+"$buildId"+"/"+"FactorySimulation.json"+$env:sasToken
$SimulationUri=$env:simulationUri+"/"+"$buildId"+"/"+"FactorySimulation.json"+$env:sasSimulationUriToken
$InitSimulationUri=$env:initSimulationUri+"/"+"$buildId"+"/"+"FactorySimulation.json"+$env:sasInitSimulationUriToken
$WebAppLocalPath=$env:webAppLocalPath+"/"+"$buildId"+"/"+"FactorySimulation.json"+$env:WebAppLocalPath
$uri="http://api-ondemanddemo.azurewebsites.net/api/builds/complete?buildId="+$buildId;
$pkgUrl=$VmArmTemplateUri+"|"+$SimulationUri+"|"+$InitSimulationUri+"|"+$WebAppLocalPath
$qry=@{"Status"=2;"Description"="Build Completed successfully";"VSTSBuildId"=$buildId;"PkgURL"=$pkgUrl};
$json=$qry|ConvertTo-Json;
Write-Output $json
$response=Invoke-RestMethod -Method PUT -Uri $uri -ContentType "application/json" -Headers @{} -Body $json;
Write-Output $response