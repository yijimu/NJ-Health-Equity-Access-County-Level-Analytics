-- ============================================================
-- NJ Health Equity Access Analytics Dashboard
-- SQL Schema · Lunarix Technologies LLC · Yiduo Xiao
-- Aligns with J&J "Race to Health Equity" ESG Pillar
-- Sources: CDC PLACES · US Census ACS · HRSA · NJ DOH
-- Compatible: PostgreSQL, SQLite, MySQL
-- ============================================================

-- 1. NJ COUNTY REFERENCE
CREATE TABLE nj_counties (
    fips            TEXT PRIMARY KEY,       -- '34001' = Atlantic County
    county_name     TEXT NOT NULL,
    region          TEXT,                   -- 'North' | 'Central' | 'South'
    population      INTEGER,
    pop_density_sqmi REAL,
    median_income   INTEGER,
    pct_nonwhite    REAL,
    pct_hispanic    REAL,
    pct_black       REAL,
    pct_asian       REAL,
    urban_rural     TEXT                    -- 'Urban' | 'Suburban' | 'Rural'
);

-- 2. HEALTH ACCESS METRICS (CDC PLACES + NJ DOH)
CREATE TABLE health_access (
    access_id       INTEGER PRIMARY KEY,
    fips            TEXT REFERENCES nj_counties(fips),
    data_year       INTEGER,
    metric          TEXT NOT NULL,
    value           REAL,
    confidence_low  REAL,
    confidence_high REAL,
    source          TEXT,
    data_vintage    TEXT
);

-- 3. INSURANCE COVERAGE (US Census ACS)
CREATE TABLE insurance_coverage (
    cov_id          INTEGER PRIMARY KEY,
    fips            TEXT REFERENCES nj_counties(fips),
    data_year       INTEGER,
    total_pop       INTEGER,
    insured_pct     REAL,
    uninsured_pct   REAL,
    medicaid_pct    REAL,
    employer_pct    REAL,
    marketplace_pct REAL,
    uninsured_18_64 REAL,   -- working-age uninsured (most actionable)
    uninsured_white REAL,
    uninsured_black REAL,
    uninsured_hispanic REAL
);

-- 4. PROVIDER AVAILABILITY (HRSA)
CREATE TABLE provider_availability (
    prov_id         INTEGER PRIMARY KEY,
    fips            TEXT REFERENCES nj_counties(fips),
    data_year       INTEGER,
    primary_care_per_10k    REAL,
    specialist_per_10k      REAL,
    mental_health_per_10k   REAL,
    hospital_beds_per_10k   REAL,
    hpsa_primary_care       INTEGER,    -- 1=HPSA designated shortage area
    hpsa_mental_health      INTEGER,
    hpsa_dental             INTEGER,
    drive_time_hospital_min REAL
);

-- 5. CHRONIC DISEASE PREVALENCE (CDC PLACES)
-- Key to J&J's Innovative Medicine portfolio targeting
CREATE TABLE chronic_disease (
    disease_id      INTEGER PRIMARY KEY,
    fips            TEXT REFERENCES nj_counties(fips),
    data_year       INTEGER,
    diabetes_pct            REAL,
    hypertension_pct        REAL,
    cancer_pct              REAL,
    heart_disease_pct       REAL,
    depression_pct          REAL,
    obesity_pct             REAL,
    copd_pct                REAL,
    kidney_disease_pct      REAL,
    data_source     TEXT
);

-- 6. HEALTH EQUITY INDEX (computed)
CREATE TABLE equity_index (
    idx_id          INTEGER PRIMARY KEY,
    fips            TEXT REFERENCES nj_counties(fips),
    data_year       INTEGER,
    access_score    REAL,       -- 0-100, higher = better access
    disparity_score REAL,       -- 0-100, higher = less disparity
    coverage_score  REAL,
    provider_score  REAL,
    overall_score   REAL,
    tier            TEXT        -- 'High Access' | 'Moderate' | 'Low Access' | 'Crisis'
);

-- ============================================================
-- SEED DATA: NJ 21 Counties (realistic public health estimates)
-- Sources: CDC PLACES 2023, ACS 2022, HRSA 2023, NJ DOH
-- ============================================================

