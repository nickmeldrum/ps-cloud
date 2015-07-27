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

Function Delete-Site {
    $sitenameIfExists = (azure site list | grep $stagingSitename | gawk '{print $2}')
    if ($sitenameIfExists -ne $null) {
        write-host "deleting azure site $sitenameIfExists..."
        Delete-AzureSite $sitenameIfExists $githubRepo
    }
}

Function Create-LocalGitRepo {
    write-host "creating local git repo..."
    git init
    echo "hello world!" > index.html
    git add .
    git commit -m "initial commit"
}

Describe "preconfigured sites setup" {
    BeforeAll {
        mkdir $localGitPath
        cd $localGitPath
        Create-LocalGitRepo
        write-host "creating githubrepo $githubrepo..."
        create-githurepo $githubrepo
     }

    AfterAll {
        cd $currentPath
        Delete-Site
        remove-item $localGitPath -recurse -force
        delete-githubrepo $githubrepo
    }

    Context "check preconditions" {
        It "azure site does not exist without trying anything" {
            $sitenameIfExists = (azure site list | grep $stagingSitename | gawk '{print $2}')
            $sitenameIfExists | Should Be $null
        }

        It "github webhook does not exist without trying anything" {
            $webhook = (List-GithubWebhooks $githubRepo).config.url | where ({$_.indexof($stagingSitename) -ne -1})
            $webhook | Should Be $null
        }
    }
    
    Context "create staging site" {
        BeforeAll {
            write-host "setting up staging site $stagingSitename..."
            write-host "against github repo: $githubRepo."
            Setup-StagingSite $stagingSitename $githubRepo "test1"

            $siteDetails = Get-AzureWebsite $stagingSitename
            write-host $siteDetails
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

