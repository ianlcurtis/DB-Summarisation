-- Patients table - core patient information
CREATE TABLE Patients (
    PatientId INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Gender NVARCHAR(20),
    Email NVARCHAR(255),
    Phone NVARCHAR(20),
    Address NVARCHAR(500),
    EmergencyContactName NVARCHAR(200),
    EmergencyContactPhone NVARCHAR(20),
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    UpdatedAt DATETIME2 DEFAULT GETDATE()
);

-- Medical conditions/diagnoses
CREATE TABLE MedicalConditions (
    ConditionId INT PRIMARY KEY IDENTITY(1,1),
    PatientId INT NOT NULL,
    ConditionName NVARCHAR(255) NOT NULL,
    DiagnosisDate DATE,
    Status NVARCHAR(50) DEFAULT 'Active', -- Active, Resolved, Chronic
    Notes NVARCHAR(MAX),
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (PatientId) REFERENCES Patients(PatientId)
);

-- Medications
CREATE TABLE Medications (
    MedicationId INT PRIMARY KEY IDENTITY(1,1),
    PatientId INT NOT NULL,
    MedicationName NVARCHAR(255) NOT NULL,
    Dosage NVARCHAR(100),
    Frequency NVARCHAR(100),
    StartDate DATE,
    EndDate DATE,
    PrescribedBy NVARCHAR(200),
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (PatientId) REFERENCES Patients(PatientId)
);

-- Allergies
CREATE TABLE Allergies (
    AllergyId INT PRIMARY KEY IDENTITY(1,1),
    PatientId INT NOT NULL,
    AllergenName NVARCHAR(255) NOT NULL,
    Severity NVARCHAR(50), -- Mild, Moderate, Severe
    Reaction NVARCHAR(500),
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (PatientId) REFERENCES Patients(PatientId)
);

-- Medical visits/appointments
CREATE TABLE MedicalVisits (
    VisitId INT PRIMARY KEY IDENTITY(1,1),
    PatientId INT NOT NULL,
    VisitDate DATETIME2 NOT NULL,
    ProviderName NVARCHAR(200),
    VisitType NVARCHAR(100), -- Routine, Emergency, Follow-up, Specialist
    ChiefComplaint NVARCHAR(500),
    Diagnosis NVARCHAR(MAX),
    TreatmentPlan NVARCHAR(MAX),
    Notes NVARCHAR(MAX),
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (PatientId) REFERENCES Patients(PatientId)
);

-- Lab results
CREATE TABLE LabResults (
    LabResultId INT PRIMARY KEY IDENTITY(1,1),
    PatientId INT NOT NULL,
    VisitId INT,
    TestName NVARCHAR(255) NOT NULL,
    TestDate DATE NOT NULL,
    ResultValue NVARCHAR(100),
    Unit NVARCHAR(50),
    ReferenceRange NVARCHAR(100),
    IsAbnormal BIT DEFAULT 0,
    Notes NVARCHAR(MAX),
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (PatientId) REFERENCES Patients(PatientId),
    FOREIGN KEY (VisitId) REFERENCES MedicalVisits(VisitId)
);

-- Indexes for common queries
CREATE INDEX IX_MedicalConditions_PatientId ON MedicalConditions(PatientId);
CREATE INDEX IX_Medications_PatientId ON Medications(PatientId);
CREATE INDEX IX_Allergies_PatientId ON Allergies(PatientId);
CREATE INDEX IX_MedicalVisits_PatientId ON MedicalVisits(PatientId);
CREATE INDEX IX_MedicalVisits_VisitDate ON MedicalVisits(VisitDate);
CREATE INDEX IX_LabResults_PatientId ON LabResults(PatientId);

-- ============================================
-- Create Read-Only SQL Login and User for MCP Server
-- ============================================

-- Create login at server level (run this part with sysadmin privileges)
-- Note: Change the password to a secure value in production
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'mcp_readonly_user')
BEGIN
    CREATE LOGIN mcp_readonly_user WITH PASSWORD = 'YourSecurePassword123!';
END
GO

-- Create user in the database mapped to the login
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'mcp_readonly_user')
BEGIN
    CREATE USER mcp_readonly_user FOR LOGIN mcp_readonly_user;
END
GO

-- Grant SELECT-only permissions on all tables
GRANT SELECT ON Patients TO mcp_readonly_user;
GRANT SELECT ON MedicalConditions TO mcp_readonly_user;
GRANT SELECT ON Medications TO mcp_readonly_user;
GRANT SELECT ON Allergies TO mcp_readonly_user;
GRANT SELECT ON MedicalVisits TO mcp_readonly_user;
GRANT SELECT ON LabResults TO mcp_readonly_user;
GO

-- Explicitly deny INSERT, UPDATE, DELETE to ensure read-only access
DENY INSERT, UPDATE, DELETE ON Patients TO mcp_readonly_user;
DENY INSERT, UPDATE, DELETE ON MedicalConditions TO mcp_readonly_user;
DENY INSERT, UPDATE, DELETE ON Medications TO mcp_readonly_user;
DENY INSERT, UPDATE, DELETE ON Allergies TO mcp_readonly_user;
DENY INSERT, UPDATE, DELETE ON MedicalVisits TO mcp_readonly_user;
DENY INSERT, UPDATE, DELETE ON LabResults TO mcp_readonly_user;
GO
