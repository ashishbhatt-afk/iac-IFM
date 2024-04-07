// File: groupEnv.bicep
targetScope = 'resourceGroup'

// params
@description('''
The location of the resource.
Default: `resourceGroup().location`
''')
param location string = resourceGroup().location

@description('Short UTC date string used for tagging')
param utcShort string = utcNow('d')

@secure()
param secrets object = {}

@secure()
param sqlLocalAdminPass string = ''

// vars
@description('Import variables scoped to the resource group')
import * as common from 'vars/group.bicep'

@description('Tags for resources including LastDeployed')
var tags = union(common.tags, { LastDeployed: utcShort })

@description('Add common tags to each agent pool')
var agentPoolsUnion = [
  for pool in common.json.env.aks.agentPools: union(
    pool,
    {
      tags: tags
      vnetSubnetID: common.ids.snetAks
    }
  )
]

@description('Define domains that will require a DNS zone to be created.')
var dnsZonesArray = [
  'privatelink.redis.cache.windows.net'
  'privatelink.vaultcore.azure.net'
  'privatelink${environment().suffixes.sqlServerHostname}'
]

@description('Define the NSG rules for subnets that need them')
var nsgRules = {
  aks: []
  agw: [
    {
      name: 'allow-in-ranges-gwmgr-any'
      properties: {
        access: 'Allow'
        destinationAddressPrefix: '*'
        destinationPortRange: '65200-65535'
        direction: 'Inbound'
        priority: 200
        protocol: 'Tcp'
        sourceAddressPrefix: 'GatewayManager'
        sourcePortRange: '*'
      }
    }
    {
      name: 'allow-in-https-internet-any'
      properties: {
        access: 'Allow'
        destinationAddressPrefix: '*'
        destinationPortRange: '443'
        direction: 'Inbound'
        priority: 210
        protocol: 'Tcp'
        sourceAddressPrefix: 'Internet'
        sourcePortRange: '*'
      }
    }
  ]
}

@description('Loop through subnets and build an array of objects containing subnet details.')
var subnets = [
  for subnet in common.json.env.networking.vnet.subnets: {
    id: subnet.id
    name: '${common.names.snet}-${subnet.id}'
    prefix: subnet.prefix
    delegations: subnet.?delegations ?? []
    endpoints: subnet.?endpoints ?? []
    privateLinkServiceNetworkPolicies: subnet.?privateLinkServiceNetworkPolicies ?? 'Enabled'
    privateEndpointNetworkPolicies: subnet.?privateLinkServiceNetworkPolicies ?? 'Disabled'
  }
]

@description('''
Build an array containing resource IDs for subnets that have a Key Vault service endpoint.

Any that do not will result in `remove` being added to the array.
''')
var snetIdsStEndpoints = [
  for subnet in subnets: contains(string(subnet.endpoints), 'Microsoft.Storage')
    ? resourceId('Microsoft.Network/virtualNetworks/subnets', common.names.vnet, subnet.name)
    : 'remove'
]

@description('Use a Lambda function to filter out the `remove` values from the array.')
var snetIdsStEndpointsFiltered = filter(snetIdsStEndpoints, subnetIds => subnetIds != 'remove')

// resources
resource aks 'Microsoft.ContainerService/managedClusters@2024-01-02-preview' = {
  name: common.names.aksCluster
  dependsOn: [
    aksIdentity
    vnet
  ]
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${common.ids.idAks}': {}
    }
  }
  sku: {
    name: 'Base'
    tier: common.json.env.aks.tier
  }
  tags: tags
  properties: {
    addonProfiles: {
      ingressApplicationGateway: {
        config: {
          applicationGatewayId: common.json.run.createAgw ? agw.outputs.id : common.ids.idAgw
        }
        enabled: true
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'false'
          rotationPollInterval: '2m'
        }
      }
    }
    agentPoolProfiles: agentPoolsUnion
    azureMonitorProfile: {
      metrics: {
        enabled: true
      }
    }
    dnsPrefix: '${common.names.aksCluster}-dns'
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
    }
    nodeResourceGroup: '${resourceGroup().name}-aks'
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

