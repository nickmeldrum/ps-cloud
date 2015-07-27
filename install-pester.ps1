function Get-UserModulePath {
 
    $Path = $env:PSModulePath -split ";" -match $env:USERNAME
 
    if (-not (Test-Path -Path $Path))
    {
        New-Item -Path $Path -ItemType Container | Out-Null
    }
    return $Path
}

$modulePath = get-usermodulepath

(New-Object Net.WebClient).DownloadFile('https://github.com/pester/Pester/archive/master.zip','C:\pester.zip');
$shell = New-Object -ComObject Shell.Application
$pesterModuleDir = $shell.NameSpace("c:\pester.zip\pester-master")
$shell.NameSpace($modulePath).CopyHere($pesterModuleDir)
ren "$modulePath\pester-master" "$modulePath\pester"

Import-Module Pester

