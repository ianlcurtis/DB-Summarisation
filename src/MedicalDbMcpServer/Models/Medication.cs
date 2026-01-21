namespace MedicalDbMcpServer.Models;

/// <summary>
/// Represents a medication prescribed to a patient.
/// </summary>
public record Medication(
    int MedicationId,
    int PatientId,
    string MedicationName,
    string? Dosage,
    string? Frequency,
    DateTime? StartDate,
    DateTime? EndDate,
    string? PrescribedBy,
    bool IsActive,
    DateTime CreatedAt);
