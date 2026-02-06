using Microsoft.Data.SqlClient;

namespace MedicalDbMcpServer.Data;

/// <summary>
/// A placeholder connection factory used when no database connection string is configured.
/// This allows the MCP server to start and respond to health checks (/alive, /health)
/// even when the database is not yet configured.
/// </summary>
/// <remarks>
/// This is useful during initial deployment testing to Azure, where you want to verify
/// the server is running and reachable before configuring the database connection.
/// Any attempt to use MCP tools that require database access will receive a clear error.
/// </remarks>
public sealed class NullConnectionFactory : IDbConnectionFactory
{
    /// <inheritdoc/>
    /// <exception cref="InvalidOperationException">
    /// Always thrown, as no database connection string is configured.
    /// </exception>
    public Task<SqlConnection> CreateConnectionAsync(CancellationToken cancellationToken = default)
    {
        throw new InvalidOperationException(
            "Database connection is not configured. " +
            "Please set 'ConnectionStrings:MedicalDb' in configuration or " +
            "'MEDICAL_DB_CONNECTION_STRING' environment variable.");
    }
}
