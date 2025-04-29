// Creates an Azure AI resource with proxied endpoints for the Azure AI services provider

@description('Azure region of the deployment')
param location string

@description('Project name')
param projectName string

@description('Project display name')
param projectFriendlyName string = projectName

@description('Specifies the AI hub resource id')
param hubId string

@description('Specifies the public network access for the machine learning workspace.')
param publicNetworkAccess string = 'Enabled'

resource project 'Microsoft.MachineLearningServices/workspaces@2023-08-01-preview' = {
  name: projectName
  location: location
  kind: 'Project'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: projectFriendlyName
    hbiWorkspace: false
    v1LegacyMode: false
    publicNetworkAccess: publicNetworkAccess
    hubResourceId: hubId
    systemDatastoresAuthMode: 'identity'
  }
}
