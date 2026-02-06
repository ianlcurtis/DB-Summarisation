using Azure.Core;
using Azure.Identity;
using ModelContextProtocol.Client;
using ModelContextProtocol.Protocol;

namespace MedicalAgent.Api;

/// <summary>
/// Singleton manager for MCP client connections to the MedicalDbMcpServer.
/// Provides thread-safe lazy initialization with automatic reconnection.
/// Uses Aspire service discovery to locate the MCP server endpoint.
/// Supports Entra ID authentication when deployed to Azure with automatic token refresh.
/// </summary>
public sealed class MedicalMcpClientFactory : IAsyncDisposable
{
    private readonly IConfiguration _config;
    private readonly ILogger<MedicalMcpClientFactory> _logger;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly TokenCredential? _credential;
    private readonly string? _entraScope;
    private readonly SemaphoreSlim _connectionLock = new(1, 1);
    private McpClient? _client;
    private DateTimeOffset _tokenExpiresOn;
    private bool _disposed;
    
    /// <summary>
    /// Event raised when the MCP client is reconnected, signaling that cached agents
    /// need to be invalidated as their tool references are now stale.
    /// </summary>
    public event EventHandler? OnReconnected;
    
    /// <summary>
    /// Increments each time the client is reconnected. Agents can check this
    /// to determine if they need to recreate themselves with fresh tools.
    /// </summary>
    public long ConnectionGeneration { get; private set; }
    
    /// <summary>
    /// Buffer time before token expiration to trigger a refresh.
    /// Reconnect 5 minutes before the token expires to avoid request failures.
    /// </summary>
    private static readonly TimeSpan TokenRefreshBuffer = TimeSpan.FromMinutes(5);

    public MedicalMcpClientFactory(
        IConfiguration config, 
        ILogger<MedicalMcpClientFactory> logger,
        IHttpClientFactory httpClientFactory)
    {
        _config = config;
        _logger = logger;
        _httpClientFactory = httpClientFactory;
        
        // Initialize Entra authentication if configured
        var entraAuthEnabled = config.GetValue<bool>("McpServer:EntraAuth:Enabled");
        if (entraAuthEnabled)
        {
            _entraScope = config["McpServer:EntraAuth:Scope"] 
                ?? throw new InvalidOperationException("McpServer:EntraAuth:Scope is required when Entra auth is enabled");
            
            // Use DefaultAzureCredential which works with Managed Identity in Azure
            // and falls back to Azure CLI/Visual Studio credentials locally
            _credential = new DefaultAzureCredential();
            _logger.LogInformation("Entra authentication enabled for MCP server with scope: {Scope}", _entraScope);
        }
    }

    /// <summary>
    /// Gets or creates a shared MCP client connection.
    /// Thread-safe with automatic reconnection if the connection is lost or token is expiring.
    /// </summary>
    public async Task<McpClient> GetClientAsync(CancellationToken ct = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        // Check if we need to refresh due to token expiration
        if (_client is not null && IsTokenExpiringSoon())
        {
            _logger.LogInformation("Token expiring soon (expires at {ExpiresOn}), triggering reconnection", _tokenExpiresOn);
            await ReconnectAsync(ct).ConfigureAwait(false);
        }

        // Fast path: return existing healthy connection
        if (_client is not null)
        {
            return _client;
        }

        await _connectionLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            // Double-check after acquiring lock (token might have been refreshed)
            if (_client is not null && !IsTokenExpiringSoon())
            {
                return _client;
            }
            
            // Close existing client if token is expiring
            if (_client is not null)
            {
                _logger.LogInformation("Closing existing MCP client for token refresh");
                await _client.DisposeAsync().ConfigureAwait(false);
                _client = null;
            }

            _client = await CreateClientAsync(ct).ConfigureAwait(false);
            _logger.LogInformation("MCP client connection established, token expires at {ExpiresOn}", _tokenExpiresOn);
            return _client;
        }
        finally
        {
            _connectionLock.Release();
        }
    }
    
    /// <summary>
    /// Checks if the current token is expiring soon and needs refresh.
    /// </summary>
    private bool IsTokenExpiringSoon()
    {
        // If no Entra auth, token never expires
        if (_credential is null)
        {
            return false;
        }
        
        // Check if we're within the refresh buffer of expiration
        return DateTimeOffset.UtcNow >= _tokenExpiresOn - TokenRefreshBuffer;
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
            
            // Increment generation and notify subscribers
            ConnectionGeneration++;
            _logger.LogInformation("MCP connection generation incremented to {Generation}", ConnectionGeneration);
            OnReconnected?.Invoke(this, EventArgs.Empty);
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
        
        // Check for explicit MCP endpoint override (used in Azure deployment)
        var mcpEndpointOverride = _config["McpServer:Endpoint"];
        var mcpEndpoint = !string.IsNullOrEmpty(mcpEndpointOverride) 
            ? new Uri(mcpEndpointOverride) 
            : httpClient.BaseAddress!;
        
        // MCP server uses /sse endpoint for SSE transport (WithHttpTransport() default)
        var mcpUri = new Uri(mcpEndpoint.ToString().TrimEnd('/') + "/sse");
        _logger.LogInformation("Connecting to MCP server at {McpServerUrl}", mcpUri);

        // Build HttpClientTransportOptions with authentication headers if Entra is enabled
        var transportOptions = new HttpClientTransportOptions
        {
            Endpoint = mcpUri,
            Name = "MedicalDbMcpServer",
            // Use SSE mode which is what the MCP server uses with WithHttpTransport()
            TransportMode = HttpTransportMode.Sse
        };

        // Add Bearer token to AdditionalHeaders if Entra authentication is enabled
        if (_credential is not null && !string.IsNullOrEmpty(_entraScope))
        {
            _logger.LogInformation("Acquiring access token for MCP server with scope: {Scope}", _entraScope);
            
            var tokenRequest = new TokenRequestContext([_entraScope]);
            var token = await _credential.GetTokenAsync(tokenRequest, ct).ConfigureAwait(false);
            
            // Track token expiration for automatic refresh
            _tokenExpiresOn = token.ExpiresOn;
            _logger.LogInformation("Acquired access token for MCP server, expires at {ExpiresOn} (in {Minutes:F1} minutes)", 
                token.ExpiresOn, (token.ExpiresOn - DateTimeOffset.UtcNow).TotalMinutes);
            
            // Use AdditionalHeaders for authentication - this is the documented approach
            transportOptions.AdditionalHeaders = new Dictionary<string, string>
            {
                { "Authorization", $"Bearer {token.Token}" }
            };
            
            _logger.LogInformation("Using Entra authentication via AdditionalHeaders");
        }
        else
        {
            // No Entra auth - set expiration far in the future
            _tokenExpiresOn = DateTimeOffset.MaxValue;
        }

        // Use HttpClientTransport with SSE mode
        var transport = new HttpClientTransport(transportOptions);

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
