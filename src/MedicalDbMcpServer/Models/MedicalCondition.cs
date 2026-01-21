namespace MedicalDbMcpServer.Models;

/// <summary>
/// Represents a medical condition or diagnosis for a patient.
/// </summary>
public record MedicalCondition(
    int ConditionId,
    int PatientId,
    string ConditionName,
    DateTime? DiagnosisDate,
    string? Status,
    string? Notes,
    DateTime CreatedAt);
