## Assumes you have pester installed as part of your profile
# pester is here: https://github.com/pester/Pester
# see here for installation: http://www.powershellmagazine.com/2014/03/12/get-started-with-pester-powershell-unit-testing-framework/
# or just run the .\install-pester.ps1 script here :)

import-module .\ps-cloud.psd1 -force

$siteNamePrefix = "pstest-"
$stagingSuffix = "-staging"
$randomString = [Guid]::NewGuid().ToString().replace("-", "").toupperinvariant().substring(5, 5)

$stagingSiteName = "$siteNamePrefix$randomString$stagingSuffix"

$currentPath = $pwd.Path
$localGitPath = "C:\temp\$randomString"
$githubRepo = "$siteNamePrefix$randomString"

# Local Git Repo Functions
#
Function Test-LocalGitRepoShouldNotExist {
    if (test-path $localGitPath) {
        throw "local github folder already exists!"
    }
}

Function Delete-TestLocalGitRepo {
    if (test-path $localGitPath) {
        remove-item $localgitpath -recurse -force
    }
}

Function Create-TestLocalGitRepo {
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
Function Test-StagingSiteShouldNotExist {
    $sitenameIfExists = (azure site list | grep $stagingSitename | gawk '{print $2}')
    if ($sitenameIfExists -ne $null) {
        throw "Site already exists!"
    }
}

Function Delete-TestStagingSiteIfExists {
    $sitenameIfExists = (azure site list | grep $stagingSitename | gawk '{print $2}')
    if ($sitenameIfExists -ne $null) {
        write-host "deleting azure site $sitenameIfExists..."
        Delete-AzureSite $sitenameIfExists $githubRepo
    }
}

Function Create-TestStagingSite {
    write-host "setting up staging site $stagingSitename..."
    write-host "against github repo: $githubRepo."
    Setup-StagingSite $stagingSitename $githubRepo "test1"
}

# Github Webhook Functions
#
Function Test-StagingGithubWebhookShouldNotExist {
    $hooks = List-GithubWebhooks $githubRepo
    if ($hooks.length -eq 0) {
        return
    }
    $webhook =  $hooks.config.url | where ({$_.indexof($stagingSitename) -ne -1})
    if ($webhook -ne $null) {
        throw "webhook already exists!"
    }
}

# Github Repo Functions
#
Function Test-GithubRepoShouldNotExist {
    $repos = (List-GithubRepos).name | where {$_ -eq $githubrepo}
    if ($repos.length -ne 0) {
        throw "github repo already exists!"
    }
}

Function Delete-TestGithubRepoIfExists {
    $repos = (List-GithubRepos).name | where {$_ -eq $githubrepo}
    if ($repos.length -ne 0) {
        Delete-GithubRepo $githubrepo
    }
}

Function Create-TestGithubRepo {
    write-host "creating githubrepo $githubrepo..."
    create-githubrepo $githubrepo
}

Describe "preconfigured sites setup" {
    BeforeAll {
        Test-LocalGitRepoShouldNotExist
        Test-GithubRepoShouldNotExist

        Create-TestLocalGitRepo
        Create-TestGithubRepo
    }

    AfterAll {
        cd $currentPath
        Delete-TestLocalGitRepo
        delete-testgithubrepoifexists
    }
   
    Context "create staging site" {
        BeforeAll {
            Test-StagingSiteShouldNotExist
            Test-StagingGithubWebhookShouldNotExist

            Create-TestStagingSite
            $siteDetails = Get-AzureWebsite $stagingSitename
         }

        AfterAll {
            Delete-TestStagingSiteIfExists
        }

        It "is enabled" {
            $siteDetails.Enabled | Should Be $true
        }

        It "php has been turned off" {
            $phpVersionEmpty = [string]::IsNullOrWhitespace($siteDetails.phpVersion)
            $phpVersionEmpty | Should Be $true
        }
    }
}

