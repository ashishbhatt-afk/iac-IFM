// File: commonSub.bicep
targetScope = 'subscription'

@description('Import global variables')
@export()
import * as global from 'global.bicep'

@export()
var groups = {
  env: 'rg${infix.delimited}'
  envAks: 'rg${infix.delimited}-aks'
  locSha: 'rg-${global.json.run.productShort}-sha-${location.central}'
}

var infix = {
  concatenated: '${global.json.run.productShort}${global.json.run.envShort}${location.short}'
  delimited: '-${global.json.run.productShort}-${global.json.run.envShort}-${location.short}'
}

var location = {
  short: global.locations[deployment().location].geoCode
  central: global.locations[global.locations[deployment().location].central].geoCode
  geography: toLower(global.locations[deployment().location].geography)
}

@description('Programmatically generated strings')
@export()
var strings = {}

@export()
var tags = union(global.tags, {})
