// File: keyVaultRoles.bicep
// Author: Bunny Davies

// params - other
@description('Name of the existing Key Vault.')
param kvName string

@description('The principal ID to be assigned roles on the target resource.')
param principalId string

@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
@description('The principal type of the assigned principal ID.')
param principalType string = 'ServicePrincipal'

@description('''
Array of role definition IDs to be assigned to the principal ID.
https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
''')
param roleIds array

// resources
@description('Retrieve the existing resource')
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: kvName
}

@description('Create the role assignments')
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roleIds: {
    scope: kv
    name: guid(kv.id, principalId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role))
    properties: {
      principalId: principalId
      principalType: principalType
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    }
  }
]

// outputs - standard
@description('Resource API version')
output api string = roleAssignments[0].apiVersion

@description('Resource ID')
output id string = roleAssignments[0].id

@description('Resource type')
output type string = roleAssignments[0].type

// outputs - other
