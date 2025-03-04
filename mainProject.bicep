// Script to deploy the Project Specific Resources: Project, Project Role Assignments, Network Connection and DevBox Pools

targetScope = 'subscription'
param location string = deployment().location

@description('Subscription ID where Dev Center will be deployed')
param devCenterSubscriptionID string

param devCenterResourceGroupName string

@description('Dev Center Name')
param devCenterName string

@description('Default resource Group')
param projectResourceGroupName string

param projectName string
param projectDescription string

param projectPools array

param projectRoleAssignments array

param virtualNetworkName string
param virtualNetworkSubnetID string

// deploy resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: projectResourceGroupName
  location: location
}

// retrieve the Dev Center by the devCenterName
resource devCenter 'Microsoft.DevCenter/devcenters@2023-04-01' existing = {
  name: devCenterName
  scope: resourceGroup(devCenterSubscriptionID,devCenterResourceGroupName)
}


module devCenterProject 'modules/DevCenterProject.bicep' = {
  name: 'DevCenter${projectName}'
  scope: rg
  params: {
    location: location
    ProjectDescription: projectDescription
    ProjectName: projectName
    roleAssignments: projectRoleAssignments
    DevCenterID: devCenter.id
  }
}

var networkNamePrefix = '${split(virtualNetworkSubnetID, '/')[8]}-${last(split(virtualNetworkSubnetID, '/'))}'

module devCenterNetworkConnection 'modules/DevCenterNetworkConnection.bicep' = {
  name: '${networkNamePrefix}-NetworkConnection'
  scope: rg
  params: {
    location: location
    SubnetID: virtualNetworkSubnetID
    NetworkConnectionName: '${networkNamePrefix}-NetworkConnection'
    networkingResourceGroupName: '${rg.name}-nics'
  }
}

module devCenterNetworkAttach 'modules/DevCenterNetworkAttach.bicep' = {
  name: virtualNetworkName
  scope: resourceGroup(devCenterSubscriptionID, devCenterResourceGroupName)
  params: {
    devCenterName: devCenterName
    networkConnectionID: devCenterNetworkConnection.outputs.networkConnectionID
    networkAttachName: virtualNetworkName
  }
}


// deploy DevCenter Porject Pools
module devCenterPools 'modules/DevCenterProjectPools.bicep' = [for (pool, i) in projectPools: {
  name: '${devCenterProject.name}pool${i}'
  scope: rg
  dependsOn: [
    devCenterNetworkConnection
  ]
  params: {
    location: location
    DevCenterProjectName: devCenterProject.outputs.Name
    devBoxDefinitionName: pool.definitionName
    networkConnectionName: pool.networkConnectionName
    // gracePeriodMinutes: pool.gracePeriodMinutes
    localAdministrator: pool.localAdministrator
    // stopOnDisconnect: pool.stopOnDisconnect
    deploySchedule: !empty(pool.schedule)
    scheduleTime: !empty(pool.schedule) ? pool.schedule.time : ''
    scheduleTimeZone: !empty(pool.schedule) ? pool.schedule.timeZone : ''
  }
}]
