// ------ [ Azure Parameters ] ------ //

param location string = 'westus3'

// // Parameters for the web app
// param webAppName string = 'final-project-webapp'
// param webAppNamePlan string = 'final-project-webapp-plan'

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
param cosmosDbContainerName string = 'Items'
param cosmosDbPartitionKey string = '/LastName'

// Parameters for the private endpoint
param privateEndpointName string = 'final-project-private-endpoint'

// Parameters for the API Management
param apiManagementName string = 'final-project-api-management-v3'

// Parameters for the Application Insights
param applicationInsightsName string = 'final-project-appinsights'

// Parameters for the Log Analytics workspace
param logAnalyticsWorkspaceName string = 'final-project-loganalytics-workspace'

// ------ [ Azure Resources ] ------ //
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
      throughput: 1000 // Optional: Specify throughput
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
      // Other container properties as needed
    }
    options: {
      // Container options like throughput
    }
  }
}

// ------------------- [ Web App ] ------------------- //

// // Create an App Service Plan
// resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
//   name: webAppNamePlan
//   location: location
//   sku: {
//     name: 'P1v2' // Pricing tier for the App Service Plan
//   }
// }

// // Create a Web App
// resource webApp 'Microsoft.Web/sites@2021-02-01' = {
//   name: webAppName
//   location: location
//   properties: {
//     serverFarmId: appServicePlan.id
//     httpsOnly: true
//   }
// }

// ------------------- [ Azure Function ] ------------------- //

// Create a storage account for the Azure Function
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  // Set minimumTlsVersion to disable support for older TLS versions
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
          name: 'CosmosDBConnectionString'
          value: 'AccountEndpoint=https://${cosmosDbAccountName}.documents.azure.com:443/;AccountKey=${cosmosDbAccount.listKeys().primaryMasterKey};'
        }
        // Add the Application Insights instrumentation key
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4' // Set the Functions runtime version to ~4
        }
      ]
    }
  }
}

// ------------------- [ API Management ] ------------------- //

// Create an API Management service
resource apiManagement 'Microsoft.ApiManagement/service@2021-04-01-preview' = {
  name: apiManagementName
  location: location
  sku: {
    name: 'Consumption' // Pricing tier for the API Management service
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
  properties: {
    // Workspace properties
  }
}

// Create Application Insights for monitoring
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id // Link to Log Analytics Workspace
    // Other properties as needed
  }
}

resource applicationInsightsForAPIM 'Microsoft.Insights/components@2020-02-02' = {
  name: 'apim-appinsights'
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

resource apiManagementLogger 'Microsoft.ApiManagement/service/loggers@2021-04-01-preview' = {
  parent: apiManagement
  name: 'apim-logger'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Logger for APIM'
    credentials: {
      instrumentationKey: applicationInsightsForAPIM.properties.InstrumentationKey
    }
  }
}
