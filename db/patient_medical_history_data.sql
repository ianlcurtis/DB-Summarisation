-- Synthetic Medical Data for Patient Medical History Database
-- Generated for testing and development purposes

-- ============================================
-- Insert Patients
-- ============================================
SET IDENTITY_INSERT Patients ON;

INSERT INTO Patients (PatientId, FirstName, LastName, DateOfBirth, Gender, Email, Phone, Address, EmergencyContactName, EmergencyContactPhone)
VALUES
(1, 'Emily', 'Johnson', '1985-03-15', 'Female', 'emily.johnson@email.com', '020 7946 0101', '42 Victoria Road, Islington, London N1 9BE', 'Michael Johnson', '020 7946 0102'),
(2, 'James', 'Williams', '1972-08-22', 'Male', 'james.williams@email.com', '0161 496 0103', '15 Deansgate, Manchester M3 2BA', 'Sarah Williams', '0161 496 0104'),
(3, 'Maria', 'Garcia', '1990-11-30', 'Female', 'maria.garcia@email.com', '0121 496 0105', '78 Broad Street, Birmingham B1 2HF', 'Carlos Garcia', '0121 496 0106'),
(4, 'Robert', 'Brown', '1968-05-10', 'Male', 'robert.brown@email.com', '0113 496 0107', '23 Briggate, Leeds LS1 6HD', 'Linda Brown', '0113 496 0108'),
(5, 'Jennifer', 'Davis', '1995-01-25', 'Female', 'jennifer.davis@email.com', '0117 496 0109', '56 Park Street, Bristol BS1 5JN', 'Thomas Davis', '0117 496 0110'),
(6, 'William', 'Martinez', '1982-07-18', 'Male', 'william.martinez@email.com', '0151 496 0111', '89 Bold Street, Liverpool L1 4HY', 'Ana Martinez', '0151 496 0112'),
(7, 'Patricia', 'Anderson', '1978-12-03', 'Female', 'patricia.anderson@email.com', '0131 496 0113', '34 Princes Street, Edinburgh EH2 2BY', 'David Anderson', '0131 496 0114'),
(8, 'Michael', 'Taylor', '1955-09-08', 'Male', 'michael.taylor@email.com', '029 2049 0115', '12 St Mary Street, Cardiff CF10 1AT', 'Elizabeth Taylor', '029 2049 0116'),
(9, 'Linda', 'Thomas', '1988-04-20', 'Female', 'linda.thomas@email.com', '0141 496 0117', '67 Buchanan Street, Glasgow G1 3HL', 'Richard Thomas', '0141 496 0118'),
(10, 'David', 'Jackson', '1963-02-14', 'Male', 'david.jackson@email.com', '0191 496 0119', '45 Grey Street, Newcastle upon Tyne NE1 6EE', 'Mary Jackson', '0191 496 0120'),
(11, 'Susan', 'White', '1992-06-28', 'Female', 'susan.white@email.com', '01865 496121', '28 High Street, Oxford OX1 4AP', 'John White', '01865 496122'),
(12, 'Charles', 'Harris', '1975-10-12', 'Male', 'charles.harris@email.com', '01223 496123', '91 King Street, Cambridge CB1 1LN', 'Nancy Harris', '01223 496124');

SET IDENTITY_INSERT Patients OFF;

-- ============================================
-- Insert Medical Conditions
-- ============================================
SET IDENTITY_INSERT MedicalConditions ON;

INSERT INTO MedicalConditions (ConditionId, PatientId, ConditionName, DiagnosisDate, Status, Notes)
VALUES
-- Patient 1: Emily Johnson
(1, 1, 'Asthma', '2010-05-20', 'Chronic', 'Mild persistent asthma, triggered by exercise and allergens'),
(2, 1, 'Seasonal Allergic Rhinitis', '2008-03-15', 'Active', 'Symptoms worsen in spring and fall'),

-- Patient 2: James Williams
(3, 2, 'Type 2 Diabetes Mellitus', '2015-08-10', 'Chronic', 'Well-controlled with medication and diet'),
(4, 2, 'Hypertension', '2014-02-28', 'Chronic', 'Stage 1 hypertension, on ACE inhibitor'),
(5, 2, 'Hyperlipidemia', '2016-01-15', 'Active', 'Elevated LDL cholesterol'),

