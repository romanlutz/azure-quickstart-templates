// Execute this main file to depoy Azure AI Foundry resources in the basic security configuraiton

// Parameters
@minLength(2)
@maxLength(12)
@description('Name for the AI resource and used to derive name of dependent resources.')
param aiHubName string = 'pyrit-lab'

@description('Friendly name for your Azure AI resource')
param aiHubFriendlyName string = 'pyrit-lab'

@description('Description of your Azure AI resource dispayed in AI Foundry')
param aiHubDescription string = 'This is an example AI resource for use in Azure AI Foundry.'

@description('Azure region used for the deployment of all resources.')
param location string = resourceGroup().location

// Variables
var name = toLower('${aiHubName}')
var aiServicesName = 'ais${name}${uniqueSuffix}'

// Create a short, unique suffix, that will be unique to each resource group
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)

// Dependent resources for the Azure Machine Learning workspace
module aiDependencies 'modules/dependent-resources.bicep' = {
  name: 'dependencies-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    storageName: 'st${name}${uniqueSuffix}'
    keyvaultName: 'kv-${name}-${uniqueSuffix}'
    applicationInsightsName: 'appi-${name}-${uniqueSuffix}'
    containerRegistryName: 'cr${name}${uniqueSuffix}'
    aiServicesName: aiServicesName
    deployments: [
      {
        model: {
          name: 'gpt-4o'
          version: '2024-05-13'
        }
        sku: {
          name: 'Standard'
          capacity: 10
        }
      }
    ]
  }
}

module aiHub 'modules/ai-hub.bicep' = {
  name: 'ai-${name}-${uniqueSuffix}-deployment'
  params: {
    // workspace organization
    aiHubName: 'aih-${name}-${uniqueSuffix}'
    aiHubFriendlyName: aiHubFriendlyName
    aiHubDescription: aiHubDescription
    location: location

    // dependent resources
    aiServicesId: aiDependencies.outputs.aiservicesID
    aiServicesTarget: aiDependencies.outputs.aiservicesTarget
    applicationInsightsId: aiDependencies.outputs.applicationInsightsId
    containerRegistryId: aiDependencies.outputs.containerRegistryId
    keyVaultId: aiDependencies.outputs.keyvaultId
    storageAccountId: aiDependencies.outputs.storageId
  }
}

module project 'modules/project.bicep' = {
  name: 'project-${name}-${uniqueSuffix}-deployment'
  params: {
    location: location
    projectName: 'proj-${name}-${uniqueSuffix}'
    projectFriendlyName: 'pyrit-lab'
    hubId: aiHub.outputs.aiHubID
  }
}
