targetScope = 'subscription'

@description('Function App principal ID')
param principalId string

@description('Subscription ID for role assignments')
param subscriptionId string = subscription().subscriptionId

// Role Assignment: Reader (for Service Health queries)
resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  // Reader role
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: subscription()
  name: guid(subscriptionId, principalId, readerRoleDefinition.id, 'reader')
  properties: {
    roleDefinitionId: readerRoleDefinition.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment: Monitoring Reader
resource monitoringReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  // Monitoring Reader role
  name: '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
}

resource monitoringReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: subscription()
  name: guid(subscriptionId, principalId, monitoringReaderRoleDefinition.id, 'monitoring')
  properties: {
    roleDefinitionId: monitoringReaderRoleDefinition.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output readerRoleAssignmentId string = readerRoleAssignment.id
output monitoringReaderRoleAssignmentId string = monitoringReaderRoleAssignment.id
