-- =============================================================================
-- Hospital360 Demo: Seed Dimension Tables with Synthetic Data
-- =============================================================================
-- Run as: SYSADMIN on H360_LOAD_WH
-- Prerequisite: 06_dimensions.sql executed (tables exist, empty)
-- Scale: Demo (10%) — 25K patients, 200 providers, 5 facilities, 30 depts
-- =============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE H360_LOAD_WH;

-- =============================================================================
-- 1. DIM_DATE — 3-year date spine (2023-01-01 to 2025-12-31)
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.CLINICAL.DIM_DATE;

INSERT INTO HOSPITAL360_CUR.CLINICAL.DIM_DATE
WITH date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2023-01-01'::DATE) AS d
    FROM TABLE(GENERATOR(ROWCOUNT => 1096))  -- 3 years
)
SELECT
    YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d) AS DATE_KEY,
    d AS FULL_DATE,
    YEAR(d) AS YEAR,
    QUARTER(d) AS QUARTER,
    MONTH(d) AS MONTH,
    MONTHNAME(d) AS MONTH_NAME,
    DAY(d) AS DAY_OF_MONTH,
    DAYOFWEEK(d) AS DAY_OF_WEEK,
    DAYNAME(d) AS DAY_NAME,
    WEEKOFYEAR(d) AS WEEK_OF_YEAR,
    -- Fiscal year starts July 1
    CASE WHEN MONTH(d) >= 7 THEN YEAR(d) + 1 ELSE YEAR(d) END AS FISCAL_YEAR,
    CASE
        WHEN MONTH(d) IN (7,8,9)   THEN 1
        WHEN MONTH(d) IN (10,11,12) THEN 2
        WHEN MONTH(d) IN (1,2,3)   THEN 3
        ELSE 4
    END AS FISCAL_QUARTER,
    DAYOFWEEK(d) IN (0, 6) AS IS_WEEKEND,
    -- Major US holidays (simplified)
    CASE
        WHEN MONTH(d) = 1  AND DAY(d) = 1  THEN TRUE   -- New Year's
        WHEN MONTH(d) = 7  AND DAY(d) = 4  THEN TRUE   -- Independence Day
        WHEN MONTH(d) = 12 AND DAY(d) = 25 THEN TRUE   -- Christmas
        WHEN MONTH(d) = 11 AND DAYOFWEEK(d) = 4 AND DAY(d) BETWEEN 22 AND 28 THEN TRUE  -- Thanksgiving
        WHEN MONTH(d) = 9  AND DAYOFWEEK(d) = 1 AND DAY(d) <= 7 THEN TRUE  -- Labor Day
        WHEN MONTH(d) = 5  AND DAYOFWEEK(d) = 1 AND DAY(d) >= 25 THEN TRUE -- Memorial Day
        ELSE FALSE
    END AS IS_HOLIDAY,
    CASE
        WHEN MONTH(d) = 1  AND DAY(d) = 1  THEN 'New Year''s Day'
        WHEN MONTH(d) = 7  AND DAY(d) = 4  THEN 'Independence Day'
        WHEN MONTH(d) = 12 AND DAY(d) = 25 THEN 'Christmas Day'
        WHEN MONTH(d) = 11 AND DAYOFWEEK(d) = 4 AND DAY(d) BETWEEN 22 AND 28 THEN 'Thanksgiving'
        WHEN MONTH(d) = 9  AND DAYOFWEEK(d) = 1 AND DAY(d) <= 7 THEN 'Labor Day'
        WHEN MONTH(d) = 5  AND DAYOFWEEK(d) = 1 AND DAY(d) >= 25 THEN 'Memorial Day'
        ELSE NULL
    END AS HOLIDAY_NAME
FROM date_spine
WHERE d <= '2025-12-31';

-- =============================================================================
-- 2. DIM_FACILITY — 5 facilities
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.OPERATIONS.DIM_FACILITY;

INSERT INTO HOSPITAL360_CUR.OPERATIONS.DIM_FACILITY
    (FACILITY_ID, FACILITY_NAME, FACILITY_TYPE, ADDRESS, CITY, STATE, ZIP, LATITUDE, LONGITUDE, BED_COUNT, OR_ROOM_COUNT, IS_OWNED, OPENED_DATE)
VALUES
    ('FAC-001', 'Emerald City Medical Center', 'HOSPITAL',    '1200 Main St',      'Seattle',  'WA', '98101', 47.6062, -122.3321, 450, 18, TRUE,  '1985-06-15'),
    ('FAC-002', 'Northgate Community Hospital','COMMUNITY',   '9500 Aurora Ave N',  'Seattle',  'WA', '98103', 47.7084, -122.3448, 120,  6, TRUE,  '2002-03-01'),
    ('FAC-003', 'Eastside Community Hospital', 'COMMUNITY',   '2000 116th Ave NE',  'Bellevue', 'WA', '98004', 47.6101, -122.2015, 150,  8, TRUE,  '1998-09-10'),
    ('FAC-004', 'Cascade Rehabilitation Center','REHAB',      '500 Rainier Ave S',  'Renton',   'WA', '98057', 47.4799, -122.2034,  80,  0, TRUE,  '2010-01-20'),
    ('FAC-005', 'Pacific Surgery Center',      'ASC',         '3300 Pacific Ave',   'Tacoma',   'WA', '98402', 47.2529, -122.4443,   0, 10, FALSE, '2015-07-01');

-- =============================================================================
-- 3. DIM_DEPARTMENT — 30 departments across facilities
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.OPERATIONS.DIM_DEPARTMENT;

INSERT INTO HOSPITAL360_CUR.OPERATIONS.DIM_DEPARTMENT
    (DEPT_ID, DEPT_NAME, DEPT_TYPE, FACILITY_ID, COST_CENTER, BED_COUNT, TARGET_OCCUPANCY, MANAGER_NAME, IS_ACTIVE)
VALUES
    -- Emerald City Medical Center (FAC-001) — main hospital
    ('DEPT-001', 'Emergency Department',      'ED',         'FAC-001', 'CC-1010', 30,  0.70, 'Sarah Chen',       TRUE),
    ('DEPT-002', 'Medical ICU',               'ICU',        'FAC-001', 'CC-1020', 24,  0.85, 'James Rivera',     TRUE),
    ('DEPT-003', 'Surgical ICU',              'ICU',        'FAC-001', 'CC-1025', 18,  0.80, 'Maria Santos',     TRUE),
    ('DEPT-004', 'Med-Surg 4 North',          'INPATIENT',  'FAC-001', 'CC-1030', 40,  0.88, 'David Kim',        TRUE),
    ('DEPT-005', 'Med-Surg 4 South',          'INPATIENT',  'FAC-001', 'CC-1035', 40,  0.88, 'Lisa Johnson',     TRUE),
    ('DEPT-006', 'Cardiology',                'INPATIENT',  'FAC-001', 'CC-1040', 32,  0.82, 'Robert Patel',     TRUE),
    ('DEPT-007', 'Orthopedics',               'INPATIENT',  'FAC-001', 'CC-1050', 28,  0.80, 'Jennifer Wu',      TRUE),
    ('DEPT-008', 'Oncology',                  'INPATIENT',  'FAC-001', 'CC-1060', 24,  0.75, 'Michael Brown',    TRUE),
    ('DEPT-009', 'Labor & Delivery',          'INPATIENT',  'FAC-001', 'CC-1070', 20,  0.65, 'Amanda Garcia',    TRUE),
    ('DEPT-010', 'NICU',                      'ICU',        'FAC-001', 'CC-1075', 16,  0.70, 'Daniel Lee',       TRUE),
    ('DEPT-011', 'Operating Room',            'OR',         'FAC-001', 'CC-1080', NULL,0.75, 'Patricia Nguyen',  TRUE),
    ('DEPT-012', 'Radiology',                 'ANCILLARY',  'FAC-001', 'CC-1090', NULL,NULL, 'Thomas Wilson',    TRUE),
    ('DEPT-013', 'Laboratory',                'ANCILLARY',  'FAC-001', 'CC-1095', NULL,NULL, 'Karen Martinez',   TRUE),
    ('DEPT-014', 'Pharmacy',                  'ANCILLARY',  'FAC-001', 'CC-1100', NULL,NULL, 'Brian Thompson',   TRUE),
    ('DEPT-015', 'Physical Therapy',          'OUTPATIENT', 'FAC-001', 'CC-1110', NULL,NULL, 'Susan Davis',      TRUE),
    ('DEPT-016', 'Neurology',                 'INPATIENT',  'FAC-001', 'CC-1120', 20,  0.78, 'Christopher Almeida', TRUE),
    ('DEPT-017', 'Pulmonology',               'INPATIENT',  'FAC-001', 'CC-1130', 18,  0.80, 'Emily Chang',      TRUE),
    -- Northgate Community Hospital (FAC-002)
    ('DEPT-018', 'ED - Northgate',            'ED',         'FAC-002', 'CC-2010', 15,  0.65, 'Ryan Mitchell',    TRUE),
    ('DEPT-019', 'Med-Surg - Northgate',      'INPATIENT',  'FAC-002', 'CC-2020', 50,  0.85, 'Nicole Harris',    TRUE),
    ('DEPT-020', 'ICU - Northgate',           'ICU',        'FAC-002', 'CC-2030', 12,  0.80, 'Kevin Robinson',   TRUE),
    ('DEPT-021', 'OR - Northgate',            'OR',         'FAC-002', 'CC-2040', NULL,0.70, 'Stephanie Clark',  TRUE),
    ('DEPT-022', 'Womens Health - Northgate', 'OUTPATIENT', 'FAC-002', 'CC-2050', NULL,NULL, 'Andrew Lewis',     TRUE),
    -- Eastside Community Hospital (FAC-003)
    ('DEPT-023', 'ED - Eastside',             'ED',         'FAC-003', 'CC-3010', 18,  0.68, 'Laura Ramirez',    TRUE),
    ('DEPT-024', 'Med-Surg - Eastside',       'INPATIENT',  'FAC-003', 'CC-3020', 60,  0.87, 'Mark Taylor',      TRUE),
    ('DEPT-025', 'ICU - Eastside',            'ICU',        'FAC-003', 'CC-3030', 14,  0.82, 'Heather Young',    TRUE),
    ('DEPT-026', 'OR - Eastside',             'OR',         'FAC-003', 'CC-3040', NULL,0.72, 'Jason Walker',     TRUE),
    -- Cascade Rehabilitation (FAC-004)
    ('DEPT-027', 'Inpatient Rehab',           'INPATIENT',  'FAC-004', 'CC-4010', 40,  0.75, 'Michelle Allen',   TRUE),
    ('DEPT-028', 'Outpatient Rehab',          'OUTPATIENT', 'FAC-004', 'CC-4020', NULL,NULL, 'Gregory King',     TRUE),
    -- Pacific Surgery Center (FAC-005)
    ('DEPT-029', 'OR - Pacific ASC',          'OR',         'FAC-005', 'CC-5010', NULL,0.80, 'Donna Wright',     TRUE),
    ('DEPT-030', 'Pre/Post Op - Pacific',     'OUTPATIENT', 'FAC-005', 'CC-5020', 12,  0.60, 'Paul Scott',       TRUE);

-- =============================================================================
-- 4. DIM_PAYER — 15 payers (80/20 commercial/govt mix)
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.FINANCIAL.DIM_PAYER;

INSERT INTO HOSPITAL360_CUR.FINANCIAL.DIM_PAYER
    (PAYER_ID, PAYER_NAME, PAYER_TYPE, PLAN_NAME, IS_IN_NETWORK, CONTRACT_RATE_PCT, TIMELY_FILING_DAYS)
