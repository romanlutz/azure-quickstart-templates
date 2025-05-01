// Creates Azure dependent resources for Azure AI Foundry

@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('AI services name')
param aiServicesName string

@description('Specifies the OpenAI deployments to create.')
param deployments array = []

@description('Specifies the OpenAI without custom RAI policy deployments to create.')
param deploymentsNoRAI array = []

@description('Application Insights resource name')
param applicationInsightsName string

@description('Container registry name')
param containerRegistryName string

@description('The name of the Key Vault')
param keyvaultName string

@allowed(['Asynchronous_filter', 'Blocking', 'Default', 'Deferred'])
param mode string = 'Default'

@description('Base policy to be used for the new policy')
param basePolicyName string = 'Microsoft.DefaultV2'

param contentFilters array = [
  {
    name: 'Violence'
    severityThreshold: 'High'
    blocking: true
    enabled: true
    source: 'Prompt'
  }
  {
      name: 'Hate'
      severityThreshold: 'High'
      blocking: true
      enabled: true
      source: 'Prompt'
  }
  {
      name: 'Sexual'
      severityThreshold: 'High'
      blocking: true
      enabled: true
      source: 'Prompt'
  }
  {
      name: 'Selfharm'
      severityThreshold: 'High'
      blocking: true
      enabled: true
      source: 'Prompt'
  }
  {
      name: 'Jailbreak'
      blocking: true
      enabled: true
      source: 'Prompt'
  }
  {
      name: 'Indirect Attack'
      blocking: true
      enabled: true
      source: 'Prompt'
  }
  {
      name: 'Profanity'
      blocking: true
      enabled: true
      source: 'Prompt'
  }
  {
      name: 'Violence'
      severityThreshold: 'High'
      blocking: true
      enabled: true
      source: 'Completion'
  }
  {
      name: 'Hate'
      severityThreshold: 'High'
      blocking: true
      enabled: true
      source: 'Completion'
  }
  {
      name: 'Sexual'
      severityThreshold: 'High'
      blocking: true
      enabled: true
      source: 'Completion'
  }
  {
      name: 'Selfharm'
      severityThreshold: 'High'
      blocking: true
      enabled: true
      source: 'Completion'
  }
  {
      name: 'Protected Material Text'
      blocking: true
      enabled: true
      source: 'Completion'
  }
  {
      name: 'Protected Material Code'
      blocking: true
      enabled: true
      source: 'Completion'
  }
  {
      name: 'Profanity'
      blocking: true
      enabled: true
      source: 'Completion'
  }
]

var containerRegistryNameCleaned = replace(containerRegistryName, '-', '')

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    DisableIpMasking: false
    DisableLocalAuth: false
    Flow_Type: 'Bluefield'
    ForceCustomerStorageForProfiler: false
    ImmediatePurgeDataOn30Days: true
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Disabled'
    Request_Source: 'rest'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: containerRegistryNameCleaned
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: 'Deny'
    }
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      retentionPolicy: {
        status: 'enabled'
        days: 7
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: 'Disabled'
    zoneRedundancy: 'Disabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyvaultName
  location: location
  properties: {
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    enableRbacAuthorization: true
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
}

@description('Name of the storage account')
param storageName string

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Premium_LRS'
  'Premium_ZRS'
])

@description('Storage SKU')
param storageSkuName string = 'Standard_LRS'

var storageNameCleaned = replace(storageName, '-', '')

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: aiServicesName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
}

resource raiPolicy 'Microsoft.CognitiveServices/accounts/raiPolicies@2024-10-01' = {
  name: 'custom-policy'
  parent: aiServices
  properties: {
      mode: mode
      basePolicyName: basePolicyName
      contentFilters: contentFilters
  }
}

@batchSize(1)
resource model 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [
  for deployment in deployments: {
    name: deployment.model.name
    parent: aiServices
    sku: {
      capacity: deployment.sku.capacity ?? 100
      name: empty(deployment.sku.name) ? 'Standard' : deployment.sku.name
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: deployment.model.name
        version: deployment.model.version
      }
      raiPolicyName: 'custom-policy'
    }
    dependsOn: [
      raiPolicy
    ]
  }
]

@batchSize(1)
resource modelNoRAI 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [
  for deployment in deploymentsNoRAI: {
    name: deployment.model.name
    parent: aiServices
    sku: {
      capacity: deployment.sku.capacity ?? 100
      name: empty(deployment.sku.name) ? 'Standard' : deployment.sku.name
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: deployment.model.name
        version: deployment.model.version
      }
    }
    dependsOn: [
      model
      storage
    ]
  }
]

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageNameCleaned
  location: location
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Service'
        }
        table: {
          enabled: true
          keyType: 'Service'
        }
      }
    }
    isHnsEnabled: false
    isNfsV3Enabled: false
    keyPolicy: {
      keyExpirationPeriodInDays: 7
    }
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
  }
}

output aiservicesID string = aiServices.id
output aiservicesTarget string = aiServices.properties.endpoint
output storageId string = storage.id
output keyvaultId string = keyVault.id
output containerRegistryId string = containerRegistry.id
output applicationInsightsId string = applicationInsights.id
output aiservicesKey string = aiServices.listKeys().key1
output aiservicesEndpoints object = aiServices.properties.endpoints
