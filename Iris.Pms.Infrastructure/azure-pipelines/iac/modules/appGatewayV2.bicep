// File: appGatewayV2.bicep
// Author: Bunny Davies
// 
// Deploys an Application Gateway v2 with a public IP address and defaults for: ip configuration, listener, pool, rules, and settings.<br>
// This is designed to be used to deploy an Application Gateway with a base configuration and then to be updated in application specific deployments.<br>
// If a public IP resource ID is not defined then a public IP will be created.<br>
// As the Application Gateway configuration is overwritten when deployed, a conditional deployment recommended.
// 
// module agw_m 'appGatewayV2copy.bicep' = if (createAgw_p == 'True') {
//   name: agw.name
//   params: {
//     location_p: location_p
//     name_p: agw.name
//     pipId_p: agwPip_m.outputs.id
//     resourceTags_p: resourceTags_p
//     skuName_p: subscriptionVars_v[subscription().displayName].agwSku
//     subnetId_p: subnets_m[1].outputs.id // does match the agw subnet array
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
param diagsWorkspaceId string = ''

// params - other
@description('''
Name of the Application Gateway.
Default: `agw-${uniqueString(resourceGroup().id)}`
''')
param gatewayName string = 'agw-${uniqueString(resourceGroup().id)}'

@description('''
Array of objects containing backend pools and their targets.
```
[
  {
    name: 'pool_api'
    properties: {
      backendAddresses: [
        {
          fqdn: 'app-ops-app-api-poc.azurewebsites.net'
        }
        {
          ipAddress: '10.0.0.5'
        }
      ]
    }
  }
]
```
Default: `[]`
''')
param backendPools array = []

@description('''
Array of objects containing backend settings.

Default:
```
[
  {
    name: 'settings_default'
    properties: {
      port: 80
      protocol: 'Http'
      cookieBasedAffinity: 'Disabled'
      requestTimeout: 20
    }
  }
]
```
''')
param backendSettings array = [
  {
    name: 'settings_default'
    properties: {
      port: 80
      protocol: 'Http'
      cookieBasedAffinity: 'Disabled'
      requestTimeout: 20
    }
  }
]

@minValue(1)
@maxValue(32)
@description('''
Capacity (instance count) of an application gateway.
If minCapacity_p is greater then `0` then capacity will be disabled and this value will be ignored.
Default: `1`
''')
param capacity int = 1

@allowed([
  'AppGwSslPolicy20150501'
  'AppGwSslPolicy20170401'
  'AppGwSslPolicy20170401S'
  'AppGwSslPolicy20220101'
  'AppGwSslPolicy20220101S'
  'Undefined'
])
@description('''
Default predefined SSL policy for all listeners.

If set to `Undefined` then the default policy will be used.

Default: `AppGwSslPolicy20220101`
''')
param defaultSslPolicy string = 'AppGwSslPolicy20220101'

@description('''
Whether HTTP2 is enabled on the application gateway resource.
Default: `false`
''')
param enableHttp2 bool = false

@description('''
Array of objects containing frontend ports.

Note that `port_80` will always be created.

Default:
```
[
  {
    name: 'port_443'
    properties: {
      port: 443
    }
  }
]
```
''')
param frontendPorts array = [
  {
    name: 'port_443'
    properties: {
      port: 443
    }
  }
]

@allowed([
  'None'
  'UserAssigned'
])
@description('''
The identity of the application gateway.
An identity is required if a Key Vault will be used to store certificates.
Default: `None`
''')
param identity string = 'None'

@description('''
Resource of the User Assigned Identity.
Required if `identity_p` is set to `UserAssigned`.
''')
param identityId string = ''

@description('''
Lower bound on number of Application Gateway autoscale configuration capacity.
A minimum instance count of 2 is recommended for production workloads.
If set to `0` then autoscale will be disabled.
Default: `0`
''')
param minCapacity int = 0

@minValue(2)
@maxValue(125)
@description('''
Upper bound on number of Application Gateway autoscale configuration capacity.
Must greater than both `2` and `minCapacity_p`.
Default: `2`
''')
param maxCapacity int = 2

@description('''
Name of the new public IP address.

Default: `pip${uniqueString(gatewayName)}`
''')
param publicIpName string = 'pip${uniqueString(gatewayName)}'

@description('''
Resource ID of the existing public IP address.

If one is not provided, a new public IP address will be created.
''')
param publicIpAddressesId string = ''