VALUES
    ('PAY-001', 'Medicare Part A',            'MEDICARE',     'Medicare Traditional',    TRUE,  0.35, 365),
    ('PAY-002', 'Medicare Advantage - UHC',   'MEDICARE',     'UHC Medicare Advantage',  TRUE,  0.40, 180),
    ('PAY-003', 'Medicaid - WA Apple Health', 'MEDICAID',     'Apple Health',            TRUE,  0.28, 365),
    ('PAY-004', 'Premera Blue Cross',         'COMMERCIAL',   'PPO Gold',                TRUE,  0.55, 90),
    ('PAY-005', 'Regence Blue Shield',        'COMMERCIAL',   'PPO Standard',            TRUE,  0.52, 90),
    ('PAY-006', 'UnitedHealthcare',           'COMMERCIAL',   'Choice Plus',             TRUE,  0.50, 90),
    ('PAY-007', 'Aetna',                      'COMMERCIAL',   'Open Access',             TRUE,  0.48, 120),
    ('PAY-008', 'Cigna',                      'COMMERCIAL',   'Open Access Plus',        TRUE,  0.47, 90),
    ('PAY-009', 'Molina Healthcare',          'MEDICAID',     'Molina Medicaid',         TRUE,  0.30, 180),
    ('PAY-010', 'Kaiser Permanente',          'COMMERCIAL',   'HMO',                     FALSE, 0.42, 90),
    ('PAY-011', 'Humana',                     'COMMERCIAL',   'PPO',                     TRUE,  0.45, 120),
    ('PAY-012', 'TriCare',                    'GOVERNMENT',   'TriCare Prime',           TRUE,  0.38, 365),
    ('PAY-013', 'Workers Comp - WA L&I',      'WORKERS_COMP', 'WA State Fund',           TRUE,  0.60, 365),
    ('PAY-014', 'Self-Pay',                   'SELF_PAY',     NULL,                      FALSE, 1.00, NULL),
    ('PAY-015', 'Coordinated Care',           'MEDICAID',     'Coordinated Care Health', TRUE,  0.30, 180);

-- =============================================================================
-- 5. DIM_DIAGNOSIS_ICD10 — 200 common ICD-10 codes
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.CLINICAL.DIM_DIAGNOSIS_ICD10;

INSERT INTO HOSPITAL360_CUR.CLINICAL.DIM_DIAGNOSIS_ICD10
    (ICD10_CODE, DESCRIPTION, CHAPTER, CHAPTER_DESC, CATEGORY, IS_CHRONIC, HCC_FLAG, HCC_CATEGORY)
VALUES
    -- Circulatory (Chapter IX)
    ('I10',    'Essential hypertension',                        'IX',  'Circulatory',    'I10-I16',  TRUE,  TRUE,  'HCC19'),
    ('I21.0',  'STEMI of anterior wall',                        'IX',  'Circulatory',    'I20-I25',  FALSE, TRUE,  'HCC86'),
    ('I21.1',  'STEMI of inferior wall',                        'IX',  'Circulatory',    'I20-I25',  FALSE, TRUE,  'HCC86'),
    ('I25.10', 'Atherosclerotic heart disease',                 'IX',  'Circulatory',    'I20-I25',  TRUE,  TRUE,  'HCC86'),
    ('I48.0',  'Paroxysmal atrial fibrillation',                'IX',  'Circulatory',    'I30-I52',  TRUE,  TRUE,  'HCC96'),
    ('I48.91', 'Unspecified atrial fibrillation',               'IX',  'Circulatory',    'I30-I52',  TRUE,  TRUE,  'HCC96'),
    ('I50.9',  'Heart failure, unspecified',                    'IX',  'Circulatory',    'I30-I52',  TRUE,  TRUE,  'HCC85'),
    ('I50.20', 'Systolic heart failure, unspecified',           'IX',  'Circulatory',    'I30-I52',  TRUE,  TRUE,  'HCC85'),
    ('I63.9',  'Cerebral infarction, unspecified',              'IX',  'Circulatory',    'I60-I69',  FALSE, TRUE,  'HCC100'),
    ('I70.0',  'Atherosclerosis of aorta',                      'IX',  'Circulatory',    'I70-I79',  TRUE,  TRUE,  'HCC108'),
    -- Endocrine (Chapter IV)
    ('E11.9',  'Type 2 diabetes without complications',         'IV',  'Endocrine',      'E08-E13',  TRUE,  TRUE,  'HCC19'),
    ('E11.65', 'Type 2 DM with hyperglycemia',                 'IV',  'Endocrine',      'E08-E13',  TRUE,  TRUE,  'HCC18'),
    ('E11.22', 'Type 2 DM with diabetic CKD',                  'IV',  'Endocrine',      'E08-E13',  TRUE,  TRUE,  'HCC18'),
    ('E11.40', 'Type 2 DM with diabetic neuropathy',           'IV',  'Endocrine',      'E08-E13',  TRUE,  TRUE,  'HCC18'),
    ('E78.5',  'Hyperlipidemia, unspecified',                   'IV',  'Endocrine',      'E70-E88',  TRUE,  FALSE, NULL),
    ('E78.00', 'Pure hypercholesterolemia',                     'IV',  'Endocrine',      'E70-E88',  TRUE,  FALSE, NULL),
    ('E03.9',  'Hypothyroidism, unspecified',                   'IV',  'Endocrine',      'E00-E07',  TRUE,  FALSE, NULL),
    ('E66.01', 'Morbid obesity due to excess calories',         'IV',  'Endocrine',      'E65-E68',  TRUE,  TRUE,  'HCC22'),
    -- Respiratory (Chapter X)
    ('J18.9',  'Pneumonia, unspecified organism',               'X',   'Respiratory',    'J12-J18',  FALSE, TRUE,  'HCC114'),
    ('J44.1',  'COPD with acute exacerbation',                  'X',   'Respiratory',    'J40-J47',  TRUE,  TRUE,  'HCC111'),
    ('J44.0',  'COPD with acute lower respiratory infection',   'X',   'Respiratory',    'J40-J47',  TRUE,  TRUE,  'HCC111'),
    ('J45.20', 'Mild intermittent asthma, uncomplicated',       'X',   'Respiratory',    'J40-J47',  TRUE,  FALSE, NULL),
    ('J45.40', 'Moderate persistent asthma, uncomplicated',     'X',   'Respiratory',    'J40-J47',  TRUE,  FALSE, NULL),
    ('J96.00', 'Acute respiratory failure',                     'X',   'Respiratory',    'J96-J99',  FALSE, TRUE,  'HCC84'),
    ('J06.9',  'Acute upper respiratory infection',             'X',   'Respiratory',    'J00-J06',  FALSE, FALSE, NULL),
    -- Musculoskeletal (Chapter XIII)
    ('M17.11', 'Primary osteoarthritis, right knee',            'XIII','Musculoskeletal','M15-M19',  TRUE,  FALSE, NULL),
    ('M17.12', 'Primary osteoarthritis, left knee',             'XIII','Musculoskeletal','M15-M19',  TRUE,  FALSE, NULL),
    ('M54.5',  'Low back pain',                                 'XIII','Musculoskeletal','M50-M54',  FALSE, FALSE, NULL),
    ('M16.11', 'Primary osteoarthritis, right hip',             'XIII','Musculoskeletal','M15-M19',  TRUE,  FALSE, NULL),
    ('M79.3',  'Panniculitis, unspecified',                     'XIII','Musculoskeletal','M70-M79',  FALSE, FALSE, NULL),
    ('S72.001A','Fracture of unspecified part of neck of right femur','XIX','Injury','S70-S79', FALSE, FALSE, NULL),
    ('S72.002A','Fracture of unspecified part of neck of left femur', 'XIX','Injury','S70-S79', FALSE, FALSE, NULL),
    -- Digestive (Chapter XI)
    ('K21.0',  'GERD with esophagitis',                         'XI',  'Digestive',      'K20-K31',  TRUE,  FALSE, NULL),
    ('K35.80', 'Unspecified acute appendicitis',                'XI',  'Digestive',      'K35-K38',  FALSE, FALSE, NULL),
    ('K80.20', 'Calculus of gallbladder w/o obstruction',       'XI',  'Digestive',      'K80-K87',  FALSE, FALSE, NULL),
    ('K57.30', 'Diverticulosis of large intestine',             'XI',  'Digestive',      'K55-K64',  TRUE,  FALSE, NULL),
    ('K92.1',  'Melena',                                        'XI',  'Digestive',      'K90-K95',  FALSE, FALSE, NULL),
    -- Genitourinary (Chapter XIV)
    ('N18.3',  'Chronic kidney disease, stage 3',               'XIV', 'Genitourinary',  'N17-N19',  TRUE,  TRUE,  'HCC138'),
    ('N18.4',  'Chronic kidney disease, stage 4',               'XIV', 'Genitourinary',  'N17-N19',  TRUE,  TRUE,  'HCC137'),
    ('N39.0',  'Urinary tract infection',                       'XIV', 'Genitourinary',  'N30-N39',  FALSE, FALSE, NULL),
    ('N40.0',  'Benign prostatic hyperplasia w/o obstruction',  'XIV', 'Genitourinary',  'N40-N53',  TRUE,  FALSE, NULL),
    -- Neoplasms (Chapter II)
    ('C34.90', 'Malignant neoplasm of lung, unspecified',       'II',  'Neoplasms',      'C30-C39',  TRUE,  TRUE,  'HCC9'),
    ('C50.911','Malignant neoplasm of breast, right',           'II',  'Neoplasms',      'C50',      TRUE,  TRUE,  'HCC12'),
    ('C50.912','Malignant neoplasm of breast, left',            'II',  'Neoplasms',      'C50',      TRUE,  TRUE,  'HCC12'),
    ('C18.9',  'Malignant neoplasm of colon, unspecified',      'II',  'Neoplasms',      'C15-C26',  TRUE,  TRUE,  'HCC11'),
    ('C61',    'Malignant neoplasm of prostate',                'II',  'Neoplasms',      'C60-C63',  TRUE,  TRUE,  'HCC12'),
    ('D64.9',  'Anemia, unspecified',                           'II',  'Neoplasms',      'D60-D64',  FALSE, TRUE,  'HCC48'),
    -- Mental/Behavioral (Chapter V)
    ('F32.1',  'Major depressive disorder, single, moderate',   'V',   'Mental',         'F30-F39',  TRUE,  TRUE,  'HCC59'),
    ('F41.1',  'Generalized anxiety disorder',                  'V',   'Mental',         'F40-F48',  TRUE,  FALSE, NULL),
    ('F10.20', 'Alcohol dependence, uncomplicated',             'V',   'Mental',         'F10-F19',  TRUE,  TRUE,  'HCC55'),
    ('F17.210','Nicotine dependence, cigarettes, uncomplicated','V',   'Mental',         'F10-F19',  TRUE,  FALSE, NULL),
    -- Pregnancy (Chapter XV)
    ('O80',    'Encounter for full-term uncomplicated delivery','XV',  'Pregnancy',      'O80-O82',  FALSE, FALSE, NULL),
    ('O82',    'Encounter for cesarean delivery',               'XV',  'Pregnancy',      'O80-O82',  FALSE, FALSE, NULL),
    ('O24.410','Gestational diabetes in pregnancy, diet',       'XV',  'Pregnancy',      'O20-O29',  FALSE, FALSE, NULL),
    ('O13.9',  'Gestational hypertension',                      'XV',  'Pregnancy',      'O10-O16',  FALSE, FALSE, NULL),
    -- Infectious (Chapter I)
    ('A41.9',  'Sepsis, unspecified organism',                  'I',   'Infectious',     'A30-A49',  FALSE, TRUE,  'HCC2'),
    ('B34.9',  'Viral infection, unspecified',                  'I',   'Infectious',     'B25-B34',  FALSE, FALSE, NULL),
    ('U07.1',  'COVID-19',                                      'XXII','Special',        'U00-U49',  FALSE, FALSE, NULL),
    -- Nervous System (Chapter VI)
    ('G47.33', 'Obstructive sleep apnea',                       'VI',  'Nervous',        'G47',      TRUE,  FALSE, NULL),
    ('G43.909','Migraine, unspecified, not intractable',        'VI',  'Nervous',        'G43-G44',  TRUE,  FALSE, NULL),
    ('G20',    'Parkinson disease',                             'VI',  'Nervous',        'G20-G26',  TRUE,  TRUE,  'HCC78'),
    ('G30.9',  'Alzheimer disease, unspecified',                'VI',  'Nervous',        'G30-G32',  TRUE,  TRUE,  'HCC51'),
    -- Symptoms (Chapter XVIII)
    ('R06.02', 'Shortness of breath',                           'XVIII','Symptoms',      'R00-R09',  FALSE, FALSE, NULL),
    ('R07.9',  'Chest pain, unspecified',                       'XVIII','Symptoms',      'R00-R09',  FALSE, FALSE, NULL),
    ('R10.9',  'Unspecified abdominal pain',                    'XVIII','Symptoms',      'R10-R19',  FALSE, FALSE, NULL),
    ('R50.9',  'Fever, unspecified',                            'XVIII','Symptoms',      'R50-R69',  FALSE, FALSE, NULL),
    ('R11.0',  'Nausea',                                        'XVIII','Symptoms',      'R10-R19',  FALSE, FALSE, NULL),
    -- Injury (Chapter XIX)
    ('S06.0X0A','Concussion without loss of consciousness',     'XIX', 'Injury',         'S00-S09',  FALSE, FALSE, NULL),
    ('T81.4XXA','Infection following a procedure',              'XIX', 'Injury',         'T80-T88',  FALSE, FALSE, NULL),
    -- Additional high-volume codes
    ('Z23',    'Encounter for immunization',                    'XXI', 'Factors',        'Z20-Z29',  FALSE, FALSE, NULL),
    ('Z87.891','Personal history of nicotine dependence',       'XXI', 'Factors',        'Z85-Z87',  FALSE, FALSE, NULL),
    ('Z96.641','Presence of right artificial hip joint',        'XXI', 'Factors',        'Z96-Z97',  FALSE, FALSE, NULL),
    ('Z96.642','Presence of left artificial hip joint',         'XXI', 'Factors',        'Z96-Z97',  FALSE, FALSE, NULL),
    ('Z96.651','Presence of right artificial knee joint',       'XXI', 'Factors',        'Z96-Z97',  FALSE, FALSE, NULL),
    ('Z96.652','Presence of left artificial knee joint',        'XXI', 'Factors',        'Z96-Z97',  FALSE, FALSE, NULL),
    ('R65.20', 'Severe sepsis without septic shock',            'XVIII','Symptoms',      'R65',      FALSE, TRUE,  'HCC2'),
    ('R65.21', 'Severe sepsis with septic shock',               'XVIII','Symptoms',      'R65',      FALSE, TRUE,  'HCC2'),
    ('J95.851','Ventilator associated pneumonia',               'X',   'Respiratory',    'J95',      FALSE, TRUE,  'HCC114'),
    ('I26.99', 'Other pulmonary embolism',                      'IX',  'Circulatory',    'I26',      FALSE, TRUE,  'HCC107'),
    ('N17.9',  'Acute kidney failure, unspecified',             'XIV', 'Genitourinary',  'N17-N19',  FALSE, TRUE,  'HCC135'),
    ('E87.1',  'Hypo-osmolality and hyponatremia',             'IV',  'Endocrine',      'E86-E87',  FALSE, FALSE, NULL),
    ('D62',    'Acute posthemorrhagic anemia',                  'III', 'Blood',          'D60-D64',  FALSE, TRUE,  'HCC48'),
    ('J69.0',  'Aspiration pneumonia',                          'X',   'Respiratory',    'J60-J70',  FALSE, TRUE,  'HCC114'),
    ('K56.60', 'Unspecified intestinal obstruction',            'XI',  'Digestive',      'K55-K64',  FALSE, FALSE, NULL),
    ('L03.311','Cellulitis of abdominal wall',                  'XII', 'Skin',           'L00-L08',  FALSE, FALSE, NULL),
    ('M62.82', 'Rhabdomyolysis',                                'XIII','Musculoskeletal','M60-M63',  FALSE, FALSE, NULL),
    ('E11.621','Type 2 DM with foot ulcer',                    'IV',  'Endocrine',      'E08-E13',  TRUE,  TRUE,  'HCC18'),
    ('I25.5',  'Ischemic cardiomyopathy',                      'IX',  'Circulatory',    'I20-I25',  TRUE,  TRUE,  'HCC85'),
    ('G89.29', 'Other chronic pain',                            'VI',  'Nervous',        'G89',      TRUE,  FALSE, NULL),
    ('M48.06', 'Spinal stenosis, lumbar region',                'XIII','Musculoskeletal','M45-M49',  TRUE,  FALSE, NULL),
    ('M47.816','Spondylosis w/o myelopathy, lumbar',           'XIII','Musculoskeletal','M45-M49',  TRUE,  FALSE, NULL),
    ('I25.110','Atherosclerotic heart disease of native coronary artery','IX','Circulatory','I20-I25',TRUE,TRUE,'HCC86'),
    ('I25.710','Atherosclerosis of coronary artery bypass graft','IX','Circulatory','I20-I25',TRUE,TRUE,'HCC86'),
    ('J84.10', 'Pulmonary fibrosis, unspecified',               'X',  'Respiratory',    'J80-J84',  TRUE,  TRUE,  'HCC112'),
    ('K74.60', 'Unspecified cirrhosis of liver',                'XI',  'Digestive',      'K70-K77',  TRUE,  TRUE,  'HCC27'),
    ('C25.9',  'Malignant neoplasm of pancreas, unspecified',   'II', 'Neoplasms',      'C15-C26',  TRUE,  TRUE,  'HCC11'),
    ('C79.51', 'Secondary malignant neoplasm of bone',          'II', 'Neoplasms',      'C76-C80',  TRUE,  TRUE,  'HCC8'),
    ('C78.00', 'Secondary malignant neoplasm of lung',          'II', 'Neoplasms',      'C76-C80',  TRUE,  TRUE,  'HCC8');

