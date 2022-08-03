<#
    .Synopsis
        Allow Dataguard VNet access to all storage accounts through Service Endpoints.
    .Description
        This script will iterate through all the storage accounts across all subscriptions.
        If it found storage account :
        * that allows access from all networks - then it will do nothing
        * that allows access from selected networks - then it will ADD dataguard VNet to the allowed network list
        * that blocks all networks - then it will not modify anything but just report the disabled storage account for further review.
        
        NOTE: This script onlt allows Dataguard network to be allowed for storage account. As such it does not give any permission.
        Permissions still continue to be governed by the Role Assignments.
#>
param(
  [string]$tenandId, # The Tenant ID where DataGuard is deployed.
  [string]$subnetId # The name of the managed DataGuard identity.
)

$disabled = @() 
$Result=@()
Get-AzSubscription -TenantId $tenandId | ForEach-Object {
        $_ | Set-AzContext                            
        Get-AzStorageAccount | ForEach-Object {
            $storageaccount = $_
            if ($storageaccount.PublicNetworkAccess -eq 'Disabled') {
                $disabled += $storageaccount
            }
            
            Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $storageaccount.ResourceGroupName -AccountName $storageaccount.StorageAccountName | ForEach-Object {
                    
                    $Result += New-Object PSObject -property @{ 
                        Account = $storageaccount.StorageAccountName
                        ResourceGroup = $storageaccount.ResourceGroupName
                        Bypass = $_.Bypass
                        Action = $_.DefaultAction
                        IPrules = $_.IpRules
                        Vnetrules = $_.VirtualNetworkRules
                        ResourceRules = $_.ResourceAccessRules
                        Public = $storageaccount.PublicNetworkAccess
                    }
                    
                    if ( $_.DefaultAction -eq 'Deny' ){
                        Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $storageaccount.ResourceGroupName -AccountName $storageaccount.StorageAccountName -VirtualNetworkRule (
                            @{VirtualNetworkResourceId = $subnetId}
                        )
                    }
            }           
        }
    }

-join('["', (($disabled).Id -join '","'), '"]') | Out-File "~/disabled_storage_accounts.txt"