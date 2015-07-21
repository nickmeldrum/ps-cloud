# Dependencies:
# ==============
#
# Ensure $githubUsername, $githubToken var exists and contains a valid github auth token and $githubPassword var exists and is your actual password (yes this sucks, currently trying to find a better way of doing this.) I stick this in my powershell profile so it's available globally. Don't stick it in source control!

$headers = @{
    "Accept" = "application/vnd.github.v3+json";
    "Content-Type" = "application/json";
    "Authorization" = ("token " + $githubToken);
}

$ErrorActionPreference = "Stop"

Function CheckVarNotNullOrWhiteSpace {
    param ([string]$var, [string]$msg)

    if ([string]::IsNullOrWhiteSpace($var)) {
        throw $msg
    }
}

Function CheckDependencies {
    CheckVarNotNullOrWhiteSpace $githubUsername "doesn't look like your githubUsername variable has been setup, exiting. (Set up a global var with your username in .)"
    CheckVarNotNullOrWhiteSpace $githubToken "doesn't look like your githubToken variable has been setup, exiting. (Set up a global var with your token in .)"
    CheckVarNotNullOrWhiteSpace $githubPassword "doesn't look like your githubPassword variable has been setup, exiting. (Set up a global var with your password in.)"

    echo "dependency check (githubUsername, githubToken, githubPassword) passed!"
}

Function FunctionPreflight {
    CheckDependencies
}

Function CreateRemoteRepoAndPush {
    param (
        [string]$remoteRestUrl,
        [string]$remoteGitUrl,
        $repoHeaders,
        [string]$body
    )

    Invoke-WebRequest -Uri $remoteRestUrl -Headers $repoHeaders -Method Post -Body $body
    git remote rm origin
    git remote add origin $remoteGitUrl 
    git push -u origin --all
    git push -u origin --tags
}

Function CreateBitbucket {
    param (
        [string]$repoName,
        [string]$isPrivate
    )

    $bbHeaders = @{
        "Content-Type" = "application/x-www-form-urlencoded; charset=UTF-8";
        "Authorization" = ("Basic " + $bitbucketToken);
    }

    $body = "name=$repoName&is_private=$isPrivate&scm=git&fork_policy=allow_forks"

    CreateRemoteRepoAndPush "https://bitbucket.org/api/2.0/repositories/nickmeldrum/$repoName" "https://$bitbucketUsername@bitbucket.org/$bitbucketUsername/$repoName.git" $bbHeaders $body
}

# Run the Create-GithubRepo function on an already created local git repo to create a remote
# repo on github and push to it. (local repo must have at least 1 commit)
Function Create-GithubRepo {
    param ([string]$githubRepo)

    $json = "{`"name`":`"" + $githubRepo + "`"}"

    CreateRemoteRepoAndPush "https://api.github.com/user/repos" "https://github.com/$githubUsername/$githubRepo.git" $headers $json
}

Function Create-BitbucketPrivateRepo {
    param ([string]$repoName)

    CreateBitbucket $repoName "true"
}

Function Create-BitbucketPublicRepo {
    param ([string]$repoName)

    CreateBitbucket $repoName "false"
}

Function Create-GithubWebhook {
    param ([string]$githubRepo, [string]$triggerUrl)
    CheckVarNotNullOrWhiteSpace $githubRepo "Please pass in a valid githubRepo as a string"
    CheckVarNotNullOrWhiteSpace $triggerUrl "Please pass in a valid triggerUrl as a string"
    FunctionPreflight

    echo "setting up github webhook..."
    $body = @{
      "name" = "web";
      "active" = "true";
      "events" = @(
        "push"
      );
      "config" = @{
        "url" = "$triggerUrl";
        "content_type" = "form"
      }
    }

    Invoke-RestMethod -Uri "https://api.github.com/repos/$githubUsername/$githubRepo/hooks" -Method Post -ContentType "application/json" -Headers $headers -Body (ConvertTo-Json $body)
}

Function Delete-GithubWebhook {
    param ([string]$githubRepo, [string]$triggerUrlSubstring)
    CheckVarNotNullOrWhiteSpace $triggerUrlSubstring "Please pass in a valid triggerUrlSubstring as a string"
    CheckVarNotNullOrWhiteSpace $githubRepo "Please pass in a valid githubRepo as a string"

    echo "deleting webhook if it exists..."
    $webhook = ((Invoke-RestMethod -Uri "https://api.github.com/repos/$githubUsername/$githubRepo/hooks" -Method Get -Headers $headers) | where { $_.config.url.indexof($triggerUrlSubstring) -gt -1})

    if ($webhook -ne $null) {
        echo ("deleting webhook with url: " + $webhook.url)
        Invoke-RestMethod -Uri ("https://api.github.com/repos/$githubUsername/$githubRepo/hooks/" + $webhook.id) -Method Delete -Headers $headers
    }
}

Function List-GithubWebhooks {
    param ([string]$githubRepo)
    CheckVarNotNullOrWhiteSpace $githubRepo "Please pass in a valid githubRepo as a string"

    Invoke-RestMethod -Uri "https://api.github.com/repos/$githubUsername/$githubRepo/hooks" -Method Get -Headers $headers
}

export-modulemember *-*