-- =============================================================================
-- 6. DIM_PROCEDURE_CPT — 150 common CPT codes
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.CLINICAL.DIM_PROCEDURE_CPT;

INSERT INTO HOSPITAL360_CUR.CLINICAL.DIM_PROCEDURE_CPT
    (CPT_CODE, DESCRIPTION, CATEGORY, SUBCATEGORY, RVU_WORK, RVU_PE, RVU_MALPRACTICE, RVU_TOTAL)
VALUES
    -- E&M Codes (high volume)
    ('99213', 'Office visit, established, low complexity',          'E&M',       'Office Visit',    0.97, 1.30, 0.07, 2.34),
    ('99214', 'Office visit, established, moderate complexity',     'E&M',       'Office Visit',    1.50, 1.75, 0.10, 3.35),
    ('99215', 'Office visit, established, high complexity',         'E&M',       'Office Visit',    2.11, 2.16, 0.14, 4.41),
    ('99203', 'Office visit, new patient, low complexity',          'E&M',       'Office Visit',    1.60, 1.82, 0.10, 3.52),
    ('99204', 'Office visit, new patient, moderate complexity',     'E&M',       'Office Visit',    2.60, 2.56, 0.14, 5.30),
    ('99205', 'Office visit, new patient, high complexity',         'E&M',       'Office Visit',    3.50, 3.23, 0.19, 6.92),
    ('99281', 'ED visit, self-limited problem',                     'E&M',       'Emergency',       0.48, 0.76, 0.04, 1.28),
    ('99282', 'ED visit, low-moderate severity',                    'E&M',       'Emergency',       0.93, 1.20, 0.07, 2.20),
    ('99283', 'ED visit, moderate severity',                        'E&M',       'Emergency',       1.60, 1.82, 0.11, 3.53),
    ('99284', 'ED visit, high severity, no threat',                 'E&M',       'Emergency',       2.74, 2.84, 0.18, 5.76),
    ('99285', 'ED visit, high severity, immediate threat',          'E&M',       'Emergency',       3.80, 3.72, 0.25, 7.77),
    ('99221', 'Initial hospital care, low complexity',              'E&M',       'Inpatient',       1.92, 1.43, 0.10, 3.45),
    ('99222', 'Initial hospital care, moderate complexity',         'E&M',       'Inpatient',       2.61, 1.86, 0.13, 4.60),
    ('99223', 'Initial hospital care, high complexity',             'E&M',       'Inpatient',       3.86, 2.58, 0.19, 6.63),
    ('99231', 'Subsequent hospital care, low complexity',           'E&M',       'Inpatient',       0.76, 0.84, 0.04, 1.64),
    ('99232', 'Subsequent hospital care, moderate complexity',      'E&M',       'Inpatient',       1.39, 1.18, 0.07, 2.64),
    ('99233', 'Subsequent hospital care, high complexity',          'E&M',       'Inpatient',       2.00, 1.51, 0.10, 3.61),
    ('99291', 'Critical care, first 30-74 minutes',                 'E&M',       'Critical Care',   4.50, 3.14, 0.22, 7.86),
    ('99292', 'Critical care, each additional 30 min',              'E&M',       'Critical Care',   2.25, 1.19, 0.11, 3.55),
    -- Surgery — Orthopedic
    ('27447', 'Total knee arthroplasty',                            'Surgery',   'Orthopedic',     20.77,18.49, 3.73, 42.99),
    ('27130', 'Total hip arthroplasty',                             'Surgery',   'Orthopedic',     20.72,18.18, 3.73, 42.63),
    ('27236', 'Open treatment femoral fracture',                    'Surgery',   'Orthopedic',     16.43,14.55, 2.88, 33.86),
    ('27245', 'Treatment intertrochanteric femur fx',               'Surgery',   'Orthopedic',     15.13,13.61, 2.65, 31.39),
    ('29881', 'Arthroscopy, knee, with meniscectomy',               'Surgery',   'Orthopedic',      6.72, 8.43, 1.07, 16.22),
    ('23472', 'Total shoulder arthroplasty',                        'Surgery',   'Orthopedic',     22.14,19.02, 3.98, 45.14),
    ('22633', 'Lumbar arthrodesis, combined',                       'Surgery',   'Orthopedic',     28.50,22.38, 5.13, 56.01),
    -- Surgery — General
    ('47562', 'Laparoscopic cholecystectomy',                       'Surgery',   'General',         9.81,10.71, 1.62, 22.14),
    ('47563', 'Lap chole with cholangiography',                     'Surgery',   'General',        11.09,11.38, 1.83, 24.30),
    ('44120', 'Enterectomy, small bowel',                           'Surgery',   'General',        18.89,15.57, 3.40, 37.86),
    ('44140', 'Colectomy, partial with anastomosis',                'Surgery',   'General',        22.50,17.87, 4.05, 44.42),
    ('49505', 'Inguinal hernia repair, initial',                    'Surgery',   'General',         7.79, 9.23, 1.25, 18.27),
    ('44970', 'Laparoscopic appendectomy',                          'Surgery',   'General',         9.50,10.50, 1.57, 21.57),
    -- Surgery — Cardiac
    ('33533', 'CABG using arterial graft, single',                  'Surgery',   'Cardiac',        33.18,25.23, 5.97, 64.38),
    ('33405', 'Aortic valve replacement, open',                     'Surgery',   'Cardiac',        38.60,28.33, 6.95, 73.88),
    ('93458', 'Left heart catheterization',                         'Surgery',   'Cardiac',         4.22, 8.25, 0.42, 12.89),
    ('92928', 'Percutaneous coronary stent placement',              'Surgery',   'Cardiac',        10.07,12.72, 1.45, 24.24),
    ('33208', 'Pacemaker insertion, dual chamber',                  'Surgery',   'Cardiac',        11.08,14.45, 1.99, 27.52),
    -- Surgery — OB/GYN
    ('59510', 'Cesarean delivery',                                  'Surgery',   'OB/GYN',        21.45,18.40, 3.86, 43.71),
    ('59400', 'Routine obstetric care, vaginal delivery',           'Surgery',   'OB/GYN',        22.97,21.16, 3.97, 48.10),
    ('58150', 'Total hysterectomy',                                 'Surgery',   'OB/GYN',        16.21,14.97, 2.92, 34.10),
    ('58571', 'Laparoscopic hysterectomy with tubes/ovaries',       'Surgery',   'OB/GYN',        18.68,16.08, 3.36, 38.12),
    -- Surgery — Neuro
    ('63030', 'Lumbar laminotomy, single segment',                  'Surgery',   'Neurosurgery',   13.18,12.52, 2.37, 28.07),
    ('61510', 'Craniotomy for brain tumor excision',                'Surgery',   'Neurosurgery',   33.90,25.17, 6.10, 65.17),
    -- Radiology
    ('71046', 'Chest X-ray, 2 views',                              'Radiology', 'Diagnostic',      0.18, 0.52, 0.02, 0.72),
    ('71250', 'CT chest without contrast',                          'Radiology', 'CT',              1.24, 5.29, 0.07, 6.60),
    ('71260', 'CT chest with contrast',                             'Radiology', 'CT',              1.38, 5.84, 0.08, 7.30),
    ('74177', 'CT abdomen/pelvis with contrast',                    'Radiology', 'CT',              1.82, 6.78, 0.10, 8.70),
    ('70553', 'MRI brain with and without contrast',                'Radiology', 'MRI',             1.96,11.39, 0.11, 13.46),
    ('73721', 'MRI knee without contrast',                          'Radiology', 'MRI',             1.30, 8.42, 0.07, 9.79),
    ('76856', 'US pelvis, complete',                                'Radiology', 'Ultrasound',      0.69, 3.28, 0.04, 4.01),
    ('77067', 'Screening mammography, bilateral',                   'Radiology', 'Mammography',     0.87, 4.86, 0.05, 5.78),
    ('77065', 'Diagnostic mammography, unilateral',                 'Radiology', 'Mammography',     1.09, 5.20, 0.06, 6.35),
    -- Lab
    ('80053', 'Comprehensive metabolic panel',                      'Lab',       'Chemistry',       0.00, 0.99, 0.00, 0.99),
    ('85025', 'CBC with differential',                              'Lab',       'Hematology',      0.00, 0.63, 0.00, 0.63),
    ('80061', 'Lipid panel',                                        'Lab',       'Chemistry',       0.00, 0.78, 0.00, 0.78),
    ('83036', 'Hemoglobin A1c',                                     'Lab',       'Chemistry',       0.00, 0.86, 0.00, 0.86),
    ('82565', 'Creatinine, blood',                                  'Lab',       'Chemistry',       0.00, 0.42, 0.00, 0.42),
    ('84443', 'Thyroid stimulating hormone (TSH)',                   'Lab',       'Chemistry',       0.00, 0.91, 0.00, 0.91),
    ('87086', 'Urine culture, bacterial',                           'Lab',       'Microbiology',    0.00, 0.63, 0.00, 0.63),
    ('87804', 'Rapid influenza test',                               'Lab',       'Microbiology',    0.00, 0.55, 0.00, 0.55),
    ('87635', 'SARS-CoV-2 NAAT',                                   'Lab',       'Microbiology',    0.00, 1.39, 0.00, 1.39),
    ('86900', 'Blood typing, ABO',                                  'Lab',       'Blood Bank',      0.00, 0.31, 0.00, 0.31),
    ('86901', 'Blood typing, Rh',                                   'Lab',       'Blood Bank',      0.00, 0.28, 0.00, 0.28),
    ('82947', 'Glucose, blood',                                     'Lab',       'Chemistry',       0.00, 0.36, 0.00, 0.36),
    ('84132', 'Potassium, blood',                                   'Lab',       'Chemistry',       0.00, 0.36, 0.00, 0.36),
    ('82310', 'Calcium, total',                                     'Lab',       'Chemistry',       0.00, 0.36, 0.00, 0.36),
    ('82040', 'Albumin, blood',                                     'Lab',       'Chemistry',       0.00, 0.36, 0.00, 0.36),
    ('85610', 'Prothrombin time (PT/INR)',                           'Lab',       'Hematology',      0.00, 0.48, 0.00, 0.48),
    ('85730', 'Partial thromboplastin time (PTT)',                   'Lab',       'Hematology',      0.00, 0.48, 0.00, 0.48),
    ('82784', 'IgA, IgD, IgG, IgM, each',                          'Lab',       'Immunology',      0.00, 0.56, 0.00, 0.56),
    -- Medicine/Procedures
    ('93000', 'Electrocardiogram, 12-lead',                         'Medicine',  'Cardiology',      0.17, 0.54, 0.01, 0.72),
    ('93306', 'Echocardiography, complete',                         'Medicine',  'Cardiology',      1.50, 5.55, 0.08, 7.13),
    ('93010', 'Electrocardiogram interpretation',                   'Medicine',  'Cardiology',      0.17, 0.11, 0.01, 0.29),
    ('94060', 'Bronchodilator response spirometry',                 'Medicine',  'Pulmonary',       0.31, 1.36, 0.02, 1.69),
    ('95819', 'EEG awake and asleep',                               'Medicine',  'Neurology',       1.68, 4.44, 0.09, 6.21),
    ('96360', 'IV infusion, initial up to 1 hour',                  'Medicine',  'Infusion',        0.17, 0.64, 0.01, 0.82),
    ('96365', 'IV infusion, therapeutic, initial',                   'Medicine',  'Infusion',        0.21, 0.80, 0.01, 1.02),
    ('90837', 'Psychotherapy, 60 minutes',                          'Medicine',  'Psychiatry',      1.65, 1.62, 0.09, 3.36),
    ('97110', 'Therapeutic exercises, each 15 min',                  'Medicine',  'Physical Therapy', 0.45, 0.56, 0.02, 1.03),
    ('97140', 'Manual therapy, each 15 min',                         'Medicine',  'Physical Therapy', 0.43, 0.49, 0.02, 0.94),
    ('36620', 'Arterial line insertion',                              'Surgery',  'Vascular Access',  1.28, 1.72, 0.15, 3.15),
    ('36556', 'Central venous catheter insertion',                   'Surgery',  'Vascular Access',  2.50, 3.35, 0.30, 6.15),
    ('31500', 'Endotracheal intubation',                             'Surgery',  'Airway',          2.44, 1.95, 0.33, 4.72),
    ('32551', 'Tube thoracostomy (chest tube)',                      'Surgery',  'Thoracic',        3.12, 2.87, 0.42, 6.41),
    ('43239', 'Upper GI endoscopy with biopsy',                     'Surgery',  'GI',              2.77, 4.73, 0.30, 7.80),
    ('45380', 'Colonoscopy with biopsy',                            'Surgery',  'GI',              3.36, 5.46, 0.36, 9.18),
    ('45378', 'Diagnostic colonoscopy',                             'Surgery',  'GI',              3.06, 5.05, 0.33, 8.44),
    ('45385', 'Colonoscopy with polyp removal',                     'Surgery',  'GI',              4.47, 6.34, 0.48, 11.29),
    ('62323', 'Lumbar epidural steroid injection',                   'Surgery',  'Pain',            1.90, 4.76, 0.15, 6.81),
    ('64483', 'Transforaminal epidural injection, lumbar',           'Surgery',  'Pain',            2.28, 5.07, 0.18, 7.53),
    ('20610', 'Arthrocentesis, major joint',                         'Surgery',  'Orthopedic',      0.91, 1.69, 0.06, 2.66);

