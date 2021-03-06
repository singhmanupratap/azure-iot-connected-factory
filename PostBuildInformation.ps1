Param(
	[Parameter(Mandatory=$true, HelpMessage="Specify the Api Uri.")]
	[string] $StatusUpdateApiUri="",
	[Parameter(Mandatory=$true, HelpMessage="Specify the Build Request Id.")]
	[string] $BuildRequestId,
	[Parameter(Mandatory=$true, HelpMessage="Specify the Build Id generated by Build queue.")]
	[string] $BuildId,
	[Parameter(Mandatory=$true, HelpMessage="Specify the status to be updated in system.")]
	[string] $Status = "",
	[Parameter(Mandatory=$false, HelpMessage="Specify the Description to be updated in system.")]
	[string] $Description = "",
	[Parameter(Mandatory=$false, HelpMessage="Specify the Build template file uri.")]
	[string] $TemplateUri="",
	[Parameter(Mandatory=$false, HelpMessage="Specify the Build template parameter file uri.")]
	[string] $TemplateParameterUri=""
)
#-StatusUpdateApiUri "$Env:StatusUpdateApiUri" -BuildRequestId "$Env:BuildRequestId" -BuildId "$Env:BuildId" -Status "1" -Description "" -TemplateUri "$Env:TemplateUri" -TemplateParameterUri "$Env:TemplateParameterUri"
$uri= $StatusUpdateApiUri -f $BuildRequestId; #"http://api-ondemanddemo.azurewebsites.net/api/builds/"
$qry=@{"Status"=$Status;"Description"=$Description;"VSTSBuildId"=$BuildId;"TemplateUri"=$TemplateUri;"TemplateParameterUri"=$TemplateParameterUri};
$json=$qry|ConvertTo-Json;
Write-Output $json
$response=Invoke-RestMethod -Method PUT -Uri $uri -ContentType "application/json" -Headers @{} -Body $json;
Write-Output $response