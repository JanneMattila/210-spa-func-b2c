using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

[assembly: FunctionsStartup(typeof(Func.Startup))]

namespace Func
{
    public class Startup : FunctionsStartup
    {
        public override void Configure(IFunctionsHostBuilder builder)
        {
#if DEBUG
            Microsoft.IdentityModel.Logging.IdentityModelEventSource.ShowPII = true;
#endif
            builder.Services.AddOptions<AzureADB2COptions>()
                .Configure<IConfiguration>((settings, configuration) =>
                {
                    configuration.GetSection("AzureADB2C").Bind(settings);
                });
            builder.Services.AddSingleton<ISalesRepository, SalesRepository>();
            builder.Services.AddSingleton<ISecurityValidator, SecurityValidator>();
        }
    }
}