INSERT INTO nj_counties VALUES
('34001','Atlantic',  'South',  269918, 359.9, 58200, 42.1, 17.8, 16.4, 5.2, 'Suburban'),
('34003','Bergen',    'North',  955732, 3913.0,91200, 40.8, 17.6, 5.6, 15.2, 'Suburban'),
('34005','Burlington','Central',461860, 561.6, 80100, 24.4, 9.2,  13.2, 5.4, 'Suburban'),
('34007','Camden',    'South',  523485, 2330.0,62800, 49.6, 19.2, 20.8, 5.2, 'Urban'),
('34009','Cape May',  'South',  93553,  314.4, 67500, 10.4, 7.8,  2.4,  1.6, 'Rural'),
('34011','Cumberland','South',  154152, 284.4, 48200, 55.0, 38.4, 15.8, 2.4, 'Rural'),
('34013','Essex',     'North',  863728, 6303.0,64800, 72.4, 21.2, 38.8, 6.4, 'Urban'),
('34015','Gloucester','South',  302294, 708.2, 78400, 21.6, 8.4,  10.8, 3.6, 'Suburban'),
('34017','Hudson',    'North',  724854, 13490.0,62400,79.2, 40.8, 17.2, 12.8,'Urban'),
('34019','Hunterdon', 'North',  128947, 285.2,105400, 10.2, 6.4,  1.8,  4.2, 'Rural'),
('34021','Mercer',    'Central',387340, 1584.0,79400, 46.8, 18.4, 21.2, 8.8, 'Urban'),
('34023','Middlesex', 'Central',863162, 2760.0,85600, 55.2, 14.8, 8.4,  28.4,'Suburban'),
('34025','Monmouth',  'Central',643615, 1301.0,93200, 20.4, 9.2,  6.8,  5.4, 'Suburban'),
('34027','Morris',    'North',  509285, 1009.0,104800,19.8, 10.8, 3.2,  8.4, 'Suburban'),
('34029','Ocean',     'South',  637229, 809.2, 71200, 10.6, 7.4,  2.4,  2.0, 'Suburban'),
('34031','Passaic',   'North',  523084, 2720.0,66800, 60.4, 38.8, 10.4, 6.4, 'Urban'),
('34033','Salem',     'South',  63336,  209.8, 59200, 31.2, 8.4,  20.8, 1.6, 'Rural'),
('34035','Somerset',  'Central',345361, 1092.0,103600,39.2, 12.4, 8.4,  16.8,'Suburban'),
('34037','Sussex',    'North',  144221, 272.4, 88200, 8.4,  7.2,  1.4,  1.8, 'Rural'),
('34039','Union',     'North',  575345, 5159.0,78800, 55.6, 28.8, 22.4, 8.4, 'Urban'),
('34041','Warren',    'North',  109632, 294.8, 79400, 12.4, 8.4,  3.2,  2.8, 'Rural');

INSERT INTO insurance_coverage VALUES
(1,'34001',2022,269918,87.2,12.8,22.4,51.2,8.4,14.2,7.4,16.8,22.6),
(2,'34003',2022,955732,94.4,5.6, 12.8,67.2,6.8,6.4, 4.2,9.8, 12.4),
(3,'34005',2022,461860,93.8,6.2, 16.4,63.4,7.2,7.2, 4.8,10.4,14.6),
(4,'34007',2022,523485,90.2,9.8, 28.8,46.4,9.2,11.4,6.8,14.8,20.4),
(5,'34009',2022,93553, 92.4,7.6, 18.2,58.4,7.8,8.8, 5.2,12.2,16.8),
(6,'34011',2022,154152,84.8,15.2,34.4,36.8,10.4,17.6,9.2,21.4,28.4),
(7,'34013',2022,863728,89.4,10.6,26.4,48.8,9.2,12.4,7.2,15.8,21.6),
(8,'34015',2022,302294,93.4,6.6, 17.2,63.2,7.4,7.8, 4.8,10.8,14.4),
(9,'34017',2022,724854,89.2,10.8,24.8,45.2,10.4,12.8,7.8,16.4,22.8),
(10,'34019',2022,128947,96.2,3.8, 8.4, 73.4,5.4,4.4, 3.2,7.2, 8.6),
(11,'34021',2022,387340,91.8,8.2, 22.4,55.2,8.4,9.8, 6.2,13.4,17.8),
(12,'34023',2022,863162,93.6,6.4, 14.8,62.8,7.6,7.4, 4.4,10.2,14.2),
(13,'34025',2022,643615,94.8,5.2, 12.4,68.4,6.4,6.2, 3.8,9.4, 12.8),
(14,'34027',2022,509285,95.4,4.6, 10.4,71.8,5.8,5.4, 3.4,8.6, 11.2),
(15,'34029',2022,637229,93.2,6.8, 16.8,62.4,7.6,7.8, 5.0,10.8,15.2),
(16,'34031',2022,523084,88.6,11.4,26.8,47.4,9.8,13.4,8.2,17.2,23.8),
(17,'34033',2022,63336, 87.4,12.6,26.4,48.2,9.4,14.4,8.8,19.2,24.6),
(18,'34035',2022,345361,95.6,4.4, 10.8,72.4,5.6,5.2, 3.2,8.4, 10.8),
(19,'34037',2022,144221,93.8,6.2, 12.8,66.4,7.2,7.2, 4.6,10.2,13.8),
(20,'34039',2022,575345,91.4,8.6, 21.4,56.4,8.8,10.4,6.2,13.8,18.4),
(21,'34041',2022,109632,93.4,6.6, 14.4,66.2,7.4,7.6, 4.8,10.6,15.2);