@allowed([
  'Dynamic'
  'Static'
])
@description('''
The private IP address allocation method.
Default: `Dynamic`
''')
param privateIPAllocationMethod string = 'Dynamic'

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
      'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    ]
  }
]
```

Default: `[]`

''')
param roles array = []

@allowed([
  'Standard_v2'
  'WAF_v2'
])
@description('''
Name of an application gateway SKU.

Default: `Standard_v2`
''')
param skuName string = 'Standard_v2'

@description('Resource ID of the subnet from where the gateway gets its private address')
param subnetId string

@description('''
Whether the web application firewall is enabled or not.

Default: `contains(skuName_p, 'WAF') ? true : false`
''')
param wafEnabled bool = contains(skuName, 'WAF') ? true : false

@allowed([
  'Detection'
  'Prevention'
])
@description('''
The mode of the web application firewall.

Default: `Detection`
''')
param wafMode string = 'Detection'

@allowed([
  '2.29'
  '3.0'
  '3.1'
  '3.2'
])
@description('''
The version of the web application firewall rule set.
Default: `3.2`
''')
param wafRuleSetVersion string = '3.2'

// vars
@description('Define values for possible identity configurations in a format that can be used in a resource.')
var identityObject = {
  None: {
    type: identity
  }
  UserAssigned: {
    type: identity
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
}

@description('''
Define the default SSL policy object in a format that can be used in a resource.
If sslPolicy_p is set to 'None' then the object will be empty.
''')
var sslPolicyObject = defaultSslPolicy != 'Undefined'
  ? {
      policyType: 'Predefined'
      policyName: defaultSslPolicy
    }
  : {}

// resources
@description('Public IP adddress (if required)')
module pip 'br/Operations:publicip:0.1.0' =
  if (empty(publicIpAddressesId)) {
    name: 'pip'
    params: {
      diagsEventHubAuthRuleId_p: diagsEventHubAuthRuleId
      diagsEventHubName_p: diagsEventHubName
      diagsRetentionDays_p: diagsRetentionDays
      diagsRetentionEnabled_p: diagsRetentionEnabled
      diagsStorageAccountId_p: diagsStorageAccountId
      diagsWorkspaceId_p: diagsWorkspaceId
      location_p: location
      pipName_p: publicIpName
      resourceTags_p: tags
    }
  }

@description('Create the Application Gateway.')
resource agw 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: gatewayName
  location: location
  tags: tags
  identity: identityObject[identity]
  properties: {
    autoscaleConfiguration: minCapacity > 0
      ? {
          minCapacity: minCapacity
          maxCapacity: maxCapacity
        }
      : null
    backendAddressPools: union(
      backendPools,
      [
        {
          name: 'pool_default'
          properties: {}
        }
      ]
    )
    backendHttpSettingsCollection: backendSettings
    enableHttp2: enableHttp2
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIpIPv4'
        properties: {
          privateIPAllocationMethod: privateIPAllocationMethod
          publicIPAddress: {
            id: empty(publicIpAddressesId) ? pip.outputs.id : publicIpAddressesId
          }
        }
      }
    ]
    frontendPorts: union(
      frontendPorts,
      [
        {
          name: 'port_80'
          properties: {
            port: 80
          }
        }
      ]
    )
    httpListeners: [
      {
        name: 'listener_default'
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/frontendIPConfigurations',
              gatewayName,
              'appGwPublicFrontendIpIPv4'
            )
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', gatewayName, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rule_default'
        properties: {
          priority: 1000
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', gatewayName, 'listener_default')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', gatewayName, 'pool_default')
          }
          backendHttpSettings: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
              gatewayName,
              'settings_default'
            )
          }
        }
      }
    ]
    sku: {
      name: skuName
      tier: skuName
      capacity: minCapacity == 0 || maxCapacity == 0 ? capacity : null
    }
    sslPolicy: sslPolicyObject
    webApplicationFirewallConfiguration: contains(skuName, 'WAF')
      ? {
          enabled: wafEnabled
          firewallMode: wafMode
          ruleSetType: 'OWASP'
          ruleSetVersion: wafRuleSetVersion
        }
      : null
  }
}

@description('Configure diagnosting settings.')
resource agwDiags 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' =
  if (!empty(diagsEventHubAuthRuleId) || !empty(diagsStorageAccountId) || !empty(diagsWorkspaceId)) {
    scope: agw
    name: 'default'
    properties: {
      eventHubAuthorizationRuleId: !empty(diagsEventHubAuthRuleId) ? diagsEventHubAuthRuleId : null
      eventHubName: !empty(diagsEventHubName) ? diagsEventHubName : null
      storageAccountId: !empty(diagsStorageAccountId) ? diagsStorageAccountId : null
      workspaceId: !empty(diagsWorkspaceId) ? diagsWorkspaceId : null
      logs: [
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

module agwRoles 'appGatewayRoles.bicep' = [
  for (role, i) in roles: if (!empty(roles)) {
    name: 'kvRolesAgw-${i}'
    params: {
      agwName: agw.name
      principalId: role.principalId
      principalType: role.?principalType ?? null
      roleIds: role.roleIds
    }
  }
]

// outputs - standard
@description('Resource API version')
output api string = agw.apiVersion

@description('Resource ID')
output id string = agw.id

@description('Resource name')
output name string = agw.name

@description('Resource type')
output type string = agw.type

// outputs - other
output pipId string = agw.properties.frontendIPConfigurations[0].properties.publicIPAddress.id
