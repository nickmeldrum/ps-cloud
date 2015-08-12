$headers = @{
    "X-DNSimple-Token" = ($dnsimpleEmail + ":$dnsimpleToken");
    "Content-Type" = "application/json";
    "Accept" = "application/json";
}

Function Get-DnsimpleCnameRecords {
    param ($domainName)

    Check-VarNotNullOrWhiteSpace $domainName "please pass in a domain name"
    Check-VarNotNullOrWhiteSpace $dnsimpleEmail "please set a dnsimpleEmail variable globally for example in your powershell profile"
    Check-VarNotNullOrWhiteSpace $dnsimpleToken "please set a dnsimpleToken variable globally for example in your powershell profile"

    $allRecords = ((curl -method "GET" -uri "https://api.dnsimple.com/v1/domains/$domainName/records" -header $headers).content | convertfrom-json).record
    return $allRecords | where {$_.record_type -eq "CNAME"} | select id, name, content
}

Function Create-DnsimpleCnameRecord {
    param ($domainName, $name, $content)

    Check-VarNotNullOrWhiteSpace $domainName "please pass in a domain name"
    Check-VarNotNullOrWhiteSpace $name "please pass in a host header or * for all"
    Check-VarNotNullOrWhiteSpace $content "please pass in a destination domain"
    Check-VarNotNullOrWhiteSpace $dnsimpleEmail "please set a dnsimpleEmail variable globally for example in your powershell profile"
    Check-VarNotNullOrWhiteSpace $dnsimpleToken "please set a dnsimpleToken variable globally for example in your powershell profile"

    $bodyJson = "{ `"record`": { `"name`": `"$name`", `"record_type`": `"CNAME`", `"content`": `"$content`" } }"

    curl -method "POST" -uri "https://api.dnsimple.com/v1/domains/$domainName/records" -header $headers -body $bodyJson
}

Function Delete-DnsimpleCnameRecord {
    param ($domainName, $id)

    Check-VarNotNullOrWhiteSpace $domainName "please pass in a domain name"
    Check-VarNotNullOrWhiteSpace $id "please pass in an id of the record you want to delete"
    Check-VarNotNullOrWhiteSpace $dnsimpleEmail "please set a dnsimpleEmail variable globally for example in your powershell profile"
    Check-VarNotNullOrWhiteSpace $dnsimpleToken "please set a dnsimpleToken variable globally for example in your powershell profile"

    curl -method "DELETE" -uri "https://api.dnsimple.com/v1/domains/$domainName/records/$id" -header $headers
}