resource redis 'Microsoft.Cache/redis@2023-08-01' = {
  name: common.names.redis
  location: location
  properties: {
    sku: {
      capacity: common.json.env.redis.skuCapacity
      family: common.json.env.redis.skuFamily
      name: common.json.env.redis.skuName
    }
  }
}

// modules
@description('Create agw identity')
module aksIdentity 'br/Operations:userassignedidentity:0.1.0' = {
  name: 'aksIdentity'
  params: {
    identityName_p: '${common.names.id}-aks'
    location_p: location
    resourceTags_p: tags
  }
}

@description('NAT Gateway (if required)')
module ng 'modules/natGateway.bicep' =
  if (common.json.env.networking.vnet.natGateway) {
    name: 'ng'
    params: {
      gatewayName: common.names.ng
      location: location
      publicIpName: '${common.names.pip}-ng'
      tags: tags
    }
  }

@description('Loop through each subnet and create an NSG for each one.')
module nsgs 'br/Operations:networksecuritygroup:0.1.0' = [
  for subnet in subnets: {
    name: 'nsg-${subnet.id}'
    params: {
      // diagsEventHubAuthRuleId_p: common.diags.rule
      // diagsEventHubName_p: common.diags.hub
      location_p: location
      nsgName_p: '${common.names.nsg}-${subnet.id}'
      resourceTags_p: tags
      securityRules_p: nsgRules[?subnet.id] ?? []
    }
  }
]

@description('''
Create the Virtual Network.
Build the subnets by looping through the common.json.env.networking.vnet.subnets object.
''')
module vnet 'br/Operations:virtualnetwork:0.1.0' = {
  name: 'vnet'
  params: {
    // diagsEventHubAuthRuleId_p: common.diags.rule
    // diagsEventHubName_p: common.diags.hub
    location_p: location
    vnetName_p: common.names.vnet
    resourceTags_p: tags
    subnets_p: [
      for (subnet, i) in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.prefix
          delegations: subnet.?delegations ?? []
          natGateway: common.json.env.networking.vnet.natGateway && !contains(subnet.id, 'pep')
            ? { id: ng.outputs.id }
            : null
          networkSecurityGroup: { id: nsgs[i].outputs.id }
          privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
          privateEndpointNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
          serviceEndpoints: subnet.endpoints
        }
      }
    ]
    vnetAddressPrefix_p: common.json.env.networking.vnet.prefix
  }
}

@description('Create a DNS zone for each domain and attach it to the AKS vnet')
module dnsZones 'br/Operations:privatednszone:0.1.0' = [
  for zone in dnsZonesArray: {
    name: 'dnsZones-${zone}'
    params: {
      location_p: 'global'
      resourceTags_p: tags
      vnetIds_p: [
        vnet.outputs.id
      ]
      zoneName_p: zone
    }
  }
]

