$ErrorActionPreference = "Stop"

$azureLocation = "North Europe"

Function Setup-NickMeldrumBlog {
    Check-VarNotNullOrWhiteSpace $siteAdminPassword "please setup a global variable siteAdminPassword outside this script as it must be kept secret"
    Check-VarNotNullOrWhiteSpace $githubUsername "doesn't look like your githubUsername variable has been setup, exiting. (Set up a global var with your username in .)"
    Check-VarNotNullOrWhiteSpace $githubPassword "doesn't look like your githubPassword variable has been setup, exiting. (Set up a global var with your password in.)"
    Check-VarNotNullOrWhiteSpace $dnsimpleEmail "doesn't look like your dnsimpleEmail variable has been setup, exiting. (Set up a global var with your username in .)"
    Check-VarNotNullOrWhiteSpace $dnsimpleToken "doesn't look like your dnsimpleToken variable has been setup, exiting. (Set up a global var with your password in.)"

    Login-AzureApi

# setup variables
    $localRepo = "C:\Work\nickmeldrum\nickmeldrum.com.markdownblog"
    $githubRepo = "nickmeldrum.com.markdownblog"
    $prodSiteName = "nickmeldrum"
    $stagingSiteName = "nickmeldrum-staging"
    $prodHostNames = @("*.nickmeldrum.com", "www.nickmeldrum.com", "*.nickmeldrum.net", "www.nickmeldrum.net")
    $storageAccountName = "nickmeldrum"
    $prodStorageContainerName = "luceneindex"
    $stagingStorageContainerName = "luceneindex-staging"

# Create storage account and container
    $storageAccount = Get-AzureStorageAccountDetailsAndCreateIfNotExists $storageAccountName

    if ((get-azurestoragecontainer | where { $_.name -eq $stagingStorageContainerName }).count -gt 0) {
        echo "removing azure storage container $stagingStorageContainerName..."
        Remove-AzureStorageContainer -Name $stagingStorageContainerName -Force
    }

    if ((get-azurestoragecontainer | where { $_.name -eq $prodStorageContainerName }).count -gt 0) {
        echo "removing azure storage container $prodStorageContainerName..."
        Remove-AzureStorageContainer -Name $prodStorageContainerName -Force
    }

    $azureStorageAppSettings = "azureStorageAccountName=$storageAccountName;azureStorageBlobEndPoint=$($storageAccount.blobEndPoint);azureStorageKey=$($storageAccount.accountKey)"
    $stagingStorageAppSettings = "$azureStorageAppSettings;azureStorageContainerName=$stagingStorageContainerName"
    $prodStorageAppSettings = "$azureStorageAppSettings;azureStorageContainerName=$prodStorageContainerName"

    $blogAppSettings = "username-Nick-admin=$siteAdminPassword"
    $stagingblogAppSettings = "$blogAppSettings;ShowDrafts=True"
    $prodblogAppSettings = "$blogAppSettings;ShowDrafts=False"

    Setup-SiteWithGithubDeployment "test" $githubRepo $stagingSiteName "$stagingStorageAppSettings;$stagingblogAppSettings"
    Setup-SiteWithGithubDeployment "prod" $githubRepo $prodSiteName "$prodStorageAppSettings;$prodblogAppSettings" $prodHostNames

    Try-CreateAzureStorageContainer $stagingStorageContainerName
    Try-CreateAzureStorageContainer $prodStorageContainerName

    Ensure-Deployment "test" $stagingSiteName $localRepo
    Ensure-Deployment "prod" $prodSiteName $localRepo
}

Function Ensure-Deployment {
    param ([string]$releaseMode, [string]$siteName, [string]$localRepo)

    $vars = Get-AzureSiteReleaseModeVariables $releaseMode

    $currentPath = $pwd.Path
    cd $localRepo
    $currentBranch = git rev-parse --abbrev-ref HEAD
    git checkout $vars.BranchName
    Add-Content .\Web\Views\Shared\_Layout.cshtml "`r`n"
    git add .
    git commit -m "deployment trigger commit"
    git push
    git checkout $currentBranch
    cd $currentPath
}

