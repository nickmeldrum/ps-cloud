$ErrorActionPreference = "Stop"

Function Delete-AzureSiteAndWebhook {
    param ([string]$sitename, [string]$githubRepo)
    Check-VarNotNullOrWhiteSpace $sitename "please pass in a sitename"
    Check-VarNotNullOrWhiteSpace $githubRepo "please pass in a github repo"

    write-host "deleting site..."
    azure site delete -q $sitename

    if (-Not ([string]::IsNullOrWhiteSpace($githubRepo))) {
        write-host "deleting webhook..."
        Delete-GithubWebhook $githubRepo "$sitename.scm.azurewebsites.net"
    }
}

Function Get-AzureSiteCurrentDeployment {
    param ([string]$sitename)
    Check-VarNotNullOrWhiteSpace $sitename "please pass in a sitename"

    return azure site deployment list $sitename | grep -i active
}

Function Redeploy-AzureSiteCurrentDeployment {
    param ([string]$sitename)
    Check-VarNotNullOrWhiteSpace $sitename "please pass in a sitename"

    $currentDeployId = (azure site deployment list $sitename | grep -i active | gawk '{print $3}')

    if ($currentDeployId -eq $null) {
        throw "didn't find an active deployment. Has this site been deployed yet?"
    }
    else {
        azure site deployment redeploy -q $currentDeployId $sitename
    }
}

Function Create-AzureSiteDeploymentTriggerUrl {
    param ([string]$sitename)
    Check-VarNotNullOrWhiteSpace $sitename "please pass in a sitename"

    $websiteInfo = Get-AzureWebsite $sitename

    if ($websiteInfo.publishingpassword -eq $null) {
        throw "publishing password from azure not found."
    }
    
    return ('https://' + $websiteInfo.publishingusername + ":" + $websiteInfo.publishingpassword + "@$sitename.scm.azurewebsites.net/deploy")
}

export-modulemember *-*

