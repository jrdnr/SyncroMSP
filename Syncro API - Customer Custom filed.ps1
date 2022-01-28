<#
.Synopsis
   Update a customer custom field using the Syncro API
.DESCRIPTION
   To use this script, you have to create a API Token that has those permissions:
   - Customer - Edit
.NOTES
  Version:        1.0
  Author:         Alexandre-Jacques St-Jacques
  Creation Date:  14-04-2021
  Purpose/Change: Initial script development
#>

# The API token used for the request. Create a API key with permission "Customer - Edit". It is advised to populated it with the "Script variable" feature of syncro
#$ApiToken = "test"
# Will usually be syncromsp.com
$ApiBaseURL = $env:RepairTechApiBaseURL
# Your account sub domain will magically be imported.
$ApiSubDomain = $env:RepairTechApiSubDomain

function Update-CustomerCustomField {
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $ApiToken,
        [Parameter(Mandatory=$true)]
        [String]
        $CustomerId,
        [Parameter(Mandatory=$true)]
        [String]
        $CustomField,
        [Parameter(Mandatory=$true)]
        [String]
        $CustomFieldValue
    )

$headers = @{
    Content='application/json'
    Authorization="Bearer $ApiToken"
}

$payload = @"
{
    "properties": {
        "$CustomField": "$CustomFieldValue"
    }
}
"@

    $ApiPath = "/api/v1/customers"

    $resp = try {
        Invoke-RestMethod -Method PUT "https://$($ApiSubDomain).$($ApiBaseURL)$($ApiPath)/$($CustomerId)" -Headers $headers -Body "$payload" -ContentType "application/json"
    } catch {
        Write-Host "ERROR!"
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host $responseBody
    }
}

# This is the function call to update the custom field of a customer. I would recommend you to populate $CustomerID using a script variable that uses the "{{customer_id}}" platform variable
Update-CustomerCustomField -ApiToken $ApiToken -CustomerId $CustomerID -CustomField "Customer test" -CustomFieldValue "testing"
