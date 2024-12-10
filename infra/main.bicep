@description('Main Bicep file for the infra module')

param keyVaultName string
@description('Role assignments for the Key Vault')
param keyVaultRoleAssignments array
@description('Deployment location for the resource group')
param location string = resourceGroup().location
@description('Name of the App Service API application')
param appServiceAPIAppName string
param environmentType string = 'nonprod'


// service plan 
module serviceplan './serviceplan.bicep' = {
  name: 'serviceplan'
  params: {
    location: location
    appServicePlanName: 'appServicePlan'
    skuName: 'B1'
  }
}

module keyVault 'keyvault.bicep' = {
  name: 'keyVault'
  params: {
    keyVaultName: keyVaultName
    location: location
    roleAssignments: keyVaultRoleAssignments
  }
}

module registry 'registry.bicep' = {
  name: 'registry'
  params: {
    registryName: 'drosel-myregistry'
    location: location
    sku: 'Basic'
    keyVaultResourceId: keyVault.outputs.resourceId
    keyVaultSecretNameAdminUsername: 'admin-username'
    keyVaultSecretNameAdminPassword0: 'admin-password-0'
    keyVaultSecretNameAdminPassword1: 'admin-password-1'
  }
}

@description('Existing Key Vault resource')
resource keyVaultReference 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: last(split(keyVault.outputs.resourceId, '/'))
}

module webapp 'webapp.bicep' = {
  name: 'drosel-webapp'
  params: {
    location: location
    environmentType: environmentType
    appServiceAPIAppName: appServiceAPIAppName
    appServicePlanId: serviceplan.outputs.id
    containerRegistryName: keyVault.outputs.keyVaultName
    dockerRegistryUserName: keyVaultReference.getSecret('admin-username')
    dockerRegistryPassword: keyVaultReference.getSecret('admin-password-0')
    dockerRegistryImageName: 'myimage'
    appSettings: [ ]
  }
  dependsOn: [
    registry
  ]
}