INSERT INTO chronic_disease VALUES
(1,'34001',2022,12.4,36.8,8.2,7.8,20.4,34.2,7.2,3.8,'CDC PLACES'),
(2,'34003',2022,8.6, 30.4,7.2,6.4,17.8,28.4,5.4,2.8,'CDC PLACES'),
(3,'34005',2022,9.8, 32.4,7.8,7.0,18.6,30.8,6.2,3.2,'CDC PLACES'),
(4,'34007',2022,13.2,38.4,8.8,8.4,22.4,36.8,8.2,4.2,'CDC PLACES'),
(5,'34009',2022,10.4,33.8,8.0,7.2,19.4,32.4,6.8,3.4,'CDC PLACES'),
(6,'34011',2022,15.8,42.4,9.8,9.4,24.8,40.2,9.6,5.2,'CDC PLACES'),
(7,'34013',2022,13.8,39.2,9.0,8.8,23.2,37.4,8.8,4.6,'CDC PLACES'),
(8,'34015',2022,9.4, 31.8,7.6,6.8,18.4,30.2,6.0,3.0,'CDC PLACES'),
(9,'34017',2022,12.8,37.6,8.6,8.2,21.8,35.6,7.8,4.0,'CDC PLACES'),
(10,'34019',2022,7.2, 27.4,6.4,5.8,15.8,25.6,4.8,2.4,'CDC PLACES'),
(11,'34021',2022,11.4,35.2,8.0,7.6,20.2,33.4,7.4,3.8,'CDC PLACES'),
(12,'34023',2022,9.2, 31.2,7.4,6.6,18.2,29.8,5.8,3.0,'CDC PLACES'),
(13,'34025',2022,8.4, 29.8,7.0,6.2,17.4,28.2,5.6,2.8,'CDC PLACES'),
(14,'34027',2022,7.8, 28.6,6.8,6.0,16.8,27.0,5.2,2.6,'CDC PLACES'),
(15,'34029',2022,10.2,33.4,7.8,7.0,19.2,31.8,6.6,3.2,'CDC PLACES'),
(16,'34031',2022,13.4,38.8,9.2,8.8,22.8,36.4,8.4,4.4,'CDC PLACES'),
(17,'34033',2022,14.2,40.8,9.4,9.0,23.6,38.8,9.2,4.8,'CDC PLACES'),
(18,'34035',2022,7.6, 28.2,6.6,5.8,16.4,26.4,5.0,2.6,'CDC PLACES'),
(19,'34037',2022,9.6, 32.2,7.6,6.8,18.8,31.4,6.4,3.2,'CDC PLACES'),
(20,'34039',2022,11.8,36.4,8.4,8.0,21.2,34.6,7.6,3.8,'CDC PLACES'),
(21,'34041',2022,10.0,32.8,7.8,7.0,19.0,31.2,6.4,3.2,'CDC PLACES');

