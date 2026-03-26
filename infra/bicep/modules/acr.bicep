@description('Name of the Azure Container Registry')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Standard'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: true
  }
}

output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output acrId string = acr.id
