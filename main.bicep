// ------ [ Azure Parameters ] ------ //

// Parameters for location of all resources
param location string = 'westus3'

// IP address for the Cosmos DB firewall
param myIpAddress string = '185.216.231.192'

// Parameters for the function app
param functionAppName string = 'final-project-functionapp'
param functionAppNamePlan string = 'final-project-functionapp-plan'
param functionAppStorageAccount string = 'finalprojectsa'

// Parameters for the virtual network
param vnetName string = 'final-project-vnet'
param vnetAddressPrefix string = '10.0.0.0/16'

// Parameters for the subnet
param subnetName string = 'final-project-subnet'
param subnetPrefix string = '10.0.0.0/24'

// Parameters for Cosmos DB
param cosmosDbAccountName string = 'final-project-cosmosdb'
param cosmosDbConsistencyLevel string = 'Session'
param cosmosDbDatabaseName string = 'Users'
param cosmosDbContainerName string = 'items'
param cosmosDbPartitionKey string = '/LastName'

// Parameters for the private endpoint
param privateEndpointName string = 'final-project-private-endpoint'

// Parameters for the API Management
param apiManagementName string = 'final-project-api-management-v7'

// Parameters for the Application Insights
param applicationInsightsName string = 'final-project-function-appinsights'

// Parameters for the Log Analytics workspace
param logAnalyticsWorkspaceName string = 'final-project-loganalytics-workspace'

// Parameters for the Key Vault
param keyVaultName string = 'final-project-keyvault'

// ------ [ Azure Resources ] ------ //
// ------------------- [ Key Vault ] ------------------- //

// ...
resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: keyVaultName
}

// ------------------- [ Cosmos DB ] ------------------- //

// Create Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

// Create Cosmos DB account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    isVirtualNetworkFilterEnabled: true
    publicNetworkAccess: 'Enabled'
    networkAclBypass: 'AzureServices'
    ipRules: [
      {
        ipAddressOrRange: myIpAddress
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: cosmosDbConsistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

// Create a private endpoint for Cosmos DB
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'cosmosDbConnection'
        properties: {
          privateLinkServiceId: cosmosDbAccount.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
    subnet: {
      id: virtualNetwork.properties.subnets[0].id
    }
  }
}

// Create Cosmos DB Database within the Cosmos DB Account
resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-04-15' = {
  parent: cosmosDbAccount
  name: cosmosDbDatabaseName
  properties: {
    resource: {
      id: cosmosDbDatabaseName
    }
    options: {
      throughput: 1000
    }
  }
}

// Create a Container within the Cosmos DB Database
resource cosmosDbContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-04-15' = {
  parent: cosmosDbDatabase
  name: cosmosDbContainerName
  properties: {
    resource: {
      id: cosmosDbContainerName
      partitionKey: {
        paths: [
          cosmosDbPartitionKey
        ]
        kind: 'Hash'
      }
    }
  }
}

// ------------------- [ Azure Function ] ------------------- //

// Create a storage account for the Azure Function
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  properties: {
    minimumTlsVersion: 'TLS1_2'
  }
  name: functionAppStorageAccount
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

// Create the Function App service plan
resource functionAppServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: functionAppNamePlan
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

// Create the Function App
resource functionApp 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: functionAppServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'CosmosDBConnection'
          value: 'AccountEndpoint=https://${cosmosDbAccountName}.documents.azure.com:443/;AccountKey=${cosmosDbAccount.listKeys().primaryMasterKey};'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'GithubOAuthToken'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/GitHubOAuthToken)'
        }
      ]
    }
  }
  resource sourceControl 'sourcecontrols' = {
    name: 'web'
    properties: {
      repoUrl: 'https://github.com/StrangeRanger/EWU-CSCD396-2023-Fall-Final'
      branch: 'main'
      isManualIntegration: false
      isGitHubAction: false
      deploymentRollbackEnabled: false
      isMercurial: false
    }
  }
}

// ------------------- [ API Management ] ------------------- //

// Create an API Management service
resource apiManagement 'Microsoft.ApiManagement/service@2021-04-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: 'email@example.com'
    publisherName: 'PublisherName'
  }
}

// ------------------- [ Anaylitics/Insight/Workspace ] ------------------- //

// Create a Log Analytics workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsWorkspaceName
  location: location
}

// Create Application Insights for monitoring the Azure Function
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// API Management API linked to the Azure Function
resource api 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  parent: apiManagement
  name: 'myFunctionApi'
  properties: {
    displayName: 'Function API'
    path: 'functionapi'
    serviceUrl: 'https://${functionApp.properties.defaultHostName}'
    protocols: [
      'https'
    ]
  }
}
