// File: groupEnvAks.bicep
targetScope = 'resourceGroup'

// params
@description('''
The location of the resource.
Default: `resourceGroup().location`
''')
param location string = resourceGroup().location

@description('Short UTC date string used for tagging')
param utcShort string = utcNow('d')

// vars
@description('Import variables scoped to the resource group')
import * as common from 'vars/group.bicep'

@description('Tags for resources including LastDeployed')
var tags = union(common.tags, { LastDeployed: utcShort })

// resources
resource aks 'Microsoft.ContainerService/managedClusters@2024-01-02-preview' existing = {
  scope: resourceGroup(common.groups.env)
  name: common.names.aksCluster
}

resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' existing = {
  scope: resourceGroup(common.groups.locSha)
  name: common.names.dnsZone
}

resource idAksAgentpool 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: '${aks.name}-agentpool'
}

resource idAksKv 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: 'azurekeyvaultsecretsprovider-${common.names.aksCluster}'
}

resource idCredAksAgentpool 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-07-31-preview' = {
  parent: idAksAgentpool
  name: 'cert-manager'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: aks.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:cert-manager:cert-manager'
  }
}

module dnsZoneRoles 'modules/dnsZoneRoles.bicep' = {
  scope: resourceGroup(common.groups.locSha)
  name: 'dnsZoneRoles'
  params: {
    dnsZoneName: dnsZone.name
    principalId: idAksAgentpool.properties.principalId
    roleIds: [
      'befefa01-2a29-4197-83a8-272ff33ce314' // DNS Zone Contributor
    ]
  }
}

module kvRolesAks 'modules/keyVaultRoles.bicep' = {
  scope: resourceGroup(common.groups.env)
  name: 'kvRolesAks'
  params: {
    kvName: common.names.kv
    principalId: idAksKv.properties.principalId
    roleIds: [
      '00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator
    ]
  }
}

// outputs
output location string = location
output tags object = tags
