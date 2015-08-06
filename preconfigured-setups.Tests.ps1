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
        azure site delete -q $stagingSitename
    }
}

Function Create-TestStagingSite {
    write-host "setting up staging site $stagingSitename..."
    write-host "against github repo: $githubRepo."
    Setup-SiteWithGithubDeployment "test" $githubRepo $stagingSitename "testName=John"
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

Function Test-DeploymentCompleted {
    param ($sitename, $deployMsg)

    $timesToTestIfDeploymentOccurred = 0
    while ($timesToTestIfDeploymentOccurred < 5) {
        $currentDeployment = (Get-AzureWebsiteDeployment -name $sitename | where {$_.Current -eq $true})
        if ($currentDeployment.Status -eq "Success" -and $currentDeployment.Complete -eq "True"
                -and $currentDeployment.Message.trim() -eq $deployMsg) {
            return
        }
        start-sleep -s 5
    }
    throw "deployment not completed within timeout"
}

Describe "preconfigured sites setup" {
    BeforeAll {
        Check-VarNotNullOrWhiteSpace $githubPassword "github password not set?"

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

            write-host "github repo name: $githubrepo"
            write-host "staging site name: $stagingSitename"
         }

        AfterAll {
            Delete-TestStagingSiteIfExists
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

        It "staging site is online with deployed content" {
            start-sleep -s 5
            Test-DeploymentCompleted $stagingSitename "initial commit"
            (curl -method "GET" -uri "http://$stagingSitename.azurewebsites.net/").content.trim() -eq "hello world!" | Should Be $true
        }

        It "site picks up the appsettings that azure sets" {
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

# TODO: STILL TO TEST:
# committing to master and then pushing sets off a new deployment
# that we have both a staging and a prod website and prod website deploys from release branch
# that correct build configuration has been picked up
# that azure storage has been setup correctly
# that hostname on prod website has been setup correctly
# that staging site is on free plan and prod site on shared plan (cos of hostname)
    }
}

