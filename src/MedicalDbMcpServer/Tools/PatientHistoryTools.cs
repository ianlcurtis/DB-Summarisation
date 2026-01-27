// ============================================================================
// MCP (Model Context Protocol) Server - Tool Implementation
// ============================================================================
// 
// What is MCP?
// ------------
// MCP is an open protocol that standardises how AI applications (like GitHub 
// Copilot, Claude Desktop, or custom AI agents) connect to external tools and 
// data sources. It enables AI models to produce more accurate, context-aware 
// responses by giving them access to real-world data.
//
// Architecture Overview:
// ----------------------
// - MCP HOST: The AI application (e.g., VS Code with Copilot, Claude Desktop)
// - MCP CLIENT: Built into the host, connects to MCP servers
// - MCP SERVER: This application - exposes "tools" that the AI can call
//
// How it works:
// 1. The AI host discovers available tools via ListToolsRequest
// 2. When the AI needs data, it sends a CallToolRequest to invoke a tool
// 3. This server processes the request and returns structured data
// 4. The AI uses this data to formulate its response to the user
//
// Reference: https://learn.microsoft.com/en-us/dotnet/ai/get-started-mcp
// ============================================================================

using System.ComponentModel;
using System.Text.Json;
using MedicalDbMcpServer.Data;
using MedicalDbMcpServer.Models;
using Microsoft.Data.SqlClient;
using ModelContextProtocol.Server;  // Official MCP C# SDK from NuGet (ModelContextProtocol package)

namespace MedicalDbMcpServer.Tools;

/// <summary>
/// MCP tools for querying patient medical history.
/// 
/// This class contains methods that are exposed as "tools" to AI clients via MCP.
/// When an AI needs patient information, it can call these tools to retrieve data
/// from the database.
/// </summary>
/// <remarks>
/// The [McpServerToolType] attribute marks this class as containing MCP tool methods.
/// The MCP SDK uses this attribute during tool discovery to find all available tools.
/// When the server starts, it scans for classes with this attribute and registers
/// their [McpServerTool] methods as callable tools.
/// </remarks>
[McpServerToolType]
public sealed class PatientHistoryTools
{
    private readonly IDbConnectionFactory _connectionFactory;
    
