# Install-Module -Name PowerShellForGitHub

# Set-GitHubConfiguration -SuppressTelemetryReminder

$PSDefaultParameterValues["*-GitHub*:AccessToken"] = $env:GITHUB_TOKEN

$repo = "orion"
$organization = "solarwinds"
$repoUri = "https://github.com/$organization/$repo" 
$teamName = "eng-spider-team"

function GetLastBuildStatus {
    param (
        $pullRequest
    )
    $params = @{
        'UriFragment' = $pullRequest.statuses_url
        'Method'      = "Get"
        'Description' = "Getting statuses"
        'AccessToken' = $env:GITHUB_TOKEN
    }
    $statuses = Invoke-GHRestMethod @params 

    $lastVerifyStatus = $statuses 
     | Where-Object {$_.context}
     | Where-Object {$_.context.StartsWith("Verify PR Merge Check")} 
     | Select-Object -Last 1

    return $lastVerifyStatus
}
function GetLasReview {
    param (
        $pullRequest
    )

    $params = @{
        'UriFragment' = "https://api.github.com/repos/$organization/$repo/pulls/$($pullRequest.number)/reviews"
        'Method'      = "Get"
        'Description' = "Getting reviews"
        'AccessToken' = $env:GITHUB_TOKEN
    }
    $reviews = Invoke-GHRestMethod @params

    $lastReview = $reviews | Select-Object -Last 1

    return $lastReview;
}

function GetTCBuildLink {
    param (
        $pullRequest
    )
    $branch = $pullRequest.head.ref

    $url = "https://teamcity.solarwinds.com/viewType.html?buildTypeId=OneOrion_VerifyPrMergeCheck&branch_OneOrion="
    $url += [System.Web.HTTPUtility]::UrlEncode($branch)
    return $url;
}

function FormatStatus {
    param (
        $lastReview
    )
    if($lastReview.state -and $lastReview.submitted_at) {
        return "$($lastReview.state)  on  $($lastReview.submitted_at)";
    }

    return "";
}

function GetCurrentPR {
    param (
        [string] 
        [Alias("a")]
        $author,
        [string] 
        [Alias("t")]
        $title
    )
    $pullRequests = Get-GitHubPullRequest -Uri $repoUri -State Open

    $teamMembers = Get-GitHubTeamMember -OrganizationName $organization -TeamName $teamName
    $logins = $teamMembers | ForEach-Object{$_.login}

    if ($author) {
        $logins = $logins -like "*$($author)*"
        # Write-Output  $logins
    }
    
    $teamPRs = $pullRequests | Where-Object {$_.user.login -in $logins} 
    #$teamPRs | Select-Object @{name="login";expression={$_.user.login} }, title | Format-Table

    if ($title) {
        $teamPRs = $teamPRs | Where-Object {$_.title -like "*$($title)*"}
    }
    
    $result = $teamPRs 
        | Select-Object title, 
                        @{name="author";expression={$_.user.login}}, 
                        @{name="url";expression={$_.html_url}}, 
                        @{name="build_status";expression={(GetLastBuildStatus($_)).state.ToUpper()}},
                        @{name="tc_url";expression={(GetTCBuildLink($_))}},
                        @{name="pr_status";expression={FormatStatus(GetLasReview($_))}}

    $result | Format-List


    <#
        .SYNOPSIS
        Return all current Pull Requests.

        .EXAMPLE
        PS> GetCurrentPR -author "plet" -title "oo-"

        .EXAMPLE
        PS> GetCurrentPR -a "plet" -t "oo-"

        .EXAMPLE
        PS> GetCurrentPR
    #>
}
