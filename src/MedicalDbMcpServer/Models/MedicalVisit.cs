namespace MedicalDbMcpServer.Models;

/// <summary>
/// Represents a medical visit or appointment for a patient.
/// </summary>
public record MedicalVisit(
    int VisitId,
    int PatientId,
    DateTime VisitDate,
    string? ProviderName,
    string? VisitType,
    string? ChiefComplaint,
    string? Diagnosis,
    string? TreatmentPlan,
    string? Notes,
    DateTime CreatedAt);
