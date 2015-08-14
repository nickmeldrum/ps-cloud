## Assumes you have pester installed as part of your profile
# pester is here: https://github.com/pester/Pester
# see here for installation: http://www.powershellmagazine.com/2014/03/12/get-started-with-pester-powershell-unit-testing-framework/
# or just run the .\install-pester.ps1 script here :)

import-module .\ps-cloud.psd1 -force

$siteNamePrefix = "pstest-"
$stagingSuffix = "-staging"
$prodSuffix = "-prod"
$randomString = [Guid]::NewGuid().ToString().replace("-", "").toupperinvariant().substring(5, 5)

$stagingSiteName = "$siteNamePrefix$randomString$stagingSuffix"
$prodSiteName = "$siteNamePrefix$randomString$prodSuffix"
$storageAccountName = "pstestacc$randomString".tolowerinvariant()
$storageContainerName = "pstestcntr$randomString".tolowerinvariant()

$currentPath = $pwd.Path
$localGitPath = "C:\temp\$randomString"
$githubRepo = "$siteNamePrefix$randomString"

# Local Git Repo Functions
#
Function LocalGitRepoShouldNotExist {
    if (test-path $localGitPath) {
        throw "local github folder already exists!"
    }
}

Function Delete-LocalGitRepo {
    if (test-path $localGitPath) {
        remove-item $localgitpath -recurse -force
    }
}

Function Create-LocalGitRepo {
    write-host "creating local git repo $localGitPath..."

    mkdir $localGitPath
    cd $localGitPath
    git init
    "hello world!" | out-file index.html -encoding ascii
    "*.publishsettings" | out-file .gitignore -encoding ascii
    copy "$currentPath\*.publishsettings" .
    git add .
    git commit -m "initial commit"
}

# Azure Site Functions
#
Function SiteShouldNotExist {
    param ([string]$siteName)

    $sitenameIfExists = (azure site list | grep $siteName | gawk '{print $2}')
    if ($sitenameIfExists -ne $null) {
        throw "Site already exists!"
    }
}

Function Delete-SiteIfExists {
    param ([string]$siteName)

    $sitenameIfExists = (azure site list | grep $siteName | gawk '{print $2}')
    if ($sitenameIfExists -ne $null) {
        write-host "deleting azure site $sitenameIfExists..."
        azure site delete -q $siteName
    }
}

# Github Webhook Functions
#
Function GithubWebhookShouldNotExist {
    param ([string]$siteName)

    $hooks = List-GithubWebhooks $githubRepo
    if ($hooks.length -eq 0) {
        return
    }
    $webhook =  $hooks.config.url | where ({$_.indexof($siteName) -ne -1})
    if ($webhook -ne $null) {
        throw "webhook already exists!"
    }
}

# Github Repo Functions
#
Function GithubRepoShouldNotExist {
    $repos = (List-GithubRepos).name | where {$_ -eq $githubrepo}
    if ($repos.length -ne 0) {
        throw "github repo already exists!"
    }
}

Function Delete-GithubRepoIfExists {
    $repos = (List-GithubRepos).name | where {$_ -eq $githubrepo}
    if ($repos.length -ne 0) {
        Delete-GithubRepo $githubrepo
    }
}

Function Test-DeploymentCompleted {
    param ($sitename, $deployMsg)

    $timesToTestIfDeploymentOccurred = 0
    start-sleep -s 5
    while ($timesToTestIfDeploymentOccurred -ne 5) {
        $currentDeployment = (Get-AzureWebsiteDeployment -name $sitename | where {$_.Current -eq $true})
        if ($currentDeployment.Status -eq "Success" -and $currentDeployment.Complete -eq "True" -and $currentDeployment.Message.trim() -eq $deployMsg) {
            return
        }
        start-sleep -s 5
        $timesToTestIfDeploymentOccurred++
    }
    throw "deployment not completed within timeout"
}

Describe "storage setup" {
    BeforeAll {
        $script:details = Get-AzureStorageAccountDetailsAndCreateIfNotExists $storageAccountName
    }

    AfterAll {
        Remove-AzureStorageAccount -StorageAccountName $storageAccountName
    }

    It "creating a storage account returns key and endpoint" {
        $details.blobEndPoint | Should Not BeNullOrEmpty
        $details.accountKey | Should Not BeNullOrEmpty
    }

    It "can create a blob container and read and write to that container on a new storage account" {
        new-azurestoragecontainer -Name $storageContainerName -Permission "Blob"
        
        Put-AzureStorageBlobTextData "test.txt" "hello world!" $storageContainerName $storageAccountName $details.accountKey
        $getText = (Get-AzureStorageBlobTextData "test.txt" $storageContainerName $storageAccountName $details.accountKey)

        $getText | Should Be "hello world!"
    }
}

