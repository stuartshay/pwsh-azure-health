// Azure Health Monitoring - Bicep Parameters (Development)

using './main.bicep'

param environment = 'dev'
param baseName = 'azurehealth'
param timerSchedule = '0 */15 * * * *'
param cacheContainerName = 'servicehealth-cache'

// User-Assigned Managed Identity from shared resource group
// This value will be passed from deploy-bicep.ps1 script which reads it from shared-identity-info.json
// For manual deployments, get the Resource ID from: az identity show --name id-azurehealth-shared --resource-group rg-azure-health-shared --query id -o tsv
param managedIdentityResourceId = ''
