using namespace System.Net

Function Invoke-ListSharepointQuota {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Sharepoint.Admin.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    Write-LogMessage -headers $Headers -API $APIName -message 'Accessed this API' -Sev 'Debug'

    # Interact with query parameters or the body of the request.
    $TenantFilter = $Request.Query.TenantFilter

    if ($Request.Query.TenantFilter -eq 'AllTenants') {
        $UsedStoragePercentage = 'Not Supported'
    } else {
        try {
            $tenantName = (New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/sites/root' -asApp $true -tenantid $TenantFilter).id.Split('.')[0]

            $sharepointToken = (Get-GraphToken -scope "https://$($tenantName)-admin.sharepoint.com/.default" -tenantid $TenantFilter)
            $sharepointToken.Add('accept', 'application/json')
            # Implement a try catch later to deal with sharepoint guest user settings
            $sharepointQuota = (Invoke-RestMethod -Method 'GET' -Headers $sharepointToken -Uri "https://$($tenantName)-admin.sharepoint.com/_api/StorageQuotas()?api-version=1.3.2" -ErrorAction Stop).value | Sort-Object -Property GeoUsedStorageMB -Descending | Select-Object -First 1

            if ($sharepointQuota) {
                $UsedStoragePercentage = [int](($sharepointQuota.GeoUsedStorageMB / $sharepointQuota.TenantStorageMB) * 100)
            }
        } catch {
            $UsedStoragePercentage = 'Not available'
        }
    }

    $sharepointQuotaDetails = @{
        GeoUsedStorageMB = $sharepointQuota.GeoUsedStorageMB
        TenantStorageMB  = $sharepointQuota.TenantStorageMB
        Percentage       = $UsedStoragePercentage
        Dashboard        = "$($UsedStoragePercentage) / 100"
    }

    $StatusCode = [HttpStatusCode]::OK

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $sharepointQuotaDetails
        })

}
