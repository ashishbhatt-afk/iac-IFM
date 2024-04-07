// File: keyVault.bicep
// Author: Bunny Davies
// 
// module kv_m 'keyVault.bicep' = {
//   name: 'kv_m'
//   params: {
//     adminId_p: vaultAdminId_p
//     enabledForTemplateDeployment_p: true
//     diagsEventHubAuthRuleId_p: eventHubAuthId_p
//     kvName_p: kvName_v
//     location_p: location_p
//     resourceTags_p: resourceTags_p
//   }
// }

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
param diagsWorkspaceId_p string = ''

// params - other
// param accessPolicies array = []

@secure()
param adminId string = ''

@description('''
The list of IP address rules.

Example:
```
[
  1.1.1.1
  2.2.2.2
]
```
''')
param allowedIpAddresses array = []

@description('''
The list allowed subnets IDs.

Example:
```
[
  id1
  id2
]
```
''')
param allowedSubnets array = []

@allowed([
  'AzureServices'
  'None'
])
@description('''
Tells what traffic can bypass network rules.

Default: `enabledForDeployment_p || enabledForTemplateDeployment_p ? 'AzureServices' : 'None'`
''')
param bypass_p string = enabledForDeployment || enabledForTemplateDeployment ? 'AzureServices' : 'None'

@allowed([
  'Allow'
  'Deny'
])
@description('''
The default action when no rule from ipRules and from virtualNetworkRules match. This is only used after the bypass property has been evaluated.

Default: `Deny`
''')
param defaultAction string = 'Deny'

@description('''
Property to specify whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.

Default: `false`
''')
param enabledForDeployment bool = false

@description('''
Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.
Default: `false`
''')
param enabledForTemplateDeployment bool = false

// @description('''
// Property specifying whether protection against purge is enabled for this vault. Setting this property to true activates protection against purge for this vault and its content - only the Key Vault service may initiate a hard, irrecoverable deletion.

// The setting is effective only if soft delete is also enabled. Enabling this functionality is irreversible - that is, the property does not accept false as its value.
// ''')
// param enablePurgeProtection_p bool = enabledForDeployment_p  //TODO: refactor purge protection as false value is not accepted

@description('''
Property that controls how data actions are authorized. When true, the key vault will use Role Based Access Control (RBAC) for authorization of data actions, and the access policies specified in vault properties will be ignored.
When false, the key vault will use the access policies specified in vault properties, and any policy stored on Azure Resource Manager will be ignored.
If null or not specified, the vault is created with the default value of false. Note that management actions are always authorized with RBAC.
Default: `empty(adminId_p) ? true : false`
''')
param enableRbacAuthorization bool = empty(adminId) ? true : false

@description('''
Property to specify whether the 'soft delete' functionality is enabled for this key vault.
Once set to true, it cannot be reverted to false.
Default: `softDeleteRetentionInDays_p > 0 ? true : false`
''')
param enableSoftDelete bool = softDeleteRetentionInDays > 0 ? true : false

@description('''
The resource name.
Default: `kv-${uniqueString(resourceGroup().id)}`
''')
param kvName string = 'kv-${uniqueString(resourceGroup().id)}'

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
      '21090545-7ca7-4776-b22c-e363652d74d2' // Key Vault Reader
    ]
  }
]
```

Default: `[]`

''')
param roles array = []

@description('''
Optional object containing key:value list of secrets.
Secret names with special characters must be wrapped in single quotes.
```
{
  'pass-localadmin': localAdminPass_p
  apikey: apiKey_p
}
''')
@secure()
param secrets object = {}

@allowed([
  'premium'
  'standard'
])
@description('''
SKU name to specify whether the key vault is a standard vault or a premium vault.
Default: `standard`
''')
param skuName string = 'standard'

@minValue(7)
@maxValue(90)
@description('''
SoftDelete data retention days.
Default: `7`
''')
param softDeleteRetentionInDays int = 7

// vars
var allowedIpsArray_v = [
  for ip in allowedIpAddresses: {
    value: ip
  }
]

var allowedSubnetsArray_v = [
  for subnet in allowedSubnets: {
    id: subnet
  }
]

// resources
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    // accessPolicies: accessPolicies
    enabledForDeployment: enabledForDeployment
    enabledForTemplateDeployment: enabledForTemplateDeployment
    // enablePurgeProtection: enablePurgeProtection_p   //TODO: refactor purge protection as false value is not accepted
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: enableSoftDelete
    networkAcls: {
      bypass: bypass_p
      defaultAction: defaultAction
      ipRules: allowedIpsArray_v
      virtualNetworkRules: allowedSubnetsArray_v
    }
    sku: {
      family: 'A'
      name: skuName
    }
    softDeleteRetentionInDays: softDeleteRetentionInDays
    tenantId: subscription().tenantId
  }

  // resource accessPolicies 'accessPolicies' =
  //   if (!empty(adminId)) {
  //     name: 'add'
  //     properties: {
  //       accessPolicies: [
  //         {
  //           tenantId: subscription().tenantId
  //           permissions: {
  //             certificates: [
  //               'all'
  //             ]
  //             keys: [
  //               'all'
  //             ]
  //             secrets: [
  //               'all'
  //             ]
  //           }
  //           objectId: adminId
  //         }
  //       ]
  //     }
  //   }
}

module kvRoles 'keyVaultRoles.bicep' = [
  for (role, i) in roles: if (!empty(roles)) {
    name: 'kvRolesAgw-${i}'
    params: {
      kvName: kv.name
      principalId: role.principalId
      principalType: role.?principalType ?? null
      roleIds: role.roleIds
    }
  }
]

resource kvDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' =
  if (!empty(diagsEventHubAuthRuleId) || !empty(diagsStorageAccountId) || !empty(diagsWorkspaceId_p)) {
    scope: kv
    name: 'default'
    properties: {
      eventHubAuthorizationRuleId: !empty(diagsEventHubAuthRuleId) ? diagsEventHubAuthRuleId : null
      eventHubName: !empty(diagsEventHubName) ? diagsEventHubName : null
      storageAccountId: !empty(diagsStorageAccountId) ? diagsStorageAccountId : null
      workspaceId: !empty(diagsWorkspaceId_p) ? diagsWorkspaceId_p : null
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

@description('Loop through each secret and create a new secret')
resource secrets_r 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = [
  for secret in items(secrets): {
    parent: kv
    name: secret.key
    properties: {
      value: secret.value
    }
  }
]

// outputs - standard
@description('Resource API version')
output api string = kv.apiVersion

@description('Resource ID')
output id string = kv.id

@description('Resource name')
output name string = kv.name

@description('Resource type')
output type string = kv.type

// outputs - other
