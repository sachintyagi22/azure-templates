# azure-templates

Azure deployment templates to bring up and configure the dataguard landing zone in the customer Azure environment. The dataguard services can then be installed in this landing zone.

NOTE: The `Deploy to Azure` button does not work on Gitlab due to this CORS related [issue](https://gitlab.com/gitlab-org/gitlab/-/issues/16732).
Therefore the deploy to azure button points to the public copy of this repo on Github. Eventually we can move these scripts to some other publicly accessible location, say S3, but it will involve the hassle of always keeping the repo, s3, and links in sync.

## Prerequisites
1. A user with `AAD Global Administrators` to deploy this template.
2. Follow the steps [here](https://github.com/Azure/Enterprise-Scale/blob/main/docs/EnterpriseScale-Setup-azure.md) to configure deploying user's permissions for ARM tenant deployment.
3. Collect the following information from your Azure environment as it will used as parameters to the deployment:
    * Billing Account Id 
    * Billing Profile Id
    * Invoice Section Id
    [Steps to fetch this information](#how-to-get-billing-account-name)
4. Subscription Ids for which activities are to be monitored by Dataguard

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Fmain%2Ftemplates%2Fsetup-dataguard-subscription.json)

## What these templates do
1. Create a new dataguard subscription. 
2. Create a managed identity and 
    * Assign it RBAC permissions for the AD tenant graph
    * Subscription contributor role on the data guard subscription
    * Reader role at the root tenant group
3. Create a VNet in the dataguard subscription.
4. Create a storage account in the subscription without public access.
    * Create a private endpoint from the VNet
5. Configure subscription level log diagnostic settings to push the activity logs data to dataguard storage account
6. Configure any resource logs (that need to be analyzed by the dataguard) diagnostic settings to make it available to dataguard storage account.
7. Launch VMs in the VNet.
8. Create a bastion host in the public subnet to connect to the VMs in the VNet.

## What these templates do NOT do
1. Install dataguard services on the VMs.

For this we can use our existing workflows for AWS/GCP.

## How to Get Billing Account Name
1. Signin with Azure Powershell (signin user should have access to billing information). [Steps](https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-7.1.0)
2. Run [this script](scripts/fetch-billing-accounts.ps1) after login and note down the relevant billing information. It will produce information about different billing sections, note down the one you want to use for creating a new subscription for dataguard.
```
Option 1
	 Billing Account Id: aaaaaaaa-1111-1111-1111-1111aaaabbbb:cccc2222-1111-2222-3333-eeeeffff1111_2019-01-01
	 Billing Profile Id: YAAA-XXXX-YYY-PPP   	 (Name: Bhimsen Joshi)
	 Invoice Section Id: NNNN-OOOO-PPP-GGG   	 (Name: Joshi Profile)

Option 2
	 Billing Account Id: aaaaaaaa-1111-1111-1111-1111aaaabbbb:cccc2222-1111-2222-3333-eeeeffff1111_2019-01-01
	 Billing Profile Id: YAAA-XXXX-YYY-PPP   	 (Name: Bhimsen Joshi)
	 Invoice Section Id: BBBB-TTTT-UUU-KKK   	 (Name: Test Profile)
```

## Useful references

1. Creating subscriptions with ARM templates. [link](https://techcommunity.microsoft.com/t5/azure-governance-and-management/creating-subscriptions-with-arm-templates/ba-p/1839961)
2. [link](https://stackoverflow.com/questions/63478559/how-to-deploy-arm-template-with-user-managed-identity-and-assign-a-subscription)
