$ErrorActionPreference = "Stop"

Function Check-VarNotNullOrWhiteSpace {
    param ([string]$var, [string]$msg)

    if ([string]::IsNullOrWhiteSpace($var)) {
        throw $msg
    }
}

export-modulemember *-*