-- Patient 3: Maria Garcia
(6, 3, 'Migraine without Aura', '2018-09-05', 'Chronic', 'Approximately 3-4 episodes per month'),
(7, 3, 'Iron Deficiency Anemia', '2022-04-12', 'Resolved', 'Resolved after iron supplementation'),

-- Patient 4: Robert Brown
(8, 4, 'Coronary Artery Disease', '2019-11-20', 'Chronic', 'History of NSTEMI, two stents placed'),
(9, 4, 'Type 2 Diabetes Mellitus', '2010-03-08', 'Chronic', 'On insulin therapy'),
(10, 4, 'Chronic Kidney Disease Stage 3', '2021-06-15', 'Chronic', 'eGFR 45 mL/min'),
(11, 4, 'Hypertension', '2005-07-22', 'Chronic', 'On multiple antihypertensives'),

-- Patient 5: Jennifer Davis
(12, 5, 'Generalized Anxiety Disorder', '2020-01-10', 'Active', 'Managed with therapy and medication'),
(13, 5, 'Irritable Bowel Syndrome', '2019-06-25', 'Chronic', 'IBS-D subtype, diet-controlled'),

-- Patient 6: William Martinez
(14, 6, 'Gout', '2021-03-18', 'Chronic', 'Primarily affects right big toe'),
(15, 6, 'Obesity', '2018-02-01', 'Active', 'BMI 34.2, working on weight loss'),

-- Patient 7: Patricia Anderson
(16, 7, 'Hypothyroidism', '2012-08-30', 'Chronic', 'Hashimoto thyroiditis, on levothyroxine'),
(17, 7, 'Osteoarthritis', '2020-11-05', 'Chronic', 'Bilateral knee involvement'),
(18, 7, 'Depression', '2015-04-20', 'Active', 'Major depressive disorder, recurrent'),

-- Patient 8: Michael Taylor
(19, 8, 'Atrial Fibrillation', '2018-07-12', 'Chronic', 'Persistent AFib, on anticoagulation'),
(20, 8, 'Heart Failure', '2020-02-28', 'Chronic', 'HFrEF, EF 35%'),
(21, 8, 'COPD', '2015-09-10', 'Chronic', 'GOLD Stage 2, former smoker'),
(22, 8, 'Benign Prostatic Hyperplasia', '2017-01-25', 'Active', 'Moderate symptoms, on tamsulosin'),

-- Patient 9: Linda Thomas
(23, 9, 'Polycystic Ovary Syndrome', '2016-05-08', 'Chronic', 'Managed with oral contraceptives'),
(24, 9, 'Acne Vulgaris', '2014-03-15', 'Resolved', 'Resolved with treatment'),

-- Patient 10: David Jackson
(25, 10, 'Parkinson Disease', '2021-08-20', 'Chronic', 'Early stage, tremor-dominant'),
(26, 10, 'Hypertension', '2008-11-12', 'Chronic', 'Well-controlled'),
(27, 10, 'Gastroesophageal Reflux Disease', '2015-06-30', 'Active', 'On PPI therapy'),

-- Patient 11: Susan White
(28, 11, 'Celiac Disease', '2019-02-14', 'Chronic', 'Strict gluten-free diet'),
(29, 11, 'Vitamin D Deficiency', '2020-10-05', 'Active', 'On supplementation'),

-- Patient 12: Charles Harris
(30, 12, 'Sleep Apnea', '2020-05-22', 'Chronic', 'Moderate OSA, using CPAP'),
(31, 12, 'Hypertension', '2017-09-15', 'Chronic', 'On lisinopril'),
(32, 12, 'Pre-diabetes', '2022-01-10', 'Active', 'HbA1c 6.2%, lifestyle modifications');

SET IDENTITY_INSERT MedicalConditions OFF;

-- ============================================
-- Insert Medications
-- ============================================
SET IDENTITY_INSERT Medications ON;

INSERT INTO Medications (MedicationId, PatientId, MedicationName, Dosage, Frequency, StartDate, EndDate, PrescribedBy, IsActive)
VALUES
-- Patient 1: Emily Johnson
(1, 1, 'Albuterol Inhaler', '90 mcg', '2 puffs as needed', '2010-05-20', NULL, 'Dr. Sarah Mitchell', 1),
(2, 1, 'Fluticasone Nasal Spray', '50 mcg', 'Once daily', '2015-03-01', NULL, 'Dr. Sarah Mitchell', 1),
(3, 1, 'Cetirizine', '10 mg', 'Once daily', '2018-04-10', NULL, 'Dr. Sarah Mitchell', 1),

