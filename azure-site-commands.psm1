$ErrorActionPreference = "Stop"

$azureLocation = "North Europe"

Function CheckReleaseModeSet {
    $relMode = Get-ReleaseMode
    Check-VarNotNullOrWhiteSpace $relMode "doesn't look like your release mode has been setup, exiting. (Run Set-ReleaseMode to set this.)"
}

Function GetAzureSiteReleaseModeVariables {
    CheckReleaseModeSet

    $info = @{}

    $relMode = Get-ReleaseMode

    switch ($relMode.ToLower().Substring(0, 4)) {
        "prod" {
            $info.ReleaseMode=$relMode
            $info.BranchName="release"
            $info.BuildConfiguration="Release"
            $info.ShowDrafts="false"
        }
        "test" {
            $info.ReleaseMode=$relMode
            $info.BranchName="master"
            $info.BuildConfiguration="Debug"
            $info.ShowDrafts="true"
        }
        default {
            throw "unknown release mode, please set to either `"prod`" or `"test`""
        }
    }
    return (new-object -typename PSObject -prop $info)
}

Function Echo-AzureSiteReleaseModeVariables {
    $vars = GetAzureSiteReleaseModeVariables
    echo "Release mode = $($vars.ReleaseMode)"
    echo "branch to deploy = $($vars.BranchName)"
    echo "build config = $($vars.BuildConfiguration)"
    echo "show drafts = $($vars.ShowDrafts)"
}

Function CheckDependencies {
}

Function FunctionPreflight {
    param ([string]$sitename)
    CheckDependencies
    Check-VarNotNullOrWhiteSpace $sitename "Please pass in a site name"
    Login-AzureApi
}

Function Create-AzureSitePS {
    param ([string]$sitename, [string]$githubRepo, [string]$siteAdminPassword)
    Check-VarNotNullOrWhiteSpace $siteAdminPassword "Please pass in a valid site admin password as a string"
    Check-VarNotNullOrWhiteSpace $githubRepo "Please pass in a valid githubRepo as a string"
    Check-VarNotNullOrWhiteSpace $githubUsername "doesn't look like your githubUsername variable has been setup, exiting. (Set up a global var with your username in .)"
    Check-VarNotNullOrWhiteSpace $githubPassword "doesn't look like your githubPassword variable has been setup, exiting. (Set up a global var with your password in.)"
    FunctionPreflight $sitename
    CheckReleaseModeSet

    echo "creating site..."

    echo "falling back on asking for creds as passing them in (below in func) isn't working atm..."
    new-azurewebsite -name $sitename -location $azureLocation -github -githubrepository "$githubusername/$githubrepo"

    Set-AzureConfig $sitename $siteAdminPassword

    return
    echo "TODO: The following doesn't seem to work - auth failure against github i think..."
    $secpasswd = ConvertTo-SecureString $githubPassword -AsPlainText -Force
    $githubCreds = New-Object -Typename System.Management.Automation.PSCredential -Argumentlist $githubUsername, $secpasswd
    new-azurewebsite -name $sitename -location $azureLocation -github -githubcredentials $githubCreds -githubrepository "$githubusername/$githubrepo"
}

Function Create-AzureSite {
    param ([string]$sitename, [string]$githubRepo, [string]$siteAdminPassword)
    Check-VarNotNullOrWhiteSpace $siteAdminPassword "Please pass in a valid site admin password as a string"
    Check-VarNotNullOrWhiteSpace $githubRepo "Please pass in a valid githubRepo as a string"
    Check-VarNotNullOrWhiteSpace $githubUsername "doesn't look like your githubUsername variable has been setup, exiting. (Set up a global var with your username in .)"
    Check-VarNotNullOrWhiteSpace $githubPassword "doesn't look like your githubPassword variable has been setup, exiting. (Set up a global var with your password in.)"
    FunctionPreflight $sitename
    CheckReleaseModeSet

    echo "creating site..."
    azure site create --location $azureLocation $sitename
    
    Set-AzureConfig $sitename $siteAdminPassword

    echo "setting up deployment..."
    azure site deployment github --githubusername $githubUsername --githubpassword $githubPassword --githubrepository "$githubUsername/$githubRepo" $sitename 

    echo "if you got here without errors then bingo bango - you have a new azure website with the name $sitename and a push deployment webhook from github repo $githubRepo setup"
}

Function Set-AzureSiteConfig {
    param ([string]$sitename, [string]$siteAdminPassword)
    Check-VarNotNullOrWhiteSpace $siteAdminPassword "Please pass in a valid site admin password as a string"
    FunctionPreflight $sitename

    echo "setting up site config..."
    azure site set --php-version off $sitename

    $vars = GetAzureSiteReleaseModeVariables

    # deployment settings
    azure site appsetting add "deployment_branch=$($vars.BranchName);SCM_BUILD_ARGS=-p:Configuration=$($vars.BuildConfiguration)" $sitename
    # azure storage settings
    azure site appsetting add "azureStorageAccountName=nickmeldrum;azureStorageBlobEndPoint=https://nickmeldrum.blob.core.windows.net/;azureStorageKey=kVjV1bHjuK3jcShagvfwNV6lndMjb4h12pLNJgkcbQ2ZYQ/TFpXTWIdfORZLxOS0QdymmNfYVtWPZCDHyQZgSw==" $sitename
    # app settings
    azure site appsetting add "ShowDrafts=$($vars.ShowDrafts);username-Nick-admin=$siteAdminPassword" $sitename
}

Function Clear-AzureSiteConfig {
    param ([string]$sitename)
    FunctionPreflight $sitename

    echo "deleting appsettings..."

    azure site appsetting delete -q deployment_branch $sitename
    azure site appsetting delete -q SCM_BUILD_ARGS $sitename

    azure site appsetting delete -q azureStorageAccountName $sitename
    azure site appsetting delete -q azureStorageBlobEndPoint $sitename
    azure site appsetting delete -q azureStorageKey $sitename

    azure site appsetting delete -q ShowDrafts $sitename
    azure site appsetting delete -q username-Nick-Admin $sitename
}

Function Delete-AzureSite {
    param ([string]$sitename, [string]$githubRepo)
    FunctionPreflight $sitename

    echo "deleting site..."
    azure site delete -q $sitename

    if ($githubRepo -ne $null) {
        Delete-GithubWebhook $githubRepo "$sitename.scm.azurewebsites.net"
    }
}

Function Get-AzureSiteCurrentDeploymentPS {
    param ([string]$sitename)
    FunctionPreflight $sitename

    return Get-AzureWebsiteDeployment -name $sitename | where {$_.Current -eq $true}
}

Function Get-AzureSiteCurrentDeployment {
    param ([string]$sitename)
    FunctionPreflight $sitename

    return azure site deployment list $sitename | grep -i active
}

Function Redeploy-AzureSiteCurrentDeployment {
    param ([string]$sitename)
    FunctionPreflight $sitename

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
    FunctionPreflight $sitename

    $websiteInfo = Get-AzureWebsite $sitename

    if ($websiteInfo.publishingpassword -eq $null) {
        throw "publishing password from azure not found."
    }
    
    return ('https://' + $websiteInfo.publishingusername + ":" + $websiteInfo.publishingpassword + "@$sitename.scm.azurewebsites.net/deploy")
}

export-modulemember *-*

