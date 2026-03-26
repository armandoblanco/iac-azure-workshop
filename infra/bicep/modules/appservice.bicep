@description('Name of the App Service')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Resource ID of the App Service Plan')
param appServicePlanId string

@description('Full container image name (e.g., myacr.azurecr.io/bankapi:latest)')
param containerImage string

@description('ACR login server URL')
param acrLoginServer string

@description('ACR resource name (used to fetch credentials)')
param acrName string

var acrCreds = listCredentials(resourceId('Microsoft.ContainerRegistry/registries', acrName), '2023-07-01')

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerImage}'
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrLoginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acrCreds.username
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acrCreds.passwords[0].value
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
      ]
      alwaysOn: true
    }
    httpsOnly: true
  }
}

output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appServiceName string = appService.name
