<#
.SYNOPSIS
Script to tag NuGet.Client and NuGet.Build.Localization every time an insertion is made into VS.

.DESCRIPTION
Uses the Personal Access Token of NuGetLurker to automate the tagging process.

.PARAMETER PersonalAccessToken
PersonalAccessToken of the NuGetLurker account

.PARAMETER VsTargetBranch
The VS Branch that the NuGet build is being inserted into. 

#>

param
(
    [Parameter(Mandatory=$True)]
    [string]$PersonalAccessToken,
    [Parameter(Mandatory=$True)]
    [string]$VsTargetBranch
)

$Token = $PersonalAccessToken
$Base64Token = [System.Convert]::ToBase64String([char[]]$Token)

$Headers= @{
    Authorization='Basic {0}' -f $Base64Token;
}

# These environment variables are set on the VSTS Release Definition agents.
$Branch = ${env:BUILD_SOURCEBRANCHNAME}
$Build = ${env:BUILD_BUILDNUMBER}
$Commit = ${env:BUILD_SOURCEVERSION}

$OutputPath = "\\nuget\nuget\share\drops\ci\nuget.client"
$NuGetExePath = [System.IO.Path]::Combine($OutputPath, $Branch, $Build, 'artifacts', 'VS15', "NuGet.exe")
Write-Host $NuGetExePath

$TagName = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($NuGetExePath).FileVersion
$ProductVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($NuGetExePath).ProductVersion
$Date = Get-Date
$Message = "Insert $ProductVersion into $VsTargetBranch on $Date"
$BuildInfoJsonFile = [System.IO.Path]::Combine($OutputPath, $Branch, $Build, 'buildinfo.json')
$buildInfoJson = (Get-Content $BuildInfoJsonFile -Raw) | ConvertFrom-Json
$LocRepoCommitHash = $buildInfoJson.LocalizationRepositoryCommitHash

Tag-GitCommit -NuGetRepository 'NuGet.Client' -HttpHeaders $Headers -CommitHash $Commit -TagName $TagName -TagMessage $Message

Tag-GitCommit -NuGetRepository 'NuGet.Build.Localization' -HttpHeaders $Headers -CommitHash $LocRepoCommitHash -TagName $TagName -TagMessage $Message


Function Tag-GitCommit {
    param(
        [string]$NuGetRepository,
        [string]$HttpHeaders,
        [string]$CommitHash,
        [string]$TagName,
        [string]$TagMessage
    )

$Body = @{
tag = $TagName;
object = $CommitHash;
type = 'commit';
message= $TagMessage;
} | ConvertTo-Json;

Write-Host $Body

$tagObject = "refs/tags/$TagName"

$r1 = Invoke-RestMethod -Headers $HttpHeaders -Method Post -Uri "https://api.github.com/repos/NuGet/$NuGetRepository/git/tags" -Body $Body

Write-Host $r1

$Body2 = @{
ref = $tagObject;
sha = $r1.sha;
} | ConvertTo-Json;

Write-Host $Body2

$r2 = Invoke-RestMethod -Headers $HttpHeaders -Method Post -Uri "https://api.github.com/repos/NuGet/$NuGetRepository/git/refs" -Body $Body2

Write-Host $r2

}