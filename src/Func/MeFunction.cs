using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;

namespace Func
{
    public class MeFunction
    {
        private readonly ISecurityValidator _securityValidator;

        public MeFunction(
            ISecurityValidator securityValidator)
        {
            _securityValidator = securityValidator;
        }

        [FunctionName("Me")]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("Me function processing request.");

            var principal = await _securityValidator.GetClaimsPrincipalAsync(req, log);
            if (principal == null)
            {
                return new UnauthorizedResult();
            }

            return new OkObjectResult(principal
                .Claims
                .Select(c => c.Value)
                .ToList());
        }
    }
}
