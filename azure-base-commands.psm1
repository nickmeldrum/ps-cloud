$ErrorActionPreference = "Stop"

$loggedIn = $false

Function CheckDependencies {
    if ((get-childitem .\*.publishsettings).length -eq 0) {
        throw "no publishsettings file found - can't login to azure, exiting (Ensure 1 .publishsettings file with 1 subscription is in the directory you are executing in.)"
    }
    if ((get-childitem .\*.publishsettings).gettype().IsArray) {
        throw "more than 1 publishsettings file found - dont' know which one to use, exiting. (Ensure 1 .publishsettings file with 1 subscription is in the directory you are executing in.)"
    }
}

Function Setup-AzureApi {
    echo "installing azure powershell module and azure xpat cli..."
    Import-Module "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
    npm install azure-cli -g
}

Function Login-AzureApi {
    CheckDependencies

    if ($script:loggedIn -eq $false) {
        echo "Assuming the azure powershell module and the azure xpat cli have already been installed - if not, please run Setup-AzureApi first..."

        echo "logging into both azure powershell and azure xpat cli..."
        $publishSettings = (get-childitem .\*.publishsettings).fullname
        Import-AzurePublishSettingsFile $publishSettings
        azure account import $publishSettings
        $script:loggedIn = $true
    }
}

Function Set-ReleaseMode {
    param ([string]$relMode)

    $script:releaseMode = $relMode
}

Function Get-ReleaseMode {
    return $releaseMode
}

export-modulemember *-*

