// File: main.bicep
targetScope = 'subscription'

// params
@description('''
The location of the resource.
Default: `deployment().location`
''')
param location string = deployment().location

@description('Short UTC date string used for tagging')
param utcShort string = utcNow('d')

@secure()
param secrets object = {}

@secure()
param sqlLocalAdminPass string = ''

// vars
@description('Import variables')
import * as common from 'vars/sub.bicep'

@description('Tags for resources including LastDeployed')
var tags = union(common.tags, { LastDeployed: utcShort })

// resources
@description('Resource group for environment resources')
resource rgEnv 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: common.groups.env
  location: location
  tags: tags
}

@description('Resource group for shared location resources')
resource rgLocSha 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: common.groups.locSha
  location: location
  tags: union(tags, { Environment: 'Shared' })
}

@description('Deploy shared location resources')
module groupLocSha 'groupLocSha.bicep' = {
  scope: rgLocSha
  name: 'groupLocSha'
  params: {
    location: rgLocSha.location
    utcShort: utcShort
  }
}

@description('Deploy environment resources')
module groupEnv 'groupEnv.bicep' = {
  scope: rgEnv
  name: 'groupEnv'
  dependsOn: [
    groupLocSha
  ]
  params: {
    location: rgEnv.location
    secrets: secrets
    sqlLocalAdminPass: sqlLocalAdminPass
    utcShort: utcShort
  }
}

@description('''
Resources that need defining post AKS infrastructure resource group deployment.

Note that this group is created by Azure.
''')
module groupEnvAks 'groupEnvAks.bicep' = {
  scope: resourceGroup(common.groups.envAks)
  name: 'groupEnvAks'
  dependsOn: [
    groupEnv
  ]
  params: {
    location: location
    utcShort: utcShort
  }
}

// outputs
output deploymentName string = deployment().name
output location string = location
output tags object = tags
