## Assumes you have pester installed as part of your profile
# pester is here: https://github.com/pester/Pester
# see here for installation: http://www.powershellmagazine.com/2014/03/12/get-started-with-pester-powershell-unit-testing-framework/
# or just run the .\install-pester.ps1 script here :)

import-module .\ps-cloud.psd1 -force

$stagingSitename = "nmpester-test-staging"
$githubRepo = "nickmeldrum.com.markdownblog"
$siteAdminPassword = "test1"

Describe "nickmeldrum-blog setup" {
    $sitenameIfExists = (azure site list | grep $stagingSitename | gawk '{print $2}')
    if ($sitenameIfExists -ne $null) {
        write-host "deleting azure site $sitenameIfExists..."
        Delete-AzureSite $sitenameIfExists
    }

    It "azure site does not exist without trying anything (initial clean up worked)" {
        $sitenameIfExists = (azure site list | grep $stagingSitename | gawk '{print $2}')
        $sitenameIfExists | Should Be $null
    }

    It "github webhook does not exist without trying anything (initial clean up worked)" {
        $webhook = (List-GithubWebhooks $githubRepo).config.url | where ({$_.indexof($stagingSitename) -ne -1})
        $webhook | Should Be $null
    }
    
    Context "create staging site" {
        write-host "setting up staging site $stagingSitename..."
        write-host "against github repo: $githubRepo."
        Setup-StagingSite $stagingSitename $githubRepo $siteAdminPassword
        $siteDetails = Get-AzureWebsite $stagingSitename
        write-host $siteDetails

        It "is enabled" {
            $siteDetails.Enabled | Should Be $true
        }

        It "php has been turned off" {
            $phpVersionEmpty = [string]::IsNullOrWhitespace($siteDetails.phpVersion)
            $phpVersionEmpty | Should Be $true
        }
    }
}

