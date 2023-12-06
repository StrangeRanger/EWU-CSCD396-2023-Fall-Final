using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace UserFunction
{
    public class GetUser
    {
        [FunctionName("GetRandomUser")]
        public static async Task<IActionResult> RunAsync(
            [HttpTrigger(AuthorizationLevel.Function, "get", Route = null)] HttpRequest req,
            [
                CosmosDB(databaseName: "Users", containerName: "Items", Connection = "CosmosDBConnection")
            ] CosmosClient client,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request");

            Container container = client.GetDatabase("Users").GetContainer("items");

            log.LogInformation("Searching for User Count");

            QueryDefinition queryDefinition = new QueryDefinition("SELECT value Count(i) FROM items i");

            int count = 0;
            using (FeedIterator<int> resultSet = container.GetItemQueryIterator<int>(queryDefinition))
            {
                count = (await resultSet.ReadNextAsync()).First();
            }
            log.LogInformation("{Count} users found", count);

            // Random number between 0 and count
            var rnd = new Random();
            int offset = rnd.Next(count);

            log.LogInformation("Grabbing user {Offset} of {Count}", offset, count);

            QueryDefinition queryDefinitionUser = new QueryDefinition($"SELECT * FROM items i OFFSET {offset} LIMIT 1");

            User? user = null;
            using (FeedIterator<User> resultSet = container.GetItemQueryIterator<User>(queryDefinitionUser))
            {
                user = (await resultSet.ReadNextAsync()).First();
            }

            if (user == null)
            {
                return new OkObjectResult(
                    $"No users found with User Id {req.Query["id"]} and author {req.Query["partitionKey"]}");
            }
            return new OkObjectResult(user);
        }
    }
}