-- Patient 2: James Williams
(4, 2, 'Metformin', '1000 mg', 'Twice daily', '2015-08-15', NULL, 'Dr. Robert Chen', 1),
(5, 2, 'Lisinopril', '20 mg', 'Once daily', '2014-03-01', NULL, 'Dr. Robert Chen', 1),
(6, 2, 'Atorvastatin', '40 mg', 'Once daily at bedtime', '2016-02-01', NULL, 'Dr. Robert Chen', 1),
(7, 2, 'Aspirin', '81 mg', 'Once daily', '2015-09-01', NULL, 'Dr. Robert Chen', 1),

-- Patient 3: Maria Garcia
(8, 3, 'Sumatriptan', '50 mg', 'As needed for migraine', '2018-09-10', NULL, 'Dr. Amanda Peters', 1),
(9, 3, 'Topiramate', '50 mg', 'Once daily', '2020-02-15', NULL, 'Dr. Amanda Peters', 1),
(10, 3, 'Ferrous Sulfate', '325 mg', 'Once daily', '2022-04-15', '2022-10-15', 'Dr. Amanda Peters', 0),

-- Patient 4: Robert Brown
(11, 4, 'Aspirin', '81 mg', 'Once daily', '2019-12-01', NULL, 'Dr. James Wilson', 1),
(12, 4, 'Clopidogrel', '75 mg', 'Once daily', '2019-12-01', NULL, 'Dr. James Wilson', 1),
(13, 4, 'Metoprolol Succinate', '100 mg', 'Once daily', '2019-12-01', NULL, 'Dr. James Wilson', 1),
(14, 4, 'Lisinopril', '40 mg', 'Once daily', '2010-03-15', NULL, 'Dr. James Wilson', 1),
(15, 4, 'Atorvastatin', '80 mg', 'Once daily at bedtime', '2019-12-01', NULL, 'Dr. James Wilson', 1),
(16, 4, 'Insulin Glargine', '30 units', 'Once daily at bedtime', '2018-05-01', NULL, 'Dr. Robert Chen', 1),
(17, 4, 'Insulin Lispro', '10-15 units', 'With meals', '2018-05-01', NULL, 'Dr. Robert Chen', 1),

-- Patient 5: Jennifer Davis
(18, 5, 'Escitalopram', '10 mg', 'Once daily', '2020-01-15', NULL, 'Dr. Lisa Thompson', 1),
(19, 5, 'Dicyclomine', '20 mg', 'As needed', '2019-07-01', NULL, 'Dr. Amanda Peters', 1),

-- Patient 6: William Martinez
(20, 6, 'Allopurinol', '300 mg', 'Once daily', '2021-04-01', NULL, 'Dr. Robert Chen', 1),
(21, 6, 'Colchicine', '0.6 mg', 'As needed for flares', '2021-03-20', NULL, 'Dr. Robert Chen', 1),
(22, 6, 'Phentermine', '37.5 mg', 'Once daily', '2023-01-15', '2023-04-15', 'Dr. Robert Chen', 0),

-- Patient 7: Patricia Anderson
(23, 7, 'Levothyroxine', '100 mcg', 'Once daily on empty stomach', '2012-09-01', NULL, 'Dr. Sarah Mitchell', 1),
(24, 7, 'Sertraline', '100 mg', 'Once daily', '2015-05-01', NULL, 'Dr. Lisa Thompson', 1),
(25, 7, 'Acetaminophen', '650 mg', 'As needed for pain', '2020-11-10', NULL, 'Dr. Sarah Mitchell', 1),
(26, 7, 'Meloxicam', '15 mg', 'Once daily', '2021-02-01', NULL, 'Dr. Sarah Mitchell', 1),

