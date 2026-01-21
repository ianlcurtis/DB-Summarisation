# C# .NET Coding Standards

## Naming Conventions

- **PascalCase** for class names, method names, properties, and public members
- **camelCase** for local variables and private fields
- **_camelCase** (underscore prefix) for private fields
- **IPascalCase** (I prefix) for interfaces
- **TPascalCase** (T prefix) for generic type parameters
- Use meaningful, descriptive names that reveal intent

```csharp
public class CustomerService
{
    private readonly ILogger _logger;
    private int _retryCount;

    public string CustomerName { get; set; }

    public async Task<Customer> GetCustomerAsync(int customerId)
    {
        var customer = await _repository.FindAsync(customerId);
        return customer;
    }
}
```

## Code Organization

- One class per file
- File name should match the class name
- Organize namespaces to match folder structure
- Order class members: fields, constructors, properties, methods
- Group related methods together

## Async/Await

- Use `async`/`await` for all I/O-bound operations
- Suffix async methods with `Async`
- Prefer `Task<T>` over `Task` when returning values
- Avoid `async void` except for event handlers
- Use `ConfigureAwait(false)` in library code

```csharp
public async Task<Data> FetchDataAsync(CancellationToken cancellationToken = default)
{
    var response = await _httpClient.GetAsync(url, cancellationToken).ConfigureAwait(false);
    return await response.Content.ReadFromJsonAsync<Data>(cancellationToken).ConfigureAwait(false);
}
```

## Null Handling

- Enable nullable reference types (`<Nullable>enable</Nullable>`)
- Use null-conditional operators (`?.`, `??`, `??=`)
- Prefer pattern matching for null checks
- Use `ArgumentNullException.ThrowIfNull()` for parameter validation

```csharp
public void ProcessOrder(Order? order)
{
    ArgumentNullException.ThrowIfNull(order);
    
    var customerName = order.Customer?.Name ?? "Unknown";
}
```

## LINQ Best Practices

- Prefer method syntax for complex queries
- Use meaningful variable names in lambda expressions
- Avoid multiple enumerations (use `.ToList()` or `.ToArray()` when needed)
- Prefer `Any()` over `Count() > 0`

```csharp
var activeCustomers = customers
    .Where(customer => customer.IsActive)
    .OrderBy(customer => customer.LastName)
    .Select(customer => new CustomerDto(customer.Id, customer.FullName))
    .ToList();
```

## Exception Handling

- Catch specific exceptions, not `Exception`
- Use exception filters when appropriate
- Don't swallow exceptions silently
- Include meaningful messages and context
- Use custom exceptions for domain-specific errors

```csharp
try
{
    await ProcessPaymentAsync(payment);
}
catch (PaymentGatewayException ex) when (ex.IsRetryable)
{
    _logger.LogWarning(ex, "Retryable payment error for order {OrderId}", orderId);
    throw new PaymentProcessingException($"Payment failed for order {orderId}", ex);
}
```

## Dependency Injection

- Use constructor injection for required dependencies
- Register services with appropriate lifetimes (Singleton, Scoped, Transient)
- Prefer interfaces over concrete implementations
- Keep constructors simple (no logic)

```csharp
public class OrderService : IOrderService
{
    private readonly IOrderRepository _orderRepository;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository orderRepository, ILogger<OrderService> logger)
    {
        _orderRepository = orderRepository;
        _logger = logger;
    }
}
```

## Records and Immutability

- Use `record` types for DTOs and value objects
- Prefer immutable objects where possible
- Use `init` setters for properties that should only be set during initialization
- Use `required` modifier for mandatory properties

```csharp
public record CustomerDto(int Id, string Name, string Email);

public record CreateOrderRequest
{
    public required int CustomerId { get; init; }
    public required List<OrderItem> Items { get; init; }
}
```

## Collections

- Use `IReadOnlyList<T>` or `IReadOnlyCollection<T>` for return types when collection shouldn't be modified
- Use `List<T>` internally, expose as `IEnumerable<T>` or read-only interfaces
- Prefer collection expressions (`[]`) in C# 12+
- Initialize collections with capacity when size is known

```csharp
public IReadOnlyList<Product> GetProducts()
{
    List<Product> products = new(expectedCount);
    // populate...
    return products;
}

// C# 12+
int[] numbers = [1, 2, 3, 4, 5];
```

## String Handling

- Use string interpolation over concatenation
- Use `StringBuilder` for multiple string operations
- Use `StringComparison` for comparisons
- Prefer `string.IsNullOrEmpty()` or `string.IsNullOrWhiteSpace()`

```csharp
var message = $"Hello, {customer.Name}! Your order #{orderId} is ready.";

if (string.Equals(input, expected, StringComparison.OrdinalIgnoreCase))
{
    // ...
}
```

## Documentation

- Use XML documentation comments for public APIs
- Document exceptions that can be thrown
- Include examples for complex methods
- Keep comments up-to-date with code changes

```csharp
/// <summary>
/// Retrieves a customer by their unique identifier.
/// </summary>
/// <param name="customerId">The unique identifier of the customer.</param>
/// <returns>The customer if found; otherwise, null.</returns>
/// <exception cref="ArgumentOutOfRangeException">Thrown when customerId is less than 1.</exception>
public async Task<Customer?> GetCustomerByIdAsync(int customerId)
```

## Testing

- Follow AAA pattern (Arrange, Act, Assert)
- Use descriptive test names: `MethodName_Scenario_ExpectedResult`
- One assertion per test when practical
- Use `FluentAssertions` for readable assertions
- Mock external dependencies

```csharp
[Fact]
public async Task GetCustomerByIdAsync_WithValidId_ReturnsCustomer()
{
    // Arrange
    var expectedCustomer = new Customer { Id = 1, Name = "John" };
    _mockRepository.Setup(r => r.GetByIdAsync(1)).ReturnsAsync(expectedCustomer);

    // Act
    var result = await _sut.GetCustomerByIdAsync(1);

    // Assert
    result.Should().BeEquivalentTo(expectedCustomer);
}
```

## Performance Considerations

- Use `Span<T>` and `Memory<T>` for high-performance scenarios
- Prefer `ValueTask<T>` for hot paths that often complete synchronously
- Use object pooling for frequently allocated objects
- Avoid boxing value types
- Use `sealed` on classes that won't be inherited

## File-Scoped Namespaces

Use file-scoped namespaces to reduce indentation:

```csharp
namespace MyProject.Services;

public class CustomerService
{
    // ...
}
```

## Project Structure

```
/src
  /ProjectName.Api          # API/Web layer
  /ProjectName.Core         # Domain/Business logic
  /ProjectName.Infrastructure   # Data access, external services
/tests
  /ProjectName.UnitTests
  /ProjectName.IntegrationTests
```
