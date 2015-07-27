$ErrorActionPreference = "Stop"

$azureLocation = "North Europe"

Function CheckReleaseModeSet {
    $relMode = Get-ReleaseMode
    Check-VarNotNullOrWhiteSpace $relMode "doesn't look like your release mode has been setup, exiting. (Run Set-ReleaseMode to set this.)"
}

Function Get-AzureSiteReleaseModeVariables {
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
    $vars = Get-AzureSiteReleaseModeVariables
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
    $secpasswd = ConvertTo-SecureString $githubPassword -AsPlainText -Force
    $githubCreds = New-Object -Typename System.Management.Automation.PSCredential -Argumentlist $githubUsername, $secpasswd
    new-azurewebsite -name $sitename -location $azureLocation -github -githubcredentials $githubCreds -githubrepository "$githubusername/$githubrepo"

    Set-AzureSiteConfig $sitename $siteAdminPassword
}

Function Create-AzureSite {
    param ([string]$sitename)
    Check-VarNotNullOrWhiteSpace $azureLocation "azureLocation variable should have been set up the top of the site powershell script"
    FunctionPreflight $sitename

    echo "creating site..."
    azure site create --location $azureLocation $sitename
}

Function Setup-AzureSiteGithubDeployment {
    param ([string]$sitename, [string]$githubRepo)
    Check-VarNotNullOrWhiteSpace $githubRepo "Please pass in a valid githubRepo as a string"
    Check-VarNotNullOrWhiteSpace $githubUsername "doesn't look like your githubUsername variable has been setup, exiting. (Set up a global var with your username in .)"
    Check-VarNotNullOrWhiteSpace $githubPassword "doesn't look like your githubPassword variable has been setup, exiting. (Set up a global var with your password in.)"
    FunctionPreflight $sitename

    Set-AzureSiteDeploymentMode $sitename

    echo "setting up deployment..."
    azure site deployment github --githubusername $githubUsername --githubpassword $githubPassword --githubrepository "$githubUsername/$githubRepo" $sitename 
}

Function Stop-AzureSitePhp {
    param ([string]$sitename)
    FunctionPreflight $sitename

    azure site set --php-version off $sitename
}

Function Set-AzureSiteDeploymentMode {
    param ([string]$sitename)
    FunctionPreflight $sitename

    $vars = Get-AzureSiteReleaseModeVariables
    azure site appsetting add "deployment_branch=$($vars.BranchName);SCM_BUILD_ARGS=-p:Configuration=$($vars.BuildConfiguration)" $sitename
}

Function Clear-AzureSiteDeploymentSettings {
    param ([string]$sitename)
    FunctionPreflight $sitename

    echo "deleting appsettings..."

    azure site appsetting delete -q deployment_branch $sitename
    azure site appsetting delete -q SCM_BUILD_ARGS $sitename
}

Function Delete-AzureSite {
    param ([string]$sitename, [string]$githubRepo)
    FunctionPreflight $sitename

    echo "deleting site..."
    azure site delete -q $sitename

    if (-Not ([string]::IsNullOrWhiteSpace($githubRepo))) {
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