-- Patient 8: Michael Taylor
(27, 8, 'Apixaban', '5 mg', 'Twice daily', '2018-07-20', NULL, 'Dr. James Wilson', 1),
(28, 8, 'Carvedilol', '25 mg', 'Twice daily', '2020-03-01', NULL, 'Dr. James Wilson', 1),
(29, 8, 'Furosemide', '40 mg', 'Once daily', '2020-03-01', NULL, 'Dr. James Wilson', 1),
(30, 8, 'Lisinopril', '10 mg', 'Once daily', '2020-03-01', NULL, 'Dr. James Wilson', 1),
(31, 8, 'Tiotropium', '18 mcg', 'Once daily inhaled', '2015-09-15', NULL, 'Dr. Sarah Mitchell', 1),
(32, 8, 'Tamsulosin', '0.4 mg', 'Once daily', '2017-02-01', NULL, 'Dr. David Lee', 1),

-- Patient 9: Linda Thomas
(33, 9, 'Norethindrone/Ethinyl Estradiol', '1 mg/35 mcg', 'Once daily', '2016-06-01', NULL, 'Dr. Jennifer Adams', 1),
(34, 9, 'Spironolactone', '50 mg', 'Once daily', '2017-01-15', NULL, 'Dr. Jennifer Adams', 1),

-- Patient 10: David Jackson
(35, 10, 'Carbidopa-Levodopa', '25/100 mg', 'Three times daily', '2021-08-25', NULL, 'Dr. Michael Brown', 1),
(36, 10, 'Amlodipine', '10 mg', 'Once daily', '2010-01-15', NULL, 'Dr. Robert Chen', 1),
(37, 10, 'Omeprazole', '20 mg', 'Once daily before breakfast', '2015-07-01', NULL, 'Dr. Robert Chen', 1),

-- Patient 11: Susan White
(38, 11, 'Vitamin D3', '2000 IU', 'Once daily', '2020-10-10', NULL, 'Dr. Sarah Mitchell', 1),
(39, 11, 'Calcium Carbonate', '500 mg', 'Twice daily', '2020-10-10', NULL, 'Dr. Sarah Mitchell', 1),

-- Patient 12: Charles Harris
(40, 12, 'Lisinopril', '10 mg', 'Once daily', '2017-09-20', NULL, 'Dr. Robert Chen', 1);

SET IDENTITY_INSERT Medications OFF;

-- ============================================
-- Insert Allergies
-- ============================================
SET IDENTITY_INSERT Allergies ON;

INSERT INTO Allergies (AllergyId, PatientId, AllergenName, Severity, Reaction)
VALUES
(1, 1, 'Penicillin', 'Severe', 'Anaphylaxis - requires epinephrine'),
(2, 1, 'Shellfish', 'Moderate', 'Hives and facial swelling'),
(3, 2, 'Sulfa Drugs', 'Moderate', 'Skin rash'),
(4, 3, 'Latex', 'Mild', 'Contact dermatitis'),
(5, 4, 'Codeine', 'Moderate', 'Nausea and severe itching'),
(6, 4, 'Iodine Contrast', 'Severe', 'Anaphylactoid reaction'),
(7, 5, 'Peanuts', 'Severe', 'Anaphylaxis - carries EpiPen'),
(8, 6, 'Aspirin', 'Mild', 'Gastric upset'),
(9, 7, 'Morphine', 'Moderate', 'Severe nausea and hallucinations'),
(10, 8, 'ACE Inhibitors', 'Moderate', 'Angioedema'),
(11, 9, 'Amoxicillin', 'Mild', 'Mild rash'),
(12, 10, 'NSAIDs', 'Moderate', 'Gastric bleeding'),
(13, 11, 'Gluten', 'Severe', 'Celiac disease - autoimmune reaction'),
(14, 12, 'Bee Stings', 'Severe', 'Anaphylaxis');

SET IDENTITY_INSERT Allergies OFF;

-- ============================================
-- Insert Medical Visits
-- ============================================
SET IDENTITY_INSERT MedicalVisits ON;

INSERT INTO MedicalVisits (VisitId, PatientId, VisitDate, ProviderName, VisitType, ChiefComplaint, Diagnosis, TreatmentPlan, Notes)
VALUES
-- Patient 1: Emily Johnson
(1, 1, '2024-01-15 09:00:00', 'Dr. Sarah Mitchell', 'Routine', 'Annual physical examination', 'Healthy adult, asthma well-controlled', 'Continue current medications, return in 1 year', 'Patient reports good exercise tolerance'),
(2, 1, '2024-06-20 14:30:00', 'Dr. Sarah Mitchell', 'Follow-up', 'Increased asthma symptoms', 'Asthma exacerbation due to seasonal allergies', 'Increase inhaler use, add montelukast temporarily', 'Triggered by high pollen count'),
(3, 1, '2025-01-10 10:00:00', 'Dr. Sarah Mitchell', 'Routine', 'Annual wellness visit', 'Stable asthma, no new concerns', 'Continue current regimen', 'Discussed flu and COVID vaccination'),

