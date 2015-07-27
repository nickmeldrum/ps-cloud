## Assumes you have pester installed as part of your profile
# pester is here: https://github.com/pester/Pester
# see here for installation: http://www.powershellmagazine.com/2014/03/12/get-started-with-pester-powershell-unit-testing-framework/
# or just run the .\install-pester.ps1 script here :)

import-module .\ps-cloud.psd1

Describe "nickmeldrum-blog setup" {
    Context "staging site setup" {
        $result = 1

        It "gets setup" {
            $result | Should Be 2
        }
    }
}

