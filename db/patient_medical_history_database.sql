-- Patients table - core patient information
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Patients')
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
GO

-- Medical conditions/diagnoses
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MedicalConditions')
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
GO

-- Medications
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Medications')
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
GO

-- Allergies
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Allergies')
CREATE TABLE Allergies (
    AllergyId INT PRIMARY KEY IDENTITY(1,1),
    PatientId INT NOT NULL,
    AllergenName NVARCHAR(255) NOT NULL,
    Severity NVARCHAR(50), -- Mild, Moderate, Severe
    Reaction NVARCHAR(500),
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (PatientId) REFERENCES Patients(PatientId)
);
GO

-- Medical visits/appointments
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MedicalVisits')
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
GO

-- Lab results
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'LabResults')
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
GO

-- Indexes for common queries
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_MedicalConditions_PatientId')
CREATE INDEX IX_MedicalConditions_PatientId ON MedicalConditions(PatientId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Medications_PatientId')
CREATE INDEX IX_Medications_PatientId ON Medications(PatientId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Allergies_PatientId')
CREATE INDEX IX_Allergies_PatientId ON Allergies(PatientId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_MedicalVisits_PatientId')
CREATE INDEX IX_MedicalVisits_PatientId ON MedicalVisits(PatientId);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_MedicalVisits_VisitDate')
CREATE INDEX IX_MedicalVisits_VisitDate ON MedicalVisits(VisitDate);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_LabResults_PatientId')
CREATE INDEX IX_LabResults_PatientId ON LabResults(PatientId);