-- Patient 2: James Williams
(4, 2, '2024-02-08 11:00:00', 'Dr. Robert Chen', 'Routine', 'Diabetes follow-up', 'Type 2 DM - good control, HbA1c 6.8%', 'Continue current medications', 'Patient adhering well to diet'),
(5, 2, '2024-08-15 09:30:00', 'Dr. Robert Chen', 'Follow-up', 'Quarterly diabetes check', 'Diabetes well-controlled, BP slightly elevated', 'Increase lisinopril to 20mg, recheck in 3 months', 'Discussed importance of sodium restriction'),
(6, 2, '2025-01-05 10:00:00', 'Dr. Robert Chen', 'Routine', 'Quarterly check-up', 'Stable diabetes and hypertension', 'Continue medications, labs in 3 months', 'HbA1c 6.9%, BP 128/82'),

-- Patient 3: Maria Garcia
(7, 3, '2024-03-12 15:00:00', 'Dr. Amanda Peters', 'Specialist', 'Frequent migraines', 'Chronic migraine, frequency increased', 'Start topiramate prophylaxis, continue sumatriptan PRN', 'Keeping headache diary'),
(8, 3, '2024-09-25 11:00:00', 'Dr. Amanda Peters', 'Follow-up', 'Migraine follow-up', 'Migraine frequency improved with prophylaxis', 'Continue current regimen', 'Reduced from 8 to 3 migraines per month'),

-- Patient 4: Robert Brown
(9, 4, '2024-01-22 08:00:00', 'Dr. James Wilson', 'Follow-up', 'Cardiology follow-up', 'Stable CAD post-PCI, HFpEF stable', 'Continue current cardiac medications', 'Echo shows EF 55%, no new wall motion abnormalities'),
(10, 4, '2024-04-18 09:00:00', 'Dr. Robert Chen', 'Routine', 'Diabetes and kidney check', 'DM with stable CKD stage 3', 'Optimize blood sugar control, monitor kidney function', 'Creatinine stable at 1.8'),
(11, 4, '2024-07-30 14:00:00', 'Dr. James Wilson', 'Emergency', 'Chest pain', 'Unstable angina, ruled out MI', 'Admit for observation, adjust medications', 'Troponins negative, stress test positive'),
(12, 4, '2024-10-15 10:00:00', 'Dr. James Wilson', 'Follow-up', 'Post-hospitalization follow-up', 'Stable post medical management', 'Continue medications, cardiac rehab referral', 'Patient enrolled in cardiac rehab program'),

-- Patient 5: Jennifer Davis
(13, 5, '2024-02-28 13:00:00', 'Dr. Lisa Thompson', 'Specialist', 'Anxiety symptoms worsening', 'Generalized anxiety disorder, moderate', 'Increase escitalopram, continue therapy', 'Referred to cognitive behavioral therapy'),
(14, 5, '2024-08-05 10:30:00', 'Dr. Lisa Thompson', 'Follow-up', 'Mental health follow-up', 'Anxiety improved with treatment', 'Continue current medications', 'Patient reports significant improvement'),
(15, 5, '2024-11-20 14:00:00', 'Dr. Amanda Peters', 'Follow-up', 'IBS symptoms', 'IBS flare, likely stress-related', 'Dietary modifications, probiotics', 'Correlates with work stress'),

-- Patient 6: William Martinez
(16, 6, '2024-03-20 09:00:00', 'Dr. Robert Chen', 'Routine', 'Gout and weight management', 'Gout controlled, obesity management', 'Continue allopurinol, discuss weight loss options', 'Patient interested in weight loss program'),
(17, 6, '2024-09-10 11:00:00', 'Dr. Robert Chen', 'Follow-up', 'Weight management follow-up', 'Weight reduced by 15 lbs, gout stable', 'Continue lifestyle modifications', 'BMI improved to 32.5'),

