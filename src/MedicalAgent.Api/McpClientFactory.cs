using ModelContextProtocol.Client;
using ModelContextProtocol.Protocol;

namespace MedicalAgent.Api;

/// <summary>
/// Singleton manager for MCP client connections to the MedicalDbMcpServer.
/// Provides thread-safe lazy initialization with automatic reconnection.
/// Uses Aspire service discovery to locate the MCP server endpoint.
/// </summary>
public sealed class MedicalMcpClientFactory : IAsyncDisposable
{
    private readonly IConfiguration _config;
    private readonly ILogger<MedicalMcpClientFactory> _logger;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly SemaphoreSlim _connectionLock = new(1, 1);
    private McpClient? _client;
    private bool _disposed;

    public MedicalMcpClientFactory(
        IConfiguration config, 
        ILogger<MedicalMcpClientFactory> logger,
        IHttpClientFactory httpClientFactory)
    {
        _config = config;
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

    /// <summary>
    /// Gets or creates a shared MCP client connection.
    /// Thread-safe with automatic reconnection if the connection is lost.
    /// </summary>
    public async Task<McpClient> GetClientAsync(CancellationToken ct = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        // Fast path: return existing healthy connection
        if (_client is not null)
        {
            return _client;
        }

        await _connectionLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            // Double-check after acquiring lock
            if (_client is not null)
            {
                return _client;
            }

            _client = await CreateClientAsync(ct).ConfigureAwait(false);
            _logger.LogInformation("MCP client connection established");
            return _client;
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    /// <summary>
    /// Forces reconnection on next GetClientAsync call.
    /// Call this if the connection appears to be broken.
    /// </summary>
    public async Task ReconnectAsync(CancellationToken ct = default)
    {
        await _connectionLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            if (_client is not null)
            {
                _logger.LogInformation("Closing existing MCP client connection for reconnect");
                await _client.DisposeAsync().ConfigureAwait(false);
                _client = null;
            }
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    private async Task<McpClient> CreateClientAsync(CancellationToken ct)
    {
        // Use Aspire service discovery via named HttpClient
        // The "mcp-server" client is configured with service discovery in Program.cs
        var httpClient = _httpClientFactory.CreateClient("mcp-server");
        
        // MCP server uses MapMcp() which maps Streamable HTTP at root path
        var mcpEndpoint = httpClient.BaseAddress!;
        
        _logger.LogInformation("Connecting to MCP server at {McpServerUrl}", mcpEndpoint);

        // Connect to MCP server via Streamable HTTP transport
        var transport = new HttpClientTransport(new HttpClientTransportOptions
        {
            Endpoint = mcpEndpoint,
            Name = "MedicalDbMcpServer"
        }, httpClient);

        var client = await McpClient.CreateAsync(
            transport,
            new McpClientOptions
            {
                ClientInfo = new Implementation { Name = "MedicalAgent", Version = "1.0.0" }
            },
            cancellationToken: ct
        ).ConfigureAwait(false);

        return client;
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;

        await _connectionLock.WaitAsync().ConfigureAwait(false);
        try
        {
            if (_client is not null)
            {
                await _client.DisposeAsync().ConfigureAwait(false);
                _client = null;
            }
        }
        finally
        {
            _connectionLock.Release();
            _connectionLock.Dispose();
        }
    }
}
