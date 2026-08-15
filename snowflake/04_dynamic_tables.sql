-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Supply Chain Traceability
-- ============================================================================
USE DATABASE PALM_OIL_TRACEABILITY_ID;
USE SCHEMA CURATED;

-- FULL_CHAIN_OF_CUSTODY: End-to-end smallholder-to-port chain-of-custody with mass balance
-- Source: CHAIN_OF_CUSTODY, MILLS, SHIPMENTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.FULL_CHAIN_OF_CUSTODY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = TRACEABILITY_WH
AS
SELECT * FROM RAW.CHAIN_OF_CUSTODY;
-- TODO: Replace with actual join/aggregation logic per demo

-- MILL_TRACEABILITY_SCORE: Per-mill traceability completeness and certification status
-- Source: MILLS, CHAIN_OF_CUSTODY, CERTIFICATIONS
CREATE OR REPLACE DYNAMIC TABLE CURATED.MILL_TRACEABILITY_SCORE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = TRACEABILITY_WH
AS
SELECT * FROM RAW.MILLS;
-- TODO: Replace with actual join/aggregation logic per demo

-- BUYER_SUPPLY_CHAIN_VIEW: Buyer-specific supply chain view with Row Access Policy enforcement
-- Source: SHIPMENTS, CHAIN_OF_CUSTODY, BUYERS
CREATE OR REPLACE DYNAMIC TABLE CURATED.BUYER_SUPPLY_CHAIN_VIEW
  TARGET_LAG = '5 minutes'
  WAREHOUSE = TRACEABILITY_WH
AS
SELECT * FROM RAW.SHIPMENTS;
-- TODO: Replace with actual join/aggregation logic per demo

-- MASS_BALANCE_RECONCILIATION: Input-output mass balance per mill per month
-- Source: CHAIN_OF_CUSTODY, SHIPMENTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.MASS_BALANCE_RECONCILIATION
  TARGET_LAG = '5 minutes'
  WAREHOUSE = TRACEABILITY_WH
AS
SELECT * FROM RAW.CHAIN_OF_CUSTODY;
-- TODO: Replace with actual join/aggregation logic per demo

