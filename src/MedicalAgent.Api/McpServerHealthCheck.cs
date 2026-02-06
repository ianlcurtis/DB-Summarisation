using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace MedicalAgent.Api;

/// <summary>
/// Health check that verifies connectivity to the MCP server.
/// Uses a simple HTTP request to the health endpoint rather than the MCP protocol
/// to avoid issues with stale SSE connections.
/// </summary>
public sealed class McpServerHealthCheck : IHealthCheck
{
    private readonly IConfiguration _config;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<McpServerHealthCheck> _logger;

    public McpServerHealthCheck(
        IConfiguration config,
        IHttpClientFactory httpClientFactory,
        ILogger<McpServerHealthCheck> logger)
    {
        _config = config;
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Get the MCP server endpoint
            var mcpEndpoint = _config["McpServer:Endpoint"];
            if (string.IsNullOrEmpty(mcpEndpoint))
            {
                // Fall back to service discovery
                var discoveryClient = _httpClientFactory.CreateClient("mcp-server");
                mcpEndpoint = discoveryClient.BaseAddress?.ToString();
            }

            if (string.IsNullOrEmpty(mcpEndpoint))
            {
                return HealthCheckResult.Unhealthy("MCP server endpoint not configured");
            }

            // Use a simple HTTP health check to the MCP server's /health endpoint
            // This is more reliable than using the MCP protocol for health checks
            using var httpClient = _httpClientFactory.CreateClient();
            var healthUrl = new Uri(new Uri(mcpEndpoint.TrimEnd('/')), "/health");
            
            var response = await httpClient.GetAsync(healthUrl, cancellationToken).ConfigureAwait(false);
            
            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                return HealthCheckResult.Healthy($"MCP server is healthy: {content}");
            }
            else
            {
                return HealthCheckResult.Unhealthy($"MCP server returned {response.StatusCode}");
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "MCP server health check failed");
            return HealthCheckResult.Unhealthy("MCP server is not reachable", exception: ex);
        }
    }
}
