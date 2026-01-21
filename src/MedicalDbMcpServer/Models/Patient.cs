namespace MedicalDbMcpServer.Models;

/// <summary>
/// Represents a patient's core demographic information.
/// </summary>
public record Patient(
    int PatientId,
    string FirstName,
    string LastName,
    DateTime DateOfBirth,
    string? Gender,
    string? Email,
    string? Phone,
    string? Address,
    string? EmergencyContactName,
    string? EmergencyContactPhone,
    DateTime CreatedAt,
    DateTime UpdatedAt);
