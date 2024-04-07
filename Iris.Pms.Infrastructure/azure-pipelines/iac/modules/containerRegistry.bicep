// File: containerRegistry.bicep

// params - standard
@description('''
The location of the resource.
Default: `resourceGroup().location`
''')
param location string = resourceGroup().location

@description('The tags of the resource.')
param tags object = {}

// params - diags
@description('Event Hub authorisation rule ID.')
param diagsEventHubAuthRuleId string = ''

@description('Event Hub name.')
param diagsEventHubName string = ''

@description('''
The number of days for the retention in days. A value of 0 will retain the events indefinitely.
Default: `0`
''')
param diagsRetentionDays int = 0

@description('''
Avalue indicating whether the retention policy is enabled.
Default: `false`
''')
param diagsRetentionEnabled bool = false

@description('Storage Account ID.')
param diagsStorageAccountId string = ''

@description('Log Analytics Workspace ID.')
param diagsWorkspaceId string = ''

// params - other
@description('''
The value that indicates whether the admin user is enabled.
Default: `false`
''')
param adminEnabled bool = false

@description('''
Name of the Container Registry.
Default: `acr${uniqueString(resourceGroup().id)}`
''')
param crName string = 'cr${uniqueString(resourceGroup().id)}'

@description('''
Array of role definition IDs to be assigned to the principal ID.
https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles

Example:
```
[
  {
    principalId: identity.outputs.principalId
    principalType: 'Device|ForeignGroup|Group|ServicePrincipal|User'
    roleIds: [
      '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
    ]
  }
]
```

Default: `[]`

''')
param roles array = []

@allowed([
  'Basic'
  'Classic'
  'Premium'
  'Standard'
])
@description('''
The SKU name of the container registry.
Default: `Basic`
''')
param skuName string = 'Basic'

// resources
resource cr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: crName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: adminEnabled
    zoneRedundancy: (skuName == 'Premium' ? 'Enabled' : 'Disabled')
  }

  // resource replica_r 'replications' = if (!empty(replicaLocation) && skuName == 'Premium') {
  //   name: replicaLocation
  //   location: replicaLocation
  //   properties: {
  //     zoneRedundancy: 'Enabled'
  //   }
  // }
}

resource crDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' =
  if (!empty(diagsEventHubAuthRuleId) || !empty(diagsStorageAccountId) || !empty(diagsWorkspaceId)) {
    scope: cr
    name: 'default'
    properties: {
      eventHubAuthorizationRuleId: !empty(diagsEventHubAuthRuleId) ? diagsEventHubAuthRuleId : null
      eventHubName: !empty(diagsEventHubName) ? diagsEventHubName : null
      workspaceId: !empty(diagsWorkspaceId) ? diagsWorkspaceId : null
      storageAccountId: !empty(diagsStorageAccountId) ? diagsStorageAccountId : null
      logs: [
        {
          categoryGroup: 'audit'
          enabled: true
          retentionPolicy: {
            days: diagsRetentionDays
            enabled: diagsRetentionEnabled
          }
        }
        {
          categoryGroup: 'allLogs'
          enabled: true
          retentionPolicy: {
            days: diagsRetentionDays
            enabled: diagsRetentionEnabled
          }
        }
      ]
      metrics: [
        {
          category: 'AllMetrics'
          enabled: true
          retentionPolicy: {
            days: diagsRetentionDays
            enabled: diagsRetentionEnabled
          }
        }
      ]
    }
  }

module crRoles 'keyVaultRoles.bicep' = [
  for (role, i) in roles: if (!empty(roles)) {
    name: 'kvRolesAgw-${i}'
    params: {
      kvName: cr.name
      principalId: role.principalId
      principalType: role.?principalType ?? null
      roleIds: role.roleIds
    }
  }
]

// outputs - standard
@description('Resource API version')
output api string = cr.apiVersion

@description('Resource ID')
output id string = cr.id

@description('Resource name')
output name string = cr.name

@description('Resource type')
output type string = cr.type

// outputs - other
@description('Container Registry URL')
output url string = cr.properties.loginServer
