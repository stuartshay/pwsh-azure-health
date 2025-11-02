@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name for resources (will be suffixed with environment)')
param baseName string = 'azurehealth'

@description('Azure subscription ID to monitor for Service Health events')
param subscriptionId string = subscription().subscriptionId

@description('Timer trigger CRON schedule')
param timerSchedule string = '0 */15 * * * *'

@description('Blob container name for caching Service Health payloads')
param cacheContainerName string = 'servicehealth-cache'

@description('Current date for tagging (automatically set)')
param currentDate string = utcNow('yyyy-MM-dd')

// Generate unique names
var uniqueSuffix = uniqueString(resourceGroup().id)
var storageAccountName = take('st${baseName}${environment}${uniqueSuffix}', 24)
var functionAppName = '${baseName}-func-${environment}-${uniqueSuffix}'
var appInsightsName = '${baseName}-ai-${environment}'
var appServicePlanName = '${baseName}-plan-${environment}'

// Tags for all resources
var commonTags = {
  environment: environment
  project: 'azure-health-monitoring'
  managedBy: 'bicep'
  createdDate: currentDate
}

// Storage Account for Function App
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob service and container for cache
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource cacheContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: cacheContainerName
  properties: {
    publicAccess: 'None'
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// App Service Plan (Consumption)
resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanName
  location: location
  tags: commonTags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: false // false for Windows, true for Linux
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: functionAppName
  location: location
  tags: commonTags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      powerShellVersion: '7.4'
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountname'
          value: storageAccount.name
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '7.4'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AZURE_SUBSCRIPTION_ID'
          value: subscriptionId
        }
        {
          name: 'CACHE_CONTAINER'
          value: cacheContainerName
        }
        {
          name: 'TIMER_CRON'
          value: timerSchedule
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

// Enable Easy Auth / Microsoft Entra ID authentication (required by Azure Policy)
resource functionAppAuthConfig 'Microsoft.Web/sites/config@2024-04-01' = {
  name: 'authsettingsV2'
  parent: functionApp
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    httpSettings: {
      requireHttps: true
    }
    platform: {
      enabled: true
      runtimeVersion: '~1'
    }
  }
}

// Role Assignments at subscription scope via module
module subscriptionRoleAssignments 'modules/roleAssignments.bicep' = {
  name: 'subscription-role-assignments'
  scope: subscription()
  params: {
    principalId: functionApp.identity.principalId
    subscriptionId: subscriptionId
  }
}

// Role Assignment: Storage Blob Data Contributor (for cache container)
resource blobContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  // Storage Blob Data Contributor role
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource blobContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, blobContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: blobContributorRoleDefinition.id
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
output functionAppPrincipalId string = functionApp.identity.principalId
output resourceGroupName string = resourceGroup().name
