using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace Func
{
    public interface ISecurityValidator
    {
        Task<ClaimsPrincipal> GetClaimsPrincipalAsync(HttpRequest req, ILogger log);
    }
}
