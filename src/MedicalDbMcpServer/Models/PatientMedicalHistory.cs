namespace MedicalDbMcpServer.Models;

/// <summary>
/// Composite record aggregating all medical history data for a patient.
/// </summary>
public record PatientMedicalHistory(
    Patient Patient,
    IReadOnlyList<MedicalCondition> MedicalConditions,
    IReadOnlyList<Medication> Medications,
    IReadOnlyList<Allergy> Allergies,
    IReadOnlyList<MedicalVisit> MedicalVisits,
    IReadOnlyList<LabResult> LabResults);
