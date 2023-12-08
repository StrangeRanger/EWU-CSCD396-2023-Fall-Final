# EWU-CSCD396-2023-Winter-Final

[![Project Tracker](https://img.shields.io/badge/repo%20status-Project%20Tracker-lightgrey)](https://wiki.hthompson.dev/en/project-tracker)

This repository contains the code for an Azure Function, used in my Final for [CSCD 396 class](https://github.com/StrangeRanger/EWU-CSCD396-2023-Fall). In this README, I'll outline the steps to get everything working...

## Setup

1. Generate a GitHub token with the following permissions:

   1. All `repo` permissions should be enabled
   2. All `admin:repo_hook` permission should be enabled

2. Save your configurations and place the generated token in a safe location.

3. Create an Azure KeyVault to store the GitHub token in:

   ```bash
   az group create --resource-group cscd396-final --location "westus3"
   az keyvault create --name "final-project-keyvault" --resource-group "cscd396-final" --location "westus3"
   az keyvault secret set --name GitHubOAuthToken --vault-name "final-project-keyvault" --value "<YourGitHubOAuthToken>" # Replace "<YourGitHubOAuthToken>" with your token.
   ```

4. After confirming the token has been stored, execute the bicep file

   ```bash
   az deployment group create --resource-group "cscd396-final" --template-file "main.bicep"
   ```

   This will take anywhere from 8 to 15 minutes to finish setting everything up.

5. Once the bicep file has run its course, access the Azure resource group, via the website, containing all of your services.

6. Access the CosmosDB Account and click the `Networks` tab in the Settings section. Ensure that you are on the `Public access` tab, and enable the following settings, add your current IP to the Firewall whitelist, then hit `Save`. Note that the new firewall settings will take up to 5+ minutes to be updated.

   ![Screenshot 2023-12-07 at 9.52.45 AM](/Users/hunter/Library/Application Support/typora-user-images/Screenshot 2023-12-07 at 9.52.45 AM.png)

7. Make your way to the `Data Explorer` tab, and stop when you are at a screen that looks similar to the following:

   ![Screenshot 2023-12-07 at 9.54.59 AM](/Users/hunter/Library/Application Support/typora-user-images/Screenshot 2023-12-07 at 9.54.59 AM.png)

8. Select `Upload Item`, and upload the `generated_users.json` file. This should populate the database with 10 users.

9. Next, make your way to the APIM resource, labeled `final-project-api-management-v6`.

10. Click on the `API` tab in the `APIs` section, and you should be greated by something similar to the following picture:

    ![Screenshot 2023-12-07 at 1.55.50 PM](/Users/hunter/Desktop/Screenshot 2023-12-07 at 1.55.50 PM.png)

11. Click on the `Function App` box, and you'll be led through the process of adding the function to your APIM.

## Other

### Azure Function Purpose/Info

< ADD INFO ON WHAT THE FUNCTION DOES >