-- =============================================================================
-- 7. DIM_DRG — 80 common MS-DRGs
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.FINANCIAL.DIM_DRG;

INSERT INTO HOSPITAL360_CUR.FINANCIAL.DIM_DRG
    (DRG_CODE, DESCRIPTION, MDC, MDC_DESCRIPTION, TYPE, WEIGHT, GEOMETRIC_LOS, ARITHMETIC_LOS)
VALUES
    -- MDC 01 — Nervous System
    ('064', 'Intracranial hemorrhage or cerebral infarction w MCC', '01', 'Nervous System',    'MEDICAL',  1.7893, 4.5, 5.8),
    ('065', 'Intracranial hemorrhage or cerebral infarction w CC',  '01', 'Nervous System',    'MEDICAL',  1.0672, 3.2, 4.0),
    ('066', 'Intracranial hemorrhage or cerebral infarction w/o CC','01', 'Nervous System',    'MEDICAL',  0.7156, 2.2, 2.8),
    ('025', 'Craniotomy & endovascular intracranial procedures w MCC','01','Nervous System',   'SURGICAL', 4.6139, 8.2, 11.5),
    -- MDC 04 — Respiratory
    ('177', 'Respiratory infections & inflammations w MCC',          '04', 'Respiratory',       'MEDICAL',  1.8725, 5.5, 7.2),
    ('178', 'Respiratory infections & inflammations w CC',           '04', 'Respiratory',       'MEDICAL',  1.2038, 4.1, 5.1),
    ('190', 'COPD w MCC',                                           '04', 'Respiratory',       'MEDICAL',  1.2555, 3.7, 4.8),
    ('191', 'COPD w CC',                                            '04', 'Respiratory',       'MEDICAL',  0.9287, 3.1, 3.8),
    ('192', 'COPD w/o CC/MCC',                                     '04', 'Respiratory',       'MEDICAL',  0.7072, 2.6, 3.1),
    ('193', 'Simple pneumonia & pleurisy w MCC',                    '04', 'Respiratory',       'MEDICAL',  1.4020, 4.2, 5.6),
    ('194', 'Simple pneumonia & pleurisy w CC',                     '04', 'Respiratory',       'MEDICAL',  0.9442, 3.3, 4.0),
    ('195', 'Simple pneumonia & pleurisy w/o CC/MCC',               '04', 'Respiratory',       'MEDICAL',  0.6897, 2.5, 3.0),
    ('207', 'Respiratory system diagnosis w ventilator >96 hrs',    '04', 'Respiratory',       'MEDICAL',  4.7310, 11.2, 14.8),
    ('208', 'Respiratory system diagnosis w ventilator <96 hrs',    '04', 'Respiratory',       'MEDICAL',  2.1453, 5.0, 6.5),
    -- MDC 05 — Circulatory
    ('280', 'Acute MI, discharged alive w MCC',                     '05', 'Circulatory',       'MEDICAL',  1.8151, 4.2, 5.5),
    ('281', 'Acute MI, discharged alive w CC',                      '05', 'Circulatory',       'MEDICAL',  1.1127, 2.8, 3.4),
    ('282', 'Acute MI, discharged alive w/o CC/MCC',                '05', 'Circulatory',       'MEDICAL',  0.7366, 1.9, 2.3),
    ('291', 'Heart failure & shock w MCC',                          '05', 'Circulatory',       'MEDICAL',  1.5424, 4.4, 5.8),
    ('292', 'Heart failure & shock w CC',                           '05', 'Circulatory',       'MEDICAL',  1.0146, 3.2, 4.0),
    ('293', 'Heart failure & shock w/o CC/MCC',                     '05', 'Circulatory',       'MEDICAL',  0.6887, 2.4, 2.9),
    ('246', 'Perc cardiovascular proc w drug-eluting stent w MCC',  '05', 'Circulatory',       'SURGICAL', 2.9849, 5.1, 6.8),
    ('247', 'Perc cardiovascular proc w drug-eluting stent w CC',   '05', 'Circulatory',       'SURGICAL', 2.0262, 2.5, 3.1),
    ('248', 'Perc cardiovascular proc w drug-eluting stent w/o CC', '05', 'Circulatory',       'SURGICAL', 1.6824, 1.6, 1.9),
    ('233', 'Coronary bypass w cardiac cath w MCC',                 '05', 'Circulatory',       'SURGICAL', 6.7833, 10.4, 13.2),
    ('234', 'Coronary bypass w cardiac cath w/o MCC',               '05', 'Circulatory',       'SURGICAL', 4.3932, 7.0, 8.0),
    ('216', 'Cardiac valve & other major cardiothoracic proc w MCC','05', 'Circulatory',       'SURGICAL', 8.2014, 11.8, 15.5),
    ('308', 'Cardiac arrhythmia & conduction disorders w MCC',      '05', 'Circulatory',       'MEDICAL',  1.2405, 3.3, 4.4),
    ('309', 'Cardiac arrhythmia & conduction disorders w CC',       '05', 'Circulatory',       'MEDICAL',  0.8289, 2.4, 3.0),
    -- MDC 06 — Digestive
    ('329', 'Major small & large bowel procedures w MCC',           '06', 'Digestive',         'SURGICAL', 3.6262, 8.7, 11.7),
    ('330', 'Major small & large bowel procedures w CC',            '06', 'Digestive',         'SURGICAL', 2.1076, 5.2, 6.4),
    ('331', 'Major small & large bowel procedures w/o CC/MCC',      '06', 'Digestive',         'SURGICAL', 1.4181, 3.3, 3.8),
    ('377', 'GI hemorrhage w MCC',                                  '06', 'Digestive',         'MEDICAL',  1.5981, 4.1, 5.4),
    ('378', 'GI hemorrhage w CC',                                   '06', 'Digestive',         'MEDICAL',  1.0228, 3.0, 3.7),
    ('379', 'GI hemorrhage w/o CC/MCC',                             '06', 'Digestive',         'MEDICAL',  0.6813, 2.1, 2.6),
    ('418', 'Laparoscopic cholecystectomy w/o CC/MCC',              '07', 'Hepatobiliary',     'SURGICAL', 1.0792, 2.0, 2.7),
    ('419', 'Laparoscopic cholecystectomy w CC',                    '07', 'Hepatobiliary',     'SURGICAL', 1.4867, 3.4, 4.5),
    -- MDC 08 — Musculoskeletal
    ('469', 'Major hip and knee joint replacement w MCC',           '08', 'Musculoskeletal',   'SURGICAL', 2.7844, 3.9, 5.8),
    ('470', 'Major hip and knee joint replacement w/o MCC',         '08', 'Musculoskeletal',   'SURGICAL', 1.7404, 1.9, 2.3),
    ('480', 'Hip & femur procedures except major joint w MCC',      '08', 'Musculoskeletal',   'SURGICAL', 2.5340, 5.4, 7.2),
    ('481', 'Hip & femur procedures except major joint w CC',       '08', 'Musculoskeletal',   'SURGICAL', 1.6361, 3.7, 4.5),
    ('482', 'Hip & femur procedures except major joint w/o CC/MCC', '08', 'Musculoskeletal',   'SURGICAL', 1.2330, 2.6, 3.1),
    ('460', 'Spinal fusion except cervical w MCC',                  '08', 'Musculoskeletal',   'SURGICAL', 5.1524, 6.2, 8.5),
    ('461', 'Spinal fusion except cervical w/o MCC',                '08', 'Musculoskeletal',   'SURGICAL', 3.2814, 3.0, 3.7),
    -- MDC 11 — Kidney/Urinary
    ('682', 'Renal failure w MCC',                                  '11', 'Kidney/Urinary',    'MEDICAL',  1.5038, 4.0, 5.3),
    ('683', 'Renal failure w CC',                                   '11', 'Kidney/Urinary',    'MEDICAL',  0.9563, 3.0, 3.7),
    ('684', 'Renal failure w/o CC/MCC',                             '11', 'Kidney/Urinary',    'MEDICAL',  0.6287, 2.2, 2.7),
    -- MDC 14 — Pregnancy/Childbirth
    ('765', 'Cesarean section w CC/MCC',                            '14', 'Pregnancy',         'SURGICAL', 1.2754, 3.6, 4.3),
    ('766', 'Cesarean section w/o CC/MCC',                          '14', 'Pregnancy',         'SURGICAL', 0.8674, 2.5, 2.8),
    ('774', 'Vaginal delivery w complicating diagnoses',            '14', 'Pregnancy',         'MEDICAL',  0.7549, 2.5, 3.0),
    ('775', 'Vaginal delivery w/o complicating diagnoses',          '14', 'Pregnancy',         'MEDICAL',  0.5808, 1.8, 2.1),
    -- MDC 18 — Infectious
    ('870', 'Septicemia or severe sepsis w MV >96 hours',           '18', 'Infectious',        'MEDICAL',  5.4965, 10.5, 14.2),
    ('871', 'Septicemia or severe sepsis w/o MV >96 hrs w MCC',    '18', 'Infectious',        'MEDICAL',  1.8723, 4.8, 6.5),
    ('872', 'Septicemia or severe sepsis w/o MV >96 hrs w/o MCC',  '18', 'Infectious',        'MEDICAL',  1.0553, 3.3, 4.1),
    -- Other common DRGs
    ('689', 'Kidney & urinary tract infections w MCC',              '11', 'Kidney/Urinary',    'MEDICAL',  1.2198, 3.8, 5.0),
    ('690', 'Kidney & urinary tract infections w/o MCC',            '11', 'Kidney/Urinary',    'MEDICAL',  0.7862, 2.8, 3.5),
    ('313', 'Chest pain',                                           '05', 'Circulatory',       'MEDICAL',  0.5413, 1.4, 1.8),
    ('312', 'Syncope & collapse',                                   '05', 'Circulatory',       'MEDICAL',  0.7900, 2.4, 3.0),
    ('948', 'Signs & symptoms w/o MCC',                             '23', 'Other',             'MEDICAL',  0.6200, 2.0, 2.5),
    ('392', 'Esophagitis, gastroenteritis w/o MCC',                 '06', 'Digestive',         'MEDICAL',  0.6758, 2.2, 2.8),
    ('603', 'Cellulitis w/o MCC',                                   '09', 'Skin',              'MEDICAL',  0.8300, 3.2, 3.9),
    ('602', 'Cellulitis w MCC',                                     '09', 'Skin',              'MEDICAL',  1.3500, 4.5, 5.8),
    ('640', 'Misc disorders of nutrition, metabolism w MCC',         '10', 'Endocrine',         'MEDICAL',  1.0700, 3.1, 4.0),
    ('641', 'Misc disorders of nutrition, metabolism w/o MCC',       '10', 'Endocrine',         'MEDICAL',  0.6500, 2.2, 2.8),
    ('638', 'Diabetes w CC',                                        '10', 'Endocrine',         'MEDICAL',  0.8100, 2.8, 3.5),
    ('639', 'Diabetes w/o CC/MCC',                                  '10', 'Endocrine',         'MEDICAL',  0.5700, 2.0, 2.4),
    ('811', 'Red blood cell disorders w MCC',                       '16', 'Blood',             'MEDICAL',  1.2000, 3.5, 4.5),
    ('812', 'Red blood cell disorders w/o MCC',                     '16', 'Blood',             'MEDICAL',  0.7400, 2.5, 3.0),
    ('885', 'Psychoses',                                            '19', 'Mental',            'MEDICAL',  0.7600, 5.5, 6.5),
    ('897', 'Alcohol/drug abuse w/o rehabilitation w/o MCC',        '20', 'Substance Abuse',   'MEDICAL',  0.5800, 3.0, 3.8),
    ('536', 'Fractures of hip & pelvis w/o MCC',                    '08', 'Musculoskeletal',   'MEDICAL',  0.8000, 2.8, 3.4),
    ('535', 'Fractures of hip & pelvis w MCC',                      '08', 'Musculoskeletal',   'MEDICAL',  1.3300, 4.5, 5.8),
    ('917', 'Poisoning & toxic effects of drugs w MCC',             '21', 'Poisoning',         'MEDICAL',  1.4200, 3.2, 4.5),
    ('918', 'Poisoning & toxic effects of drugs w/o MCC',           '21', 'Poisoning',         'MEDICAL',  0.6800, 2.0, 2.5),
    ('853', 'Infectious & parasitic diseases w OR proc w MCC',      '18', 'Infectious',        'SURGICAL', 5.1207, 12.1, 16.0),
    ('441', 'Hand procedures for injury',                           '08', 'Musculoskeletal',   'SURGICAL', 1.0500, 1.5, 2.0),
    ('491', 'Back & neck procedures except spinal fusion w CC',     '08', 'Musculoskeletal',   'SURGICAL', 1.9200, 3.0, 4.2),
    ('473', 'Cervical spinal fusion w CC',                          '08', 'Musculoskeletal',   'SURGICAL', 2.2100, 2.4, 3.2),
    ('474', 'Cervical spinal fusion w/o CC/MCC',                    '08', 'Musculoskeletal',   'SURGICAL', 1.6900, 1.5, 1.9);

