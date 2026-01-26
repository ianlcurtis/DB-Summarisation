using Microsoft.Extensions.Diagnostics.HealthChecks;
using ModelContextProtocol.Client;

namespace MedicalAgent.Api;

/// <summary>
/// Health check that verifies connectivity to the MCP server.
/// </summary>
public sealed class McpServerHealthCheck : IHealthCheck
{
    private readonly MedicalMcpClientFactory _mcpFactory;
    private readonly ILogger<McpServerHealthCheck> _logger;

    public McpServerHealthCheck(MedicalMcpClientFactory mcpFactory, ILogger<McpServerHealthCheck> logger)
    {
        _mcpFactory = mcpFactory;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Attempt to get or establish MCP client connection
            var client = await _mcpFactory.GetClientAsync(cancellationToken).ConfigureAwait(false);

            // Verify connection by listing tools (lightweight operation)
            var tools = await client.ListToolsAsync(cancellationToken: cancellationToken).ConfigureAwait(false);

            return HealthCheckResult.Healthy($"MCP server connected. {tools.Count} tools available.");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "MCP server health check failed");

            // Trigger reconnection on next request
            try
            {
                await _mcpFactory.ReconnectAsync(cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                // Ignore reconnect errors during health check
            }

            return HealthCheckResult.Unhealthy(
                "MCP server is not reachable",
                exception: ex);
        }
    }
}
