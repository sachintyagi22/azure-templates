<#
    .Synopsis
        
    .Description
        
#>

$TenantID="<tenant id>"
$GraphAppId = "00000003-0000-0000-c000-000000000000"
$DisplayNameOfMSI="template-created-dg-id"
$PermissionNames = "Directory.Read.All", "UserAuthenticationMethod.Read.All"

# Install the module if needed: Install-Module AzureAD

Connect-AzureAD -TenantId $TenantID

$MSI = (Get-AzureADServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'")

Start-Sleep -Seconds 10

$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"
foreach($pName in $PermissionNames){
    $AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $pName -and $_.AllowedMemberTypes -contains "Application"}

    New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
}

function Get-AzCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'

    $azureRmProfileModuleVersion = (Get-Module Az.Profile).Version
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azureRmProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
  
    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
$token = Get-AzCachedAccessToken
$ruleName = "dataguard-managed-id-ad-diag-setting"

Select-AzureRmSubscription -Subscription 'Template Created DG Subscription'
$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName "dataguard-resource-grp"
$storageAccountId = $storageAccount.id

$uri = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/{0}?api-version=2017-04-01-preview" -f $ruleName
$body = @"
{
    "id": "providers/microsoft.aadiam/diagnosticSettings/$ruleName",
    "type": null,
    "name": "Storage Account",
    "location": null,
    "kind": null,
    "tags": null,
    "properties": {
      "storageAccountId": "$storageAccountId",
      "serviceBusRuleId": null,
      "workspaceId": null,
      "eventHubAuthorizationRuleId": null,
      "eventHubName": null,
      "metrics": [],
      "logs": [
        {
          "category": "AuditLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
          "category": "SignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        },
        {
          "category": "NonInteractiveUserSignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "ServicePrincipalSignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "ManagedIdentitySignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "ProvisioningLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "ADFSSignInLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "RiskyUsers",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }, 
        {
          "category": "UserRiskEvents",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }
      ]
    },
    "identity": null
  }
"@

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

$response = Invoke-WebRequest -Method Put -Uri $uri -Body $body -Headers $headers

if ($response.StatusCode -ne 200) {
    throw "an error occured: $($response | out-string)"

}