-- Patient 7: Patricia Anderson
(18, 7, '2024-04-05 10:00:00', 'Dr. Sarah Mitchell', 'Routine', 'Thyroid and joint pain check', 'Hypothyroidism well-controlled, OA progression', 'Continue levothyroxine, add meloxicam for OA', 'TSH normal, knee X-ray shows moderate OA'),
(19, 7, '2024-06-15 14:00:00', 'Dr. Lisa Thompson', 'Specialist', 'Depression worsening', 'Major depression, recurrent episode', 'Increase sertraline, add therapy sessions', 'Patient reports low mood and poor sleep'),
(20, 7, '2024-12-01 09:30:00', 'Dr. Sarah Mitchell', 'Follow-up', 'General follow-up', 'All conditions stable', 'Continue current medications', 'Mood improved, joint pain manageable'),

-- Patient 8: Michael Taylor
(21, 8, '2024-01-30 08:30:00', 'Dr. James Wilson', 'Follow-up', 'Heart failure check', 'HFrEF stable, no fluid overload', 'Continue current regimen', 'Weight stable, no edema'),
(22, 8, '2024-05-22 10:00:00', 'Dr. Sarah Mitchell', 'Follow-up', 'COPD follow-up', 'COPD stable, no exacerbations', 'Continue tiotropium, reinforce smoking cessation', 'PFTs stable from last year'),
(23, 8, '2024-09-08 15:00:00', 'Dr. James Wilson', 'Emergency', 'Shortness of breath', 'Heart failure exacerbation', 'Increase diuretics, low sodium diet', 'Admitted for 3 days, fluid removed'),
(24, 8, '2024-11-15 09:00:00', 'Dr. James Wilson', 'Follow-up', 'Post-discharge follow-up', 'Heart failure improved post-diuresis', 'Maintain current medications, strict fluid restriction', 'Stable, weight at dry weight'),

-- Patient 9: Linda Thomas
(25, 9, '2024-03-08 11:00:00', 'Dr. Jennifer Adams', 'Routine', 'Annual gynecology visit', 'PCOS stable on current treatment', 'Continue oral contraceptives', 'Regular cycles, no concerning symptoms'),
(26, 9, '2024-10-22 10:00:00', 'Dr. Jennifer Adams', 'Follow-up', 'Contraception follow-up', 'PCOS well-controlled', 'Continue current regimen', 'BP normal, no side effects from OCP'),

-- Patient 10: David Jackson
(27, 10, '2024-02-14 09:00:00', 'Dr. Michael Brown', 'Specialist', 'Parkinson follow-up', 'Parkinson disease, early stage stable', 'Continue carbidopa-levodopa', 'Tremor controlled, no freezing'),
(28, 10, '2024-07-10 14:00:00', 'Dr. Michael Brown', 'Follow-up', 'Neurology follow-up', 'PD progressing slowly', 'May need dose adjustment soon', 'Slight increase in tremor noted'),
(29, 10, '2024-12-18 10:30:00', 'Dr. Robert Chen', 'Routine', 'Annual physical', 'Stable PD, HTN, and GERD', 'Continue all medications', 'Comprehensive metabolic panel normal'),

-- Patient 11: Susan White
(30, 11, '2024-04-25 13:00:00', 'Dr. Sarah Mitchell', 'Follow-up', 'Celiac disease check', 'Celiac disease in remission on GF diet', 'Continue strict gluten-free diet', 'tTG-IgA normalized'),
(31, 11, '2024-11-08 09:00:00', 'Dr. Sarah Mitchell', 'Routine', 'Annual wellness', 'Stable celiac, vitamin D improving', 'Continue supplements', 'Vitamin D level now 35 ng/mL'),

-- Patient 12: Charles Harris
(32, 12, '2024-05-15 08:00:00', 'Dr. Robert Chen', 'Follow-up', 'Sleep apnea and metabolic check', 'OSA controlled with CPAP, pre-diabetes stable', 'Continue CPAP, lifestyle modifications', 'CPAP compliance 85%, HbA1c 6.1%'),
(33, 12, '2024-10-30 10:00:00', 'Dr. Robert Chen', 'Routine', 'Quarterly check-up', 'All conditions stable', 'Continue current management', 'Lost 10 lbs, BP well-controlled');

SET IDENTITY_INSERT MedicalVisits OFF;

