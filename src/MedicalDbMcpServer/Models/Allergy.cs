namespace MedicalDbMcpServer.Models;

/// <summary>
/// Represents an allergy recorded for a patient.
/// </summary>
public record Allergy(
    int AllergyId,
    int PatientId,
    string AllergenName,
    string? Severity,
    string? Reaction,
    DateTime CreatedAt);