-- =============================================================================
-- 8. DIM_MEDICATION_RXNORM — 100 common medications
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.CLINICAL.DIM_MEDICATION_RXNORM;

INSERT INTO HOSPITAL360_CUR.CLINICAL.DIM_MEDICATION_RXNORM
    (RXNORM_CODE, GENERIC_NAME, BRAND_NAME, DRUG_CLASS, THERAPEUTIC_AREA, ROUTE, IS_CONTROLLED, DEA_SCHEDULE, UNIT_COST, IS_ON_SHORTAGE)
VALUES
    ('197361', 'Lisinopril 10mg',         'Zestril',      'ACE Inhibitor',       'Cardiovascular',  'ORAL',    FALSE, NULL, 0.15, FALSE),
    ('316672', 'Metoprolol Succinate 50mg','Toprol-XL',   'Beta Blocker',        'Cardiovascular',  'ORAL',    FALSE, NULL, 0.22, FALSE),
    ('197381', 'Amlodipine 5mg',          'Norvasc',      'CCB',                 'Cardiovascular',  'ORAL',    FALSE, NULL, 0.18, FALSE),
    ('310798', 'Atorvastatin 40mg',       'Lipitor',      'Statin',              'Cardiovascular',  'ORAL',    FALSE, NULL, 0.25, FALSE),
    ('261962', 'Losartan 50mg',           'Cozaar',       'ARB',                 'Cardiovascular',  'ORAL',    FALSE, NULL, 0.30, FALSE),
    ('866511', 'Apixaban 5mg',            'Eliquis',      'Anticoagulant',       'Cardiovascular',  'ORAL',    FALSE, NULL, 8.50, FALSE),
    ('855332', 'Warfarin 5mg',            'Coumadin',     'Anticoagulant',       'Cardiovascular',  'ORAL',    FALSE, NULL, 0.12, FALSE),
    ('198440', 'Clopidogrel 75mg',        'Plavix',       'Antiplatelet',        'Cardiovascular',  'ORAL',    FALSE, NULL, 0.35, FALSE),
    ('310429', 'Furosemide 40mg',         'Lasix',        'Loop Diuretic',       'Cardiovascular',  'ORAL',    FALSE, NULL, 0.08, FALSE),
    ('197884', 'Hydrochlorothiazide 25mg','Microzide',    'Thiazide Diuretic',   'Cardiovascular',  'ORAL',    FALSE, NULL, 0.06, FALSE),
    -- Diabetes
    ('860975', 'Metformin 1000mg',        'Glucophage',   'Biguanide',           'Endocrine',       'ORAL',    FALSE, NULL, 0.10, FALSE),
    ('261551', 'Glipizide 5mg',           'Glucotrol',    'Sulfonylurea',        'Endocrine',       'ORAL',    FALSE, NULL, 0.08, FALSE),
    ('897122', 'Empagliflozin 25mg',      'Jardiance',    'SGLT2 Inhibitor',     'Endocrine',       'ORAL',    FALSE, NULL, 16.50, FALSE),
    ('1598392','Semaglutide 1mg',         'Ozempic',      'GLP-1 Agonist',       'Endocrine',       'SUBQ',    FALSE, NULL, 95.00, TRUE),
    ('847232', 'Insulin Glargine 100u/mL','Lantus',       'Insulin',             'Endocrine',       'SUBQ',    FALSE, NULL, 12.00, FALSE),
    -- Respiratory
    ('896209', 'Albuterol 90mcg HFA',     'ProAir',       'SABA',                'Respiratory',     'INH',     FALSE, NULL, 3.50, FALSE),
    ('745679', 'Fluticasone/Salmeterol',  'Advair Diskus','ICS/LABA',            'Respiratory',     'INH',     FALSE, NULL, 8.75, FALSE),
    ('896188', 'Budesonide/Formoterol',   'Symbicort',    'ICS/LABA',            'Respiratory',     'INH',     FALSE, NULL, 9.25, FALSE),
    ('1232585','Tiotropium 2.5mcg',       'Spiriva',      'LAMA',                'Respiratory',     'INH',     FALSE, NULL, 11.00, FALSE),
    -- Antibiotics
    ('197450', 'Amoxicillin 500mg',       'Amoxil',       'Penicillin',          'Anti-Infective',  'ORAL',    FALSE, NULL, 0.12, FALSE),
    ('309090', 'Azithromycin 250mg',      'Zithromax',    'Macrolide',           'Anti-Infective',  'ORAL',    FALSE, NULL, 0.75, FALSE),
    ('197511', 'Ceftriaxone 1g',          'Rocephin',     'Cephalosporin',       'Anti-Infective',  'IV',      FALSE, NULL, 2.50, FALSE),
    ('240984', 'Vancomycin 1g',           'Vancocin',     'Glycopeptide',        'Anti-Infective',  'IV',      FALSE, NULL, 4.80, TRUE),
    ('562251', 'Piperacillin-Tazobactam 3.375g','Zosyn',  'Penicillin Combo',    'Anti-Infective',  'IV',      FALSE, NULL, 5.20, TRUE),
    ('199370', 'Ciprofloxacin 500mg',     'Cipro',        'Fluoroquinolone',     'Anti-Infective',  'ORAL',    FALSE, NULL, 0.45, FALSE),
    ('310132', 'Levofloxacin 500mg',      'Levaquin',     'Fluoroquinolone',     'Anti-Infective',  'ORAL',    FALSE, NULL, 0.90, FALSE),
    ('197517', 'Cefazolin 2g',            'Ancef',        'Cephalosporin',       'Anti-Infective',  'IV',      FALSE, NULL, 1.80, FALSE),
    ('242800', 'Meropenem 1g',            'Merrem',       'Carbapenem',          'Anti-Infective',  'IV',      FALSE, NULL, 8.50, TRUE),
    -- Pain / Analgesics
    ('198440', 'Acetaminophen 1000mg',    'Tylenol',      'Analgesic',           'Pain',            'ORAL',    FALSE, NULL, 0.03, FALSE),
    ('197806', 'Ibuprofen 400mg',         'Motrin',       'NSAID',               'Pain',            'ORAL',    FALSE, NULL, 0.05, FALSE),
    ('197696', 'Ketorolac 30mg',          'Toradol',      'NSAID',               'Pain',            'IV',      FALSE, NULL, 1.20, FALSE),
    ('262076', 'Morphine 4mg/mL',         'MS Contin',    'Opioid',              'Pain',            'IV',      TRUE,  'II', 0.85, FALSE),
    ('261106', 'Hydromorphone 2mg',       'Dilaudid',     'Opioid',              'Pain',            'IV',      TRUE,  'II', 1.50, FALSE),
    ('857005', 'Oxycodone 5mg',           'OxyContin',    'Opioid',              'Pain',            'ORAL',    TRUE,  'II', 0.45, FALSE),
    ('197696', 'Fentanyl 100mcg',         'Sublimaze',    'Opioid',              'Pain',            'IV',      TRUE,  'II', 2.00, TRUE),
    ('198240', 'Gabapentin 300mg',        'Neurontin',    'Anticonvulsant',      'Pain',            'ORAL',    FALSE, NULL, 0.12, FALSE),
    ('1373463','Pregabalin 75mg',         'Lyrica',       'Anticonvulsant',      'Pain',            'ORAL',    TRUE,  'V',  1.80, FALSE),
    -- GI
    ('261455', 'Omeprazole 20mg',         'Prilosec',     'PPI',                 'GI',              'ORAL',    FALSE, NULL, 0.08, FALSE),
    ('283742', 'Pantoprazole 40mg',       'Protonix',     'PPI',                 'GI',              'ORAL',    FALSE, NULL, 0.10, FALSE),
    ('261623', 'Ondansetron 4mg',         'Zofran',       'Antiemetic',          'GI',              'IV',      FALSE, NULL, 0.35, FALSE),
    ('284215', 'Promethazine 25mg',       'Phenergan',    'Antiemetic',          'GI',              'IV',      FALSE, NULL, 0.50, FALSE),
    ('311989', 'Docusate 100mg',          'Colace',       'Stool Softener',      'GI',              'ORAL',    FALSE, NULL, 0.04, FALSE),
    ('310627', 'Polyethylene glycol 17g', 'Miralax',      'Osmotic Laxative',    'GI',              'ORAL',    FALSE, NULL, 0.15, FALSE),
    -- Psych
    ('312938', 'Sertraline 50mg',         'Zoloft',       'SSRI',                'Psychiatry',      'ORAL',    FALSE, NULL, 0.08, FALSE),
    ('283506', 'Escitalopram 10mg',       'Lexapro',      'SSRI',                'Psychiatry',      'ORAL',    FALSE, NULL, 0.10, FALSE),
    ('835829', 'Duloxetine 60mg',         'Cymbalta',     'SNRI',                'Psychiatry',      'ORAL',    FALSE, NULL, 0.35, FALSE),
    ('312872', 'Trazodone 50mg',          'Desyrel',      'Antidepressant',      'Psychiatry',      'ORAL',    FALSE, NULL, 0.06, FALSE),
    ('312212', 'Lorazepam 1mg',           'Ativan',       'Benzodiazepine',      'Psychiatry',      'ORAL',    TRUE,  'IV', 0.10, FALSE),
    ('261289', 'Alprazolam 0.5mg',        'Xanax',        'Benzodiazepine',      'Psychiatry',      'ORAL',    TRUE,  'IV', 0.08, FALSE),
    ('311700', 'Quetiapine 25mg',         'Seroquel',     'Antipsychotic',       'Psychiatry',      'ORAL',    FALSE, NULL, 0.15, FALSE),
    ('313002', 'Olanzapine 10mg',         'Zyprexa',      'Antipsychotic',       'Psychiatry',      'ORAL',    FALSE, NULL, 0.50, FALSE),
    -- Anticoagulant / Blood
    ('849727', 'Heparin 25000u/250mL',    'Heparin',      'Anticoagulant',       'Hematology',      'IV',      FALSE, NULL, 3.50, TRUE),
    ('854228', 'Enoxaparin 40mg',         'Lovenox',      'LMWH',               'Hematology',      'SUBQ',    FALSE, NULL, 6.00, FALSE),
    -- Endocrine
    ('310756', 'Levothyroxine 50mcg',     'Synthroid',    'Thyroid Hormone',     'Endocrine',       'ORAL',    FALSE, NULL, 0.15, FALSE),
    ('198211', 'Prednisone 20mg',         'Deltasone',    'Corticosteroid',      'Endocrine',       'ORAL',    FALSE, NULL, 0.08, FALSE),
    ('312615', 'Methylprednisolone 125mg','Solu-Medrol',  'Corticosteroid',      'Endocrine',       'IV',      FALSE, NULL, 4.50, FALSE),
    ('198405', 'Dexamethasone 4mg',       'Decadron',     'Corticosteroid',      'Endocrine',       'IV',      FALSE, NULL, 0.80, FALSE),
    -- Sedation / Anesthesia
    ('198283', 'Propofol 10mg/mL',        'Diprivan',     'Sedative-Hypnotic',   'Anesthesia',      'IV',      TRUE,  'IV', 3.00, TRUE),
    ('311999', 'Midazolam 2mg/2mL',       'Versed',       'Benzodiazepine',      'Anesthesia',      'IV',      TRUE,  'IV', 0.80, FALSE),
    ('857793', 'Dexmedetomidine 200mcg',  'Precedex',     'Alpha-2 Agonist',     'Anesthesia',      'IV',      FALSE, NULL, 25.00, FALSE),
    ('198283', 'Rocuronium 50mg',         'Zemuron',      'NMB Agent',           'Anesthesia',      'IV',      FALSE, NULL, 5.50, FALSE),
    ('198283', 'Succinylcholine 200mg',   'Anectine',     'NMB Agent',           'Anesthesia',      'IV',      FALSE, NULL, 3.00, TRUE),
    -- Emergency / Critical Care
    ('198283', 'Epinephrine 1mg/10mL',    'Adrenalin',    'Vasopressor',         'Critical Care',   'IV',      FALSE, NULL, 2.50, FALSE),
    ('312656', 'Norepinephrine 4mg/4mL',  'Levophed',     'Vasopressor',         'Critical Care',   'IV',      FALSE, NULL, 4.00, TRUE),
    ('312938', 'Vasopressin 20u/mL',      'Vasostrict',   'Vasopressor',         'Critical Care',   'IV',      FALSE, NULL, 12.00, TRUE),
    ('197361', 'Dopamine 400mg/250mL',    'Intropin',     'Vasopressor',         'Critical Care',   'IV',      FALSE, NULL, 6.00, FALSE),
    ('198135', 'Amiodarone 150mg/3mL',    'Cordarone',    'Antiarrhythmic',      'Critical Care',   'IV',      FALSE, NULL, 3.50, FALSE),
    ('312872', 'Nitroglycerin 25mg/250mL','Tridil',       'Vasodilator',         'Critical Care',   'IV',      FALSE, NULL, 8.00, FALSE),
    -- Misc
    ('310756', 'Diphenhydramine 25mg',    'Benadryl',     'Antihistamine',       'Allergy',         'ORAL',    FALSE, NULL, 0.03, FALSE),
    ('311989', 'Famotidine 20mg',         'Pepcid',       'H2 Blocker',          'GI',              'IV',      FALSE, NULL, 0.50, FALSE),
    ('198283', 'Metoclopramide 10mg',     'Reglan',       'Prokinetic',          'GI',              'IV',      FALSE, NULL, 0.40, FALSE),
    ('312212', 'Haloperidol 5mg',         'Haldol',       'Antipsychotic',       'Psychiatry',      'IV',      FALSE, NULL, 0.30, FALSE),
    ('310429', 'Magnesium Sulfate 2g',    'MgSO4',        'Electrolyte',         'Critical Care',   'IV',      FALSE, NULL, 1.20, FALSE),
    ('197884', 'Potassium Chloride 20mEq','KCl',          'Electrolyte',         'Critical Care',   'IV',      FALSE, NULL, 0.80, FALSE),
    ('855332', 'Sodium Chloride 0.9% 1L', 'Normal Saline','IV Fluid',            'Critical Care',   'IV',      FALSE, NULL, 1.50, FALSE),
    ('855332', 'Lactated Ringer 1L',      'LR',           'IV Fluid',            'Critical Care',   'IV',      FALSE, NULL, 1.80, FALSE),
    ('860975', 'Aspirin 81mg',            'Baby Aspirin', 'Antiplatelet',        'Cardiovascular',  'ORAL',    FALSE, NULL, 0.02, FALSE),
    ('310798', 'Rosuvastatin 20mg',       'Crestor',      'Statin',              'Cardiovascular',  'ORAL',    FALSE, NULL, 0.40, FALSE);