Describe "site setup" {
    BeforeAll {
        Check-VarNotNullOrWhiteSpace $githubPassword "github password not set?"

        LocalGitRepoShouldNotExist
        GithubRepoShouldNotExist

        Create-LocalGitRepo

        write-host "creating githubrepo $githubrepo..."
        create-githubrepo $githubrepo
    }

    AfterAll {
        cd $currentPath
        Delete-LocalGitRepo
        delete-githubrepoifexists
    }
   
    Context "create staging site" {
        BeforeAll {
            SiteShouldNotExist $stagingSitename
            GithubWebhookShouldNotExist $stagingSitename

            write-host "setting up staging site $stagingSitename"
            write-host "against github repo: $githubRepo..."
            Setup-SiteWithGithubDeployment "test" $githubRepo $stagingSitename "testName=John"

            $siteDetails = Get-AzureWebsite $stagingSitename

            write-host "github repo name: $githubrepo"
            write-host "staging site name: $stagingSitename"
         }

        AfterAll {
            Delete-SiteIfExists $stagingSitename
        }

        It "staging site has been created" {
            $siteDetails -eq $null | Should Be $false
        }

        It "staging site is enabled" {
            $siteDetails.Enabled | Should Be $true
        }

        It "staging site php has been turned off" {
            $phpVersionEmpty = [string]::IsNullOrWhitespace($siteDetails.phpVersion)
            $phpVersionEmpty | Should Be $true
        }

        It "staging site has deployment branch set as master" {
            $siteDetails.AppSettings.deployment_branch | Should Be "master"
        }

        It "staging site build configuration set as debug" {
            $siteDetails.AppSettings.SCM_BUILD_ARGS | Should Be "-p:Configuration=Debug"
        }

        It "staging site is on Free SKU" {
            $siteDetails.SKU | Should Be "Free"
        }

        It "staging site is online with deployed content" {
            start-sleep -s 5
            Test-DeploymentCompleted $stagingSitename "initial commit"
            (curl -method "GET" -uri "http://$stagingSitename.azurewebsites.net/").content.trim() -eq "hello world!" | Should Be $true
        }

        It "pushing to github sets off a deployment and site picks up the appsettings that azure sets during deployment" {
            $deployMsg = "adding aspx page to check an appsetting"
            '<%@ Page Language="C#" %>' | out-file appsettings.aspx -encoding ascii
            '<%Response.Write(System.Configuration.ConfigurationSettings.AppSettings["testName"]); %>' | out-file appsettings.aspx -encoding ascii -append -noclobber
            git add .
            git commit -m $deployMsg
            git push

            Test-DeploymentCompleted $stagingSitename $deployMsg

            write-host (Get-AzureSiteCurrentDeployment $stagingSiteName)
            (curl -method "GET" -uri "http://$stagingSitename.azurewebsites.net/appsettings.aspx").content.trim() -eq "john" | Should Be $true
        }
    }
   
    Context "create prod site" {
        BeforeAll {
            SiteShouldNotExist $prodSitename
            GithubWebhookShouldNotExist $prodSitename

            git checkout -b "release"
            "This is the release branch!" | out-file index.html -encoding ascii
            git add .
            git commit -m "release commit"
            git push --set-upstream origin release

            write-host "setting up prod site $prodSitename"
            write-host "against github repo: $githubRepo..."
            Setup-SiteWithGithubDeployment "prod" $githubRepo $prodSitename "testName=John" @($prodSitename)

            $siteDetails = Get-AzureWebsite $prodSitename

            write-host "github repo name: $githubrepo"
            write-host "prod site name: $prodSitename"
        }

        AfterAll {
            Delete-SiteIfExists $prodSiteName
        }

        It "prod site has been created" {
            $siteDetails -eq $null | Should Be $false
        }

        It "prod site is enabled" {
            $siteDetails.Enabled | Should Be $true
        }

        It "prod site php has been turned off" {
            $phpVersionEmpty = [string]::IsNullOrWhitespace($siteDetails.phpVersion)
            $phpVersionEmpty | Should Be $true
        }

        It "prod site has deployment branch set as release" {
            $siteDetails.AppSettings.deployment_branch | Should Be "release"
        }

        It "prod site build configuration set as Release" {
            $siteDetails.AppSettings.SCM_BUILD_ARGS | Should Be "-p:Configuration=Release"
        }

        It "prod site is on Shared SKU" {
            $siteDetails.SKU | Should Be "Shared"
        }

        It "prod site is online with deployed content from release branch" {
            Test-DeploymentCompleted $prodSiteName "release commit"
            (curl -method "GET" -uri "http://$prodSiteName.azurewebsites.net/").content.trim() -eq "This is the release branch!" | Should Be $true
        }

        It "prod site has hostname added to it" {
            Test-DeploymentCompleted $prodSiteName "release commit"
            (curl -method GET -uri "http://$prodSiteName.nickmeldrum.com/").content.trim() -eq "This is the release branch!" | Should Be $true
        }
    }
}

Describe "setup nickmeldrum blog" {
    BeforeAll {
        Setup-NickMeldrumBlog
    }

    It "staging site is reachable from azurewebsites domain" {
        $false | Should Be $true
    }

    It "staging site has site deployed onto it" {
        $false | Should Be $true
    }

    It "staging site has search functionality working" {
        $false | Should Be $true
    }

    It "prod site is reachable from azurewebsites domain" {
        $false | Should Be $true
    }

    It "prod site is reachable from nickmeldrum.com" {
        $false | Should Be $true
    }

    It "prod site has site deployed onto it" {
        $false | Should Be $true
    }

    It "prod site has search functionality working" {
        $false | Should Be $true
    }
}