Function Try-CreateAzureStorageContainer {
    param ([string]$name)

    $timesToTry = 0
    $succeeded = false

    start-sleep -s 5
    while ($timesToTry -ne 10) {
        try {
            new-azurestoragecontainer -Name $name -Permission "Blob"
            $succeeded = $true
        }
        catch [system.exception] {
            echo "creating storage container failed with message: " + $_.Exception.Message
            echo "trying again..."
        }
        
        if ($succeeded) {
            return
        }

        start-sleep -s 10
        $timesToTry++
    }

    throw "creating azure storage container not completed within set time"
}

Function Setup-SiteWithGithubDeployment {
    param ([string]$releaseMode, [string]$githubRepo, [string]$sitename, [string]$appSettings, [string[]]$hostNames)

    Check-VarNotNullOrWhiteSpace $azureLocation "azureLocation variable should have been set up the top of the site powershell script"
    Check-VarNotNullOrWhiteSpace $githubUsername "doesn't look like your githubUsername variable has been setup, exiting. (Set up a global var with your username in .)"
    Check-VarNotNullOrWhiteSpace $githubPassword "doesn't look like your githubPassword variable has been setup, exiting. (Set up a global var with your password in.)"

    Check-VarNotNullOrWhiteSpace $releaseMode "Please pass in a valid releaseMode as a string"
    Check-VarNotNullOrWhiteSpace $githubRepo "Please pass in a valid githubRepo as a string"
    Check-VarNotNullOrWhiteSpace $sitename "Please pass in a valid sitename as a string"
 
    $vars = Get-AzureSiteReleaseModeVariables $ReleaseMode

    remove-azurewebsite $sitename -force
    azure site create --location $azureLocation $sitename

    azure site set --php-version off $sitename

    if (-not [string]::IsNullOrWhiteSpace($appSettings)) {
        azure site appsetting add $appSettings $siteName
    }

# Setup appsettings that kudu will read to know what branch to build and which build config msbuild should use
    azure site appsetting add "deployment_branch=$($vars.BranchName);SCM_BUILD_ARGS=-p:Configuration=$($vars.BuildConfiguration)" $sitename
# Setup azure site (kudu) to create a github webhook to trigger a build and deploy on a push to github
    Delete-GithubWebhook $githubRepo -triggerurlsubstring "$sitename.scm.azurewebsites.net/deploy"
    azure site deployment github --githubusername $githubUsername --githubpassword $githubPassword --githubrepository "$githubUsername/$githubRepo" $sitename 

    if ($vars.ReleaseMode -eq "prod") {
        azure site scale mode --mode shared $sitename

        if ($hostNames.length -eq 0) {
            write-host "no host names passed in for prod profile - just a warning!"
        }

        Set-HostNamesInDnsimpleAndAzure $hostNames $siteName
    }
}

Function Set-HostNamesInDnsimpleAndAzure {
    param ([string[]]$hostNames, $sitename)

    $ipaddress = ([System.Net.Dns]::GetHostAddresses("$sitename.azurewebsites.net")).ipaddresstostring

    foreach ($hostName in $hostNames) {
        $hostHeader = $hostName.substring(0, $hostName.indexof("."))
        $domainName = $hostName.substring($hostName.indexof(".") + 1)

        $aRecords = (Get-DnsimpleARecords $domainName)
        if ($aRecords.id.length -gt 0 -and $aRecords.name.contains("")) {
            $id = (get-DnsimpleARecords $domainName | where {$_.name -eq ""}).id
            Delete-DNSimpleRecord $domainName $id
        }
        Create-DnsimpleARecord $domainName "" $ipaddress

        $cnameRecords = (Get-DnsimpleCnameRecords $domainName)
        if ($cnameRecords.length -gt 0 -and $cnameRecords.name.contains($hostHeader)) {
            $id = (get-DnsimpleCnameRecords $domainName | where {$_.name -eq $hostHeader}).id
            Delete-DNSimpleRecord $domainName $id
        }
        Create-DnsimpleCnameRecord $domainName $hostHeader "$sitename.azurewebsites.net"

        if ($hostName.startswith("*.")) {
            $hostName = $domainName
        }

        azure site domain add $hostName $sitename
    }
}

Function Get-AzureSiteReleaseModeVariables {
    param ([string]$relMode)

    $info = @{}

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

