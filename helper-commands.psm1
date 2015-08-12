$ErrorActionPreference = "Stop"

Function Check-VarNotNullOrWhiteSpace {
    param ([string]$var, [string]$msg)

    if ([string]::IsNullOrWhiteSpace($var)) {
        throw $msg
    }
}

Function Delete-AllTestSites {
    (get-azurewebsite).name | where {$_.startswith("pstest")} | % { remove-azurewebsite -force -name $_ }
}

Function Delete-AllTestRepos {
    (List-GithubRepos).name | where { $_.startswith("pstest") } | % { delete-githubrepo $_ }
}

export-modulemember *-*