module vnetRolesAks 'modules/virtualNetworkRoles.bicep' = {
  name: 'vnetRolesAks'
  params: {
    principalId: aksIdentity.outputs.principalId
    roleIds: [
      'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    ]
    vnetName: vnet.outputs.name
  }
}

module vnetRolesAgw 'modules/virtualNetworkRoles.bicep' = {
  name: 'vnetRolesAgw'
  params: {
    principalId: agwIdentity.outputs.principalId
    roleIds: [
      '4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor
    ]
    vnetName: vnet.outputs.name
  }
}

@description('Create agw identity')
module agwIdentity 'br/Operations:userassignedidentity:0.1.0' = {
  name: 'agwIdentity'
  params: {
    identityName_p: '${common.names.id}-agw'
    location_p: location
    resourceTags_p: tags
  }
}

module agw 'modules/appGatewayV2.bicep' =
  if (common.json.run.createAgw) {
    name: 'agw'
    params: {
      capacity: common.json.env.networking.agw.skuCapacity
      gatewayName: common.names.agw
      identity: 'UserAssigned'
      identityId: agwIdentity.outputs.id
      location: location
      maxCapacity: common.json.env.networking.agw.maxCapacity
      minCapacity: common.json.env.networking.agw.minCapacity
      publicIpName: '${common.names.pip}-agw'
      roles: [
        {
          principalId: aksIdentity.outputs.principalId
          roleIds: [
            'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
          ]
        }
      ]
      skuName: common.json.env.networking.agw.skuName
      subnetId: common.ids.snetAgw
      tags: tags
    }
  }

module kv 'modules/keyVault.bicep' = {
  name: 'kv'
  params: {
    kvName: common.names.kv
    location: location
    roles: [
      {
        principalId: agwIdentity.outputs.principalId
        roleIds: [
          '21090545-7ca7-4776-b22c-e363652d74d2' // Key Vault Reader
        ]
      }
    ]
    secrets: secrets
    tags: tags
  }
}

module pepKv 'br/Operations:privateendpoint:0.1.1' = {
  name: 'pepKv'
  dependsOn: [
    dnsZones
  ]
  params: {
    endpointName_p: '${common.names.pep}-kv'
    dnsZoneId_p: common.ids.dnsZoneVault
    groupIds_p: [
      'vault'
    ]
    location_p: location
    resourceTags_p: tags
    serviceId_p: kv.outputs.id
    subnetId_p: common.ids.snetPep
  }
}

@description('Create SQL Server')
module sqlServer 'br/Operations:sqlserver:0.1.0' =
  if (!empty(sqlLocalAdminPass)) {
    name: 'sqlServer'
    params: {
      adAdminGroupId_p: common.json.env.sql.aadAdminId
      adAdminGroupName_p: common.json.env.sql.aadAdminLogin
      auditDevOpsOperations_p: true
      localAdminPass_p: sqlLocalAdminPass
      location_p: location
      resourceTags_p: tags
      serverName_p: common.names.sql
    }
  }

module pepSql 'br/Operations:privateendpoint:0.1.1' = {
  name: 'pepSql'
  dependsOn: [
    dnsZones
  ]
  params: {
    endpointName_p: '${common.names.pep}-sql'
    dnsZoneId_p: common.ids.dnsZoneSql
    groupIds_p: [
      'sqlServer'
    ]
    location_p: location
    resourceTags_p: tags
    serviceId_p: sqlServer.outputs.id
    subnetId_p: common.ids.snetPep
  }
}

module elasticPools 'br/Operations:sqlelasticpool:0.1.0' = [
  for pool in common.json.env.sql.pools: {
    name: 'elasticPools-${pool.id}'
    dependsOn: [
      sqlServer
    ]
    params: {
      location_p: location
      maxCapacityPerDb_p: pool.dbMaxCapacity
      maxSizeGb_p: pool.maxSizeGb
      poolName_p: '${common.names.sqlep}-${pool.id}'
      resourceTags_p: tags
      skuCapacity_p: pool.skuCapacity
      skuEdition_p: pool.skuTier
      skuName_p: pool.skuName
      sqlServerName_p: common.names.sql
    }
  }
]

module pepRedis 'br/Operations:privateendpoint:0.1.1' = {
  name: 'pepRedis'
  dependsOn: [
    dnsZones
  ]
  params: {
    endpointName_p: '${common.names.pep}-redis'
    dnsZoneId_p: common.ids.dnsZoneRedis
    groupIds_p: [
      'redisCache'
    ]
    location_p: location
    resourceTags_p: tags
    serviceId_p: redis.id
    subnetId_p: common.ids.snetPep
  }
}

module sbns 'br/Operations:servicebusnamespace:0.1.0' = {
  name: 'sbns'
  params: {
    kvName_p: kv.outputs.name
    location_p: location
    namespaceName_p: common.names.sbns
    resourceTags_p: tags
  }
}

module st 'br/Operations:storageaccount:0.1.0' = {
  name: 'st'
  params: {
    accountName_p: common.names.st
    allowedSubnets_p: snetIdsStEndpointsFiltered
    bypass_p: 'AzureServices'
    // diagsEventHubAuthRuleId_p: common.diags.rule
    // diagsEventHubName_p: common.diags.hub
    kind_p: 'StorageV2'
    kvName_p: kv.outputs.name
    location_p: location
    publicNetworkAccess_p: 'Enabled'
    resourceTags_p: tags
    skuName_p: common.json.env.storageSku
  }
}

// outputs
output location string = location
output tags object = tags
