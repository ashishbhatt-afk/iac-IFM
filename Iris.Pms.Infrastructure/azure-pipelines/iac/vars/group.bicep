targetScope = 'resourceGroup'

// params

// vars
@description('Import global variables')
import * as global from 'global.bicep'

@export()
var groups = {
  env: 'rg${infix.delimited}'
  envAks: 'rg${infix.delimited}-aks'
  locSha: 'rg-${global.json.run.productShort}-sha-${location.central}'
}

@description('Resource IDs')
@export()
var ids = {
  dnsZoneRedis: resourceId(groups.env, 'Microsoft.Network/privateDnsZones', 'privatelink.redis.cache.windows.net')
  dnsZoneSql: resourceId(
    groups.env,
    'Microsoft.Network/privateDnsZones',
    'privatelink${environment().suffixes.sqlServerHostname}'
  )
  dnsZoneVault: resourceId('Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
  idAgw: resourceId(groups.env, 'Microsoft.Network/applicationGateways', names.agw)
  idAks: resourceId(groups.env, 'Microsoft.ManagedIdentity/userAssignedIdentities', '${names.id}-aks')
  snetAgw: resourceId(groups.env, 'Microsoft.Network/virtualNetworks/subnets', names.vnet, '${names.snet}-agw')
  snetAks: resourceId(groups.env, 'Microsoft.Network/virtualNetworks/subnets', names.vnet, '${names.snet}-aks')
  snetPep: resourceId(groups.env, 'Microsoft.Network/virtualNetworks/subnets', names.vnet, '${names.snet}-pep')
}

var infix = {
  concatenated: '${global.json.run.productShort}${global.json.run.envShort}${location.short}'
  delimited: '-${global.json.run.productShort}-${global.json.run.envShort}-${location.short}'
}

@description('JSON imports')
@export()
var json = union(global.json, {})

@description('Programmatically generated resource names')
@export()
var names = {
  // appi: 'appi${infix.delimited}'
  // asp: 'asp${infix.delimited}'
  // evh: 'evh${infix.delimited}'
  // evhns: 'evh${infix.delimited}'
  // func: 'func${infix.delimited}'
  // group: 'rg${infix.delimited}'

  // log: 'log${infix.delimited}'
  // lt: 'lt${infix.delimited}'
  // script: 'script${infix.delimited}'
  // sigr: 'sigr${infix.delimited}'
  // sqldb: 'sqldb${infix.delimited}'
  agw: 'agw${infix.delimited}'
  aksCluster: 'aks${infix.delimited}'
  aksSystemNode: 'npsystem${infix.delimited}'
  aksUserNode: 'np${infix.delimited}'
  cr: 'cr${infix.concatenated}'
  dnsZone: global.json.run.envShort == 'prod'
    ? '${location.geography}.${global.json.env.networking.domain}'
    : '${global.json.run.envShort}${location.geography}.${global.json.env.networking.domain}'
  id: 'id${infix.delimited}'
  kv: 'kv${infix.delimited}'
  ng: 'ng${infix.delimited}'
  nsg: 'nsg${infix.delimited}'
  pep: 'pep${infix.delimited}'
  pip: 'pip${infix.delimited}'
  redis: 'redis${infix.delimited}'
  sbns: 'sbns${infix.delimited}'
  snet: 'snet${infix.delimited}'
  sql: 'sql${infix.delimited}'
  sqlep: 'sqlep${infix.delimited}'
  st: 'st${infix.concatenated}'
  vnet: 'vnet${infix.delimited}'
}

var location = {
  short: global.locations[resourceGroup().location].geoCode
  central: global.locations[global.locations[resourceGroup().location].central].geoCode
  geography: toLower(global.locations[resourceGroup().location].geography)
}

@description('Programmatically generated strings')
@export()
var strings = {
  envShort: split(resourceGroup().name, '-')[2] == 'core'
    ? split(subscription().subscriptionId, '-')[1]
    : json.run.envShort
  group: split(resourceGroup().name, '-')[2]
}

@description('Resource tags')
@export()
var tags = union(global.tags, {})

// @description('Diagnostics variables using Event Hub')
// @export()
// var diags = {
//   datadogSite: 'datadoghq.eu'
//   enabled: json.run.diags || json.env.diags ? true : false
//   evh: '${names.evh}-dd'
//   evhns: '${names.evhns}-dd'
//   hub: json.run.diags || json.env.diags ? '${names.evh}-dd' : null
//   kv: '${names.kv}-dd'
//   rule: json.run.diags || json.env.diags
//     ? resourceId(groups.core, 'Microsoft.EventHub/namespaces/AuthorizationRules', '${names.evhns}-dd', 'diags')
//     : null
//   script: '${names.script}-dd'
// }

// @description('Resource group names')
// @export()
// var groups = union(commonSub.groups, {})

// @description('Resource IDs')
// @export()
// var ids = {
//   appi: resourceId(groups.app, 'Microsoft.Insights/components', names.appi)
//   idKv: resourceId(groups.app, 'Microsoft.ManagedIdentity/userAssignedIdentities', names.idKv)
//   idSql: resourceId(groups.app, 'Microsoft.ManagedIdentity/userAssignedIdentities', names.idSql)
//   idSqlRo: resourceId(groups.app, 'Microsoft.ManagedIdentity/userAssignedIdentities', names.idSqlRo)
//   idSqlRw: resourceId(groups.app, 'Microsoft.ManagedIdentity/userAssignedIdentities', names.idSqlRw)
// }
