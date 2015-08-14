$ErrorActionPreference = "Stop"

$azureLocation = "North Europe"

Function Setup-NickMeldrumBlog {
    Check-VarNotNullOrWhiteSpace $siteAdminPassword "please setup a global variable siteAdminPassword outside this script as it must be kept secret"

    Login-AzureApi

# setup variables
    $githubRepo = "nickmeldrum.com.markdownblog"
    $prodSiteName = "nickmeldrum"
    $stagingSiteName = "nickmeldrum-staging"
    $prodHostNames = @("*.nickmeldrum.com", "www.nickmeldrum.com", "*.nickmeldrum.net", "www.nickmeldrum.net")
    $storageAccountName = "nickmeldrum"
    $prodStorageContainerName = "luceneindex"
    $stagingStorageContainerName = "luceneindex-staging"

# Create storage account and container
    $storageAccount = Get-AzureStorageAccountDetailsAndCreateIfNotExists $storageAccountName
    new-azurestoragecontainer -Name $prodStorageContainerName -Permission "Blob"
    new-azurestoragecontainer -Name $stagingStorageContainerName -Permission "Blob"

# Create appsettings
    $azureStorageAppSettings = "azureStorageAccountName=$storageAccountName;azureStorageBlobEndPoint=$($storageAccount.blobEndPoint);azureStorageKey=$($storageAccount.accountKey)"
    $stagingStorageAppSettings = "$azureStorageAppSettings;azureStorageContainerName=$stagingStorageContainerName"
    $prodStorageAppSettings = "$azureStorageAppSettings;azureStorageContainerName=$prodStorageContainerName"

    $blogAppSettings = "username-Nick-admin=$siteAdminPassword"
    $stagingblogAppSettings = "$blogAppSettings;ShowDrafts=True"
    $prodblogAppSettings = "$blogAppSettings;ShowDrafts=False"

    Setup-SiteWithGithubDeployment "test" $githubRepo $stagingSiteName "$stagingStorageAppSettings;$stagingblogAppSettings"
    Setup-SiteWithGithubDeployment "prod" $githubRepo $prodSiteName "$prodStorageAppSettings;$prodblogAppSettings" $prodHostNames
}

Function Setup-SiteWithGithubDeployment {
    param ([string]$releaseMode, [string]$githubRepo, [string]$sitename, [string]$appSettings, [string[]]$hostNames)

    Check-VarNotNullOrWhiteSpace $azureLocation "azureLocation variable should have been set up the top of the site powershell script"
    Check-VarNotNullOrWhiteSpace $githubUsername "doesn't look like your githubUsername variable has been setup, exiting. (Set up a global var with your username in .)"
    Check-VarNotNullOrWhiteSpace $githubPassword "doesn't look like your githubPassword variable has been setup, exiting. (Set up a global var with your password in.)"

    Check-VarNotNullOrWhiteSpace $releaseMode "Please pass in a valid releaseMode as a string"
    Check-VarNotNullOrWhiteSpace $githubRepo "Please pass in a valid githubRepo as a string"
    Check-VarNotNullOrWhiteSpace $sitename "Please pass in a valid sitename as a string"
 
    Set-ReleaseMode $ReleaseMode
    $vars = Get-AzureSiteReleaseModeVariables

    azure site create --location $azureLocation $sitename

    azure site set --php-version off $sitename

    if (-not [string]::IsNullOrWhiteSpace($appSettings)) {
        azure site appsetting add $appSettings $siteName
    }

    if ($vars.ReleaseMode -eq "prod") {
        azure site scale mode --mode shared $sitename

        if ($hostNames.length -eq 0) {
            write-host "no host names passed in for prod profile - just a warning!"
        }

        Set-HostNamesInDnsimpleAndAzure $hostNames $siteName
    }

# Setup appsettings that kudu will read to know what branch to build and which build config msbuild should use
    azure site appsetting add "deployment_branch=$($vars.BranchName);SCM_BUILD_ARGS=-p:Configuration=$($vars.BuildConfiguration)" $sitename
# Setup azure site (kudu) to create a github webhook to trigger a build and deploy on a push to github
    azure site deployment github --githubusername $githubUsername --githubpassword $githubPassword --githubrepository "$githubUsername/$githubRepo" $sitename 
}

Function Set-HostNamesInDnsimpleAndAzure {
    param ([string[]]$hostNames, $sitename)

    $ipaddress = ([System.Net.Dns]::GetHostAddresses("$sitename.azurewebsites.net")).ipaddresstostring

    foreach ($hostName in $hostNames) {
        $hostHeader = $hostName.substring(0, $hostName.indexof("."))
        $domainName = $hostName.substring($hostName.indexof(".") + 1)

        $aRecords = (Get-DnsimpleARecords $domainName)
        $cnameRecords = (Get-DnsimpleCnameRecords $domainName)

        if ($aRecords.length -eq 0 -or -not $aRecords.name.contains("")) {
            Create-DnsimpleARecord $domainName "" $ipaddress
        }

        if ($cnameRecords.length -gt 0 -and -not $cnameRecords.name.contains($hostHeader)) {
            Create-DnsimpleCnameRecord $domainName $hostHeader "$sitename.azurewebsites.net"
        }

        if ($hostName.startswith("*.")) {
            $hostName = $domainName
        }
        azure site domain add $hostName $sitename
    }
}

Function Set-ReleaseMode {
    param ([string]$relMode)

    $script:releaseMode = $relMode
}

Function Get-ReleaseMode {
    return $releaseMode
}

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
        }
        "test" {
            $info.ReleaseMode=$relMode
            $info.BranchName="master"
            $info.BuildConfiguration="Debug"
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

