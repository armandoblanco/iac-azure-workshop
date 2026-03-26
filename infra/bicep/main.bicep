targetScope = 'subscription'

@description('Base name prefix for all resources')
param prefix string = 'iacworkshop'

@description('Azure region for deployment')
param location string = 'eastus2'

@description('Container image tag')
param imageTag string = 'latest'

// ---------- Computed names ----------
var rgName = 'rg-${prefix}'
var acrName = replace('acr${prefix}${uniqueString(subscription().id)}', '-', '')
var planName = 'plan-${prefix}'
var appName = 'app-${prefix}-${uniqueString(subscription().id)}'

// ---------- Resource Group ----------
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
}

// ---------- Container Registry ----------
module acr 'modules/acr.bicep' = {
  scope: rg
  name: 'deploy-acr'
  params: {
    name: acrName
    location: location
  }
}

// ---------- App Service Plan ----------
module plan 'modules/appserviceplan.bicep' = {
  scope: rg
  name: 'deploy-plan'
  params: {
    name: planName
    location: location
  }
}

// ---------- App Service ----------
module app 'modules/appservice.bicep' = {
  scope: rg
  name: 'deploy-app'
  params: {
    name: appName
    location: location
    appServicePlanId: plan.outputs.planId
    containerImage: '${acr.outputs.acrLoginServer}/bankapi:${imageTag}'
    acrLoginServer: acr.outputs.acrLoginServer
    acrUsername: acrName
    acrPassword: listCredentials(resourceId(subscription().subscriptionId, rgName, 'Microsoft.ContainerRegistry/registries', acrName), '2023-07-01').passwords[0].value
  }
  dependsOn: [acr]
}

// ---------- Outputs ----------
output resourceGroupName string = rg.name
output acrLoginServer string = acr.outputs.acrLoginServer
output appServiceUrl string = app.outputs.appServiceUrl
output appServiceName string = app.outputs.appServiceName
