// File: acrRoles.bicep
// Author: Bunny Davies
// 
// Creates Container Registry role assignments
// 
// module acrRoles_m 'acrRoles.bicep' = {
//   scope: group_r
//   name: 'acrRoles_m'
//   params: {
//     acrName_p: 'acr_m.outputs.name'
//     principalId_p: 'acr_m.outputs.principalId'
//     principalType_p: 'ServicePrincipal'
//     roles_p: [
//       'AcrPull'
//     ]
//   }
// }

// params - other
@description('Name of the existing Key Vault.')
param agwName string

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
resource agw 'Microsoft.Network/applicationGateways@2023-09-01' existing = {
  name: agwName
}

@description('Create the role assignments')
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roleIds: {
    scope: agw
    name: guid(agw.id, principalId, subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role))
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
