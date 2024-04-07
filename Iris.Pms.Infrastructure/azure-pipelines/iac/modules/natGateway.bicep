// File: natGateway.bicep
// Author: Bunny Davies

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
The idle timeout in minutes of the NAT gateway.

Default: `4`
''')
param idleTimeout int = 4

@description('''
Name of the NAT gateway.

Default: `ng${uniqueString(resourceGroup().id)}`
''')
param gatewayName string = 'ng${uniqueString(resourceGroup().id)}'

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

@description('Create the NAT Gateway.')
resource ng 'Microsoft.Network/natGateways@2023-09-01' = {
  name: gatewayName
  properties: {
    idleTimeoutInMinutes: idleTimeout
    publicIpAddresses: [
      {
        id: empty(publicIpAddressesId) ? pip.outputs.id : publicIpAddressesId
      }
    ]
  }
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
}

// outputs - standard
@description('Resource API version')
output api string = ng.apiVersion

@description('Resource ID')
output id string = ng.id

@description('Resource name')
output name string = ng.name

@description('Resource type')
output type string = ng.type

// outputs - other
output pipId string = ng.properties.publicIpAddresses[0].id
