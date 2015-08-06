$ErrorActionPreference = "Stop"

Function Get-AzureSiteCurrentDeployment {
    param ([string]$sitename)
    Check-VarNotNullOrWhiteSpace $sitename "please pass in a sitename"

    return azure site deployment list $sitename | grep -i active
}

Function Get-AzureSiteCurrentDeploymentPS {
    param ([string]$sitename)
    FunctionPreflight $sitename

    return Get-AzureWebsiteDeployment -name $sitename | where {$_.Current -eq $true}
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

