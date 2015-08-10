$storageAccountName = "nickmeldrum"
$storageContainerName = "luceneindex"
$azureLocation = "North Europe"

##### Accounts:

# list storage accounts
azure storage account list
$subscriptionId = (Get-AzureSubscription | where {$_.IsCurrent -eq $true}).Subscriptionid
set-azuresubscription -subscriptionid $subscriptionId -currentstorageaccountname $storageAccountName
get-azurestorageaccount

# specific storage account exists
$storageAccountList = (azure storage account list | gawk '{print $2}')
$storageAccountList.Contains($storageAccountName)
(get-azurestorageaccount).storageaccountname.contains($storageAccountName)

# create storage account
azure storage account create --type LRS --location $azureLocation $storageAccountName
New-AzureStorageAccount -storageaccountname $storageAccountName -location $azureLocation -type "Standard_LRS"

# delete storage account
azure storage account delete -q $storageAccountName
remove-azurestorageaccount -storageaccountname $storageAccountName

# get primary storage account key
$accountKey = (Get-AzureStorageKey $storageAccountName).primary
$accountKey = azure storage account keys list $storageAccountName | where {$_.Contains("Primary")} | gawk '{print $3}'

# get storage account blob endpoint:
(Get-AzureStorageAccount $storageAccountName).endpoints | where {$_.tolowerinvariant().contains("blob")}

##### Containers:

# list containers for account
azure storage container list -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"
Get-AzureStorageContainer

# container exists
$containerList = (azure storage container list -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey" | gawk '{print $2}')
$containerList.Contains($storageContainerName)
(get-azurestoragecontainer).name.contains($storageContainerName)

# create container with permissions off
azure storage container create $storageContainerName -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"
new-azurestoragecontainer -Name $storageContainerName

# create container with blob public access level
azure storage container create $storageContainerName -p Blob -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"
new-azurestoragecontainer -Name $storageContainerName -Permission "Blob"

# delete container
azure storage container delete $storageContainerName -q -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"
remove-azurestoragecontainer -name $storageContainerName -force

# list blobs in container:
azure storage blob list $storageContainerName -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"
Get-AzureStorageBlob -container $storageContainerName

# blobs exist in container:
$blobs = (azure storage blob list $storageContainerName -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey")
($blobs | where {$_.Contains("No blobs found")}).length -eq 0
(Get-AzureStorageBlob -container $storageContainerName).length -gt 0

