## Assumes you have pester installed as part of your profile
# pester is here: https://github.com/pester/Pester
# see here for installation: http://www.powershellmagazine.com/2014/03/12/get-started-with-pester-powershell-unit-testing-framework/
# or just run the .\install-pester.ps1 script here :)

import-module .\ps-cloud.psd1

Describe "nickmeldrum-blog setup" {

    Context "staging site setup" {
        BeforeEach {
            $sitenameIfExists = (azure site list | grep "nickmeldrum-staging" | gawk '{print $2}')
            if ($sitenameIfExists -ne $null) {
                Delete-AzureSite $sitenameIfExists
            }
        }

        It "azure site does not exist without trying anything (before each is doing it's job)" {
            $sitenameIfExists = (azure site list | grep "nickmeldrum-staging" | gawk '{print $2}')
            $sitenameIfExists | Should Be $null
        }

        It "github webhook does not exist without trying anything (before each is doing it's job)" {
            $webhook = (List-GithubWebhooks "nickmeldrum.com.markdownblog").config.url | where ({$_.indexof("nickmeldrum-staging") -ne -1})
            $webhook | Should Be $null
        }

        It "staging setup creates azure site and autodeploys onto it" {
            $false | Should Be $true
        }
    }
}

