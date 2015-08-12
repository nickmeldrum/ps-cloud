$ErrorActionPreference = "Stop"

$azureLocation = "North Europe"

Function Get-AzureStorageAccountDetailsAndCreateIfNotExists {
    param([string]$storageAccountName)

    $subscriptionId = (Get-AzureSubscription | where {$_.IsCurrent -eq $true}).Subscriptionid
    $null = set-azuresubscription -subscriptionid $subscriptionId -currentstorageaccountname $storageAccountName
    $storageAccounts = get-azurestorageaccount
    if ($storageAccounts.Count -eq 0 -or -not $storageAccounts.storageaccountname.contains($storageAccountName)) {
        $null = New-AzureStorageAccount -storageaccountname $storageAccountName -location $azureLocation -type "Standard_LRS"
    }

    $accountKey = (Get-AzureStorageKey $storageAccountName).primary
    $blobEndPoint = (Get-AzureStorageAccount $storageAccountName).endpoints | where {$_.tolowerinvariant().contains("blob")}

    $returnHT = @{accountKey=$accountKey;blobEndPoint=$blobEndPoint}
    $returnObj = new-object psobject -property $returnHT
    return $returnObj
}

# thanks to this article for the complicated code! http://sqlblog.com/blogs/jamie_thomson/archive/2014/09/12/create-a-blob-in-azure-blob-storage-using-the-rest-api-and-powershell.aspx

Function Put-AzureStorageBlobTextData {
    param ([string]$fileName, [string]$content, [string]$storageContainerName, [string]$storageAccountName, [string]$storageAccountKey)

    $Url = "https://$StorageAccountName.blob.core.windows.net/$StorageContainerName/$fileName"
    $method = "PUT"
    $headerDate = '2014-02-14'
    $headers = @{"x-ms-version"="$headerDate"}
    $xmsdate = (get-date -format r).ToString()
    $bytes = ([System.Text.Encoding]::UTF8.GetBytes($content))
    $contentLength = $bytes.length
    $null = $headers.Add("x-ms-date",$xmsdate)
    $null = $headers.Add("Content-Length","$contentLength")
    $null = $headers.Add("x-ms-blob-type","BlockBlob")

    $signatureString = "$method$([char]10)$([char]10)$([char]10)$contentLength$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)"
#Add CanonicalizedHeaders
    $signatureString += "x-ms-blob-type:" + $headers["x-ms-blob-type"] + "$([char]10)"
    $signatureString += "x-ms-date:" + $headers["x-ms-date"] + "$([char]10)"
    $signatureString += "x-ms-version:" + $headers["x-ms-version"] + "$([char]10)"
#Add CanonicalizedResource
    $uri = New-Object System.Uri -ArgumentList $url
    $signatureString += "/" + $StorageAccountName + $uri.AbsolutePath

    $dataToMac = [System.Text.Encoding]::UTF8.GetBytes($signatureString)

    $accountKeyBytes = [System.Convert]::FromBase64String($StorageAccountKey)

    $hmac = new-object System.Security.Cryptography.HMACSHA256((,$accountKeyBytes))
    $signature = [System.Convert]::ToBase64String($hmac.ComputeHash($dataToMac))

    $null = $headers.Add("Authorization", "SharedKey " + $StorageAccountName + ":" + $signature);
    return Invoke-RestMethod -Uri $Url -Method $method -headers $headers -Body $content
}

Function Get-AzureStorageBlobTextData {
    param ([string]$fileName, [string]$storageContainerName, [string]$storageAccountName, [string]$storageAccountKey)

    $Url = "https://$StorageAccountName.blob.core.windows.net/$StorageContainerName/$fileName"
    $method = "GET"
    $headerDate = '2014-02-14'
    $headers = @{"x-ms-version"="$headerDate"}
    $xmsdate = (get-date -format r).ToString()
    $null = $headers.Add("x-ms-date",$xmsdate)
    $null = $headers.Add("Content-Length","0")
    $null = $headers.Add("x-ms-blob-type","BlockBlob")

    $signatureString = "$method$([char]10)$([char]10)$([char]10)$contentLength$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)$([char]10)"
#Add CanonicalizedHeaders
    $signatureString += "x-ms-blob-type:" + $headers["x-ms-blob-type"] + "$([char]10)"
    $signatureString += "x-ms-date:" + $headers["x-ms-date"] + "$([char]10)"
    $signatureString += "x-ms-version:" + $headers["x-ms-version"] + "$([char]10)"
#Add CanonicalizedResource
    $uri = New-Object System.Uri -ArgumentList $url
    $signatureString += "/" + $StorageAccountName + $uri.AbsolutePath

    $dataToMac = [System.Text.Encoding]::UTF8.GetBytes($signatureString)

    $accountKeyBytes = [System.Convert]::FromBase64String($StorageAccountKey)

    $hmac = new-object System.Security.Cryptography.HMACSHA256((,$accountKeyBytes))
    $signature = [System.Convert]::ToBase64String($hmac.ComputeHash($dataToMac))

    $null = $headers.Add("Authorization", "SharedKey " + $StorageAccountName + ":" + $signature);
    return Invoke-RestMethod -Uri $Url -Method $method -headers $headers
}

export-modulemember *-*

