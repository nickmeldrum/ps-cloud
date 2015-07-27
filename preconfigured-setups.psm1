$ErrorActionPreference = "Stop"

Function Setup-NickMeldrumBlog {
    param ([string]$sitename)

    $stagingSiteName = "nickmeldrum-staging"
    $githubRepo = "nickmeldrum.com.markdownblog"
    $siteAdminPassword = "test1"

    Setup-StagingSite $stagingSiteName $githubRepo $siteAdminPassword
}

Function Setup-StagingSite {
    param ([string]$sitename)

    Set-ReleaseMode "test"
    Create-AzureSite $sitename

    Stop-AzureSitePhp $sitename

    $vars = Get-AzureSiteReleaseModeVariables

    # azure storage settings
    azure site appsetting add "azureStorageAccountName=nickmeldrum;azureStorageBlobEndPoint=https://nickmeldrum.blob.core.windows.net/;azureStorageKey=kVjV1bHjuK3jcShagvfwNV6lndMjb4h12pLNJgkcbQ2ZYQ/TFpXTWIdfORZLxOS0QdymmNfYVtWPZCDHyQZgSw==" $sitename
    # app settings
    azure site appsetting add "ShowDrafts=$($vars.ShowDrafts);username-Nick-admin=$siteAdminPassword" $sitename

    Setup-AzureSiteGithubDeployment
}

