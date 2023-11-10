// Create the DevCenter and other resources related to the DevCenter directly (not project specific): Image Gallery and DevBox Definitions

targetScope = 'subscription'
param location string = deployment().location

@description('Dev Center Name')
param DevCenterName string

@description('Default resource Group')
param resourceGroupName string

@description('Array of Image Definitions to be used in Dev Center')
param definitions array

// Dev Center Object
var DevCenter = {
  name: DevCenterName
  resourceGroupName: resourceGroupName
  definitions: definitions
}


resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: DevCenter.resourceGroupName
  location: location
}

// deploy DevCenter
module devCenter 'modules/DevCenter.bicep' = {
  name: 'DevCenter'
  scope: rg
  params: {
    location: location
    devCenterName: DevCenter.name
  }
}

// deploy DevCenter builtin images
module devCenterBuiltinImages 'modules/DevCenterImage.bicep' = [for (definition, i) in DevCenter.definitions: {
  name: 'DeCenterImage${i}'
  scope: rg
  params: {
    location: location
    DevCenterDefinitionName: definition.name
    DevCenterGalleryImageName: definition.image
    DevCenterGalleryName: 'Default'
    DevCenterName: devCenter.outputs.Name
    imageSKU: definition.vmSKU
    imageStorageType: definition.diskSize
  }
}]