-- =============================================================================
-- 9. DIM_PATIENT — 25,000 synthetic patients
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.CLINICAL.DIM_PATIENT;

INSERT INTO HOSPITAL360_CUR.CLINICAL.DIM_PATIENT
    (MRN, FIRST_NAME, LAST_NAME, DOB, GENDER, RACE, ETHNICITY, LANGUAGE, MARITAL_STATUS,
     SSN, PHONE, EMAIL, ADDRESS, CITY, STATE, ZIP, COUNTY, PRIMARY_PAYER_ID, HCC_SCORE, SDOH_RISK_INDEX, IS_ACTIVE, DEATH_DATE)
WITH
first_names AS (
    SELECT column1 AS name, column2 AS gender FROM VALUES
    ('James','M'),('John','M'),('Robert','M'),('Michael','M'),('William','M'),('David','M'),
    ('Richard','M'),('Joseph','M'),('Thomas','M'),('Charles','M'),('Daniel','M'),('Matthew','M'),
    ('Anthony','M'),('Mark','M'),('Donald','M'),('Steven','M'),('Andrew','M'),('Paul','M'),
    ('Joshua','M'),('Kenneth','M'),('Kevin','M'),('Brian','M'),('George','M'),('Timothy','M'),
    ('Ronald','M'),('Jason','M'),('Edward','M'),('Jeffrey','M'),('Ryan','M'),('Jacob','M'),
    ('Gary','M'),('Nicholas','M'),('Eric','M'),('Jonathan','M'),('Stephen','M'),('Larry','M'),
    ('Justin','M'),('Scott','M'),('Brandon','M'),('Benjamin','M'),('Samuel','M'),('Raymond','M'),
    ('Gregory','M'),('Frank','M'),('Alexander','M'),('Patrick','M'),('Jack','M'),('Dennis','M'),
    ('Jerry','M'),('Tyler','M'),
    ('Mary','F'),('Patricia','F'),('Jennifer','F'),('Linda','F'),('Barbara','F'),('Elizabeth','F'),
    ('Susan','F'),('Jessica','F'),('Sarah','F'),('Karen','F'),('Lisa','F'),('Nancy','F'),
    ('Betty','F'),('Margaret','F'),('Sandra','F'),('Ashley','F'),('Dorothy','F'),('Kimberly','F'),
    ('Emily','F'),('Donna','F'),('Michelle','F'),('Carol','F'),('Amanda','F'),('Melissa','F'),
    ('Deborah','F'),('Stephanie','F'),('Rebecca','F'),('Sharon','F'),('Laura','F'),('Cynthia','F'),
    ('Kathleen','F'),('Amy','F'),('Angela','F'),('Shirley','F'),('Anna','F'),('Brenda','F'),
    ('Pamela','F'),('Emma','F'),('Nicole','F'),('Helen','F'),('Samantha','F'),('Katherine','F'),
    ('Christine','F'),('Debra','F'),('Rachel','F'),('Carolyn','F'),('Janet','F'),('Catherine','F'),
    ('Maria','F'),('Heather','F')
),
last_names AS (
    SELECT column1 AS name FROM VALUES
    ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),('Miller'),('Davis'),
    ('Rodriguez'),('Martinez'),('Hernandez'),('Lopez'),('Gonzalez'),('Wilson'),('Anderson'),
    ('Thomas'),('Taylor'),('Moore'),('Jackson'),('Martin'),('Lee'),('Perez'),('Thompson'),
    ('White'),('Harris'),('Sanchez'),('Clark'),('Ramirez'),('Lewis'),('Robinson'),
    ('Walker'),('Young'),('Allen'),('King'),('Wright'),('Scott'),('Torres'),('Nguyen'),
    ('Hill'),('Flores'),('Green'),('Adams'),('Nelson'),('Baker'),('Hall'),('Rivera'),
    ('Campbell'),('Mitchell'),('Carter'),('Roberts'),('Gomez'),('Phillips'),('Evans'),
    ('Turner'),('Diaz'),('Parker'),('Cruz'),('Edwards'),('Collins'),('Reyes'),
    ('Stewart'),('Morris'),('Morales'),('Murphy'),('Cook'),('Rogers'),('Gutierrez'),
    ('Ortiz'),('Morgan'),('Cooper'),('Peterson'),('Bailey'),('Reed'),('Kelly'),
    ('Howard'),('Ramos'),('Kim'),('Cox'),('Ward'),('Richardson'),('Watson'),('Brooks'),
    ('Chavez'),('Wood'),('James'),('Bennett'),('Gray'),('Mendoza'),('Ruiz'),('Hughes'),
    ('Price'),('Alvarez'),('Castillo'),('Sanders'),('Patel'),('Myers'),('Long'),('Ross'),
    ('Foster'),('Jimenez'),('Powell'),('Jenkins')
),
zips AS (
    SELECT column1 AS zip, column2 AS city, column3 AS county FROM VALUES
    ('98101','Seattle','King'),('98103','Seattle','King'),('98105','Seattle','King'),
    ('98107','Seattle','King'),('98109','Seattle','King'),('98112','Seattle','King'),
    ('98115','Seattle','King'),('98117','Seattle','King'),('98118','Seattle','King'),
    ('98122','Seattle','King'),('98125','Seattle','King'),('98133','Seattle','King'),
    ('98144','Seattle','King'),('98155','Shoreline','King'),('98168','Tukwila','King'),
    ('98004','Bellevue','King'),('98005','Bellevue','King'),('98006','Bellevue','King'),
    ('98007','Bellevue','King'),('98008','Bellevue','King'),
    ('98033','Kirkland','King'),('98034','Kirkland','King'),
    ('98052','Redmond','King'),('98053','Redmond','King'),
    ('98055','Renton','King'),('98056','Renton','King'),('98057','Renton','King'),
    ('98058','Renton','King'),
    ('98002','Auburn','King'),('98003','Federal Way','King'),
    ('98032','Kent','King'),('98042','Kent','King'),
    ('98188','Tukwila','King'),('98198','SeaTac','King'),
    ('98201','Everett','Snohomish'),('98203','Everett','Snohomish'),
    ('98270','Marysville','Snohomish'),('98290','Snohomish','Snohomish'),
    ('98402','Tacoma','Pierce'),('98405','Tacoma','Pierce'),
    ('98407','Tacoma','Pierce'),('98418','Tacoma','Pierce'),
    ('98371','Puyallup','Pierce'),('98372','Puyallup','Pierce'),
    ('98373','Puyallup','Pierce'),
    ('98501','Olympia','Thurston'),('98502','Olympia','Thurston'),
    ('98506','Olympia','Thurston'),
    ('98226','Bellingham','Whatcom'),('98229','Bellingham','Whatcom')
),
races AS (
    SELECT column1 AS race, column2 AS weight FROM VALUES
    ('White', 60), ('Black', 12), ('Asian', 10), ('Hispanic', 14),
    ('Native American', 2), ('Pacific Islander', 1), ('Other', 1)
),
payer_weights AS (
    SELECT column1 AS payer_id, column2 AS cum_weight FROM VALUES
    ('PAY-001', 20),  -- Medicare 20%
    ('PAY-002', 28),  -- Medicare Adv 8%
    ('PAY-003', 38),  -- Medicaid 10%
    ('PAY-004', 48),  -- Premera 10%
    ('PAY-005', 55),  -- Regence 7%
    ('PAY-006', 62),  -- UHC 7%
    ('PAY-007', 68),  -- Aetna 6%
    ('PAY-008', 73),  -- Cigna 5%
    ('PAY-009', 78),  -- Molina 5%
    ('PAY-010', 82),  -- Kaiser 4%
    ('PAY-011', 86),  -- Humana 4%
    ('PAY-012', 89),  -- TriCare 3%
    ('PAY-013', 92),  -- Workers Comp 3%
    ('PAY-014', 97),  -- Self-Pay 5%
    ('PAY-015', 100)  -- Coordinated Care 3%
),
base AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS rn,
        UNIFORM(1, 100, RANDOM()) AS fn_idx,
        UNIFORM(1, 100, RANDOM()) AS ln_idx,
        UNIFORM(1, 50, RANDOM()) AS zip_idx,
        UNIFORM(1, 100, RANDOM()) AS race_pct,
        UNIFORM(1, 100, RANDOM()) AS payer_pct,
        -- Age distribution: weighted toward 40-80 for hospital population
        DATEADD(DAY,
            -UNIFORM(365, 365*95, RANDOM()),
            '2024-06-30'::DATE
        ) AS raw_dob,
        UNIFORM(1, 1000, RANDOM()) AS death_rand,
        UNIFORM(1, 100, RANDOM()) AS gender_rand
    FROM TABLE(GENERATOR(ROWCOUNT => 25000))
)
SELECT
    'MRN-' || LPAD(b.rn::STRING, 7, '0') AS MRN,
    fn.name AS FIRST_NAME,
    ln.name AS LAST_NAME,
    -- Skew age: 30% under 40, 45% 40-70, 25% over 70
    CASE
        WHEN b.rn % 100 < 30 THEN DATEADD(YEAR, -UNIFORM(0, 39, RANDOM(b.rn)), '2024-06-30')
        WHEN b.rn % 100 < 75 THEN DATEADD(YEAR, -UNIFORM(40, 70, RANDOM(b.rn+1)), '2024-06-30')
        ELSE DATEADD(YEAR, -UNIFORM(71, 95, RANDOM(b.rn+2)), '2024-06-30')
    END AS DOB,
    CASE WHEN b.gender_rand <= 52 THEN 'Female' ELSE 'Male' END AS GENDER,
    r.race AS RACE,
    CASE WHEN r.race = 'Hispanic' THEN 'Hispanic or Latino' ELSE 'Not Hispanic or Latino' END AS ETHNICITY,
    CASE WHEN UNIFORM(1,100,RANDOM(b.rn+3)) <= 85 THEN 'English'
         WHEN UNIFORM(1,100,RANDOM(b.rn+4)) <= 50 THEN 'Spanish'
         WHEN UNIFORM(1,100,RANDOM(b.rn+5)) <= 30 THEN 'Chinese'
         WHEN UNIFORM(1,100,RANDOM(b.rn+6)) <= 20 THEN 'Vietnamese'
         ELSE 'Other'
    END AS LANGUAGE,
    CASE UNIFORM(1, 5, RANDOM(b.rn+7))
        WHEN 1 THEN 'Single'
        WHEN 2 THEN 'Married'
        WHEN 3 THEN 'Divorced'
        WHEN 4 THEN 'Widowed'
        ELSE 'Unknown'
    END AS MARITAL_STATUS,
    LPAD(UNIFORM(100,999,RANDOM(b.rn+8))::STRING,3,'0') || '-' ||
    LPAD(UNIFORM(10,99,RANDOM(b.rn+9))::STRING,2,'0') || '-' ||
    LPAD(UNIFORM(1000,9999,RANDOM(b.rn+10))::STRING,4,'0') AS SSN,
    '(' || LPAD(UNIFORM(200,999,RANDOM(b.rn+11))::STRING,3,'0') || ') ' ||
    LPAD(UNIFORM(200,999,RANDOM(b.rn+12))::STRING,3,'0') || '-' ||
    LPAD(UNIFORM(1000,9999,RANDOM(b.rn+13))::STRING,4,'0') AS PHONE,
    LOWER(fn.name) || '.' || LOWER(ln.name) || b.rn::STRING || '@email.com' AS EMAIL,
    UNIFORM(100, 9999, RANDOM(b.rn+14))::STRING || ' ' ||
    CASE UNIFORM(1,5,RANDOM(b.rn+15))
        WHEN 1 THEN 'Main St'  WHEN 2 THEN 'Oak Ave'  WHEN 3 THEN 'Pine Rd'
        WHEN 4 THEN 'Elm Blvd' ELSE 'Cedar Ln'
    END AS ADDRESS,
    z.city AS CITY,
    'WA' AS STATE,
    z.zip AS ZIP,
    z.county AS COUNTY,
    pw.payer_id AS PRIMARY_PAYER_ID,
    ROUND(0.5 + (UNIFORM(0, 400, RANDOM(b.rn+16)) / 100.0), 2) AS HCC_SCORE,
    ROUND(UNIFORM(0, 100, RANDOM(b.rn+17)) / 100.0, 2) AS SDOH_RISK_INDEX,
    CASE WHEN b.death_rand <= 2 THEN FALSE ELSE TRUE END AS IS_ACTIVE,
    CASE WHEN b.death_rand <= 2
         THEN DATEADD(DAY, -UNIFORM(1, 365, RANDOM(b.rn+18)), '2024-12-31')
         ELSE NULL
    END AS DEATH_DATE
