using System;
using System.Net;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;

namespace Func
{
    public class SalesFunction
    {
        private readonly ISecurityValidator _securityValidator;
        private readonly ISalesRepository _salesRepository;

        public SalesFunction(
            ISecurityValidator securityValidator,
            ISalesRepository salesRepository)
        {
            _securityValidator = securityValidator;
            _salesRepository = salesRepository;
        }

        [FunctionName("Sales")]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", "delete", Route = "sales/{id?}")] HttpRequest req,
            string id,
            ILogger log)
        {
            log.LogInformation("Sales function processing request.");

            var principal = await _securityValidator.GetClaimsPrincipalAsync(req, log);
            if (principal == null)
            {
                return new UnauthorizedResult();
            }

            log.LogInformation("Processing {method} request", req.Method);
            return req.Method switch
            {
                "GET" => Get(log, principal, id),
                "POST" => Post(log, principal, req, id),
                "DELETE" => Delete(log, principal, id),
                _ => new StatusCodeResult((int)HttpStatusCode.NotImplemented)
            };
        }

        private IActionResult Get(ILogger log, ClaimsPrincipal principal, string id)
        {
            if (!(principal.HasPermission(PermissionConstants.SalesRead) ||
                principal.HasPermission(PermissionConstants.SalesReadWrite)))
            {
                log.LogWarning("User {user} does not have (at least) permission {permission}", principal.Identity.Name, PermissionConstants.SalesRead);
                return new UnauthorizedResult();
            }

            if (string.IsNullOrEmpty(id))
            {
                log.LogTrace("Fetch all data");
                var response = _salesRepository.Get();
                return new OkObjectResult(response);
            }
            else
            {
                log.LogTrace("Fetch data with {id}", id);
                var response = _salesRepository.Get(id);
                if (response == null)
                {
                    return new NotFoundResult();
                }
                return new OkObjectResult(response);
            }
        }

        private IActionResult Post(ILogger log, ClaimsPrincipal principal, HttpRequest req, string id)
        {
            if (!principal.HasPermission(PermissionConstants.SalesReadWrite))
            {
                log.LogWarning("User {user} does not have permission {permission}", principal.Identity.Name, PermissionConstants.SalesReadWrite);
                return new UnauthorizedResult();
            }
            return new OkObjectResult($"sales data updated {id}");
        }

        private IActionResult Delete(ILogger log, ClaimsPrincipal principal, string id)
        {
            if (!principal.HasPermission(PermissionConstants.SalesReadWrite))
            {
                log.LogWarning("User {user} does not have permission {permission}", principal.Identity.Name, PermissionConstants.SalesReadWrite);
                return new UnauthorizedResult();
            }
            return new OkResult();
        }
    }
}
