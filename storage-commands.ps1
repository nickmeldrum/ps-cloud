$storageAccountName = "nickmeldrum"
$storageContainerName = "luceneindex"
$azureLocation = "North Europe"

##### Accounts:

# list storage accounts
azure storage account list

# specific storage account exists
$storageAccountList = (azure storage account list | gawk '{print $2}')
$storageAccountList.Contains($storageAccountName)

# create storage account
azure storage account create --type LRS --location $azureLocation $storageAccountName

# delete storage account
azure storage account delete -q $storageAccountName

# get primary storage account key
$accountKey = azure storage account keys list $storageAccountName | where {$_.Contains("Primary")} | gawk '{print $3}'

##### Containers:

# list containers for account
azure storage container list -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"

# container exists
$containerList = (azure storage container list -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey" | gawk '{print $2}')
$containerList.Contains($storageContainerName)

# create container with permissions off
azure storage container create $storageContainerName -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"

# create container with blob public access level
azure storage container create $storageContainerName -p Blob -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"

# delete container
azure storage container delete $storageContainerName -q -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"

# list blobs in container:
azure storage blob list luceneindex -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey"

# blobs exist in container:
$blobs = (azure storage blob list $storageContainerName -c "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$accountKey")
($blobs | where {$_.Contains("No blobs found")}).length -eq 0

