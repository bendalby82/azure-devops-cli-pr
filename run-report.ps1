# This script requires the following:
# [1] Azure CLI version 2.10.1 or later, plus the Azure DevOps extension.
#     See instructions here to install: 
#     https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops
# [2] Azure CLI to be signed into your organization.
#	  See instructions here to isign in with Personal Access Token (PAT)
#	  https://docs.microsoft.com/en-us/azure/devops/cli/log-in-via-pat?view=azure-devops&tabs=windows

# We need to filter dates ourselves, there is currently no CLI parameter to do this.
# Our particular use case is to get activity for the previous week (Monday to Sunday)
$endDate = (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-(Get-Date).DayOfWeek.value__ + 1)
$startDate = $endDate.AddDays(-7)
# Retrieve enough PRs for each project to cover the time period.
$prlimit = 20

# Retrieve all the projects in my organisation.
$projects = az devops project list --query "value[].name" | ConvertFrom-Json
$allprs = @()
$filteredprs = @()

# Decide which attributes we want to show. The PR JSON object is very rich, and we can 
# use JMESPath language to filter, slice, project and select this object: https://jmespath.org/
$query = "[].{Created:creationDate, Closed:closedDate, Creator:createdBy.displayName, PR:codeReviewId, " + `
	"Title:title, Repo:repository.name, Reviewers:join(',',reviewers[].displayName), Source:sourceRefName, " + `
	"Target:targetRefName}"

# Retrieve a limit of $prlimit PRs for each project 
foreach ($project in $projects) {
	$prlist = az repos pr list --project $project --status all --top $prlimit --query $query | ConvertFrom-Json
	$allprs = $allprs + $prlist
}

# Convert JSON dates into PowerShell dates
foreach ($pr in $allprs){
	$createdDate = [datetime]::parseexact($pr.Created.SubString(0,19),'yyyy-MM-ddTHH:mm:ss',$null)
	$pr.Created = $createdDate
	# Closed will be empty if the PR is still open at the time the report runs.
	if (-NOT [string]::IsNullOrEmpty($pr.Closed)){
		$closedDate = [datetime]::parseexact($pr.Closed.SubString(0,19),'yyyy-MM-ddTHH:mm:ss',$null)
		$pr.Closed = $closedDate
	}
}

# Filter on Created date 
foreach ($pr in $allprs){
	if ($pr.Created -ge $startDate -AND $pr.Created -lt $endDate){
		$filteredprs = $filteredprs + $pr
	}
}

# Save as CSV
$csvname = ".\" + $startDate.ToString("yyyyMMdd") + "-pr-report.csv"
$filteredprs | ConvertTo-Csv -NoTypeInformation | Set-Content $csvname

