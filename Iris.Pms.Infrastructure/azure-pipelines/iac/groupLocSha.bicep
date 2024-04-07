// File: groupLoc.bicep
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
resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: common.names.dnsZone
  location: 'global'
  tags: tags
  properties: {
    zoneType: 'Public'
  }
}

// modules

// outputs
output location string = location
output tags object = tags
