# Coding Standards

## C# .NET

### Naming
- **PascalCase**: classes, methods, properties, public members
- **camelCase**: local variables
- **_camelCase**: private fields
- **I** prefix for interfaces, **T** prefix for generic type parameters

### Code Organization
- One class per file, filename matches class name
- Namespaces match folder structure
- Member order: fields → constructors → properties → methods
- Use file-scoped namespaces

### Async/Await
- Use `async`/`await` for all I/O operations
- Suffix async methods with `Async`
- Avoid `async void` except for event handlers
- Use `ConfigureAwait(false)` in library code

### Null Handling
- Enable nullable reference types
- Use null-conditional operators (`?.`, `??`, `??=`)
- Use `ArgumentNullException.ThrowIfNull()` for validation

### LINQ
- Prefer method syntax for complex queries
- Avoid multiple enumerations
- Prefer `Any()` over `Count() > 0`

### Exception Handling
- Catch specific exceptions, not `Exception`
- Don't swallow exceptions silently
- Include meaningful messages and context

### Dependency Injection
- Use constructor injection for required dependencies
- Prefer interfaces over concrete implementations
- Keep constructors simple (no logic)

### Records & Collections
- Use `record` types for DTOs and value objects
- Use `IReadOnlyList<T>` for immutable return types
- Prefer collection expressions in C# 12+

### Testing
- Follow AAA pattern (Arrange, Act, Assert)
- Naming: `MethodName_Scenario_ExpectedResult`
- Mock external dependencies

### Performance
- Use `Span<T>` and `Memory<T>` for high-performance scenarios
- Use `sealed` on classes that won't be inherited
- Avoid boxing value types

---

## React / TypeScript

### Component Structure
- One component per file, filename matches component name
- Use functional components with hooks
- Keep components small and focused (single responsibility)

### Naming
- **PascalCase**: components, types, interfaces
- **camelCase**: functions, variables, props, hooks
- **use** prefix for custom hooks

### State Management
- Prefer `useState` for local state
- Use `useReducer` for complex state logic
- Lift state only when necessary

### Hooks
- Follow Rules of Hooks (top-level only, React functions only)
- Use `useMemo` and `useCallback` for expensive computations
- Always include proper dependency arrays

### Props
- Define explicit TypeScript interfaces for props
- Use destructuring in function parameters
- Provide default values where appropriate

### Styling
- Use CSS modules or styled-components
- Avoid inline styles except for dynamic values
- Keep styles co-located with components

### Performance
- Use `React.memo` for expensive pure components
- Avoid anonymous functions in JSX when possible
- Use lazy loading for routes and heavy components

### Testing
- Use React Testing Library
- Test behavior, not implementation details
- Mock external dependencies and API calls

---

## SQL

### Naming
- **snake_case** or **PascalCase** consistently for tables and columns
- Singular nouns for table names (e.g., `patient`, not `patients`)
- Prefix views with `vw_`, stored procedures with `sp_`, functions with `fn_`

### Formatting
- UPPERCASE for SQL keywords (`SELECT`, `FROM`, `WHERE`)
- One clause per line for readability
- Indent subqueries and joined tables

### Query Best Practices
- Always specify column names (avoid `SELECT *`)
- Use table aliases for multi-table queries
- Prefer `JOIN` syntax over comma-separated tables
- Use parameterized queries to prevent SQL injection

### Indexing
- Index columns used in `WHERE`, `JOIN`, and `ORDER BY`
- Avoid over-indexing (impacts write performance)
- Use covering indexes for frequently queried columns

### Performance
- Avoid functions on indexed columns in `WHERE` clauses
- Use `EXISTS` instead of `IN` for subqueries when appropriate
- Limit result sets with `TOP` or `OFFSET/FETCH`
- Avoid `SELECT DISTINCT` when possible

### Data Integrity
- Define primary keys on all tables
- Use foreign keys to enforce referential integrity
- Apply appropriate constraints (`NOT NULL`, `CHECK`, `UNIQUE`)

### Transactions
- Use explicit transactions for multi-statement operations
- Keep transactions as short as possible
- Always include error handling with `TRY/CATCH`