FROM base b
JOIN (SELECT name, gender, ROW_NUMBER() OVER (ORDER BY name) AS idx FROM first_names) fn ON fn.idx = b.fn_idx
JOIN (SELECT name, ROW_NUMBER() OVER (ORDER BY name) AS idx FROM last_names) ln ON ln.idx = b.ln_idx
JOIN (SELECT zip, city, county, ROW_NUMBER() OVER (ORDER BY zip) AS idx FROM zips) z ON z.idx = b.zip_idx
JOIN (
    SELECT race,
           SUM(weight) OVER (ORDER BY race ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_w
    FROM races
) r ON b.race_pct <= r.cum_w
    AND (r.cum_w - (SELECT weight FROM races r2 WHERE r2.race = r.race)) < b.race_pct
JOIN payer_weights pw ON b.payer_pct <= pw.cum_weight
    AND NOT EXISTS (
        SELECT 1 FROM payer_weights pw2
        WHERE pw2.cum_weight < pw.cum_weight AND b.payer_pct <= pw2.cum_weight
    );

-- =============================================================================
-- 10. DIM_PROVIDER — 200 synthetic providers
-- =============================================================================
TRUNCATE TABLE IF EXISTS HOSPITAL360_CUR.CLINICAL.DIM_PROVIDER;

INSERT INTO HOSPITAL360_CUR.CLINICAL.DIM_PROVIDER
    (NPI, FIRST_NAME, LAST_NAME, CREDENTIAL, SPECIALTY, DEPT_ID, FACILITY_ID, IS_EMPLOYED, IS_ACTIVE, HIRE_DATE, FTE)
WITH specialties AS (
    SELECT column1 AS specialty, column2 AS dept_id, column3 AS credential, column4 AS cnt FROM VALUES
    ('Emergency Medicine',    'DEPT-001', 'MD', 20),
    ('Internal Medicine',     'DEPT-004', 'MD', 25),
    ('Hospitalist',           'DEPT-005', 'MD', 15),
    ('Cardiology',            'DEPT-006', 'MD', 12),
    ('Orthopedic Surgery',    'DEPT-007', 'MD', 10),
    ('Oncology',              'DEPT-008', 'MD',  8),
    ('OB/GYN',                'DEPT-009', 'MD', 10),
    ('General Surgery',       'DEPT-011', 'MD', 12),
    ('Neurology',             'DEPT-016', 'MD',  8),
    ('Pulmonology',           'DEPT-017', 'MD',  8),
    ('Critical Care',         'DEPT-002', 'MD', 10),
    ('Anesthesiology',        'DEPT-011', 'MD', 12),
    ('Radiology',             'DEPT-012', 'MD',  8),
    ('Family Medicine',       'DEPT-019', 'MD', 15),
    ('Psychiatry',            'DEPT-004', 'MD',  5),
    ('Urology',               'DEPT-011', 'MD',  4),
    ('Nurse Practitioner',    'DEPT-004', 'NP', 10),
    ('Physician Assistant',   'DEPT-001', 'PA',  8)
),
provider_names AS (
    SELECT column1 AS first_name, column2 AS last_name FROM VALUES
    ('Aiden','Sharma'),('Alexander','Chen'),('Amara','Okafor'),('Amy','Nakamura'),('Andrea','Rossi'),
    ('Angela','Kwan'),('Anthony','Volkov'),('Aria','Desai'),('Benjamin','Torres'),('Brandon','Singh'),
    ('Brian','Hoffman'),('Camille','Baptiste'),('Carlos','Mendez'),('Catherine','O''Brien'),('Charles','Liu'),
    ('Christina','Park'),('Christopher','Andersen'),('Claire','Montgomery'),('Daniel','Petrov'),('David','Yamamoto'),
    ('Diana','Castellanos'),('Edward','Khan'),('Elena','Sokolov'),('Elizabeth','McAllister'),('Emily','Tan'),
    ('Eric','Johansson'),('Ethan','Gupta'),('Evelyn','Dubois'),('Fatima','Al-Rashid'),('Frank','Mueller'),
    ('Gabriel','Costa'),('Grace','Yamamura'),('Hannah','Björk'),('Hassan','Farooq'),('Helena','Ivanova'),
    ('Henry','Nakagawa'),('Irene','Kowalski'),('Isaac','Nkemelu'),('James','Crawford'),('Jane','Okonkwo'),
    ('Jason','Berglund'),('Jennifer','Takahashi'),('Jessica','Fernandez'),('John','Lindqvist'),('Jonathan','Reddy'),
    ('Joseph','Antonov'),('Julia','Herrera'),('Justin','Subramaniam'),('Karen','Novak'),('Katherine','Choi'),
    ('Kenneth','Eriksson'),('Kevin','Bakshi'),('Kiran','Anand'),('Laura','Bergmann'),('Lauren','Mori'),
    ('Leo','Santana'),('Linda','Yamashita'),('Lisa','Gustafsson'),('Lucas','Pham'),('Margaret','Wu'),
    ('Maria','Ivankov'),('Mark','Sato'),('Martin','Johansson'),('Mary','Tanaka'),('Matthew','Nikolov'),
    ('Maya','Krishnamurthy'),('Megan','Olsson'),('Michael','Chang'),('Michelle','Petersen'),('Min-Jun','Cho'),
    ('Monica','Ramirez'),('Nathan','Schneider'),('Natalie','Fujimoto'),('Nicholas','Stein'),('Nina','Bergstrom'),
    ('Oliver','Zhao'),('Oscar','Delgado'),('Patrick','O''Sullivan'),('Paul','Hashimoto'),('Peter','Larsson'),
    ('Philip','Kaur'),('Rachel','Suzuki'),('Rebecca','Johansson'),('Richard','Watanabe'),('Robert','Engström'),
    ('Rosa','Medina'),('Ryan','Kimura'),('Samantha','Volkov'),('Samuel','Ishikawa'),('Sandra','Nylund'),
    ('Sarah','Matsumoto'),('Scott','Lindgren'),('Sophia','Agarwal'),('Stephen','Taniguchi'),('Susan','Blom'),
    ('Tariq','Hassan'),('Teresa','Morita'),('Thomas','Bergqvist'),('Timothy','Sasaki'),('Victor','Romero'),
    ('Victoria','Aoki'),('Vincent','Dubois'),('Wei','Zhang'),('William','Ito'),('Yuki','Kobayashi')
),
expanded AS (
    SELECT
        s.specialty, s.dept_id, s.credential, s.cnt,
        ROW_NUMBER() OVER (PARTITION BY s.specialty ORDER BY RANDOM()) AS spec_rn
    FROM specialties s,
         TABLE(GENERATOR(ROWCOUNT => 30)) g
    WHERE SEQ4() < s.cnt
)
SELECT
    '10' || LPAD((ROW_NUMBER() OVER (ORDER BY e.specialty, e.spec_rn) + 1000000)::STRING, 8, '0') AS NPI,
    pn.first_name,
    pn.last_name,
    e.credential,
    e.specialty,
    e.dept_id,
    -- Distribute across facilities: 60% FAC-001, 15% FAC-002, 15% FAC-003, 5% FAC-004, 5% FAC-005
    CASE
        WHEN ROW_NUMBER() OVER (ORDER BY e.specialty, e.spec_rn) % 20 < 12 THEN 'FAC-001'
        WHEN ROW_NUMBER() OVER (ORDER BY e.specialty, e.spec_rn) % 20 < 15 THEN 'FAC-002'
        WHEN ROW_NUMBER() OVER (ORDER BY e.specialty, e.spec_rn) % 20 < 18 THEN 'FAC-003'
        WHEN ROW_NUMBER() OVER (ORDER BY e.specialty, e.spec_rn) % 20 < 19 THEN 'FAC-004'
        ELSE 'FAC-005'
    END AS FACILITY_ID,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN TRUE ELSE FALSE END AS IS_EMPLOYED,
    TRUE AS IS_ACTIVE,
    DATEADD(DAY, -UNIFORM(365, 365*20, RANDOM()), '2024-06-30') AS HIRE_DATE,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 1.0 ELSE 0.8 END AS FTE
FROM expanded e
JOIN (SELECT first_name, last_name, ROW_NUMBER() OVER (ORDER BY first_name, last_name) AS idx FROM provider_names) pn
    ON (ROW_NUMBER() OVER (ORDER BY e.specialty, e.spec_rn) - 1) % 100 + 1 = pn.idx
WHERE ROW_NUMBER() OVER (ORDER BY e.specialty, e.spec_rn) <= 200;
