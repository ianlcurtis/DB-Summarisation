using Microsoft.Data.SqlClient;

namespace MedicalDbMcpServer.Data;

/// <summary>
/// Factory interface for creating database connections.
/// </summary>
public interface IDbConnectionFactory
{
    /// <summary>
    /// Creates and opens a new SQL connection asynchronously.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>An open SqlConnection.</returns>
    Task<SqlConnection> CreateConnectionAsync(CancellationToken cancellationToken = default);
}
