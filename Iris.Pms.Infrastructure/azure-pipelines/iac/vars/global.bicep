// File: global.bicep
// Must contain functions that are available in all target scopes 

targetScope = 'subscription'

@description('''
Location information.

https://learn.microsoft.com/en-us/azure/backup/scripts/geo-code-list
https://learn.microsoft.com/en-us/rest/api/resources/subscriptions/list-locations
''')
@export()
var locations = {
  eastus: {
    central: 'eastus'
    geography: 'US'
    geoCode: 'eus'
    displayName: 'East US'
    pairedRegion: 'westus'
  }
  westus: {
    central: 'eastus'
    displayName: 'West US'
    geoCode: 'wus'
    geography: 'US'
    pairedRegion: 'eastus'
  }
  uksouth: {
    central: 'uksouth'
    displayName: 'UK south'
    geoCode: 'uks'
    geography: 'UK'
    pairedRegion: 'ukwest'
  }
  ukwest: {
    central: 'uksouth'
    displayName: 'UK West'
    geoCode: 'uks'
    geography: 'UK'
    pairedRegion: 'uksouth'
  }
}

@description('JSON imports')
@export()
var json = {
  env: loadJsonContent('${loadJsonContent('run.jsonc').envShort}.jsonc')
  global: loadJsonContent('global.jsonc')
  run: loadJsonContent('run.jsonc')
}

@description('Resource tags')
@export()
var tags = {
  // Division: json.run.division
  Environment: json.run.envLong
  Product: json.run.productLong
  // LastUpdated: utcNow()
  // ProductID: json.run.productId
}
