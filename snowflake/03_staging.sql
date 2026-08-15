-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Supply Chain Traceability
-- Country: INDONESIA | Currency: IDR
-- ============================================================================
USE DATABASE PALM_OIL_TRACEABILITY_ID;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- MILLS: 300 rows — Palm oil mills across Sumatra and Kalimantan with GPS coordinates and ISPO status
-- SHIPMENTS: 60,000 rows — CPO and PKO shipments from mill to refinery to port
-- CHAIN_OF_CUSTODY: 150,000 rows — Custody transfer records linking smallholder to mill to buyer
-- CERTIFICATIONS: 8,000 rows — ISPO, RSPO, and ISCC certifications per mill and supplier
-- AUDIT_REPORTS: 500 rows — Third-party audit reports, mass balance reconciliations, and findings
-- BUYERS: 80 rows — International buyers with sustainability requirements and data access scope
-- SMALLHOLDERS: 5,000 rows — Independent smallholders feeding into each mill catchment area
