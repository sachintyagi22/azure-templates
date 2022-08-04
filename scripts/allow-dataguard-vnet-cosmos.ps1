<#
    .Synopsis
        Allow Dataguard VNet access to all cosmos DBs through Service Endpoints.
    .Description
        
#>
param(
  [string]$tenantId, # The Tenant ID where DataGuard is deployed.
  [string]$subnetId, # The name of the subnet in which to create service endpoint.
  [string]$dataguardSubId, # Dataguard subscription id
  [string]$StorageAccountId, # The id of the dataguard storage account.
  [string]$DataguardIdentity # The id of the dataguard managed identioty.
)

$disabled = @() 
$Result=@()
# $tenantId = '938e7f1c-a9cc-47d3-897f-a12d33bf6c38'
# $dataguardSubId = 'b3f51724-9bff-43e5-9a6a-23f236ff683d'
# $subnetId = '/subscriptions/b3f51724-9bff-43e5-9a6a-23f236ff683d/resourceGroups/DataGuard_Demo_3_Grp/providers/Microsoft.Network/virtualNetworks/dataguard-vnet/subnets/app-gw-subnet'
# $StorageAccountId = '/subscriptions/b3f51724-9bff-43e5-9a6a-23f236ff683d/resourceGroups/azure-test-rg/providers/Microsoft.Storage/storageAccounts/dgwestplaintest'
# $DataguardIdentity = "bedc2f53-8a62-4e42-9960-b07c72ae4c46"

Set-AzContext -SubscriptionId $dataguardSubId
Register-AzResourceProvider -ProviderNamespace Microsoft.DocumentDB

Get-AzSubscription -TenantId $tenantId -SubscriptionId 6aa465aa-0075-40bc-a8da-cc33ef685b94 | Where-Object {$_.HomeTenantId -eq $tenantId} | ForEach-Object {
        $_ | Set-AzContext
        Get-AzResourceGroup | ForEach-Object {
            $resourceGroupName = $_.ResourceGroupName
            
            Get-AzCosmosDBAccount -ResourceGroupName $resourceGroupName | ForEach-Object {
                # $_.PSObject.Properties | ForEach-Object {
                #     Write-Host $_.Name ' --  ' $_.Value
                # }
                
                $accountName = $_.Name
                $roleName = 'DataguardCosmosReadOnly'
                New-AzCosmosDBSqlRoleDefinition -AccountName $accountName `
                    -ResourceGroupName $resourceGroupName `
                    -Type CustomRole -RoleName $roleName `
                    -DataAction @( `
                        'Microsoft.DocumentDB/databaseAccounts/readMetadata',
                        'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read', `
                        'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery', `
                        'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed') `
                    -AssignableScope "/"
                    
                $readOnlyRoleDefinition = Get-AzCosmosDBSqlRoleDefinition -AccountName $accountName `
                    -ResourceGroupName $resourceGroupName | Where-Object {$_.RoleName -eq $roleName} 
                $readOnlyRoleDefinitionId = $readOnlyRoleDefinition.Id
                Write-Host $readOnlyRoleDefinitionId
                New-AzCosmosDBSqlRoleAssignment -AccountName $accountName `
                    -ResourceGroupName $resourceGroupName `
                    -RoleDefinitionId $readOnlyRoleDefinitionId `
                    -Scope "/" `
                    -PrincipalId $DataguardIdentity
                
                $ResourceId = $_.Id
                $dataPlaneReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category DataPlaneRequests -Enabled
                $controlPlaneReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category ControlPlaneRequests -Enabled
                $mongoReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category MongoRequests -Enabled
                $cassandraReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category CassandraRequests -Enabled
                $gremlinReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category GremlinRequests -Enabled
                $tableApiReqs = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category TableApiRequests -Enabled
                $DiagnosticSettingName = "dataguard-resouce-diagnostics"
                $setting = New-AzDiagnosticSetting `
                    -Name $DiagnosticSettingName `
                    -ResourceId $ResourceId `
                    -StorageAccountId $StorageAccountId `
                    -Setting $dataPlaneReqs,$controlPlaneReqs,$mongoReqs,$cassandraReqs,$gremlinReqs,$tableApiReqs
                Set-AzDiagnosticSetting -InputObject $setting
                
                $Result += New-Object PSObject -property @{ 
                    Id = $_.Id
                    Name = $accountName
                    ResourceGroup = $resourceGroupName
                    IpRangeFilter = $_.IpRangeFilter
                    VirtualNetworkRules = $_.VirtualNetworkRules
                    NetworkAclBypass = $_.NetworkAclBypass
                    NetworkAclBypassResourceIds = $_.NetworkAclBypassResourceIds
                    PublicNetworkAccess = $_.PublicNetworkAccess
                    IsVirtualNetworkFilterEnabled = $_.IsVirtualNetworkFilterEnabled
                }

                if ( ($_.PublicNetworkAccess -eq 'Enabled') -and ($_.IsVirtualNetworkFilterEnabled -eq $true -or $_.IpRules.Count -ge 0)){
                    Write-Host 'Adding service endpoint to ' $subnetId
                    $vnetRule = New-AzCosmosDBVirtualNetworkRule -Id $subnetId
                    Update-AzCosmosDBAccount -ResourceGroupName $resourceGroupName `
                        -Name $accountName `
                        -EnableVirtualNetwork $true `
                        -VirtualNetworkRuleObject @($vnetRule)
                } else {
                    Write-Host 'NOT Adding service endpoint because $_.PublicNetworkAccess ' $_.PublicNetworkAccess ' and $_.IsVirtualNetworkFilterEnabled ' $_.IsVirtualNetworkFilterEnabled 
                }
                if ($_.PublicNetworkAccess -eq 'Disabled') {
                    $disabled += $_
                }
            }
        }                            
        
    }

-join('["', (($disabled).Id -join '","'), '"]') | Out-File "~/disabled_cosmosdb_accounts.txt"