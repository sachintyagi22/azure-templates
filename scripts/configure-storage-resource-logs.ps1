<#
    .Synopsis
        Configure the diagnostic settings for resource logs of all storage account in all subscriptions to Dataguard storage account.
    .Description
        This script will iterate through all the storage accounts across all subscriptions and configures the dumping of resource logs
        of all the storage accounts found in the dataguard storage account.
#>

param(
    [string]$tenandId, # The Tenant ID where DataGuard is deployed.
    [string]$StorageAccountId, # The id of the dataguard storage account.
    [string]$Region
  )
  
$DiagnosticSettingName = "dataguard-resouce-diagnostics"

$disabled = @() 
Get-AzSubscription -TenantId $tenandId | ForEach-Object {
        $_ | Set-AzContext                            
        Get-AzStorageAccount | Where-Object {((($_.Location -eq $Region) -or ($Region -eq $null)) -and ($_.Id -ne $StorageAccountId))} | ForEach-Object {
            $storageaccount = $_
            if ($storageaccount.PublicNetworkAccess -eq 'Disabled') {
                $disabled += $storageaccount
            }
            $ResourceId = $storageaccount.Id
            $readlog = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category StorageRead -Enabled
            $writelog = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category StorageWrite -Enabled
            $deletelog = New-AzDiagnosticDetailSetting -Log -RetentionEnabled -Category StorageDelete -Enabled
            $Ids = @($ResourceId + "/blobServices/default"
                    $ResourceId + "/fileServices/default"
                    $ResourceId + "/queueServices/default"
                    $ResourceId + "/tableServices/default"
            )
            $Ids | ForEach-Object {
                $setting = New-AzDiagnosticSetting -Name $DiagnosticSettingName -ResourceId $ResourceId -StorageAccountId $StorageAccountId -Setting $readlog,$writelog,$deletelog
                Set-AzDiagnosticSetting -InputObject $setting
            }          
        }
    }