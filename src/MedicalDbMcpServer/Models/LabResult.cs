namespace MedicalDbMcpServer.Models;

/// <summary>
/// Represents a laboratory test result for a patient.
/// </summary>
public record LabResult(
    int LabResultId,
    int PatientId,
    int? VisitId,
    string TestName,
    DateTime TestDate,
    string? ResultValue,
    string? Unit,
    string? ReferenceRange,
    bool IsAbnormal,
    string? Notes,
    DateTime CreatedAt);