-- ============================================
-- Insert Lab Results
-- ============================================
SET IDENTITY_INSERT LabResults ON;

INSERT INTO LabResults (LabResultId, PatientId, VisitId, TestName, TestDate, ResultValue, Unit, ReferenceRange, IsAbnormal, Notes)
VALUES
-- Patient 1: Emily Johnson
(1, 1, 1, 'Complete Blood Count', '2024-01-15', 'Normal', NULL, NULL, 0, 'All values within normal limits'),
(2, 1, 1, 'Basic Metabolic Panel', '2024-01-15', 'Normal', NULL, NULL, 0, 'Electrolytes and kidney function normal'),
(3, 1, 3, 'Hemoglobin A1c', '2025-01-10', '5.4', '%', '4.0-5.6%', 0, 'Normal glucose metabolism'),

-- Patient 2: James Williams
(4, 2, 4, 'Hemoglobin A1c', '2024-02-08', '6.8', '%', '4.0-5.6%', 1, 'Diabetic, but well-controlled'),
(5, 2, 4, 'Fasting Glucose', '2024-02-08', '128', 'mg/dL', '70-100 mg/dL', 1, 'Elevated, consistent with diabetes'),
(6, 2, 4, 'LDL Cholesterol', '2024-02-08', '95', 'mg/dL', '<100 mg/dL', 0, 'At goal on statin'),
(7, 2, 4, 'Creatinine', '2024-02-08', '1.1', 'mg/dL', '0.7-1.3 mg/dL', 0, 'Normal kidney function'),
(8, 2, 6, 'Hemoglobin A1c', '2025-01-05', '6.9', '%', '4.0-5.6%', 1, 'Slightly elevated from last visit'),
(9, 2, 6, 'Lipid Panel', '2025-01-05', 'Optimal', NULL, NULL, 0, 'Total cholesterol 165, LDL 88'),

-- Patient 3: Maria Garcia
(10, 3, 7, 'Complete Blood Count', '2024-03-12', 'Normal', NULL, NULL, 0, 'No anemia currently'),
(11, 3, 7, 'Ferritin', '2024-03-12', '45', 'ng/mL', '12-150 ng/mL', 0, 'Iron stores replenished'),

-- Patient 4: Robert Brown
(12, 4, 9, 'BNP', '2024-01-22', '180', 'pg/mL', '<100 pg/mL', 1, 'Mildly elevated, stable from baseline'),
(13, 4, 9, 'Troponin I', '2024-01-22', '<0.01', 'ng/mL', '<0.04 ng/mL', 0, 'No acute myocardial injury'),
(14, 4, 10, 'Hemoglobin A1c', '2024-04-18', '7.8', '%', '4.0-5.6%', 1, 'Suboptimal control'),
(15, 4, 10, 'Creatinine', '2024-04-18', '1.8', 'mg/dL', '0.7-1.3 mg/dL', 1, 'CKD stage 3, stable'),
(16, 4, 10, 'eGFR', '2024-04-18', '45', 'mL/min/1.73m2', '>60 mL/min/1.73m2', 1, 'Consistent with CKD stage 3'),
(17, 4, 11, 'Troponin I', '2024-07-30', '0.02', 'ng/mL', '<0.04 ng/mL', 0, 'No evidence of MI'),
(18, 4, 11, 'Troponin I (6h)', '2024-07-30', '0.03', 'ng/mL', '<0.04 ng/mL', 0, 'Stable, no rise'),

-- Patient 5: Jennifer Davis
(19, 5, 13, 'TSH', '2024-02-28', '2.1', 'mIU/L', '0.4-4.0 mIU/L', 0, 'Thyroid function normal'),
(20, 5, 13, 'Vitamin B12', '2024-02-28', '450', 'pg/mL', '200-900 pg/mL', 0, 'Normal'),

-- Patient 6: William Martinez
(21, 6, 16, 'Uric Acid', '2024-03-20', '5.8', 'mg/dL', '3.5-7.2 mg/dL', 0, 'Well-controlled on allopurinol'),
(22, 6, 16, 'Fasting Glucose', '2024-03-20', '98', 'mg/dL', '70-100 mg/dL', 0, 'Normal'),
(23, 6, 17, 'Lipid Panel', '2024-09-10', 'Improved', NULL, NULL, 0, 'LDL 118, improved with weight loss'),