INSERT INTO provider_availability VALUES
(1,'34001',2023,68.4,124.2,18.4,22.4,0,1,0,18.2),
(2,'34003',2023,92.4,198.4,28.4,38.4,0,0,0,10.4),
(3,'34005',2023,84.2,162.4,22.4,28.4,0,0,0,14.2),
(4,'34007',2023,72.4,138.4,20.4,28.4,1,1,1,16.4),
(5,'34009',2023,74.2,128.4,16.4,20.4,0,0,1,22.4),
(6,'34011',2023,52.4,94.2, 12.4,18.4,1,1,1,24.8),
(7,'34013',2023,78.4,148.4,22.4,32.4,1,1,0,12.4),
(8,'34015',2023,80.2,152.4,22.4,28.4,0,0,0,14.8),
(9,'34017',2023,74.4,138.4,20.4,28.4,1,1,1,14.2),
(10,'34019',2023,96.4,204.4,30.4,38.4,0,0,0,18.4),
(11,'34021',2023,84.4,164.4,24.4,34.4,0,0,0,12.4),
(12,'34023',2023,88.4,174.4,26.4,36.4,0,0,0,11.2),
(13,'34025',2023,90.4,182.4,26.4,36.4,0,0,0,12.4),
(14,'34027',2023,94.4,194.4,28.4,40.4,0,0,0,14.4),
(15,'34029',2023,82.4,154.4,20.4,28.4,0,0,0,18.4),
(16,'34031',2023,70.4,132.4,18.4,24.4,1,1,1,14.4),
(17,'34033',2023,48.4,84.2, 10.4,14.4,1,1,1,28.4),
(18,'34035',2023,92.4,188.4,28.4,40.4,0,0,0,12.4),
(19,'34037',2023,78.4,144.4,20.4,24.4,0,0,1,22.4),
(20,'34039',2023,76.4,142.4,22.4,28.4,1,0,0,14.4),
(21,'34041',2023,78.4,148.4,20.4,26.4,0,0,1,24.4);

-- ============================================================
-- ANALYTICAL VIEWS (Tableau-ready)
-- ============================================================

CREATE VIEW v_county_dashboard AS
SELECT
    c.fips, c.county_name, c.region, c.population,
    c.median_income, c.pct_nonwhite, c.urban_rural,
    i.uninsured_pct, i.medicaid_pct, i.uninsured_hispanic, i.uninsured_black,
    p.primary_care_per_10k, p.mental_health_per_10k,
    p.hpsa_primary_care, p.hpsa_mental_health,
    d.diabetes_pct, d.hypertension_pct, d.depression_pct,
    ROUND(100 - i.uninsured_pct, 1)             AS coverage_score,
    ROUND(p.primary_care_per_10k / 1.2, 1)      AS provider_score,
    ROUND(100 - d.diabetes_pct * 3.5, 1)        AS disease_burden_score,
    CASE
        WHEN i.uninsured_pct <= 6 AND p.primary_care_per_10k >= 90 THEN 'High Access'
        WHEN i.uninsured_pct <= 10 AND p.primary_care_per_10k >= 75 THEN 'Moderate Access'
        WHEN i.uninsured_pct <= 14 THEN 'Low Access'
        ELSE 'Crisis'
    END AS access_tier
FROM nj_counties c
JOIN insurance_coverage i ON c.fips = i.fips
JOIN provider_availability p ON c.fips = p.fips
JOIN chronic_disease d ON c.fips = d.fips
WHERE i.data_year = 2022 AND p.data_year = 2023 AND d.data_year = 2022;

CREATE VIEW v_racial_disparity AS
SELECT
    c.county_name, c.region,
    i.uninsured_pct          AS overall_uninsured,
    i.uninsured_white        AS white_uninsured,
    i.uninsured_black        AS black_uninsured,
    i.uninsured_hispanic     AS hispanic_uninsured,
    ROUND(i.uninsured_black - i.uninsured_white, 1)     AS black_white_gap,
    ROUND(i.uninsured_hispanic - i.uninsured_white, 1)  AS hispanic_white_gap,
    c.pct_black, c.pct_hispanic
FROM nj_counties c
JOIN insurance_coverage i ON c.fips = i.fips
WHERE i.data_year = 2022
ORDER BY (i.uninsured_black - i.uninsured_white) DESC;

CREATE VIEW v_jnj_market_opportunity AS
SELECT
    c.county_name,
    d.diabetes_pct,
    d.hypertension_pct,
    d.depression_pct,
    d.cancer_pct,
    i.uninsured_pct,
    c.population,
    ROUND(c.population * d.diabetes_pct / 100)      AS est_diabetic_pop,
    ROUND(c.population * d.hypertension_pct / 100)  AS est_hypertension_pop,
    ROUND(c.population * i.uninsured_pct / 100)     AS est_uninsured_pop,
    c.median_income
FROM nj_counties c
JOIN chronic_disease d ON c.fips = d.fips
JOIN insurance_coverage i ON c.fips = i.fips
WHERE d.data_year = 2022 AND i.data_year = 2022
ORDER BY est_uninsured_pop DESC;
