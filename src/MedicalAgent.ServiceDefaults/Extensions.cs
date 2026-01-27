using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

namespace Microsoft.Extensions.Hosting;

// =============================================================================
// .NET ASPIRE SERVICE DEFAULTS
// =============================================================================
// This class provides extension methods that configure standard "service defaults"
// for all projects in your Aspire solution. These defaults include:
//   - OpenTelemetry for distributed tracing and metrics
//   - Health checks for Kubernetes-style probes
//   - Service discovery for finding other services by name
//   - Resilient HTTP clients with retry policies
//
// Each project calls builder.AddServiceDefaults() to get consistent configuration.
// Learn more: https://learn.microsoft.com/dotnet/aspire/fundamentals/service-defaults
// =============================================================================
public static class Extensions
{
    /// <summary>
    /// Adds the standard Aspire service defaults to your application.
    /// Call this in Program.cs: builder.AddServiceDefaults();
    /// 
    /// This single call configures:
    /// - OpenTelemetry (logs, metrics, traces) sent to the Aspire dashboard
    /// - Health check endpoints (/health, /alive)
    /// - Service discovery (resolve "http://mcp-server" to actual URL)
    /// - Resilient HTTP clients with automatic retries
    /// </summary>
    public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
    {
        // Configure OpenTelemetry for observability
        // This enables the Aspire dashboard to show logs, metrics, and traces
        builder.ConfigureOpenTelemetry();

        // Add default health checks for liveness/readiness probes
        builder.AddDefaultHealthChecks();

        // Enable service discovery - allows services to find each other by name
        // e.g., "http://mcp-server" resolves to the actual endpoint
        builder.Services.AddServiceDiscovery();

        // Configure all HttpClient instances with resilience and service discovery
        builder.Services.ConfigureHttpClientDefaults(http =>
        {
            // AddStandardResilienceHandler adds retry policies, circuit breakers,
            // and timeouts to all HTTP calls - essential for distributed systems
            http.AddStandardResilienceHandler();

            // Enable service discovery for HttpClient - URLs like "http://mcp-server"
            // are automatically resolved to actual endpoints
            http.AddServiceDiscovery();
        });

        return builder;
    }

    /// <summary>
    /// Configures OpenTelemetry for distributed observability.
    /// 
    /// OpenTelemetry is the industry standard for collecting:
    /// - Logs: Application log messages with structured data
    /// - Metrics: Counters, histograms (request count, response times)
    /// - Traces: Distributed traces showing request flow across services
    /// 
    /// The Aspire dashboard automatically receives this telemetry via OTLP
    /// (OpenTelemetry Protocol), giving you real-time visibility into your app.
    /// </summary>
    public static IHostApplicationBuilder ConfigureOpenTelemetry(this IHostApplicationBuilder builder)
    {
        // Configure logging to flow through OpenTelemetry
        builder.Logging.AddOpenTelemetry(logging =>
        {
            // Include the formatted message in logs (not just structured data)
            logging.IncludeFormattedMessage = true;
            // Include logging scopes for additional context
            logging.IncludeScopes = true;
        });

        builder.Services.AddOpenTelemetry()
            // Configure METRICS collection
            .WithMetrics(metrics =>
            {
                // Collect ASP.NET Core metrics (request duration, status codes)
                metrics.AddAspNetCoreInstrumentation()
                       // Collect HttpClient metrics (outgoing request duration)
                       .AddHttpClientInstrumentation()
                       // Collect .NET runtime metrics (GC, thread pool)
                       .AddRuntimeInstrumentation();
            })
            // Configure TRACING (distributed traces)
            .WithTracing(tracing =>
            {
                // Trace incoming HTTP requests
                tracing.AddAspNetCoreInstrumentation()
                       // Trace outgoing HTTP calls (shows full request chain)
                       .AddHttpClientInstrumentation()
                       // Trace SQL queries (see database calls in traces)
                       .AddSqlClientInstrumentation();
            });

        // Add exporters to send telemetry to the Aspire dashboard
        AddOpenTelemetryExporters(builder);

        return builder;
    }

    /// <summary>
    /// Adds OTLP (OpenTelemetry Protocol) exporters if configured.
    /// The Aspire AppHost automatically sets OTEL_EXPORTER_OTLP_ENDPOINT
    /// to point to its dashboard collector.
    /// </summary>
    private static void AddOpenTelemetryExporters(IHostApplicationBuilder builder)
    {
        // Check if OTLP endpoint is configured (set automatically by Aspire)
        var useOtlpExporter = !string.IsNullOrWhiteSpace(
            builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]);

        if (useOtlpExporter)
        {
            // UseOtlpExporter() sends all telemetry to the configured endpoint
            // In Aspire, this is the dashboard's collector
            builder.Services.AddOpenTelemetry().UseOtlpExporter();
        }
    }

    /// <summary>
    /// Adds default health checks used by container orchestrators (Kubernetes, etc).
    /// Health checks tell the orchestrator whether your service is healthy.
    /// </summary>
    public static IHostApplicationBuilder AddDefaultHealthChecks(this IHostApplicationBuilder builder)
    {
        builder.Services.AddHealthChecks()
            // Add a simple "self" check that always returns healthy
            // Tagged with "live" for the liveness probe
            .AddCheck("self", () => HealthCheckResult.Healthy(), ["live"]);

        return builder;
    }

    /// <summary>
    /// Maps health check endpoints to your web application.
    /// These endpoints are used by Kubernetes and other orchestrators:
    /// 
    /// /health - READINESS probe
    ///   - Checks if the service is ready to receive traffic
    ///   - All health checks must pass
    ///   - Used to determine when to route traffic to a new instance
    /// 
    /// /alive - LIVENESS probe  
    ///   - Checks if the service process is alive
    ///   - Only checks tagged with "live" (minimal checks)
    ///   - If this fails, the orchestrator restarts the container
    /// </summary>
    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        // Readiness probe - all health checks must pass
        // If any check fails, the service is not ready to receive traffic
        app.MapHealthChecks("/health");

        // Liveness probe - only checks tagged with "live"
        // This is a minimal check to verify the process is alive
        // Keeps the check lightweight to avoid false negatives
        app.MapHealthChecks("/alive", new HealthCheckOptions
        {
            Predicate = r => r.Tags.Contains("live")
        });

        return app;
    }
}
