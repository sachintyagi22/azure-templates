# azure-templates

Azure deployment templates to bring up and configure the client Azure environment for dataguard.

The `Deploy to Azure` button does not work on Gitlab due to this [issue](https://gitlab.com/gitlab-org/gitlab/-/issues/16732).


## Steps: 
0. Create a user managed identity called "dataguard-identity" (Manual).
    * Assign it the RBAC permissions for AD tenant Graph.
    * Assign it the reader role at the root tenant group.
1. Create a new dataguard subscription. [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsachintyagi22%2Fazure-templates%2Fmain%2Ftemplates%2Fcreate-dataguard-subscription.json)
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
9. Install dataguard services on the VMs.