-- Patient 7: Patricia Anderson
(24, 7, 18, 'TSH', '2024-04-05', '1.8', 'mIU/L', '0.4-4.0 mIU/L', 0, 'Well-controlled on levothyroxine'),
(25, 7, 18, 'Free T4', '2024-04-05', '1.2', 'ng/dL', '0.8-1.8 ng/dL', 0, 'Normal'),
(26, 7, 20, 'Vitamin D', '2024-12-01', '32', 'ng/mL', '30-100 ng/mL', 0, 'Adequate'),

-- Patient 8: Michael Taylor
(27, 8, 21, 'BNP', '2024-01-30', '450', 'pg/mL', '<100 pg/mL', 1, 'Elevated, baseline for HFrEF'),
(28, 8, 21, 'Creatinine', '2024-01-30', '1.4', 'mg/dL', '0.7-1.3 mg/dL', 1, 'Mildly elevated'),
(29, 8, 22, 'Pulmonary Function Test', '2024-05-22', 'FEV1 65%', '% predicted', '>80%', 1, 'Consistent with moderate COPD'),
(30, 8, 23, 'BNP', '2024-09-08', '890', 'pg/mL', '<100 pg/mL', 1, 'Elevated during exacerbation'),
(31, 8, 24, 'BNP', '2024-11-15', '380', 'pg/mL', '<100 pg/mL', 1, 'Improved after diuresis'),

-- Patient 9: Linda Thomas
(32, 9, 25, 'LH/FSH Ratio', '2024-03-08', '2.5', 'ratio', '<2', 1, 'Consistent with PCOS'),
(33, 9, 25, 'Testosterone, Total', '2024-03-08', '58', 'ng/dL', '15-70 ng/dL', 0, 'Upper normal, improved from baseline'),

-- Patient 10: David Jackson
(34, 10, 27, 'Complete Blood Count', '2024-02-14', 'Normal', NULL, NULL, 0, 'All values normal'),
(35, 10, 29, 'Basic Metabolic Panel', '2024-12-18', 'Normal', NULL, NULL, 0, 'Electrolytes and kidney function normal'),
(36, 10, 29, 'Lipid Panel', '2024-12-18', 'Borderline', NULL, NULL, 0, 'LDL 125, consider statin'),

-- Patient 11: Susan White
(37, 11, 30, 'tTG-IgA', '2024-04-25', '8', 'U/mL', '<20 U/mL', 0, 'Normalized on gluten-free diet'),
(38, 11, 30, 'Vitamin D', '2024-04-25', '28', 'ng/mL', '30-100 ng/mL', 1, 'Slightly low, increase supplementation'),
(39, 11, 31, 'Vitamin D', '2024-11-08', '35', 'ng/mL', '30-100 ng/mL', 0, 'Improved with supplementation'),
(40, 11, 31, 'Complete Blood Count', '2024-11-08', 'Normal', NULL, NULL, 0, 'No nutritional deficiencies'),

-- Patient 12: Charles Harris
(41, 12, 32, 'Hemoglobin A1c', '2024-05-15', '6.1', '%', '4.0-5.6%', 1, 'Pre-diabetes range'),
(42, 12, 32, 'Fasting Glucose', '2024-05-15', '108', 'mg/dL', '70-100 mg/dL', 1, 'Impaired fasting glucose'),
(43, 12, 33, 'Hemoglobin A1c', '2024-10-30', '5.9', '%', '4.0-5.6%', 1, 'Improved with lifestyle changes'),
(44, 12, 33, 'Lipid Panel', '2024-10-30', 'Optimal', NULL, NULL, 0, 'Total cholesterol 175, LDL 98');

SET IDENTITY_INSERT LabResults OFF;

-- ============================================
-- Verification Queries (Optional - Comment out for production)
-- ============================================
-- SELECT 'Patients' AS TableName, COUNT(*) AS RecordCount FROM Patients
-- UNION ALL SELECT 'MedicalConditions', COUNT(*) FROM MedicalConditions
-- UNION ALL SELECT 'Medications', COUNT(*) FROM Medications
-- UNION ALL SELECT 'Allergies', COUNT(*) FROM Allergies
-- UNION ALL SELECT 'MedicalVisits', COUNT(*) FROM MedicalVisits
-- UNION ALL SELECT 'LabResults', COUNT(*) FROM LabResults;
