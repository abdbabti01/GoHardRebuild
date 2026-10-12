namespace GoHard.Api.Application.FoodDiscovery;

public static class FoodDiscoveryRegistration
{
    public static IServiceCollection AddFoodDiscovery(this IServiceCollection services, IConfiguration config)
    {
        var options = config.GetSection("FoodData").Get<FoodDataOptions>() ?? new();
        services.AddSingleton(options);
        // The service bounds each call itself; the client timeout is only a backstop behind it.
        services.AddHttpClient<OpenFoodFactsProvider>(c =>
        {
            c.BaseAddress = new Uri(options.OpenFoodFactsBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds + 2);
            c.DefaultRequestHeaders.UserAgent.ParseAdd(options.UserAgent);
        }).ConfigurePrimaryHttpMessageHandler(Handler);
        services.AddHttpClient<UsdaProvider>(c =>
        {
            c.BaseAddress = new Uri(options.UsdaBaseUrl);
            c.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds + 2);
            c.DefaultRequestHeaders.UserAgent.ParseAdd(options.UserAgent);
            if (options.UsdaConfigured) c.DefaultRequestHeaders.Add("X-Api-Key", options.UsdaApiKey!.Trim());
        }).ConfigurePrimaryHttpMessageHandler(Handler);
        // One instance for the process: it holds the cache and the request budgets every user shares.
        services.AddSingleton<FoodDiscoveryService>();
        return services;
    }

    // The clients live as long as the service that holds them, so connections are renewed here instead of by the factory.
    private static HttpMessageHandler Handler() => new SocketsHttpHandler { PooledConnectionLifetime = TimeSpan.FromMinutes(5) };
}