    /// <summary>
    /// JSON serialisation options for tool responses.
    /// MCP tools typically return data as JSON strings which the AI can then parse and use.
    /// </summary>
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,                          // Makes the JSON human-readable (helpful for debugging)
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase  // Use camelCase for property names
    };

    /// <summary>
    /// Constructor - dependencies are injected via ASP.NET Core's DI container.
    /// </summary>
    /// <param name="connectionFactory">Factory for creating database connections.</param>
    /// <remarks>
    /// The MCP SDK integrates with ASP.NET Core's dependency injection, so any 
    /// services registered in Program.cs can be injected into tool classes.
    /// </remarks>
    public PatientHistoryTools(IDbConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    /// <summary>
    /// Retrieves the complete medical history for a patient.
    /// </summary>
    /// <param name="patientId">The unique identifier of the patient.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Complete patient medical history as JSON.</returns>
    /// <remarks>
    /// KEY MCP ATTRIBUTES EXPLAINED:
    /// 
    /// [McpServerTool] - Marks this method as an MCP tool that can be invoked by AI clients.
    /// When an AI host sends a CallToolRequest, the MCP SDK routes it to this method.
    /// The method name becomes the tool name (e.g., "GetPatientMedicalHistory").
    /// 
    /// [Description] on the method - This description is sent to the AI during tool discovery
    /// (ListToolsRequest). The AI uses this to understand WHAT the tool does and WHEN to use it.
    /// Write clear, detailed descriptions so the AI knows when this tool is appropriate.
    /// 
    /// [Description] on parameters - Tells the AI what values to provide for each parameter.
    /// The AI will extract these values from the user's natural language query.
    /// For example, if a user asks "Show me patient 5's history", the AI knows to call
    /// this tool with patientId=5.
    /// 
    /// Return type: Tools return strings (usually JSON). The AI parses this data and uses
    /// it to formulate a natural language response to the user.
    /// </remarks>
    [McpServerTool]
    [Description("Retrieves the complete medical history for a patient including demographics, conditions, medications, allergies, visits, and lab results.")]
    public async Task<string> GetPatientMedicalHistory(
        [Description("The unique identifier of the patient")] int patientId,
        CancellationToken cancellationToken = default)
    {
        // Create a database connection using the injected factory
        await using var connection = await _connectionFactory.CreateConnectionAsync(cancellationToken).ConfigureAwait(false);

        // Fetch the patient's basic info first - return early if patient doesn't exist
        var patient = await GetPatientAsync(connection, patientId, cancellationToken).ConfigureAwait(false);
        if (patient is null)
        {
            // Return error as JSON so the AI can inform the user appropriately
            return JsonSerializer.Serialize(new { error = $"Patient with ID {patientId} not found." }, JsonOptions);
        }

        // Fetch all related medical data in parallel (note: passing null for dates means no filtering)
        var conditions = await GetMedicalConditionsAsync(connection, patientId, null, null, cancellationToken).ConfigureAwait(false);
        var medications = await GetMedicationsAsync(connection, patientId, null, null, cancellationToken).ConfigureAwait(false);
        var allergies = await GetAllergiesAsync(connection, patientId, cancellationToken).ConfigureAwait(false);
        var visits = await GetMedicalVisitsAsync(connection, patientId, null, null, cancellationToken).ConfigureAwait(false);
        var labResults = await GetLabResultsAsync(connection, patientId, null, null, cancellationToken).ConfigureAwait(false);

        // Combine all data into a single response object and serialise to JSON
        // The AI will receive this JSON and use it to answer the user's question
        var history = new PatientMedicalHistory(patient, conditions, medications, allergies, visits, labResults);
        return JsonSerializer.Serialize(history, JsonOptions);
    }

    /// <summary>
    /// Retrieves patient medical history filtered by date range.
    /// </summary>
    /// <param name="patientId">The unique identifier of the patient.</param>
    /// <param name="startDate">Start date of the range (inclusive).</param>
    /// <param name="endDate">End date of the range (inclusive).</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Filtered patient medical history as JSON.</returns>
    /// <remarks>
    /// This is a second MCP tool - you can have multiple tools in one class.
    /// Each [McpServerTool] method becomes a separate tool the AI can call.
    /// 
    /// The AI will choose between tools based on the user's query:
    /// - "Show me patient 5's full history" → GetPatientMedicalHistory
    /// - "What happened to patient 5 in 2024?" → GetPatientMedicalHistoryBetweenDates
    /// 
    /// The [Description] attributes help the AI understand these differences.
    /// </remarks>
    [McpServerTool]
    [Description("Retrieves patient medical history filtered by date range. Filters visits by VisitDate, conditions by DiagnosisDate, medications by StartDate, and lab results by TestDate.")]
    public async Task<string> GetPatientMedicalHistoryBetweenDates(
        [Description("The unique identifier of the patient")] int patientId,
        [Description("Start date of the range (inclusive) in ISO 8601 format (e.g., 2024-01-01)")] DateTime startDate,
        [Description("End date of the range (inclusive) in ISO 8601 format (e.g., 2024-12-31)")] DateTime endDate,
        CancellationToken cancellationToken = default)
    {
        await using var connection = await _connectionFactory.CreateConnectionAsync(cancellationToken).ConfigureAwait(false);

        var patient = await GetPatientAsync(connection, patientId, cancellationToken).ConfigureAwait(false);
        if (patient is null)
        {
            return JsonSerializer.Serialize(new { error = $"Patient with ID {patientId} not found." }, JsonOptions);
        }

        var conditions = await GetMedicalConditionsAsync(connection, patientId, startDate, endDate, cancellationToken).ConfigureAwait(false);
        var medications = await GetMedicationsAsync(connection, patientId, startDate, endDate, cancellationToken).ConfigureAwait(false);
        var allergies = await GetAllergiesAsync(connection, patientId, cancellationToken).ConfigureAwait(false);
        var visits = await GetMedicalVisitsAsync(connection, patientId, startDate, endDate, cancellationToken).ConfigureAwait(false);
        var labResults = await GetLabResultsAsync(connection, patientId, startDate, endDate, cancellationToken).ConfigureAwait(false);

        var history = new PatientMedicalHistory(patient, conditions, medications, allergies, visits, labResults);
        return JsonSerializer.Serialize(history, JsonOptions);
    }

    private static async Task<Patient?> GetPatientAsync(SqlConnection connection, int patientId, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT PatientId, FirstName, LastName, DateOfBirth, Gender, Email, Phone, 
                   Address, EmergencyContactName, EmergencyContactPhone, CreatedAt, UpdatedAt
            FROM Patients
            WHERE PatientId = @PatientId
            """;

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@PatientId", patientId);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            return null;
        }

        return new Patient(
            PatientId: reader.GetInt32(0),
            FirstName: reader.GetString(1),
            LastName: reader.GetString(2),
            DateOfBirth: reader.GetDateTime(3),
            Gender: reader.IsDBNull(4) ? null : reader.GetString(4),
            Email: reader.IsDBNull(5) ? null : reader.GetString(5),
            Phone: reader.IsDBNull(6) ? null : reader.GetString(6),
            Address: reader.IsDBNull(7) ? null : reader.GetString(7),
            EmergencyContactName: reader.IsDBNull(8) ? null : reader.GetString(8),
            EmergencyContactPhone: reader.IsDBNull(9) ? null : reader.GetString(9),
            CreatedAt: reader.GetDateTime(10),
            UpdatedAt: reader.GetDateTime(11));
    }

    private static async Task<IReadOnlyList<MedicalCondition>> GetMedicalConditionsAsync(
        SqlConnection connection, int patientId, DateTime? startDate, DateTime? endDate, CancellationToken cancellationToken)
    {
        var sql = """
            SELECT ConditionId, PatientId, ConditionName, DiagnosisDate, Status, Notes, CreatedAt
            FROM MedicalConditions
            WHERE PatientId = @PatientId
            """;

        if (startDate.HasValue && endDate.HasValue)
        {
            sql += " AND DiagnosisDate >= @StartDate AND DiagnosisDate <= @EndDate";
        }

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@PatientId", patientId);
        if (startDate.HasValue && endDate.HasValue)
        {
            command.Parameters.AddWithValue("@StartDate", startDate.Value);
            command.Parameters.AddWithValue("@EndDate", endDate.Value);
        }

        var conditions = new List<MedicalCondition>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            conditions.Add(new MedicalCondition(
                ConditionId: reader.GetInt32(0),
                PatientId: reader.GetInt32(1),
                ConditionName: reader.GetString(2),
                DiagnosisDate: reader.IsDBNull(3) ? null : reader.GetDateTime(3),
                Status: reader.IsDBNull(4) ? null : reader.GetString(4),
                Notes: reader.IsDBNull(5) ? null : reader.GetString(5),
                CreatedAt: reader.GetDateTime(6)));
        }

        return conditions;
    }

    private static async Task<IReadOnlyList<Medication>> GetMedicationsAsync(
        SqlConnection connection, int patientId, DateTime? startDate, DateTime? endDate, CancellationToken cancellationToken)
    {
        var sql = """
            SELECT MedicationId, PatientId, MedicationName, Dosage, Frequency, StartDate, 
                   EndDate, PrescribedBy, IsActive, CreatedAt
            FROM Medications
            WHERE PatientId = @PatientId
            """;

        if (startDate.HasValue && endDate.HasValue)
        {
            sql += " AND StartDate >= @StartDate AND StartDate <= @EndDate";
        }

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@PatientId", patientId);
        if (startDate.HasValue && endDate.HasValue)
        {
            command.Parameters.AddWithValue("@StartDate", startDate.Value);
            command.Parameters.AddWithValue("@EndDate", endDate.Value);
        }

        var medications = new List<Medication>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            medications.Add(new Medication(
                MedicationId: reader.GetInt32(0),
                PatientId: reader.GetInt32(1),
                MedicationName: reader.GetString(2),
                Dosage: reader.IsDBNull(3) ? null : reader.GetString(3),
                Frequency: reader.IsDBNull(4) ? null : reader.GetString(4),
                StartDate: reader.IsDBNull(5) ? null : reader.GetDateTime(5),
                EndDate: reader.IsDBNull(6) ? null : reader.GetDateTime(6),
                PrescribedBy: reader.IsDBNull(7) ? null : reader.GetString(7),
                IsActive: reader.GetBoolean(8),
                CreatedAt: reader.GetDateTime(9)));
        }

        return medications;
    }

    private static async Task<IReadOnlyList<Allergy>> GetAllergiesAsync(
        SqlConnection connection, int patientId, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT AllergyId, PatientId, AllergenName, Severity, Reaction, CreatedAt
            FROM Allergies
            WHERE PatientId = @PatientId
            """;

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@PatientId", patientId);

        var allergies = new List<Allergy>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            allergies.Add(new Allergy(
                AllergyId: reader.GetInt32(0),
                PatientId: reader.GetInt32(1),
                AllergenName: reader.GetString(2),
                Severity: reader.IsDBNull(3) ? null : reader.GetString(3),
                Reaction: reader.IsDBNull(4) ? null : reader.GetString(4),
                CreatedAt: reader.GetDateTime(5)));
        }

        return allergies;
    }

    private static async Task<IReadOnlyList<MedicalVisit>> GetMedicalVisitsAsync(
        SqlConnection connection, int patientId, DateTime? startDate, DateTime? endDate, CancellationToken cancellationToken)
    {
        var sql = """
            SELECT VisitId, PatientId, VisitDate, ProviderName, VisitType, ChiefComplaint, 
                   Diagnosis, TreatmentPlan, Notes, CreatedAt
            FROM MedicalVisits
            WHERE PatientId = @PatientId
            """;

        if (startDate.HasValue && endDate.HasValue)
        {
            sql += " AND VisitDate >= @StartDate AND VisitDate <= @EndDate";
        }

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@PatientId", patientId);
        if (startDate.HasValue && endDate.HasValue)
        {
            command.Parameters.AddWithValue("@StartDate", startDate.Value);
            command.Parameters.AddWithValue("@EndDate", endDate.Value);
        }

        var visits = new List<MedicalVisit>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            visits.Add(new MedicalVisit(
                VisitId: reader.GetInt32(0),
                PatientId: reader.GetInt32(1),
                VisitDate: reader.GetDateTime(2),
                ProviderName: reader.IsDBNull(3) ? null : reader.GetString(3),
                VisitType: reader.IsDBNull(4) ? null : reader.GetString(4),
                ChiefComplaint: reader.IsDBNull(5) ? null : reader.GetString(5),
                Diagnosis: reader.IsDBNull(6) ? null : reader.GetString(6),
                TreatmentPlan: reader.IsDBNull(7) ? null : reader.GetString(7),
                Notes: reader.IsDBNull(8) ? null : reader.GetString(8),
                CreatedAt: reader.GetDateTime(9)));
        }

        return visits;
    }

    private static async Task<IReadOnlyList<LabResult>> GetLabResultsAsync(
        SqlConnection connection, int patientId, DateTime? startDate, DateTime? endDate, CancellationToken cancellationToken)
    {
        var sql = """
            SELECT LabResultId, PatientId, VisitId, TestName, TestDate, ResultValue, 
                   Unit, ReferenceRange, IsAbnormal, Notes, CreatedAt
            FROM LabResults
            WHERE PatientId = @PatientId
            """;

        if (startDate.HasValue && endDate.HasValue)
        {
            sql += " AND TestDate >= @StartDate AND TestDate <= @EndDate";
        }

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@PatientId", patientId);
        if (startDate.HasValue && endDate.HasValue)
        {
            command.Parameters.AddWithValue("@StartDate", startDate.Value);
            command.Parameters.AddWithValue("@EndDate", endDate.Value);
        }

        var results = new List<LabResult>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
        {
            results.Add(new LabResult(
                LabResultId: reader.GetInt32(0),
                PatientId: reader.GetInt32(1),
                VisitId: reader.IsDBNull(2) ? null : reader.GetInt32(2),
                TestName: reader.GetString(3),
                TestDate: reader.GetDateTime(4),
                ResultValue: reader.IsDBNull(5) ? null : reader.GetString(5),
                Unit: reader.IsDBNull(6) ? null : reader.GetString(6),
                ReferenceRange: reader.IsDBNull(7) ? null : reader.GetString(7),
                IsAbnormal: reader.GetBoolean(8),
                Notes: reader.IsDBNull(9) ? null : reader.GetString(9),
                CreatedAt: reader.GetDateTime(10)));
        }

        return results;
    }
}
