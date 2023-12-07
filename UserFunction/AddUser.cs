using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace UserFunction;

public class AddUser
{
    [FunctionName("AddUser")]
    public static async Task<IActionResult> RunAsync(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req,
        [
            CosmosDB(databaseName: "Users", containerName: "Items", Connection = "CosmosDBConnectionString")
        ] IAsyncCollector<dynamic> documents,
        ILogger log)
    {
        log.LogInformation("C# HTTP trigger function processed a request.");

        string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
        User user = JsonConvert.DeserializeObject<User>(requestBody);

        if (user is not null)
        {
            user.Id = Guid.NewGuid().ToString();

            // client.GetContainer(DatabaseName, ContainerName).CreateItemAsync(user, new PartitionKey(user.LastName));
            // client.GetContainer(DatabaseName, ContainerName).GetItemLinqQueryable<User>();
            return new OkObjectResult(user);
        }
        else
        {
            return new BadRequestObjectResult("Please pass a user in the request body");
        }
    }
}
